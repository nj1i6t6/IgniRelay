import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:ignirelay_app/app/mesh/event_types.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/app/services/event_decoder.dart';
import 'package:ignirelay_app/app/services/event_store.dart';

class SosAlert {
  final String eventId;
  final int urgency;
  final String description;
  final double? lat;
  final double? lng;
  final Uint8List? senderPubKey;
  final DateTime timestamp;
  SosAlert(
      {required this.eventId,
      required this.urgency,
      required this.description,
      this.lat,
      this.lng,
      this.senderPubKey,
      required this.timestamp});
}

class MatchUpdate {
  final String eventId;
  final int eventType;
  final String? negotiationId;
  final String? resourceId;
  final String? requestId;
  final Object? decodedPayload;
  MatchUpdate(
      {required this.eventId,
      required this.eventType,
      this.negotiationId,
      this.resourceId,
      this.requestId,
      this.decodedPayload});
}

class HazardEvent {
  final String eventId;
  final String type;
  final int severity;
  final double lat;
  final double lng;
  final double radiusMeters;
  final String description;
  HazardEvent(
      {required this.eventId,
      required this.type,
      required this.severity,
      required this.lat,
      required this.lng,
      required this.radiusMeters,
      required this.description});
}

class SupplyChange {
  final String eventId;
  final String resourceType;
  final int quantity;
  final String unit;
  SupplyChange(
      {required this.eventId,
      required this.resourceType,
      required this.quantity,
      required this.unit});
}

/// 聊天訊息典型化 wrapper：UI 訂閱 [EventStream.chatMessages] 就能在新訊息抵達
/// 時刷新對應房間，不需要再 listen rawEvents 後自行解 payload。
class ChatMessage {
  final String eventId;
  final String roomId;
  final String roomType;
  final String content;
  final String? replyTo;
  final DateTime timestamp;
  ChatMessage({
    required this.eventId,
    required this.roomId,
    required this.roomType,
    required this.content,
    this.replyTo,
    required this.timestamp,
  });
}

/// 通用「事件日誌變動」通知。
///
/// 給只關心「某個事件剛剛抵達/落地，請我重整自己這份 view」的 UI 使用
/// （地圖 overlay、match 列表、navigation peer 位置等）。內容是純 Dart 型別，
/// 不含 protobuf。
///
/// 之所以提供這個 stream，是為了讓 production UI 不再需要依賴 `rawEvents`
/// 做「any event arrived」訊號，符合 Stage 1 spec 對 raw stream 僅限 debug
/// 使用的要求。
class EventLogChanged {
  /// 此批至少包含一筆新事件的 hint event id；UI 通常用不到具體值，主要
  /// 訊號是「stream 有 push」這件事本身。
  final String latestEventId;
  EventLogChanged({required this.latestEventId});
}

class EventStream {
  EventStream({
    required MeshEventHandler handler,
    required EventDecoder decoder,
    required EventStore store,
  })  : _handler = handler,
        _decoder = decoder,
        _store = store;

  final MeshEventHandler _handler;
  final EventDecoder _decoder;
  final EventStore _store;
  StreamSubscription<MeshDataReceived>? _subscription;
  final Set<String> _dispatchedEventIds = <String>{};

  final StreamController<SosAlert> _sosController =
      StreamController<SosAlert>.broadcast();
  final StreamController<MatchUpdate> _matchController =
      StreamController<MatchUpdate>.broadcast();
  final StreamController<HazardEvent> _hazardController =
      StreamController<HazardEvent>.broadcast();
  final StreamController<SupplyChange> _supplyController =
      StreamController<SupplyChange>.broadcast();
  final StreamController<ChatMessage> _chatController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<EventLogChanged> _anyEventController =
      StreamController<EventLogChanged>.broadcast();

  Stream<SosAlert> get sosAlerts => _sosController.stream;
  Stream<MatchUpdate> get matchUpdates => _matchController.stream;
  Stream<HazardEvent> get hazardEvents => _hazardController.stream;
  Stream<SupplyChange> get supplyChanges => _supplyController.stream;
  Stream<ChatMessage> get chatMessages => _chatController.stream;

  /// 「事件日誌有新東西」的通用通知 stream。UI 若只需要「something 變了，
  /// 請重新跑 query」的訊號，就訂閱這個 stream，不要再用 [rawEvents]。
  Stream<EventLogChanged> get anyEventChanges => _anyEventController.stream;

