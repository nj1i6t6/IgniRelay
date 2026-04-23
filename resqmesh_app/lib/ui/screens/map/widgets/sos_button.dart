import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Stage 4d：SOS FAB 需長按 1.5 秒啟動（plan §Stage 4d L224）。
///
/// 設計邏輯：
///   - 一般點擊不觸發，避免誤觸送出 SOS 求救；
///   - 長按時顯示圓形進度環（1.5s 填滿）；
///   - 填滿後 `HapticFeedback.heavyImpact` + 呼叫 `onActivated`；
///   - 提前放開則取消，進度環還原 0；
///   - 已送出的 SOS（外部給 `active=true`）改為一般點擊即可取消，
///     因為此時使用者是在「取消既有求救」而非「發送新求救」。
class SosLongPressButton extends StatefulWidget {
  const SosLongPressButton({
    super.key,
    required this.active,
    required this.onActivated,
    required this.onCancelActive,
    required this.label,
    required this.activeLabel,
    required this.holdHint,
    this.activeUrgencyHigh = false,
    this.holdDuration = const Duration(milliseconds: 1500),
  });

  /// `true` = 已送出一次 SOS，按鈕功能改為「取消」。
  final bool active;

  /// 未送出時，長按 1.5s 後觸發。
  final VoidCallback onActivated;

  /// 已送出時，單擊即取消。
  final VoidCallback onCancelActive;

  /// i18n 標籤（預設態）。
  final String label;

  /// i18n 標籤（已送出態）。
  final String activeLabel;

  /// 單擊時 snack bar 提示「需長按」的 i18n 字串。
  final String holdHint;

  /// 已送出 SOS 的 urgency >= 3 時用深紅；否則深橘。
  final bool activeUrgencyHigh;

  final Duration holdDuration;

  @override
  State<SosLongPressButton> createState() => _SosLongPressButtonState();
}

class _SosLongPressButtonState extends State<SosLongPressButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _holdCtrl = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  );
  Timer? _fireTimer;

  void _startHold() {
    if (widget.active) return;
    HapticFeedback.selectionClick();
    _holdCtrl.forward(from: 0);
    _fireTimer = Timer(widget.holdDuration, () {
      HapticFeedback.heavyImpact();
      widget.onActivated();
      _holdCtrl.reverse();
    });
  }

  void _cancelHold() {
    _fireTimer?.cancel();
    _fireTimer = null;
    if (_holdCtrl.isAnimating) _holdCtrl.reverse();
  }

  @override
  void dispose() {
    _fireTimer?.cancel();
    _holdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.active) {
      final bg = widget.activeUrgencyHigh ? Colors.red[800] : Colors.orange[800];
      return FloatingActionButton.extended(
        heroTag: 'sos',
        backgroundColor: bg,
        onPressed: widget.onCancelActive,
        icon: const Icon(Icons.check_circle, color: Colors.white),
        label: Text(
          widget.activeLabel,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: 13,
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPressStart: (_) => _startHold(),
      onLongPressEnd: (_) => _cancelHold(),
      onLongPressCancel: _cancelHold,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FloatingActionButton.extended(
            heroTag: 'sos',
            backgroundColor: Colors.redAccent,
            // 單擊不觸發，提供 tooltip 提示：需長按
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 2),
                  content: Text(widget.holdHint),
                ),
              );
            },
            icon: const Icon(Icons.sos, color: Colors.white),
            label: Text(widget.label,
                style: const TextStyle(color: Colors.white)),
          ),
          // 長按進度環疊層
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _holdCtrl,
              builder: (_, __) => SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: _holdCtrl.value,
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
