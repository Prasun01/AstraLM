import 'package:flutter/material.dart';

/// Space Gray, Black & White design-system tokens.
///
/// High-contrast, sophisticated monochrome typography & space gray surfaces:
/// - Light mode: Pure White (#FFFFFF) with Solid Black (#000000) typography.
/// - Dark mode: Pure Black (#000000) with Solid White (#FFFFFF) typography.
class AppColors {
  AppColors._();

  // ── Primary Accent (Monochrome Contrast) ──
  static const Color primary = Color(0xFF000000); // Solid Black (light mode)
  static const Color primaryDim = Color(0xFFFFFFFF); // Solid White (dark mode)
  static const Color primaryDeep = Color(0xFF1E2028);
  static const Color primaryContainerLight = Color(0xFFEAEEF4);
  static const Color primaryContainerDark = Color(0xFF22252E);
  static const Color secondary = Color(0xFF383C48);

  // ── Semantic ──
  static const Color success = Color(0xFF30D158);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color error = Color(0xFFFF453A);
  static const Color errorContainer = Color(0xFF481212);
  static const Color onErrorContainer = Color(0xFFFFD6D6);
  static const Color info = Color(0xFF64D2FF);

  // ── Light mode (Pure White Background + Solid Black Text) ──
  static const Color bgLight = Color(0xFFFFFFFF); // Pure White Canvas
  static const Color textLight = Color(0xFF000000); // Solid Black (Opposite of BG)
  static const Color textSecondaryLight = Color(0xFF2E323B); // Dark Charcoal
  static const Color textMutedLight = Color(0xFF686E7D); // Cool Slate

  // ── Dark mode (Pure Black Background + Solid White Text) ──
  static const Color bgDark = Color(0xFF050608); // Deep Space Black Canvas
  static const Color textDark = Color(0xFFFFFFFF); // Solid White (Opposite of BG)
  static const Color textSecondaryDark = Color(0xFFE2E5EE); // Crisp Silver
  static const Color textMutedDark = Color(0xFF9096A8); // Space Mist

  // ── Tonal space gray surface layers (light) ──
  static const Color surfaceLowestLight = Color(0xFFFFFFFF);
  static const Color surfaceLowLight = Color(0xFFF3F5F8);
  static const Color surfaceContainerLight = Color(0xFFE8EBF2);
  static const Color surfaceHighLight = Color(0xFFDDE1EB);
  static const Color surfaceHighestLight = Color(0xFFD0D5E1);

  // ── Tonal space gray surface layers (dark) ──
  static const Color surfaceLowestDark = Color(0xFF000000);
  static const Color surfaceLowDark = Color(0xFF101217); // Dark Space Gray
  static const Color surfaceContainerDark = Color(0xFF171920); // Mid Space Gray
  static const Color surfaceHighDark = Color(0xFF20232B); // Elevated Space Gray
  static const Color surfaceHighestDark = Color(0xFF2A2E38); // Highlight Space Gray

  // ── Outlines ──
  static const Color outlineLight = Color(0xFF828898);
  static const Color outlineVariantLight = Color(0xFFD8DDE6);
  static const Color outlineDark = Color(0xFF6E7486);
  static const Color outlineVariantDark = Color(0xFF262933);

  /// Accent color adapted to brightness.
  static Color accentOf(Brightness brightness) =>
      brightness == Brightness.dark ? primaryDim : primary;

  /// Legacy & direct aliases.
  static const Color textPrimary = textDark;
  static const Color textSecondary = textSecondaryDark;
  static const Color textMuted = textMutedDark;
  static const Color bg = bgDark;
  static const Color surface = surfaceHighDark;
  static const Color surfaceLight = surfaceHighestDark;
  static const Color card = surfaceContainerDark;
  static const Color border = outlineVariantDark;
  static const Color borderLight = outlineVariantLight;
  static const Color userBubble = surfaceHighLight;
  static const Color aiBubble = bgDark;
  static const Color cmdBubble = surfaceContainerDark;

  /// Dynamic colors based on brightness
  static Color backgroundOf(Brightness brightness) =>
      brightness == Brightness.dark ? bgDark : bgLight;

  static Color textOf(Brightness brightness) =>
      brightness == Brightness.dark ? textDark : textLight;

  static Color textSecondaryOf(Brightness brightness) =>
      brightness == Brightness.dark ? textSecondaryDark : textSecondaryLight;

  static Color surfaceContainerLowOf(Brightness brightness) =>
      brightness == Brightness.dark ? surfaceLowDark : surfaceLowLight;

  static Color surfaceContainerHighOf(Brightness brightness) =>
      brightness == Brightness.dark ? surfaceHighDark : surfaceHighLight;

  static Color userBubbleColorOf(Brightness brightness) =>
      brightness == Brightness.dark ? surfaceHighDark : surfaceHighLight;

  static Color aiBubbleColorOf(Brightness brightness) =>
      brightness == Brightness.dark ? bgDark : bgLight;
}
