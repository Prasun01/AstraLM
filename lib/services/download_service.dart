import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../controllers/model_controller.dart';

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

  void updateProgress({required int downloaded, required int total, double? nativeSpeed, String? status}) {
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
      if (elapsedSec >= 0.5 && downloaded >= _lastBytes) {
        final instantSpeed = (downloaded - _lastBytes) / elapsedSec;
        _smoothedSpeed = _smoothedSpeed <= 0
            ? instantSpeed
            : (0.7 * _smoothedSpeed + 0.3 * instantSpeed);
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

/// Service for downloading GGUF model files with progress tracking.
class DownloadService extends GetxService with WidgetsBindingObserver {
  /// Currently active downloads.
  final activeDownloads = <String, DownloadProgress>{}.obs;
  final _nativeDownloadIds = <String, int>{};

  bool get isDownloadingAny => activeDownloads.isNotEmpty;

  /// Whether the platform supports downloading models.
  bool get supportsDownload => !kIsWeb;

  Future<String> get modelsDir async => await platform_dl.getModelsDir();

  Future<String> modelPath(String filename) async {
    final dir = await modelsDir;
    final internalPath = '$dir/$filename';
    if (await File(internalPath).exists()) {
      return internalPath;
    }
    if (!kIsWeb && Platform.isAndroid) {
      // Check app's external files dir
      final extFilesDir = '/storage/emulated/0/Android/data/com.prasun01.astralm/files/Download/$filename';
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

    if (!kIsWeb && Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);

      // Initial reconciliation on startup
      reconcileActiveDownloads();

      // Permanent channel progress listener
      const MethodChannel('com.prasun01.astralm/model_import')
          .setMethodCallHandler((call) async {
        if (call.method == 'importProgress') {
          final data = Map<String, dynamic>.from(call.arguments as Map);
          final filename = data['filename'] as String;
          final downloaded = (data['copiedBytes'] as num).toInt();
          final total = (data['totalBytes'] as num).toInt();
          final speed = (data['bytesPerSecond'] as num).toDouble();
          final status = data['status'] as String;

          var progress = activeDownloads[filename];
          if (progress == null &&
              (status == 'Downloading...' ||
                  status == 'Downloading to phone...' ||
                  status.startsWith('Starting') ||
                  status.startsWith('Importing'))) {
            progress = DownloadProgress(filename: filename);
            activeDownloads[filename] = progress;
          }
          if (progress != null) {
            progress.updateProgress(
              downloaded: downloaded,
              total: total,
              nativeSpeed: speed > 0 ? speed : null,
              status: status,
            );

            if (status == 'Download complete') {
              activeDownloads.remove(filename);
              _nativeDownloadIds.remove(filename);
              try {
                Get.find<ModelController>().refreshDownloaded();
              } catch (_) {}
            } else if (status.startsWith('Download failed') ||
                status == 'Download cancelled') {
              activeDownloads.remove(filename);
              _nativeDownloadIds.remove(filename);
            }
          }

          // Also update ModelController import state in real-time if it is currently importing
          try {
            final modelCtrl = Get.find<ModelController>();
            if (modelCtrl.isImporting.value) {
              final isPhoneDownload =
                  modelCtrl.importStatus.value.contains('phone') ||
                      modelCtrl.importStatus.value.contains('Starting');

              modelCtrl.importFileName.value = filename;
              modelCtrl.importStatus.value = status;
              modelCtrl.importCopiedBytes.value = downloaded;
              modelCtrl.importTotalBytes.value = total;
              modelCtrl.importBytesPerSecond.value = speed;

              if (status == 'Download complete' ||
                  status.startsWith('Download failed') ||
                  status == 'Download cancelled') {
                if (status == 'Download complete' && isPhoneDownload) {
                  Get.snackbar(
                    'Saved to Downloads',
                    'Model downloaded and ready to use.',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 4),
                  );
                }
                Future.delayed(const Duration(seconds: 2), () {
                  if (modelCtrl.importStatus.value == status) {
                    modelCtrl.isImporting.value = false;
                    modelCtrl.importFileName.value = '';
                    modelCtrl.importStatus.value = '';
                  }
                });
              }
            }
          } catch (_) {}
        }
        return null;
      });
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

  Future<void> reconcileActiveDownloads() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final list = await platform_dl.getActiveNativeDownloads();
      final recoveredFilenames = <String>{};
      for (final item in list) {
        final id = item['downloadId'] as int;
        final filename = item['filename'] as String;
        final downloaded = item['downloaded'] as int;
        final total = item['total'] as int;
        final status = item['status'] as String;
        recoveredFilenames.add(filename);

        _nativeDownloadIds[filename] = id;

        final progress =
            activeDownloads[filename] ?? DownloadProgress(filename: filename);
        progress.updateProgress(
          downloaded: downloaded,
          total: total,
          status: status,
        );
        progress.isPaused.value = status == 'Paused';
        if (!activeDownloads.containsKey(filename)) {
          activeDownloads[filename] = progress;
        }
      }

      // Remove UI entries whose native DownloadManager jobs no longer exist.
      final staleFilenames = _nativeDownloadIds.keys
          .where((filename) => !recoveredFilenames.contains(filename))
          .toList();
      for (final filename in staleFilenames) {
        _nativeDownloadIds.remove(filename);
        activeDownloads.remove(filename);
      }

      // Trigger refresh of downloaded models in case one finished in background
      try {
        Get.find<ModelController>().refreshDownloaded();
      } catch (_) {}
    } catch (e) {
      print('[DownloadService] Failed to reconcile active downloads: $e');
    }
  }

  Future<String> downloadModel({
    required String url,
    required String filename,
    String? authToken,
  }) async {
    if (kIsWeb) return 'ERROR: Downloading models is not supported on web.';

    final downloadProgress = DownloadProgress(filename: filename);
    activeDownloads[filename] = downloadProgress;

    if (Platform.isAndroid) {
      try {
        final modelsDirectory = await modelsDir;
        final result = await platform_dl.startNativeDownload(
          url: url,
          filename: filename,
          modelsDir: modelsDirectory,
        );
        if (result != null) {
          final id = result['downloadId'] as int;
          _nativeDownloadIds[filename] = id;
          return 'NATIVE_BACKGROUND_STARTED';
        }
      } catch (e) {
        print('[DownloadService] Native background download start failed, falling back to resumable Dio: $e');
      }
    }

    // Fallback: Resumable chunked in-app download
    final savePath = await modelPath(filename);
    try {
      final result = await platform_dl.downloadModel(
        url: url,
        savePath: savePath,
        authToken: authToken,
        onProgress: (received, total) {
          downloadProgress.updateProgress(
            downloaded: received,
            total: total,
          );
        },
      );
      activeDownloads.remove(filename);
      return result;
    } catch (e) {
      activeDownloads.remove(filename);
      rethrow;
    }
  }

  void pauseDownload(String filename) {
    final nativeId = _nativeDownloadIds[filename];
    if (nativeId != null && Platform.isAndroid) {
      platform_dl.cancelNativeDownload(
          downloadId: nativeId, filename: filename);
      activeDownloads.remove(filename);
      _nativeDownloadIds.remove(filename);
    } else {
      platform_dl.pauseDownload(filename);
      activeDownloads.remove(filename);
    }
  }

  Future<void> deleteModel(String filename) async {
    if (kIsWeb) return;
    final nativeId = _nativeDownloadIds[filename];
    if (nativeId != null && Platform.isAndroid) {
      await platform_dl.cancelNativeDownload(
          downloadId: nativeId, filename: filename);
      _nativeDownloadIds.remove(filename);
    }
    await platform_dl.deleteModel(await modelPath(filename));
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

  static String formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0 || bytesPerSecond.isNaN || bytesPerSecond.isInfinite) {
      return '0 KB/s';
    }
    return '${formatBytes(bytesPerSecond.round())}/s';
  }

  static String formatDuration(Duration? duration) {
    if (duration == null || duration.isNegative) return '--';
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    }
    return '${duration.inSeconds}s';
  }
}
