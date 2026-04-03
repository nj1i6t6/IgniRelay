import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_mbtiles/vector_map_tiles_mbtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../mesh/mbtiles_loader.dart';
import '../mesh/native_bridge.dart';
import '../mesh/event_manager.dart';
import '../services/location_service.dart';
import '../services/match_service.dart';
import 'ignirelay_theme.dart';
import 'physical_handoff.dart';
import 'supply_category_data.dart';

/// 導航引導畫面
/// 顯示供給/需求兩方座標、直線距離、方位、BLE 近接偵測
class NavigationScreen extends StatefulWidget {
  final MatchEntry match;

  const NavigationScreen({super.key, required this.match});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final _location = LocationService();
  final _eventManager = EventManager();
  final _mapController = MapController();

  // MBTiles 離線地圖
  MbTiles? _mbTiles;
  TileProviders? _tileProviders;
  vtr.Theme? _mapTheme;
  bool _mapReady = false;

  // BLE 掃描
  StreamSubscription? _bleScanSub;
  bool _peerDetected = false;
  int _peerRssi = -100;
  Timer? _scanTimer;
  bool _scanning = false;

  // 位置更新
  Timer? _locationRefresh;
  LatLng? _myLocation;
  MatchEntry? _liveMatch;

  @override
  void initState() {
    super.initState();
    _myLocation = _location.currentLocation;
    _liveMatch = widget.match;
    _initMBTiles();
    _startBleScan();
    // 每 3 秒刷新位置
    _locationRefresh = Timer.periodic(const Duration(seconds: 3), (_) async {
      final loc = _location.currentLocation;
      final refreshed = await _resolveLiveMatch();
      if (mounted) {
        setState(() {
          if (loc != null) _myLocation = loc;
          if (refreshed != null) _liveMatch = refreshed;
        });
      }
    });
  }

  Future<void> _initMBTiles() async {
    try {
      final available = await MBTilesLoader.isAvailable();
      if (!available) return;
      final path = await MBTilesLoader.getLocalPath();
      await MBTilesLoader.sanitizeMetadata(path);
      final mbTiles = MbTiles(mbtilesPath: path, gzip: true);
      final provider = MbTilesVectorTileProvider(mbtiles: mbTiles);
      // 不帶 POI → 傳入全部 disabled（空 set = 全部啟用，我們直接用無 POI 的 theme）
      final theme = buildIgniRelayTheme(disabledPoi: _allPoiIds);
      if (mounted) {
        setState(() {
          _mbTiles = mbTiles;
          _tileProviders = TileProviders({'openmaptiles': provider});
          _mapTheme = theme;
          _mapReady = true;
        });
      }
    } catch (e) {
      debugPrint('[Navigation] MBTiles init failed: $e');
    }
  }

  /// 所有 POI ID，用來讓 theme 隱藏全部 POI 圖層
  static final Set<String> _allPoiIds = {
    'resq_grocery',
    'resq_pharmacy',
    'resq_school',
    'resq_police',
    'resq_hospital',
  };

  Future<MatchEntry?> _resolveLiveMatch() async {
    final session = await _eventManager.getActiveSessionByMatch(
      widget.match.resourceId,
      widget.match.requestEventId,
    );
    if (session == null) return null;

    return MatchEntry(
      resourceId: widget.match.resourceId,
      resourceType: widget.match.resourceType,
      requestResourceType: widget.match.requestResourceType,
      requestDesc: widget.match.requestDesc,
      requestEventId: widget.match.requestEventId,
      urgency: widget.match.urgency,
      identityLevel: widget.match.identityLevel,
      score: widget.match.score,
      hlcTimestamp: widget.match.hlcTimestamp,
      supplyQty: widget.match.supplyQty,
      requestQty: widget.match.requestQty,
      deliveryMode: widget.match.deliveryMode,
      mobilityMode: widget.match.mobilityMode,
      fulfillmentRatio: widget.match.fulfillmentRatio,
      distanceMeters: widget.match.distanceMeters,
      supplyLat: (session['last_provider_lat'] as num?)?.toDouble() ??
          widget.match.supplyLat,
      supplyLng: (session['last_provider_lng'] as num?)?.toDouble() ??
          widget.match.supplyLng,
      requestLat: (session['last_requester_lat'] as num?)?.toDouble() ??
          widget.match.requestLat,
      requestLng: (session['last_requester_lng'] as num?)?.toDouble() ??
          widget.match.requestLng,
      requesterPubKey: widget.match.requesterPubKey,
      providerPubKey: widget.match.providerPubKey,
      iAmProvider: widget.match.iAmProvider,
      iAmRequester: widget.match.iAmRequester,
    );
  }

