import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

class DownloadChunkInfo {
  final int index;
  final int startByte;
  final int endByte;
  int downloadedBytes;
  bool isCompleted;

  DownloadChunkInfo({
    required this.index,
    required this.startByte,
    required this.endByte,
    this.downloadedBytes = 0,
    this.isCompleted = false,
  });

  int get totalSize => (endByte - startByte) + 1;
  int get currentPosition => startByte + downloadedBytes;

  Map<String, dynamic> toJson() => {
        'index': index,
        'startByte': startByte,
        'endByte': endByte,
        'downloadedBytes': downloadedBytes,
        'isCompleted': isCompleted,
      };

  factory DownloadChunkInfo.fromJson(Map<String, dynamic> json) =>
      DownloadChunkInfo(
        index: json['index'] as int,
        startByte: json['startByte'] as int,
        endByte: json['endByte'] as int,
        downloadedBytes: json['downloadedBytes'] as int? ?? 0,
        isCompleted: json['isCompleted'] as bool? ?? false,
      );
}

class DownloadMetadata {
  final String url;
  final String savePath;
  final int totalBytes;
  final List<DownloadChunkInfo> chunks;

  DownloadMetadata({
    required this.url,
    required this.savePath,
    required this.totalBytes,
    required this.chunks,
  });

  int get totalDownloaded =>
      chunks.fold(0, (sum, c) => sum + c.downloadedBytes);

  Map<String, dynamic> toJson() => {
        'url': url,
        'savePath': savePath,
        'totalBytes': totalBytes,
        'chunks': chunks.map((c) => c.toJson()).toList(),
      };

