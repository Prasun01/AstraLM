import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

final Dio _dio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
    sendTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 14; Mobile; arm64-v8a) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36 AstraLM/2.0',
      'Accept': '*/*',
    },
  ),
);
final Map<String, CancelToken> _cancelTokens = {};
const _channel = MethodChannel('com.prasun01.astralm/model_import');

Future<String> getModelsDir() async {
  final dir = await getApplicationDocumentsDirectory();
  final modelsPath = '${dir.path}/models';
  await Directory(modelsPath).create(recursive: true);
  return modelsPath;
}

Future<bool> isModelDownloaded(String path) async {
  return File(path).existsSync();
}

Future<List<String>> getDownloadedModels(String modelsDir) async {
  final result = <String>{};
  final dir = Directory(modelsDir);
  if (await dir.exists()) {
    try {
      for (final f in dir.listSync()) {
        final p = f.path.toLowerCase();
        if (p.endsWith('.gguf') ||
            p.endsWith('.litertlm') ||
            p.endsWith('.safetensors')) {
          result.add(f.path.split('/').last);
        }
      }
    } catch (_) {}
  }
  if (Platform.isAndroid) {
    for (final dlPath in ['/storage/emulated/0/Download', '/sdcard/Download']) {
      try {
        final dlDir = Directory(dlPath);
        if (await dlDir.exists()) {
          for (final f in dlDir.listSync()) {
            final p = f.path.toLowerCase();
            if (p.endsWith('.gguf') ||
                p.endsWith('.litertlm') ||
                p.endsWith('.safetensors')) {
              result.add(f.path.split('/').last);
            }
          }
        }
      } catch (_) {}
    }
  }
  return result.toList();
}

Future<int> getModelSize(String path) async {
  final file = File(path);
  if (!await file.exists()) return 0;
  return await file.length();
}

Future<int> getRemoteFileSize(String url, {String? authToken}) async {
  final headers = <String, dynamic>{};
  if (authToken != null && authToken.isNotEmpty) {
    headers['Authorization'] = 'Bearer $authToken';
  }

  // 1. Try HEAD request
  try {
    final response = await _dio.head(
      url,
      options: Options(headers: headers, followRedirects: true),
    );
    final length = response.headers.value(Headers.contentLengthHeader);
    final size = int.tryParse(length ?? '') ?? 0;
    if (size > 0) return size;
  } catch (_) {
    // If HEAD fails, fall back to GET with Range
  }

  // 2. Try GET request with Range: bytes=0-0 (efficiently fetch metadata only)
  try {
    final response = await _dio.get(
      url,
      options: Options(
        headers: {
          ...headers,
          'Range': 'bytes=0-0',
        },
        followRedirects: true,
      ),
    );
    
    // Check Content-Range header first (e.g., bytes 0-0/12345678)
    final contentRange = response.headers.value('content-range');
    if (contentRange != null) {
      final parts = contentRange.split('/');
      if (parts.length > 1) {
        final size = int.tryParse(parts.last.trim());
        if (size != null && size > 0) return size;
      }
    }

    // Fallback to Content-Length (if the server ignored Range and returned the whole file)
    final length = response.headers.value(Headers.contentLengthHeader);
    final size = int.tryParse(length ?? '') ?? 0;
    if (size > 0) return size;
  } catch (_) {
    // Both failed
  }

  return 0;
}

