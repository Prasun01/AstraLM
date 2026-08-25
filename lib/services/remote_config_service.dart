import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'app_log_service.dart';

class RemoteConfigService extends GetxService {
  static const String configUrl =
      'https://raw.githubusercontent.com/Prasun01/AstraLM/main/app_config.json';

  // Observable remote configs
  final isLoaded = false.obs;
  final backgroundAppsWarningEnabled = true.obs;
  final backgroundAppsWarningText =
      'Multiple background apps detected. Close background apps to free RAM for faster inference ⚡'.obs;
  final lowRamThresholdGB = 2.0.obs;
  final remoteThinkingMessages = <String>[].obs;
  final announcement = ''.obs;

  Box? _box;

  Future<RemoteConfigService> init() async {
    try {
      _box = await Hive.openBox('remote_config_box');
      _loadCachedConfig();
    } catch (_) {}

    // Silently fetch remote config in background
    unawaited(fetchRemoteConfig());
    return this;
  }

  void _loadCachedConfig() {
    if (_box == null) return;
    try {
      backgroundAppsWarningEnabled.value =
          _box!.get('bg_warning_enabled', defaultValue: true) as bool;
      backgroundAppsWarningText.value = _box!.get('bg_warning_text',
          defaultValue:
              'Multiple background apps detected. Close background apps to free RAM for faster inference ⚡') as String;
      lowRamThresholdGB.value =
          (_box!.get('low_ram_threshold', defaultValue: 2.0) as num).toDouble();
      announcement.value = _box!.get('announcement', defaultValue: '') as String;
      final cachedThinking = _box!.get('thinking_messages') as List<dynamic>?;
      if (cachedThinking != null && cachedThinking.isNotEmpty) {
        remoteThinkingMessages.value = cachedThinking.map((e) => e.toString()).toList();
      }
      isLoaded.value = true;
    } catch (_) {}
  }

  Future<void> fetchRemoteConfig() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));

      final response = await dio.get(configUrl);
      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> data = response.data is String
            ? jsonDecode(response.data as String)
            : Map<String, dynamic>.from(response.data as Map);

        if (data.containsKey('background_apps_warning_enabled')) {
          backgroundAppsWarningEnabled.value =
              data['background_apps_warning_enabled'] as bool;
          _box?.put('bg_warning_enabled', backgroundAppsWarningEnabled.value);
        }

        if (data.containsKey('background_apps_warning_text')) {
          backgroundAppsWarningText.value =
              data['background_apps_warning_text'].toString();
          _box?.put('bg_warning_text', backgroundAppsWarningText.value);
        }

        if (data.containsKey('low_ram_threshold_gb')) {
          lowRamThresholdGB.value =
              (data['low_ram_threshold_gb'] as num).toDouble();
          _box?.put('low_ram_threshold', lowRamThresholdGB.value);
        }

        if (data.containsKey('announcement')) {
          announcement.value = data['announcement'].toString();
          _box?.put('announcement', announcement.value);
        }

        if (data.containsKey('thinking_messages')) {
          final list = (data['thinking_messages'] as List<dynamic>)
              .map((e) => e.toString())
              .toList();
          remoteThinkingMessages.value = list;
          _box?.put('thinking_messages', list);
        }

        isLoaded.value = true;
      }
    } catch (e) {
      if (Get.isRegistered<AppLogService>()) {
        Get.find<AppLogService>()
            .info('[RemoteConfig] Using local defaults, fetch skipped: $e');
      }
    }
  }
}
