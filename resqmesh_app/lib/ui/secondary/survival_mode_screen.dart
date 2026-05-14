import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:ignirelay_app/app/controllers/ble_scan_controller.dart';
import 'package:ignirelay_app/app/controllers/device_info_controller.dart';
import 'package:ignirelay_app/app/controllers/event_stream.dart';
import 'package:ignirelay_app/app/controllers/mesh_runtime_controller.dart';
import 'package:ignirelay_app/app/controllers/tier_manager.dart';
import 'package:ignirelay_app/app/services/event_store.dart';
import 'package:ignirelay_app/app/services/profile_repo.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/secondary/debug_log_viewer.dart';
import 'package:ignirelay_app/ui/secondary/survival_mode_controller.dart';

/// Stage 2A：本檔由 god file 拆出來後改為 thin shell。
/// 真正的 state + business logic 在 [SurvivalModeController]，
/// debug panel 抽出為獨立 widget [DebugLogViewer]。
class SurvivalModeScreen extends StatefulWidget {
  const SurvivalModeScreen({super.key});

  @override
  State<SurvivalModeScreen> createState() => _SurvivalModeScreenState();
}

class _SurvivalModeScreenState extends State<SurvivalModeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  SurvivalModeController? _controller;
  bool _showDebug = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= SurvivalModeController(
      mesh: context.read<MeshRuntimeController>(),
      deviceInfo: context.read<DeviceInfoController>(),
      tierManager: context.read<TierManager>(),
      eventStream: context.read<EventStream>(),
      bleScanController: context.read<BleScanController>(),
      eventStore: context.read<EventStore>(),
      profileRepo: context.read<ProfileRepo>(),
      meshReceivedLabel: (n) => context.l10n.survivalMeshReceived(n),
    )..init();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onToggleDataMule() async {
    final c = _controller!;
    final wasMule = c.isDataMule;
    final nowMule = await c.toggleDataMule();
    if (!wasMule && !nowMule && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.survivalDataMuleFailSnack),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _onToggleBle() async {
    final outcome = await _controller!.toggleBle(
      ensureBlePermissions: () async {
        final statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
          Permission.locationWhenInUse,
        ].request();
        return statuses.values.every((s) => s.isGranted || s.isLimited);
      },
    );
    if (!mounted) return;
    whenBleOutcome<void>(
      outcome,
      started: () {},
      stopped: () {},
      permissionDenied: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.survivalBleFailSnack('Missing BLE permissions')),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      },
      startFailed: (msg) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.survivalBleFailSnack(msg)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      },
    );
  }

  Future<void> _onExportLogs() async {
    try {
      final file = await _controller!.exportLogs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.survivalExportSuccess(file.path.split('/').last)),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.survivalExportFail(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final c = _controller!;
    final muleColor = c.isDataMule ? Colors.cyanAccent : Colors.white24;
    final batteryColor = c.batteryLevel < 0
        ? Colors.grey
        : c.batteryLevel < 20
            ? Colors.red
            : c.batteryLevel < 40
                ? Colors.orange
                : Colors.green;

    final tierLabel = context.read<TierManager>().getTierLabel(context.l10n);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Icon(
                  c.isDataMule ? Icons.router : Icons.bluetooth_audio,
                  key: ValueKey(c.isDataMule),
                  color: muleColor,
                  size: 80,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tierLabel,
                style: TextStyle(
                  color: muleColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (c.batteryLevel >= 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      c.batteryLevel > 80
                          ? Icons.battery_full
                          : c.batteryLevel > 20
                              ? Icons.battery_4_bar
                              : Icons.battery_alert,
                      color: batteryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        context.l10n.survivalBattery(c.batteryLevel),
                        style: TextStyle(color: batteryColor, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              LinearProgressIndicator(
                backgroundColor: Colors.grey[900],
                valueColor: AlwaysStoppedAnimation<Color>(
                  c.isDataMule ? Colors.cyan : Colors.white24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.survivalListening,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white12),
              Row(
                children: [
                  Expanded(
                    child: _ControlButton(
                      icon: Icons.router,
                      label: c.isDataMule ? context.l10n.survivalDataMuleDisable : context.l10n.survivalDataMuleEnable,
                      color: c.isDataMule ? Colors.cyan : Colors.white24,
                      onTap: _onToggleDataMule,
                      onInfoTap: () => _showDataMuleExplanation(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ControlButton(
                      icon: Icons.bluetooth,
                      label: c.isBleActive ? context.l10n.survivalBlePause : context.l10n.survivalBleResume,
                      color: c.isBleActive ? Colors.blueAccent : Colors.white24,
                      onTap: _onToggleBle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _StatChip(label: context.l10n.survivalStatsLocalEvents, value: '${c.totalEventCount}'),
                  const SizedBox(width: 8),
                  _StatChip(label: context.l10n.survivalStatsBleConnections, value: '${c.bleConnectedCount}'),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              if (c.recentEvents.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.survivalRecentEvents,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 6),
                ...c.recentEvents.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        e,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    )),
              ],
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => setState(() => _showDebug = !_showDebug),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _showDebug ? Icons.bug_report : Icons.bug_report_outlined,
                        color: Colors.amber,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _showDebug ? 'BLE Debug (tap to hide)' : 'BLE Debug (tap to show)',
                        style: const TextStyle(color: Colors.amber, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showDebug) ...[
                const SizedBox(height: 8),
                DebugLogViewer(
                  transportActive: c.mesh.transportActive,
                  connectedPeers: c.mesh.transportStats.connectedPeers,
                  seenEventsCount: c.mesh.transportStats.seenEventsCount,
                  sentCount: c.mesh.transportStats.sentCount,
                  receivedCount: c.mesh.transportStats.receivedCount,
                  gattLogs: c.gattServerLogs,
                  transportLogs: c.mesh.transportStats.debugLogs,
                  onExport: _onExportLogs,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDataMuleExplanation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Row(
          children: [
            const Icon(Icons.router, color: Colors.cyanAccent, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.survivalDataMuleDialogTitle,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          context.l10n.survivalDataMuleDialogContent,
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              context.l10n.survivalDataMuleDialogDismiss,
              style: const TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onInfoTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, style: TextStyle(color: color, fontSize: 12)),
            ),
            if (onInfoTap != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onInfoTap,
                child: Icon(Icons.info_outline, color: color, size: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
