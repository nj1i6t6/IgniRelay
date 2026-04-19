import 'package:flutter/foundation.dart';

/// 烽傳 Ignirelay 急難模式觸發來源。
///
/// 任一條件成立即進入 emergency palette；全部解除才回到 dark/light。
enum EmergencyTrigger {
  /// 用戶本人正在 SOS。
  selfSos,

  /// 附近（< 配置半徑）有紅色事件（SOS / 嚴重災害）。
  nearbyRed,

  /// 系統偵測到大字體（accessibility scale > 閾值）。
  largeFont,

  /// 電量過低（預設 < 15%）。
  lowBattery,

  /// 用戶手動在「我 → 顯示」啟用。
  manual,
}

/// 急難模式控制器。
///
/// Stage 2：骨架 + 手動開關；自動觸發接線（SOS、nearbyRed、lowBattery、largeFont）
/// 於 Stage 3（App 殼）與 Stage 4a（我）/ 4d（地圖）各自接上對應事件源。
///
/// 透過 [ChangeNotifier] 通知上層 rebuild；實際 palette 選擇由 App 殼觀察此 controller。
class EmergencyModeController extends ChangeNotifier {
  EmergencyModeController._();
  static final EmergencyModeController instance = EmergencyModeController._();

  final Set<EmergencyTrigger> _active = <EmergencyTrigger>{};

  /// 目前是否處於急難模式（任一觸發源成立）。
  bool get isEmergency => _active.isNotEmpty;

  /// 目前啟動的觸發源（唯讀快照）。
  Set<EmergencyTrigger> get activeTriggers => Set.unmodifiable(_active);

  /// 宣告某觸發源成立。
  void set(EmergencyTrigger t, bool active) {
    final changed = active ? _active.add(t) : _active.remove(t);
    if (changed) notifyListeners();
  }

  /// 清除所有觸發源（強制退出急難模式）。測試/debug 用途。
  @visibleForTesting
  void reset() {
    if (_active.isEmpty) return;
    _active.clear();
    notifyListeners();
  }
}