  LatLng? get _supplyPos {
    final m = _liveMatch ?? widget.match;
    if (m.supplyLat != null && m.supplyLng != null) {
      return LatLng(m.supplyLat!, m.supplyLng!);
    }
    return null;
  }

  LatLng? get _requestPos {
    final m = _liveMatch ?? widget.match;
    if (m.requestLat != null && m.requestLng != null) {
      return LatLng(m.requestLat!, m.requestLng!);
    }
    return null;
  }

  LatLng get _targetPos {
    // 根據配送方向決定目標
    // DELIVER → 供給者要前往需求者位置
    // PICKUP → 需求者要前往供給者位置
    final currentMatch = _liveMatch ?? widget.match;
    if (currentMatch.deliveryMode == 'DELIVER') {
      return _requestPos ??
          _supplyPos ??
          _myLocation ??
          const LatLng(25.033, 121.565);
    }
    return _supplyPos ??
        _requestPos ??
        _myLocation ??
        const LatLng(25.033, 121.565);
  }

  // ── BLE 掃描 ──────────────────────────────────────────────────

  Future<void> _startBleScan() async {
    try {
      final btOn = await NativeBridge.isBluetoothEnabled();
      if (!btOn) {
        debugPrint('[Navigation] BLE 未開啟');
        return;
      }

      _scanning = true;
      _performScan();

      // 每 15 秒重新掃描
      _scanTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted && _scanning) _performScan();
      });
    } catch (e) {
      debugPrint('[Navigation] BLE 初始化失敗: $e');
    }
  }

  Future<void> _performScan() async {
    try {
      await NativeBridge.startNordicScan();

      _bleScanSub?.cancel();
      _bleScanSub = NativeBridge.nativeEventStream.listen((event) {
        if (event is Map && event['type'] == 'nordic_found' && mounted) {
          final rssi = event['rssi'] as int? ?? -100;
          setState(() {
            _peerDetected = true;
            if (rssi > _peerRssi) _peerRssi = rssi;
          });
        }
      });

      // 8 秒後停止本輪掃描
      Future.delayed(const Duration(seconds: 8), () {
        if (_scanning) NativeBridge.stopNordicScan();
      });
    } catch (e) {
      debugPrint('[Navigation] BLE scan error: $e');
    }
  }

  void _stopBleScan() {
    _scanning = false;
    _scanTimer?.cancel();
    _bleScanSub?.cancel();
    try {
      NativeBridge.stopNordicScan();
    } catch (_) {}
  }

  // ── 開始交接 ──────────────────────────────────────────────────

  void _startHandoff() {
    final currentMatch = _liveMatch ?? widget.match;
    final role = currentMatch.iAmRequester
        ? HandoffRole.requester
        : HandoffRole.provider;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PhysicalHandoffScreen(
        role: role,
        resourceId: currentMatch.resourceId,
        resourceType: currentMatch.resourceType,
        urgency: currentMatch.urgency,
        requestId: currentMatch.requestEventId,
      ),
    ));
  }

  // ── UI ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final m = _liveMatch ?? widget.match;
    final readableName = getReadableName(m.resourceType);
    final myLoc = _myLocation;
    final target = _targetPos;

    // 距離和方向
    double? distMeters;
    String? dirLabel;
    double? bearingDeg;
    if (myLoc != null) {
      distMeters = LocationService.haversineMeters(myLoc, target);
      bearingDeg = LocationService.bearing(myLoc, target);
      dirLabel = LocationService.bearingToDirection(bearingDeg);
    } else if (m.distanceMeters > 0) {
      distMeters = m.distanceMeters;
    }

    // 配送方向描述
    String whoMoves;
    if (m.deliveryMode == 'DELIVER') {
      whoMoves = '供給者前往需求者';
    } else {
      whoMoves = '需求者前往供給者';
    }
    final roleLabel = m.iAmRequester ? '你是需求者' : '你是供給者';

    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      appBar: AppBar(
        title: const Text('導航指引', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1a1a2e),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ── 地圖區域 ──
          Expanded(
            flex: 5,
            child: _buildMap(myLoc, target),
          ),

          // ── 資訊面板 ──
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1a1a2e),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 物資名稱 + 配送方向
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(readableName,
                                style: const TextStyle(
                                    color: Colors.greenAccent, fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          m.deliveryMode == 'DELIVER'
                              ? Icons.delivery_dining
                              : Icons.directions_walk,
                          color: Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(whoMoves,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                            Text(roleLabel,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 距離 + 方向 大字
                    if (distMeters != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            LocationService.formatDistance(distMeters),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (dirLabel != null) ...[
                            const SizedBox(width: 12),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  if (bearingDeg != null)
                                    Transform.rotate(
                                      angle: bearingDeg * pi / 180,
                                      child: const Icon(
                                        Icons.navigation,
                                        color: Colors.redAccent,
                                        size: 24,
                                      ),
                                    ),
                                  const SizedBox(width: 4),
                                  Text(dirLabel,
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 18)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '供給: ${m.supplyQty.toInt()} 份 ←→ 需求: ${m.requestQty.toInt()} 份 (滿足率 ${(m.fulfillmentRatio * 100).toInt()}%)',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[
                      const Text('GPS 定位中...',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 16)),
                    ],
                    const SizedBox(height: 16),

                    // BLE 狀態
                    _buildBleStatus(),

                    const SizedBox(height: 16),

                    // 交接按鈕
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startHandoff,
                        icon: Icon(
                          _peerDetected ? Icons.handshake : Icons.navigation,
                          color: Colors.white,
                        ),
                        label: Text(
                          _peerDetected ? '開始交接' : '開啟交接流程',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _peerDetected
                              ? Colors.amber[700]
                              : Colors.blue[700],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(LatLng? myLoc, LatLng target) {
    // 計算 bounds 包含所有點
    final points = <LatLng>[target];
    if (myLoc != null) points.add(myLoc);
    if (_supplyPos != null) points.add(_supplyPos!);
    if (_requestPos != null) points.add(_requestPos!);

    final center = _fitCenter(points);
    final zoom = _fitZoom(points);

    final markers = <Marker>[];
    final polylines = <Polyline>[];

    // 我的位置
    if (myLoc != null) {
      markers.add(Marker(
        point: myLoc,
        width: 24,
        height: 24,
        child:
            const Icon(Icons.my_location, color: Colors.cyanAccent, size: 24),
      ));
    }

    // 供給位置
    if (_supplyPos != null) {
      markers.add(Marker(
        point: _supplyPos!,
        width: 32,
        height: 32,
        child:
            const Icon(Icons.inventory_2, color: Colors.greenAccent, size: 28),
      ));
    }

    // 需求位置
    if (_requestPos != null) {
      markers.add(Marker(
        point: _requestPos!,
        width: 32,
        height: 32,
        child: const Icon(Icons.campaign, color: Colors.amber, size: 28),
      ));
    }

    // 連線
    if (_supplyPos != null && _requestPos != null) {
      polylines.add(Polyline(
        points: [_supplyPos!, _requestPos!],
        color: Colors.redAccent.withValues(alpha: 0.7),
        strokeWidth: 3,
      ));
    } else if (myLoc != null) {
      polylines.add(Polyline(
        points: [myLoc, target],
        color: Colors.redAccent.withValues(alpha: 0.7),
        strokeWidth: 3,
      ));
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        minZoom: 6.0,
        maxZoom: 18.0,
        backgroundColor: const Color(0xFF0a0a18),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // 離線向量圖磚底圖（街道+地名，無 POI/災害）
        if (_mapReady && _tileProviders != null && _mapTheme != null)
          VectorTileLayer(
            tileProviders: _tileProviders!,
            theme: _mapTheme!,
            layerMode: VectorTileLayerMode.vector,
          ),
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildBleStatus() {
    if (_peerDetected) {
      // RSSI 轉信號強度
      String strength;
      Color strengthColor;
      if (_peerRssi > -60) {
        strength = '強 (很近)';
        strengthColor = Colors.greenAccent;
      } else if (_peerRssi > -80) {
        strength = '中 (附近)';
        strengthColor = Colors.amber;
      } else {
        strength = '弱 (較遠)';
        strengthColor = Colors.orange;
      }

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.bluetooth_connected,
                color: Colors.greenAccent, size: 20),
            const SizedBox(width: 8),
            Text('偵測到 Mesh 節點',
                style:
                    const TextStyle(color: Colors.greenAccent, fontSize: 13)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: strengthColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('信號 $strength',
                  style: TextStyle(color: strengthColor, fontSize: 11)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white38),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '掃描藍牙中... 接近對方時會自動偵測',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  LatLng _fitCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(25.033, 121.565);
    double sumLat = 0, sumLng = 0;
    for (final p in points) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  double _fitZoom(List<LatLng> points) {
    if (points.length < 2) return 15;
    double maxDist = 0;
    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        final d = LocationService.haversineMeters(points[i], points[j]);
        if (d > maxDist) maxDist = d;
      }
    }
    // 粗略 zoom 映射
    if (maxDist < 100) return 17;
    if (maxDist < 500) return 15;
    if (maxDist < 2000) return 13;
    if (maxDist < 10000) return 11;
    return 9;
  }

  @override
  void dispose() {
    _stopBleScan();
    _locationRefresh?.cancel();
    _mbTiles?.dispose();
    super.dispose();
  }
}
