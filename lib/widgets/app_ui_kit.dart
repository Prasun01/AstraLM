import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'pressable_scale.dart';

/// AstraLM Design System — Minimalist, High-End Editorial UI Components
/// Strictly Zero Emojis, Zero Colored Thin Outlines, Pure Tonal Depth

class AstraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final bool isHighlighted;
  final Color? backgroundColor;

  const AstraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.onTap,
    this.isHighlighted = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    final bg = backgroundColor ??
        (isHighlighted
            ? (isDark ? const Color(0xFF161924) : const Color(0xFFEAEFF8))
            : (isDark ? const Color(0xFF0F1118) : const Color(0xFFF4F6FB)));

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: isHighlighted
            ? Border.all(
                color: isDark ? const Color(0xFF2A3045) : const Color(0xFFCBD5E1),
                width: 1,
              )
            : null,
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
    this.padding = const EdgeInsets.only(top: 16, bottom: 10, left: 2, right: 2),
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
                    fontSize: 15.5,
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
                      fontSize: 12,
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

class AstraBadge extends StatelessWidget {
  final String label;
  final PhosphorIconData? icon;
  final Color? color;
  final Color? textColor;

  const AstraBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = color ?? (isDark ? const Color(0xFF181B26) : const Color(0xFFE8EDF5));
    final fg = textColor ??
        (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
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
                    ? const Color(0xFF141722)
                    : scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: PhosphorIcon(
                icon,
                size: 32,
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
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0E1017),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
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
                    ? PhosphorIcon(actionIcon!, size: 15)
                    : const SizedBox.shrink(),
                label: Text(
                  actionLabel!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
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
