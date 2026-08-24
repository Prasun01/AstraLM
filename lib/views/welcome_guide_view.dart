import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../services/hive_service.dart';
import '../widgets/pressable_scale.dart';
import 'model_view.dart';

class WelcomeGuideView extends StatefulWidget {
  final bool isReplay;
  const WelcomeGuideView({super.key, this.isReplay = false});

  @override
  State<WelcomeGuideView> createState() => _WelcomeGuideViewState();
}

class _WelcomeGuideViewState extends State<WelcomeGuideView>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _ambientController;
  late final AnimationController _pulseController;
  int _currentPage = 0;

  final List<_MonochromeGuideItem> _items = [
    const _MonochromeGuideItem(
      tag: '01 / ARCHITECTURE',
      badge: 'WELCOME TO ASTRALM',
      title: 'Next-Gen Intelligence.\nUncompromising Privacy.',
      description:
          'Experience state-of-the-art AI right in your hands. Fast, completely offline-capable, and universally extensible across local hardware and global cloud APIs.',
      icon: PhosphorIconsBold.sparkle,
    ),
    const _MonochromeGuideItem(
      tag: '02 / LOCAL INFERENCE',
      badge: '100% PRIVATE & OFFLINE',
      title: 'On-Device Engine.\nZero Telemetry.',
      description:
          'Run cutting-edge GGUF & LiteRT open-weight language models locally on your phone. Your conversations, prompts, and personal data never leave your physical device.',
      icon: PhosphorIconsBold.cpu,
    ),
    const _MonochromeGuideItem(
      tag: '03 / CLOUD ECOSYSTEM',
      badge: 'UNIVERSAL CONNECTIVITY',
      title: 'Connect Any Provider.\nYour Own Keys.',
      description:
          'Switch seamlessly to Claude, OpenAI, OpenRouter, DeepSeek, Kimi, Nvidia NIM, or any custom OpenAI-compatible endpoint with your private API credentials.',
      icon: PhosphorIconsBold.gitBranch,
    ),
    const _MonochromeGuideItem(
      tag: '04 / MULTIMODAL & CREATIVE',
      badge: 'VISION & ART ENGINE',
      title: 'Vision & Generation.\nAll in One Place.',
      description:
          'Inspect documents and analyze photos with multimodal vision models, or generate high-fidelity art on-device with built-in Stable Diffusion isolate engines.',
      icon: PhosphorIconsBold.palette,
    ),
    const _MonochromeGuideItem(
      tag: '05 / READY',
      badge: 'OPTIMIZED FOR HARDWARE',
      title: 'Tailored Performance\nfor Your Device.',
      description:
          'AstraLM has automatically benchmarked and optimized context size, RAM allocation, and GPU acceleration for your hardware.',
      icon: PhosphorIconsBold.rocket,
      isFinal: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Slow ambient rotation controller (18 seconds per full cycle)
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    // Slow breathing pulse animation (4.5 seconds ping-pong)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ambientController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _completeGuide({VoidCallback? nextAction}) async {
    final hive = Get.find<HiveService>();
    await hive.setSetting(AppConstants.keyHasSeenWelcomeGuide, true);
    if (!mounted) return;
    Navigator.of(context).pop();
    nextAction?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0E),
      body: Stack(
        children: [
          // ── Layer 1: Animated Space Gray & Graphite Ambient Canvas ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientController,
              builder: (context, child) {
                final t = _ambientController.value * 2 * math.pi;
                return CustomPaint(
                  painter: _MonochromeAmbientPainter(phase: t),
                );
              },
            ),
          ),

          // ── Layer 2: Subtle Frosted Glass Depth Blur ──
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
              child: Container(
                color: const Color(0xFF090A0E).withValues(alpha: 0.6),
              ),
            ),
          ),

          // ── Layer 3: Main Guide Carousel & Controls ──
          SafeArea(
            child: Column(
              children: [
                // Top Header (Step Tag & Skip button)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141620),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF262B3B),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _items[_currentPage].tag,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: const Color(0xFFBAC0D0),
                          ),
                        ),
                      ),
                      if (_currentPage < _items.length - 1)
                        PressableScale(
                          onTap: () => _completeGuide(),
                          pressedScale: 0.94,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13151D),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF222634),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Skip',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF8E95A8),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Carousel Pages
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _items.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _buildSlide(context, _items[index]);
                    },
                  ),
                ),

                // Bottom Indicators & Action Buttons
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Smooth Expanding Pill Page Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_items.length, (idx) {
                          final isSelected = idx == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 360),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 5,
                            width: isSelected ? 30 : 6,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF262B3B),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),

                      // Action Button(s)
                      if (_items[_currentPage].isFinal)
                        Column(
                          children: [
                            _buildSolidWhiteButton(
                              label: 'Explore Local Models',
                              icon: PhosphorIconsBold.arrowDown,
                              onTap: () => _completeGuide(
                                nextAction: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const ModelView()),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildGhostButton(
                              label: 'Start Chatting',
                              onTap: () => _completeGuide(),
                            ),
                          ],
                        )
                      else
                        _buildSolidWhiteButton(
                          label: 'Continue',
                          icon: PhosphorIconsBold.arrowRight,
                          onTap: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 420),
                              curve: Curves.easeInOutCubic,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(BuildContext context, _MonochromeGuideItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Slow Floating Animated Monochrome Icon Badge with Orbit Rings
          AnimatedBuilder(
            animation: Listenable.merge([_ambientController, _pulseController]),
            builder: (context, child) {
              final rot = _ambientController.value * 2 * math.pi;
              final breath =
                  0.96 + 0.08 * Curves.easeInOut.transform(_pulseController.value);

              return Transform.scale(
                scale: breath,
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated Orbit Ring 1 (Forward rotation)
                      Transform.rotate(
                        angle: rot,
                        child: CustomPaint(
                          size: const Size(130, 130),
                          painter: _OrbitRingPainter(
                            color: const Color(0xFF32384C),
                            dotColor: Colors.white,
                          ),
                        ),
                      ),
                      // Animated Orbit Ring 2 (Counter rotation)
                      Transform.rotate(
                        angle: -rot * 0.7,
                        child: CustomPaint(
                          size: const Size(106, 106),
                          painter: _OrbitRingPainter(
                            color: const Color(0xFF222634),
                            dotColor: const Color(0xFF8E95A8),
                          ),
                        ),
                      ),
                      // Core Monochrome Frosted Glass Card
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF141620),
                          border: Border.all(
                            color: const Color(0xFF383E54),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.05),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            item.icon,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 38),

          // Minimalist Monochrome Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF161822),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF2C3144),
                width: 1,
              ),
            ),
            child: Text(
              item.badge,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: const Color(0xFFE2E6F2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Title
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.4,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.openSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF9096A8),
              height: 1.52,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolidWhiteButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.95,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF090A0E),
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: const Color(0xFF090A0E), size: 19),
          ],
        ),
      ),
    );
  }

  Widget _buildGhostButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.96,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: const Color(0xFF141620),
          border: Border.all(
            color: const Color(0xFF262B3B),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFE2E6F2),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonochromeGuideItem {
  final String tag;
  final String badge;
  final String title;
  final String description;
  final IconData icon;
  final bool isFinal;

  const _MonochromeGuideItem({
    required this.tag,
    required this.badge,
    required this.title,
    required this.description,
    required this.icon,
    this.isFinal = false,
  });
}

