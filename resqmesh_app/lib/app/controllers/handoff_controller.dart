import 'dart:convert';
import 'dart:typed_data';

import 'package:ignirelay_app/platform/native_bridge_facade.dart';

/// 實體交接相關的應用層 facade。
///
/// UI 層透過本類呼叫底層 handoff 能力，不再直接依賴 platform 層。
///
/// **Stage 6 (commit #10)**：跨平台事件型別歸一化。Android `IgniRelayForegroundService`
/// 與 iOS `BlePlugin` 在收到 HANDSHAKE_CHAR 寫入後，皆已 emit 統一型別
/// `handoff_result` 並帶 `{resourceId, success}` 欄位。
///
/// **Stage 6-fix (2026-04-26)**：requester 端真正的跨裝置 PIN 傳遞。
/// `sendPin(deviceId, ...)` 現在會：
///   1. 把 `{pin, resourceId}` 序列化成 JSON UTF-8 bytes
///   2. 透過 `nordicWriteHandshake` 寫到 provider 的 HANDSHAKE_CHAR
///   3. provider GATT server 做 SHA-256 + resourceId 比對，以 GATT response
///      status 回報結果（Android: GATT_SUCCESS/GATT_FAILURE；iOS:
///      .success/.writeNotPermitted）
///   4. central 端的 write callback 收到該 status，翻譯為 bool 回傳
///
/// 若 deviceId 為空（同裝置開發測試 / fallback），改走 `sendHandoffPin` 本地
/// hash 比對；正式跨裝置流程必須帶 deviceId。
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
  }) async {
    // Stage 6-fix：deviceId 提供時走 BLE write 真正跨裝置；否則 fallback。
    if (deviceId.isNotEmpty) {
      final payload = utf8.encode(jsonEncode({
        'pin': pin,
        'resourceId': resourceId,
      }));
      return NativeBridgeFacade.instance
          .nordicWriteHandshake(deviceId, Uint8List.fromList(payload));
    }
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
