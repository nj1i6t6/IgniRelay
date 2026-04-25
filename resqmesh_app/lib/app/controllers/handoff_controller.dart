import 'package:ignirelay_app/platform/native_bridge_facade.dart';

/// 實體交接相關的應用層 facade。
///
/// UI 層透過本類呼叫底層 handoff 能力，不再直接依賴 platform 層。
///
/// **Stage 6 (commit #10)**：跨平台事件型別歸一化。Android `IgniRelayForegroundService`
/// 與 iOS `BlePlugin` 在收到 HANDSHAKE_CHAR 寫入後，皆已 emit 統一型別
/// `handoff_result` 並帶 `{resourceId, success}` 欄位。本 controller 仍保留
/// 對舊版 iOS `handshake_data` 事件的轉接，以承接尚未升級的 client。
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

  /// 交接事件串流（已歸一化）。新版兩端皆送 `handoff_result`；舊版 iOS 的
  /// `handshake_data` 在此 fallback 為 success=false（因不含驗證資訊）。
  Stream<Map<String, dynamic>> get events =>
      NativeBridgeFacade.instance.handoffEvents.map(_normalizeEvent);

  /// 純函式：把任意 native handoff event 投影成 `{type:'handoff_result',
  /// resourceId, success}` 規範化形式。**static 暴露供測試**。
  static Map<String, dynamic> _normalizeEvent(Map<String, dynamic> e) {
    final type = e['type'];
    if (type == 'handoff_result') {
      return e;
    }
    if (type == 'handshake_data') {
      // 舊版 iOS 路徑：bytes 未解析 → 視為失敗，由 UI 走 timeout / 本地驗證 fallback。
      return {
        'type': 'handoff_result',
        'device': e['device'] ?? '',
        'resourceId': e['resourceId'] ?? '',
        'success': false,
        'legacy': true,
      };
    }
    return e;
  }

  /// `_normalizeEvent` 的測試入口。
  static Map<String, dynamic> debugNormalize(Map<String, dynamic> e) =>
      _normalizeEvent(e);
}
