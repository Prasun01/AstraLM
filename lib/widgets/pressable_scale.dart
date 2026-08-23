import 'package:flutter/material.dart';

/// A highly polished, tactile pressable widget with fluid spring compression,
/// subtle highlight opacity, minimum visual compression guarantee, and zero latency.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final double pressedOpacity;
  final Duration forwardDuration;
  final Duration reverseDuration;
  final Curve forwardCurve;
  final Curve reverseCurve;
  final bool enableHaptics;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.pressedOpacity = 0.85,
    this.forwardDuration = const Duration(milliseconds: 90),
    this.reverseDuration = const Duration(milliseconds: 160),
    this.forwardCurve = Curves.easeOutCubic,
    this.reverseCurve = Curves.easeOutCubic,
    this.enableHaptics = false,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.forwardDuration,
      reverseDuration: widget.reverseDuration,
      value: 0.0,
    );
    _buildAnimations();
  }

  void _buildAnimations() {
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.forwardCurve,
      reverseCurve: widget.reverseCurve,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedOpacity,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.forwardCurve,
      reverseCurve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(PressableScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pressedScale != widget.pressedScale ||
        oldWidget.pressedOpacity != widget.pressedOpacity) {
      _buildAnimations();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _release();
  }

  void _handleTapCancel() {
    _release();
  }

  void _release() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted && _controller.status != AnimationStatus.dismissed) {
        _controller.reverse();
      }
    });
  }

  void _handleTap() {
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.onTap != null || widget.onLongPress != null;
    if (!isInteractive) {
      return widget.child;
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          alignment: Alignment.center,
          child: Opacity(
            opacity: _opacityAnimation.value.clamp(0.0, 1.0),
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
