import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';

/// NegotiationRepo — 純 DB CRUD，無業務邏輯
/// 屬於 Application Layer，所有 Match_Negotiations 的讀寫都經過這裡
class NegotiationRepo {
  static final NegotiationRepo _instance = NegotiationRepo._internal();
  factory NegotiationRepo() => _instance;
  NegotiationRepo._internal();

  final _db = DatabaseHelper();

  Future<Database> get _database => _db.database;

  Future<Map<String, dynamic>?> getById(String negotiationId) async {
    final db = await _database;
    final rows = await db.query('Match_Negotiations',
        where: 'negotiation_id = ?', whereArgs: [negotiationId], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getByResource(String resourceId,
      {List<String>? statuses}) async {
    final db = await _database;
    if (statuses != null && statuses.isNotEmpty) {
      final placeholders = statuses.map((_) => '?').join(',');
      return db.rawQuery(
        'SELECT * FROM Match_Negotiations WHERE resource_id = ? AND status IN ($placeholders)',
        [resourceId, ...statuses],
      );
    }
    return db.query('Match_Negotiations',
        where: 'resource_id = ?', whereArgs: [resourceId]);
  }

  Future<List<Map<String, dynamic>>> getByRequest(String requestId,
      {List<String>? statuses}) async {
    final db = await _database;
    if (statuses != null && statuses.isNotEmpty) {
      final placeholders = statuses.map((_) => '?').join(',');
      return db.rawQuery(
        'SELECT * FROM Match_Negotiations WHERE request_id = ? AND status IN ($placeholders)',
        [requestId, ...statuses],
      );
    }
    return db.query('Match_Negotiations',
        where: 'request_id = ?', whereArgs: [requestId]);
  }

  Future<void> insert(Map<String, dynamic> row) async {
    final db = await _database;
    await db.insert('Match_Negotiations', row,
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> updateStatus(String negotiationId, String status,
      {Map<String, dynamic>? extra}) async {
    final db = await _database;
    final values = <String, dynamic>{'status': status};
    if (extra != null) values.addAll(extra);
    return db.update('Match_Negotiations', values,
        where: 'negotiation_id = ?', whereArgs: [negotiationId]);
  }

  /// 供給方可用餘量 (扣 ACCEPTED + NAVIGATING + COMPLETED)
  ///
  /// 對稱於 [computeRemainingNeed]：COMPLETED 的量已交付,不應再算可用。
  /// 之前漏扣 COMPLETED 會造成 `_reconcileMaterialStatus` 永遠看到 available > 0,
  /// Materials_State 永遠停在 AVAILABLE/DEPLETED,不會轉 CONSUMED。
  Future<double> computeAvailableQty(String resourceId) async {
    final db = await _database;
    final mat = await db.query('Materials_State',
        columns: ['total_qty'],
        where: 'resource_id = ?',
        whereArgs: [resourceId],
        limit: 1);
    if (mat.isEmpty) return 0.0;
    final totalQty = (mat.first['total_qty'] as num?)?.toDouble() ?? 0.0;

    final committed = await db.rawQuery('''
      SELECT COALESCE(SUM(agreed_qty), 0) as committed
      FROM Match_Negotiations
      WHERE resource_id = ? AND status IN ('ACCEPTED', 'NAVIGATING', 'COMPLETED')
    ''', [resourceId]);
    final used = (committed.first['committed'] as num?)?.toDouble() ?? 0.0;
    return totalQty - used;
  }

  /// 需求方仍需數量 (扣 ACCEPTED + NAVIGATING + COMPLETED)
  Future<double> computeRemainingNeed(String requestId) async {
    final db = await _database;
    final req = await db.query('Requests_State',
        columns: ['quantity_needed'],
        where: 'request_id = ?',
        whereArgs: [requestId],
        limit: 1);
    if (req.isEmpty) return 0.0;
    final needed = (req.first['quantity_needed'] as num?)?.toDouble() ?? 0.0;

    final fulfilled = await db.rawQuery('''
      SELECT COALESCE(SUM(agreed_qty), 0) as fulfilled
      FROM Match_Negotiations
      WHERE request_id = ? AND status IN ('ACCEPTED', 'NAVIGATING', 'COMPLETED')
    ''', [requestId]);
    final done = (fulfilled.first['fulfilled'] as num?)?.toDouble() ?? 0.0;
    return needed - done;
  }

  Future<int> countPendingForRequest(String requestId) async {
    final db = await _database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM Match_Negotiations
      WHERE request_id = ? AND status = 'PENDING'
    ''', [requestId]);
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// 查詢所有活躍協商 (for UI display)
  Future<List<Map<String, dynamic>>> getActiveNegotiations() async {
    final db = await _database;
    return db.query('Match_Negotiations',
        where: "status IN ('PENDING', 'ACCEPTED', 'NAVIGATING')",
        orderBy: 'created_at DESC');
  }

  /// 查某 resource 是否已有活躍 ACCEPTED/NAVIGATING
  Future<int> countActiveAccepted(String resourceId) async {
    final db = await _database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM Match_Negotiations
      WHERE resource_id = ? AND status IN ('ACCEPTED', 'NAVIGATING')
    ''', [resourceId]);
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// 取得已過期的 PENDING 協商
  Future<List<Map<String, dynamic>>> getExpiredPending(int now) async {
    final db = await _database;
    return db.rawQuery('''
      SELECT negotiation_id, resource_id, request_id
      FROM Match_Negotiations
      WHERE status = 'PENDING' AND expires_at < ?
    ''', [now]);
  }

  /// 取得可能過時的 ACCEPTED/NAVIGATING 協商
  Future<List<Map<String, dynamic>>> getStaleActive(int now) async {
    final db = await _database;
    return db.rawQuery('''
      SELECT negotiation_id FROM Match_Negotiations
      WHERE status IN ('ACCEPTED', 'NAVIGATING')
      AND (expires_at < ? OR
           (navigating_at IS NOT NULL AND ? - navigating_at > 14400000))
    ''', [now, now]);
  }

  /// 查詢我發起的或我參與的所有協商
  Future<List<Map<String, dynamic>>> getMyNegotiations(
      Uint8List myPubKey) async {
    final db = await _database;
    return db.rawQuery('''
      SELECT * FROM Match_Negotiations
      WHERE provider_pub_key = ? OR requester_pub_key = ?
      ORDER BY created_at DESC
    ''', [myPubKey, myPubKey]);
  }

  Future<Map<String, dynamic>?> queryNegotiation(String negotiationId) async {
    final db = await _database;
    final rows = await db.query('Match_Negotiations',
        where: 'negotiation_id = ?', whereArgs: [negotiationId]);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<Map<String, dynamic>?> queryPeerLocationForNegotiation(
      String negotiationId) async {
    final db = await _database;
    final rows = await db.query('Match_Negotiations',
        columns: ['provider_lat', 'provider_lng', 'requester_lat', 'requester_lng'],
        where: 'negotiation_id = ?',
        whereArgs: [negotiationId]);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<List<Map<String, dynamic>>> queryActiveNegotiations() async {
    final db = await _database;
    return db.query('Match_Negotiations',
        where: "status IN ('PENDING', 'ACCEPTED', 'NAVIGATING')",
        orderBy: 'updated_at DESC');
  }

  Future<List<Map<String, dynamic>>> queryByStatus(String status) async {
    final db = await _database;
    return db.query('Match_Negotiations',
        where: 'status = ?', whereArgs: [status], orderBy: 'updated_at DESC');
  }

  // ── Orphan_Events CRUD ──

  Future<void> insertOrphanEvent(
      String eventId, int eventType, List<int> payload) async {
    final db = await _database;
    await db.insert(
        'Orphan_Events',
        {
          'event_id': eventId,
          'event_type': eventType,
          'payload': Uint8List.fromList(payload),
          'buffered_at': DateTime.now().millisecondsSinceEpoch,
          'retry_count': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, dynamic>>> getRetryableOrphans() async {
    final db = await _database;
    return db.query('Orphan_Events',
        where: 'retry_count < 3', orderBy: 'buffered_at ASC');
  }

  Future<void> deleteOrphan(String eventId) async {
    final db = await _database;
    await db.delete('Orphan_Events',
        where: 'event_id = ?', whereArgs: [eventId]);
  }

  Future<void> incrementOrphanRetry(String eventId, int currentCount) async {
    final db = await _database;
    await db.update('Orphan_Events', {'retry_count': currentCount + 1},
        where: 'event_id = ?', whereArgs: [eventId]);
  }

  Future<void> purgeOldOrphans() async {
    final db = await _database;
    final cutoff = DateTime.now().millisecondsSinceEpoch - 86400000; // 24h
    await db.delete('Orphan_Events',
        where: 'buffered_at < ?', whereArgs: [cutoff]);
  }

  /// Transaction-based CAS accept (for split-brain safety)
  Future<Map<String, dynamic>?> casAcceptInTransaction(
    String negotiationId,
    double requestedQty,
  ) async {
    final db = await _database;
    return await db.transaction((txn) async {
      // 1. Read negotiation
      final neg = await txn.query('Match_Negotiations',
          where: 'negotiation_id = ? AND status = ?',
          whereArgs: [negotiationId, 'PENDING']);
      if (neg.isEmpty) return null;

      final resourceId = neg.first['resource_id'] as String;
      final requestId = neg.first['request_id'] as String;

      // 2. Read material info
      final mat = await txn.query('Materials_State',
          where: 'resource_id = ?', whereArgs: [resourceId]);
      if (mat.isEmpty) return null;
      final totalQty = (mat.first['total_qty'] as num?)?.toDouble() ?? 0.0;
      final deliveryMode = (mat.first['delivery_mode'] as String?) ?? 'PICKUP';

      // 3. Calculate committed quantity (對稱於 computeAvailableQty,含 COMPLETED)
      final committed = await txn.rawQuery('''
        SELECT COALESCE(SUM(agreed_qty), 0) as committed
        FROM Match_Negotiations
        WHERE resource_id = ? AND status IN ('ACCEPTED', 'NAVIGATING', 'COMPLETED')
      ''', [resourceId]);
      final usedQty =
          (committed.first['committed'] as num?)?.toDouble() ?? 0.0;
      final availableQty = totalQty - usedQty;

      // 4. Check request status (CAS dual-side check — rule 7)
      final req = await txn.query('Requests_State',
          where: 'request_id = ?', whereArgs: [requestId]);
      if (req.isEmpty) return null;
      final reqStatus = req.first['status'] as String;
      if (reqStatus != 'OPEN' && reqStatus != 'MATCHED') return null;

      // 5. DELIVER/DROP_OFF: only one active ACCEPTED at a time
      if (deliveryMode == 'DELIVER' || deliveryMode == 'DROP_OFF') {
        final activeCount = Sqflite.firstIntValue(await txn.rawQuery('''
          SELECT COUNT(*) FROM Match_Negotiations
          WHERE resource_id = ? AND status IN ('ACCEPTED', 'NAVIGATING')
        ''', [resourceId])) ?? 0;
        if (activeCount > 0) return null;
      }

      // 6. Inventory check (partial accept supported)
      final offeredQty =
          (neg.first['offered_qty'] as num?)?.toDouble() ?? requestedQty;
      final wantedQty = requestedQty > 0 ? requestedQty : offeredQty;
      final agreedQty = wantedQty < availableQty ? wantedQty : availableQty;
      if (agreedQty <= 0) return null;

      final now = DateTime.now().millisecondsSinceEpoch;
      // 4h expiry for ACCEPTED
      final expiresAt = now + 14400000;

      // 7. Update to ACCEPTED
      await txn.update(
          'Match_Negotiations',
          {
            'status': 'ACCEPTED',
            'agreed_qty': agreedQty,
            'responded_at': now,
            'expires_at': expiresAt,
          },
          where: 'negotiation_id = ?',
          whereArgs: [negotiationId]);

      // 8. Reconcile Materials_State
      final newAvailable = availableQty - agreedQty;
      await txn.update(
          'Materials_State',
          {
            'status': newAvailable <= 0 ? 'DEPLETED' : 'AVAILABLE',
          },
          where: 'resource_id = ?',
          whereArgs: [resourceId]);

      // 9. Update Requests_State
      await txn.update('Requests_State', {'status': 'MATCHED'},
          where: 'request_id = ?', whereArgs: [requestId]);

      return {
        'agreedQty': agreedQty,
        'resourceId': resourceId,
        'requestId': requestId,
        'negotiation': neg.first,
      };
    });
  }
}