  /// Raw stream passthrough — **debug 專用**。Production UI 一律走上面的 typed
  /// streams 或 [anyEventChanges]，由 Stage 1 acceptance gate 強制執行。
  /// `survival_mode_screen.dart` 是僅有的合法 consumer，將在 v0.3 隨 debug
  /// 頁重構一併移除。
  Stream<MeshDataReceived> get rawEvents => _handler.events;

  List<String> get debugLogs => _handler.debugLogs;

  void start() {
    _subscription ??= _handler.events.listen((_) {
      unawaited(_dispatchRecentEvents());
    });
  }

  Future<void> _dispatchRecentEvents() async {
    final rows = await _store.queryRecent(limit: 50);
    String? latestNewEventId;
    for (final row in rows.reversed) {
      final eventId = row['event_id'] as String? ?? '';
      if (eventId.isEmpty || !_dispatchedEventIds.add(eventId)) continue;
      latestNewEventId = eventId;

      final eventType = row['event_type'] as int? ?? -1;
      final urgency = row['urgency'] as int? ?? 0;
      final payload = row['payload'] as Uint8List?;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        (row['hlc_timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      );

      switch (eventType) {
        case EventType.requestBroadcast:
          final data =
              payload == null ? null : _decoder.decodeRequestData(payload);
          if (urgency >= 2) {
            _sosController.add(SosAlert(
              eventId: eventId,
              urgency: urgency,
              description: data?.note ?? '',
              lat: row['lat'] as double?,
              lng: row['lng'] as double?,
              senderPubKey: row['sender_pub_key'] as Uint8List?,
              timestamp: timestamp,
            ));
          } else if (data != null) {
            _supplyController.add(SupplyChange(
              eventId: eventId,
              resourceType: data.resourceType,
              quantity: data.quantity,
              unit: '',
            ));
          }
          break;
        case EventType.resourceRegister:
          final data =
              payload == null ? null : _decoder.decodeResourceData(payload);
          if (data != null) {
            _supplyController.add(SupplyChange(
              eventId: eventId,
              resourceType: data.resourceType,
              quantity: data.quantity,
              unit: data.unit,
            ));
          }
          break;
        case EventType.hazardMarker:
          final data =
              payload == null ? null : _decoder.decodeHazardData(payload);
          if (data != null) {
            _hazardController.add(HazardEvent(
              eventId: eventId,
              type: data.hazardType,
              severity: data.severity,
              lat: data.centerLat,
              lng: data.centerLng,
              radiusMeters: data.radiusMeters,
              description: data.description,
            ));
          }
          break;
        case EventType.matchOffer:
        case EventType.matchRequest:
        case EventType.matchAccept:
        case EventType.matchDecline:
        case EventType.matchCancel:
        case EventType.physicalHandshake:
        case EventType.handshakeComplete:
        case EventType.locationUpdate:
          _matchController.add(MatchUpdate(
            eventId: eventId,
            eventType: eventType,
            decodedPayload: _decoder.decodeByType(
                eventType, payload ?? const <int>[]),
          ));
          break;
        case EventType.chatMessage:
          final chat = _tryDecodeChat(eventId, payload, timestamp);
          if (chat != null) _chatController.add(chat);
          break;
        default:
          break;
      }
    }
    if (latestNewEventId != null) {
      _anyEventController.add(EventLogChanged(latestEventId: latestNewEventId));
    }
  }

  ChatMessage? _tryDecodeChat(
      String eventId, Uint8List? payload, DateTime ts) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(payload));
      if (decoded is! Map) return null;
      final roomId = decoded['room_id'] as String? ?? '';
      final roomType = decoded['room_type'] as String? ?? '';
      final content = decoded['content'] as String? ?? '';
      if (roomId.isEmpty || content.isEmpty) return null;
      return ChatMessage(
        eventId: eventId,
        roomId: roomId,
        roomType: roomType,
        content: content,
        replyTo: decoded['reply_to'] as String?,
        timestamp: ts,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _sosController.close();
    await _matchController.close();
    await _hazardController.close();
    await _supplyController.close();
    await _chatController.close();
    await _anyEventController.close();
  }
}
