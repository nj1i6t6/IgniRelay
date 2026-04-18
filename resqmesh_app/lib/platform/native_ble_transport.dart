import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ignirelay_app/app/mesh/ble_manager.dart';
import 'package:ignirelay_app/app/mesh/event_manager.dart';
import 'package:ignirelay_app/platform/mesh_transport.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/platform/native_bridge.dart';
import 'package:ignirelay_app/app/mesh/triage_queue.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';

/// NativeBleTransport — 完整的自研 BLE Mesh Transport
///
/// 整合雙角色：
/// - Central（NativeBridge 掃描）：由 BleManager 處理
/// - Peripheral（Native GATT Server）：由 NativeBridge EventChannel 接收
///
/// 兩條路徑收到的資料都統一交給 MeshEventHandler 處理。
class NativeBleTransport implements MeshTransport {
  static final NativeBleTransport _instance = NativeBleTransport._internal();
  factory NativeBleTransport() => _instance;
  NativeBleTransport._internal();

  final BleManager _bleManager = BleManager();
  final MeshEventHandler _eventHandler = MeshEventHandler();

  // Stream controllers (橋接 BleManager + GATT Server 的事件)
  final _dataController = StreamController<MeshDataReceived>.broadcast();
  final _peerConnectedController = StreamController<String>.broadcast();
  final _peerDisconnectedController = StreamController<String>.broadcast();
  final _stateController = StreamController<TransportState>.broadcast();

  StreamSubscription? _bleEventSub;
  StreamSubscription? _gattServerDataSub;
  StreamSubscription? _gattServerPeerSub;

  @override
  Future<void> initialize() async {
    _stateController.add(TransportState.stopped);
  }

  @override
  Future<void> start() async {
    _stateController.add(TransportState.starting);

    // ── 1. 訂閱 BleManager 事件（Central 角色）──
    _bleEventSub?.cancel();
    _bleEventSub = _bleManager.events.listen((event) {
      switch (event.type) {
        case 'connected':
          _peerConnectedController.add(event.deviceId);
          break;
        case 'received':
          if (event.data != null) {
            final data = Uint8List.fromList(event.data!);
            _eventHandler.handleIncomingData(data, event.deviceId);
            _dataController.add(MeshDataReceived(event.deviceId, data));
          }
          break;
        case 'disconnected':
          _peerDisconnectedController.add(event.deviceId);
          break;
      }
    });

    // ── 2. 訂閱 GATT Server EventChannel（Peripheral 角色接收 Central 寫入）──
    _gattServerDataSub?.cancel();
    _gattServerDataSub =
        NativeBridge.nativeEventStream.where((event) {
      return event is Map && event['type'] == 'ble_data';
    }).listen((event) {
      final map = Map<String, dynamic>.from(event);
      final deviceId = map['device'] as String? ?? 'unknown';
      final dataList = map['data'];
      if (dataList is List && dataList.isNotEmpty) {
        final data = Uint8List.fromList(List<int>.from(dataList));
        debugPrint(
            '[NativeBLE] GATT Server received ${data.length}B from $deviceId');
        _eventHandler.handleIncomingData(data, deviceId);
        _dataController.add(MeshDataReceived(deviceId, data));
      }
    });

    // ── 3. 訂閱 GATT Server Peer 連線事件 ──
    _gattServerPeerSub?.cancel();
    _gattServerPeerSub =
        NativeBridge.nativeEventStream.where((event) {
      return event is Map && event['type'] == 'ble_peer';
    }).listen((event) {
      final map = Map<String, dynamic>.from(event);
      final deviceId = map['device'] as String? ?? 'unknown';
      final state = map['state'] as String? ?? '';
      if (state == 'connected') {
        _peerConnectedController.add(deviceId);
      } else {
        _peerDisconnectedController.add(deviceId);
      }
    });

    // ── 4. 啟動 Central 掃描 + Peripheral 廣播 ──
    await _bleManager.startScanning();

    // 取得真正的 pubKey prefix 和 identity level
    final identity = IdentityManager();
    List<int> pubKeyPrefix;
    try {
      pubKeyPrefix = await identity.getPublicKeyBytes();
    } catch (_) {
      pubKeyPrefix = [0, 0, 0, 0];
    }
    final identityLevel = identity.getIdentityLevel();
    await NativeBridge.startBleAdvertising(pubKeyPrefix, identityLevel);

    _stateController.add(TransportState.running);
  }

  @override
  Future<void> stop() async {
    await _bleManager.stopScanning();
    await _bleEventSub?.cancel();
    _bleEventSub = null;
    await _gattServerDataSub?.cancel();
    _gattServerDataSub = null;
    await _gattServerPeerSub?.cancel();
    _gattServerPeerSub = null;
    _stateController.add(TransportState.stopped);
  }

  @override
  Future<String> broadcast(Uint8List data) async {
    // 解碼 wire payload 取得 eventId，放入 TriageQueue
    // BleManager 的 _connectAndSync 會在下次掃描連線時消費推送
    final decoded = MeshEventHandler.decodeWirePayload(data);
    if (decoded != null) {
      EventManager().queue.enqueue(
        MeshTask(decoded.eventId, decoded.urgency, data, eventType: decoded.eventType),
      );
      debugPrint(
          '[NativeBLE] broadcast ${decoded.eventId.substring(0, 8)}.. urg=${decoded.urgency} type=${decoded.eventType} → TriageQueue');
      return decoded.eventId;
    }
    debugPrint('[NativeBLE] broadcast ${data.length}B → decode failed');
    return 'native-ble-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<String> sendToNode(String nodeId, Uint8List data) async {
    // BLE GATT 無法定向傳送，同樣放入 TriageQueue 等待下次遇到該節點
    final decoded = MeshEventHandler.decodeWirePayload(data);
    if (decoded != null) {
      EventManager().queue.enqueue(
        MeshTask(decoded.eventId, decoded.urgency, data, eventType: decoded.eventType),
      );
      debugPrint(
          '[NativeBLE] sendToNode $nodeId ${decoded.eventId.substring(0, 8)}.. type=${decoded.eventType} → TriageQueue');
      return decoded.eventId;
    }
    return 'native-ble-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Stream<MeshDataReceived> get onDataReceived => _dataController.stream;

  @override
  Stream<String> get onPeerConnected => _peerConnectedController.stream;

  @override
  Stream<String> get onPeerDisconnected => _peerDisconnectedController.stream;

  @override
  Stream<TransportState> get onStateChanged => _stateController.stream;

  @override
  bool get isActive => _bleManager.isActive;

  @override
  TransportStats get stats => TransportStats(
        sentCount: _bleManager.syncedEventCount,
        receivedCount:
            _bleManager.receivedEventCount + _eventHandler.receivedEventCount,
        connectedPeers: _bleManager.knownPeersCount,
        seenEventsCount: _bleManager.seenEventsCount,
        debugLogs: List.unmodifiable([
          ..._bleManager.debugLogs,
          ..._eventHandler.debugLogs,
        ]),
      );

  @override
  void dispose() {
    _bleEventSub?.cancel();
    _gattServerDataSub?.cancel();
    _gattServerPeerSub?.cancel();
    _dataController.close();
    _peerConnectedController.close();
    _peerDisconnectedController.close();
    _stateController.close();
  }
}
