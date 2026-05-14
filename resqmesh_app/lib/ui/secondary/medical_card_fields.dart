import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ignirelay_app/ui/secondary/medical_card_controller.dart';

// =============================================================================
// 醫療卡表單共用元件 — Stage 2B：由 medical_card_screen god file 拆出。
//
// 區段標題、SOS 廣播 toggle、通用文字 / 數字欄位。各 section widget 共用。
// =============================================================================

const _kFieldFill = Color(0xFF1a1a2e);

/// 區段標題列（icon + 標題 + divider）。
class MedicalSectionHeader extends StatelessWidget {
  const MedicalSectionHeader({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 12),
              child: Divider(color: Colors.white12),
            ),
          ),
        ],
      ),
    );
  }
}

/// 單一欄位的「SOS 廣播」開關。點擊切換 [MedicalCardController] 內對應 flag。
class MedicalSosToggle extends StatelessWidget {
  const MedicalSosToggle({
    super.key,
    required this.controller,
    required this.field,
  });

  final MedicalCardController controller;
  final String field;

  @override
  Widget build(BuildContext context) {
    final isOn = controller.card.sosFlags[field] ?? false;
    return GestureDetector(
      onTap: () => controller.toggleSosFlag(field),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isOn
              ? Colors.redAccent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cell_tower,
              color: isOn ? Colors.redAccent : Colors.white24,
              size: 16,
            ),
            const SizedBox(width: 2),
            Text(
              isOn ? 'ON' : 'OFF',
              style: TextStyle(
                color: isOn ? Colors.redAccent : Colors.white24,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration({
  required String label,
  required String hint,
  required IconData icon,
  String? suffix,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
    prefixIcon: Icon(icon, color: Colors.white38, size: 18),
    suffixText: suffix,
    suffixStyle: const TextStyle(color: Colors.white38, fontSize: 13),
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.white12),
      borderRadius: BorderRadius.circular(8),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.redAccent),
      borderRadius: BorderRadius.circular(8),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    filled: true,
    fillColor: _kFieldFill,
  );
}

/// 通用文字欄位 + 行末 SOS toggle。
class MedicalTextField extends StatelessWidget {
  const MedicalTextField({
    super.key,
    required this.controller,
    required this.field,
    required this.textController,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  final MedicalCardController controller;
  final String field;
  final TextEditingController textController;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: textController,
              maxLines: maxLines,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration:
                  _fieldDecoration(label: label, hint: hint, icon: icon),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: MedicalSosToggle(controller: controller, field: field),
          ),
        ],
      ),
    );
  }
}

/// 數字欄位（digitsOnly）+ 行末 SOS toggle。
class MedicalNumberField extends StatelessWidget {
  const MedicalNumberField({
    super.key,
    required this.controller,
    required this.field,
    required this.textController,
    required this.label,
    required this.hint,
    required this.icon,
    this.suffix,
  });

  final MedicalCardController controller;
  final String field;
  final TextEditingController textController;
  final String label;
  final String hint;
  final IconData icon;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: textController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _fieldDecoration(
                  label: label, hint: hint, icon: icon, suffix: suffix),
            ),
          ),
          const SizedBox(width: 8),
          MedicalSosToggle(controller: controller, field: field),
        ],
      ),
    );
  }
}
