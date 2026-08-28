import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class ModelDownloadNotificationService {
  static const int _baseNotificationId = 5100;
  static const String _channelId = 'model_download_progress';
  static const String _channelName = 'Model downloads';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final Map<String, int> _modelNotificationIds = {};
  int _nextId = 0;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings);
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'Live progress updates for AI model downloads',
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          ),
        );
    _initialized = true;
  }

  Future<void> ensurePermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await Permission.notification.request();
    } catch (_) {}
  }

  int _getId(String filename) {
    return _modelNotificationIds.putIfAbsent(
        filename, () => _baseNotificationId + (_nextId++ % 50));
  }

  Future<void> showProgress({
    required String filename,
    required String modelName,
    required int downloadedBytes,
    required int totalBytes,
    required double bytesPerSecond,
    Duration? eta,
  }) async {
    if (!Platform.isAndroid) return;
    await init();
    final id = _getId(filename);

    final percent = totalBytes > 0
        ? ((downloadedBytes / totalBytes) * 100).clamp(0, 100).round()
        : 0;

    final speedMb = (bytesPerSecond / (1024 * 1024)).toStringAsFixed(1);
    final downloadedStr = _formatBytes(downloadedBytes);
    final totalStr = totalBytes > 0 ? _formatBytes(totalBytes) : 'Unknown';

    var body = '$downloadedStr / $totalStr ($speedMb MB/s)';
    if (eta != null && eta.inSeconds > 0) {
      body += ' · ~${_formatEta(eta.inSeconds)} left';
    }

    try {
      await _notifications.show(
        id,
        'Downloading $modelName ($percent%)',
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Live progress updates for AI model downloads',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            showProgress: true,
            maxProgress: totalBytes > 0 ? 100 : 0,
            progress: percent,
            indeterminate: totalBytes <= 0,
            color: const Color(0xFF3B82F6),
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> showComplete({
    required String filename,
    required String modelName,
    required int totalBytes,
  }) async {
    if (!Platform.isAndroid) return;
    await init();
    final id = _getId(filename);

    try {
      await _notifications.show(
        id,
        '$modelName Ready',
        'Download complete (${_formatBytes(totalBytes)}). Model verified.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Live progress updates for AI model downloads',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            autoCancel: true,
            onlyAlertOnce: true,
          ),
        ),
      );
    } catch (_) {}
    _modelNotificationIds.remove(filename);
  }

  Future<void> showError({
    required String filename,
    required String modelName,
    required String error,
  }) async {
    if (!Platform.isAndroid) return;
    await init();
    final id = _getId(filename);

    try {
      await _notifications.show(
        id,
        'Download Interrupted: $modelName',
        error,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Live progress updates for AI model downloads',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            autoCancel: true,
          ),
        ),
      );
    } catch (_) {}
    _modelNotificationIds.remove(filename);
  }

  Future<void> cancel(String filename) async {
    if (!Platform.isAndroid) return;
    final id = _modelNotificationIds[filename];
    if (id != null) {
      try {
        await _notifications.cancel(id);
      } catch (_) {}
      _modelNotificationIds.remove(filename);
    }
  }

  Future<void> cancelAll() async {
    if (!Platform.isAndroid) return;
    try {
      await _notifications.cancelAll();
    } catch (_) {}
    _modelNotificationIds.clear();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatEta(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    if (minutes < 60) {
      return rest == 0 ? '${minutes}m' : '${minutes}m ${rest}s';
    }
    final hours = minutes ~/ 60;
    final remMin = minutes % 60;
    return remMin == 0 ? '${hours}h' : '${hours}h ${remMin}m';
  }
}
