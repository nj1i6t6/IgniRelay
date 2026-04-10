import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../mesh/mesh_transport.dart';
import '../mesh/mesh_event_handler.dart';
import '../mesh/native_bridge.dart';
import '../mesh/event_manager.dart';
import '../mesh/tier_manager.dart';
import '../db/database_helper.dart';
import '../l10n/generated/app_localizations.dart';

class SurvivalModeScreen extends StatefulWidget {
  const SurvivalModeScreen({super.key});

  @override
  State<SurvivalModeScreen> createState() => _SurvivalModeScreenState();
}

class _SurvivalModeScreenState extends State<SurvivalModeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // 模式
  bool _isDataMule = false;
  bool _isBleActive = false;
  int _batteryLevel = -1;

  // 統計
  int _totalEventCount = 0;
  int _bleConnectedCount = 0;

  // 最近 Mesh 事件
  List<String> _recentEvents = [];

  // Debug
  bool _showDebug = false;
  final List<String> _gattServerLogs = [];
  StreamSubscription? _gattSub;

  late final MeshTransport _transport;
  StreamSubscription? _bleSub;
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    _transport = Provider.of<MeshTransport>(context, listen: false);
    _checkCapabilities();
    _loadStats();
    DatabaseHelper().purgeDebugLogs(); // 清理 24h 前的日誌
    _startMeshListening();
    _startGattListener();
    _statsTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _refreshDebug());
  }

  Future<void> _checkCapabilities() async {
    int battery = -1;
    try {
      battery = await NativeBridge.getBatteryLevel();
    } catch (_) {
      battery = -1;
    }
    if (battery >= 0) {
      TierManager().updateBattery(battery);
    }
    if (mounted) {
      setState(() {
        _batteryLevel = battery;
      });
    }
  }

  Future<void> _loadStats() async {
    final events = await EventManager().getRecentEvents(limit: 50);
    final recentLabels = events.take(5).map((e) {
      final urgency = e['urgency'] as int? ?? 0;
      final labels = ['INFO', 'RESOURCE', 'SOS_YELLOW', 'SOS_RED'];
      final ts = e['hlc_timestamp'] as int? ?? 0;
      final time = DateTime.fromMillisecondsSinceEpoch(ts);
      return '[${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}] ${labels[urgency]}';
    }).toList();

    if (mounted) {
      setState(() {
        _totalEventCount = events.length;
        _recentEvents = recentLabels;
      });
    }
  }

  void _startMeshListening() {
    // Transport 已在 main 啟動時自動開始，這裡同步 UI 狀態
    _isBleActive = _transport.isActive;

    // 監聽 transport 狀態變化，同步 BLE 按鈕顯示
    _transport.onStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isBleActive = state == TransportState.running;
      });
    });

    _bleSub = MeshEventHandler().events.listen((event) {
      if (!mounted) return;
      setState(() {
        _bleConnectedCount++;
        _recentEvents.insert(0, S.of(context)!.survivalMeshReceived(event.data.length));
        if (_recentEvents.length > 5) _recentEvents.removeLast();
      });
    });
  }

  void _startGattListener() {
    // 監聽 Kotlin GATT Server 透過 EventChannel 送來的原始資料
    // 使用 NativeBridge 共享 stream，避免重複 receiveBroadcastStream() 衝突
    _gattSub = NativeBridge.nativeEventStream.listen((event) {
      if (!mounted) return;
      if (event is Map) {
        final type = event['type'];
        final device = event['device'] ?? '?';
        String log;
        if (type == 'ble_data') {
          final data = event['data'];
          final len = data is List ? data.length : 0;
          log = '[GATT-RX] $device: $len bytes';
        } else if (type == 'ble_peer') {
          log = '[GATT] $device ${event['state']}';
        } else {
          log = '[GATT] $type from $device';
        }
        setState(() {
          _gattServerLogs.add(log);
          if (_gattServerLogs.length > 30) _gattServerLogs.removeAt(0);
        });
        DatabaseHelper().writeDebugLog('GATT', log);
      }
    }, onError: (e) {
      debugPrint('[GATT EventChannel] error: $e');
    });
  }

  void _refreshDebug() {
    _loadStats();
    if (_showDebug && mounted) setState(() {});
  }

  Future<void> _toggleDataMule() async {
    if (_isDataMule) {
      try {
        await NativeBridge.stopAllServices();
      } catch (_) {}
      setState(() => _isDataMule = false);
    } else {
      // 確保前景服務先啟動，避免 race condition 導致閃退
      try {
        await NativeBridge.startMeshForegroundService();
      } catch (_) {}

      // 帶重試機制（首次安裝後服務可能需要時間綁定）
      bool success = false;
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          success = await NativeBridge.startAndroidDataMuleMode();
          if (success) break;
        } catch (_) {
          success = false;
        }
        if (!success && attempt < 2) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      if (success) {
        setState(() => _isDataMule = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context)!.survivalDataMuleFailSnack),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleBle() async {
    if (_isBleActive) {
      try {
        await _transport.stop();
      } catch (_) {}
      setState(() => _isBleActive = false);
    } else {
      try {
        // 確保 BLE 權限已授權，避免無權限啟動 crash
        final statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
          Permission.locationWhenInUse,
        ].request();
        final allGranted = statuses.values.every(
          (s) => s.isGranted || s.isLimited,
        );
        if (!allGranted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context)!.survivalBleFailSnack('Missing BLE permissions')),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
        // 確保前景服務啟動，防止背景被系統殺掉
        try {
          await NativeBridge.startMeshForegroundService();
        } catch (_) {}
        await _transport.initialize();
        await _transport.start();
        setState(() => _isBleActive = true);
      } catch (e) {
        debugPrint('[BLE Toggle] start failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context)!.survivalBleFailSnack(e.toString())),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  Future<void> _exportLogs() async {
    try {
      final s = _transport.stats;
      final buf = StringBuffer();
      buf.writeln('=== IgniRelay Debug Log ===');
      buf.writeln('Time: ${DateTime.now().toIso8601String()}');
      buf.writeln('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
      buf.writeln('');

      // 裝置資訊（方便跨設備比對日誌）
      String manufacturer = 'unknown';
      try {
        manufacturer = await NativeBridge.getManufacturer();
      } catch (_) {}

      buf.writeln('--- Device Info ---');
      buf.writeln('manufacturer: $manufacturer');
      buf.writeln('platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
      buf.writeln('');

      buf.writeln('--- Transport State ---');
      buf.writeln('syncProtocol: v2 (WriteBloom+NotifyDiff)');
      buf.writeln('active: ${_transport.isActive}');
      buf.writeln('connectedPeers: ${s.connectedPeers}');
      buf.writeln('seenEvents: ${s.seenEventsCount}');
      buf.writeln('sent: ${s.sentCount}');
      buf.writeln('recv: ${s.receivedCount}');
      buf.writeln('');

      // 持久 GATT Server 狀態（不依賴 log buffer，確保不會被擠掉）
      if (Platform.isAndroid) {
        try {
          final gattStatus = await NativeBridge.getGattServerStatus();
          buf.writeln('--- GATT Server Status ---');
          buf.writeln('serviceReady: ${gattStatus['ready']}');
          buf.writeln('serviceStatus: ${gattStatus['status']}');
          buf.writeln('');
        } catch (_) {}
      }

      buf.writeln('--- GATT Server Logs (${_gattServerLogs.length}) ---');
      for (final l in _gattServerLogs) {
        buf.writeln(l);
      }
      buf.writeln('');

      // 從 DB 匯出全量持久化日誌（不受記憶體 buffer 80 筆限制）
      final dbLogs = await DatabaseHelper().exportDebugLogs();
      buf.writeln('--- Persistent DB Logs (${dbLogs.length}) ---');
      for (final row in dbLogs) {
        final ts = row['timestamp'] as int? ?? 0;
        final src = row['source'] as String? ?? '?';
        final msg = row['message'] as String? ?? '';
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        final timeStr =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
        buf.writeln('[$timeStr][$src] $msg');
      }
      buf.writeln('');

      buf.writeln('--- In-Memory Transport Logs (${s.debugLogs.length}) ---');
      for (final l in s.debugLogs) {
        buf.writeln(l);
      }
      buf.writeln('');

      buf.writeln('--- In-Memory MeshEventHandler Logs (${MeshEventHandler().debugLogs.length}) ---');
      for (final l in MeshEventHandler().debugLogs) {
        buf.writeln(l);
      }

      // 存到公開的「下載」資料夾，檔案管理員可直接看到
      final downloadDir = Directory('/storage/emulated/0/Download');
      final fallbackDir = await getApplicationDocumentsDirectory();
      final dir = (Platform.isAndroid && await downloadDir.exists()) ? downloadDir : fallbackDir;
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final file = File('${dir.path}/ignirelay_debug_$ts.txt');
      await file.writeAsString(buf.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context)!.survivalExportSuccess(file.path.split('/').last)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context)!.survivalExportFail(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final muleColor = _isDataMule ? Colors.cyanAccent : Colors.white24;
    final batteryColor = _batteryLevel < 0
        ? Colors.grey
        : _batteryLevel < 20
            ? Colors.red
            : _batteryLevel < 40
                ? Colors.orange
                : Colors.green;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // 模式圖示
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Icon(
                  _isDataMule ? Icons.router : Icons.bluetooth_audio,
                  key: ValueKey(_isDataMule),
                  color: muleColor,
                  size: 80,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                TierManager().getTierLabel(S.of(context)!),
                style: TextStyle(
                  color: muleColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // 電量顯示
              if (_batteryLevel >= 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _batteryLevel > 80
                          ? Icons.battery_full
                          : _batteryLevel > 20
                              ? Icons.battery_4_bar
                              : Icons.battery_alert,
                      color: batteryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        S.of(context)!.survivalBattery(_batteryLevel),
                        style: TextStyle(color: batteryColor, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 24),

              // 進度條
              LinearProgressIndicator(
                backgroundColor: Colors.grey[900],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isDataMule ? Colors.cyan : Colors.white24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                S.of(context)!.survivalListening,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),

              const SizedBox(height: 24),
              const Divider(color: Colors.white12),

              // 控制按鈕
              Row(
                children: [
                  Expanded(
                    child: _ControlButton(
                      icon: Icons.router,
                      label: _isDataMule ? S.of(context)!.survivalDataMuleDisable : S.of(context)!.survivalDataMuleEnable,
                      color: _isDataMule ? Colors.cyan : Colors.white24,
                      onTap: _toggleDataMule,
                      onInfoTap: () => _showDataMuleExplanation(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ControlButton(
                      icon: Icons.bluetooth,
                      label: _isBleActive ? S.of(context)!.survivalBlePause : S.of(context)!.survivalBleResume,
                      color: _isBleActive ? Colors.blueAccent : Colors.white24,
                      onTap: _toggleBle,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 統計
              Row(
                children: [
                  _StatChip(label: S.of(context)!.survivalStatsLocalEvents, value: '$_totalEventCount'),
                  const SizedBox(width: 8),
                  _StatChip(label: S.of(context)!.survivalStatsBleConnections, value: '$_bleConnectedCount'),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: Colors.white12),

              // 最近事件
              if (_recentEvents.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    S.of(context)!.survivalRecentEvents,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 6),
                ..._recentEvents.map((e) => Padding(
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

              // ── Debug Panel Toggle ──
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
                        color: Colors.amber, size: 16,
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

              // ── Debug Panel Content ──
              if (_showDebug) ...[
                const SizedBox(height: 8),
                _buildDebugPanel(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebugPanel() {
    final s = _transport.stats;
    final logs = s.debugLogs;
    final gattLogs = _gattServerLogs;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 匯出日誌按鈕 ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.withValues(alpha: 0.2),
                foregroundColor: Colors.amber,
                side: const BorderSide(color: Colors.amber),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: _exportLogs,
              icon: const Icon(Icons.download, size: 16),
              label: Text(S.of(context)!.survivalExportButton, style: const TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(height: 10),

          // Transport State
          const Text('Transport State', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          _debugRow('active', '${_transport.isActive}'),
          _debugRow('connected peers', '${s.connectedPeers}'),
          _debugRow('seenEvents (mem)', '${s.seenEventsCount}'),
          _debugRow('sent total', '${s.sentCount}'),
          _debugRow('recv total', '${s.receivedCount}'),

          const SizedBox(height: 8),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),

          // GATT Server Logs
          Row(
            children: [
              const Text('GATT Server', style: TextStyle(color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${gattLogs.length} events', style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          if (gattLogs.isEmpty)
            const Text('(no GATT events yet)', style: TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace'))
          else
            ...gattLogs.reversed.take(10).map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Text(l, style: const TextStyle(color: Colors.cyan, fontSize: 9, fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.ellipsis),
            )),

          const SizedBox(height: 8),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),

          // Transport Debug Logs
          Row(
            children: [
              const Text('Transport Logs', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${logs.length} entries', style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          if (logs.isEmpty)
            const Text('(no logs yet)', style: TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace'))
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                reverse: true,
                itemCount: logs.length,
                itemBuilder: (_, i) {
                  final log = logs[logs.length - 1 - i];
                  Color c = Colors.greenAccent.withValues(alpha: 0.7);
                  if (log.contains('ERROR')) c = Colors.red;
                  else if (log.contains('SKIP')) c = Colors.orange;
                  else if (log.contains('SENT')) c = Colors.lightBlueAccent;
                  else if (log.contains('RECV')) c = Colors.purpleAccent;
                  else if (log.contains('SCAN') || log.contains('BLOOM')) c = Colors.yellow;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Text(log, style: TextStyle(color: c, fontSize: 9, fontFamily: 'monospace'), maxLines: 2, overflow: TextOverflow.ellipsis),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _debugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
        ],
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
              child: Text(S.of(context)!.survivalDataMuleDialogTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
        content: Text(
          S.of(context)!.survivalDataMuleDialogContent,
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.of(context)!.survivalDataMuleDialogDismiss, style: const TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    _gattSub?.cancel();
    _statsTimer?.cancel();
    super.dispose();
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
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
