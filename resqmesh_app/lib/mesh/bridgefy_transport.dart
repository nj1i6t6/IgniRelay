import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'native_ble_transport.dart';
import 'mesh_transport.dart';

/// [`BridgefyTransport`](resqmesh_app/lib/mesh/bridgefy_transport.dart)
///
/// 目前專案未納入實際 [`package:bridgefy/bridgefy.dart`](resqmesh_app/lib/mesh/bridgefy_transport.dart)
/// 依賴，故以 Native BLE 作為相容 fallback，保留既有型別與介面，
/// 避免 analyzer / build 因缺少私有 SDK 而失敗。
class BridgefyTransport implements MeshTransport {
  static final BridgefyTransport _instance = BridgefyTransport._internal();
  factory BridgefyTransport() => _instance;
  BridgefyTransport._internal();

  final NativeBleTransport _delegate = NativeBleTransport();

  void _dlog(String msg) {
    debugPrint('[BridgefyFallback] $msg');
  }

  @override
  Future<void> initialize() async {
    _dlog('Bridgefy SDK unavailable, fallback initialize -> NativeBleTransport');
    await _delegate.initialize();
  }

  @override
  Future<void> start() async {
    _dlog('Bridgefy SDK unavailable, fallback start -> NativeBleTransport');
    await _delegate.start();
  }

  @override
  Future<void> stop() async {
    await _delegate.stop();
  }

  @override
  Future<String> broadcast(Uint8List data) => _delegate.broadcast(data);

  @override
  Future<String> sendToNode(String nodeId, Uint8List data) =>
      _delegate.sendToNode(nodeId, data);

  @override
  Stream<MeshDataReceived> get onDataReceived => _delegate.onDataReceived;

  @override
  Stream<String> get onPeerConnected => _delegate.onPeerConnected;

  @override
  Stream<String> get onPeerDisconnected => _delegate.onPeerDisconnected;

  @override
  Stream<TransportState> get onStateChanged => _delegate.onStateChanged;

  @override
  bool get isActive => _delegate.isActive;

  @override
  TransportStats get stats => _delegate.stats;

  @override
  void dispose() {
    // singleton delegate 由實際 transport 生命週期統一管理，這裡不主動 dispose
  }
}
