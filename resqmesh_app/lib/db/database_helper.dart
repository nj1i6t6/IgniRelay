import 'dart:io';
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
      version: 3,
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
  Future<void> saveMedicalCard(List<int> pubKey, String medicalCardJson) async {
    final db = await database;
    await db.update(
      'Local_Users',
      {'medical_card': medicalCardJson},
      where: 'pub_key = ?',
      whereArgs: [pubKey],
    );
  }

  /// 讀取醫療卡 (JSON 字串)
  Future<String?> getMedicalCard(List<int> pubKey) async {
    final db = await database;
    final result = await db.query(
      'Local_Users',
      columns: ['medical_card'],
      where: 'pub_key = ?',
      whereArgs: [pubKey],
    );
    if (result.isEmpty) return null;
    return result.first['medical_card'] as String?;
  }
}
