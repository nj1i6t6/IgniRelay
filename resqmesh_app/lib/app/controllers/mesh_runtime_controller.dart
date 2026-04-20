import 'dart:typed_data';

import 'package:ignirelay_app/platform/mesh_transport.dart';
import 'package:ignirelay_app/platform/native_bridge.dart';

// 對 UI 層重新導出 transport 的 value 型別，讓 UI 不必直接 import
// `lib/platform/mesh_transport.dart`（check_layers 規則禁止 UI→platform）。
// 行為型別（抽象類 MeshTransport 本身）刻意不導出——UI 不該拿到 transport
// 實例，只能透過此 controller 的 facade 方法操作。
export 'package:ignirelay_app/platform/mesh_transport.dart'
    show TransportState, TransportStats;

/// Mesh 執行時期（前景服務、傳輸模式、GATT 狀態、BLE transport 控制）的應用層 facade。
///
/// 供「我」分頁的生存模式子頁與主流程切換 Data Mule / BLE relay / 停機使用。
///
/// Stage 4a-fix：吸收 `MeshTransport` 控制面——UI 不再 `Provider.of<MeshTransport>`，
/// 一律走 `MeshRuntimeController.instance`。`main.dart` 在啟動時呼叫一次
/// [attachTransport] 注入 transport 實例。
class MeshRuntimeController {
  MeshRuntimeController._();
  static final MeshRuntimeController instance = MeshRuntimeController._();

  MeshTransport? _transport;

  // ── Transport 注入 ────────────────────────────────────────
  /// 由 `main.dart` 於 `runApp` 之前呼叫一次，注入全域 transport 實例。
  ///
  /// 二次呼叫會覆蓋——測試時可傳 fake transport。
  void attachTransport(MeshTransport transport) {
    _transport = transport;
  }

  MeshTransport get _requiredTransport {
    final t = _transport;
    if (t == null) {
      throw StateError(
          'MeshRuntimeController: transport 尚未注入，請確認 main.dart 已呼叫 attachTransport()');
    }
    return t;
  }

  // ── Transport 生命週期（UI facade） ─────────────────────────
  /// transport 是否運作中。
  bool get transportActive => _transport?.isActive ?? false;

  /// transport 狀態變化 stream。
  Stream<TransportState> get transportStateChanges =>
      _requiredTransport.onStateChanged;

  /// transport 統計（供 Debug 面板）。
  TransportStats get transportStats =>
      _transport?.stats ?? const TransportStats();

  /// 啟動 BLE transport（內含 initialize + start）。
  Future<void> startTransport() async {
    final t = _requiredTransport;
    await t.initialize();
    await t.start();
  }

  /// 停止 BLE transport。
  Future<void> stopTransport() => _requiredTransport.stop();

  // ── Android 前景服務 / 傳輸模式 ─────────────────────────────
  Future<bool> startForegroundService() =>
      NativeBridge.startMeshForegroundService();

  Future<void> stopForegroundService() =>
      NativeBridge.stopMeshForegroundService();

  Future<bool> startDataMuleMode() => NativeBridge.startAndroidDataMuleMode();

  Future<bool> startBleRelayMode() => NativeBridge.startBleRelayMode();

  Future<void> stopAllServices() => NativeBridge.stopAllServices();

  Future<bool> updateBloomFilter(Uint8List bloomBytes) =>
      NativeBridge.updateBloomFilter(bloomBytes);

  Future<bool> updateEventOutbox(List<Uint8List> events) =>
      NativeBridge.updateEventOutbox(events);

  Future<bool> requestHighBandwidthTransfer(
    String peerMac,
    List<int> payload,
  ) =>
      NativeBridge.requestHighBandwidthTransfer(peerMac, payload);

  Future<bool> startBleAdvertising(
    List<int> pubKeyPrefix,
    int identityLevel,
  ) =>
      NativeBridge.startBleAdvertising(pubKeyPrefix, identityLevel);

  Future<Map<String, dynamic>> gattServerStatus() =>
      NativeBridge.getGattServerStatus();
}
