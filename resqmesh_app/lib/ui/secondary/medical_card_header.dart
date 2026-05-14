import 'dart:io';

import 'package:flutter/material.dart';

import 'package:ignirelay_app/app/models/medical_card.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/secondary/medical_card_controller.dart';

/// 醫療卡表單頁首 — SOS 廣播說明、快速預設列、Health Connect 匯入按鈕。
/// Stage 2B：由 medical_card_screen god file 拆出。
///
/// 預設套用 / Health 匯入都會觸發 snackbar / dialog，故交由 shell 經
/// [onApplyPreset] / [onImportHealth] 處理；本 widget 只負責呈現。
class MedicalCardHeader extends StatelessWidget {
  const MedicalCardHeader({
    super.key,
    required this.controller,
    required this.onApplyPreset,
    required this.onImportHealth,
  });

  final MedicalCardController controller;
  final void Function(Set<String> preset, String presetName) onApplyPreset;
  final VoidCallback onImportHealth;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SOS 廣播說明
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: Colors.redAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.medicalSosInfo,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 快速預設列：label 一行 + chips 用 Wrap（英文 / 大字自動折行）
        Text(s.medicalPresetLabel,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _PresetChip(
              label: s.medicalPresetMinimal,
              preset: MedicalField.presetMinimal,
              controller: controller,
              onApplyPreset: onApplyPreset,
            ),
            _PresetChip(
              label: s.medicalPresetRecommended,
              preset: MedicalField.presetRecommended,
              controller: controller,
              onApplyPreset: onApplyPreset,
            ),
            _PresetChip(
              label: s.medicalPresetFull,
              preset: MedicalField.presetFull,
              controller: controller,
              onApplyPreset: onApplyPreset,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 從系統健康資料匯入（僅 Android）
        if (Platform.isAndroid)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.cyanAccent,
              side: const BorderSide(color: Colors.cyanAccent),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: onImportHealth,
            icon: const Icon(Icons.download, size: 18),
            label: Text(s.medicalHealthImportButton,
                style: const TextStyle(fontSize: 13)),
          ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.preset,
    required this.controller,
    required this.onApplyPreset,
  });

  final String label;
  final Set<String> preset;
  final MedicalCardController controller;
  final void Function(Set<String> preset, String presetName) onApplyPreset;

  @override
  Widget build(BuildContext context) {
    final isActive = controller.isPresetActive(preset);
    return GestureDetector(
      onTap: () => onApplyPreset(preset, label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.redAccent.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? Colors.redAccent : Colors.white24,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.redAccent : Colors.white54,
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
