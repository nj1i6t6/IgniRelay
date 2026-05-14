import 'package:flutter/material.dart';

import 'package:ignirelay_app/app/models/medical_card.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/secondary/medical_card_controller.dart';
import 'package:ignirelay_app/ui/secondary/medical_card_fields.dart';

/// 醫療卡「基本生理」區段 — 姓名 / 年齡 / 身高 / 體重 / 血型。
/// Stage 2B：由 medical_card_screen god file 拆出。
class MedicalBasicSection extends StatelessWidget {
  const MedicalBasicSection({super.key, required this.controller});

  final MedicalCardController controller;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MedicalSectionHeader(
            title: s.medicalSectionBasic, icon: Icons.person_outline),
        MedicalTextField(
          controller: controller,
          field: MedicalField.name,
          textController: controller.nameCtrl,
          label: s.medicalFieldName,
          hint: s.medicalHintName,
          icon: Icons.badge_outlined,
        ),
        MedicalNumberField(
          controller: controller,
          field: MedicalField.age,
          textController: controller.ageCtrl,
          label: s.medicalFieldAge,
          hint: s.medicalHintAge,
          icon: Icons.cake_outlined,
          suffix: s.medicalSuffixAge,
        ),
        MedicalNumberField(
          controller: controller,
          field: MedicalField.heightCm,
          textController: controller.heightCtrl,
          label: s.medicalFieldHeight,
          hint: s.medicalHintHeight,
          icon: Icons.height,
          suffix: s.medicalSuffixHeight,
        ),
        MedicalNumberField(
          controller: controller,
          field: MedicalField.weightKg,
          textController: controller.weightCtrl,
          label: s.medicalFieldWeight,
          hint: s.medicalHintWeight,
          icon: Icons.monitor_weight_outlined,
          suffix: s.medicalSuffixWeight,
        ),
        _BloodTypeField(controller: controller),
      ],
    );
  }
}

class _BloodTypeField extends StatelessWidget {
  const _BloodTypeField({required this.controller});

  final MedicalCardController controller;

  @override
  Widget build(BuildContext context) {
    final card = controller.card;
    final value = MedicalCardController.bloodTypes.contains(card.bloodType)
        ? card.bloodType
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: value,
              dropdownColor: const Color(0xFF1a1a2e),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: context.l10n.medicalFieldBloodType,
                labelStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.bloodtype_outlined,
                    color: Colors.white38, size: 18),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white12),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.redAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                filled: true,
                fillColor: const Color(0xFF1a1a2e),
              ),
              items: MedicalCardController.bloodTypes.map((bt) {
                return DropdownMenuItem(
                  value: bt,
                  child: Text(
                      bt.isEmpty ? context.l10n.medicalBloodTypeNone : bt),
                );
              }).toList(),
              onChanged: (v) => controller.setBloodType(v ?? ''),
            ),
          ),
          const SizedBox(width: 8),
          MedicalSosToggle(
              controller: controller, field: MedicalField.bloodType),
        ],
      ),
    );
  }
}
