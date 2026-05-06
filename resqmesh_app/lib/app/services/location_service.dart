import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// 全域 GPS 定位服務 (Singleton)
/// 提供目前位置、距離計算和方位角
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionSub;
  bool _initialized = false;

  final StreamController<LatLng> _locationController =
      StreamController<LatLng>.broadcast();

  /// 目前已知位置 (可能為 null)
  LatLng? get currentLocation => _currentLocation;

  /// 位置是否可用
  bool get hasLocation => _currentLocation != null;

  /// 是否已完成 init()
  bool get isInitialized => _initialized;

  /// 位置更新 stream（broadcast）。
  /// 訂閱時立即可讀 currentLocation，後續每次 GPS 更新都會 push。
  /// MapScreenController 應使用此 stream，而非自行呼叫 Geolocator。
  Stream<LatLng> get locationStream => _locationController.stream;

  /// GPS 不可用原因 (null = 正常可用或尚未檢查)
  String? _unavailableReason;
  String? get unavailableReason => _unavailableReason;

  /// GPS 是否永久拒絕 (需要到系統設定手動開啟)
  bool _permDeniedForever = false;
  bool get permDeniedForever => _permDeniedForever;

  /// GPS 首次就緒時的回呼（用於自動加入聊天室等）
  void Function()? onFirstFix;

  /// 初始化 GPS（若已初始化則 no-op）
  /// 帶 timeout 避免在 GPS 不可用時永久阻塞
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _unavailableReason = null;
    _permDeniedForever = false;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _unavailableReason = 'GPS 服務未開啟，請前往系統設定啟用定位功能';
        debugPrint('[LocationService] GPS 服務未開啟');
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.deniedForever) {
        _permDeniedForever = true;
        _unavailableReason = 'GPS 權限已被永久拒絕，請前往系統設定 → 應用程式 → 授予定位權限';
        debugPrint('[LocationService] GPS 權限被永久拒絕');
        return;
      }
      if (perm == LocationPermission.denied) {
        _unavailableReason = '請授予 GPS 定位權限以取得更準確的媒合結果';
        debugPrint('[LocationService] GPS 權限被拒（由 _requestPermissions 統一處理）');
        return;
      }

      // 先嘗試取得上次已知位置（瞬間回傳，GPS 冷啟動前先有座標可用）
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          _currentLocation = LatLng(lastPos.latitude, lastPos.longitude);
          debugPrint('[LocationService] 使用上次已知位置');
        }
      } catch (e) {
        debugPrint('[LocationService] getLastKnownPosition 失敗: $e');
      }

      // 取得精確位置（20 秒 timeout，低階機 GPS 冷啟動需要較長時間）
      try {
        final wasNull = _currentLocation == null;
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 20));
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _locationController.add(_currentLocation!);
        if (wasNull && onFirstFix != null) {
          debugPrint('[LocationService] 首次精確定位就緒，觸發 onFirstFix');
          onFirstFix!();
          onFirstFix = null;
        }
      } on TimeoutException {
        debugPrint('[LocationService] getCurrentPosition 逾時 (20s)');
        if (_currentLocation == null) {
          _unavailableReason = 'GPS 定位逾時，請確認已開啟定位功能或移到開闊處';
        }
      } catch (e) {
        debugPrint('[LocationService] getCurrentPosition 失敗: $e');
        if (_currentLocation == null) {
          _unavailableReason = 'GPS 定位失敗: $e';
        }
      }

      // 無論初始定位是否成功，都訂閱位置更新（GPS 恢復後會自動收到）
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        final wasNull = _currentLocation == null;
        final loc = LatLng(pos.latitude, pos.longitude);
        _currentLocation = loc;
        _locationController.add(loc);
        // GPS 恢復後清除不可用原因
        if (_unavailableReason != null) {
          _unavailableReason = null;
          debugPrint('[LocationService] GPS 已恢復定位');
        }
        // 首次取得定位時觸發回呼（自動加入聊天室等）
        if (wasNull && onFirstFix != null) {
          debugPrint('[LocationService] 首次定位就緒，觸發 onFirstFix');
          onFirstFix!();
          onFirstFix = null; // 只觸發一次
        }
      });
    } catch (e) {
      debugPrint('[LocationService] 初始化失敗: $e');
      _unavailableReason = '定位服務初始化失敗: $e';
    }
  }

  /// 計算兩點間 Haversine 距離 (公尺)
  static double haversineMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final sinDLat = sin(dLat / 2);
    final sinDLng = sin(dLng / 2);
    final h = sinDLat * sinDLat +
        cos(_toRad(a.latitude)) * cos(_toRad(b.latitude)) * sinDLng * sinDLng;
    return R * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  /// 計算從 a 到 b 的方位角 (degrees, 0=北, 90=東)
  static double bearing(LatLng from, LatLng to) {
    final dLng = _toRad(to.longitude - from.longitude);
    final lat1 = _toRad(from.latitude);
    final lat2 = _toRad(to.latitude);
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    final brng = atan2(y, x) * 180 / pi;
    return (brng + 360) % 360;
  }

  /// 方位角轉中文方向
  static String bearingToDirection(double deg) {
    if (deg >= 337.5 || deg < 22.5) return '北方';
    if (deg < 67.5) return '東北方';
    if (deg < 112.5) return '東方';
    if (deg < 157.5) return '東南方';
    if (deg < 202.5) return '南方';
    if (deg < 247.5) return '西南方';
    if (deg < 292.5) return '西方';
    return '西北方';
  }

  /// 距離格式化
  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.toInt()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// 歸一化距離用於評分 (0~1, 越近越高)
  /// maxRange 為參考最大距離
  static double normalizeDistance(double meters, {double maxRange = 20000}) {
    if (meters <= 0) return 1.0;
    if (meters >= maxRange) return 0.0;
    return 1.0 - (meters / maxRange);
  }

  static double _toRad(double deg) => deg * pi / 180;

  void dispose() {
    _positionSub?.cancel();
    _positionSub = null;
    _locationController.close();
    _initialized = false;
  }
}
