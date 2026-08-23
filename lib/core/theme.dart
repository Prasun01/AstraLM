import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Lumina Runner theme — editorial-grade minimalism.
///
/// No shadows, no outlines. Hierarchy comes from type scale, whitespace,
/// and subtle tonal shifts. 16px soft radii, pill chips, single violet accent.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final accent = AppColors.accentOf(brightness);

    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final onSurface = isDark ? AppColors.textDark : AppColors.textLight;
    final onSurfaceVariant =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final muted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
      onPrimary: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      primaryContainer:
          isDark ? const Color(0xFF242734) : const Color(0xFFE2E6EE),
      onPrimaryContainer:
          isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
      secondary: isDark ? const Color(0xFFE0E3EC) : const Color(0xFF2A2D36),
      onSecondary: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      secondaryContainer:
          isDark ? const Color(0xFF20232E) : const Color(0xFFE2E6EE),
      onSecondaryContainer:
          isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
      tertiary: isDark ? const Color(0xFFFF9F0A) : const Color(0xFFD97706),
      onTertiary: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      tertiaryContainer:
          isDark ? const Color(0xFF33220A) : const Color(0xFFFEF3C7),
      onTertiaryContainer:
          isDark ? const Color(0xFFFFD188) : const Color(0xFF78350F),
      error: isDark ? const Color(0xFFFFB4AB) : AppColors.error,
      onError: isDark ? const Color(0xFF690005) : Colors.white,
      errorContainer:
          isDark ? const Color(0xFF93000A) : AppColors.errorContainer,
      onErrorContainer:
          isDark ? AppColors.errorContainer : AppColors.onErrorContainer,
      surface: bg,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: isDark ? AppColors.outlineDark : AppColors.outlineLight,
      outlineVariant:
          isDark ? AppColors.outlineVariantDark : AppColors.outlineVariantLight,
      inverseSurface: isDark ? AppColors.bgLight : AppColors.bgDark,
      onInverseSurface: isDark ? AppColors.textLight : AppColors.textDark,
      inversePrimary: isDark ? AppColors.primary : AppColors.primaryDim,
      surfaceContainerHighest:
          isDark ? AppColors.surfaceHighestDark : AppColors.surfaceHighestLight,
      surfaceContainerHigh:
          isDark ? AppColors.surfaceHighDark : AppColors.surfaceHighLight,
      surfaceContainer:
          isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
      surfaceContainerLow:
          isDark ? AppColors.surfaceLowDark : AppColors.surfaceLowLight,
      surfaceContainerLowest:
          isDark ? AppColors.surfaceLowestDark : AppColors.surfaceLowestLight,
      surfaceTint: AppColors.primaryDeep,
    );

    // Open Sans for body reading text; Playfair Display for headlines/editorial display; Manrope for UI controls/labels.
    final baseText = GoogleFonts.openSansTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).apply(bodyColor: onSurface, displayColor: onSurface);

    final playfair = GoogleFonts.playfairDisplayTextTheme(baseText);
    final manrope = GoogleFonts.manropeTextTheme(baseText);

    final textTheme = baseText.copyWith(
      displayLarge: playfair.displayLarge?.copyWith(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
      ),
      displayMedium: playfair.displayMedium?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineLarge: playfair.headlineLarge?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      headlineMedium: playfair.headlineMedium?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      headlineSmall: playfair.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleLarge: manrope.titleLarge?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      titleMedium: manrope.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: manrope.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelLarge: manrope.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelMedium: manrope.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
      labelSmall: manrope.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.6,
        color: onSurface,
      ),
      bodyMedium: baseText.bodyMedium?.copyWith(
        fontSize: 14.5,
        height: 1.5,
        color: onSurface,
      ),
      bodySmall: baseText.bodySmall?.copyWith(
        fontSize: 12.5,
        height: 1.4,
        color: onSurfaceVariant,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      primaryColor: accent,
      cardColor: scheme.surfaceContainerLow,
      hintColor: muted,
      dividerColor: scheme.outlineVariant.withValues(alpha: 0.4),
      splashFactory: InkSparkle.splashFactory,
      colorScheme: scheme,
      textTheme: textTheme,

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: manrope.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        iconTheme: IconThemeData(color: onSurfaceVariant),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      // ── Card: tonal shift only — no border, no shadow ──
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ── Bottom Nav ──
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bg,
        selectedItemColor: accent,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.03),
        unselectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),

      textSelectionTheme: TextSelectionThemeData(cursorColor: accent),

      // ── Input: flat tonal fill, no border, accent caret ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF171920) : const Color(0xFFE8EBF2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
              color: isDark ? Colors.white : Colors.black, width: 1.5),
        ),
        hintStyle: TextStyle(color: muted, fontSize: 15),
        labelStyle: TextStyle(color: muted, fontSize: 14),
      ),

      // ── Buttons: solid accent / ghost ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
          foregroundColor:
              isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle:
              GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor:
              isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
          foregroundColor:
              isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle:
              GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : Colors.black,
          side: BorderSide(
            color: isDark ? const Color(0xFF282B36) : const Color(0xFFD6DBE4),
            width: 1.2,
          ),
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle:
              GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? Colors.white : Colors.black,
          textStyle:
              GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: onSurfaceVariant),
      ),

      // ── Switches & Sliders ──
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? Colors.black : Colors.white;
          }
          return isDark ? AppColors.textMutedDark : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? Colors.white : Colors.black;
          }
          return isDark
              ? AppColors.surfaceHighestDark
              : AppColors.surfaceHighestLight;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.onPrimary,
        overlayColor: accent.withValues(alpha: 0.12),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      ),

      // ── Chips: pill-shaped, tonal, high-contrast ──
      chipTheme: ChipThemeData(
        backgroundColor:
            isDark ? const Color(0xFF14161E) : const Color(0xFFF0F2F6),
        selectedColor:
            isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
        checkmarkColor:
            isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
        labelStyle: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFC0C4D0) : const Color(0xFF505462)),
        secondaryLabelStyle: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF)),
        shape: const StadiumBorder(),
        side: BorderSide(
          color: isDark ? const Color(0xFF242734) : const Color(0xFFD6DBE5),
          width: 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Segmented Button ──
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return isDark
                  ? const Color(0xFFFFFFFF)
                  : const Color(0xFF000000);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return isDark
                  ? const Color(0xFF000000)
                  : const Color(0xFFFFFFFF);
            }
            return isDark
                ? const Color(0xFFC0C4D0)
                : const Color(0xFF505462);
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return isDark
                  ? const Color(0xFF000000)
                  : const Color(0xFFFFFFFF);
            }
            return isDark
                ? const Color(0xFFC0C4D0)
                : const Color(0xFF505462);
          }),
          side: WidgetStateProperty.all(BorderSide(
            color: isDark ? const Color(0xFF242734) : const Color(0xFFD6DBE5),
            width: 1,
          )),
          shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          textStyle: WidgetStateProperty.all(GoogleFonts.manrope(
              fontSize: 13.5, fontWeight: FontWeight.w600)),
        ),
      ),

      // ── Misc ──
      dividerTheme:
          DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.35), thickness: 0.5),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
            fontFamily: 'Bricolage Grotesque',
            package: null,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: onSurface),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        iconColor: onSurfaceVariant,
        titleTextStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.4),
        subtitleTextStyle: TextStyle(fontSize: 13, color: muted, height: 1.35),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return muted;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.transparent;
        }),
        side: BorderSide(color: muted, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            TextStyle(fontSize: 14, color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(fontSize: 12, color: scheme.onInverseSurface),
      ),
    );
  }

  // ── Chat bubble helpers (Lumina Runner chat spec) ──

  /// User messages: soft-tinted container anchoring the right edge.
  static Color userBubbleColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return scheme.surfaceContainerHigh;
  }

  /// Assistant messages: no bubble — they sit directly on the background.
  static Color aiBubbleColor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  /// Command/system messages: subtle tonal container.
  static Color cmdBubbleColor(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainer;
}
