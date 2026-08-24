import 'package:get/get.dart';

import 'device_info_native.dart' if (dart.library.html) 'device_info_web.dart'
    as platform_info;

/// Device capability detection — reads RAM to set safe inference limits.
/// Cross-platform: works on Android/iOS natively, defaults on web.
class DeviceInfoService extends GetxService {
  final totalRamGB = 0.0.obs;
  final availableRamGB = 0.0.obs;
  final deviceTier = ''.obs; // 'low', 'mid', 'high', 'ultra'
  final isTensorSoC = false.obs;
  final socFamily = platform_info.SocFamily.unknown.obs;
  final socHardware = ''.obs;

  // Recommended limits based on device RAM
  int get recommendedContextSize => _tierConfig['contextSize']!;
  int get recommendedMaxTokens => _tierConfig['maxTokens']!;
  int get maxSafeContextSize => _tierConfig['maxContextSize']!;
  int get maxSafeTokens => _tierConfig['maxSafeTokens']!;

  Map<String, int> get _tierConfig {
    final ram = totalRamGB.value;
    if (ram <= 4) {
      return {
        'contextSize': 1024,
        'maxTokens': 256,
        'maxContextSize': 2048,
        'maxSafeTokens': 512,
      };
    } else if (ram <= 6) {
      return {
        'contextSize': 2048,
        'maxTokens': 512,
        'maxContextSize': 4096,
        'maxSafeTokens': 1024,
      };
    } else if (ram <= 8) {
      return {
        'contextSize': 4096,
        'maxTokens': 1024,
        'maxContextSize': 8192,
        'maxSafeTokens': 2048,
      };
    } else if (ram <= 12) {
      return {
        'contextSize': 4096,
        'maxTokens': 2048,
        'maxContextSize': 8192,
        'maxSafeTokens': 4096,
      };
    } else {
      return {
        'contextSize': 8192,
        'maxTokens': 4096,
        'maxContextSize': 16384,
        'maxSafeTokens': 4096,
      };
    }
  }

  Future<DeviceInfoService> init() async {
    await refreshMemoryInfo();

    // Classify device tier
    final ram = totalRamGB.value;
    if (ram <= 4) {
      deviceTier.value = 'low';
    } else if (ram <= 6) {
      deviceTier.value = 'mid';
    } else if (ram <= 8) {
      deviceTier.value = 'high';
    } else {
      deviceTier.value = 'ultra';
    }

    print('[DeviceInfo] RAM: ${totalRamGB.value.toStringAsFixed(1)}GB total, '
        '${availableRamGB.value.toStringAsFixed(1)}GB available, '
        'tier: ${deviceTier.value}, tensor: ${isTensorSoC.value}');
    return this;
  }

  Future<void> refreshMemoryInfo() async {
    final info = await platform_info.getDeviceInfo();
    totalRamGB.value = (info['totalRamGB'] as num).toDouble();
    availableRamGB.value = (info['availableRamGB'] as num).toDouble();
    isTensorSoC.value = (info['isTensorSoC'] as num? ?? 0.0) > 0.5;
    final rawIndex = (info['socFamily'] as num? ?? 8).toInt();
    final clamped = rawIndex < 0 ? 0 : (rawIndex > 8 ? 8 : rawIndex);
    socFamily.value = platform_info.SocFamily.values[clamped];
    socHardware.value = (info['socHardware'] as String?) ?? '';
  }

  String get tierDescription {
    switch (deviceTier.value) {
      case 'low':
        return 'Low RAM (${totalRamGB.value.toStringAsFixed(1)}GB) — Use small models only';
      case 'mid':
        return 'Mid-range (${totalRamGB.value.toStringAsFixed(1)}GB) — Good for 1-3B models';
      case 'high':
        return 'High-end (${totalRamGB.value.toStringAsFixed(1)}GB) — Can run 3-7B models';
      case 'ultra':
        return 'Ultra (${totalRamGB.value.toStringAsFixed(1)}GB) — Full performance mode';
      default:
        return '${totalRamGB.value.toStringAsFixed(1)}GB RAM detected';
    }
  }

