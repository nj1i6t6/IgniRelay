import 'dart:typed_data';

import 'package:ignirelay_app/platform/native_bridge_facade.dart';

/// BLE 掃描與連線（Nordic central 面向）的應用層 facade。
///
/// 用於導航配對、Bloom filter 交換、outbox 傳輸等 Central 側操作。
///
/// Stage 5：改走 `NativeBridgeFacade`，讓單元測試可注入 `FakeNativeBridge`。
class BleScanController {
  BleScanController._();
  static final BleScanController instance = BleScanController._();

  Future<bool> isBluetoothEnabled() =>
      NativeBridgeFacade.instance.isBluetoothEnabled();

  Future<bool> requestBluetoothEnable() =>
      NativeBridgeFacade.instance.requestBluetoothEnable();

  Future<bool> startScan() => NativeBridgeFacade.instance.startNordicScan();

  Future<void> stopScan() => NativeBridgeFacade.instance.stopNordicScan();

  Future<bool> connect(String deviceId) =>
      NativeBridgeFacade.instance.nordicConnect(deviceId);

  Future<void> disconnect(String deviceId) =>
      NativeBridgeFacade.instance.nordicDisconnect(deviceId);

  Future<Uint8List?> readBloom(String deviceId) =>
      NativeBridgeFacade.instance.nordicReadBloom(deviceId);

  Future<bool> writeBloom(String deviceId, Uint8List bloomBytes) =>
      NativeBridgeFacade.instance.nordicWriteBloom(deviceId, bloomBytes);

  Future<bool> writeEvent(String deviceId, Uint8List eventBytes) =>
      NativeBridgeFacade.instance.nordicWriteEvent(deviceId, eventBytes);

  /// Stage 6-fix：寫 PIN+resourceId JSON 到對端 Handshake Characteristic。
  /// 回傳值即 provider 端 GATT server 的驗證結果（true = PIN 正確）。
  Future<bool> writeHandshake(String deviceId, Uint8List handshakeBytes) =>
      NativeBridgeFacade.instance.nordicWriteHandshake(deviceId, handshakeBytes);

  /// 掃描/GATT 事件串流（跨用途的原始事件）。
  Stream<dynamic> get rawEventStream =>
      NativeBridgeFacade.instance.nativeEventStream;
}
