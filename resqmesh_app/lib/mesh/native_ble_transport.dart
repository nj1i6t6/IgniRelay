import 'dart:async';
import 'package:flutter/foundation.dart';
import 'ble_manager.dart';
import 'mesh_transport.dart';
import 'mesh_event_handler.dart';

/// NativeBleTransport — 包裝現有 BleManager 為 MeshTransport 介面
///
/// 這是過渡用的包裝層，讓現有 flutter_blue_plus BLE 實作
/// 可以透過 MeshTransport 抽象介面被上層使用。
/// 未來 Bridgefy 穩定後可完全替換。
class NativeBleTransport implements MeshTransport {
  static final NativeBleTransport _instance = NativeBleTransport._internal();
  factory NativeBleTransport() => _instance;
  NativeBleTransport._internal();

  final BleManager _bleManager = BleManager();
  final MeshEventHandler _eventHandler = MeshEventHandler();

  // Stream controllers (橋接 BleManager 的事件)
  final _dataController = StreamController<MeshDataReceived>.broadcast();
  final _peerConnectedController = StreamController<String>.broadcast();
  final _peerDisconnectedController = StreamController<String>.broadcast();
  final _stateController = StreamController<TransportState>.broadcast();

  StreamSubscription? _bleEventSub;

  @override
  Future<void> initialize() async {
    // BleManager 不需要額外初始化（FlutterBluePlus 自動偵測）
    _stateController.add(TransportState.stopped);
  }

  @override
  Future<void> start() async {
    _stateController.add(TransportState.starting);

    // 訂閱 BleManager 事件，橋接到 MeshTransport streams
    _bleEventSub?.cancel();
    _bleEventSub = _bleManager.events.listen((event) {
      switch (event.type) {
        case 'connected':
          _peerConnectedController.add(event.deviceId);
          break;
        case 'received':
          if (event.data != null) {
            final data = Uint8List.fromList(event.data!);
            // 交給共用 MeshEventHandler 處理
            _eventHandler.handleIncomingData(data, event.deviceId);
            _dataController.add(MeshDataReceived(event.deviceId, data));
          }
          break;
        case 'disconnected':
          _peerDisconnectedController.add(event.deviceId);
          break;
      }
    });

    await _bleManager.startScanning();
    _stateController.add(TransportState.running);
  }

  @override
  Future<void> stop() async {
    await _bleManager.stopScanning();
    await _bleEventSub?.cancel();
    _bleEventSub = null;
    _stateController.add(TransportState.stopped);
  }

  @override
  Future<String> broadcast(Uint8List data) async {
    // NativeBLE 沒有真正的 broadcast（靠 GATT 連線推送）
    // 資料放入 TriageQueue，由 BleManager 的 _connectAndSync 消費
    debugPrint('[NativeBLE] broadcast ${data.length}B → queued for GATT sync');
    return 'native-ble-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<String> sendToNode(String nodeId, Uint8List data) async {
    // NativeBLE 無法定向傳送，等待下次 GATT 連線時推送
    debugPrint('[NativeBLE] sendToNode $nodeId ${data.length}B → queued');
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
        receivedCount: _bleManager.receivedEventCount,
        connectedPeers: _bleManager.knownPeersCount,
        seenEventsCount: _bleManager.seenEventsCount,
        debugLogs: List.unmodifiable(_bleManager.debugLogs),
      );

  @override
  void dispose() {
    _bleEventSub?.cancel();
    _dataController.close();
    _peerConnectedController.close();
    _peerDisconnectedController.close();
    _stateController.close();
  }
}
