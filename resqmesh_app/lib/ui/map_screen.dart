import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_mbtiles/vector_map_tiles_mbtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;
import '../mesh/mbtiles_loader.dart';
import '../mesh/event_manager.dart';
import '../mesh/event_types.dart';
import '../mesh/poi_query.dart';
import '../db/database_helper.dart';
import 'ignirelay_sprites.dart';
import 'ignirelay_theme.dart';
import 'triage_input.dart';
import 'map_layer_settings.dart';
import '../mesh/mesh_event_handler.dart';
import '../proto/mesh_protocol.pb.dart' as pb;
import '../services/location_service.dart';
import 'supply_category_data.dart';
import '../l10n/generated/app_localizations.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final MapController _mapController = MapController();
  late final AnimationController _refreshSpinCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  bool _isRefreshing = false;
  // 預設台灣中心，GPS 取得後會更新
  LatLng _center = const LatLng(23.97, 120.97);
  final _eventManager = EventManager();

  // ── 地圖底圖 ──
  bool _mbtilesLoading = true;
  bool _mbtilesAvailable = false;
  String? _mbtilesError; // stores ARB key: 'mapMbtilesNotFound' | 'mapMbtilesLoadFail'
  String? _mbtilesErrorArg; // dynamic arg for mapMbtilesLoadFail
  MbTiles? _mbTiles;
  MbTilesVectorTileProvider? _tileProvider;
  TileProviders? _tileProviders;
  vtr.Theme? _mapTheme;
  SpriteStyle? _spriteStyle;
  PoiQuery? _poiQuery;

  // ── GPS 定位 ──
  LatLng? _userLocation;
  StreamSubscription<Position>? _positionStream;
  double _gpsAccuracy = 0;

  // ── Overlays ──
  List<Polygon> _hazardPolygons = [];
  List<Marker> _hazardCenterMarkers = [];
  List<Map<String, dynamic>> _hazardData = [];
  List<Marker> _eventMarkers = [];
  List<Marker> _poiMarkers = [];
  Timer? _refreshTimer;
  StreamSubscription? _meshEventSub;
  Timer? _meshDebounce;
  bool _showLegend = false;
  String _myReporterHex = '';

  // ── 圖層設定 ──
  final MapLayerSettings _layerSettings = MapLayerSettings();
  int _themeGeneration = 0;

  // ── POI 標記防抖 ──
  Timer? _poiRefreshTimer;

  // ── 危險標記模式 ──
  bool _isMarkingMode = false;
  LatLng? _markCenter;
  double _markRadius = 200.0;
  String _markType = 'ROADBLOCK';
  double _markSeverity = 3.0;
  final _markDescCtrl = TextEditingController();
  bool _markPublishing = false;
  String? _editingHazardId; // 非 null = 編輯模式


  // ── SOS 狀態追蹤 ──
  String? _activeSosEventId;
  int _activeSosUrgency = 0;
  String _activeSosDesc = '';

  static (String, IconData, Color) _hazardInfo(BuildContext context, String type) {
    final l = S.of(context)!;
    switch (type) {
      case 'ROADBLOCK': return (l.mapHazardRoadblock, Icons.block, Colors.orange);
      case 'FIRE': return (l.mapHazardFire, Icons.local_fire_department, Colors.red);
      case 'CHEMICAL': return (l.mapHazardChemical, Icons.warning_amber, Colors.yellow);
      case 'FLOOD': return (l.mapHazardFlood, Icons.water, Colors.blue);
      case 'BUILDING': return (l.mapHazardCollapse, Icons.domain_disabled, Colors.brown);
      case 'LANDSLIDE': return (l.mapHazardLandslide, Icons.landscape, Colors.grey);
      default: return (type, Icons.help, Colors.grey);
    }
  }

  @override
  void initState() {
    super.initState();
    _initMBTiles();
    _initGPS();
    _initReporterHex();
    _loadOverlays();
    // 每 15 秒自動刷新 overlay (危險區域 + Mesh 事件)
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _loadOverlays());
    // 監聽 Mesh 事件，即時刷新 overlay
    _meshEventSub = MeshEventHandler().events.listen((_) {
      _meshDebounce?.cancel();
      _meshDebounce = Timer(const Duration(seconds: 2), () {
        if (mounted) _loadOverlays();
      });
    });
    // 監聽圖層設定變化
    _layerSettings.addListener(_onLayerSettingsChanged);
  }

  @override
  void dispose() {
    _refreshSpinCtrl.dispose();
    _poiQuery?.dispose();
    _mbTiles?.dispose();
    _positionStream?.cancel();
    _refreshTimer?.cancel();
    _meshEventSub?.cancel();
    _meshDebounce?.cancel();
    _poiRefreshTimer?.cancel();
    _markDescCtrl.dispose();
    _layerSettings.removeListener(_onLayerSettingsChanged);
    _layerSettings.dispose();
    super.dispose();
  }

  Future<void> _initReporterHex() async {
    _myReporterHex = await _eventManager.getReporterHex();
  }

  void _onLayerSettingsChanged() {
    _rebuildTheme();
    _loadHazards();
    _refreshPoiMarkers(); // #3 Fix: 圖層控制變化時刷新 POI 圓點
  }

  void _rebuildTheme() {
    if (!_mbtilesAvailable || _mbTiles == null) return;
    final theme =
        buildIgniRelayTheme(disabledPoi: _layerSettings.disabledPoiIds);
    SpriteStyle? sprites;
    try {
      sprites = buildIgniRelaySprites();
    } catch (e) {
      debugPrint('[Map] rebuildTheme sprite 失敗 (非致命): $e');
    }
    // 重建 TileProviders → VectorTileLayer 用新 Key 完整重建
    final provider = MbTilesVectorTileProvider(mbtiles: _mbTiles!);
    if (mounted) {
      setState(() {
        _tileProvider = provider;
        _tileProviders = TileProviders({'openmaptiles': provider});
        _mapTheme = theme;
        _spriteStyle = sprites;
        _themeGeneration++;
      });
    }
  }

  // ── MBTiles 離線地圖初始化 ─────────────────────────────────────

  Future<void> _initMBTiles() async {
    try {
      final available = await MBTilesLoader.isAvailable();
      if (!available) {
        debugPrint('[Map] MBTiles NOT available');
        if (mounted) {
          setState(() {
            _mbtilesLoading = false;
            _mbtilesError = 'mapMbtilesNotFound';
          });
        }
        return;
      }

      final path = await MBTilesLoader.getLocalPath();
      await MBTilesLoader.sanitizeMetadata(path);

      // 複製 POI 詳情資料庫（首次啟動）
      final poiDbPath = await _ensurePoiDetailsDb();

      final mbTiles = MbTiles(mbtilesPath: path, gzip: true);
      final provider = MbTilesVectorTileProvider(mbtiles: mbTiles);
      final theme = buildIgniRelayTheme();

      // sprites 載入失敗不應阻止地圖渲染
      SpriteStyle? sprites;
      try {
        sprites = buildIgniRelaySprites();
      } catch (e) {
        debugPrint('[Map] Sprite 載入失敗 (非致命): $e');
      }

      // 驗證 tile 資料是否可讀取
      // MBTiles 使用 TMS 座標系 (Y 軸翻轉): tmsY = (2^z - 1) - xyzY
      // 台灣中心 z10/x859/y442(XYZ) → z10/x859/y581(TMS)
      String tileTestResult = 'untested';
      int tileTestBytes = 0;
      try {
        final tmsY = ((1 << 10) - 1) - 442; // = 581
        final testTile = mbTiles.getTile(z: 10, x: 859, y: tmsY);
        if (testTile != null) {
          tileTestBytes = testTile.length;
          tileTestResult = 'OK ${testTile.length}B';
        } else {
          // 也試試直接用 XYZ Y 看看（如果 MBTiles 是 XYZ 編碼）
          final testTileXyz = mbTiles.getTile(z: 10, x: 859, y: 442);
          if (testTileXyz != null) {
            tileTestBytes = testTileXyz.length;
            tileTestResult = 'OK(xyz) ${testTileXyz.length}B';
          } else {
            tileTestResult = 'NULL z10/859/tms$tmsY+xyz442';
          }
        }
      } catch (e) {
        tileTestResult = 'ERR: $e';
      }

      // 取得檔案大小
      final fileSize = File(path).lengthSync();
      final fileSizeMB = (fileSize / 1024 / 1024).toStringAsFixed(1);

      debugPrint(
          '[Map] MBTiles ready: path=$path, size=${fileSizeMB}MB, '
          'zoom=${provider.minimumZoom}-${provider.maximumZoom}, '
          'theme=${theme.layers.length} layers, sprites=${sprites != null ? "OK" : "NULL"}, '
          'tileTest=$tileTestResult');

      if (mounted) {
        setState(() {
          _mbTiles = mbTiles;
          _poiQuery = PoiQuery(mbtilesPath: path, poiDetailsPath: poiDbPath);
          _tileProvider = provider;
          _tileProviders = TileProviders({'openmaptiles': provider});
          _mapTheme = theme;
          _spriteStyle = sprites;
          _mbtilesAvailable = true;

        });
        _refreshPoiMarkers();
      }
    } catch (e, stack) {
      debugPrint('[Map] MBTiles init error: $e\n$stack');
      if (mounted) {
        setState(() {
        _mbtilesError = 'mapMbtilesLoadFail';
        _mbtilesErrorArg = e.toString();
      });
      }
    } finally {
      if (mounted) setState(() => _mbtilesLoading = false);
    }
  }

  /// 複製 poi_details.db 到 app 文件目錄（首次啟動）
  static Future<String?> _ensurePoiDetailsDb() async {
    const assetPath = 'assets/maps/poi_details.db';
    const fileName = 'poi_details.db';
    try {
      final dir = await getApplicationDocumentsDirectory();
      final target = File('${dir.path}/$fileName');
      if (!target.existsSync()) {
        final data = await rootBundle.load(assetPath);
        final bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await target.writeAsBytes(bytes, flush: true);
        debugPrint('[Map] POI details DB copied: ${target.lengthSync()} bytes');
      }
      return target.path;
    } catch (e) {
      debugPrint('[Map] POI details DB not available: $e');
      return null; // 退化模式：只有基本 POI 資訊
    }
  }

  // ── 台灣範圍判定 ────────────────────────────────────────────────────

  /// 檢查座標是否在台灣 MBTiles 範圍內（含外島緩衝）
  bool _isInTaiwanBounds(LatLng loc) {
    return loc.latitude >= 20.5 &&
        loc.latitude <= 26.8 &&
        loc.longitude >= 117.9 &&
        loc.longitude <= 123.1;
  }
  // ── GPS 定位 ────────────────────────────────────────────────────

  Future<void> _initGPS() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[GPS] Location service disabled');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[GPS] Permission denied');
        return;
      }

      // 取得初始位置
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('GPS timeout');
      });

      if (mounted) {
        final loc = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _userLocation = loc;
          _gpsAccuracy = pos.accuracy;
        });
        // 只在 GPS 位置落在台灣離線地圖範圍內才移動視角
        if (_isInTaiwanBounds(loc)) {
          setState(() => _center = loc);
          _mapController.move(loc, 15.0);
          _refreshPoiMarkers(); // #2 Fix: GPS 跳轉後主動刷新 POI
        }
      }

      // 持續監聽位置變化
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // 移動 10m 才更新
        ),
      ).listen((pos) {
        if (mounted) {
          setState(() {
            _userLocation = LatLng(pos.latitude, pos.longitude);
            _gpsAccuracy = pos.accuracy;
          });
        }
      });
    } catch (e) {
      debugPrint('[GPS] Init error: $e');
    }
  }

  // ── 載入 Overlay 圖層 (危險區域 + Mesh 事件標記) ────────────────

  Future<void> _loadOverlays() async {
    await Future.wait([_loadHazards(), _loadEventMarkers()]);
  }

  /// 帶旋轉動畫的重新整理
  Future<void> _refreshWithSpin() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _refreshSpinCtrl.repeat();
    try {
      // 至少轉滿一圈 (800ms)，載入較久則繼續轉
      await Future.wait([
        _loadOverlays(),
        Future.delayed(const Duration(milliseconds: 800)),
      ]);
    } finally {
      _refreshSpinCtrl.stop();
      _refreshSpinCtrl.reset();
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadHazards() async {
    if (!_layerSettings.showHazards) {
      if (mounted) {
        setState(() {
          _hazardPolygons = [];
          _hazardCenterMarkers = [];
          _hazardData = [];
        });
      }
      return;
    }
    final hazards = await _eventManager.getActiveHazards();
    final polygons = <Polygon>[];
    final centerMarkers = <Marker>[];
    final filteredData = <Map<String, dynamic>>[];

    for (final h in hazards) {
      final lat = (h['lat'] as num?)?.toDouble();
      final lng = (h['lng'] as num?)?.toDouble();
      final radius = (h['radius'] as num?)?.toDouble() ?? 200.0;
      final severity = (h['severity'] as int?) ?? 3;
      final type = h['type'] as String? ?? '';
      final confirmCount = (h['confirm_count'] as int?) ?? 1;
      final reportedBy = h['reported_by'] as String? ?? '';
      if (lat == null || lng == null) continue;

      final isMine = reportedBy == _myReporterHex;

      // 篩選：不顯示他人的 / confirm_count 不夠
      if (!isMine && !_layerSettings.showOtherHazards) continue;
      if (!isMine && confirmCount < _layerSettings.minConfirmCount) continue;

      Color color;
      switch (type) {
        case 'FIRE':
          color = Colors.red;
        case 'FLOOD':
          color = Colors.blue;
        case 'CHEMICAL':
          color = Colors.yellow;
        case 'BUILDING':
          color = Colors.brown;
        case 'LANDSLIDE':
          color = Colors.grey;
        default:
          color = Colors.orange;
      }
      if (severity >= 4) color = Colors.red;

      // 圓形多邊形 (36 邊) 取代菱形
      final points = _circlePolygonPoints(lat, lng, radius);

      // 未驗證 (confirm=1) 用虛線邊框，已驗證用實線
      polygons.add(Polygon(
        points: points,
        color: color.withValues(alpha: confirmCount >= 2 ? 0.25 : 0.12),
        borderColor: color,
        borderStrokeWidth: confirmCount >= 3 ? 3.0 : 2.0,
        pattern: confirmCount < 2
            ? const StrokePattern.dotted()
            : const StrokePattern.solid(),
      ));

      filteredData.add(h);

      // 中心標記（含確認人數 badge）
      final (typeLabel, typeIcon, _) = _hazardInfo(context, type);
      centerMarkers.add(Marker(
        point: LatLng(lat, lng),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _showHazardInfo(h),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isMine ? Colors.greenAccent : Colors.white,
                    width: isMine ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.5), blurRadius: 6),
                  ],
                ),
                child: Icon(typeIcon, color: Colors.white, size: 18),
              ),
              if (confirmCount > 1)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange, width: 1),
                    ),
                    child: Text(
                      '×$confirmCount',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ));
    }

    if (mounted) {
      setState(() {
        _hazardPolygons = polygons;
        _hazardCenterMarkers = centerMarkers;
        _hazardData = filteredData;
      });
    }
  }

  /// 產生圓形多邊形頂點
  static List<LatLng> _circlePolygonPoints(
      double lat, double lng, double radiusM,
      {int segments = 36}) {
    final latR = lat * pi / 180;
    final latDelta = radiusM / 111320.0;
    final lngDelta = radiusM / (111320.0 * cos(latR));
    return List.generate(segments, (i) {
      final a = 2 * pi * i / segments;
      return LatLng(lat + latDelta * sin(a), lng + lngDelta * cos(a));
    });
  }

  Future<void> _loadEventMarkers() async {
    final db = await DatabaseHelper().database;
    // 載入最近 24 小時的 Mesh 事件，含座標（排除 hazardMarker，它有獨立圖層）
    final cutoff = DateTime.now().millisecondsSinceEpoch - (24 * 3600 * 1000);
    final events = await db.query(
      'Event_Logs',
      where:
          'hlc_timestamp > ? AND received_lat IS NOT NULL AND received_lng IS NOT NULL AND event_type != ?',
      whereArgs: [cutoff, EventType.hazardMarker],
      orderBy: 'urgency DESC, hlc_timestamp DESC',
      limit: 100,
    );

    final markers = <Marker>[];
    if (!mounted) return;
    final _evtL = S.of(context)!;
    for (final evt in events) {
      final lat = (evt['received_lat'] as num?)?.toDouble();
      final lng = (evt['received_lng'] as num?)?.toDouble();
      final urgency = (evt['urgency'] as int?) ?? 0;
      final eventType = (evt['event_type'] as int?) ?? 0;
      if (lat == null || lng == null || lat == 0 || lng == 0) continue;

      // Bug 9: 過濾 urgency=0 INFO 事件
      if (urgency == 0) continue;

      Color markerColor;
      IconData markerIcon;
      double markerSize;
      String tooltip;

      final _l = _evtL;
      switch (urgency) {
        case 3: // SOS_RED
          markerColor = Colors.red;
          markerIcon = Icons.sos;
          markerSize = 36;
          tooltip = _l.mapEventSosRed;
          break;
        case 2: // SOS_YELLOW
          markerColor = Colors.amber;
          markerIcon = Icons.warning_amber;
          markerSize = 32;
          tooltip = _l.mapEventSosYellow;
          break;
        case 1: // RESOURCE
          markerColor = Colors.green;
          markerIcon =
              eventType == 0 ? Icons.inventory_2 : Icons.volunteer_activism;
          markerSize = 28;
          tooltip = _l.mapEventSupply;
          break;
        default: // INFO
          markerColor = Colors.cyan;
          markerIcon = Icons.info_outline;
          markerSize = 24;
          tooltip = _l.mapEventInfo;
      }

      // 解讀 payload 取得描述
      final payload = evt['payload'] as Uint8List?;
      String desc = '';
      if (payload != null) {
        try {
          desc = String.fromCharCodes(payload);
          if (desc.length > 40) desc = '${desc.substring(0, 40)}...';
        } catch (_) {}
      }

      // Bug 8: 加入事件資訊的引用資料
      final evtData = Map<String, dynamic>.from(evt);

      markers.add(Marker(
        point: LatLng(lat, lng),
        width: markerSize + 4,
        height: markerSize + 4,
        child: GestureDetector(
          onTap: () => _showEventInfo(evtData),
          child: _EventMarkerIcon(
            icon: markerIcon,
            color: markerColor,
            size: markerSize,
            tooltip: '$tooltip${desc.isNotEmpty ? '\n$desc' : ''}',
            isSOS: urgency >= 2,
          ),
        ),
      ));
    }

    if (mounted) setState(() => _eventMarkers = markers);
  }

  // ── POI / 危險區域 點擊 ──────────────────────────────────────────

  Future<void> _onMapTap(TapPosition tapPosition, LatLng latlng) async {
    // 標記模式：點擊 = 移動標記中心
    if (_isMarkingMode) {
      setState(() => _markCenter = latlng);
      return;
    }

    // 檢查是否點到危險區域（由中心標記的 GestureDetector 處理）
    // 這裡只處理 POI 查詢
    if (_poiQuery == null) return;
    final zoom = _mapController.camera.zoom;
    if (zoom < 12) return;

    final poi = await _poiQuery!.queryNearestPoi(latlng, zoom);
    if (poi == null || !mounted) return;
    _showPoiInfoSheet(poi);
  }

  void _showPoiInfoSheet(Map<String, String> poi) {
    final name = poi['name'] ?? '';
    final cls = poi['class'] ?? '';
    final sub = poi['subclass'] ?? '';
    final phone = poi['phone'] ?? '';
    final hours = poi['opening_hours'] ?? '';
    final houseNo = poi['housenumber'] ?? '';
    final street = poi['addr_street'] ?? '';
    final city = poi['addr_city'] ?? '';
    final district = poi['addr_district'] ?? '';
    final addrFull = poi['addr_full'] ?? '';

    // 組合地址：優先使用 addr:full，否則拼接
    String address = '';
    if (addrFull.isNotEmpty) {
      address = addrFull;
    } else {
      final parts = <String>[];
      if (city.isNotEmpty) parts.add(city);
      if (district.isNotEmpty) parts.add(district);
      if (street.isNotEmpty) parts.add(street);
      if (houseNo.isNotEmpty) parts.add('${houseNo}號');
      address = parts.join('');
    }

    // 類別名稱映射
    String category = _poiCategoryLabel(context, cls, sub);

    // 類別顏色
    Color categoryColor = _poiCategoryColor(cls, sub);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖曳指示器
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 名稱 + 類別標籤
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: categoryColor, width: 1),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(color: categoryColor, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 資訊列表
            if (address.isNotEmpty)
              _poiInfoRow(Icons.location_on, S.of(ctx)!.mapPoiInfoAddress, address),
            if (phone.isNotEmpty) _poiInfoRow(Icons.phone, S.of(ctx)!.mapPoiInfoPhone, phone),
            if (hours.isNotEmpty) _poiHoursWidget(ctx, hours),
            // 如果三項都空，顯示提示
            if (address.isEmpty && phone.isEmpty && hours.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(S.of(ctx)!.mapPoiInfoNoDetail,
                    style: const TextStyle(color: Colors.white38, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _poiInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 10),
          Text('$label  ',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// 營業時間 widget：解析 OSM opening_hours 格式，每行一組，星期英轉中
  Widget _poiHoursWidget(BuildContext context, String raw) {
    final lines = _formatOpeningHours(context, raw);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.access_time, color: Colors.white54, size: 18),
          const SizedBox(width: 10),
          Text('${S.of(context)!.mapPoiInfoOpen}  ',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines
                  .map((l) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(l,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 解析 OSM opening_hours 字串，回傳格式化的行列表
  /// 例: "Mo-Tu 09:00-12:00,15:30-17:30; We 09:00-12:00; Su off"
  /// →  ["週一～週二  09:00-12:00, 15:30-17:30",
  ///     "週三        09:00-12:00",
  ///     "週日        公休"]
  static List<String> _formatOpeningHours(BuildContext context, String raw) {
    final l = S.of(context)!;
    // 星期英轉中對照
    final dayMap = {
      'Mo': l.mapDayMonday,
      'Tu': l.mapDayTuesday,
      'We': l.mapDayWednesday,
      'Th': l.mapDayThursday,
      'Fr': l.mapDayFriday,
      'Sa': l.mapDaySaturday,
      'Su': l.mapDaySunday,
    };
    final holidayLabel = l.mapDayHoliday;
    final closedLabel = l.mapDayClosed;

    String translateDays(String s) {
      var result = s;
      // 先處理 "-" 連接的範圍 (Mo-Fr → 週一～週五)
      result = result.replaceAllMapped(
        RegExp(r'\b(Mo|Tu|We|Th|Fr|Sa|Su)\s*-\s*(Mo|Tu|We|Th|Fr|Sa|Su)\b'),
        (m) => '${dayMap[m[1]] ?? m[1]!}～${dayMap[m[2]] ?? m[2]!}',
      );
      // 再處理 "," 分隔的多日 (Mo,We → 週一、週三)
      result = result.replaceAllMapped(
        RegExp(r'\b(Mo|Tu|We|Th|Fr|Sa|Su)\b'),
        (m) => dayMap[m[0]] ?? m[0]!,
      );
      result = result.replaceAll(RegExp(r'PH\b'), holidayLabel);
      return result;
    }

    // 以 ";" 分割不同時段規則
    final rules =
        raw.split(';').map((r) => r.trim()).where((r) => r.isNotEmpty);
    final lines = <String>[];

    for (final rule in rules) {
      // "off" 轉 "公休"
      var formatted =
          rule.replaceAll(RegExp(r'\boff\b', caseSensitive: false), closedLabel);
      formatted = translateDays(formatted);
      // 美化: 在日期與時間之間統一為兩個空格，逗號後加空格
      formatted = formatted.replaceAll(',', ', ');
      lines.add(formatted.trim());
    }

    return lines.isEmpty ? [raw] : lines;
  }

  String _poiCategoryLabel(BuildContext context, String cls, String sub) {
    final l = S.of(context)!;
    if (cls == 'hospital' || sub == 'hospital') return l.mapPoiHospital;
    if (sub == 'clinic' || sub == 'doctors') return l.mapPoiClinic;
    if (sub == 'nursing_home') return l.mapPoiNursingHome;
    if (cls == 'pharmacy' || sub == 'pharmacy') return l.mapPoiPharmacy;
    if (sub == 'police') return l.mapPoiPolice;
    if (sub == 'fire_station') return l.mapPoiFireStation;
    if (sub == 'school' || sub == 'kindergarten') return l.mapPoiSchool;
    if (sub == 'college' || sub == 'university') return l.mapPoiUniversity;
    if (sub == 'supermarket') return l.mapPoiSupermarket;
    if (sub == 'convenience') return l.mapPoiConvenience;
    if (sub == 'mall' || sub == 'department_store') return l.mapPoiMall;
    if (sub == 'fuel') return l.mapPoiGasStation;
    if (sub == 'restaurant') return l.mapPoiRestaurant;
    if (sub == 'cafe') return l.mapPoiCafe;
    if (sub == 'bank') return l.mapPoiBank;
    if (sub == 'post_office') return l.mapPoiPostOffice;
    if (sub == 'place_of_worship') return l.mapPoiReligious;
    if (sub == 'parking') return l.mapPoiParking;
    if (cls == 'shop') return l.mapPoiShop;
    return sub.isNotEmpty ? sub : cls;
  }

  /// 判斷 POI 是否屬於五大救災類別，不屬於則回傳 null
  String? _poiCategoryId(String cls, String sub) {
    if (cls == 'hospital' || sub == 'hospital' || sub == 'clinic' ||
        sub == 'doctors' || sub == 'nursing_home') return 'resq_hospital';
    if (cls == 'pharmacy' || sub == 'pharmacy') return 'resq_pharmacy';
    if (sub == 'police' || sub == 'fire_station') return 'resq_police';
    if (sub == 'school' || sub == 'kindergarten' ||
        sub == 'college' || sub == 'university') return 'resq_school';
    if (sub == 'supermarket' || sub == 'convenience' ||
        cls == 'grocery') return 'resq_grocery';
    return null;
  }

  Color _poiCategoryColor(String cls, String sub) {
    switch (_poiCategoryId(cls, sub)) {
      case 'resq_hospital': return Colors.red;
      case 'resq_pharmacy': return Colors.purple;
      case 'resq_police': return const Color(0xFF3366ff);
      case 'resq_school': return Colors.orange;
      case 'resq_grocery': return Colors.green;
      default: return Colors.cyan;
    }
  }

  IconData _poiCategoryIcon(String cls, String sub) {
    if (cls == 'hospital' || sub == 'hospital') return Icons.local_hospital;
    if (sub == 'clinic' || sub == 'doctors') return Icons.medical_services;
    if (sub == 'nursing_home') return Icons.elderly;
    if (cls == 'pharmacy' || sub == 'pharmacy') return Icons.local_pharmacy;
    if (sub == 'police') return Icons.local_police;
    if (sub == 'fire_station') return Icons.fire_truck;
    if (sub == 'school' || sub == 'kindergarten') return Icons.school;
    if (sub == 'college' || sub == 'university') return Icons.account_balance;
    if (sub == 'supermarket' || sub == 'convenience') return Icons.shopping_cart;
    if (cls == 'grocery') return Icons.store;
    return Icons.place;
  }

  List<Marker> _buildPoiMarkers(List<Map<String, String>> pois) {
    final markers = <Marker>[];
    for (final poi in pois) {
      final lat = double.tryParse(poi['lat'] ?? '') ?? 0;
      final lng = double.tryParse(poi['lng'] ?? '') ?? 0;
      final cls = poi['class'] ?? '';
      final sub = poi['subclass'] ?? '';

      // #1 Fix: 只顯示五大救災類別的 POI
      final catId = _poiCategoryId(cls, sub);
      if (catId == null) continue;

      // #3 Fix: 圖層控制 - 檢查類別是否啟用
      if (!_layerSettings.showPoi) continue;
      if (!_layerSettings.poiIsEnabled(catId)) continue;

      final color = _poiCategoryColor(cls, sub);
      final icon = _poiCategoryIcon(cls, sub);

      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 24,
        height: 24,
        child: GestureDetector(
          onTap: () => _showPoiInfoSheet(poi),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
              ],
            ),
            child: Icon(icon, size: 12, color: Colors.white),
          ),
        ),
      ));
    }
    return markers;
  }

  void _refreshPoiMarkers() {
    _poiRefreshTimer?.cancel();
    _poiRefreshTimer = Timer(const Duration(milliseconds: 300), () {
      _doRefreshPoiMarkers();
    });
  }

  Future<void> _doRefreshPoiMarkers() async {
    if (_poiQuery == null) return;
    // 圖層關閉時清空
    if (!_layerSettings.showPoi) {
      if (_poiMarkers.isNotEmpty && mounted) {
        setState(() => _poiMarkers = []);
      }
      return;
    }
    final zoom = _mapController.camera.zoom;
    if (zoom < 12) {
      if (_poiMarkers.isNotEmpty) {
        setState(() => _poiMarkers = []);
      }
      return;
    }
    final bounds = _mapController.camera.visibleBounds;
    final pois = await _poiQuery!.queryVisiblePois(
      south: bounds.south,
      west: bounds.west,
      north: bounds.north,
      east: bounds.east,
      zoom: zoom,
    );
    if (!mounted) return;
    setState(() => _poiMarkers = _buildPoiMarkers(pois));
  }

  Future<void> _onMapLongPress(TapPosition tapPosition, LatLng latlng) async {
    if (_isMarkingMode) return; // 已在標記模式
    setState(() {
      _isMarkingMode = true;
      _markCenter = latlng;
      _markRadius = 200.0;
      _markType = 'ROADBLOCK';
      _markSeverity = 3.0;
      _markDescCtrl.clear();
      _markPublishing = false;
      _editingHazardId = null;
    });
  }

  void _exitMarkingMode() {
    setState(() {
      _isMarkingMode = false;
      _markCenter = null;
      _editingHazardId = null;
    });
  }

  /// 發布或更新危險標記（含附近重複檢查）
  Future<void> _publishOrUpdateMark() async {
    if (_markCenter == null) return;
    setState(() => _markPublishing = true);

    try {
      // ── 編輯模式 ──
      if (_editingHazardId != null) {
        await _eventManager.updateHazard(
          _editingHazardId!,
          type: _markType,
          severity: _markSeverity.round(),
          lat: _markCenter!.latitude,
          lng: _markCenter!.longitude,
          radiusMeters: _markRadius,
          description: _markDescCtrl.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(S.of(context)!.mapHazardUpdatedSnack), backgroundColor: Colors.green),
          );
        }
        _exitMarkingMode();
        _loadOverlays();
        return;
      }

      // ── 新建模式：先查附近是否已有同類型回報 ──
      final nearby = await _eventManager.findNearbyHazard(
        _markCenter!.latitude,
        _markCenter!.longitude,
        _markType,
        searchRadius: _markRadius + 300, // 允許一些重疊
      );

      if (nearby != null && mounted) {
        final dist = (nearby['_distance'] as double).round();
        final cnt = (nearby['confirm_count'] as int?) ?? 1;
        final (typeLabel, _, _) = _hazardInfo(context, _markType);
        final action = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            title: Row(children: [
              const Icon(Icons.people, color: Colors.orange),
              const SizedBox(width: 8),
              Text(S.of(context)!.mapMarkingNearbyExists,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
            ]),
            content: Text(
              '距離 ${dist}m 處已有「$typeLabel」回報\n'
              '目前已有 $cnt 人確認\n\n'
              '你可以「確認」來增加可信度，\n或建立全新標記。',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'new'),
                child: Text(S.of(context)!.mapMarkingCreateNew,
                    style: const TextStyle(color: Colors.white54)),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, 'confirm'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                icon: const Icon(Icons.check, color: Colors.white, size: 18),
                label:
                    Text(S.of(context)!.mapMarkingConfirmReport, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (action == 'confirm') {
          await _eventManager.confirmHazard(nearby['hazard_id'] as String);
          if (mounted) {
            final (tl, _, _) = _hazardInfo(context, _markType);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(S.of(context)!.mapHazardConfirmSnack(tl, 1)),
                backgroundColor: Colors.green,
              ),
            );
          }
          _exitMarkingMode();
          _loadOverlays();
          return;
        }
        // action == 'new' 或 null (取消) → 繼續建立
        if (action == null) {
          setState(() => _markPublishing = false);
          return;
        }
      }

      // ── 發布新標記 ──
      await _eventManager.publishHazard(
        type: _markType,
        severity: _markSeverity.round(),
        lat: _markCenter!.latitude,
        lng: _markCenter!.longitude,
        radiusMeters: _markRadius,
        description: _markDescCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(S.of(context)!.mapHazardPublishedSnack), backgroundColor: Colors.orange),
        );
      }
      _exitMarkingMode();
      _loadOverlays();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context)!.mapMbtilesLoadFail(e.toString())), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _markPublishing = false);
    }
  }

  // ── 危險標記詳情面板 ──────────────────────────────────────────

  void _showHazardInfo(Map<String, dynamic> h) {
    final type = h['type'] as String? ?? '';
    final severity = (h['severity'] as int?) ?? 3;
    final radius = (h['radius'] as num?)?.toDouble() ?? 200.0;
    final confirmCount = (h['confirm_count'] as int?) ?? 1;
    final desc = h['description'] as String? ?? '';
    final reportedBy = h['reported_by'] as String? ?? '';
    final createdAt = (h['created_at'] as int?) ?? 0;
    final hazardId = h['hazard_id'] as String? ?? '';
    final isMine = reportedBy == _myReporterHex;

    final (typeLabel, typeIcon, typeColor) = _hazardInfo(context, type);

    final l = S.of(context)!;
    // 時間顯示
    String timeAgo = '';
    if (createdAt > 0) {
      final diff = DateTime.now().millisecondsSinceEpoch - createdAt;
      final mins = diff ~/ 60000;
      if (mins < 60) {
        timeAgo = l.mapTimeAgoMinutes(mins);
      } else if (mins < 1440) {
        timeAgo = l.mapTimeAgoHours(mins ~/ 60);
      } else {
        timeAgo = l.mapTimeAgoDays(mins ~/ 1440);
      }
    }

    // 可信度標籤
    String credLabel;
    Color credColor;
    if (confirmCount >= 5) {
      credLabel = l.mapCredibilityConfirmed;
      credColor = Colors.greenAccent;
    } else if (confirmCount >= 3) {
      credLabel = l.mapCredibilityCredible;
      credColor = Colors.lightGreen;
    } else if (confirmCount >= 2) {
      credLabel = l.mapCredibilityEndorsed;
      credColor = Colors.orange;
    } else {
      credLabel = l.mapCredibilityUnverified;
      credColor = Colors.white38;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 標題行
            Row(children: [
              Icon(typeIcon, color: typeColor, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(typeLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: credColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: credColor, width: 1),
                ),
                child: Text('$credLabel ×$confirmCount',
                    style: TextStyle(color: credColor, fontSize: 11)),
              ),
            ]),
            const SizedBox(height: 12),
            // 嚴重度條
            Row(children: [
              Text('${l.mapHazardInfoSeverity}  ',
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ...List.generate(
                5,
                (i) => Icon(
                  Icons.circle,
                  size: 12,
                  color: i < severity
                      ? (severity >= 4 ? Colors.red : Colors.orange)
                      : Colors.white12,
                ),
              ),
              Text('  ($severity/5)',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            Text(l.mapHazardInfoRadius(radius.round()),
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(l.mapHazardInfoDesc(desc),
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
            if (timeAgo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(l.mapHazardInfoTime(timeAgo),
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
            if (isMine)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('👤 ${l.mapHazardInfoMine}',
                    style: TextStyle(
                        color: Colors.greenAccent[400], fontSize: 12)),
              ),
            const SizedBox(height: 16),
            // 操作按鈕
            Row(children: [
              if (isMine) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _enterEditMode(h);
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text(l.mapHazardInfoEditButton),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _deleteHazardConfirm(hazardId);
                    },
                    icon: const Icon(Icons.delete, size: 16),
                    label: Text(l.mapHazardDeleteConfirm),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red)),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _eventManager.confirmHazard(hazardId);
                      _loadOverlays();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                l.mapHazardConfirmSnack(typeLabel, confirmCount + 1)),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    icon:
                        const Icon(Icons.check, color: Colors.white, size: 18),
                    label: Text(l.mapHazardInfoConfirmButton,
                        style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                  ),
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  // ── 事件標記詳情面板 ────────────────────────────────────────────

  void _showEventInfo(Map<String, dynamic> evt) {
    final eventType = (evt['event_type'] as int?) ?? 0;
    final urgency = (evt['urgency'] as int?) ?? 0;
    final hlcTs = (evt['hlc_timestamp'] as int?) ?? 0;
    final lat = (evt['received_lat'] as num?)?.toDouble() ?? 0;
    final lng = (evt['received_lng'] as num?)?.toDouble() ?? 0;
    final eventId = (evt['event_id'] as String?) ?? '';

    final lEvt = S.of(context)!;
    // 事件類型名稱
    String typeName;
    IconData typeIcon;
    Color typeColor;
    switch (eventType) {
      case 0:
        typeName = lEvt.mapEventTypeSupply;
        typeIcon = Icons.inventory_2;
        typeColor = Colors.greenAccent;
        break;
      case 1:
        typeName = lEvt.mapEventTypeRequest;
        typeIcon = Icons.volunteer_activism;
        typeColor = Colors.amber;
        break;
      default:
        typeName = lEvt.mapEventTypeUnknown(eventType);
        typeIcon = Icons.info_outline;
        typeColor = Colors.cyanAccent;
    }

    // 緊急度
    String urgencyLabel;
    Color urgencyColor;
    switch (urgency) {
      case 3:
        urgencyLabel = lEvt.mapEventSosRed;
        urgencyColor = Colors.red;
        break;
      case 2:
        urgencyLabel = lEvt.mapEventSosYellow;
        urgencyColor = Colors.amber;
        break;
      case 1:
        urgencyLabel = lEvt.mapEventSupply;
        urgencyColor = Colors.green;
        break;
      default:
        urgencyLabel = lEvt.mapEventInfo;
        urgencyColor = Colors.cyan;
    }

    // 時間
    String timeAgo = '';
    if (hlcTs > 0) {
      final diff = DateTime.now().millisecondsSinceEpoch - hlcTs;
      final mins = diff ~/ 60000;
      if (mins < 60) {
        timeAgo = lEvt.mapTimeAgoMinutes(mins);
      } else if (mins < 1440) {
        timeAgo = lEvt.mapTimeAgoHours(mins ~/ 60);
      } else {
        timeAgo = lEvt.mapTimeAgoDays(mins ~/ 1440);
      }
    }

    // 解析 payload
    String payloadDesc = '';
    final payload = evt['payload'] as Uint8List?;
    if (payload != null) {
      try {
        if (eventType == 0) {
          final rd = pb.ResourceData.fromBuffer(payload);
          payloadDesc = lEvt.mapPayloadQtyUnit(getLocalizedReadableName(rd.resourceType, context), rd.quantity.toInt(), rd.unit);
        } else if (eventType == 1) {
          final rd = pb.RequestData.fromBuffer(payload);
          payloadDesc = lEvt.mapPayloadQtyPcs(getLocalizedReadableName(rd.resourceType, context), rd.quantityNeeded.toInt());
        } else {
          payloadDesc = String.fromCharCodes(payload);
          if (payloadDesc.length > 100) payloadDesc = '${payloadDesc.substring(0, 100)}...';
        }
      } catch (_) {
        payloadDesc = '${payload.length} bytes';
      }
    }

    // 距離
    String distStr = '';
    final myLoc = _userLocation;
    if (myLoc != null && lat != 0 && lng != 0) {
      final dist = LocationService.haversineMeters(myLoc, LatLng(lat, lng));
      distStr = LocationService.formatDistance(dist);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(children: [
              Icon(typeIcon, color: typeColor, size: 24),
              const SizedBox(width: 8),
              Expanded(child: Text(typeName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: urgencyColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(urgencyLabel, style: TextStyle(color: urgencyColor, fontSize: 11)),
              ),
            ]),
            const SizedBox(height: 12),
            if (payloadDesc.isNotEmpty)
              Text(payloadDesc, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            if (distStr.isNotEmpty)
              Row(children: [
                const Icon(Icons.place, size: 14, color: Colors.white38),
                const SizedBox(width: 4),
                Text(lEvt.mapEventInfoDistance(distStr), style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ]),
            if (timeAgo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(lEvt.mapEventInfoTime(timeAgo), style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
            const SizedBox(height: 4),
            Text('ID: ${eventId.length > 8 ? eventId.substring(0, 8) : eventId}...',
                style: const TextStyle(color: Colors.white24, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _enterEditMode(Map<String, dynamic> h) {
    setState(() {
      _isMarkingMode = true;
      _editingHazardId = h['hazard_id'] as String?;
      _markCenter = LatLng(
        (h['lat'] as num).toDouble(),
        (h['lng'] as num).toDouble(),
      );
      _markRadius = (h['radius'] as num?)?.toDouble() ?? 200.0;
      _markType = h['type'] as String? ?? 'ROADBLOCK';
      _markSeverity = ((h['severity'] as int?) ?? 3).toDouble();
      _markDescCtrl.text = h['description'] as String? ?? '';
      _markPublishing = false;
    });
  }

  Future<void> _deleteHazardConfirm(String hazardId) async {
    final lDel = S.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(lDel.mapHazardDeleteTitle,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(lDel.mapHazardDeleteContent,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lDel.mapHazardDeleteCancel, style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(lDel.mapHazardDeleteConfirm, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _eventManager.deleteHazard(hazardId);
      _loadOverlays();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(S.of(context)!.mapHazardDeletedSnack), backgroundColor: Colors.green),
        );
      }
    }
  }

  // ── 圖層控制面板 ──────────────────────────────────────────────

  void _showLayerControlSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MapLayerControlSheet(settings: _layerSettings),
    );
  }

  Future<void> _onTriageSubmit(int urgency, String desc,
      {bool attachMedicalCard = false}) async {
    try {
      final eventId = await _eventManager.publishEvent(
        urgency: urgency,
        description: desc,
        lat: _userLocation?.latitude,
        lng: _userLocation?.longitude,
        attachMedicalCard: attachMedicalCard,
      );
      if (mounted) {
        // 追蹤 SOS 狀態（urgency >= 2 為 SOS 等級）
        if (urgency >= 2) {
          setState(() {
            _activeSosEventId = eventId;
            _activeSosUrgency = urgency;
            _activeSosDesc = desc;
          });
        }
        final lTriage = S.of(context)!;
        final labels = [
          lTriage.mapTriageBroadcastLabel0,
          lTriage.mapTriageBroadcastLabel1,
          lTriage.mapTriageBroadcastLabel2,
          lTriage.mapTriageBroadcastLabel3,
        ];
        final colors = [
          Colors.blue[700],
          Colors.green[700],
          Colors.orange[700],
          Colors.red[700]
        ];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lTriage.mapTriageBroadcastSnack(labels[urgency], desc)),
            backgroundColor: colors[urgency],
          ),
        );
        _loadOverlays(); // 即時刷新事件標記
      }
    } on RateLimitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.orange),
        );
      }
    }
  }

  /// 取消 SOS 求救
  Future<void> _cancelSos() async {
    final lSos = S.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(lSos.mapCancelSosTitle, style: const TextStyle(color: Colors.white)),
        content: Text(
          lSos.mapCancelSosContent,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lSos.mapCancelSosBack),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lSos.mapCancelSosConfirm, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      // 發布取消事件到 Mesh 網路
      await _eventManager.publishEvent(
        urgency: 0, // INFO level
        description: '${S.of(context)!.mapSosCancelledPrefix}$_activeSosDesc',
        lat: _userLocation?.latitude,
        lng: _userLocation?.longitude,
      );
      setState(() {
        _activeSosEventId = null;
        _activeSosUrgency = 0;
        _activeSosDesc = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context)!.mapSosCancelledSnack),
            backgroundColor: Colors.grey[700],
          ),
        );
        _loadOverlays();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context)!.mapSosCancelFailSnack(e.toString())), backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  void _centerOnUser() {
    if (_userLocation != null) {
      _mapController.moveAndRotate(_userLocation!, 15.0, 0.0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(S.of(context)!.mapGpsNotReady),
            backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context)!.mapTitle,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.layers, color: Colors.white),
            onPressed: _showLayerControlSheet,
            tooltip: S.of(context)!.mapLayerControlTooltip,
          ),
          IconButton(
            icon: const Icon(Icons.legend_toggle, color: Colors.white),
            onPressed: () => setState(() => _showLegend = !_showLegend),
            tooltip: S.of(context)!.mapLegendTooltip,
          ),
          IconButton(
            icon: AnimatedBuilder(
              animation: _refreshSpinCtrl,
              builder: (_, child) => Transform.rotate(
                angle: _refreshSpinCtrl.value * 2 * 3.14159265,
                child: child,
              ),
              child: const Icon(Icons.refresh, color: Colors.white),
            ),
            onPressed: _refreshWithSpin,
            tooltip: S.of(context)!.mapRefreshTooltip,
          ),
        ],
      ),
      body: _mbtilesLoading
          ? _buildLoadingScreen()
          : !_mbtilesAvailable
              ? _buildErrorScreen()
              : _buildMapView(),
      floatingActionButton: _isMarkingMode
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 定位按鈕
                FloatingActionButton.small(
                  heroTag: 'gps',
                  backgroundColor: _userLocation != null
                      ? Colors.blueAccent
                      : Colors.grey[700],
                  onPressed: _centerOnUser,
                  child: Icon(
                    _userLocation != null
                        ? Icons.my_location
                        : Icons.location_searching,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 12),
                // SOS 求救按鈕（根據狀態切換）
                _activeSosEventId != null
                    ? FloatingActionButton.extended(
                        heroTag: 'sos',
                        backgroundColor: _activeSosUrgency >= 3
                            ? Colors.red[800]
                            : Colors.orange[800],
                        onPressed: _cancelSos,
                        icon:
                            const Icon(Icons.check_circle, color: Colors.white),
                        label: Text(
                          S.of(context)!.mapSosSentLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 13,
                          ),
                        ),
                      )
                    : FloatingActionButton.extended(
                        heroTag: 'sos',
                        backgroundColor: Colors.redAccent,
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: const Color(0xFF1a1a2e),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20)),
                            ),
                            builder: (ctx) =>
                                TriageInputWidget(onSubmit: _onTriageSubmit),
                          );
                        },
                        icon: const Icon(Icons.sos, color: Colors.white),
                        label: Text(S.of(context)!.mapSosButton,
                            style: const TextStyle(color: Colors.white)),
                      ),
              ],
            ),
    );
  }

  Widget _buildMapView() {
    // 建立用戶位置 Marker
    final List<Marker> locationMarkers = [];
    if (_userLocation != null) {
      locationMarkers.add(Marker(
        point: _userLocation!,
        width: 26,
        height: 26,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 4,
              ),
            ],
          ),
        ),
      ));
    }

    // 建立精度圈
    final List<CircleMarker> accuracyCircles = [];
    if (_userLocation != null && _gpsAccuracy > 0) {
      accuracyCircles.add(CircleMarker(
        point: _userLocation!,
        radius: _gpsAccuracy,
        useRadiusInMeter: true,
        color: Colors.blue.withValues(alpha: 0.1),
        borderColor: Colors.blue.withValues(alpha: 0.3),
        borderStrokeWidth: 1,
      ));
    }

    // 預覽多邊形（標記模式）
    final List<Polygon> previewPolygons = [];
    if (_isMarkingMode && _markCenter != null) {
      final (_, _, previewColor) = _hazardInfo(context, _markType);
      previewPolygons.add(Polygon(
        points: _circlePolygonPoints(
          _markCenter!.latitude,
          _markCenter!.longitude,
          _markRadius,
        ),
        color: previewColor.withValues(alpha: 0.18),
        borderColor: previewColor,
        borderStrokeWidth: 2.5,
        pattern: const StrokePattern.dotted(),
      ));
    }

    // 預覽中心標記
    final List<Marker> previewMarkers = [];
    if (_isMarkingMode && _markCenter != null) {
      previewMarkers.add(Marker(
        point: _markCenter!,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_on, color: Colors.white, size: 36),
      ));
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 15.0,
            minZoom: 6.0,
            maxZoom: 18.0,
            onTap: _onMapTap,
            onLongPress: _onMapLongPress,
            onPositionChanged: (pos, hasGesture) {
              _refreshPoiMarkers(); // 任何地圖移動都刷新 POI（包含程式觸發）
            },
          ),
          children: [
            // 1. 離線向量圖磚底圖 (含自動 POI 顯示)
            if (_tileProviders != null && _mapTheme != null)
              VectorTileLayer(
                key: ValueKey('vt_$_themeGeneration'),
                tileProviders: _tileProviders!,
                theme: _mapTheme!,
                // sprites 暫時停用：sprite atlas PNG 解碼會觸發
                // Codec failed to produce an image 未處理例外，
                // 導致整個 tile 載入管線中斷 (tileset=null)
                sprites: null,
                layerMode: VectorTileLayerMode.vector,
              ),
            // 2. POI 圓點標記
            if (_poiMarkers.isNotEmpty)
              MarkerLayer(markers: _poiMarkers),
            // 3. GPS 精度圈
            if (accuracyCircles.isNotEmpty)
              CircleLayer(circles: accuracyCircles),
            // 4. 危險區域覆蓋層
            if (_hazardPolygons.isNotEmpty)
              PolygonLayer(polygons: _hazardPolygons),
            // 3.5 預覽標記多邊形
            if (previewPolygons.isNotEmpty)
              PolygonLayer(polygons: previewPolygons),
            // 4. 危險區域中心標記
            if (_hazardCenterMarkers.isNotEmpty)
              MarkerLayer(markers: _hazardCenterMarkers),
            // 4.5 預覽中心點
            if (previewMarkers.isNotEmpty) MarkerLayer(markers: previewMarkers),
            // 5. Mesh 事件標記
            if (_eventMarkers.isNotEmpty) MarkerLayer(markers: _eventMarkers),
            // 6. 用戶位置
            if (locationMarkers.isNotEmpty)
              MarkerLayer(markers: locationMarkers),
          ],
        ),

        // 長按提示（非標記模式時顯示）
        if (!_isMarkingMode)
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  S.of(context)!.mapLongPressHint,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        // 標記模式控制面板
        if (_isMarkingMode) _buildMarkingPanel(),
        // 圖例面板
        if (_showLegend && !_isMarkingMode) _buildLegendPanel(),
      ],
    );
  }

  // ── 標記模式控制面板 ─────────────────────────────────────────────

  Widget _buildMarkingPanel() {
    final lPanel = S.of(context)!;
    final (typeLabel, _, typeColor) = _hazardInfo(context, _markType);
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e).withValues(alpha: 0.97),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 標題 + 取消 ──
            Row(children: [
              const Icon(Icons.warning_amber, color: Colors.orange, size: 22),
              const SizedBox(width: 8),
              Text(
                _editingHazardId != null ? lPanel.mapMarkingEditTitle : lPanel.mapMarkingNewTitle,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: _exitMarkingMode,
                icon: const Icon(Icons.close, color: Colors.white38),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
            Text(lPanel.mapMarkingTapHint,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 10),

            // ── 危險類型選擇 ──
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ['ROADBLOCK', 'FIRE', 'CHEMICAL', 'FLOOD', 'BUILDING', 'LANDSLIDE'].map((key) {
                  final (label, icon, color) = _hazardInfo(context, key);
                  final selected = _markType == key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      avatar: Icon(icon, color: color, size: 16),
                      label: Text(label),
                      selected: selected,
                      selectedColor: color.withValues(alpha: 0.3),
                      backgroundColor: Colors.white10,
                      labelStyle: TextStyle(
                        color: selected ? color : Colors.white70,
                        fontSize: 12,
                      ),
                      side:
                          BorderSide(color: selected ? color : Colors.white24),
                      onSelected: (_) => setState(() => _markType = key),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // ── 嚴重程度 ──
            Row(children: [
              Text(lPanel.mapMarkingSeverityLabel,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _markSeverity,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: typeColor,
                  inactiveColor: Colors.white12,
                  label: '${_markSeverity.round()}',
                  onChanged: (v) => setState(() => _markSeverity = v),
                ),
              ),
              Text('${_markSeverity.round()}/5',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),

            // ── 影響半徑 ──
            Row(children: [
              Text(lPanel.mapMarkingRadiusLabel,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _markRadius,
                  min: 50,
                  max: 2000,
                  divisions: 39,
                  activeColor: Colors.orange,
                  inactiveColor: Colors.white12,
                  label: '${_markRadius.round()}m',
                  onChanged: (v) => setState(() => _markRadius = v),
                ),
              ),
              Text('${_markRadius.round()}m',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),

            // ── 描述 ──
            SizedBox(
              height: 40,
              child: TextField(
                controller: _markDescCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: lPanel.mapMarkingDescHint,
                  hintStyle:
                      const TextStyle(color: Colors.white24, fontSize: 13),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── 發布按鈕 ──
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _markPublishing ? null : _publishOrUpdateMark,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _markPublishing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(
                        _editingHazardId != null
                            ? Icons.save
                            : Icons.cell_tower,
                        color: Colors.white,
                        size: 20),
                label: Text(
                  _editingHazardId != null ? lPanel.mapMarkingUpdateButton : lPanel.mapMarkingPublishButton,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    final lLoad = S.of(context)!;
    return Container(
      color: const Color(0xFFF2EFE9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(lLoad.mapLoading, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Text(
              lLoad.mapLoadingNote,
              style: const TextStyle(color: Colors.black38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    final l = S.of(context)!;
    String errorMsg;
    if (_mbtilesError == 'mapMbtilesLoadFail') {
      errorMsg = l.mapMbtilesLoadFail(_mbtilesErrorArg ?? '');
    } else if (_mbtilesError == 'mapMbtilesNotFound') {
      errorMsg = l.mapMbtilesNotFound;
    } else {
      errorMsg = l.mapErrorUnknown;
    }
    return Container(
      color: const Color(0xFFF2EFE9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, color: Colors.black26, size: 64),
            const SizedBox(height: 16),
            Text(l.mapErrorTitle,
                style: const TextStyle(color: Colors.black54, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              errorMsg,
              style: const TextStyle(color: Colors.black38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              l.mapErrorAssetNote,
              style: const TextStyle(color: Colors.black26, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _mbtilesLoading = true;
                  _mbtilesError = null;
                  _mbtilesErrorArg = null;
                });
                _initMBTiles();
              },
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: Text(l.mapRetryButton, style: const TextStyle(color: Colors.white)),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendPanel() {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)
          ],
        ),
        child: Builder(builder: (ctx) {
          final lLeg = S.of(ctx)!;
          return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🚨 ${lLeg.mapLegendTitle}',
                style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(height: 4),
            Text(lLeg.mapLegendZoomHint,
                style: const TextStyle(color: Colors.red, fontSize: 10)),
            const Divider(color: Colors.black12, height: 16),
            _legendItem(Colors.red, lLeg.mapLegendHospital),
            _legendItem(const Color(0xFF3366ff), lLeg.mapLegendPolice),
            _legendItem(Colors.orange, lLeg.mapLegendSchool),
            _legendItem(Colors.purple, lLeg.mapLegendPharmacy),
            _legendItem(Colors.green, lLeg.mapLegendSupermarket),
            const Divider(color: Colors.black12, height: 16),
            Text(lLeg.mapLegendMeshEvents,
                style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
            _legendItem(Colors.red, lLeg.mapEventSosRed, icon: Icons.sos),
            _legendItem(Colors.amber, lLeg.mapEventSosYellow, icon: Icons.warning_amber),
            _legendItem(Colors.green, lLeg.mapEventSupply, icon: Icons.inventory_2),
            _legendItem(Colors.cyan, lLeg.mapEventInfo, icon: Icons.info_outline),
          ],
          );
        }),
      ),
    );
  }

  Widget _legendItem(Color color, String label, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon != null
              ? Icon(icon, color: color, size: 14)
              : Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26, width: 1),
                  ),
                ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: Colors.black87, fontSize: 12)),
        ],
      ),
    );
  }
}

/// 事件標記圖示 (帶呼吸動畫的 SOS 標記)
class _EventMarkerIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final String tooltip;
  final bool isSOS;

  const _EventMarkerIcon({
    required this.icon,
    required this.color,
    required this.size,
    required this.tooltip,
    this.isSOS = false,
  });

  @override
  State<_EventMarkerIcon> createState() => _EventMarkerIconState();
}

class _EventMarkerIconState extends State<_EventMarkerIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.isSOS) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget marker = Tooltip(
      message: widget.tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(color: widget.color.withValues(alpha: 0.6), blurRadius: 8)
          ],
        ),
        child: Icon(widget.icon, color: Colors.white, size: widget.size * 0.55),
      ),
    );

    if (widget.isSOS && _controller != null) {
      return AnimatedBuilder(
        animation: _controller!,
        builder: (_, child) => Opacity(
          opacity: 0.6 + _controller!.value * 0.4,
          child: Transform.scale(
            scale: 0.9 + _controller!.value * 0.15,
            child: child,
          ),
        ),
        child: marker,
      );
    }
    return marker;
  }
}
