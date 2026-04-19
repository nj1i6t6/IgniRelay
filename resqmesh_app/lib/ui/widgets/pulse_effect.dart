import 'package:flutter/material.dart';

/// 呼吸式脈衝動畫包裝（對應 React 原型 `PulseEffect`）。
///
/// 用於廣播中、SOS 待啟動、BLE 掃描中的視覺提示。透過 [active] 控制；
/// 關閉時直接回傳 [child] 不啟動 ticker，避免不必要的重繪。
class PulseEffect extends StatefulWidget {
  const PulseEffect({
    super.key,
    required this.child,
    this.active = true,
    this.duration = const Duration(milliseconds: 1400),
    this.minScale = 1.0,
    this.maxScale = 1.08,
    this.minOpacity = 0.55,
    this.maxOpacity = 1.0,
  });

  final Widget child;
  final bool active;
  final Duration duration;
  final double minScale;
  final double maxScale;
  final double minOpacity;
  final double maxOpacity;

  @override
  State<PulseEffect> createState() => _PulseEffectState();
}

class _PulseEffectState extends State<PulseEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant PulseEffect old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
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
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        final scale = widget.minScale + (widget.maxScale - widget.minScale) * t;
        final opacity =
            widget.maxOpacity - (widget.maxOpacity - widget.minOpacity) * t;
        return Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: widget.child,
    );
  }
}
