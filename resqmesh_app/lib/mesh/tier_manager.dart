import 'package:flutter/foundation.dart';
import 'mesh_constants.dart';

/// 電量感知 Tier 管理器
///
/// Tier 1: 全功能 (電量 >= 50%)
/// Tier 2: 省電中繼 (電量 20-49%)
/// Tier 3: 極省電模式 (電量 < 20%)
///
/// 遲滯帶防止邊界震盪：升級需高於門檻 +10%
class TierManager {
  static final TierManager _instance = TierManager._internal();
  factory TierManager() => _instance;
  TierManager._internal();

  int _currentTier = 1;
  bool _forceFullSpeed = false;

  int get currentTier => _forceFullSpeed ? 1 : _currentTier;
  bool get isForceFullSpeed => _forceFullSpeed;

  void updateBattery(int batteryLevel) {
    if (_forceFullSpeed) return;

    final prev = _currentTier;
    switch (_currentTier) {
      case 1:
        if (batteryLevel < kTier2MinBattery) {
          _currentTier = 3;
        } else if (batteryLevel < kTier1MinBattery) {
          _currentTier = 2;
        }
        break;
      case 2:
        if (batteryLevel >= kTier1MinBattery + kTierHysteresis) {
          _currentTier = 1;
        } else if (batteryLevel < kTier2MinBattery) {
          _currentTier = 3;
        }
        break;
      case 3:
        if (batteryLevel >= kTier2MinBattery + kTierHysteresis) {
          _currentTier = 2;
        }
        break;
    }
    if (prev != _currentTier) {
      debugPrint('[Tier] $prev → $_currentTier (battery=$batteryLevel%)');
    }
  }

  void setForceFullSpeed(bool enabled) {
    _forceFullSpeed = enabled;
    if (enabled) {
      debugPrint('[Tier] Force full speed ON → Tier 1');
    } else {
      debugPrint('[Tier] Force full speed OFF → Tier $_currentTier');
    }
  }

  String getTierLabel() {
    if (_forceFullSpeed) return '全速模式 (Tier 1)';
    switch (_currentTier) {
      case 3:
        return '極省電模式 (Tier 3)';
      case 2:
        return '省電中繼模式 (Tier 2)';
      default:
        return '標準模式 (Tier 1)';
    }
  }
}
