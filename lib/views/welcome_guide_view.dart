import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/model_controller.dart';
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

  final List<_WalkthroughSlideData> _slides = [
    const _WalkthroughSlideData(
      stepNumber: '01 / 03',
      badge: '100% PRIVATE & OFFLINE',
      title: 'On-Device AI.\nZero Data Leaves Your Phone.',
      description:
          'Run cutting-edge LiteRT & GGUF open-weight models directly on your hardware. Fast, confidential, and completely functional without internet.',
      icon: PhosphorIconsBold.shieldCheck,
      featurePills: [
        'Zero Telemetry',
        'Hardware Accelerated',
        'Offline Capable',
      ],
    ),
    const _WalkthroughSlideData(
      stepNumber: '02 / 03',
      badge: 'UNIVERSAL ECOSYSTEM',
      title: 'Connect Flagship Models.\nDirect & Peer-to-Peer.',
      description:
          'Plug in your own API keys for Google Gemini, DeepSeek, OpenAI, Claude, Groq, or OpenRouter. Your credentials are encrypted locally on device.',
      icon: PhosphorIconsBold.key,
      featurePills: [
        'Client-Side Keys',
        '200+ Cloud Models',
        'Zero Middleman',
      ],
    ),
    const _WalkthroughSlideData(
      stepNumber: '03 / 03',
      badge: 'GET STARTED',
      title: 'Choose How You Want\nto Experience AstraLM.',
      description:
          'Download an ultra-fast local starter model for instant offline intelligence, or connect your favorite cloud API key in seconds.',
      icon: PhosphorIconsBold.sparkle,
      isFinal: true,
      featurePills: [
        'Local Offline Chat',
        'Cloud Flagship Power',
        'Artifacts & Canvas',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
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

  void _openModelsWithScope(String scope) {
    _completeGuide(
      nextAction: () {
        try {
          final modelCtrl = Get.find<ModelController>();
          modelCtrl.modelScope.value = scope;
        } catch (_) {}
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ModelView()),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090C),
      body: Stack(
        children: [
          // ── Layer 1: Ambient Obsidian Canvas ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientController,
              builder: (context, child) {
                final phase = _ambientController.value * 2 * math.pi;
                return CustomPaint(
                  painter: _ObsidianAmbientPainter(phase: phase),
                );
              },
            ),
          ),

          // ── Layer 2: Frosted Glass Blur ──
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                color: const Color(0xFF08090C).withValues(alpha: 0.55),
              ),
            ),
          ),

          // ── Layer 3: Main Carousel & Controls ──
          SafeArea(
            child: Column(
              children: [
                // Top Header (Step Counter & Skip Button)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141620),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _slides[_currentPage].stepNumber,
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: const Color(0xFFBAC0D0),
                          ),
                        ),
                      ),
                      if (_currentPage < _slides.length - 1)
                        PressableScale(
                          onTap: () => _completeGuide(),
                          pressedScale: 0.94,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141620),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Skip',
                              style: GoogleFonts.manrope(
                                fontSize: 12.5,
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
                    itemCount: _slides.length,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _buildSlide(context, _slides[index]);
                    },
                  ),
                ),

                // Bottom Indicators & Action Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Smooth Expanding Pill Page Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (idx) {
                          final isSelected = idx == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 4,
                            width: isSelected ? 26 : 6,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF1D202C),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),

                      // Final Step Action Choices or Continue Button
                      if (_slides[_currentPage].isFinal)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Download Starter Model Card (Solid White, No border)
                            PressableScale(
                              onTap: () => _openModelsWithScope('local'),
                              pressedScale: 0.96,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.16),
                                      blurRadius: 18,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF090A0E),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(
                                        child: PhosphorIcon(
                                          PhosphorIconsBold.arrowDown,
                                          size: 17,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Download Starter Model',
                                            style: GoogleFonts.manrope(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF090A0E),
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            'Qwen 2.5 0.6B · 586 MB · Instant Offline AI',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF555B6C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const PhosphorIcon(
                                      PhosphorIconsBold.caretRight,
                                      size: 15,
                                      color: Color(0xFF090A0E),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // 2. Connect Cloud API Card (Solid Dark, No border)
                            PressableScale(
                              onTap: () => _openModelsWithScope('cloud'),
                              pressedScale: 0.96,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141722),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E2232),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(
                                        child: PhosphorIcon(
                                          PhosphorIconsBold.key,
                                          size: 17,
                                          color: Color(0xFFCBD2E1),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Connect Cloud API Key',
                                            style: GoogleFonts.manrope(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            'Gemini, DeepSeek, OpenAI, OpenRouter',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF8E95A8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const PhosphorIcon(
                                      PhosphorIconsBold.caretRight,
                                      size: 15,
                                      color: Color(0xFF8E95A8),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),

                            // 3. Ghost Button: Start Chatting Directly
                            PressableScale(
                              onTap: () => _completeGuide(),
                              pressedScale: 0.96,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  'Explore On My Own',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF8E95A8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        PressableScale(
                          onTap: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 380),
                              curve: Curves.easeInOutCubic,
                            );
                          },
                          pressedScale: 0.95,
                          child: Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Continue',
                                  style: GoogleFonts.manrope(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF08090C),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const PhosphorIcon(
                                  PhosphorIconsBold.arrowRight,
                                  size: 18,
                                  color: Color(0xFF08090C),
                                ),
                              ],
                            ),
                          ),
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

  Widget _buildSlide(BuildContext context, _WalkthroughSlideData item) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          // Animated Obsidian Glass Icon Emblem
          AnimatedBuilder(
            animation: Listenable.merge([_ambientController, _pulseController]),
            builder: (context, child) {
              final rot = _ambientController.value * 2 * math.pi;
              final breath =
                  0.96 + 0.08 * Curves.easeInOut.transform(_pulseController.value);

              return Transform.scale(
                scale: breath,
                child: SizedBox(
                  width: 124,
                  height: 124,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Precision Orbit Ring 1 (Clockwise)
                      Transform.rotate(
                        angle: rot,
                        child: CustomPaint(
                          size: const Size(116, 116),
                          painter: _WalkthroughOrbitPainter(
                            color: const Color(0xFF202534),
                            dotColor: Colors.white,
                          ),
                        ),
                      ),
                      // Precision Orbit Ring 2 (Counter-Clockwise)
                      Transform.rotate(
                        angle: -rot * 0.75,
                        child: CustomPaint(
                          size: const Size(94, 94),
                          painter: _WalkthroughOrbitPainter(
                            color: const Color(0xFF161924),
                            dotColor: const Color(0xFF8E95A8),
                          ),
                        ),
                      ),
                      // Core Frosted Obsidian Emblem (Borderless)
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF141722),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.06),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: PhosphorIcon(
                            item.icon,
                            size: 30,
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
          const SizedBox(height: 24),

          // Minimalist Badge Pill (Borderless)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF141722),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              item.badge,
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: const Color(0xFFE2E6F2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),

          // Description
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF8E95A8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Feature Highlights Pills (Borderless)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final pill in item.featurePills)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12141E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pill,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFBAC0CC),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _WalkthroughSlideData {
  final String stepNumber;
  final String badge;
  final String title;
  final String description;
  final PhosphorIconData icon;
  final List<String> featurePills;
  final bool isFinal;

  const _WalkthroughSlideData({
    required this.stepNumber,
    required this.badge,
    required this.title,
    required this.description,
    required this.icon,
    this.featurePills = const [],
    this.isFinal = false,
  });
}

class _ObsidianAmbientPainter extends CustomPainter {
  final double phase;
  _ObsidianAmbientPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()..color = const Color(0xFF08090C);
    canvas.drawRect(rect, bgPaint);

    final node1 = Offset(
      size.width * (0.7 + 0.1 * math.cos(phase)),
      size.height * (0.28 + 0.08 * math.sin(phase)),
    );
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF1E2232).withValues(alpha: 0.65),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: node1, radius: size.width * 0.75));
    canvas.drawCircle(node1, size.width * 0.75, paint1);

    final node2 = Offset(
      size.width * (0.25 + 0.1 * math.sin(phase * 1.2)),
      size.height * (0.72 + 0.08 * math.cos(phase * 1.1)),
    );
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF141722).withValues(alpha: 0.75),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: node2, radius: size.width * 0.8));
    canvas.drawCircle(node2, size.width * 0.8, paint2);
  }

  @override
  bool shouldRepaint(covariant _ObsidianAmbientPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}

class _WalkthroughOrbitPainter extends CustomPainter {
  final Color color;
  final Color dotColor;

  _WalkthroughOrbitPainter({required this.color, required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, radius, ringPaint);

    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    final dotOffset = Offset(center.dx + radius, center.dy);
    canvas.drawCircle(dotOffset, 2.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _WalkthroughOrbitPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.dotColor != dotColor;
  }
}
