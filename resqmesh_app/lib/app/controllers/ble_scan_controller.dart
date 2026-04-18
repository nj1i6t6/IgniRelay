import 'dart:typed_data';

import 'package:ignirelay_app/platform/native_bridge.dart';

/// BLE 掃描與連線（Nordic central 面向）的應用層 facade。
///
/// 用於導航配對、Bloom filter 交換、outbox 傳輸等 Central 側操作。
class BleScanController {
  BleScanController._();
  static final BleScanController instance = BleScanController._();

  Future<bool> isBluetoothEnabled() => NativeBridge.isBluetoothEnabled();

  Future<bool> requestBluetoothEnable() =>
      NativeBridge.requestBluetoothEnable();

  Future<bool> startScan() => NativeBridge.startNordicScan();

  Future<void> stopScan() => NativeBridge.stopNordicScan();

  Future<bool> connect(String deviceId) =>
      NativeBridge.nordicConnect(deviceId);

  Future<void> disconnect(String deviceId) =>
      NativeBridge.nordicDisconnect(deviceId);

  Future<Uint8List?> readBloom(String deviceId) =>
      NativeBridge.nordicReadBloom(deviceId);

  Future<bool> writeBloom(String deviceId, Uint8List bloomBytes) =>
      NativeBridge.nordicWriteBloom(deviceId, bloomBytes);

  Future<bool> writeEvent(String deviceId, Uint8List eventBytes) =>
      NativeBridge.nordicWriteEvent(deviceId, eventBytes);

  /// 掃描/GATT 事件串流（跨用途的原始事件）。
  Stream<dynamic> get rawEventStream => NativeBridge.nativeEventStream;
}
