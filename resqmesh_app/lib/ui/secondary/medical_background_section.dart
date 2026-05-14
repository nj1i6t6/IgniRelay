import 'package:flutter/material.dart';

import 'package:ignirelay_app/app/models/medical_card.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/secondary/medical_card_controller.dart';
import 'package:ignirelay_app/ui/secondary/medical_card_fields.dart';

/// 醫療卡「醫療背景」區段 — 醫療狀況 / 過敏原（多筆）/ 目前藥物。
/// Stage 2B：由 medical_card_screen god file 拆出。
class MedicalBackgroundSection extends StatelessWidget {
  const MedicalBackgroundSection({super.key, required this.controller});

  final MedicalCardController controller;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MedicalSectionHeader(
            title: s.medicalSectionBackground,
            icon: Icons.medical_services_outlined),
        MedicalTextField(
          controller: controller,
          field: MedicalField.conditions,
          textController: controller.conditionsCtrl,
          label: s.medicalFieldConditions,
          hint: s.medicalHintConditions,
          icon: Icons.healing_outlined,
          maxLines: 2,
        ),
        _AllergySection(controller: controller),
        MedicalTextField(
          controller: controller,
          field: MedicalField.medications,
          textController: controller.medicationsCtrl,
          label: s.medicalFieldMedications,
          hint: s.medicalHintMedications,
          icon: Icons.medication_outlined,
          maxLines: 2,
        ),
      ],
    );
  }
}

class _AllergySection extends StatelessWidget {
  const _AllergySection({required this.controller});

  final MedicalCardController controller;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final allergies = controller.card.allergies;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_outlined,
                  color: Colors.white38, size: 18),
              const SizedBox(width: 8),
              Text(s.medicalAllergenLabel,
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const Spacer(),
              MedicalSosToggle(
                  controller: controller, field: MedicalField.allergies),
            ],
          ),
          const SizedBox(height: 8),
          ...allergies.asMap().entries.map((entry) {
            final i = entry.key;
            final a = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a2e),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${a.allergen} → ${a.reaction}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => controller.removeAllergy(i),
                    child: const Icon(Icons.close,
                        color: Colors.white38, size: 16),
                  ),
                ],
              ),
            );
          }),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _AllergyInput(
                  controller: controller.allergenCtrl,
                  hint: s.medicalAllergenHint,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: _AllergyInput(
                  controller: controller.reactionCtrl,
                  hint: s.medicalReactionHint,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => controller.addAllergy(
                  controller.allergenCtrl.text,
                  controller.reactionCtrl.text,
                  fallbackReaction: s.medicalReactionUnknown,
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.5)),
                  ),
                  child:
                      const Icon(Icons.add, color: Colors.redAccent, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AllergyInput extends StatelessWidget {
  const _AllergyInput({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white12),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent),
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: const Color(0xFF1a1a2e),
      ),
    );
  }
}
