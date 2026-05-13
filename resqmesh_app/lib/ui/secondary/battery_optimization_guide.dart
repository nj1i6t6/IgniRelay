import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignirelay_app/app/controllers/device_info_controller.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';

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
    final exempt = await context.read<DeviceInfoController>().isBatteryOptimizationExempt();
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
          SnackBar(content: Text(context.l10n.batteryAndroidOnly)),
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

  @override
  void initState() {
    super.initState();
    _loadManufacturer();
  }

  Future<void> _loadManufacturer() async {
    final m = await context.read<DeviceInfoController>().manufacturer();
    if (mounted) setState(() => _manufacturer = m);
  }

  bool get _isKnownManufacturer {
    const knownKeys = ['xiaomi', 'redmi', 'huawei', 'honor', 'oppo', 'realme', 'vivo', 'samsung', 'asus'];
    return knownKeys.any((k) => _manufacturer.contains(k));
  }

  String _getManufacturerLabel(BuildContext context) {
    final l = context.l10n;
    final m = _manufacturer;
    if (m.contains('xiaomi') || m.contains('redmi')) return l.batteryManufacturerXiaomi;
    if (m.contains('huawei')) return l.batteryManufacturerHuawei;
    if (m.contains('honor')) return l.batteryManufacturerHonor;
    if (m.contains('oppo')) return l.batteryManufacturerOppo;
    if (m.contains('realme')) return l.batteryManufacturerRealme;
    if (m.contains('vivo')) return l.batteryManufacturerVivo;
    if (m.contains('samsung')) return l.batteryManufacturerSamsung;
    if (m.contains('asus')) return l.batteryManufacturerAsus;
    return _manufacturer;
  }

  String _getManufacturerInstruction(BuildContext context) {
    final l = context.l10n;
    final m = _manufacturer;
    if (m.contains('xiaomi') || m.contains('redmi')) return l.batteryInstructionXiaomi;
    if (m.contains('huawei')) return l.batteryInstructionHuawei;
    if (m.contains('honor')) return l.batteryInstructionHonor;
    if (m.contains('oppo')) return l.batteryInstructionOppo;
    if (m.contains('realme')) return l.batteryInstructionRealme;
    if (m.contains('vivo')) return l.batteryInstructionVivo;
    if (m.contains('samsung')) return l.batteryInstructionSamsung;
    if (m.contains('asus')) return l.batteryInstructionAsus;
    return l.batteryInstructionDefault;
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
          Expanded(
            child: Text(
              _step == 3 ? context.l10n.batteryDoneTitle : context.l10n.batteryGuideTitle,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
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
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.batteryIntroTitle,
                  style: const TextStyle(
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
        Text(
          context.l10n.batteryIntroBody,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        _bulletPoint(context.l10n.batteryIntroConsequence1),
        _bulletPoint(context.l10n.batteryIntroConsequence2),
        _bulletPoint(context.l10n.batteryIntroConsequence3),
        const SizedBox(height: 12),
        Text(
          context.l10n.batteryIntroGuide,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
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
        _stepIndicator(context.l10n.batteryStep1Label, context.l10n.batteryStep1Title),
        const SizedBox(height: 12),
        Text(
          context.l10n.batteryStep1Desc,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
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
                    await context.read<DeviceInfoController>().requestBatteryOptimizationExemption();
                    // 等待用戶操作後回來
                    await Future.delayed(const Duration(seconds: 2));
                    final exempt =
                        await context.read<DeviceInfoController>().isBatteryOptimizationExempt();
                    if (mounted) {
                      setState(() => _exemptDone = exempt);
                    }
                  },
            icon: Icon(_exemptDone ? Icons.check : Icons.battery_saver),
            label: Text(_exemptDone ? context.l10n.batteryStep1Done : context.l10n.batteryStep1Button),
          ),
        ),
        if (_exemptDone) ...[
          const SizedBox(height: 12),
          Center(
            child: Text(
              '✓ ${context.l10n.batteryStep1Success}',
              style: const TextStyle(color: Colors.green, fontSize: 13),
            ),
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
        _stepIndicator(context.l10n.batteryStep2Label, context.l10n.batteryStep2Title(_getManufacturerLabel(context))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.cyan.withValues(alpha:0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.cyan.withValues(alpha:0.2)),
          ),
          child: Text(
            _getManufacturerInstruction(context),
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
                    await context.read<DeviceInfoController>().openManufacturerPowerSettings();
                    if (mounted) {
                      setState(() => _manufacturerDone = true);
                    }
                  },
            icon: Icon(_manufacturerDone ? Icons.check : Icons.settings),
            label: Text(_manufacturerDone ? context.l10n.batteryOpenedSettings : context.l10n.batteryGoSettings),
          ),
        ),
        if (_manufacturerDone) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              context.l10n.batteryReturnNote,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
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
        Text(
          context.l10n.batteryDoneContent,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.batteryDoneBody,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.l10n.batteryDoneNote,
                  style: const TextStyle(color: Colors.green, fontSize: 12),
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
            child: Text(context.l10n.batteryLaterButton, style: const TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => setState(() => _step = 1),
            child: Text(context.l10n.batteryStartButton),
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
            child: Text(context.l10n.batterySkipButton, style: const TextStyle(color: Colors.white38)),
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
            child: Text(context.l10n.batteryNextButton),
          ),
        ];
      case 2:
        return [
          TextButton(
            onPressed: () => setState(() => _step = 3),
            child: Text(context.l10n.batterySkipButton, style: const TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => setState(() => _step = 3),
            child: Text(context.l10n.batteryNextButton),
          ),
        ];
      case 3:
        return [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.batteryFinishButton),
          ),
        ];
      default:
        return [];
    }
  }
}
