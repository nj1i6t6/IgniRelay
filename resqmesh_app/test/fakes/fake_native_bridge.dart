import 'dart:async';
import 'dart:typed_data';

import 'package:ignirelay_app/platform/native_bridge_facade.dart';

/// Stage 5：`NativeBridgeFacade` 的測試替身。
///
/// 所有 method 預設回傳「成功」(`true` / 空 stream)；測試可覆寫任一 field
/// 來模擬失敗或回傳特定資料。呼叫紀錄存放在 `calls`，可於斷言檢查。
///
/// 使用方式：
/// ```dart
/// late FakeNativeBridge fake;
/// setUp(() {
///   fake = FakeNativeBridge();
///   NativeBridgeFacade.instance = fake;
/// });
/// tearDown(NativeBridgeFacade.resetToReal);
/// ```
class FakeNativeBridge implements NativeBridgeFacade {
  /// 每一次呼叫的紀錄：`(method, argsMap)`。
  final List<(String, Map<String, Object?>)> calls = [];

  /// 測試可覆寫這些 field 來改變回傳值。
  bool bluetoothEnabled = true;
  bool requestBluetoothEnableResult = true;
  bool startScanResult = true;
  bool connectResult = true;
  bool writeBloomResult = true;
  bool writeEventResult = true;
  bool writeHandshakeResult = true;
  Uint8List? readBloomResult;

  bool startHandoffAdvertisingResult = true;
  bool sendHandoffPinResult = true;

  final StreamController<Map<String, dynamic>> handoffEventsCtrl =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<dynamic> nativeEventCtrl =
      StreamController<dynamic>.broadcast();

  void dispose() {
    handoffEventsCtrl.close();
    nativeEventCtrl.close();
  }

  // ── Handoff ──────────────────────────────────────────────────────

  @override
  Future<bool> startHandoffAdvertising({
    required String resourceId,
    required String pinHash,
  }) async {
    calls.add((
      'startHandoffAdvertising',
      {'resourceId': resourceId, 'pinHash': pinHash}
    ));
    return startHandoffAdvertisingResult;
  }

  @override
  Future<bool> sendHandoffPin({
    required String deviceId,
    required String resourceId,
    required String pin,
  }) async {
    calls.add((
      'sendHandoffPin',
      {'deviceId': deviceId, 'resourceId': resourceId, 'pin': pin}
    ));
    return sendHandoffPinResult;
  }

  @override
  Future<void> stopHandoffAdvertising() async {
    calls.add(('stopHandoffAdvertising', const {}));
  }

  @override
  Stream<Map<String, dynamic>> get handoffEvents => handoffEventsCtrl.stream;

  // ── BLE Central ──────────────────────────────────────────────────

  @override
  Future<bool> isBluetoothEnabled() async {
    calls.add(('isBluetoothEnabled', const {}));
    return bluetoothEnabled;
  }

  @override
  Future<bool> requestBluetoothEnable() async {
    calls.add(('requestBluetoothEnable', const {}));
    return requestBluetoothEnableResult;
  }

  @override
  Future<bool> startNordicScan() async {
    calls.add(('startNordicScan', const {}));
    return startScanResult;
  }

  @override
  Future<void> stopNordicScan() async {
    calls.add(('stopNordicScan', const {}));
  }

  @override
  Future<bool> nordicConnect(String deviceId) async {
    calls.add(('nordicConnect', {'deviceId': deviceId}));
    return connectResult;
  }

  @override
  Future<void> nordicDisconnect(String deviceId) async {
    calls.add(('nordicDisconnect', {'deviceId': deviceId}));
  }

  @override
  Future<Uint8List?> nordicReadBloom(String deviceId) async {
    calls.add(('nordicReadBloom', {'deviceId': deviceId}));
    return readBloomResult;
  }

  @override
  Future<bool> nordicWriteBloom(String deviceId, Uint8List bloomBytes) async {
    calls.add(('nordicWriteBloom',
        {'deviceId': deviceId, 'bloomBytes': bloomBytes}));
    return writeBloomResult;
  }

  @override
  Future<bool> nordicWriteEvent(String deviceId, Uint8List eventBytes) async {
    calls.add(('nordicWriteEvent',
        {'deviceId': deviceId, 'eventBytes': eventBytes}));
    return writeEventResult;
  }

  @override
  Future<bool> nordicWriteHandshake(
      String deviceId, Uint8List handshakeBytes) async {
    calls.add(('nordicWriteHandshake',
        {'deviceId': deviceId, 'handshakeBytes': handshakeBytes}));
    return writeHandshakeResult;
  }

  @override
  Stream<dynamic> get nativeEventStream => nativeEventCtrl.stream;
}
