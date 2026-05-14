import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ignirelay_app/app/controllers/ble_scan_controller.dart';
import 'package:ignirelay_app/app/controllers/device_info_controller.dart';
import 'package:ignirelay_app/app/controllers/event_stream.dart';
import 'package:ignirelay_app/app/controllers/mesh_runtime_controller.dart';
import 'package:ignirelay_app/app/controllers/tier_manager.dart';
import 'package:ignirelay_app/app/services/event_store.dart';
import 'package:ignirelay_app/app/services/profile_repo.dart';

/// Stage 2A 拆分：survival_mode_screen 的純 state + business logic 容器。
///
/// 遵循 `MapScreenController` 模式：
///   - state 集中在 ChangeNotifier，UI widget 不再持有業務 state。
///   - 不持有 BuildContext / 不直接做 UI side effect；snackbar / 對話框由 widget
///     根據 outcome 決定。
///   - 所有依賴透過 constructor 注入，無 singleton 入口。
class SurvivalModeController extends ChangeNotifier {
  SurvivalModeController({
    required MeshRuntimeController mesh,
    required DeviceInfoController deviceInfo,
    required TierManager tierManager,
    required EventStream eventStream,
    required BleScanController bleScanController,
    required EventStore eventStore,
    required ProfileRepo profileRepo,
    String Function(int byteLen)? meshReceivedLabel,
  })  : _mesh = mesh,
        _deviceInfo = deviceInfo,
        _tierManager = tierManager,
        _eventStream = eventStream,
        _bleScanController = bleScanController,
        _eventStore = eventStore,
        _profileRepo = profileRepo,
        _meshReceivedLabel = meshReceivedLabel;

  final MeshRuntimeController _mesh;
  final DeviceInfoController _deviceInfo;
  final TierManager _tierManager;
  final EventStream _eventStream;
  final BleScanController _bleScanController;
  final EventStore _eventStore;
  final ProfileRepo _profileRepo;
  final String Function(int byteLen)? _meshReceivedLabel;

  bool _disposed = false;

  // 模式
  bool _isDataMule = false;
  bool _isBleActive = false;
  int _batteryLevel = -1;

  // 統計
  int _totalEventCount = 0;
  int _bleConnectedCount = 0;

  // 最近 Mesh 事件
  final List<String> _recentEvents = <String>[];

  // GATT debug
  final List<String> _gattServerLogs = <String>[];

  StreamSubscription? _bleSub;
  StreamSubscription? _gattSub;
  StreamSubscription<TransportState>? _transportStateSub;
  Timer? _statsTimer;

  bool get isDataMule => _isDataMule;
  bool get isBleActive => _isBleActive;
  int get batteryLevel => _batteryLevel;
  int get totalEventCount => _totalEventCount;
  int get bleConnectedCount => _bleConnectedCount;
  List<String> get recentEvents => List.unmodifiable(_recentEvents);
  List<String> get gattServerLogs => List.unmodifiable(_gattServerLogs);

  MeshRuntimeController get mesh => _mesh;
  EventStream get eventStream => _eventStream;

  /// 由 widget 在 didChangeDependencies 第一次呼叫。
  void init() {
    _statsTimer ??= Timer.periodic(const Duration(seconds: 3), (_) => _refreshDebug());
    _checkCapabilities();
    _loadStats();
    _profileRepo.purgeDebugLogs();
    _startMeshListening();
    _startGattListener();
  }

  Future<String> tierLabel(String Function(TierManager) labelOf) async {
    return labelOf(_tierManager);
  }

  String getTierLabelFrom(String Function(TierManager) labelOf) {
    return labelOf(_tierManager);
  }

  Future<void> _checkCapabilities() async {
    int battery = -1;
    try {
      battery = await _deviceInfo.batteryLevel();
    } catch (_) {
      battery = -1;
    }
    if (_disposed) return;
    if (battery >= 0) {
      _tierManager.updateBattery(battery);
    }
    _batteryLevel = battery;
    notifyListeners();
  }

  Future<void> _loadStats() async {
    final events = await _eventStore.queryRecent(limit: 50);
    if (_disposed) return;

    final recentLabels = events.take(5).map((e) {
      final urgency = e['urgency'] as int? ?? 0;
      final labels = ['INFO', 'RESOURCE', 'SOS_YELLOW', 'SOS_RED'];
      final ts = e['hlc_timestamp'] as int? ?? 0;
      final time = DateTime.fromMillisecondsSinceEpoch(ts);
      return '[${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}] ${labels[urgency]}';
    }).toList();

    _totalEventCount = events.length;
    _recentEvents
      ..clear()
      ..addAll(recentLabels);
    notifyListeners();
  }

  void _startMeshListening() {
    _isBleActive = _mesh.transportActive;
    notifyListeners();

    _transportStateSub = _mesh.transportStateChanges.listen((state) {
      if (_disposed) return;
      _isBleActive = state == TransportState.running;
      notifyListeners();
    });

    _bleSub = _eventStream.rawEvents.listen((event) {
      if (_disposed) return;
      _bleConnectedCount++;
      final label = _meshReceivedLabel?.call(event.data.length) ??
          '[MESH] ${event.data.length} bytes';
      _recentEvents.insert(0, label);
      if (_recentEvents.length > 5) _recentEvents.removeLast();
      notifyListeners();
    });
  }

