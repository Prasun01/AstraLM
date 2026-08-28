import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../controllers/model_controller.dart';
import 'model_download_notification_service.dart';

import 'download_native.dart' if (dart.library.html) 'download_web.dart'
    as platform_dl;

/// State for an individual download with smoothed metrics.
class DownloadProgress {
  final String filename;
  final RxDouble progress = 0.0.obs;
  final RxInt downloadedBytes = 0.obs;
  final RxInt totalBytes = 0.obs;
  final RxDouble bytesPerSecond = 0.0.obs;
  final RxBool isPaused = false.obs;
  final RxString statusMessage = 'Downloading...'.obs;
  final DateTime startedAt = DateTime.now();

  int _lastBytes = 0;
  DateTime _lastTime = DateTime.now();
  double _smoothedSpeed = 0.0;

  DownloadProgress({required this.filename});

  void updateProgress({
    required int downloaded,
    required int total,
    double? nativeSpeed,
    String? status,
  }) {
    downloadedBytes.value = downloaded;
    if (total > 0) {
      totalBytes.value = total;
      progress.value = (downloaded / total).clamp(0.0, 1.0);
    }
    if (status != null && status.isNotEmpty) {
      statusMessage.value = status;
    }

    if (nativeSpeed != null && nativeSpeed > 0) {
      bytesPerSecond.value = nativeSpeed;
      _smoothedSpeed = nativeSpeed;
    } else {
      final now = DateTime.now();
      final elapsedSec = now.difference(_lastTime).inMilliseconds / 1000.0;
      if (elapsedSec >= 0.25 && downloaded >= _lastBytes) {
        final instantSpeed = (downloaded - _lastBytes) / elapsedSec;
        _smoothedSpeed = _smoothedSpeed <= 0
            ? instantSpeed
            : (0.75 * _smoothedSpeed + 0.25 * instantSpeed);
        bytesPerSecond.value = _smoothedSpeed;
        _lastBytes = downloaded;
        _lastTime = now;
      }
    }
  }

  Duration? get eta {
    final speed = bytesPerSecond.value;
    final total = totalBytes.value;
    final downloaded = downloadedBytes.value;
    if (speed <= 1024 || total <= 0 || downloaded >= total) return null;
    final remaining = total - downloaded;
    if (remaining <= 0) return Duration.zero;
    final seconds = (remaining / speed).round();
    if (seconds <= 0 || seconds > 86400 * 7) return null;
    return Duration(seconds: seconds);
  }
}

/// Service for downloading GGUF model files with parallel streaming and persistence.
class DownloadService extends GetxService with WidgetsBindingObserver {
  final activeDownloads = <String, DownloadProgress>{}.obs;
  final ModelDownloadNotificationService _notifService =
      ModelDownloadNotificationService();

  bool get isDownloadingAny => activeDownloads.isNotEmpty;
  bool get supportsDownload => !kIsWeb;

  Future<String> get modelsDir async => await platform_dl.getModelsDir();

  Future<String> modelPath(String filename) async {
    final dir = await modelsDir;
    final internalPath = '$dir/$filename';
    if (await File(internalPath).exists()) {
      return internalPath;
    }
    if (!kIsWeb && Platform.isAndroid) {
      final extFilesDir =
          '/storage/emulated/0/Android/data/com.prasun01.astralm/files/Download/$filename';
      if (await File(extFilesDir).exists()) {
        return extFilesDir;
      }
      final dlPath1 = '/storage/emulated/0/Download/$filename';
      if (await File(dlPath1).exists()) {
        return dlPath1;
      }
      final dlPath2 = '/sdcard/Download/$filename';
      if (await File(dlPath2).exists()) {
        return dlPath2;
      }
    }
    return internalPath;
  }

  Future<bool> isModelDownloaded(String filename) async {
    if (kIsWeb) return false;
    final path = await modelPath(filename);
    return await platform_dl.isModelDownloaded(path);
  }

  Future<List<String>> getDownloadedModels() async {
    if (kIsWeb) return [];
    return await platform_dl.getDownloadedModels(await modelsDir);
  }

  Future<int> getModelSize(String filename) async {
    if (kIsWeb) return 0;
    return await platform_dl.getModelSize(await modelPath(filename));
  }

  Future<int> getRemoteFileSize(String url, {String? authToken}) async {
    if (kIsWeb) return 0;
    return await platform_dl.getRemoteFileSize(url, authToken: authToken);
  }

