import 'package:flutter/material.dart';

import 'package:ignirelay_app/ui/theme/igni_colors.dart';

/// 1 物理像素分隔線（對應 React 原型 `Hairline`）。
///
/// 色調固定採當前主題 [IgniPalette.border1]；要更淡用 [border0]、更顯眼用 [border2]
/// 時請自寫 [Container]。水平/垂直由 [axis] 決定，預設水平。
class Hairline extends StatelessWidget {
  const Hairline({
    super.key,
    this.axis = Axis.horizontal,
    this.strong = false,
    this.indent = 0,
  });

  final Axis axis;

  /// 使用較深的 border2 代替 border1（例如畫面主要分區邊線）。
  final bool strong;

  /// 兩側內縮（僅水平軸向有效）。
  final double indent;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final color = strong ? p.border2 : p.border1;
    final thickness = 1.0 / MediaQuery.of(context).devicePixelRatio;
    if (axis == Axis.vertical) {
      return Container(width: thickness, color: color);
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent),
      child: Container(height: thickness, color: color),
    );
  }
}
