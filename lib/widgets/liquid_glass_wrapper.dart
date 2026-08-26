import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Thin, beautiful pure Frosted Glass input bar (Active in both Local & Cloud, 120 FPS)
class LiquidGlassInputWrapper extends StatelessWidget {
  final Widget child;
  final bool isCloud;
  final bool isGenerating;
  final double cornerRadius;

  const LiquidGlassInputWrapper({
    super.key,
    required this.child,
    this.isCloud = true,
    this.isGenerating = false,
    this.cornerRadius = 30.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cornerRadius),
        boxShadow: [
          // Ambient soft glow shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.04),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
          // Crisp contact shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.02),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cornerRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Container(
            decoration: BoxDecoration(
              // Smooth frosted gradient fill
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        const Color(0xFF161A26).withValues(alpha: 0.52),
                        const Color(0xFF0F121C).withValues(alpha: 0.62),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.72),
                        Colors.white.withValues(alpha: 0.56),
                      ],
              ),
              borderRadius: BorderRadius.circular(cornerRadius),
              // Thin, razor-sharp frosted glass border
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.60),
                width: 0.5,
              ),
            ),
            child: Stack(
              children: [
                // Top-Down Frosted Light Glint
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(cornerRadius),
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

                // Interactive Foreground Controls
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
