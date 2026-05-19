import 'dart:io';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:ignirelay_app/app/services/medical_card_repo.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;
  late final MedicalCardRepo _medicalCardRepo = MedicalCardRepo(this);

  /// Stage 5-fix：測試專用 DB 路徑覆蓋。
  ///
  /// 預設為 `null` → 走 `getDatabasesPath()/resqmesh_local.db`（正式行為）。
  /// 測試端在 `setUpAll` 設為 `inMemoryDatabasePath`（即 `:memory:`），讓
  /// 多個測試檔在 `flutter test` 平行 isolate 時各自開獨立 in-memory DB，
  /// 避免共享磁碟檔造成 UNIQUE constraint / database is locked 偶發 flake。
  @visibleForTesting
  static String? testDatabasePathOverride;

  /// Stage 5-fix：測試專用——丟掉現有 connection（in-memory 模式下相當於清庫）。
  /// 在 `setUp`/`tearDown` 呼叫可保證 test 間零殘留狀態。
  @visibleForTesting
  Future<void> resetForTest() async {
    await _db?.close();
    _db = null;
  }

  /// Exposed for MedicalCardRepo (and other repos) to access the DB.
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final overridePath = testDatabasePathOverride;
    final path = overridePath ??
        join(await getDatabasesPath(), 'resqmesh_local.db');

    return await openDatabase(
      path,
      version: 11,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2: 新增醫療卡欄位 (JSON TEXT)
      await db.execute('ALTER TABLE Local_Users ADD COLUMN medical_card TEXT');
    }
    if (oldVersion < 3) {
      // v3: 危險標記增加確認計數 / 描述 / 更新時間
      await db.execute(
          'ALTER TABLE Hazards_State ADD COLUMN confirm_count INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE Hazards_State ADD COLUMN description TEXT');
      await db
          .execute('ALTER TABLE Hazards_State ADD COLUMN updated_at INTEGER');
    }
    if (oldVersion < 4) {
      // v4: Event_Logs 新增事件原始創建者座標（用於 Zone-Based 地理圍欄路由）
      await db.execute(
          'ALTER TABLE Event_Logs ADD COLUMN origin_lat REAL');
      await db.execute(
          'ALTER TABLE Event_Logs ADD COLUMN origin_lng REAL');
    }
    if (oldVersion < 5) {
      // v5: 據點額度追蹤 + 聊天室
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Station_Quotas (
          station_resource_id TEXT NOT NULL,
          user_pub_key BLOB NOT NULL,
          category TEXT NOT NULL,
          used_quantity INTEGER NOT NULL DEFAULT 0,
          total_used INTEGER NOT NULL DEFAULT 0,
          last_reset_at INTEGER NOT NULL,
          PRIMARY KEY (station_resource_id, user_pub_key, category)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Chat_Rooms (
          room_id TEXT PRIMARY KEY,
          room_name TEXT NOT NULL,
          room_type TEXT NOT NULL,
          rate_limit_seconds INTEGER NOT NULL DEFAULT 180,
          admin_only INTEGER NOT NULL DEFAULT 0,
          join_token_hash TEXT,
          joined_at INTEGER NOT NULL,
          last_read_hlc INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Chat_Messages (
          event_id TEXT PRIMARY KEY,
          room_id TEXT NOT NULL,
          sender_pub_key BLOB NOT NULL,
          content TEXT NOT NULL,
          reply_to TEXT,
          hlc_timestamp INTEGER NOT NULL,
          FOREIGN KEY (room_id) REFERENCES Chat_Rooms(room_id)
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_chat_messages_room ON Chat_Messages(room_id, hlc_timestamp)');
    }
    if (oldVersion < 6) {
      // v6: Debug_Logs 持久化（24h TTL，正式版移除）
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Debug_Logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp INTEGER NOT NULL,
          source TEXT NOT NULL,
          message TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 7) {
      // v7: 需求狀態表 + 媒合 Session 表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Requests_State (
          request_id TEXT PRIMARY KEY,
          event_id TEXT NOT NULL,
          sender_pub_key BLOB NOT NULL,
          status TEXT NOT NULL DEFAULT 'AVAILABLE',
          hlc_timestamp INTEGER NOT NULL,
          hlc_counter INTEGER NOT NULL,
          matched_resource_id TEXT,
          match_expires_at INTEGER,
          payload BLOB
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Match_Sessions (
          session_id TEXT PRIMARY KEY,
          resource_id TEXT NOT NULL,
          request_id TEXT NOT NULL,
          provider_pub_key BLOB NOT NULL,
          requester_pub_key BLOB NOT NULL,
          status TEXT NOT NULL DEFAULT 'ACTIVE',
          provider_lat REAL,
          provider_lng REAL,
          requester_lat REAL,
          requester_lng REAL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          completed_at INTEGER
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_match_sessions_status ON Match_Sessions(status)');
    }
    if (oldVersion < 8) {
      // 1. Safety check: Match_Sessions may not exist in some upgrade paths
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='Match_Sessions'");
      if (tables.isNotEmpty) {
        await db.execute('ALTER TABLE Match_Sessions RENAME TO Match_Sessions_v7_backup');
      }

      // 2. Create Match_Negotiations table
      await db.execute('''
        CREATE TABLE Match_Negotiations (
          negotiation_id TEXT PRIMARY KEY,
          resource_id TEXT NOT NULL,
          request_id TEXT NOT NULL,
          initiator_role TEXT NOT NULL,
          provider_pub_key BLOB NOT NULL,
          requester_pub_key BLOB NOT NULL,
          offered_qty REAL NOT NULL,
          requested_qty REAL NOT NULL,
          agreed_qty REAL,
          status TEXT NOT NULL DEFAULT 'PENDING',
          provider_lat REAL,
          provider_lng REAL,
          requester_lat REAL,
          requester_lng REAL,
          actual_delivered_qty REAL,
          handshake_method TEXT,
          created_at INTEGER NOT NULL,
          expires_at INTEGER NOT NULL,
          responded_at INTEGER,
          navigating_at INTEGER,
          completed_at INTEGER,
          match_score REAL
        )
      ''');

      // 3. Create indexes
      await db.execute('''
        CREATE UNIQUE INDEX idx_active_negotiation
        ON Match_Negotiations (resource_id, request_id)
        WHERE status IN ('PENDING', 'ACCEPTED', 'NAVIGATING')
      ''');
      await db.execute(
        'CREATE INDEX idx_negotiation_status ON Match_Negotiations (status)');
      await db.execute(
        'CREATE INDEX idx_negotiation_resource ON Match_Negotiations (resource_id, status)');
      await db.execute(
        'CREATE INDEX idx_negotiation_request ON Match_Negotiations (request_id, status)');

      // 4. Materials_State: add total_qty and delivery_mode columns
      await db.execute('ALTER TABLE Materials_State ADD COLUMN total_qty REAL');
      await db.execute('ALTER TABLE Materials_State ADD COLUMN delivery_mode TEXT');

      // 5. Requests_State: add quantity_needed, mobility_mode, note columns
      await db.execute('ALTER TABLE Requests_State ADD COLUMN quantity_needed REAL');
      await db.execute('ALTER TABLE Requests_State ADD COLUMN mobility_mode TEXT');
      await db.execute('ALTER TABLE Requests_State ADD COLUMN note TEXT');

      // 6. Reset old PENDING/LOCKED statuses to AVAILABLE
      await db.execute('''
        UPDATE Materials_State
        SET status = 'AVAILABLE', matched_request_id = NULL, match_expires_at = NULL
        WHERE status IN ('PENDING', 'LOCKED')
      ''');

      // 7. Requests_State: rename AVAILABLE to OPEN, reset LOCKED
      await db.execute('''
        UPDATE Requests_State SET status = 'OPEN'
        WHERE status IN ('AVAILABLE', 'LOCKED')
      ''');

      // 8. Create Orphan_Events table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Orphan_Events (
          event_id TEXT PRIMARY KEY,
          event_type INTEGER NOT NULL,
          payload BLOB NOT NULL,
          buffered_at INTEGER NOT NULL,
          retry_count INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 9) {
      // v0.3 Stage 0c1 — Envelope v2 storage scaffold (additive).
      // Spec: docs/specs/envelope_v2_spec_2026-05-13.md §12.
      // The new tables sit alongside the legacy Event_Logs table; the v0.3
      // dispatcher reads `Envelopes_V2` while v0.2.x writers continue to feed
      // Event_Logs until the wire flip happens. After the wire flip, Event_Logs
      // becomes a debug-only history table.
      await _createEnvelopeV2Tables(db);
    }
    if (oldVersion < 10) {
      // v0.3 Stage 0c wave 3F — Outbox_V2 for EventPublisherV2Facade
      // pending-queue persistence. Survives process death so 0d scenarios
      // that test "publish while last peer is dropping" / "publish before
      // first peer completes HELLO" can include a restart in the middle
      // without losing the message.
      await _createOutboxV2Table(db);
    }
    if (oldVersion < 11) {
      // v0.3 Stage 0c wave 3F-r3 — Outbox_V2 now stores the pre-allocated
      // `envelope_id` so restart-driven re-sends emit the SAME id the first
      // attempt did. Without this, GPT review surfaced that
      // `MessagePublisherV2.send()` would mint a fresh UUIDv7 every drain,
      // defeating receiver-side dedup for non-LWW events (SOS / HAZARD /
      // CHAT) and producing duplicates on the receiver.
      //
      // Migration approach: drop & recreate. Justification:
      //   • Wave 3F's v10 schema has NOT shipped to any production device
      //     (committed only on dev workstations, see Stage 0c wave 3F-r2
      //     "honest caveats" — schema migration was not yet device-tested).
      //   • The Outbox_V2 table is ephemeral by contract — bounded queue
      //     with cap-eviction + TTL drop. Losing in-flight rows on
      //     migration is functionally equivalent to a single process
      //     restart during the same window.
      //   • `ALTER TABLE ADD COLUMN ... NOT NULL` requires a default
      //     value sqflite can fill, but `envelope_id` has no sensible
      //     synthetic default (any bytes we invent would still be a
      //     fresh id per row, defeating the whole point).
      await db.execute('DROP TABLE IF EXISTS Outbox_V2');
      await _createOutboxV2Table(db);
    }
  }

  /// v0.3 Stage 0c1 — schema for the Envelope v2 storage layer.
  /// Spec: docs/specs/envelope_v2_spec_2026-05-13.md §12.
  Future<void> _createEnvelopeV2Tables(Database db) async {
    // §12.1 db_version single-row table.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Db_Version_V2 (
        id          INTEGER PRIMARY KEY CHECK (id = 1),
        schema_ver  INTEGER NOT NULL,
        applied_at  INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      INSERT OR REPLACE INTO Db_Version_V2 (id, schema_ver, applied_at)
      VALUES (1, 2, ${DateTime.now().millisecondsSinceEpoch})
    ''');

    // §12.2 Envelopes (primary store).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Envelopes_V2 (
        envelope_id        BLOB PRIMARY KEY,
        protocol_version   INTEGER NOT NULL,
        event_type         INTEGER NOT NULL,
        priority           INTEGER NOT NULL,
        created_at_hlc_ms  INTEGER NOT NULL,
        created_at_hlc_ctr INTEGER NOT NULL,
        expires_at_hlc_ms  INTEGER NOT NULL,
        expires_at_hlc_ctr INTEGER NOT NULL,
        max_hops           INTEGER NOT NULL,
        hop_count_seen     INTEGER NOT NULL DEFAULT 0,
        author_key         BLOB NOT NULL,
        sig_algo           INTEGER NOT NULL,
        signature          BLOB NOT NULL,
        payload            BLOB NOT NULL,
        signature_status   INTEGER NOT NULL,
        source_trust       INTEGER NOT NULL,
        last_relay_id      TEXT,
        is_experimental    INTEGER NOT NULL DEFAULT 0,
        relay_attempt_count INTEGER NOT NULL DEFAULT 0,
        is_tombstoned      INTEGER NOT NULL DEFAULT 0,
        was_surfaced_in_ui INTEGER NOT NULL DEFAULT 0,
        received_at_ms     INTEGER NOT NULL,
        first_seen_via     TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_envelopes_v2_event_type ON Envelopes_V2 (event_type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_envelopes_v2_priority ON Envelopes_V2 (priority)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_envelopes_v2_created_hlc ON Envelopes_V2 (created_at_hlc_ms DESC, created_at_hlc_ctr DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_envelopes_v2_expires_hlc ON Envelopes_V2 (expires_at_hlc_ms)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_envelopes_v2_author_key ON Envelopes_V2 (author_key)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_envelopes_v2_lww_lookup ON Envelopes_V2 (author_key, event_type, created_at_hlc_ms DESC, created_at_hlc_ctr DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_envelopes_v2_tombstoned ON Envelopes_V2 (is_tombstoned)');

    // §12.3 LWW current-winner cache.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Lww_Index_V2 (
        lww_key_hash        BLOB PRIMARY KEY,
        event_type          INTEGER NOT NULL,
        winning_envelope_id BLOB NOT NULL REFERENCES Envelopes_V2 (envelope_id) ON DELETE CASCADE,
        winning_hlc_ms      INTEGER NOT NULL,
        winning_hlc_ctr     INTEGER NOT NULL,
        updated_at_ms       INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_lww_index_v2_event_type ON Lww_Index_V2 (event_type)');

    // §12.4 Tombstones.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Tombstones_V2 (
        envelope_id        BLOB PRIMARY KEY,
        event_type         INTEGER NOT NULL,
        expired_at_ms      INTEGER NOT NULL,
        tombstone_until_ms INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tombstones_v2_until ON Tombstones_V2 (tombstone_until_ms)');

    // §15 dev-only structured mesh trace log (NOT folded into Debug_Logs).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Mesh_Trace_Logs (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        ts_ms               INTEGER NOT NULL,
        envelope_id         BLOB NOT NULL,
        event_type          INTEGER NOT NULL,
        priority            INTEGER NOT NULL,
        author_key_hash     BLOB NOT NULL,
        last_relay_id       TEXT,
        created_at_hlc_ms   INTEGER NOT NULL,
        expires_at_hlc_ms   INTEGER NOT NULL,
        action              INTEGER NOT NULL,
        drop_reason         TEXT,
        dedupe_outcome      INTEGER,
        signature_status    INTEGER,
        source_trust        INTEGER,
        hop_count_seen      INTEGER,
        relay_attempt_count INTEGER,
        peer_id             TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_mesh_trace_ts ON Mesh_Trace_Logs (ts_ms)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_mesh_trace_envelope_id ON Mesh_Trace_Logs (envelope_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_mesh_trace_action ON Mesh_Trace_Logs (action)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_mesh_trace_drop_reason ON Mesh_Trace_Logs (drop_reason)');

    // §12.6 Official_Sources (NCDR / CWA pubkey list).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Official_Sources_V2 (
        author_key    BLOB PRIMARY KEY,
        provider_name TEXT NOT NULL,
        added_at_ms   INTEGER NOT NULL,
        trust_label   INTEGER NOT NULL
      )
    ''');
  }

  /// v0.3 Stage 0c wave 3F / 3F-r3 — schema for the EventPublisherV2Facade
  /// pending queue. One row per queued (not-yet-broadcast) envelope. The
  /// facade hydrates its in-memory queue from this table on construction;
  /// drains and TTL expiries delete rows.
  ///
  /// Schema notes:
  ///   • `id` is an auto-increment so the natural FIFO order is preserved
  ///     across restarts (oldest = lowest id).
  ///   • `envelope_id` is the 16-byte UUIDv7 the facade pre-allocates at
  ///     `_broadcast()` time. PERSISTING it (added in wave 3F-r3) is what
  ///     makes restart-driven re-sends idempotent: the same envelope_id
  ///     goes out the second time, so receiver-side dedup
  ///     (`Envelopes_V2.envelope_id` PK + `Tombstones_V2`) drops the
  ///     duplicate. Without this, non-LWW events (SOS / HAZARD / CHAT)
  ///     would surface twice in the receiver UI after a restart-mid-drain.
  ///     UNIQUE so a buggy double-insert can't silently double-send.
  ///   • HLC pair is preserved so spec §10.2 LWW semantics survive the
  ///     queue→peer window, even across process death. The pre-allocated
  ///     envelope_id MUST share a clock with this HLC (i.e., be generated
  ///     at the same `_broadcast()` call) so envelope_id ↔ HLC ordering
  ///     stays consistent across restart.
  ///   • `deliveredTo` Set is INTENTIONALLY NOT persisted — after a
  ///     restart we may re-send to peers we already reached, but with
  ///     envelope_id now stable across the restart, receiver-side dedup
  ///     on `envelope_id` PK makes re-delivery idempotent. A junction
  ///     table tracking per-peer delivery would be cleaner but is
  ///     overkill for wave 3F.
  Future<void> _createOutboxV2Table(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Outbox_V2 (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        envelope_id         BLOB NOT NULL UNIQUE,
        event_type          INTEGER NOT NULL,
        priority            INTEGER NOT NULL,
        payload             BLOB NOT NULL,
        created_at_hlc_ms   INTEGER NOT NULL,
        created_at_hlc_ctr  INTEGER NOT NULL,
        expires_at_hlc_ms   INTEGER NOT NULL,
        expires_at_hlc_ctr  INTEGER NOT NULL,
        max_hops            INTEGER NOT NULL,
        enqueued_at_ms      INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_outbox_v2_enqueued ON Outbox_V2 (enqueued_at_ms)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_outbox_v2_expires ON Outbox_V2 (expires_at_hlc_ms)');
  }

  Future<void> _onCreate(Database db, int version) async {
    // Local_Users (節點身分與信任矩陣)
    await db.execute('''
      CREATE TABLE Local_Users (
        pub_key BLOB PRIMARY KEY,
        alias TEXT,
        identity_level INTEGER NOT NULL DEFAULT 0,
        badges TEXT,
        trust_score INTEGER NOT NULL DEFAULT 20,
        rate_limit_counter INTEGER NOT NULL DEFAULT 0,
        rate_limit_window_start INTEGER NOT NULL DEFAULT 0,
        quarantine_votes_weight REAL NOT NULL DEFAULT 0.0,
        is_blacklisted INTEGER NOT NULL DEFAULT 0,
        medical_card TEXT
      )
    ''');

    // Event_Logs (所有 Mesh 事件溯源核心)
    await db.execute('''
      CREATE TABLE Event_Logs (
        event_id TEXT PRIMARY KEY,
        sender_pub_key BLOB NOT NULL,
        identity_level INTEGER NOT NULL,
        event_type INTEGER NOT NULL,
        urgency INTEGER NOT NULL,
        hlc_timestamp INTEGER NOT NULL,
        hlc_counter INTEGER NOT NULL,
        ttl INTEGER NOT NULL,
        received_lat REAL,
        received_lng REAL,
        origin_lat REAL,
        origin_lng REAL,
        node_tier INTEGER NOT NULL,
        chunk_index INTEGER,
        total_chunks INTEGER,
        payload BLOB,
        signature BLOB NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_event_logs_hlc ON Event_Logs(hlc_timestamp, hlc_counter)');

    // Materials_State (物資狀態投影表 CRDT)
    await db.execute('''
      CREATE TABLE Materials_State (
        resource_id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        hlc_timestamp INTEGER NOT NULL,
        hlc_counter INTEGER NOT NULL,
        matched_request_id TEXT,
        match_expires_at INTEGER,
        payload BLOB,
        total_qty REAL,
        delivery_mode TEXT
      )
    ''');

    // Hazards_State (動態危險圖層投影表)
    await db.execute('''
      CREATE TABLE Hazards_State (
        hazard_id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        severity INTEGER NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        radius REAL NOT NULL,
        reported_by TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        confirm_count INTEGER NOT NULL DEFAULT 1,
        description TEXT,
        updated_at INTEGER
      )
    ''');

    // GeoContext_Cache (地理環境快取表)
    await db.execute('''
      CREATE TABLE GeoContext_Cache (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        lat REAL,
        lng REAL,
        environment_type TEXT,
        suggested_range_meters REAL,
        resolved_at INTEGER,
        nearest_place_class TEXT
      )
    ''');

    // Station_Quotas (據點個人申請額度)
    await db.execute('''
      CREATE TABLE Station_Quotas (
        station_resource_id TEXT NOT NULL,
        user_pub_key BLOB NOT NULL,
        category TEXT NOT NULL,
        used_quantity INTEGER NOT NULL DEFAULT 0,
        total_used INTEGER NOT NULL DEFAULT 0,
        last_reset_at INTEGER NOT NULL,
        PRIMARY KEY (station_resource_id, user_pub_key, category)
      )
    ''');

    // Chat_Rooms (聊天室)
    await db.execute('''
      CREATE TABLE Chat_Rooms (
        room_id TEXT PRIMARY KEY,
        room_name TEXT NOT NULL,
        room_type TEXT NOT NULL,
        rate_limit_seconds INTEGER NOT NULL DEFAULT 180,
        admin_only INTEGER NOT NULL DEFAULT 0,
        join_token_hash TEXT,
        joined_at INTEGER NOT NULL,
        last_read_hlc INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Chat_Messages (聊天訊息)
    await db.execute('''
      CREATE TABLE Chat_Messages (
        event_id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        sender_pub_key BLOB NOT NULL,
        content TEXT NOT NULL,
        reply_to TEXT,
        hlc_timestamp INTEGER NOT NULL,
        FOREIGN KEY (room_id) REFERENCES Chat_Rooms(room_id)
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_chat_messages_room ON Chat_Messages(room_id, hlc_timestamp)');

    // Debug_Logs (除錯日誌持久化，24h TTL，正式版移除)
    await db.execute('''
      CREATE TABLE Debug_Logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        source TEXT NOT NULL,
        message TEXT NOT NULL
      )
    ''');

    // Orphan_Events (孤立事件緩衝表)
    await db.execute('''
      CREATE TABLE Orphan_Events (
        event_id TEXT PRIMARY KEY,
        event_type INTEGER NOT NULL,
        payload BLOB NOT NULL,
        buffered_at INTEGER NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Requests_State (需求狀態投影表)
    await db.execute('''
      CREATE TABLE Requests_State (
        request_id TEXT PRIMARY KEY,
        event_id TEXT NOT NULL,
        sender_pub_key BLOB NOT NULL,
        status TEXT NOT NULL DEFAULT 'OPEN',
        hlc_timestamp INTEGER NOT NULL,
        hlc_counter INTEGER NOT NULL,
        matched_resource_id TEXT,
        match_expires_at INTEGER,
        payload BLOB,
        quantity_needed REAL,
        mobility_mode TEXT,
        note TEXT
      )
    ''');

    // Match_Negotiations (媒合協商追蹤表)
    await db.execute('''
      CREATE TABLE Match_Negotiations (
        negotiation_id TEXT PRIMARY KEY,
        resource_id TEXT NOT NULL,
        request_id TEXT NOT NULL,
        initiator_role TEXT NOT NULL,
        provider_pub_key BLOB NOT NULL,
        requester_pub_key BLOB NOT NULL,
        offered_qty REAL NOT NULL,
        requested_qty REAL NOT NULL,
        agreed_qty REAL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        provider_lat REAL,
        provider_lng REAL,
        requester_lat REAL,
        requester_lng REAL,
        actual_delivered_qty REAL,
        handshake_method TEXT,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        responded_at INTEGER,
        navigating_at INTEGER,
        completed_at INTEGER,
        match_score REAL
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX idx_active_negotiation
      ON Match_Negotiations (resource_id, request_id)
      WHERE status IN ('PENDING', 'ACCEPTED', 'NAVIGATING')
    ''');
    await db.execute(
        'CREATE INDEX idx_negotiation_status ON Match_Negotiations (status)');
    await db.execute(
        'CREATE INDEX idx_negotiation_resource ON Match_Negotiations (resource_id, status)');
    await db.execute(
        'CREATE INDEX idx_negotiation_request ON Match_Negotiations (request_id, status)');

    // 初始化 GeoContext
    await db.execute('''
      INSERT INTO GeoContext_Cache (id, environment_type, suggested_range_meters)
      VALUES (1, 'URBAN', 1000.0)
    ''');

    // v0.3 Stage 0c1 — new installs must get the additive Envelope v2 schema
    // too. Upgrades enter through _onUpgrade(oldVersion < 9).
    await _createEnvelopeV2Tables(db);
    // v0.3 Stage 0c wave 3F — same for Outbox_V2.
    await _createOutboxV2Table(db);
  }

  // --- DAO 方法 ---

  /// 資料淘汰策略 (NFR_05)
  /// 優先淘汰 ttl <= 0 且 urgency == INFO (0) 的事件，保留 SOS_RED (3)
  /// 若 DB 大小仍超過 maxBytes，繼續刪較舊的低優先級事件
  Future<void> purgeOldData(int maxBytes) async {
    final db = await database;

    // 第一輪：刪已同步的 INFO 過期事件
    await db.execute('''
      DELETE FROM Event_Logs 
      WHERE ttl <= 0 AND urgency = 0 AND is_synced = 1
    ''');

    // 檢查 DB 實際大小
    final dbPath = db.path;
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) return;

    int currentSize = dbFile.lengthSync();
    if (currentSize <= maxBytes) return;

    // 第二輪：刪已同步的 RESOURCE 事件（保留最近 100 條）
    await db.execute('''
      DELETE FROM Event_Logs 
      WHERE urgency <= 1 AND is_synced = 1
      AND event_id NOT IN (
        SELECT event_id FROM Event_Logs 
        WHERE urgency <= 1 
        ORDER BY hlc_timestamp DESC LIMIT 100
      )
    ''');

    currentSize = dbFile.lengthSync();
    if (currentSize <= maxBytes) return;

    // 第三輪：刪超過 48 小時的非 SOS_RED 事件
    final cutoff = DateTime.now().millisecondsSinceEpoch - (48 * 3600 * 1000);
    await db.execute('''
      DELETE FROM Event_Logs 
      WHERE urgency < 3 AND hlc_timestamp < ?
    ''', [cutoff]);
  }

  /// 插入本機使用者（若不存在）
  Future<void> ensureLocalUser(
      List<int> pubKey, String alias, int level) async {
    final db = await database;
    await db.insert(
        'Local_Users',
        {
          'pub_key': pubKey,
          'alias': alias,
          'identity_level': level,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// 查詢事件總數
  Future<int> getEventCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM Event_Logs');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 儲存醫療卡 (JSON 字串) — delegates to MedicalCardRepo
  Future<void> saveMedicalCard(List<int> pubKey, String medicalCardJson) =>
      _medicalCardRepo.saveMedicalCard(pubKey, medicalCardJson);

  /// 寫入除錯日誌。
  ///
  /// 預設 fire-and-forget（呼叫端不需 await，效能不受影響）；
  /// Stage 7 起回傳 `Future<void>` 以便測試或必要時呼叫端可選擇 `await`，
  /// 解決原本 `void` 介面導致測試只能用 `Future.delayed` 等待造成的偶發 flake。
  Future<void> writeDebugLog(String source, String message) async {
    try {
      final db = await database;
      await db.insert('Debug_Logs', {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'source': source,
        'message': message,
      });
    } catch (_) {
      // 任何失敗皆吞掉：debug log 不應影響主流程
    }
  }

  /// 匯出全部除錯日誌
  Future<List<Map<String, dynamic>>> exportDebugLogs() async {
    final db = await database;
    return db.query('Debug_Logs', orderBy: 'id ASC');
  }

  /// 清理超過 24 小時的除錯日誌
  Future<int> purgeDebugLogs() async {
    final db = await database;
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - (24 * 60 * 60 * 1000);
    return db.delete('Debug_Logs',
        where: 'timestamp < ?', whereArgs: [cutoff]);
  }

  /// 讀取醫療卡 (JSON 字串) — delegates to MedicalCardRepo
  Future<String?> getMedicalCard(List<int> pubKey) =>
      _medicalCardRepo.getMedicalCard(pubKey);
}
