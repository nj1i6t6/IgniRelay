import 'package:flutter/material.dart';

import 'package:ignirelay_app/app/models/medical_card.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/secondary/medical_card_controller.dart';
import 'package:ignirelay_app/ui/secondary/medical_card_fields.dart';

/// 醫療卡「急救資訊」區段 — 緊急聯絡人 / 器官捐贈意願 / 主要語言。
/// Stage 2B：由 medical_card_screen god file 拆出。
class MedicalEmergencySection extends StatelessWidget {
  const MedicalEmergencySection({super.key, required this.controller});

  final MedicalCardController controller;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MedicalSectionHeader(
            title: s.medicalSectionEmergency,
            icon: Icons.emergency_outlined),
        _EmergencyContactField(controller: controller),
        _OrganDonorField(controller: controller),
        MedicalTextField(
          controller: controller,
          field: MedicalField.primaryLanguage,
          textController: controller.languageCtrl,
          label: s.medicalFieldPrimaryLanguage,
          hint: s.medicalHintLanguage,
          icon: Icons.language,
        ),
      ],
    );
  }
}

class _EmergencyContactField extends StatelessWidget {
  const _EmergencyContactField({required this.controller});

  final MedicalCardController controller;

  InputDecoration _decoration(
      BuildContext context, String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.white38, size: 18),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.ecPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _decoration(context, s.medicalEcPhoneLabel,
                      '0912-345-678', Icons.phone_outlined),
                ),
              ),
              const SizedBox(width: 8),
              MedicalSosToggle(
                  controller: controller,
                  field: MedicalField.emergencyContact),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.ecRelationCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _decoration(context, s.medicalEcRelationLabel,
                      s.medicalEcRelationHint, Icons.people_outline),
                ),
              ),
              // 佔位，與電話欄的 toggle 對齊。
              const SizedBox(width: 8),
              const SizedBox(width: 52),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrganDonorField extends StatelessWidget {
  const _OrganDonorField({required this.controller});

  final MedicalCardController controller;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a2e),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.volunteer_activism_outlined,
                      color: Colors.white38, size: 18),
                  const SizedBox(width: 12),
                  Text(s.medicalOrganDonorLabel,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13)),
                  const Spacer(),
                  DropdownButton<bool?>(
                    value: controller.card.organDonor,
                    dropdownColor: const Color(0xFF1a1a2e),
                    underline: const SizedBox(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    items: [
                      DropdownMenuItem(
                          value: null,
                          child: Text(s.medicalOrganDonorNone)),
                      DropdownMenuItem(
                          value: true, child: Text(s.medicalOrganDonorYes)),
                      DropdownMenuItem(
                          value: false, child: Text(s.medicalOrganDonorNo)),
                    ],
                    onChanged: controller.setOrganDonor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          MedicalSosToggle(
              controller: controller, field: MedicalField.organDonor),
        ],
      ),
    );
  }
}