Future<String> downloadModel({
  required String url,
  required String savePath,
  String? authToken,
  void Function(int received, int total)? onProgress,
}) async {
  final tempPath = '$savePath.part';
  final cancelToken = CancelToken();
  final filename = savePath.split('/').last;
  _cancelTokens[filename] = cancelToken;
  var expectedTotalBytes = 0;

  final tempFile = File(tempPath);
  final oldTempFile = File('$savePath.tmp');
  if (await oldTempFile.exists()) {
    try {
      await oldTempFile.delete();
    } catch (_) {}
  }

  // First, get remote file size if not known
  expectedTotalBytes = await getRemoteFileSize(url, authToken: authToken);

  var attempts = 0;
  const maxAttempts = 6;

  while (attempts < maxAttempts) {
    attempts++;
    var startByte = 0;
    if (await tempFile.exists()) {
      startByte = await tempFile.length();
    }

    if (expectedTotalBytes > 0 && startByte >= expectedTotalBytes) {
      // Already fully downloaded in temp
      final finalFile = File(savePath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(savePath);
      _cancelTokens.remove(filename);
      return savePath;
    }

    final headers = <String, dynamic>{
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 14; Mobile; arm64-v8a) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36 AstraLM/1.0.9',
      'Accept': '*/*',
    };
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    if (startByte > 0) {
      headers['Range'] = 'bytes=$startByte-';
    }

    IOSink? sink;
    try {
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

      final isPartial = response.statusCode == 206;
      sink = tempFile.openWrite(
        mode: (isPartial && startByte > 0) ? FileMode.append : FileMode.write,
      );

      final streamLength = int.tryParse(
            response.headers.value(Headers.contentLengthHeader) ?? '',
          ) ??
          0;

      if (isPartial) {
        if (expectedTotalBytes <= 0) {
          expectedTotalBytes = startByte + streamLength;
        }
      } else {
        startByte = 0;
        if (streamLength > 0) {
          expectedTotalBytes = streamLength;
        }
      }

      var receivedBytes = startByte;
      if (onProgress != null && expectedTotalBytes > 0) {
        onProgress(receivedBytes, expectedTotalBytes);
      }

      await for (final chunk in response.data!.stream) {
        if (cancelToken.isCancelled) {
          await sink.flush();
          await sink.close();
          _cancelTokens.remove(filename);
          return 'PAUSED';
        }
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress?.call(
            receivedBytes, expectedTotalBytes > 0 ? expectedTotalBytes : 0);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      final downloadedBytes = await tempFile.length();
      if (expectedTotalBytes > 0 && downloadedBytes < expectedTotalBytes) {
        // Incomplete stream, retry resumption from current byte
        if (attempts < maxAttempts && !cancelToken.isCancelled) {
          await Future.delayed(Duration(seconds: 1 + attempts));
          continue;
        }
        throw Exception(
          'Incomplete download ($downloadedBytes / $expectedTotalBytes bytes).',
        );
      }

      final finalFile = File(savePath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(savePath);
      _cancelTokens.remove(filename);
      return savePath;
    } on DioException catch (e) {
      if (sink != null) {
        try {
          await sink.flush();
          await sink.close();
        } catch (_) {}
      }
      if (e.type == DioExceptionType.cancel || cancelToken.isCancelled) {
        _cancelTokens.remove(filename);
        return 'PAUSED';
      }
      if (attempts < maxAttempts && !cancelToken.isCancelled) {
        // Wait and retry with resumption
        await Future.delayed(Duration(seconds: 1 + attempts));
        continue;
      }
      _cancelTokens.remove(filename);
      throw Exception('Download failed after $attempts attempts: ${e.message}');
    } catch (e) {
      if (sink != null) {
        try {
          await sink.flush();
          await sink.close();
        } catch (_) {}
      }
      if (cancelToken.isCancelled) {
        _cancelTokens.remove(filename);
        return 'PAUSED';
      }
      if (attempts < maxAttempts) {
        await Future.delayed(Duration(seconds: 1 + attempts));
        continue;
      }
      _cancelTokens.remove(filename);
      rethrow;
    }
  }

  _cancelTokens.remove(filename);
  throw Exception('Download failed after $maxAttempts attempts.');
}

void pauseDownload(String filename) {
  _cancelTokens[filename]?.cancel('paused');
}

Future<void> deleteModel(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
  final partFile = File('$path.part');
  if (await partFile.exists()) await partFile.delete();
  final tempFile = File('$path.tmp');
  if (await tempFile.exists()) await tempFile.delete();
}

// ── Native MethodChannel bridges (Android DownloadManager) ──

Future<Map<String, dynamic>?> startNativeDownload({
  required String url,
  required String filename,
  required String modelsDir,
}) async {
  if (!Platform.isAndroid) return null;
  try {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'downloadModelInApp',
      {
        'url': url,
        'filename': filename,
        'modelsDir': modelsDir,
      },
    );
    return result;
  } catch (e) {
    print('[DownloadNative] startNativeDownload failed: $e');
    rethrow;
  }
}

Future<bool> cancelNativeDownload({
  required int downloadId,
  required String filename,
}) async {
  if (!Platform.isAndroid) return false;
  try {
    final result = await _channel.invokeMethod<bool>(
      'cancelDownloadInApp',
      {
        'downloadId': downloadId,
        'filename': filename,
      },
    );
    return result ?? false;
  } catch (e) {
    print('[DownloadNative] cancelNativeDownload failed: $e');
    return false;
  }
}

Future<List<Map<String, dynamic>>> getActiveNativeDownloads() async {
  if (!Platform.isAndroid) return [];
  try {
    final List<dynamic>? result = await _channel.invokeListMethod<dynamic>('getActiveDownloads');
    if (result == null) return [];
    return result.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  } catch (e) {
    print('[DownloadNative] getActiveNativeDownloads failed: $e');
    return [];
  }
}
