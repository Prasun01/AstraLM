import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'pressable_scale.dart';

/// AstraLM Design System — Reusable Core UI Components

/// Standard Card container with 16px radius, proper elevation & surface tone.
class AstraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final bool isHighlighted;
  final Color? backgroundColor;
  final Color? borderColor;

  const AstraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.onTap,
    this.isHighlighted = false,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    final bg = backgroundColor ??
        (isHighlighted
            ? (isDark ? const Color(0xFF1E2433) : const Color(0xFFE8EEF9))
            : (isDark ? const Color(0xFF10121A) : const Color(0xFFF6F8FC)));

    final border = borderColor ??
        (isHighlighted
            ? scheme.primary.withValues(alpha: 0.35)
            : (isDark ? const Color(0xFF1E222E) : const Color(0xFFE5E9F2)));

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
      ),
      child: child,
    );

    if (onTap != null) {
      content = PressableScale(
        pressedScale: 0.98,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        child: content,
      );
    }

    return RepaintBoundary(
      child: Padding(
        padding: margin,
        child: content,
      ),
    );
  }
}

/// Category and Section Headers with consistent typography hierarchy.
class AstraSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const AstraSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.only(top: 16, bottom: 10, left: 4, right: 4),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0E1017),
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: isDark
                          ? const Color(0xFF8E95A8)
                          : const Color(0xFF6B7284),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Clean pill badge for tags, hardware status, and model attributes.
class AstraBadge extends StatelessWidget {
  final String label;
  final PhosphorIconData? icon;
  final Color? color;
  final Color? textColor;
  final bool isFilled;

  const AstraBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.textColor,
    this.isFilled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    final primaryColor = color ?? scheme.primary;
    final bg = isFilled
        ? primaryColor.withValues(alpha: isDark ? 0.20 : 0.12)
        : (isDark ? const Color(0xFF181B26) : const Color(0xFFEDF1F7));
    final fg = textColor ??
        (isFilled
            ? primaryColor
            : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: isFilled
            ? Border.all(color: primaryColor.withValues(alpha: 0.3), width: 0.8)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            PhosphorIcon(icon!, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Universal Empty State Widget.
class AstraEmptyState extends StatelessWidget {
  final PhosphorIconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final PhosphorIconData? actionIcon;
  final VoidCallback? onAction;

  const AstraEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF161924)
                    : scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: PhosphorIcon(
                icon,
                size: 36,
                color: isDark
                    ? const Color(0xFF8E95A8)
                    : scheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0E1017),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: isDark
                    ? const Color(0xFF8E95A8)
                    : const Color(0xFF6B7284),
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onAction!();
                },
                icon: actionIcon != null
                    ? PhosphorIcon(actionIcon!, size: 16)
                    : const SizedBox.shrink(),
                label: Text(
                  actionLabel!,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Universal Error State Widget.
class AstraErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const AstraErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: PhosphorIcon(
                PhosphorIconsBold.warning,
                size: 32,
                color: scheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0E1017),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark
                    ? const Color(0xFF8E95A8)
                    : const Color(0xFF6B7284),
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                onRetry();
              },
              icon: PhosphorIcon(PhosphorIconsBold.arrowsCounterClockwise,
                  size: 15),
              label: const Text('Try Again'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
