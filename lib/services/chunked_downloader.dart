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
    var token = _cancelTokens[filename];
    if (token == null || token.isCancelled) {
      token = CancelToken();
      _cancelTokens[filename] = token;
    }
    return token;
  }

  void cancelDownload(String filename) {
    final token = _cancelTokens[filename];
    if (token != null && !token.isCancelled) {
      token.cancel('User paused download');
    }
    _cancelTokens.remove(filename);
  }

  Future<Map<String, dynamic>> probeRemoteFile(String url,
      {String? authToken}) async {
    final headers = <String, dynamic>{};
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    try {
      final headResp = await _dio.head(
        url,
        options: Options(
          headers: headers,
          followRedirects: true,
          maxRedirects: 10,
          validateStatus: (status) =>
              status != null && (status >= 200 && status < 400),
        ),
      );

      final contentLength =
          int.tryParse(headResp.headers.value('content-length') ?? '') ?? 0;
      final acceptRanges =
          headResp.headers.value('accept-ranges')?.toLowerCase() ?? '';
      final supportsRange = acceptRanges.contains('bytes');

      if (contentLength > 0) {
        return {
          'size': contentLength,
          'supportsRange': supportsRange,
        };
      }
    } catch (_) {}

    try {
      final rangeHeaders = Map<String, dynamic>.from(headers);
      rangeHeaders['Range'] = 'bytes=0-0';
      final rangeResp = await _dio.get(
        url,
        options: Options(
          headers: rangeHeaders,
          followRedirects: true,
          maxRedirects: 10,
          validateStatus: (status) =>
              status == 200 || status == 206,
        ),
      );

      if (rangeResp.statusCode == 206) {
        final contentRange = rangeResp.headers.value('content-range');
        if (contentRange != null && contentRange.contains('/')) {
          final totalStr = contentRange.split('/').last.trim();
          final total = int.tryParse(totalStr) ?? 0;
          if (total > 0) {
            return {
              'size': total,
              'supportsRange': true,
            };
          }
        }
      }

      final contentLength =
          int.tryParse(rangeResp.headers.value('content-length') ?? '') ?? 0;
      return {
        'size': contentLength,
        'supportsRange': false,
      };
    } catch (_) {
      return {
        'size': 0,
        'supportsRange': false,
      };
    }
  }

  Future<String> startDownload({
    required String url,
    required String savePath,
    String? authToken,
    int concurrency = defaultConcurrency,
    void Function(int received, int total, double speedBytesPerSec)? onProgress,
  }) async {
    final filename = savePath.split('/').last;
    final metaPath = '$savePath.part.meta';
    final tempPath = '$savePath.part';

    final cancelToken = getCancelToken(filename);

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('acquireLocks');
      } catch (_) {}
    }

    try {
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
          return await _singleStreamDownload(
            url: url,
            savePath: savePath,
            authToken: authToken,
            cancelToken: cancelToken,
            onProgress: onProgress,
          );
        }

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

        final raf = await tempFile.open(mode: FileMode.write);
        await raf.truncate(totalBytes);
        await raf.close();
        await _saveMetadata(metaFile, metadata);
      }

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

      onProgress?.call(metadata.totalDownloaded, totalBytes, 0);

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

      final finalDownloaded = await tempFile.length();
      if (totalBytes > 0 && finalDownloaded < totalBytes) {
        throw Exception(
          'Incomplete download ($finalDownloaded / $totalBytes bytes).',
        );
      }

      await _verifyFileHeaderIntegrity(tempFile);

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
        raf = await tempFile.open(mode: FileMode.write);
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
        throw Exception('Chunk ${chunk.index} unexpected error: $e');
      }
    }
  }

  Future<String> _singleStreamDownload({
    required String url,
    required String savePath,
    String? authToken,
    required CancelToken cancelToken,
    void Function(int received, int total, double speedBytesPerSec)? onProgress,
  }) async {
    final tempPath = '$savePath.part';
    final tempFile = File(tempPath);

    int existingBytes = 0;
    if (await tempFile.exists()) {
      existingBytes = await tempFile.length();
    }

    final headers = <String, dynamic>{
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 14; Mobile; arm64-v8a) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36 AstraLM/2.0',
      'Accept': '*/*',
    };
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    if (existingBytes > 0) {
      headers['Range'] = 'bytes=$existingBytes-';
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
            status == 200 || status == 206,
      ),
    );

    int totalBytes = -1;
    final isPartial = response.statusCode == 206;

    if (isPartial) {
      final contentRange = response.headers.value('content-range');
      if (contentRange != null && contentRange.contains('/')) {
        totalBytes =
            int.tryParse(contentRange.split('/').last.trim()) ?? -1;
      }
    } else {
      totalBytes =
          int.tryParse(response.headers.value('content-length') ?? '') ?? -1;
      existingBytes = 0;
    }

    final raf = await tempFile.open(
        mode: isPartial ? FileMode.write : FileMode.write);
    if (isPartial) {
      await raf.setPosition(existingBytes);
    }

    int receivedBytes = existingBytes;
    var lastReportTime = DateTime.now();
    var lastReportBytes = receivedBytes;
    var smoothedSpeed = 0.0;

    try {
      await for (final data in response.data!.stream) {
        if (cancelToken.isCancelled) {
          await raf.flush();
          await raf.close();
          return 'PAUSED';
        }

        await raf.writeFrom(data);
        receivedBytes += data.length;

        final now = DateTime.now();
        final elapsed = now.difference(lastReportTime).inMilliseconds / 1000.0;
        if (elapsed >= 0.25) {
          final instantSpeed = (receivedBytes - lastReportBytes) / elapsed;
          smoothedSpeed = smoothedSpeed <= 0
              ? instantSpeed
              : (0.75 * smoothedSpeed + 0.25 * instantSpeed);
          lastReportTime = now;
          lastReportBytes = receivedBytes;
          onProgress?.call(receivedBytes, totalBytes, smoothedSpeed);
        }
      }

      await raf.flush();
      await raf.close();

      await _verifyFileHeaderIntegrity(tempFile);

      final finalFile = File(savePath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(savePath);

      onProgress?.call(totalBytes, totalBytes, 0);
      return savePath;
    } catch (e) {
      try {
        await raf.close();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _verifyFileHeaderIntegrity(File file) async {
    if (!await file.exists()) {
      throw Exception('Downloaded file does not exist.');
    }
    final len = await file.length();
    if (len < 16) {
      throw Exception('Downloaded file is too small ($len bytes).');
    }

    final raf = await file.open(mode: FileMode.read);
    final headerBytes = await raf.read(8);
    await raf.close();

    final headerStr = String.fromCharCodes(headerBytes);
    if (headerStr.startsWith('<!DOC') ||
        headerStr.startsWith('<html') ||
        headerStr.startsWith('{"err') ||
        headerStr.startsWith('{"mes')) {
      throw Exception(
        'Server returned an HTML/JSON error page instead of binary model data.',
      );
    }
  }

  Future<void> _saveMetadata(File metaFile, DownloadMetadata metadata) async {
    try {
      final jsonStr = jsonEncode(metadata.toJson());
      await metaFile.writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }
}
