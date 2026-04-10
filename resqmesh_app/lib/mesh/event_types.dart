/// 事件類型常數（對應 Protobuf EventType enum）
/// 唯一定義來源 — event_manager / mesh_event_handler 皆 import 此檔
class EventType {
  // ── Broadcast ──
  static const int resourceRegister = 0;
  static const int requestBroadcast = 1;
  // ── Match negotiation ──
  static const int matchOffer   = 2;       // was matchIntent
  static const int physicalHandshake = 3;
  static const int matchAccept  = 8;       // was matchConfirm
  static const int matchDecline = 9;       // was matchReject
  static const int matchCancel  = 6;
  // ── New slots ──
  static const int matchRequest      = 15;
  static const int handshakeComplete = 16;
  static const int stationClaim      = 17;
  static const int stationResponse   = 18;
  // ── Navigation ──
  static const int locationUpdate = 14;
  // ── Non-match ──
  static const int hazardMarker    = 4;
  static const int quarantineVote  = 5;
  static const int fireAlarmRf     = 7;
  static const int chatMessage     = 13;
  // ── Deprecated (ignored but don't crash) ──
  static const int matchInquiry   = 10;
  static const int matchAvailable = 11;
  static const int matchGone      = 12;

  // Backward compat aliases
  static const int matchIntent  = matchOffer;
  static const int matchConfirm = matchAccept;
  static const int matchReject  = matchDecline;
}
