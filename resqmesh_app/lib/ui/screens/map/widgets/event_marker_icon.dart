import 'package:flutter/material.dart';

/// Stage 4d：從 `map_screen.dart` 抽出的 `_EventMarkerIcon`。
///
/// 用於 mesh 事件 Marker 的圖示本體；SOS 狀態下具備呼吸動畫。
class EventMarkerIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final String tooltip;
  final bool isSOS;

  const EventMarkerIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.size,
    required this.tooltip,
    this.isSOS = false,
  });

  @override
  State<EventMarkerIcon> createState() => _EventMarkerIconState();
}

class _EventMarkerIconState extends State<EventMarkerIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.isSOS) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget marker = Tooltip(
      message: widget.tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(color: widget.color.withValues(alpha: 0.6), blurRadius: 8)
          ],
        ),
        child: Icon(widget.icon, color: Colors.white, size: widget.size * 0.55),
      ),
    );

    if (widget.isSOS && _controller != null) {
      return AnimatedBuilder(
        animation: _controller!,
        builder: (_, child) => Opacity(
          opacity: 0.6 + _controller!.value * 0.4,
          child: Transform.scale(
            scale: 0.9 + _controller!.value * 0.15,
            child: child,
          ),
        ),
        child: marker,
      );
    }
    return marker;
  }
}
