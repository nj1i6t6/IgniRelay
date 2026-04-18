import 'dart:typed_data';

import 'package:ignirelay_app/platform/native_bridge.dart';

/// Mesh 執行時期（前景服務、傳輸模式、GATT 狀態）的應用層 facade。
///
/// 供「我」分頁的生存模式子頁與主流程切換 Data Mule / BLE relay / 停機使用。
class MeshRuntimeController {
  MeshRuntimeController._();
  static final MeshRuntimeController instance = MeshRuntimeController._();

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
