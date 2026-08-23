import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/inference_service.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final delay = index * 0.2;
                    final t = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
                    final pulse = (math.sin(t * math.pi) * 0.75).clamp(0.0, 1.0);

                    return Container(
                      margin: EdgeInsets.only(right: index < 2 ? 5 : 0),
                      child: Opacity(
                        opacity: 0.25 + pulse,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: scheme.onSurfaceVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(width: 10),
            Obx(() {
              final inference = Get.find<InferenceService>();
              if (inference.tokenCount.value > 0) {
                return Text(
                  '${inference.tokenCount.value} tokens',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                );
              }
              return Text(
                'thinking…',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