  @override
  void onInit() {
    super.onInit();
    _notifService.init();

    if (!kIsWeb && Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);
      reconcileActiveDownloads();
    }
  }

  @override
  void onClose() {
    if (!kIsWeb && Platform.isAndroid) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      reconcileActiveDownloads();
    }
  }

  /// Scans for unfinished downloads (.part.meta) and restores their progress state
  Future<void> reconcileActiveDownloads() async {
    if (kIsWeb) return;
    try {
      final dirPath = await modelsDir;
      final dir = Directory(dirPath);
      if (!await dir.exists()) return;

      for (final entity in dir.listSync()) {
        if (entity is File && entity.path.endsWith('.part.meta')) {
          try {
            final content = await entity.readAsString();
            final meta = jsonDecode(content) as Map<String, dynamic>;
            final savePath = meta['savePath'] as String? ?? '';
            final filename = savePath.split('/').last;
            final totalBytes = meta['totalBytes'] as int? ?? 0;
            final chunks = (meta['chunks'] as List<dynamic>?) ?? [];

            int downloadedBytes = 0;
            for (final c in chunks) {
              downloadedBytes += (c['downloadedBytes'] as int? ?? 0);
            }

            if (filename.isNotEmpty && !activeDownloads.containsKey(filename)) {
              final progress = DownloadProgress(filename: filename);
              progress.isPaused.value = true;
              progress.statusMessage.value = 'Paused (Tap to resume)';
              progress.updateProgress(
                downloaded: downloadedBytes,
                total: totalBytes,
              );
              activeDownloads[filename] = progress;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// High-speed parallel chunked download with foreground notification & verification
  Future<String> downloadModel({
    required String url,
    required String filename,
    String? authToken,
    String? modelDisplayName,
  }) async {
    if (kIsWeb) return 'ERROR: Downloading models is not supported on web.';

    final displayName = modelDisplayName ?? filename;
    final downloadProgress = activeDownloads.putIfAbsent(
      filename,
      () => DownloadProgress(filename: filename),
    );
    downloadProgress.isPaused.value = false;
    downloadProgress.statusMessage.value = 'Downloading...';
    activeDownloads[filename] = downloadProgress;

    await _notifService.ensurePermission();

    final savePath = await modelPath(filename);
    var lastNotifUpdate = DateTime.now();

    try {
      final result = await platform_dl.downloadModel(
        url: url,
        savePath: savePath,
        authToken: authToken,
        onProgress: (received, total, speed) {
          downloadProgress.updateProgress(
            downloaded: received,
            total: total,
            nativeSpeed: speed,
          );

          final now = DateTime.now();
          if (now.difference(lastNotifUpdate).inMilliseconds >= 800) {
            lastNotifUpdate = now;
            _notifService.showProgress(
              filename: filename,
              modelName: displayName,
              downloadedBytes: received,
              totalBytes: total,
              bytesPerSecond: speed,
              eta: downloadProgress.eta,
            );
          }
        },
      );

      if (result == 'PAUSED') {
        downloadProgress.isPaused.value = true;
        downloadProgress.statusMessage.value = 'Paused';
        await _notifService.cancel(filename);
        return 'PAUSED';
      }

      activeDownloads.remove(filename);
      await _notifService.showComplete(
        filename: filename,
        modelName: displayName,
        totalBytes: downloadProgress.totalBytes.value,
      );

      try {
        Get.find<ModelController>().refreshDownloaded();
      } catch (_) {}

      return result;
    } catch (e) {
      activeDownloads.remove(filename);
      final humanError = _humanizeError(e);
      await _notifService.showError(
        filename: filename,
        modelName: displayName,
        error: humanError,
      );

      Get.snackbar(
        'Download Interrupted',
        humanError,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E1014),
        colorText: const Color(0xFFFFB4AB),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
      );

      rethrow;
    }
  }

  void pauseDownload(String filename) {
    platform_dl.pauseDownload(filename);
    final progress = activeDownloads[filename];
    if (progress != null) {
      progress.isPaused.value = true;
      progress.statusMessage.value = 'Paused';
    }
    _notifService.cancel(filename);
  }

  Future<void> deleteModel(String filename) async {
    if (kIsWeb) return;
    pauseDownload(filename);
    activeDownloads.remove(filename);
    await platform_dl.deleteModel(await modelPath(filename));
    await _notifService.cancel(filename);
  }

  String _humanizeError(dynamic error) {
    final str = error.toString().toLowerCase();
    if (str.contains('no space') || str.contains('enospc') || str.contains('storage')) {
      return 'Not enough device storage. Please free up space and resume.';
    }
    if (str.contains('html or json error') || str.contains('rate limit')) {
      return 'The download server is busy or rate-limited. Retrying shortly...';
    }
    if (str.contains('socket') || str.contains('network') || str.contains('handshake') || str.contains('connection')) {
      return 'Network connection dropped. Download progress is saved.';
    }
    if (str.contains('timeout')) {
      return 'Connection timed out. Resuming from saved progress...';
    }
    return 'Download interrupted. Progress saved—tap to resume.';
  }

  static String formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '0 B/s';
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  static String formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final seconds = duration.inSeconds;
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remSec = seconds % 60;
    if (minutes < 60) {
      return '$minutes:${remSec.toString().padLeft(2, '0')}';
    }
    final hours = minutes ~/ 60;
    final remMin = minutes % 60;
    return '${hours}h ${remMin}m';
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String formatWholeMb(int bytes) {
    if (bytes <= 0) return '0 MB';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    final mb = (bytes / (1024 * 1024)).round().clamp(1, 1 << 31);
    return '$mb MB';
  }
}
