import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/crypto/crypto_utils.dart';
import 'package:ignirelay_app/app/proto/mesh_protocol.pb.dart' as pb;
import 'package:ignirelay_app/app/services/negotiation_repo.dart';
import 'package:ignirelay_app/app/services/negotiation_events.dart';

/// NegotiationManager — 狀態機 + CAS + 角色授權 + Stream
/// Application Layer 的核心：所有 Match_Negotiations 狀態轉換的唯一入口
/// UI 層透過 [events] Stream 訂閱狀態變化
/// MeshEventHandler 透過 [handleRemoteEvent] 轉交已驗證的事件
class NegotiationManager {
  static final NegotiationManager _instance = NegotiationManager._internal();
  factory NegotiationManager() => _instance;
  NegotiationManager._internal();

  final _repo = NegotiationRepo();
  final _db = DatabaseHelper();

  final _controller = StreamController<NegotiationEvent>.broadcast();
  Stream<NegotiationEvent> get events => _controller.stream;

  // ── 孤兒事件記憶體緩衝 ──
  final Map<String, _OrphanEvent> _orphanBuffer = {};

  // ── 超時過時的 negotiation IDs (UI 用) ──
  final Set<String> _staleNegotiationIds = {};
  Set<String> get staleNegotiationIds => _staleNegotiationIds;

  // ── EventType constants (mirror from event_manager.dart) ──
  static const int matchOffer = 2;
  static const int matchAccept = 8;
  static const int matchDecline = 9;
  static const int matchCancel = 6;
  static const int matchRequest = 15;
  static const int handshakeComplete = 16;
  static const int locationUpdate = 14;

  // ═══════════════════════════════════════════════════════════════════════════
  //  FSM 防呆（Stage 4c）— service-layer guard
  //
  //  合法狀態轉換矩陣。非終態的每個 from 指向一組允許的 to。
  //  PENDING  → ACCEPTED | DECLINED | CANCELLED | EXPIRED
  //  ACCEPTED → NAVIGATING | COMPLETED | CANCELLED
  //  NAVIGATING → COMPLETED | CANCELLED
  //  COMPLETED / DECLINED / CANCELLED / EXPIRED → terminal（無出邊）
  //
  //  不改 DB schema、不改通訊協議；純 service 層，CAS 接受路徑保持原樣
  //  （PENDING → ACCEPTED 由 casAcceptInTransaction 原子驗證，等同於此表）。
  // ═══════════════════════════════════════════════════════════════════════════
  static const Map<String, Set<String>> _fsmTransitions = {
    'PENDING': {'ACCEPTED', 'DECLINED', 'CANCELLED', 'EXPIRED'},
    'ACCEPTED': {'NAVIGATING', 'COMPLETED', 'CANCELLED'},
    'NAVIGATING': {'COMPLETED', 'CANCELLED'},
    'COMPLETED': <String>{},
    'DECLINED': <String>{},
    'CANCELLED': <String>{},
    'EXPIRED': <String>{},
  };

  /// 判斷 [from] → [to] 是否為合法狀態轉換。公開供單測與防呆檢查使用。
  static bool canTransition(String from, String to) {
    final allowed = _fsmTransitions[from];
    if (allowed == null) return false;
    return allowed.contains(to);
  }

  /// 非法跳轉攔截 hook：測試或觀測可注入以記錄違規事件。
  /// 簽名：(negotiationId, from, to) → void。
  static void Function(String negotiationId, String from, String to)?
      onIllegalTransition;

  /// 統一的非法跳轉記錄入口：寫 debugPrint + 呼叫 [onIllegalTransition] hook。
  /// 供 public API 的早退路徑（state 與預期不符）共用，確保所有被攔截的
  /// 非法狀態轉換嘗試都有一致的 log/可測試 sink。
  static void _notifyIllegal(String negotiationId, String from, String to) {
    debugPrint(
        '[NegotiationManager] ILLEGAL transition $from → $to (neg=$negotiationId) — dropped');
    onIllegalTransition?.call(negotiationId, from, to);
  }

