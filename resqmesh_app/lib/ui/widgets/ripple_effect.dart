import 'package:flutter/material.dart';

/// 擴散漣漪動畫（對應 React 原型 `RippleEffect`）。
///
/// 用於廣播節點、藍牙掃描範圍的視覺化。以 [child] 為中心點，向外
/// 疊加 [ringCount] 層等距圓環；每環從 1.0 scale/1.0 opacity 擴至
/// [maxScale] / 0.0 opacity。
class RippleEffect extends StatefulWidget {
  const RippleEffect({
    super.key,
    required this.child,
    this.active = true,
    this.color,
    this.ringCount = 2,
    this.duration = const Duration(milliseconds: 2000),
    this.maxScale = 2.4,
  });

  final Widget child;
  final bool active;

  /// 圓環顏色；null 則沿用 [Theme]'s primary。
  final Color? color;
  final int ringCount;
  final Duration duration;
  final double maxScale;

  @override
  State<RippleEffect> createState() => _RippleEffectState();
}

class _RippleEffectState extends State<RippleEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant RippleEffect old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.active && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.active)
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              return CustomPaint(
                painter: _RipplePainter(
                  progress: _ctrl.value,
                  color: color,
                  rings: widget.ringCount,
                  maxScale: widget.maxScale,
                ),
                size: const Size(80, 80),
              );
            },
          ),
        widget.child,
      ],
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.progress,
    required this.color,
    required this.rings,
    required this.maxScale,
  });

  final double progress;
  final Color color;
  final int rings;
  final double maxScale;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.shortestSide / 2;
    for (var i = 0; i < rings; i++) {
      final offset = i / rings;
      final t = (progress + offset) % 1.0;
      final scale = 1.0 + (maxScale - 1.0) * t;
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, baseRadius * scale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) =>
      old.progress != progress || old.color != color;
}
