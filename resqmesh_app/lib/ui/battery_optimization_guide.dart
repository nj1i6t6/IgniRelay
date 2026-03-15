import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../mesh/native_bridge.dart';

/// 電池優化引導 Dialog
/// 首次使用時引導用戶：
/// 1. 豁免 Android 電池優化（Doze）
/// 2. 開啟各大廠私有的背景執行/自啟動權限
/// 確保 Mesh 前景服務不會被系統殺掉
class BatteryOptimizationGuide {
  static const _prefKey = 'battery_optimization_guided';
  static const _prefSkipKey = 'battery_optimization_skip_count';

  /// 檢查是否需要顯示引導，如果需要則彈出 Dialog
  /// 回傳 true 表示已豁免，false 表示用戶跳過或平臺不支援
  static Future<bool> checkAndGuide(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    final prefs = await SharedPreferences.getInstance();
    final alreadyDone = prefs.getBool(_prefKey) ?? false;
    if (alreadyDone) return true;

    // 檢查是否已經豁免
    final exempt = await NativeBridge.isBatteryOptimizationExempt();
    if (exempt) {
      await prefs.setBool(_prefKey, true);
      return true;
    }

    // 用戶已跳過超過 3 次，就不再主動彈出（但在設定頁仍可手動觸發）
    final skipCount = prefs.getInt(_prefSkipKey) ?? 0;
    if (skipCount >= 3) return false;

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _BatteryGuideDialog(),
    );

    if (result == true) {
      // 用戶完成了引導
      await prefs.setBool(_prefKey, true);
      return true;
    } else {
      // 用戶跳過
      await prefs.setInt(_prefSkipKey, skipCount + 1);
      return false;
    }
  }

  /// 從設定頁手動觸發引導（不受跳過次數限制）
  static Future<void> showGuideManually(BuildContext context) async {
    if (!Platform.isAndroid) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('此功能僅適用 Android 裝置')),
        );
      }
      return;
    }
    await showDialog<bool>(
      context: context,
      builder: (ctx) => const _BatteryGuideDialog(),
    );
  }
}

class _BatteryGuideDialog extends StatefulWidget {
  const _BatteryGuideDialog();

  @override
  State<_BatteryGuideDialog> createState() => _BatteryGuideDialogState();
}

class _BatteryGuideDialogState extends State<_BatteryGuideDialog> {
  int _step = 0; // 0: 說明, 1: 系統豁免, 2: 廠商設定, 3: 完成
  bool _exemptDone = false;
  bool _manufacturerDone = false;
  String _manufacturer = 'unknown';

  static const _manufacturerLabels = {
    'xiaomi': '小米 / Redmi',
    'redmi': '小米 / Redmi',
    'huawei': '華為',
    'honor': '榮耀',
    'oppo': 'OPPO',
    'realme': 'realme',
    'vivo': 'vivo',
    'samsung': '三星 Samsung',
    'asus': '華碩 ASUS',
  };

  static const _manufacturerInstructions = {
    'xiaomi': '請在「自啟動管理」中找到 ResQMesh → 開啟自啟動\n'
        '另外在「省電策略」→ 選擇「無限制」',
    'redmi': '請在「自啟動管理」中找到 ResQMesh → 開啟自啟動\n'
        '另外在「省電策略」→ 選擇「無限制」',
    'huawei': '請在「啟動管理」中找到 ResQMesh\n'
        '→ 關閉「自動管理」→ 手動開啟所有開關\n'
        '另在「鎖屏清理」中不要清理本 App',
    'honor': '請在「啟動管理」中找到 ResQMesh\n'
        '→ 關閉「自動管理」→ 手動開啟所有開關',
    'oppo': '請在「自啟動管理」中允許 ResQMesh 自啟動\n'
        '另在「省電」→「App 電池管理」→ 選擇「不優化」',
    'realme': '請在「自啟動管理」中允許 ResQMesh 自啟動\n'
        '另在「省電」→「App 電池管理」→ 選擇「不優化」',
    'vivo': '請在「後臺管理」中允許 ResQMesh 高耗電運行\n'
        '另在「自啟動」中開啟本 App',
    'samsung': '請在「電池」→「背景使用限制」\n'
        '→ 將 ResQMesh 從「受限 App」清單移除\n'
        '或加入「永不進入休眠」清單',
    'asus': '請在「自動啟動管理員」中允許 ResQMesh\n'
        '另在「電池」中選擇「不受限」',
  };

  @override
  void initState() {
    super.initState();
    _loadManufacturer();
  }

  Future<void> _loadManufacturer() async {
    final m = await NativeBridge.getManufacturer();
    if (mounted) setState(() => _manufacturer = m);
  }

  bool get _isKnownManufacturer {
    return _manufacturerLabels.keys.any((k) => _manufacturer.contains(k));
  }

  String get _manufacturerLabel {
    for (final entry in _manufacturerLabels.entries) {
      if (_manufacturer.contains(entry.key)) return entry.value;
    }
    return _manufacturer;
  }