  void _startGattListener() {
    _gattSub = _bleScanController.rawEventStream.listen((event) {
      if (_disposed) return;
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
        _gattServerLogs.add(log);
        if (_gattServerLogs.length > 30) _gattServerLogs.removeAt(0);
        notifyListeners();
        _profileRepo.writeDebugLog('GATT', log);
      }
    }, onError: (e) {
      debugPrint('[GATT EventChannel] error: $e');
    });
  }

  void _refreshDebug() {
    _loadStats();
  }

  /// 切換 data mule。回傳是否切到 enabled 狀態；若啟動失敗回傳 false。
  Future<bool> toggleDataMule() async {
    if (_isDataMule) {
      try {
        await _mesh.stopAllServices();
      } catch (_) {}
      _isDataMule = false;
      notifyListeners();
      return false;
    }

    try {
      await _mesh.startForegroundService();
    } catch (_) {}

    bool success = false;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        success = await _mesh.startDataMuleMode();
        if (success) break;
      } catch (_) {
        success = false;
      }
      if (!success && attempt < 2) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (_disposed) return false;

    if (success) {
      _isDataMule = true;
      notifyListeners();
    }
    return success;
  }

  /// 切換 BLE。回傳 outcome；UI 端決定 snackbar / 權限說明。
  Future<BleToggleOutcome> toggleBle({
    required Future<bool> Function() ensureBlePermissions,
  }) async {
    if (_isBleActive) {
      try {
        await _mesh.stopTransport();
      } catch (_) {}
      if (_disposed) return BleToggleOutcome.stopped;
      _isBleActive = false;
      notifyListeners();
      return BleToggleOutcome.stopped;
    }

    final permsOk = await ensureBlePermissions();
    if (_disposed) return BleToggleOutcome.permissionDenied;
    if (!permsOk) {
      return BleToggleOutcome.permissionDenied;
    }
    try {
      try {
        await _mesh.startForegroundService();
      } catch (_) {}
      await _mesh.startTransport();
      if (_disposed) return BleToggleOutcome.started;
      _isBleActive = true;
      notifyListeners();
      return BleToggleOutcome.started;
    } catch (e) {
      debugPrint('[BLE Toggle] start failed: $e');
      return BleToggleOutcome.startFailed(e.toString());
    }
  }

  /// 將目前狀態 + DB / 記憶體中的 debug log dump 成一個檔案。
  /// 回傳寫入的檔案路徑；任何錯誤都丟出 exception 由 widget 處理 snackbar。
  Future<File> exportLogs() async {
    final s = _mesh.transportStats;
    final buf = StringBuffer();
    buf.writeln('=== IgniRelay Debug Log ===');
    buf.writeln('Time: ${DateTime.now().toIso8601String()}');
    buf.writeln('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    buf.writeln('');

    String manufacturer = 'unknown';
    try {
      manufacturer = await _deviceInfo.manufacturer();
    } catch (_) {}

    buf.writeln('--- Device Info ---');
    buf.writeln('manufacturer: $manufacturer');
    buf.writeln('platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    buf.writeln('');

    buf.writeln('--- Transport State ---');
    buf.writeln('syncProtocol: v2 (WriteBloom+NotifyDiff)');
    buf.writeln('active: ${_mesh.transportActive}');
    buf.writeln('connectedPeers: ${s.connectedPeers}');
    buf.writeln('seenEvents: ${s.seenEventsCount}');
    buf.writeln('sent: ${s.sentCount}');
    buf.writeln('recv: ${s.receivedCount}');
    buf.writeln('');

    if (Platform.isAndroid) {
      try {
        final gattStatus = await _mesh.gattServerStatus();
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

    final dbLogs = await _profileRepo.exportDebugLogs();
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

    buf.writeln('--- In-Memory EventStream Logs (${_eventStream.debugLogs.length}) ---');
    for (final l in _eventStream.debugLogs) {
      buf.writeln(l);
    }

    final downloadDir = Directory('/storage/emulated/0/Download');
    final fallbackDir = await getApplicationDocumentsDirectory();
    final dir = (Platform.isAndroid && await downloadDir.exists()) ? downloadDir : fallbackDir;
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${dir.path}/ignirelay_debug_$ts.txt');
    await file.writeAsString(buf.toString());
    return file;
  }

  @override
  void dispose() {
    _disposed = true;
    _bleSub?.cancel();
    _gattSub?.cancel();
    _transportStateSub?.cancel();
    _statsTimer?.cancel();
    super.dispose();
  }
}

/// `toggleBle()` 的 outcome enum。widget 端對應呈現 snackbar。
sealed class BleToggleOutcome {
  const BleToggleOutcome();

  static const BleToggleOutcome started = _BleToggleStarted();
  static const BleToggleOutcome stopped = _BleToggleStopped();
  static const BleToggleOutcome permissionDenied = _BleTogglePermissionDenied();

  factory BleToggleOutcome.startFailed(String message) = _BleToggleStartFailed;
}

class _BleToggleStarted extends BleToggleOutcome {
  const _BleToggleStarted();
}

class _BleToggleStopped extends BleToggleOutcome {
  const _BleToggleStopped();
}

class _BleTogglePermissionDenied extends BleToggleOutcome {
  const _BleTogglePermissionDenied();
}

class _BleToggleStartFailed extends BleToggleOutcome {
  const _BleToggleStartFailed(this.message);
  final String message;
}

/// pattern-match helpers — 避免 widget 端 import 私有 class。
T whenBleOutcome<T>(
  BleToggleOutcome outcome, {
  required T Function() started,
  required T Function() stopped,
  required T Function() permissionDenied,
  required T Function(String message) startFailed,
}) {
  return switch (outcome) {
    _BleToggleStarted() => started(),
    _BleToggleStopped() => stopped(),
    _BleTogglePermissionDenied() => permissionDenied(),
    _BleToggleStartFailed(:final message) => startFailed(message),
  };
}
