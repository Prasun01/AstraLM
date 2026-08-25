import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProviderLogo extends StatelessWidget {
  final String providerId;
  final double size;
  final Color? color;

  const ProviderLogo({
    super.key,
    required this.providerId,
    this.size = 20,
    this.color,
  });

  static const Map<String, String> _logoAssets = {
    'deepseek': 'assets/logos/deepseek.png',
    'openai': 'assets/logos/openai.png',
    'anthropic': 'assets/logos/anthropic.png',
    'google': 'assets/logos/gemini.png',
    'gemini': 'assets/logos/gemini.png',
    'openrouter': 'assets/logos/openrouter.png',
    'kimi': 'assets/logos/kimi.png',
    'nvidia': 'assets/logos/nvidia.png',
    'stability': 'assets/logos/stability.png',
    'groq': 'assets/logos/groq.png',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ?? (isDark ? Colors.white : Colors.black);
    final key = providerId.toLowerCase().trim();
    final assetPath = _logoAssets[key];

    if (assetPath != null) {
      return Image.asset(
        assetPath,
        width: size,
        height: size,
        color: effectiveColor,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => PhosphorIcon(
          PhosphorIconsBold.sparkle,
          size: size,
          color: effectiveColor,
        ),
      );
    }

    // Fallback icon for custom or unknown providers
    return PhosphorIcon(
      PhosphorIconsBold.cloud,
      size: size,
      color: effectiveColor,
    );
  }
}
