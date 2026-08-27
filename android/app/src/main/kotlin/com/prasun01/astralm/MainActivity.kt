package com.prasun01.astralm

import android.app.DownloadManager
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.Environment
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap

class MainActivity : FlutterActivity() {
    private val CHANNEL_NAMES = listOf(
        "com.prasun01.astralm/model_import",
        "com.aichat.ai_chat/model_import"
    )
    private val channels = mutableListOf<MethodChannel>()
    private val handler = Handler(Looper.getMainLooper())
    private val trackedDownloads = ConcurrentHashMap<Long, TrackedDownload>()
    private var progressPollerRunnable: Runnable? = null

    data class TrackedDownload(
        val downloadId: Long,
        val filename: String,
        var lastBytes: Long = 0L,
        var lastTimestamp: Long = System.currentTimeMillis()
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        for (channelName in CHANNEL_NAMES) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            channels.add(channel)
            channel.setMethodCallHandler { call, result ->
                handleMethodCall(call, result)
            }
        }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as? DownloadManager
        if (dm == null) {
            result.error("NO_DOWNLOAD_MANAGER", "DownloadManager is unavailable", null)
            return
        }

        when (call.method) {
            "downloadToDownloads", "downloadModelInApp" -> {
                val url = call.argument<String>("url")
                val filename = call.argument<String>("filename")
                if (url.isNullOrBlank() || filename.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "URL and filename are required", null)
                    return
                }

                try {
                    val uri = Uri.parse(url)
                    val request = DownloadManager.Request(uri).apply {
                        setTitle("AstraLM Model: $filename")
                        setDescription("Downloading AI model weights...")
                        setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                        setAllowedOverMetered(true)
                        setAllowedOverRoaming(true)
                        setMimeType("application/octet-stream")
                        addRequestHeader("User-Agent", "Mozilla/5.0 (Linux; Android 14) AstraLM/1.0.8")
                        setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, filename)
                    }

                    val downloadId = dm.enqueue(request)
                    trackedDownloads[downloadId] = TrackedDownload(downloadId, filename)
                    startProgressPoller()

                    result.success(mapOf(
                        "downloadId" to downloadId,
                        "filename" to filename
                    ))
                } catch (e: Exception) {
                    result.error("DOWNLOAD_START_FAILED", e.localizedMessage, null)
                }
            }

            "cancelDownloadToDownloads", "cancelDownloadInApp" -> {
                val downloadId = (call.argument<Number>("downloadId"))?.toLong()
                if (downloadId != null) {
                    dm.remove(downloadId)
                    trackedDownloads.remove(downloadId)
                    result.success(true)
                } else {
                    result.success(false)
                }
            }

            "getActiveDownloads" -> {
                try {
                    val activeList = mutableListOf<Map<String, Any>>()
                    val query = DownloadManager.Query()
                    val cursor: Cursor? = dm.query(query)
                    cursor?.use { c ->
                        val idIdx = c.getColumnIndex(DownloadManager.COLUMN_ID)
                        val titleIdx = c.getColumnIndex(DownloadManager.COLUMN_TITLE)
                        val statusIdx = c.getColumnIndex(DownloadManager.COLUMN_STATUS)
                        val bytesSoFarIdx = c.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                        val totalBytesIdx = c.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)

                        while (c.moveToNext()) {
                            val id = c.getLong(idIdx)
                            val status = c.getInt(statusIdx)
                            if (status == DownloadManager.STATUS_RUNNING || status == DownloadManager.STATUS_PENDING || status == DownloadManager.STATUS_PAUSED) {
                                val title = if (titleIdx >= 0) c.getString(titleIdx) ?: "model" else "model"
                                val filename = trackedDownloads[id]?.filename ?: title.removePrefix("AstraLM Model: ").trim()
                                val downloaded = if (bytesSoFarIdx >= 0) c.getLong(bytesSoFarIdx) else 0L
                                val total = if (totalBytesIdx >= 0) c.getLong(totalBytesIdx) else 0L
                                val statusStr = when (status) {
                                    DownloadManager.STATUS_PAUSED -> "Paused"
                                    DownloadManager.STATUS_PENDING -> "Pending"
                                    else -> "Downloading..."
                                }
                                activeList.add(mapOf(
                                    "downloadId" to id,
                                    "filename" to filename,
                                    "downloaded" to downloaded,
                                    "total" to total,
                                    "status" to statusStr
                                ))
                            }
                        }
                    }
                    result.success(activeList)
                } catch (e: Exception) {
                    result.error("QUERY_FAILED", e.localizedMessage, null)
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun startProgressPoller() {
        if (progressPollerRunnable != null) return

        progressPollerRunnable = object : Runnable {
            override fun run() {
                if (trackedDownloads.isEmpty()) {
                    progressPollerRunnable = null
                    return
                }

                val dm = getSystemService(Context.DOWNLOAD_SERVICE) as? DownloadManager
                if (dm == null) {
                    progressPollerRunnable = null
                    return
                }

                val completedOrFailed = mutableListOf<Long>()
                val query = DownloadManager.Query().setFilterById(*trackedDownloads.keys().toList().toLongArray())
                val cursor: Cursor? = dm.query(query)

                cursor?.use { c ->
                    val idIdx = c.getColumnIndex(DownloadManager.COLUMN_ID)
                    val statusIdx = c.getColumnIndex(DownloadManager.COLUMN_STATUS)
                    val bytesSoFarIdx = c.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                    val totalBytesIdx = c.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)

                    while (c.moveToNext()) {
                        val id = c.getLong(idIdx)
                        val tracked = trackedDownloads[id] ?: continue
                        val status = c.getInt(statusIdx)
                        val downloaded = if (bytesSoFarIdx >= 0) c.getLong(bytesSoFarIdx) else 0L
                        val total = if (totalBytesIdx >= 0) c.getLong(totalBytesIdx) else 0L

                        val now = System.currentTimeMillis()
                        val elapsed = (now - tracked.lastTimestamp) / 1000.0
                        val speed = if (elapsed > 0 && downloaded >= tracked.lastBytes) {
                            (downloaded - tracked.lastBytes) / elapsed
                        } else 0.0

                        tracked.lastBytes = downloaded
                        tracked.lastTimestamp = now

                        val (statusText, isFinished) = when (status) {
                            DownloadManager.STATUS_SUCCESSFUL -> Pair("Download complete", true)
                            DownloadManager.STATUS_FAILED -> Pair("Download failed", true)
                            DownloadManager.STATUS_PAUSED -> Pair("Paused", false)
                            DownloadManager.STATUS_PENDING -> Pair("Starting download...", false)
                            else -> Pair("Downloading to phone...", false)
                        }

                        broadcastProgress(
                            filename = tracked.filename,
                            copiedBytes = downloaded,
                            totalBytes = total,
                            bytesPerSecond = speed,
                            status = statusText
                        )

                        if (isFinished) {
                            completedOrFailed.add(id)
                        }
                    }
                }

                for (id in completedOrFailed) {
                    trackedDownloads.remove(id)
                }

                if (trackedDownloads.isNotEmpty()) {
                    handler.postDelayed(this, 1000)
                } else {
                    progressPollerRunnable = null
                }
            }
        }

        handler.post(progressPollerRunnable!!)
    }

    private fun broadcastProgress(
        filename: String,
        copiedBytes: Long,
        totalBytes: Long,
        bytesPerSecond: Double,
        status: String
    ) {
        val payload = mapOf(
            "filename" to filename,
            "copiedBytes" to copiedBytes,
            "totalBytes" to totalBytes,
            "bytesPerSecond" to bytesPerSecond,
            "status" to status
        )
        for (channel in channels) {
            channel.invokeMethod("importProgress", payload)
        }
    }
}
