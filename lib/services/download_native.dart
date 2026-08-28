import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'chunked_downloader.dart';

final ChunkedDownloader _downloader = ChunkedDownloader();
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
  final probe = await _downloader.probeRemoteFile(url, authToken: authToken);
  return probe['size'] as int? ?? 0;
}

Future<String> downloadModel({
  required String url,
  required String savePath,
  String? authToken,
  void Function(int received, int total, double bytesPerSecond)? onProgress,
}) async {
  return await _downloader.startDownload(
    url: url,
    savePath: savePath,
    authToken: authToken,
    onProgress: (received, total, speed) {
      onProgress?.call(received, total, speed);
    },
  );
}

void pauseDownload(String filename) {
  _downloader.cancelDownload(filename);
}

Future<void> deleteModel(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
  final partFile = File('$path.part');
  if (await partFile.exists()) {
    try {
      await partFile.delete();
    } catch (_) {}
  }
  final metaFile = File('$path.part.meta');
  if (await metaFile.exists()) {
    try {
      await metaFile.delete();
    } catch (_) {}
  }
}

Future<Map<String, dynamic>?> startNativeDownload({
  required String url,
  required String filename,
  required String modelsDir,
}) async {
  return null;
}

Future<void> cancelNativeDownload({
  required int downloadId,
  required String filename,
}) async {
  pauseDownload(filename);
}