  String get _manufacturerInstruction {
    for (final entry in _manufacturerInstructions.entries) {
      if (_manufacturer.contains(entry.key)) return entry.value;
    }
    return '請到手機的「設定」→「電池」→「背景執行管理」中\n允許 ResQMesh 在背景運行。';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            _step == 3 ? Icons.check_circle : Icons.battery_alert,
            color: _step == 3 ? Colors.green : Colors.orangeAccent,
          ),
          const SizedBox(width: 8),
          Text(
            _step == 3 ? '設定完成！' : '背景執行設定',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildStepContent(),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildIntroStep();
      case 1:
        return _buildSystemExemptStep();
      case 2:
        return _buildManufacturerStep();
      case 3:
        return _buildDoneStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildIntroStep() {
    return Column(
      key: const ValueKey(0),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withValues(alpha:0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '重要！Mesh 網路需要在後台持續運行',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'ResQMesh 依賴藍牙 Mesh 在背景持續廣播與中繼救援資訊。\n\n'
          '若 Android 系統將 App 殺掉，您的裝置將：',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        _bulletPoint('無法接收附近求救訊號'),
        _bulletPoint('無法擔任 Data Mule 中繼節點'),
        _bulletPoint('無法自動同步物資媒合資訊'),
        const SizedBox(height: 12),
        const Text(
          '接下來會引導您完成 1-2 步設定，確保 Mesh 網路持續運作。',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSystemExemptStep() {
    return Column(
      key: const ValueKey(1),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepIndicator('步驟 1/2', '系統電池優化豁免'),
        const SizedBox(height: 12),
        const Text(
          '點擊下方按鈕，系統會彈出確認視窗。\n'
          '請選擇「允許」，讓 ResQMesh 不受 Doze 省電限制。',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: _exemptDone
                ? null
                : () async {
                    await NativeBridge.requestBatteryOptimizationExemption();
                    // 等待用戶操作後回來
                    await Future.delayed(const Duration(seconds: 2));
                    final exempt =
                        await NativeBridge.isBatteryOptimizationExempt();
                    if (mounted) {
                      setState(() => _exemptDone = exempt);
                    }
                  },
            icon: Icon(_exemptDone ? Icons.check : Icons.battery_saver),
            label: Text(_exemptDone ? '已完成' : '開啟電池優化豁免'),
          ),
        ),
        if (_exemptDone) ...[
          const SizedBox(height: 12),
          const Center(
            child: Text('✓ 已成功豁免電池優化',
                style: TextStyle(color: Colors.green, fontSize: 13)),
          ),
        ],
      ],
    );
  }

  Widget _buildManufacturerStep() {
    return Column(
      key: const ValueKey(2),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepIndicator('步驟 2/2', '${_manufacturerLabel} 背景執行設定'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.cyan.withValues(alpha:0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.cyan.withValues(alpha:0.2)),
          ),
          child: Text(
            _manufacturerInstruction,
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: _manufacturerDone
                ? null
                : () async {
                    await NativeBridge.openManufacturerPowerSettings();
                    if (mounted) {
                      setState(() => _manufacturerDone = true);
                    }
                  },
            icon: Icon(_manufacturerDone ? Icons.check : Icons.settings),
            label: Text(_manufacturerDone ? '已開啟設定' : '前往設定'),
          ),
        ),
        if (_manufacturerDone) ...[
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '請在設定頁面完成操作後返回此畫面',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDoneStep() {
    return Column(
      key: const ValueKey(3),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 64),
        const SizedBox(height: 16),
        const Text(
          '背景執行設定完成！',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'ResQMesh 現在可以在背景持續運行 Mesh 網路，\n'
          '即使螢幕關閉也能接收並中繼救援資訊。',
          style: TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  '前景服務通知會在 Mesh 守護啟動後出現',
                  style: TextStyle(color: Colors.green, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepIndicator(String step, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withValues(alpha:0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(step,
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(color: Colors.redAccent, fontSize: 14)),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    switch (_step) {
      case 0:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('稍後再說', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => setState(() => _step = 1),
            child: const Text('開始設定'),
          ),
        ];
      case 1:
        return [
          TextButton(
            onPressed: () {
              if (_isKnownManufacturer) {
                setState(() => _step = 2);
              } else {
                setState(() => _step = 3);
              }
            },
            child: const Text('跳過此步', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              if (_isKnownManufacturer) {
                setState(() => _step = 2);
              } else {
                setState(() => _step = 3);
              }
            },
            child: const Text('下一步'),
          ),
        ];
      case 2:
        return [
          TextButton(
            onPressed: () => setState(() => _step = 3),
            child: const Text('跳過此步', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => setState(() => _step = 3),
            child: const Text('下一步'),
          ),
        ];
      case 3:
        return [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('完成'),
          ),
        ];
      default:
        return [];
    }
  }
}
