import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

class ThoughtDisclosure extends StatefulWidget {
  final String thought;
  final bool isThinking;
  final int? durationSeconds;
  final MarkdownStyleSheet styleSheet;

  const ThoughtDisclosure({
    super.key,
    required this.thought,
    required this.styleSheet,
    this.isThinking = false,
    this.durationSeconds,
  });

  @override
  State<ThoughtDisclosure> createState() => _ThoughtDisclosureState();
}

class _ThoughtDisclosureState extends State<ThoughtDisclosure>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late DateTime _startedAt;
  Timer? _timer;
  double _liveSeconds = 0.0;
  late AnimationController _expandAnimController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expanded = false;
    _startedAt = DateTime.now();

    _expandAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      value: 0.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant ThoughtDisclosure oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isThinking && !oldWidget.isThinking) {
      _startedAt = DateTime.now();
      _liveSeconds = 0.0;
    } else if (!widget.isThinking && oldWidget.isThinking) {
      _liveSeconds = (widget.durationSeconds ?? _liveSeconds.toInt()).toDouble();
    }

    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _expandAnimController.dispose();
    super.dispose();
  }

  void _syncTimer() {
    if (!widget.isThinking) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _liveSeconds =
            DateTime.now().difference(_startedAt).inMilliseconds / 1000.0;
      });
    });
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _expandAnimController.forward();
    } else {
      _expandAnimController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isThinking = widget.isThinking;

    final primaryAccent = isDark ? const Color(0xFFE0E5F5) : const Color(0xFF1E2230);
    final bgThinking = isDark ? const Color(0xFF141620) : const Color(0xFFF0F3FA);
    final mutedText = isDark ? const Color(0xFF9096A8) : const Color(0xFF646B80);
    final timeStr = _labelTime;

    Widget disclosureBox = Container(
      margin: const EdgeInsets.only(bottom: 12, top: 4),
      decoration: BoxDecoration(
        color: isThinking
            ? bgThinking
            : (isDark ? const Color(0xFF13151D) : const Color(0xFFF4F6FB)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: isThinking ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Bar
            InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    if (isThinking)
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF222638) : const Color(0xFFE2E7F5),
                        ),
                        child: Icon(
                          PhosphorIconsBold.lightbulb,
                          size: 14,
                          color: primaryAccent,
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleXY(begin: 0.88, end: 1.14, duration: 900.ms, curve: Curves.easeInOut)
                          .fade(begin: 0.7, end: 1.0, duration: 900.ms, curve: Curves.easeInOut)
                    else
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF1C1F2B) : const Color(0xFFE5EBF5),
                        ),
                        child: Icon(
                          PhosphorIconsBold.lightbulb,
                          size: 14,
                          color: mutedText,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            isThinking ? 'Thinking' : 'Thought Process',
                            style: GoogleFonts.manrope(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isThinking ? primaryAccent : mutedText,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (timeStr.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1D212E) : const Color(0xFFE2E8F4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                timeStr,
                                style: GoogleFonts.firaCode(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isThinking ? primaryAccent : mutedText,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.fastOutSlowIn,
                      child: Icon(
                        PhosphorIconsBold.caretRight,
                        size: 18,
                        color: isThinking ? primaryAccent : mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Expandable Thought Content
            SizeTransition(
              sizeFactor: _expandAnimation,
              axisAlignment: -1.0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    if (widget.thought.trim().isEmpty && isThinking)
                      Row(
                        children: [
                          Text(
                            'Formulating reasoning...',
                            style: GoogleFonts.openSans(
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                              color: mutedText,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _ThinkingShimmerCursor(isDark: isDark),
                        ],
                      )
                    else
                      MarkdownBody(
                        data: widget.thought.trim(),
                        selectable: true,
                        styleSheet: widget.styleSheet,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (isThinking) {
      return disclosureBox
          .animate(onPlay: (c) => c.repeat())
          .shimmer(
            duration: 1800.ms,
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
          );
    }

    return disclosureBox;
  }

  String get _labelTime {
    if (widget.isThinking) {
      return '${_liveSeconds.toStringAsFixed(1)}s';
    }
    final secs = widget.durationSeconds ?? _liveSeconds.toInt();
    return secs > 0 ? '${secs}s' : '';
  }
}

class _ThinkingShimmerCursor extends StatelessWidget {
  final bool isDark;
  const _ThinkingShimmerCursor({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFFBAC0D5) : const Color(0xFF4A5064),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 0.75, end: 1.25, duration: 550.ms, curve: Curves.easeInOut)
        .fade(begin: 0.35, end: 1.0, duration: 550.ms, curve: Curves.easeInOut);
  }
}
