import 'package:ignirelay_app/platform/native_bridge_facade.dart';

/// 實體交接相關的應用層 facade。
///
/// UI 層透過本類呼叫底層 handoff 能力，不再直接依賴 platform 層。
/// 後續階段（Stage 6）會在這層把跨平台事件型別歸一化（iOS handshake_data
/// 與 Dart 端 handoff_result 的不一致問題）。
///
/// Stage 5：改走 `NativeBridgeFacade`，讓單元測試可注入 `FakeNativeBridge`。
class HandoffController {
  HandoffController._();
  static final HandoffController instance = HandoffController._();

  Future<bool> startAdvertising({
    required String resourceId,
    required String pinHash,
  }) {
    return NativeBridgeFacade.instance.startHandoffAdvertising(
      resourceId: resourceId,
      pinHash: pinHash,
    );
  }

  Future<bool> sendPin({
    required String deviceId,
    required String resourceId,
    required String pin,
  }) {
    return NativeBridgeFacade.instance.sendHandoffPin(
      deviceId: deviceId,
      resourceId: resourceId,
      pin: pin,
    );
  }

  Future<void> stopAdvertising() =>
      NativeBridgeFacade.instance.stopHandoffAdvertising();

  /// 交接事件串流。Stage 6 會在此層做跨平台歸一化。
  Stream<Map<String, dynamic>> get events =>
      NativeBridgeFacade.instance.handoffEvents;
}