/// Subtle, deep Space Gray / Monochrome Ambient Flow Painter
class _MonochromeAmbientPainter extends CustomPainter {
  final double phase;
  _MonochromeAmbientPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()..color = const Color(0xFF090A0E);
    canvas.drawRect(rect, bgPaint);

    // Subtle Graphite Glow Node 1
    final node1 = Offset(
      size.width * (0.65 + 0.12 * math.cos(phase)),
      size.height * (0.28 + 0.08 * math.sin(phase)),
    );
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF1F2332).withValues(alpha: 0.7),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: node1, radius: size.width * 0.7));
    canvas.drawCircle(node1, size.width * 0.7, paint1);

    // Subtle Slate Glow Node 2
    final node2 = Offset(
      size.width * (0.25 + 0.1 * math.sin(phase * 1.2)),
      size.height * (0.68 + 0.1 * math.cos(phase * 1.1)),
    );
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF161822).withValues(alpha: 0.8),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: node2, radius: size.width * 0.75));
    canvas.drawCircle(node2, size.width * 0.75, paint2);
  }

  @override
  bool shouldRepaint(covariant _MonochromeAmbientPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}

/// Precision Orbit Ring Painter with subtle indicator node
class _OrbitRingPainter extends CustomPainter {
  final Color color;
  final Color dotColor;

  _OrbitRingPainter({required this.color, required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, radius, ringPaint);

    // Single glowing dot on the ring
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    final dotOffset = Offset(center.dx + radius, center.dy);
    canvas.drawCircle(dotOffset, 2.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.dotColor != dotColor;
  }
}
