import 'package:flutter/material.dart';

import 'pin_palette.dart';

/// Stage 4d 新增：為 mesh 事件標記群聚時顯示的氣泡。
///
/// 依 plan §Stage 4d L221 的優先級（SOS > 避難 > 醫療 > 其他），
/// 叢集 bubble 會採用群聚中最高優先級事件的 category 色，使用者可
/// 用色彩預判該區最重要事件類別，再決定是否點擊展開。
class ClusterBubble extends StatelessWidget {
  const ClusterBubble({
    super.key,
    required this.count,
    this.highestPriority = PinCategory.life,
  });

  final int count;
  final PinCategory highestPriority;

  @override
  Widget build(BuildContext context) {
    final color = PinPalette.color(highestPriority);
    final label = count > 99 ? '99+' : '$count';
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.33),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