  /// 內部護欄：在呼叫 [_repo.updateStatus] 前驗證 FSM 合法性；
  /// 非法則丟棄且不回寫錯誤值，呼叫 [onIllegalTransition]，並寫 debug log。
  ///
  /// 以 `@visibleForTesting` 開放測試直接驗證 guard 行為——正式呼叫仍須透過
  /// 公開 API（acceptNegotiation / cancelNegotiation …）以保留早退檢查。
  @visibleForTesting
  Future<bool> guardedUpdateStatus(
    String negotiationId,
    String from,
    String to, {
    Map<String, dynamic>? extra,
  }) async {
    if (!canTransition(from, to)) {
      _notifyIllegal(negotiationId, from, to);
      return false;
    }
    await _repo.updateStatus(negotiationId, to, extra: extra);
    return true;
  }

  void dispose() {
    _controller.close();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  對外 API — 本地發起
  // ═══════════════════════════════════════════════════════════════════════════

  /// 建立新協商 (本地發起 MATCH_OFFER 或 MATCH_REQUEST)
  Future<bool> createNegotiation({
    required String negotiationId,
    required String resourceId,
    required String requestId,
    required String initiatorRole,
    required List<int> providerPubKey,
    required List<int> requesterPubKey,
    required double offeredQty,
    required double requestedQty,
    required int expiresAt,
    double? matchScore,
  }) async {
    // Rule 6: max 3 PENDING per request
    final pendingCount = await _repo.countPendingForRequest(requestId);
    if (pendingCount >= 3) return false;

    try {
      await _repo.insert({
        'negotiation_id': negotiationId,
        'resource_id': resourceId,
        'request_id': requestId,
        'initiator_role': initiatorRole,
        'provider_pub_key': Uint8List.fromList(providerPubKey),
        'requester_pub_key': Uint8List.fromList(requesterPubKey),
        'offered_qty': offeredQty,
        'requested_qty': requestedQty,
        'status': 'PENDING',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'expires_at': expiresAt,
        'match_score': matchScore,
      });
    } catch (e) {
      // Partial unique index violation — already an active negotiation
      debugPrint('[NegotiationManager] createNegotiation failed: $e');
      return false;
    }

    _controller.add(NegotiationCreated(
      negotiationId: negotiationId,
      resourceId: resourceId,
      requestId: requestId,
      initiatorRole: initiatorRole,
      offeredQty: offeredQty,
      requestedQty: requestedQty,
    ));
    return true;
  }

  /// 接受協商 (CAS 雙邊檢查)
  Future<bool> acceptNegotiation(
      String negotiationId, List<int> senderPubKey) async {
    final neg = await _repo.getById(negotiationId);
    if (neg == null) {
      _bufferOrphan(negotiationId, matchAccept, senderPubKey, []);
      return false;
    }
    if (neg['status'] != 'PENDING') {
      _notifyIllegal(negotiationId, neg['status'] as String, 'ACCEPTED');
      return false;
    }
    if (!_isResponder(neg, senderPubKey)) return false;

    final requestedQty = (neg['requested_qty'] as num?)?.toDouble() ?? 0.0;
    final result = await _repo.casAcceptInTransaction(
      negotiationId,
      requestedQty,
    );
    if (result == null) return false;

    final agreedQty = (result['agreedQty'] as num).toDouble();
    _controller.add(NegotiationAccepted(
      negotiationId: negotiationId,
      agreedQty: agreedQty,
      resourceId: result['resourceId'] as String,
      requestId: result['requestId'] as String,
    ));
    return true;
  }

  /// 拒絕協商
  Future<void> declineNegotiation(
      String negotiationId, List<int> senderPubKey, String reason) async {
    final neg = await _repo.getById(negotiationId);
    if (neg == null) return;
    if (neg['status'] != 'PENDING') {
      _notifyIllegal(negotiationId, neg['status'] as String, 'DECLINED');
      return;
    }
    if (!_isResponder(neg, senderPubKey)) return;

    final ok = await guardedUpdateStatus(
        negotiationId, neg['status'] as String, 'DECLINED');
    if (!ok) return;
    await _reconcileMaterialStatus(neg['resource_id'] as String);

    _controller.add(NegotiationDeclined(
      negotiationId: negotiationId,
      reason: reason,
    ));
  }

  /// 取消協商 (雙方都可)
  Future<void> cancelNegotiation(
      String negotiationId, List<int> senderPubKey, String reason) async {
    final neg = await _repo.getById(negotiationId);
    if (neg == null) return;
    final status = neg['status'] as String;
    if (status == 'COMPLETED' || status == 'CANCELLED' || status == 'EXPIRED') {
      _notifyIllegal(negotiationId, status, 'CANCELLED');
      return;
    }
    if (!_isParticipant(neg, senderPubKey)) return;

    final ok = await guardedUpdateStatus(negotiationId, status, 'CANCELLED');
    if (!ok) return;
    await _reconcileMaterialStatus(neg['resource_id'] as String);
    await _reconcileRequestStatus(neg['request_id'] as String);

    _controller.add(NegotiationCancelled(
      negotiationId: negotiationId,
      reason: reason,
    ));
  }

  /// 開始導航
  Future<void> startNavigating(String negotiationId) async {
    final neg = await _repo.getById(negotiationId);
    if (neg == null) return;
    if (neg['status'] != 'ACCEPTED') {
      _notifyIllegal(negotiationId, neg['status'] as String, 'NAVIGATING');
      return;
    }

    final ok = await guardedUpdateStatus(
      negotiationId,
      neg['status'] as String,
      'NAVIGATING',
      extra: {'navigating_at': DateTime.now().millisecondsSinceEpoch},
    );
    if (!ok) return;

    _controller
        .add(NegotiationNavigating(negotiationId: negotiationId));
  }

  /// 完成交接
  Future<void> completeHandshake(
    String negotiationId,
    List<int> senderPubKey,
    double actualDeliveredQty,
  ) async {
    final neg = await _repo.getById(negotiationId);
    if (neg == null) {
      // HANDSHAKE_COMPLETE 孤兒 → DB 持久化
      await _repo.insertOrphanEvent(
          negotiationId, handshakeComplete, senderPubKey);
      return;
    }
    final status = neg['status'] as String;
    if (status != 'ACCEPTED' && status != 'NAVIGATING') {
      _notifyIllegal(negotiationId, status, 'COMPLETED');
      return;
    }
    if (!_isParticipant(neg, senderPubKey)) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final ok = await guardedUpdateStatus(
      negotiationId,
      status,
      'COMPLETED',
      extra: {
        'actual_delivered_qty': actualDeliveredQty,
        'completed_at': now,
      },
    );
    if (!ok) return;

    await _reconcileMaterialStatus(neg['resource_id'] as String);
    await _reconcileRequestStatus(neg['request_id'] as String);

    _controller.add(NegotiationCompleted(
      negotiationId: negotiationId,
      actualQty: actualDeliveredQty,
    ));
  }

  /// 更新位置
  Future<void> updateLocation(
    String negotiationId,
    List<int> senderPubKey,
    double lat,
    double lng,
  ) async {
    final neg = await _repo.getById(negotiationId);
    if (neg == null) return;
    if (!_isParticipant(neg, senderPubKey)) return;

    final providerKey = neg['provider_pub_key'] as Uint8List;
    final isProvider = bytesEqual(senderPubKey, providerKey);

    final db = await _db.database;
    if (isProvider) {
      await db.update(
          'Match_Negotiations', {'provider_lat': lat, 'provider_lng': lng},
          where: 'negotiation_id = ?', whereArgs: [negotiationId]);
    } else {
      await db.update(
          'Match_Negotiations', {'requester_lat': lat, 'requester_lng': lng},
          where: 'negotiation_id = ?', whereArgs: [negotiationId]);
    }

    _controller.add(LocationUpdated(
      negotiationId: negotiationId,
      lat: lat,
      lng: lng,
      isProvider: isProvider,
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MeshEventHandler 呼叫的統一入口
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> handleRemoteEvent(
      int eventType, List<int> payload, List<int> senderPubKey) async {
    switch (eventType) {
      case matchOffer:
        await _handleRemoteMatchOffer(payload, senderPubKey);
        break;
      case matchRequest:
        await _handleRemoteMatchRequest(payload, senderPubKey);
        break;
      case matchAccept:
        await _handleRemoteMatchAccept(payload, senderPubKey);
        break;
      case matchDecline:
        await _handleRemoteMatchDecline(payload, senderPubKey);
        break;
      case matchCancel:
        await _handleRemoteMatchCancel(payload, senderPubKey);
        break;
      case handshakeComplete:
        await _handleRemoteHandshakeComplete(payload, senderPubKey);
        break;
      case locationUpdate:
        await _handleRemoteLocationUpdate(payload, senderPubKey);
        break;
    }

    // Try to process orphan events after each new event
    await retryOrphanEvents();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Remote event handlers
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _handleRemoteMatchOffer(
      List<int> payload, List<int> senderPubKey) async {
    try {
      final data = pb.MatchOfferData.fromBuffer(payload);
      if (data.negotiationId.isEmpty) return;

      final expiresAt = data.expiresAt.toInt();
      await createNegotiation(
        negotiationId: data.negotiationId,
        resourceId: data.resourceId,
        requestId: data.requestId,
        initiatorRole: 'PROVIDER',
        providerPubKey: data.providerPubKey,
        requesterPubKey: data.requesterPubKey,
        offeredQty: data.offeredQty,
        requestedQty: 0,
        expiresAt: expiresAt > 0
            ? expiresAt
            : DateTime.now().millisecondsSinceEpoch + 2700000,
        matchScore: data.matchScore,
      );
    } catch (e) {
      debugPrint('[NegotiationManager] Failed to decode MatchOfferData: $e');
    }
  }

  Future<void> _handleRemoteMatchRequest(
      List<int> payload, List<int> senderPubKey) async {
    try {
      final data = pb.MatchRequestData.fromBuffer(payload);
      if (data.negotiationId.isEmpty) return;

      final expiresAt = data.expiresAt.toInt();
      await createNegotiation(
        negotiationId: data.negotiationId,
        resourceId: data.resourceId,
        requestId: data.requestId,
        initiatorRole: 'REQUESTER',
        providerPubKey: data.providerPubKey,
        requesterPubKey: data.requesterPubKey,
        offeredQty: 0,
        requestedQty: data.requestedQty,
        expiresAt: expiresAt > 0
            ? expiresAt
            : DateTime.now().millisecondsSinceEpoch + 2700000,
      );
    } catch (e) {
      debugPrint('[NegotiationManager] Failed to decode MatchRequestData: $e');
    }
  }

  Future<void> _handleRemoteMatchAccept(
      List<int> payload, List<int> senderPubKey) async {
    try {
      final data = pb.MatchAcceptData.fromBuffer(payload);
      if (data.negotiationId.isEmpty) return;
      await acceptNegotiation(data.negotiationId, senderPubKey);
    } catch (e) {
      debugPrint('[NegotiationManager] Failed to decode MatchAcceptData: $e');
    }
  }

  Future<void> _handleRemoteMatchDecline(
      List<int> payload, List<int> senderPubKey) async {
    try {
      final data = pb.MatchDeclineData.fromBuffer(payload);
      if (data.negotiationId.isEmpty) return;
      await declineNegotiation(data.negotiationId, senderPubKey, data.reason);
    } catch (e) {
      debugPrint('[NegotiationManager] Failed to decode MatchDeclineData: $e');
    }
  }

  Future<void> _handleRemoteMatchCancel(
      List<int> payload, List<int> senderPubKey) async {
    // Try 1: New format (protobuf MatchCancelData with negotiation_id)
    try {
      final data = pb.MatchCancelData.fromBuffer(payload);
      if (data.negotiationId.isNotEmpty) {
        await cancelNegotiation(data.negotiationId, senderPubKey, data.reason);
        return;
      }
    } catch (_) {}

    // Try 2: Old format "CANCEL:SUPPLY:eventId" or "CANCEL:REQUEST:eventId"
    try {
      final cancelStr = utf8.decode(payload);
      final parts = cancelStr.split(':');
      if (parts.length >= 3 && parts[0] == 'CANCEL') {
        final targetType = parts[1];
        final targetId = parts[2];
        final db = await _db.database;
        if (targetType == 'SUPPLY') {
          await db.execute(
              "UPDATE Materials_State SET status = 'CANCELLED' WHERE resource_id = ?",
              [targetId]);
        } else if (targetType == 'REQUEST') {
          await db.execute(
              "UPDATE Requests_State SET status = 'CANCELLED' WHERE request_id = ?",
              [targetId]);
        }
        return;
      }
    } catch (_) {}

    debugPrint('[NegotiationManager] Unknown CANCEL payload format, ignoring');
  }

  Future<void> _handleRemoteHandshakeComplete(
      List<int> payload, List<int> senderPubKey) async {
    try {
      final data = pb.HandshakeCompleteData.fromBuffer(payload);
      if (data.negotiationId.isEmpty) return;

      // 第三方節點視角 (bystander):本機沒對應 Match_Negotiations,或仍是
      // PENDING (錯過 matchAccept 事件)。直接寫一筆 COMPLETED + reconcile,
      // 讓本機 Materials_State / Requests_State 正確核銷,避免社區頁仍顯示
      // 已交接物資、別人重複媒合。
      //
      // 條件:HandshakeCompleteData 必須帶 resource_id + request_id
      // (schema_version >= 1)。舊 client 沒帶 → 退回原本 completeHandshake 路徑。
      //
      // 安全:sender 必須是 payload 聲稱的 provider 或 requester。比照
      // [completeHandshake] 的 `_isParticipant` 檢查,避免任意節點偽造核銷。
      if (data.resourceId.isNotEmpty && data.requestId.isNotEmpty) {
        final senderIsClaimedParticipant =
            bytesEqual(senderPubKey, data.providerPubKey) ||
                bytesEqual(senderPubKey, data.requesterPubKey);
        if (!senderIsClaimedParticipant) {
          debugPrint(
              '[NegotiationManager] Ignoring handshakeComplete: sender not in claimed participants');
          return;
        }
        final existing = await _repo.getById(data.negotiationId);
        final status = existing?['status'] as String?;
        if (existing == null ||
            status == 'PENDING' ||
            status == 'EXPIRED' ||
            status == 'DECLINED') {
          await _applyRemoteHandshakeForBystander(data);
          return;
        }
      }

      await completeHandshake(
          data.negotiationId, senderPubKey, data.actualDeliveredQty);
    } catch (e) {
      debugPrint(
          '[NegotiationManager] Failed to decode HandshakeCompleteData: $e');
    }
  }

  /// 第三方節點:寫一筆 COMPLETED Match_Negotiations(若已存在則升級狀態),
  /// 之後跑 reconcile 讓 Materials_State / Requests_State 正確進入終態。
  ///
  /// 用 synthetic row + 既有 reconcile 機制是為了:
  /// 1. 沿用 [_reconcileMaterialStatus] 已驗證過的 multi-unit 邏輯
  ///    (部分交付時不會誤判 CONSUMED)
  /// 2. 不需新增欄位 / migration
  /// 3. UNIQUE index `idx_active_negotiation` 排除 COMPLETED,不會撞索引
  Future<void> _applyRemoteHandshakeForBystander(
      pb.HandshakeCompleteData data) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _repo.getById(data.negotiationId);
    if (existing == null) {
      // 寫一筆 synthetic COMPLETED row (insert 用 ignore;重複收到不會炸)
      await _repo.insert({
        'negotiation_id': data.negotiationId,
        'resource_id': data.resourceId,
        'request_id': data.requestId,
        'initiator_role': 'PROVIDER', // bystander 不知道真實 role,此欄不影響 reconcile
        'provider_pub_key': Uint8List.fromList(data.providerPubKey),
        'requester_pub_key': Uint8List.fromList(data.requesterPubKey),
        'offered_qty': data.actualDeliveredQty,
        'requested_qty': data.actualDeliveredQty,
        'agreed_qty': data.actualDeliveredQty,
        'actual_delivered_qty': data.actualDeliveredQty,
        'status': 'COMPLETED',
        'created_at': now,
        'expires_at': now,
        'responded_at': now,
        'completed_at': now,
      });
    } else {
      // 既有 PENDING/EXPIRED/DECLINED row:強制升級為 COMPLETED,寫入交付量
      final db = await _db.database;
      await db.update(
        'Match_Negotiations',
        {
          'status': 'COMPLETED',
          'agreed_qty': data.actualDeliveredQty,
          'actual_delivered_qty': data.actualDeliveredQty,
          'completed_at': now,
        },
        where: 'negotiation_id = ?',
        whereArgs: [data.negotiationId],
      );
    }
    await _reconcileMaterialStatus(data.resourceId);
    await _reconcileRequestStatus(data.requestId);
    _controller.add(NegotiationCompleted(
      negotiationId: data.negotiationId,
      actualQty: data.actualDeliveredQty,
    ));
  }

  Future<void> _handleRemoteLocationUpdate(
      List<int> payload, List<int> senderPubKey) async {
    try {
      final data = pb.LocationUpdateData.fromBuffer(payload);
      final negId = data.sessionId.isNotEmpty
          ? data.sessionId
          : (data.hasField(1) ? data.getField(1) as String : '');
      if (negId.isEmpty) return;
      await updateLocation(negId, senderPubKey, data.lat, data.lng);
    } catch (e) {
      debugPrint(
          '[NegotiationManager] Failed to decode LocationUpdateData: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  超時清理
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> expireStaleNegotiations() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. PENDING expired → EXPIRED
    final expired = await _repo.getExpiredPending(now);
    for (final row in expired) {
      final negId = row['negotiation_id'] as String;
      final ok = await guardedUpdateStatus(
          negId, row['status'] as String? ?? 'PENDING', 'EXPIRED');
      if (!ok) continue;
      await _reconcileMaterialStatus(row['resource_id'] as String);
      _controller.add(NegotiationExpired(negotiationId: negId));
    }

    // 2. ACCEPTED/NAVIGATING stale → mark for user confirmation
    final stale = await _repo.getStaleActive(now);
    _staleNegotiationIds.clear();
    for (final row in stale) {
      _staleNegotiationIds.add(row['negotiation_id'] as String);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Oversold detection
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> checkOversold(String resourceId) async {
    final available = await _repo.computeAvailableQty(resourceId);
    if (available < 0) {
      final active = await _repo.getByResource(resourceId,
          statuses: ['ACCEPTED', 'NAVIGATING']);
      final ids = active.map((n) => n['negotiation_id'] as String).toList();
      _controller.add(OversoldDetected(
        resourceId: resourceId,
        affectedIds: ids,
      ));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Query helpers (for UI via Application Layer)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<double> getAvailableQty(String resourceId) =>
      _repo.computeAvailableQty(resourceId);

  Future<double> getRemainingNeed(String requestId) =>
      _repo.computeRemainingNeed(requestId);

  /// 對外公開的 reconcile 入口 — 給 mesh handler 在 Materials_State /
  /// Requests_State 投影寫入後呼叫,處理「handshakeComplete 先到、supply/request
  /// 事件後到」的亂序場景。若沒有對應的 COMPLETED Match_Negotiations,reconcile
  /// 是 no-op,不會誤改狀態。
  ///
  /// 設計理由:不發 mesh 事件、純本機 DB 查詢 + 至多一次 UPDATE,無網路風暴風險。
  Future<void> reconcileMaterialStatus(String resourceId) =>
      _reconcileMaterialStatus(resourceId);

  Future<void> reconcileRequestStatus(String requestId) =>
      _reconcileRequestStatus(requestId);

  Future<Map<String, dynamic>?> getNegotiation(String negotiationId) =>
      _repo.getById(negotiationId);

  Future<List<Map<String, dynamic>>> getActiveNegotiations() =>
      _repo.getActiveNegotiations();

  Future<List<Map<String, dynamic>>> getMyNegotiations(
          Uint8List myPubKey) =>
      _repo.getMyNegotiations(myPubKey);

  Future<List<Map<String, dynamic>>> getNegotiationsForResource(
          String resourceId,
          {List<String>? statuses}) =>
      _repo.getByResource(resourceId, statuses: statuses);

  Future<List<Map<String, dynamic>>> getNegotiationsForRequest(
          String requestId,
          {List<String>? statuses}) =>
      _repo.getByRequest(requestId, statuses: statuses);

  // ═══════════════════════════════════════════════════════════════════════════
  //  Internal helpers
  // ═══════════════════════════════════════════════════════════════════════════

  bool _isParticipant(Map<String, dynamic> negotiation, List<int> senderPubKey) {
    final providerKey = negotiation['provider_pub_key'] as Uint8List;
    final requesterKey = negotiation['requester_pub_key'] as Uint8List;
    return bytesEqual(senderPubKey, providerKey) ||
        bytesEqual(senderPubKey, requesterKey);
  }

  bool _isResponder(Map<String, dynamic> negotiation, List<int> senderPubKey) {
    final initiatorRole = negotiation['initiator_role'] as String;
    if (initiatorRole == 'PROVIDER') {
      return bytesEqual(
          senderPubKey, negotiation['requester_pub_key'] as Uint8List);
    } else {
      return bytesEqual(
          senderPubKey, negotiation['provider_pub_key'] as Uint8List);
    }
  }

  Future<void> _reconcileMaterialStatus(String resourceId) async {
    final available = await _repo.computeAvailableQty(resourceId);
    final db = await _db.database;

    final mat = await db.query('Materials_State',
        columns: ['total_qty', 'status'],
        where: 'resource_id = ?',
        whereArgs: [resourceId],
        limit: 1);
    if (mat.isEmpty) return;

    final totalQty = (mat.first['total_qty'] as num?)?.toDouble() ?? 0.0;
    if (totalQty <= 0) return;

    // Check if all negotiations completed
    final allNeg = await _repo.getByResource(resourceId);
    final activeOrAccepted = allNeg.where((n) {
      final s = n['status'] as String;
      return s == 'PENDING' || s == 'ACCEPTED' || s == 'NAVIGATING';
    });
    final completedNeg =
        allNeg.where((n) => n['status'] == 'COMPLETED');

    if (available <= 0 && activeOrAccepted.isEmpty && completedNeg.isNotEmpty) {
      await db.update('Materials_State', {'status': 'CONSUMED'},
          where: 'resource_id = ?', whereArgs: [resourceId]);
    } else if (available <= 0) {
      await db.update('Materials_State', {'status': 'DEPLETED'},
          where: 'resource_id = ?', whereArgs: [resourceId]);
    } else {
      await db.update('Materials_State', {'status': 'AVAILABLE'},
          where: 'resource_id = ?', whereArgs: [resourceId]);
    }
  }

  Future<void> _reconcileRequestStatus(String requestId) async {
    final remaining = await _repo.computeRemainingNeed(requestId);
    final db = await _db.database;

    final req = await db.query('Requests_State',
        where: 'request_id = ?', whereArgs: [requestId], limit: 1);
    if (req.isEmpty) return;

    final currentStatus = req.first['status'] as String;
    if (currentStatus == 'CANCELLED' || currentStatus == 'FULFILLED') return;

    final activeNeg = await _repo.getByRequest(requestId,
        statuses: ['ACCEPTED', 'NAVIGATING', 'COMPLETED']);

    if (remaining <= 0 &&
        activeNeg.every((n) => n['status'] == 'COMPLETED')) {
      await db.update('Requests_State', {'status': 'FULFILLED'},
          where: 'request_id = ?', whereArgs: [requestId]);
    } else if (activeNeg
        .any((n) => n['status'] == 'ACCEPTED' || n['status'] == 'NAVIGATING')) {
      await db.update('Requests_State', {'status': 'MATCHED'},
          where: 'request_id = ?', whereArgs: [requestId]);
    } else {
      await db.update('Requests_State', {'status': 'OPEN'},
          where: 'request_id = ?', whereArgs: [requestId]);
    }
  }

  // ── 孤兒事件緩衝 ──

  void _bufferOrphan(String negotiationId, int eventType,
      List<int> senderPubKey, List<int> payload) {
    final key = '$negotiationId:$eventType';
    _orphanBuffer[key] = _OrphanEvent(eventType, payload, senderPubKey);

    Future.delayed(const Duration(seconds: 30), () {
      final orphan = _orphanBuffer.remove(key);
      if (orphan != null) {
        handleRemoteEvent(orphan.eventType, orphan.payload, orphan.senderPubKey);
      }
    });
  }

  Future<void> retryOrphanEvents() async {
    final orphans = await _repo.getRetryableOrphans();
    for (final orphan in orphans) {
      final eventId = orphan['event_id'] as String;
      final eventType = orphan['event_type'] as int;
      final payload = orphan['payload'] as Uint8List;

      // For HANDSHAKE_COMPLETE, try to find the negotiation
      if (eventType == handshakeComplete) {
        try {
          final data = pb.HandshakeCompleteData.fromBuffer(payload);
          final neg = await _repo.getById(data.negotiationId);
          if (neg != null) {
            await completeHandshake(
                data.negotiationId, data.providerPubKey, data.actualDeliveredQty);
            await _repo.deleteOrphan(eventId);
            continue;
          }
        } catch (_) {}
      }

      final retryCount = orphan['retry_count'] as int;
      await _repo.incrementOrphanRetry(eventId, retryCount);
    }

    await _repo.purgeOldOrphans();
  }
}

class _OrphanEvent {
  final int eventType;
  final List<int> payload;
  final List<int> senderPubKey;
  _OrphanEvent(this.eventType, this.payload, this.senderPubKey);
}