  /// Dynamically computes the optimal, crash-resilient context size and max tokens
  /// tailored specifically to the model's parameter class, thinking/reasoning needs,
  /// and the device's real-time hardware capabilities.
  HardwareOptimizationResult calculateOptimalParameters({
    required String modelName,
    int? modelSizeBytes,
    required String runtime,
  }) {
    final lowerName = modelName.toLowerCase();
    final isLiteRt = runtime.toLowerCase() == 'litert';
    final ram = totalRamGB.value;

    // Detect if this is a reasoning / thinking model (e.g. DeepSeek-R1, QwQ, etc.)
    final isThinking = lowerName.contains('deepseek-r1') ||
        lowerName.contains('deepseek_r1') ||
        lowerName.contains('qwq');

    // Detect model parameter weight tier
    final bool isSmall = lowerName.contains('0.5b') ||
        lowerName.contains('0.6b') ||
        lowerName.contains('1b') ||
        lowerName.contains('1.1b') ||
        lowerName.contains('1.5b') ||
        lowerName.contains('1.7b') ||
        lowerName.contains('2b');

    final bool isMid = lowerName.contains('3b') ||
        lowerName.contains('3.2b') ||
        lowerName.contains('3.5b') ||
        lowerName.contains('3.8b') ||
        lowerName.contains('4b');

    final bool isLarge = lowerName.contains('7b') ||
        lowerName.contains('8b') ||
        lowerName.contains('14b') ||
        lowerName.contains('16b') ||
        (modelSizeBytes != null && modelSizeBytes > 3500 * 1024 * 1024);

    int contextSize;
    int maxTokens;
    String modelTier;

    if (isSmall) {
      modelTier = '1.5B–2B Ultra-Fast';
      if (ram <= 4) {
        contextSize = 2048;
        maxTokens = isThinking ? 1280 : 512;
      } else if (ram <= 6) {
        contextSize = 4096;
        maxTokens = isThinking ? 2048 : 1024;
      } else {
        contextSize = isLiteRt ? 4096 : 8192;
        maxTokens = isThinking ? 3072 : 1536;
      }
    } else if (isMid) {
      modelTier = '3B–4B Balanced';
      if (ram <= 4) {
        contextSize = 1024;
        maxTokens = isThinking ? 768 : 384;
      } else if (ram <= 6) {
        contextSize = 2048;
        maxTokens = isThinking ? 1536 : 768;
      } else if (ram <= 8) {
        contextSize = 4096;
        maxTokens = isThinking ? 2560 : 1024;
      } else {
        contextSize = isLiteRt ? 4096 : 8192;
        maxTokens = isThinking ? 3072 : 2048;
      }
    } else if (isLarge) {
      modelTier = '7B–8B Heavyweight';
      if (ram <= 4) {
        // Warning: Very tight RAM for 7B on 4GB device
        contextSize = 1024;
        maxTokens = isThinking ? 512 : 256;
      } else if (ram <= 6) {
        contextSize = 1536;
        maxTokens = isThinking ? 1024 : 512;
      } else if (ram <= 8) {
        contextSize = 2048;
        maxTokens = isThinking ? 1536 : 768;
      } else {
        contextSize = isLiteRt ? 4096 : 4096;
        maxTokens = isThinking ? 2560 : 1536;
      }
    } else {
      // General fallback based purely on device RAM
      modelTier = 'General Model';
      if (ram <= 4) {
        contextSize = 1024;
        maxTokens = isThinking ? 768 : 384;
      } else if (ram <= 6) {
        contextSize = 2048;
        maxTokens = isThinking ? 1536 : 768;
      } else {
        contextSize = 4096;
        maxTokens = isThinking ? 2048 : 1024;
      }
    }

    final bool isGemma = lowerName.contains('gemma');
    final bool isMaliOrExynos = socFamily.value == platform_info.SocFamily.exynos ||
        socHardware.value.toLowerCase().contains('mali') ||
        socHardware.value.toLowerCase().contains('exynos') ||
        socHardware.value.toLowerCase().contains('s5e8835') ||
        socHardware.value.toLowerCase().contains('s5e8845');

    if (isLiteRt) {
      if (isGemma || isMaliOrExynos) {
        contextSize = contextSize.clamp(512, 2048);
        if (ram <= 8 && isGemma) {
          contextSize = contextSize.clamp(512, 1536);
        }
      } else {
        contextSize = contextSize.clamp(512, 4096);
      }
    }

    // Ensure maxTokens never exceeds contextSize - 256 (leaving space for prompt & history)
    if (maxTokens > contextSize - 256) {
      maxTokens = (contextSize - 256).clamp(128, contextSize);
    }

    final reason = isThinking
        ? 'Allocated $maxTokens token reasoning budget for thought chains (<think> tags).'
        : 'Optimized for high-speed response with ${totalRamGB.value.toStringAsFixed(0)}GB RAM.';

    return HardwareOptimizationResult(
      optimalContextSize: contextSize,
      optimalMaxTokens: maxTokens,
      isThinkingModel: isThinking,
      explanation: reason,
      modelTier: modelTier,
    );
  }
}

class HardwareOptimizationResult {
  final int optimalContextSize;
  final int optimalMaxTokens;
  final bool isThinkingModel;
  final String explanation;
  final String modelTier;

  const HardwareOptimizationResult({
    required this.optimalContextSize,
    required this.optimalMaxTokens,
    required this.isThinkingModel,
    required this.explanation,
    required this.modelTier,
  });
}
