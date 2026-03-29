import 'dart:io';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'resqmesh_local.db');

    return await openDatabase(
      path,
      version: 6,
      onConfigure: (db) async {
        await db.execute('PRAGMA journal_mode=WAL');
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
        payload BLOB
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

    // 初始化 GeoContext
    await db.execute('''
      INSERT INTO GeoContext_Cache (id, environment_type, suggested_range_meters)
      VALUES (1, 'URBAN', 1000.0)
    ''');
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

  /// 儲存醫療卡 (JSON 字串)
  /// 使用 upsert 策略：先確保 Local_Users 記錄存在，再更新 medical_card
  Future<void> saveMedicalCard(List<int> pubKey, String medicalCardJson) async {
    final db = await database;
    final pubKeyBytes = Uint8List.fromList(pubKey);
    // 先確保用戶記錄存在（ConflictAlgorithm.ignore = 已存在則不動）
    await db.insert(
      'Local_Users',
      {
        'pub_key': pubKeyBytes,
        'alias': '',
        'identity_level': 0,
        'medical_card': medicalCardJson,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    // 再更新 medical_card 欄位（此時記錄一定存在）
    await db.update(
      'Local_Users',
      {'medical_card': medicalCardJson},
      where: 'pub_key = ?',
      whereArgs: [pubKeyBytes],
    );
  }

  /// 寫入除錯日誌（fire-and-forget，不影響效能）
  void writeDebugLog(String source, String message) {
    database.then((db) {
      db.insert('Debug_Logs', {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'source': source,
        'message': message,
      }).catchError((_) {});
    }).catchError((_) {});
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

  /// 讀取醫療卡 (JSON 字串)
  Future<String?> getMedicalCard(List<int> pubKey) async {
    final db = await database;
    final pubKeyBytes = Uint8List.fromList(pubKey);
    final result = await db.query(
      'Local_Users',
      columns: ['medical_card'],
      where: 'pub_key = ?',
      whereArgs: [pubKeyBytes],
    );
    if (result.isEmpty) return null;
    return result.first['medical_card'] as String?;
  }
}
