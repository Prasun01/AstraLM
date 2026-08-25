import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/constants.dart';
import '../services/hive_service.dart';
import 'home_view.dart';
import 'welcome_guide_view.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();

    // Smooth transition to Home or Welcome Guide
    _navTimer = Timer(const Duration(milliseconds: 1400), _proceedToNext);
  }

  void _proceedToNext() {
    if (!mounted) return;
    final hive = Get.find<HiveService>();
    final hasSeen = hive.getSetting<bool>(
          AppConstants.keyHasSeenWelcomeGuide,
          defaultValue: false,
        ) ??
        false;

    if (!hasSeen) {
      Get.off(
        () => const WelcomeGuideView(),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 350),
      );
    } else {
      Get.off(
        () => const HomeView(),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 350),
      );
    }
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0C11) : const Color(0xFFFAFBFD);
    final titleColor = isDark ? Colors.white : const Color(0xFF0E1017);
    final subColor = isDark ? const Color(0xFF7A8299) : const Color(0xFF6B7284);
    final pillBg = isDark ? const Color(0xFF131620) : const Color(0xFFEEF2F8);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Stack(
              children: [
                // ── Center: Small Logo & Clean Brand Title ──
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/icons/appicon.png',
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => PhosphorIcon(
                              PhosphorIconsBold.sparkle,
                              size: 26,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'AstraLM',
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Private Local AI',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Bottom: Important Disclaimer ──
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PhosphorIcon(
                            PhosphorIconsBold.warningCircle,
                            size: 14,
                            color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              'make sure to close all background apps',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
