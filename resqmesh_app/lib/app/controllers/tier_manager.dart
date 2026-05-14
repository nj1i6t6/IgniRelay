import 'package:flutter/foundation.dart';
import 'package:ignirelay_app/l10n/generated/app_localizations.dart';
import 'package:ignirelay_app/app/mesh/mesh_constants.dart';

/// 電量感知 Tier 管理器
///
/// Tier 1: 全功能 (電量 >= 50%)
/// Tier 2: 省電中繼 (電量 20-49%)
/// Tier 3: 極省電模式 (電量 < 20%)
///
/// 遲滯帶防止邊界震盪：升級需高於門檻 +10%
class TierManager {
  TierManager();

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

  String getTierLabel(S l) {
    if (_forceFullSpeed) return l.tierLabel1Force;
    switch (_currentTier) {
      case 3: return l.tierLabel3UltraEco;
      case 2: return l.tierLabel2EcoRelay;
      default: return l.tierLabel1Standard;
    }
  }
}
