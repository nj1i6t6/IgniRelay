import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/services/medical_card_repo.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/secondary/medical_background_section.dart';
import 'package:ignirelay_app/ui/secondary/medical_basic_section.dart';
import 'package:ignirelay_app/ui/secondary/medical_card_controller.dart';
import 'package:ignirelay_app/ui/secondary/medical_card_header.dart';
import 'package:ignirelay_app/ui/secondary/medical_emergency_section.dart';

/// Stage 2B：本檔由 god file 拆出後改為 thin shell。
/// 表單 state + load/save + Health Connect 匯入在 [MedicalCardController]；
/// 區段 UI 在 medical_*_section / medical_card_header / medical_card_fields。
class MedicalCardScreen extends StatefulWidget {
  const MedicalCardScreen({super.key});

  @override
  State<MedicalCardScreen> createState() => _MedicalCardScreenState();
}

class _MedicalCardScreenState extends State<MedicalCardScreen> {
  MedicalCardController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c ??= MedicalCardController(
      repo: context.read<MedicalCardRepo>(),
      identity: context.read<IdentityManager>(),
    )..load();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final outcome = await _c!.save();
    if (!mounted) return;
    switch (outcome) {
      case MedicalSaveOk():
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.medicalSavedSnack),
          backgroundColor: Colors.green,
        ));
        Navigator.of(context).pop(true);
      case MedicalSaveFail(:final error):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.medicalSaveFailSnack(error)),
          backgroundColor: Colors.red,
        ));
    }
  }

  void _onApplyPreset(Set<String> preset, String presetName) {
    _c!.applyPreset(preset);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.l10n.medicalPresetApplied(presetName)),
      backgroundColor: const Color(0xFF1a1a2e),
      duration: const Duration(seconds: 1),
    ));
  }

  Future<void> _onImportHealth() async {
    final outcome = await _c!.importFromHealthConnect();
    if (!mounted) return;
    final s = context.l10n;
    switch (outcome) {
      case HealthImportSdkUnavailable():
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.medicalHealthConnectRequired),
            content: Text(s.medicalHealthConnectInstallGuide),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(s.medicalHealthConnectDismiss),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _c!.installHealthConnect();
                },
                child: Text(s.medicalHealthConnectInstall),
              ),
            ],
          ),
        );
      case HealthImportAuthDenied():
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.medicalHealthConnectAuthFail),
            content: Text(s.medicalHealthConnectAuthGuide),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(s.medicalHealthConnectDismiss),
              ),
            ],
          ),
        );
      case HealthImportNoData():
        _snack(s.medicalHealthConnectNoData, Colors.orange);
      case HealthImportImported(:final count):
        _snack(s.medicalHealthConnectImported(count), Colors.green);
      case HealthImportNoNewData():
        _snack(s.medicalHealthConnectNoNewData, Colors.orange);
      case HealthImportFailure(:final error):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.medicalHealthConnectFailSnack(error)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
    }
  }

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _c!;
    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      appBar: AppBar(
        title: Text(context.l10n.medicalTitle,
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1a1a2e),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          if (c.loading) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.redAccent));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              MedicalCardHeader(
                controller: c,
                onApplyPreset: _onApplyPreset,
                onImportHealth: _onImportHealth,
              ),
              const SizedBox(height: 20),
              MedicalBasicSection(controller: c),
              const SizedBox(height: 20),
              MedicalBackgroundSection(controller: c),
              const SizedBox(height: 20),
              MedicalEmergencySection(controller: c),
            ],
          );
        },
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          if (c.loading) return const SizedBox.shrink();
          return SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: c.saving ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: c.saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save, size: 18),
                  label: Text(
                    c.saving
                        ? context.l10n.medicalSaving
                        : context.l10n.medicalSaveButton,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
