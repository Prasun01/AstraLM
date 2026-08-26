import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Reusable Thin Beautiful Frosted Glass Widget (Glassmorphism / Frosted Acrylic)
class FrostedGlass extends StatelessWidget {
  final Widget child;
  final double cornerRadius;
  final double blur;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final BoxShape shape;
  final List<BoxShadow>? shadows;
  final Color? darkColor;
  final Color? lightColor;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;

  const FrostedGlass({
    super.key,
    required this.child,
    this.cornerRadius = 22.0,
    this.blur = 16.0,
    this.borderWidth = 0.5,
    this.padding,
    this.shape = BoxShape.rectangle,
    this.shadows,
    this.darkColor,
    this.lightColor,
    this.width,
    this.height,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final boxDecoration = BoxDecoration(
      shape: shape,
      borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(cornerRadius),
      boxShadow: shadows ?? [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.04),
          blurRadius: 14,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.02),
          blurRadius: 4,
          spreadRadius: 0,
          offset: const Offset(0, 1),
        ),
      ],
    );

    final innerDecoration = BoxDecoration(
      shape: shape,
      borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(cornerRadius),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                (darkColor ?? const Color(0xFF161A26)).withValues(alpha: 0.55),
                (darkColor ?? const Color(0xFF0F121C)).withValues(alpha: 0.65),
              ]
            : [
                (lightColor ?? Colors.white).withValues(alpha: 0.75),
                (lightColor ?? Colors.white).withValues(alpha: 0.58),
              ],
      ),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.60),
        width: borderWidth,
      ),
    );

    Widget content = Container(
      width: width,
      height: height,
      constraints: constraints,
      padding: padding,
      decoration: innerDecoration,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: shape,
                  borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(cornerRadius),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.09 : 0.22),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );

    if (shape == BoxShape.circle) {
      return Container(
        decoration: boxDecoration,
        child: ClipOval(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: content,
          ),
        ),
      );
    }

    return Container(
      decoration: boxDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cornerRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      ),
    );
  }
}
