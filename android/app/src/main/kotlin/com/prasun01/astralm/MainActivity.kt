package com.prasun01.astralm

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.net.wifi.WifiManager
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
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
    private var downloadCompleteReceiver: BroadcastReceiver? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    private fun acquireDownloadLocks() {
        try {
            if (wakeLock == null) {
                val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                wakeLock = pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "AstraLM:ModelDownloadWakeLock")
                wakeLock?.setReferenceCounted(false)
            }
            if (wakeLock?.isHeld == false) {
                wakeLock?.acquire(2 * 60 * 60 * 1000L) // 2 hours max
            }

            if (wifiLock == null) {
                val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    WifiManager.WIFI_MODE_FULL_LOW_LATENCY
                } else {
                    WifiManager.WIFI_MODE_FULL_HIGH_PERF
                }
                wifiLock = wm?.createWifiLock(mode, "AstraLM:ModelDownloadWifiLock")
                wifiLock?.setReferenceCounted(false)
            }
            if (wifiLock?.isHeld == false) {
                wifiLock?.acquire()
            }
        } catch (_: Exception) {}
    }

    private fun releaseDownloadLocksIfIdle() {
        if (trackedDownloads.isEmpty()) {
            try {
                if (wakeLock?.isHeld == true) wakeLock?.release()
                if (wifiLock?.isHeld == true) wifiLock?.release()
            } catch (_: Exception) {}
        }
    }

    data class TrackedDownload(
        val downloadId: Long,
        val filename: String,
        var lastBytes: Long = 0L,
        var lastTimestamp: Long = System.currentTimeMillis(),
        var smoothedSpeed: Double = 0.0
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

        registerDownloadReceiver()
    }

    private fun registerDownloadReceiver() {
        if (downloadCompleteReceiver != null) return
        downloadCompleteReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == DownloadManager.ACTION_DOWNLOAD_COMPLETE) {
                    val downloadId = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
                    if (downloadId != -1L) {
                        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as? DownloadManager
                        var filename = trackedDownloads[downloadId]?.filename
                        var totalBytes = 0L

                        if (dm != null) {
                            try {
                                val query = DownloadManager.Query().setFilterById(downloadId)
                                val cursor: Cursor? = dm.query(query)
                                cursor?.use { c ->
                                    if (c.moveToFirst()) {
                                        val titleIdx = c.getColumnIndex(DownloadManager.COLUMN_TITLE)
                                        val totalIdx = c.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
                                        val statusIdx = c.getColumnIndex(DownloadManager.COLUMN_STATUS)
                                        if (filename == null && titleIdx >= 0) {
                                            filename = c.getString(titleIdx)?.removePrefix("AstraLM Model: ")?.trim()
                                        }
                                        if (totalIdx >= 0) {
                                            totalBytes = c.getLong(totalIdx)
                                        }
                                        val status = if (statusIdx >= 0) c.getInt(statusIdx) else -1
                                        if (status == DownloadManager.STATUS_SUCCESSFUL) {
                                            broadcastProgress(
                                                filename = filename ?: "model",
                                                copiedBytes = if (totalBytes > 0) totalBytes else 100L,
                                                totalBytes = if (totalBytes > 0) totalBytes else 100L,
                                                bytesPerSecond = 0.0,
                                                status = "Download complete"
                                            )
                                        } else if (status == DownloadManager.STATUS_FAILED) {
                                            broadcastProgress(
                                                filename = filename ?: "model",
                                                copiedBytes = 0L,
                                                totalBytes = 0L,
                                                bytesPerSecond = 0.0,
                                                status = "Download failed"
                                            )
                                        }
                                    }
                                }
                            } catch (e: Exception) {
                                // Ignore
                            }
                        }

                        trackedDownloads.remove(downloadId)
                        releaseDownloadLocksIfIdle()
                    }
                }
            }
        }
        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(downloadCompleteReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(downloadCompleteReceiver, filter)
        }
    }

    override fun onDestroy() {
        downloadCompleteReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                // Ignore
            }
            downloadCompleteReceiver = null
        }
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
            if (wifiLock?.isHeld == true) wifiLock?.release()
        } catch (_: Exception) {}
        super.onDestroy()
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
                val modelsDir = call.argument<String>("modelsDir")
                if (url.isNullOrBlank() || filename.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "URL and filename are required", null)
                    return
                }

                try {
                    val uri = Uri.parse(url.trim())
                    val request = DownloadManager.Request(uri).apply {
                        setTitle("AstraLM Model: $filename")
                        setDescription("Downloading model for AstraLM...")
                        try {
                            setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                        } catch (e: Exception) {
                            try {
                                setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
                            } catch (_: Exception) {}
                        }
                        setAllowedOverMetered(true)
                        setAllowedOverRoaming(true)
                        setMimeType("application/octet-stream")
                        addRequestHeader("User-Agent", "Mozilla/5.0 (Linux; Android 16; Mobile) AstraLM/1.0.9")
                        addRequestHeader("Accept", "*/*")

                        var destinationSet = false
                        if (!modelsDir.isNullOrBlank()) {
                            try {
                                val targetDir = File(modelsDir)
                                if (!targetDir.exists()) targetDir.mkdirs()
                                val destFile = File(targetDir, filename)
                                if (destFile.exists()) destFile.delete()
                                setDestinationUri(Uri.fromFile(destFile))
                                destinationSet = true
                            } catch (e: Exception) {
                                // Fallback
                            }
                        }

                        if (!destinationSet) {
                            try {
                                val extFilesDir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                                if (extFilesDir != null) {
                                    val destFile = File(extFilesDir, filename)
                                    if (destFile.exists()) destFile.delete()
                                    setDestinationUri(Uri.fromFile(destFile))
                                    destinationSet = true
                                }
                            } catch (e: Exception) {
                                // Fallback
                            }
                        }

                        if (!destinationSet) {
                            try {
                                setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, filename)
                            } catch (e: Exception) {
                                setDestinationInExternalFilesDir(applicationContext, Environment.DIRECTORY_DOWNLOADS, filename)
                            }
                        }
                    }

                    val downloadId = dm.enqueue(request)
                    trackedDownloads[downloadId] = TrackedDownload(downloadId, filename)
                    acquireDownloadLocks()
                    startProgressPoller()

                    result.success(mapOf(
                        "downloadId" to downloadId,
                        "filename" to filename
                    ))
                } catch (e: Exception) {
                    result.error("DOWNLOAD_START_FAILED", e.localizedMessage ?: "Failed to enqueue download", null)
                }
            }

            "acquireLocks" -> {
                acquireDownloadLocks()
                result.success(true)
            }
            "releaseLocks" -> {
                releaseDownloadLocksIfIdle()
                result.success(true)
            }
            "requestIgnoreBatteryOptimizations" -> {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        if (pm != null && !pm.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }

            "cancelDownloadToDownloads", "cancelDownloadInApp" -> {
                val downloadId = (call.argument<Number>("downloadId"))?.toLong()
                if (downloadId != null) {
                    try {
                        dm.remove(downloadId)
                    } catch (_: Exception) {}
                    trackedDownloads.remove(downloadId)
                    releaseDownloadLocksIfIdle()
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

                                if (!trackedDownloads.containsKey(id)) {
                                    trackedDownloads[id] = TrackedDownload(id, filename, downloaded)
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

                    if (trackedDownloads.isNotEmpty()) {
                        startProgressPoller()
                    }

                    result.success(activeList)
                } catch (e: Exception) {
                    result.error("QUERY_FAILED", e.localizedMessage ?: "Failed to query downloads", null)
                }
            }

            "restartApp" -> {
                try {
                    val intent = packageManager.getLaunchIntentForPackage(packageName)
                    intent?.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    Runtime.getRuntime().exit(0)
                } catch (e: Exception) {
                    result.error("RESTART_FAILED", e.localizedMessage, null)
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
                val filterIds = trackedDownloads.keys().toList().toLongArray()
                if (filterIds.isEmpty()) {
                    progressPollerRunnable = null
                    return
                }

                try {
                    val query = DownloadManager.Query().setFilterById(*filterIds)
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
                            if (elapsed >= 0.5 && downloaded >= tracked.lastBytes) {
                                val instantSpeed = (downloaded - tracked.lastBytes) / elapsed
                                tracked.smoothedSpeed = if (tracked.smoothedSpeed <= 0.0) {
                                    instantSpeed
                                } else {
                                    0.65 * tracked.smoothedSpeed + 0.35 * instantSpeed
                                }
                                tracked.lastBytes = downloaded
                                tracked.lastTimestamp = now
                            }

                            val (statusText, isFinished) = when (status) {
                                DownloadManager.STATUS_SUCCESSFUL -> Pair("Download complete", true)
                                DownloadManager.STATUS_FAILED -> Pair("Download failed", true)
                                DownloadManager.STATUS_PAUSED -> Pair("Paused", false)
                                DownloadManager.STATUS_PENDING -> Pair("Starting download...", false)
                                else -> Pair("Downloading...", false)
                            }

                            broadcastProgress(
                                filename = tracked.filename,
                                copiedBytes = downloaded,
                                totalBytes = total,
                                bytesPerSecond = tracked.smoothedSpeed,
                                status = statusText
                            )

                            if (isFinished) {
                                completedOrFailed.add(id)
                            }
                        }
                    }
                } catch (e: Exception) {
                    // Ignore query hiccups
                }

                for (id in completedOrFailed) {
                    trackedDownloads.remove(id)
                }

                if (trackedDownloads.isNotEmpty()) {
                    handler.postDelayed(this, 1000)
                } else {
                    progressPollerRunnable = null
                    releaseDownloadLocksIfIdle()
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
