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
  final processorCount = 4.obs;

  // Recommended limits based on device RAM
  int get recommendedContextSize => _tierConfig['contextSize']!;
  int get recommendedMaxTokens => _tierConfig['maxTokens']!;
  int get maxSafeContextSize => _tierConfig['maxContextSize']!;
  int get maxSafeTokens => _tierConfig['maxSafeTokens']!;

  /// Dynamically computes optimal thread count for LLM inference on modern ARM big.LITTLE CPUs.
  /// Uses 4 to 6 threads for big performance/prime cores while avoiding slow LITTLE efficiency cores.
  int get optimalInferenceThreads {
    final cores = processorCount.value > 0 ? processorCount.value : 8;
    final tier = deviceTier.value;
    final family = socFamily.value;

    if (cores >= 8) {
      // Modern 8-core mobile chips (Snapdragon 8 Gen 1/2/3, Dimensity, Tensor, Exynos)
      // Usually have 1 Prime + 3-4 Big + 3-4 Little cores.
      // 4-6 threads give peak matrix multiplication speed without thermal throttling.
      if (tier == 'ultra' || tier == 'high') {
        if (family == platform_info.SocFamily.snapdragon ||
            family == platform_info.SocFamily.mediatek ||
            family == platform_info.SocFamily.apple) {
          return 6;
        }
        return 4;
      }
      return 4;
    } else if (cores >= 6) {
      return 4;
    } else if (cores >= 4) {
      return (tier == 'low') ? 3 : 4;
    } else {
      return cores.clamp(1, 2);
    }
  }

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
        'cores: ${processorCount.value} (optimal threads: $optimalInferenceThreads), '
        'tier: ${deviceTier.value}, tensor: ${isTensorSoC.value}');
    return this;
  }

  Future<void> refreshMemoryInfo() async {
    final info = await platform_info.getDeviceInfo();
    totalRamGB.value = (info['totalRamGB'] as num).toDouble();
    availableRamGB.value = (info['availableRamGB'] as num).toDouble();
    isTensorSoC.value = (info['isTensorSoC'] as num? ?? 0.0) > 0.5;
    processorCount.value = (info['processorCount'] as num? ?? 4).toInt();
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

  /// Evaluates whether the device has sufficient RAM to load and execute the model safely
  /// without triggering the Android Low Memory Killer (LMK) or native SIGABRT / OOM crash.
  RamSafetyEvaluation evaluateModelRamSafety({
    required int modelSizeBytes,
    int? contextSize,
    required String runtime,
  }) {
    final isLiteRt = runtime.toLowerCase() == 'litert';
    final isSd = runtime.toLowerCase() == 'sd';
    final ctx = contextSize ?? recommendedContextSize;

    final double estimatedRequiredBytes;
    if (isSd) {
      estimatedRequiredBytes = modelSizeBytes + 1200.0 * 1024 * 1024;
    } else if (isLiteRt) {
      final kvBuffer = ctx * 120.0 * 1024; // ~120KB per context token (~480MB for 4k ctx)
      estimatedRequiredBytes = modelSizeBytes + kvBuffer + 250.0 * 1024 * 1024;
    } else {
      final kvBuffer = ctx * 150.0 * 1024; // ~150KB per context token for GGUF (~600MB for 4k ctx)
      estimatedRequiredBytes = modelSizeBytes + kvBuffer + 250.0 * 1024 * 1024;
    }

    final totalBytes = (totalRamGB.value * 1024 * 1024 * 1024).round();
    final availBytes = (availableRamGB.value * 1024 * 1024 * 1024).round();
    final reqBytes = estimatedRequiredBytes.round();

    // Critical checks:
    // 1. Total device RAM is simply insufficient (e.g. 7B model on a 4GB RAM phone)
    final bool isTotalRamTooSmall =
        totalBytes > 0 && reqBytes > (totalBytes * 0.85).round();

    // 2. Currently available RAM is critically low right now (< required bytes or < 300MB headroom)
    final bool isCriticallyLow = availBytes > 0 &&
        (reqBytes > availBytes || (availBytes - reqBytes) < 300 * 1024 * 1024);

    // 3. Tight RAM (< 600MB headroom)
    final bool isTight = availBytes > 0 &&
        !isCriticallyLow &&
        (availBytes - reqBytes) < 600 * 1024 * 1024;

    final String warning;
    final String recommendation;

    if (isTotalRamTooSmall) {
      warning =
          'This model requires approximately ${(reqBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB RAM, which exceeds your device\'s total capacity (${totalRamGB.value.toStringAsFixed(1)} GB).';
      recommendation =
          'Choose a smaller 1B–3B model (e.g. SmolLM2, Qwen 0.5B/1.5B, or Llama 3.2 1B).';
    } else if (isCriticallyLow) {
      warning =
          'Available RAM (${(availBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB) is below the recommended ${(reqBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB.';
      recommendation =
          'Restarting the app or closing background apps will free up memory before loading.';
    } else if (isTight) {
      warning =
          'Memory headroom is tight. The app will auto-tune context size to prevent background eviction.';
      recommendation = 'Proceed with hardware-calibrated context.';
    } else {
      warning = '';
      recommendation = 'Device memory is optimal for this model.';
    }

    return RamSafetyEvaluation(
      requiredBytes: reqBytes,
      availableBytes: availBytes,
      totalBytes: totalBytes,
      isSafe: !isTotalRamTooSmall && !isCriticallyLow,
      isCriticallyLow: isCriticallyLow,
      isTight: isTight,
      isTotalRamTooSmall: isTotalRamTooSmall,
      recommendRestart: isCriticallyLow && !isTotalRamTooSmall,
      warningMessage: warning,
      recommendation: recommendation,
    );
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
        lowerName.contains('9b') ||
        lowerName.contains('14b') ||
        lowerName.contains('16b') ||
        (modelSizeBytes != null && modelSizeBytes > 3500 * 1024 * 1024);

    int contextSize;
    int maxTokens;
    String modelTier;

    if (isSmall) {
      modelTier = '1.5B–2.6B Ultra-Fast';
      if (ram <= 4) {
        contextSize = 1536;
        maxTokens = isThinking ? 1024 : 512;
      } else if (ram <= 6) {
        contextSize = 2048;
        maxTokens = isThinking ? 2048 : 1024;
      } else {
        contextSize = isLiteRt ? 4096 : 2048;
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
        contextSize = 2048;
        maxTokens = isThinking ? 2560 : 1024;
      } else {
        contextSize = isLiteRt ? 4096 : 2048;
        maxTokens = isThinking ? 3072 : 2048;
      }
    } else if (isLarge) {
      modelTier = '7B–9B Heavyweight';
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

class RamSafetyEvaluation {
  final int requiredBytes;
  final int availableBytes;
  final int totalBytes;
  final bool isSafe;
  final bool isCriticallyLow;
  final bool isTight;
  final bool isTotalRamTooSmall;
  final bool recommendRestart;
  final String warningMessage;
  final String recommendation;

  const RamSafetyEvaluation({
    required this.requiredBytes,
    required this.availableBytes,
    required this.totalBytes,
    required this.isSafe,
    required this.isCriticallyLow,
    required this.isTight,
    required this.isTotalRamTooSmall,
    required this.recommendRestart,
    required this.warningMessage,
    required this.recommendation,
  });

  String get requiredMbFormatted =>
      (requiredBytes / (1024 * 1024)).toStringAsFixed(0);
  String get availableMbFormatted =>
      (availableBytes / (1024 * 1024)).toStringAsFixed(0);
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