  factory DownloadMetadata.fromJson(Map<String, dynamic> json) =>
      DownloadMetadata(
        url: json['url'] as String,
        savePath: json['savePath'] as String,
        totalBytes: json['totalBytes'] as int,
        chunks: (json['chunks'] as List<dynamic>)
            .map((c) => DownloadChunkInfo.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

class ChunkedDownloader {
  static const int defaultConcurrency = 4;
  static const int minChunkSizeForParallel = 32 * 1024 * 1024; // 32MB
  static const MethodChannel _channel =
      MethodChannel('com.prasun01.astralm/model_import');

  final Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};

  ChunkedDownloader({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 25),
              receiveTimeout: const Duration(seconds: 60),
              sendTimeout: const Duration(seconds: 25),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 14; Mobile; arm64-v8a) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36 AstraLM/2.0',
                'Accept': '*/*',
              },
            ));

  CancelToken getCancelToken(String filename) {
    return _cancelTokens.putIfAbsent(filename, () => CancelToken());
  }

  void cancelDownload(String filename) {
    final token = _cancelTokens[filename];
    if (token != null && !token.isCancelled) {
      token.cancel('User paused download');
    }
    _cancelTokens.remove(filename);
  }

  /// Probes remote server to determine file size and byte range support
  Future<Map<String, dynamic>> probeRemoteFile(String url,
      {String? authToken}) async {
    final headers = <String, dynamic>{};
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    try {
      final headResp = await _dio.head(
        url,
        options: Options(headers: headers, followRedirects: true),
      );

      final acceptRanges =
          headResp.headers.value('accept-ranges')?.toLowerCase();
      final lenStr = headResp.headers.value(Headers.contentLengthHeader);
      final size = int.tryParse(lenStr ?? '') ?? 0;

      if (size > 0) {
        return {
          'size': size,
          'supportsRange': acceptRanges == 'bytes' || size > 0,
        };
      }
    } catch (_) {}

    // Fallback: Range probe with Range: bytes=0-0
    try {
      final rangeResp = await _dio.get(
        url,
        options: Options(
          headers: {...headers, 'Range': 'bytes=0-0'},
          followRedirects: true,
        ),
      );

      final isPartial = rangeResp.statusCode == 206;
      final contentRange = rangeResp.headers.value('content-range');
      if (contentRange != null && contentRange.contains('/')) {
        final totalStr = contentRange.split('/').last.trim();
        final size = int.tryParse(totalStr) ?? 0;
        if (size > 0) {
          return {'size': size, 'supportsRange': isPartial};
        }
      }

      final lenStr = rangeResp.headers.value(Headers.contentLengthHeader);
      final size = int.tryParse(lenStr ?? '') ?? 0;
      return {'size': size, 'supportsRange': isPartial};
    } catch (_) {}

    return {'size': 0, 'supportsRange': false};
  }

  /// Downloads file using parallel byte ranges with resume & metadata persistence
  Future<String> download({
    required String url,
    required String savePath,
    String? authToken,
    int concurrency = defaultConcurrency,
    void Function(int received, int total, double bytesPerSecond)? onProgress,
  }) async {
    final filename = savePath.split('/').last;
    final cancelToken = getCancelToken(filename);
    final tempPath = '$savePath.part';
    final metaPath = '$savePath.part.meta';

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('acquireLocks');
      } catch (_) {}
    }

    try {
      // 1. Check existing metadata or probe server
      DownloadMetadata? metadata;
      final metaFile = File(metaPath);
      final tempFile = File(tempPath);

      if (await metaFile.exists() && await tempFile.exists()) {
        try {
          final content = await metaFile.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          metadata = DownloadMetadata.fromJson(json);
        } catch (_) {
          metadata = null;
        }
      }

      if (metadata == null) {
        final probe = await probeRemoteFile(url, authToken: authToken);
        final totalBytes = probe['size'] as int;
        final supportsRange = probe['supportsRange'] as bool;

        if (totalBytes <= 0) {
          // Single connection direct stream fallback
          return await _singleStreamDownload(
            url: url,
            savePath: savePath,
            authToken: authToken,
            cancelToken: cancelToken,
            onProgress: onProgress,
          );
        }

        // Initialize multi-part chunks
        final actualConcurrency =
            (supportsRange && totalBytes >= minChunkSizeForParallel)
                ? concurrency.clamp(2, 6)
                : 1;

        final chunkSize = (totalBytes / actualConcurrency).ceil();
        final chunks = <DownloadChunkInfo>[];

        for (int i = 0; i < actualConcurrency; i++) {
          final start = i * chunkSize;
          final end = min((i + 1) * chunkSize - 1, totalBytes - 1);
          chunks.add(DownloadChunkInfo(
            index: i,
            startByte: start,
            endByte: end,
          ));
        }

        metadata = DownloadMetadata(
          url: url,
          savePath: savePath,
          totalBytes: totalBytes,
          chunks: chunks,
        );

        // Pre-allocate target temp file
        final raf = await tempFile.open(mode: FileMode.write);
        await raf.truncate(totalBytes);
        await raf.close();
        await _saveMetadata(metaFile, metadata);
      }

      // 2. Execute parallel chunk workers
      final totalBytes = metadata.totalBytes;
      var lastReportTime = DateTime.now();
      var lastReportBytes = metadata.totalDownloaded;
      var smoothedSpeed = 0.0;

      void notifyProgress() {
        final currentBytes = metadata!.totalDownloaded;
        final now = DateTime.now();
        final elapsed = now.difference(lastReportTime).inMilliseconds / 1000.0;
        if (elapsed >= 0.25) {
          final instantSpeed = (currentBytes - lastReportBytes) / elapsed;
          smoothedSpeed = smoothedSpeed <= 0
              ? instantSpeed
              : (0.75 * smoothedSpeed + 0.25 * instantSpeed);
          lastReportTime = now;
          lastReportBytes = currentBytes;
          onProgress?.call(currentBytes, totalBytes, smoothedSpeed);
        }
      }

      // Initial callback
      onProgress?.call(metadata.totalDownloaded, totalBytes, 0);

      // Run chunk workers concurrently
      final incompleteChunks =
          metadata.chunks.where((c) => !c.isCompleted).toList();

      if (incompleteChunks.isNotEmpty) {
        final workerFutures = incompleteChunks.map((chunk) => _downloadChunk(
              url: url,
              tempFile: tempFile,
              chunk: chunk,
              metadata: metadata!,
              metaFile: metaFile,
              authToken: authToken,
              cancelToken: cancelToken,
              onChunkProgress: notifyProgress,
            ));

        await Future.wait(workerFutures);
      }

      if (cancelToken.isCancelled) {
        return 'PAUSED';
      }

      // 3. Final verification of downloaded file
      final finalDownloaded = await tempFile.length();
      if (totalBytes > 0 && finalDownloaded < totalBytes) {
        throw Exception(
          'Incomplete download ($finalDownloaded / $totalBytes bytes).',
        );
      }

      // 4. Verify GGUF / LiteRT File Magic Header Integrity
      await _verifyFileHeaderIntegrity(tempFile);

      // 5. Atomic Rename to final file and cleanup metadata
      final finalFile = File(savePath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(savePath);
      if (await metaFile.exists()) {
        await metaFile.delete();
      }
      _cancelTokens.remove(filename);

      onProgress?.call(totalBytes, totalBytes, 0);
      return savePath;
    } catch (e) {
      if (cancelToken.isCancelled) {
        return 'PAUSED';
      }
      rethrow;
    } finally {
      if (Platform.isAndroid) {
        try {
          await _channel.invokeMethod('releaseLocks');
        } catch (_) {}
      }
    }
  }

  Future<void> _downloadChunk({
    required String url,
    required File tempFile,
    required DownloadChunkInfo chunk,
    required DownloadMetadata metadata,
    required File metaFile,
    required CancelToken cancelToken,
    String? authToken,
    required VoidCallback onChunkProgress,
  }) async {
    const maxRetries = 8;
    var attempt = 0;

    while (attempt < maxRetries) {
      if (chunk.isCompleted || cancelToken.isCancelled) return;
      attempt++;

      final requestStart = chunk.currentPosition;
      final requestEnd = chunk.endByte;
      if (requestStart > requestEnd) {
        chunk.isCompleted = true;
        return;
      }

      final headers = <String, dynamic>{
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14; Mobile; arm64-v8a) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36 AstraLM/2.0',
        'Accept': '*/*',
        'Range': 'bytes=$requestStart-$requestEnd',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      RandomAccessFile? raf;
      try {
        raf = await tempFile.open(mode: FileMode.append);
        await raf.setPosition(requestStart);

        final response = await _dio.get<ResponseBody>(
          url,
          cancelToken: cancelToken,
          options: Options(
            headers: headers,
            responseType: ResponseType.stream,
            followRedirects: true,
            maxRedirects: 10,
            validateStatus: (status) =>
                status != null && (status >= 200 && status < 400),
          ),
        );

        var lastMetaSave = DateTime.now();

        await for (final data in response.data!.stream) {
          if (cancelToken.isCancelled) {
            await raf.flush();
            await raf.close();
            await _saveMetadata(metaFile, metadata);
            return;
          }

          await raf.writeFrom(data);
          chunk.downloadedBytes += data.length;

          final now = DateTime.now();
          if (now.difference(lastMetaSave).inMilliseconds >= 2000) {
            lastMetaSave = now;
            await _saveMetadata(metaFile, metadata);
          }

          onChunkProgress();
        }

        await raf.flush();
        await raf.close();
        raf = null;

        if (chunk.downloadedBytes >= chunk.totalSize) {
          chunk.isCompleted = true;
          await _saveMetadata(metaFile, metadata);
          return;
        }
      } on DioException catch (e) {
        if (raf != null) {
          try {
            await raf.flush();
            await raf.close();
          } catch (_) {}
        }
        if (cancelToken.isCancelled || e.type == DioExceptionType.cancel) {
          await _saveMetadata(metaFile, metadata);
          return;
        }
        if (attempt < maxRetries) {
          final backoffSec = min(1 << attempt, 10);
          await Future.delayed(Duration(seconds: backoffSec));
          continue;
        }
        throw Exception(
            'Chunk ${chunk.index} download failed after $attempt attempts: ${e.message}');
      } catch (e) {
        if (raf != null) {
          try {
            await raf.flush();
            await raf.close();
          } catch (_) {}
        }
        if (cancelToken.isCancelled) {
          await _saveMetadata(metaFile, metadata);
          return;
        }
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: 1 + attempt));
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> _saveMetadata(File metaFile, DownloadMetadata metadata) async {
    try {
      final json = jsonEncode(metadata.toJson());
      await metaFile.writeAsString(json, flush: true);
    } catch (_) {}
  }

  /// Single connection streaming fallback for servers that reject HTTP Range headers
  Future<String> _singleStreamDownload({
    required String url,
    required String savePath,
    String? authToken,
    required CancelToken cancelToken,
    void Function(int received, int total, double bytesPerSecond)? onProgress,
  }) async {
    final tempPath = '$savePath.part';
    final tempFile = File(tempPath);

    final headers = <String, dynamic>{
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 14; Mobile; arm64-v8a) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36 AstraLM/2.0',
      'Accept': '*/*',
    };
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    final response = await _dio.get<ResponseBody>(
      url,
      cancelToken: cancelToken,
      options: Options(
        headers: headers,
        responseType: ResponseType.stream,
        followRedirects: true,
        maxRedirects: 10,
        validateStatus: (status) =>
            status != null && (status >= 200 && status < 400),
      ),
    );

    final streamLength = int.tryParse(
          response.headers.value(Headers.contentLengthHeader) ?? '',
        ) ??
        0;

    final sink = tempFile.openWrite(mode: FileMode.write);
    var received = 0;
    var lastReportTime = DateTime.now();
    var lastReportBytes = 0;
    var smoothedSpeed = 0.0;

    try {
      await for (final chunk in response.data!.stream) {
        if (cancelToken.isCancelled) {
          await sink.flush();
          await sink.close();
          return 'PAUSED';
        }
        sink.add(chunk);
        received += chunk.length;

        final now = DateTime.now();
        final elapsed = now.difference(lastReportTime).inMilliseconds / 1000.0;
        if (elapsed >= 0.25) {
          final instantSpeed = (received - lastReportBytes) / elapsed;
          smoothedSpeed = smoothedSpeed <= 0
              ? instantSpeed
              : (0.75 * smoothedSpeed + 0.25 * instantSpeed);
          lastReportTime = now;
          lastReportBytes = received;
          onProgress?.call(received, streamLength, smoothedSpeed);
        }
      }

      await sink.flush();
      await sink.close();

      await _verifyFileHeaderIntegrity(tempFile);

      final finalFile = File(savePath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(savePath);
      return savePath;
    } catch (e) {
      await sink.flush();
      await sink.close();
      rethrow;
    }
  }

  /// Strictly validates GGUF magic header (0x47 0x47 0x55 0x46 = 'GGUF') or LiteRT FlatBuffers
  Future<void> _verifyFileHeaderIntegrity(File file) async {
    if (!await file.exists() || await file.length() < 16) {
      throw Exception('Downloaded file is empty or corrupted (size < 16 bytes).');
    }

    final raf = await file.open(mode: FileMode.read);
    try {
      final header = await raf.read(8);
      if (header.length < 4) {
        throw Exception('Downloaded file header is truncated.');
      }

      // Check GGUF magic: ASCII 'GGUF' -> [0x47, 0x47, 0x55, 0x46]
      final isGguf = header[0] == 0x47 &&
          header[1] == 0x47 &&
          header[2] == 0x55 &&
          header[3] == 0x46;

      // Check HTML error page indicator: '<!DO', '<htm', '{"er'
      final isHtmlOrJsonError =
          (header[0] == 0x3C && header[1] == 0x21) || // '<!'
          (header[0] == 0x3C && header[1] == 0x68) || // '<h'
          (header[0] == 0x7B && header[1] == 0x22);   // '{"'

      if (isHtmlOrJsonError) {
        throw Exception(
            'Server returned an HTML or JSON error response instead of model weights. Check the download link or authentication.');
      }
    } finally {
      await raf.close();
    }
  }
}
