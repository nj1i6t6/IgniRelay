// map_view_models.dart
//
// Stage 7-r2：地圖頁的中立視圖模型（view models）。
//
// 目的：把 controller 與 layer widgets 之間的契約從「Flutter Marker / Polygon」
// 改成純資料 VM，讓：
//   1. controller 可以脫離 Flutter UI 物件，便於 unit test；
//   2. layer widgets 只負責 render（吃 VM、吐 tap callback），耦合最小。
//
// 命名約定：所有 VM 皆 immutable，欄位 final，方便 `==` 比對與 `notifyListeners`
// 配合 `ListenableBuilder` 觸發最小 rebuild。

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'package:ignirelay_app/ui/screens/map/widgets/pin_palette.dart';

/// 危險區域 VM：對應 `Event_Logs` 中 hazardMarker 已聚合的單筆 hazard。
@immutable
class HazardVm {
  const HazardVm({
    required this.id,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    required this.severity,
    required this.type,
    required this.confirmCount,
    required this.reportedBy,
    required this.isMine,
    required this.description,
    required this.raw,
  });

  final String id;
  final double lat;
  final double lng;
  final double radiusMeters;
  final int severity;

  /// 大寫 hazard 種類：`ROADBLOCK` / `FIRE` / `CHEMICAL` / `FLOOD` /
  /// `BUILDING` / `LANDSLIDE` / 其他。
  final String type;
  final int confirmCount;
  final String reportedBy;
  final bool isMine;
  final String description;

  /// 原始 row（保留供後續 sheet / dialog 用，不是渲染依賴）。
  final Map<String, dynamic> raw;

  LatLng get latLng => LatLng(lat, lng);
}

/// Mesh 事件 VM：urgency >= 1 的事件，含描述與類別 metadata。
@immutable
class EventVm {
  const EventVm({
    required this.id,
    required this.lat,
    required this.lng,
    required this.urgency,
    required this.eventType,
    required this.category,
    required this.description,
    required this.raw,
  });

  final String id;
  final double lat;
  final double lng;
  final int urgency;
  final int eventType;

  /// 用於 cluster bubble 取色。`PinPalette.clusterPriority(category)`。
  final PinCategory category;
  final String description;
  final Map<String, dynamic> raw;

  LatLng get latLng => LatLng(lat, lng);
}

/// 救災 POI VM：對應五大類別 `resq_*`（hospital / pharmacy / police /
/// school / grocery）。
@immutable
class PoiVm {
  const PoiVm({
    required this.lat,
    required this.lng,
    required this.classKey,
    required this.subclassKey,
    required this.raw,
  });

  final double lat;
  final double lng;
  final String classKey;
  final String subclassKey;
  final Map<String, String> raw;

  LatLng get latLng => LatLng(lat, lng);
}

/// 自身位置 VM：含 GPS 精度。null 表示尚未定位成功。
@immutable
class SelfLocationVm {
  const SelfLocationVm({
    required this.location,
    required this.accuracyMeters,
  });

  final LatLng location;
  final double accuracyMeters;
}

/// 危險標記草稿 VM：marking mode（新建或編輯）下的所有可調欄位。
///
/// 注意：`description` 由 widget 層的 `TextEditingController` 持有，
/// 發布時由 widget 從 controller text 直接讀取後傳入 commands；
/// 此 VM 不複製 description 字串以避免雙寫。
@immutable
class MarkingDraftVm {
  const MarkingDraftVm({
    required this.isActive,
    required this.editingHazardId,
    required this.center,
    required this.type,
    required this.severity,
    required this.radiusMeters,
    required this.isPublishing,
  });

  /// 全 false / null 的 idle 預設。
  static const MarkingDraftVm idle = MarkingDraftVm(
    isActive: false,
    editingHazardId: null,
    center: null,
    type: 'ROADBLOCK',
    severity: 3.0,
    radiusMeters: 200.0,
    isPublishing: false,
  );

  final bool isActive;

  /// 非 null 表示編輯既有 hazard；null 表示新建。
  final String? editingHazardId;
  final LatLng? center;
  final String type;
  final double severity;
  final double radiusMeters;
  final bool isPublishing;

  bool get isEditing => editingHazardId != null;

  MarkingDraftVm copyWith({
    bool? isActive,
    Object? editingHazardId = _sentinel,
    Object? center = _sentinel,
    String? type,
    double? severity,
    double? radiusMeters,
    bool? isPublishing,
  }) {
    return MarkingDraftVm(
      isActive: isActive ?? this.isActive,
      editingHazardId: editingHazardId == _sentinel
          ? this.editingHazardId
          : editingHazardId as String?,
      center: center == _sentinel ? this.center : center as LatLng?,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isPublishing: isPublishing ?? this.isPublishing,
    );
  }
}

const _sentinel = Object();

/// SOS 廣播追蹤 VM。`activeEventId == null` 表示無進行中 SOS。
@immutable
class SosStateVm {
  const SosStateVm({
    required this.activeEventId,
    required this.urgency,
    required this.description,
  });

  static const SosStateVm idle = SosStateVm(
    activeEventId: null,
    urgency: 0,
    description: '',
  );

  final String? activeEventId;
  final int urgency;
  final String description;

  bool get isActive => activeEventId != null;
}

/// MBTiles 載入狀態。
@immutable
class MbTilesStateVm {
  const MbTilesStateVm({
    required this.loading,
    required this.available,
    required this.errorKey,
    required this.errorArg,
    required this.themeGeneration,
  });

  static const MbTilesStateVm initial = MbTilesStateVm(
    loading: true,
    available: false,
    errorKey: null,
    errorArg: null,
    themeGeneration: 0,
  );

  final bool loading;
  final bool available;

  /// ARB key：`'mapMbtilesNotFound'` / `'mapMbtilesLoadFail'`。
  final String? errorKey;
  final String? errorArg;

  /// 主題重建計數，用於強制 VectorTileLayer 重建（透過 ValueKey）。
  final int themeGeneration;
}
