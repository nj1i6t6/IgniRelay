//
//  Generated code. Do not modify.
//  source: mesh_protocol.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'mesh_protocol.pbenum.dart';

export 'mesh_protocol.pbenum.dart';

/// 核心 Event Log 結構
class MeshEvent extends $pb.GeneratedMessage {
  factory MeshEvent({
    $core.String? eventId,
    $core.List<$core.int>? senderPubKey,
    $core.int? identityLevel,
    EventType? type,
    UrgencyLevel? urgency,
    $fixnum.Int64? hlcTimestamp,
    $fixnum.Int64? hlcCounter,
    $core.int? ttl,
    $core.int? chunkIndex,
    $core.int? totalChunks,
    $core.List<$core.int>? payload,
    $core.List<$core.int>? signature,
    $core.double? receivedLat,
    $core.double? receivedLng,
    $core.double? originLat,
    $core.double? originLng,
  }) {
    final $result = create();
    if (eventId != null) {
      $result.eventId = eventId;
    }
    if (senderPubKey != null) {
      $result.senderPubKey = senderPubKey;
    }
    if (identityLevel != null) {
      $result.identityLevel = identityLevel;
    }
    if (type != null) {
      $result.type = type;
    }
    if (urgency != null) {
      $result.urgency = urgency;
    }
    if (hlcTimestamp != null) {
      $result.hlcTimestamp = hlcTimestamp;
    }
    if (hlcCounter != null) {
      $result.hlcCounter = hlcCounter;
    }
    if (ttl != null) {
      $result.ttl = ttl;
    }
    if (chunkIndex != null) {
      $result.chunkIndex = chunkIndex;
    }
    if (totalChunks != null) {
      $result.totalChunks = totalChunks;
    }
    if (payload != null) {
      $result.payload = payload;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    if (receivedLat != null) {
      $result.receivedLat = receivedLat;
    }
    if (receivedLng != null) {
      $result.receivedLng = receivedLng;
    }
    if (originLat != null) {
      $result.originLat = originLat;
    }
    if (originLng != null) {
      $result.originLng = originLng;
    }
    return $result;
  }
  MeshEvent._() : super();
  factory MeshEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MeshEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MeshEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'eventId')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'senderPubKey', $pb.PbFieldType.OY)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'identityLevel', $pb.PbFieldType.OU3)
    ..e<EventType>(4, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE, defaultOrMaker: EventType.RESOURCE_REGISTER, valueOf: EventType.valueOf, enumValues: EventType.values)
    ..e<UrgencyLevel>(5, _omitFieldNames ? '' : 'urgency', $pb.PbFieldType.OE, defaultOrMaker: UrgencyLevel.INFO, valueOf: UrgencyLevel.valueOf, enumValues: UrgencyLevel.values)
    ..aInt64(6, _omitFieldNames ? '' : 'hlcTimestamp')
    ..aInt64(7, _omitFieldNames ? '' : 'hlcCounter')
    ..a<$core.int>(8, _omitFieldNames ? '' : 'ttl', $pb.PbFieldType.O3)
    ..a<$core.int>(9, _omitFieldNames ? '' : 'chunkIndex', $pb.PbFieldType.O3)
    ..a<$core.int>(10, _omitFieldNames ? '' : 'totalChunks', $pb.PbFieldType.O3)
    ..a<$core.List<$core.int>>(11, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(12, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..a<$core.double>(13, _omitFieldNames ? '' : 'receivedLat', $pb.PbFieldType.OD)
    ..a<$core.double>(14, _omitFieldNames ? '' : 'receivedLng', $pb.PbFieldType.OD)
    ..a<$core.double>(15, _omitFieldNames ? '' : 'originLat', $pb.PbFieldType.OD)
    ..a<$core.double>(16, _omitFieldNames ? '' : 'originLng', $pb.PbFieldType.OD)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MeshEvent clone() => MeshEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MeshEvent copyWith(void Function(MeshEvent) updates) => super.copyWith((message) => updates(message as MeshEvent)) as MeshEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MeshEvent create() => MeshEvent._();
  MeshEvent createEmptyInstance() => create();
  static $pb.PbList<MeshEvent> createRepeated() => $pb.PbList<MeshEvent>();
  @$core.pragma('dart2js:noInline')
  static MeshEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MeshEvent>(create);
  static MeshEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get eventId => $_getSZ(0);
  @$pb.TagNumber(1)
  set eventId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasEventId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEventId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get senderPubKey => $_getN(1);
  @$pb.TagNumber(2)
  set senderPubKey($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSenderPubKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearSenderPubKey() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get identityLevel => $_getIZ(2);
  @$pb.TagNumber(3)
  set identityLevel($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasIdentityLevel() => $_has(2);
  @$pb.TagNumber(3)
  void clearIdentityLevel() => clearField(3);

  @$pb.TagNumber(4)
  EventType get type => $_getN(3);
  @$pb.TagNumber(4)
  set type(EventType v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasType() => $_has(3);
  @$pb.TagNumber(4)
  void clearType() => clearField(4);

  @$pb.TagNumber(5)
  UrgencyLevel get urgency => $_getN(4);
  @$pb.TagNumber(5)
  set urgency(UrgencyLevel v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasUrgency() => $_has(4);
  @$pb.TagNumber(5)
  void clearUrgency() => clearField(5);

  /// 混合邏輯時鐘 (HLC)
  @$pb.TagNumber(6)
  $fixnum.Int64 get hlcTimestamp => $_getI64(5);
  @$pb.TagNumber(6)
  set hlcTimestamp($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasHlcTimestamp() => $_has(5);
  @$pb.TagNumber(6)
  void clearHlcTimestamp() => clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get hlcCounter => $_getI64(6);
  @$pb.TagNumber(7)
  set hlcCounter($fixnum.Int64 v) { $_setInt64(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasHlcCounter() => $_has(6);
  @$pb.TagNumber(7)
  void clearHlcCounter() => clearField(7);

  @$pb.TagNumber(8)
  $core.int get ttl => $_getIZ(7);
  @$pb.TagNumber(8)
  set ttl($core.int v) { $_setSignedInt32(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasTtl() => $_has(7);
  @$pb.TagNumber(8)
  void clearTtl() => clearField(8);

  /// 分塊傳輸機制 (Chunking)
  @$pb.TagNumber(9)
  $core.int get chunkIndex => $_getIZ(8);
  @$pb.TagNumber(9)
  set chunkIndex($core.int v) { $_setSignedInt32(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasChunkIndex() => $_has(8);
  @$pb.TagNumber(9)
  void clearChunkIndex() => clearField(9);

  @$pb.TagNumber(10)
  $core.int get totalChunks => $_getIZ(9);
  @$pb.TagNumber(10)
  set totalChunks($core.int v) { $_setSignedInt32(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasTotalChunks() => $_has(9);
  @$pb.TagNumber(10)
  void clearTotalChunks() => clearField(10);

  @$pb.TagNumber(11)
  $core.List<$core.int> get payload => $_getN(10);
  @$pb.TagNumber(11)
  set payload($core.List<$core.int> v) { $_setBytes(10, v); }
  @$pb.TagNumber(11)
  $core.bool hasPayload() => $_has(10);
  @$pb.TagNumber(11)
  void clearPayload() => clearField(11);

  @$pb.TagNumber(12)
  $core.List<$core.int> get signature => $_getN(11);
  @$pb.TagNumber(12)
  set signature($core.List<$core.int> v) { $_setBytes(11, v); }
  @$pb.TagNumber(12)
  $core.bool hasSignature() => $_has(11);
  @$pb.TagNumber(12)
  void clearSignature() => clearField(12);

  /// 接收位置快照 (Received Location Snapshot — 每跳由接收方覆寫)
  /// optional：無 GPS 時不寫入；接收端以 hasReceivedLat() 判斷是否存在。
  @$pb.TagNumber(13)
  $core.double get receivedLat => $_getN(12);
  @$pb.TagNumber(13)
  set receivedLat($core.double v) { $_setDouble(12, v); }
  @$pb.TagNumber(13)
  $core.bool hasReceivedLat() => $_has(12);
  @$pb.TagNumber(13)
  void clearReceivedLat() => clearField(13);

  @$pb.TagNumber(14)
  $core.double get receivedLng => $_getN(13);
  @$pb.TagNumber(14)
  set receivedLng($core.double v) { $_setDouble(13, v); }
  @$pb.TagNumber(14)
  $core.bool hasReceivedLng() => $_has(13);
  @$pb.TagNumber(14)
  void clearReceivedLng() => clearField(14);

  /// 事件原始座標 (Origin Location — 創建者設定，中繼節點禁止修改)
  /// 用於地理圍欄路由判斷：確認封包屬於哪個里/鄉鎮市區。
  /// optional：無 GPS 時不寫入；接收端以 hasOriginLat() 判斷是否存在。
  @$pb.TagNumber(15)
  $core.double get originLat => $_getN(14);
  @$pb.TagNumber(15)
  set originLat($core.double v) { $_setDouble(14, v); }
  @$pb.TagNumber(15)
  $core.bool hasOriginLat() => $_has(14);
  @$pb.TagNumber(15)
  void clearOriginLat() => clearField(15);

  @$pb.TagNumber(16)
  $core.double get originLng => $_getN(15);
  @$pb.TagNumber(16)
  set originLng($core.double v) { $_setDouble(15, v); }
  @$pb.TagNumber(16)
  $core.bool hasOriginLng() => $_has(15);
  @$pb.TagNumber(16)
  void clearOriginLng() => clearField(16);
}

/// Bloom Filter 同步握手封包
class BloomFilterSync extends $pb.GeneratedMessage {
  factory BloomFilterSync({
    $core.List<$core.int>? filterData,
    $core.int? numHashFuncs,
    $core.int? capacity,
  }) {
    final $result = create();
    if (filterData != null) {
      $result.filterData = filterData;
    }
    if (numHashFuncs != null) {
      $result.numHashFuncs = numHashFuncs;
    }
    if (capacity != null) {
      $result.capacity = capacity;
    }
    return $result;
  }
  BloomFilterSync._() : super();
  factory BloomFilterSync.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BloomFilterSync.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BloomFilterSync', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'filterData', $pb.PbFieldType.OY)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'numHashFuncs', $pb.PbFieldType.O3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'capacity', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BloomFilterSync clone() => BloomFilterSync()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BloomFilterSync copyWith(void Function(BloomFilterSync) updates) => super.copyWith((message) => updates(message as BloomFilterSync)) as BloomFilterSync;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BloomFilterSync create() => BloomFilterSync._();
  BloomFilterSync createEmptyInstance() => create();
  static $pb.PbList<BloomFilterSync> createRepeated() => $pb.PbList<BloomFilterSync>();
  @$core.pragma('dart2js:noInline')
  static BloomFilterSync getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BloomFilterSync>(create);
  static BloomFilterSync? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get filterData => $_getN(0);
  @$pb.TagNumber(1)
  set filterData($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFilterData() => $_has(0);
  @$pb.TagNumber(1)
  void clearFilterData() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get numHashFuncs => $_getIZ(1);
  @$pb.TagNumber(2)
  set numHashFuncs($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasNumHashFuncs() => $_has(1);
  @$pb.TagNumber(2)
  void clearNumHashFuncs() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get capacity => $_getIZ(2);
  @$pb.TagNumber(3)
  set capacity($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasCapacity() => $_has(2);
  @$pb.TagNumber(3)
  void clearCapacity() => clearField(3);
}

/// 物資登記 (EventType.RESOURCE_REGISTER)
class ResourceData extends $pb.GeneratedMessage {
  factory ResourceData({
    $core.String? resourceId,
    $core.String? resourceType,
    $core.String? description,
    $core.double? quantity,
    $core.String? unit,
    $core.double? maxRangeMeters,
    $core.double? lat,
    $core.double? lng,
    $fixnum.Int64? expiresAt,
    $core.String? deliveryMode,
  }) {
    final $result = create();
    if (resourceId != null) {
      $result.resourceId = resourceId;
    }
    if (resourceType != null) {
      $result.resourceType = resourceType;
    }
    if (description != null) {
      $result.description = description;
    }
    if (quantity != null) {
      $result.quantity = quantity;
    }
    if (unit != null) {
      $result.unit = unit;
    }
    if (maxRangeMeters != null) {
      $result.maxRangeMeters = maxRangeMeters;
    }
    if (lat != null) {
      $result.lat = lat;
    }
    if (lng != null) {
      $result.lng = lng;
    }
    if (expiresAt != null) {
      $result.expiresAt = expiresAt;
    }
    if (deliveryMode != null) {
      $result.deliveryMode = deliveryMode;
    }
    return $result;
  }
  ResourceData._() : super();
  factory ResourceData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ResourceData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ResourceData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'resourceId')
    ..aOS(2, _omitFieldNames ? '' : 'resourceType')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..a<$core.double>(4, _omitFieldNames ? '' : 'quantity', $pb.PbFieldType.OF)
    ..aOS(5, _omitFieldNames ? '' : 'unit')
    ..a<$core.double>(6, _omitFieldNames ? '' : 'maxRangeMeters', $pb.PbFieldType.OF)
    ..a<$core.double>(7, _omitFieldNames ? '' : 'lat', $pb.PbFieldType.OD)
    ..a<$core.double>(8, _omitFieldNames ? '' : 'lng', $pb.PbFieldType.OD)
    ..aInt64(9, _omitFieldNames ? '' : 'expiresAt')
    ..aOS(16, _omitFieldNames ? '' : 'deliveryMode')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ResourceData clone() => ResourceData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ResourceData copyWith(void Function(ResourceData) updates) => super.copyWith((message) => updates(message as ResourceData)) as ResourceData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResourceData create() => ResourceData._();
  ResourceData createEmptyInstance() => create();
  static $pb.PbList<ResourceData> createRepeated() => $pb.PbList<ResourceData>();
  @$core.pragma('dart2js:noInline')
  static ResourceData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ResourceData>(create);
  static ResourceData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get resourceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set resourceId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasResourceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearResourceId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get resourceType => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceType($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasResourceType() => $_has(1);
  @$pb.TagNumber(2)
  void clearResourceType() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get quantity => $_getN(3);
  @$pb.TagNumber(4)
  set quantity($core.double v) { $_setFloat(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasQuantity() => $_has(3);
  @$pb.TagNumber(4)
  void clearQuantity() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get unit => $_getSZ(4);
  @$pb.TagNumber(5)
  set unit($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasUnit() => $_has(4);
  @$pb.TagNumber(5)
  void clearUnit() => clearField(5);

  @$pb.TagNumber(6)
  $core.double get maxRangeMeters => $_getN(5);
  @$pb.TagNumber(6)
  set maxRangeMeters($core.double v) { $_setFloat(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasMaxRangeMeters() => $_has(5);
  @$pb.TagNumber(6)
  void clearMaxRangeMeters() => clearField(6);

  @$pb.TagNumber(7)
  $core.double get lat => $_getN(6);
  @$pb.TagNumber(7)
  set lat($core.double v) { $_setDouble(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasLat() => $_has(6);
  @$pb.TagNumber(7)
  void clearLat() => clearField(7);

  @$pb.TagNumber(8)
  $core.double get lng => $_getN(7);
  @$pb.TagNumber(8)
  set lng($core.double v) { $_setDouble(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasLng() => $_has(7);
  @$pb.TagNumber(8)
  void clearLng() => clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get expiresAt => $_getI64(8);
  @$pb.TagNumber(9)
  set expiresAt($fixnum.Int64 v) { $_setInt64(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasExpiresAt() => $_has(8);
  @$pb.TagNumber(9)
  void clearExpiresAt() => clearField(9);

  /// 注意：tags 10–15 已保留，未來可擴充據點相關欄位
  @$pb.TagNumber(16)
  $core.String get deliveryMode => $_getSZ(9);
  @$pb.TagNumber(16)
  set deliveryMode($core.String v) { $_setString(9, v); }
  @$pb.TagNumber(16)
  $core.bool hasDeliveryMode() => $_has(9);
  @$pb.TagNumber(16)
  void clearDeliveryMode() => clearField(16);
}

/// 需求廣播 (EventType.REQUEST_BROADCAST)
class RequestData extends $pb.GeneratedMessage {
  factory RequestData({
    $core.String? requestId,
    $core.String? resourceType,
    $core.String? description,
    $core.double? quantityNeeded,
    UrgencyLevel? urgency,
    $core.double? lat,
    $core.double? lng,
    $core.double? maxRangeMeters,
    $core.String? mobilityMode,
    $core.String? note,
  }) {
    final $result = create();
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (resourceType != null) {
      $result.resourceType = resourceType;
    }
    if (description != null) {
      $result.description = description;
    }
    if (quantityNeeded != null) {
      $result.quantityNeeded = quantityNeeded;
    }
    if (urgency != null) {
      $result.urgency = urgency;
    }
    if (lat != null) {
      $result.lat = lat;
    }
    if (lng != null) {
      $result.lng = lng;
    }
    if (maxRangeMeters != null) {
      $result.maxRangeMeters = maxRangeMeters;
    }
    if (mobilityMode != null) {
      $result.mobilityMode = mobilityMode;
    }
    if (note != null) {
      $result.note = note;
    }
    return $result;
  }
  RequestData._() : super();
  factory RequestData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RequestData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RequestData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOS(2, _omitFieldNames ? '' : 'resourceType')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..a<$core.double>(4, _omitFieldNames ? '' : 'quantityNeeded', $pb.PbFieldType.OF)
    ..e<UrgencyLevel>(5, _omitFieldNames ? '' : 'urgency', $pb.PbFieldType.OE, defaultOrMaker: UrgencyLevel.INFO, valueOf: UrgencyLevel.valueOf, enumValues: UrgencyLevel.values)
    ..a<$core.double>(6, _omitFieldNames ? '' : 'lat', $pb.PbFieldType.OD)
    ..a<$core.double>(7, _omitFieldNames ? '' : 'lng', $pb.PbFieldType.OD)
    ..a<$core.double>(8, _omitFieldNames ? '' : 'maxRangeMeters', $pb.PbFieldType.OF)
    ..aOS(9, _omitFieldNames ? '' : 'mobilityMode')
    ..aOS(10, _omitFieldNames ? '' : 'note')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RequestData clone() => RequestData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RequestData copyWith(void Function(RequestData) updates) => super.copyWith((message) => updates(message as RequestData)) as RequestData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RequestData create() => RequestData._();
  RequestData createEmptyInstance() => create();
  static $pb.PbList<RequestData> createRepeated() => $pb.PbList<RequestData>();
  @$core.pragma('dart2js:noInline')
  static RequestData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RequestData>(create);
  static RequestData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get resourceType => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceType($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasResourceType() => $_has(1);
  @$pb.TagNumber(2)
  void clearResourceType() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get quantityNeeded => $_getN(3);
  @$pb.TagNumber(4)
  set quantityNeeded($core.double v) { $_setFloat(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasQuantityNeeded() => $_has(3);
  @$pb.TagNumber(4)
  void clearQuantityNeeded() => clearField(4);

  @$pb.TagNumber(5)
  UrgencyLevel get urgency => $_getN(4);
  @$pb.TagNumber(5)
  set urgency(UrgencyLevel v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasUrgency() => $_has(4);
  @$pb.TagNumber(5)
  void clearUrgency() => clearField(5);

  @$pb.TagNumber(6)
  $core.double get lat => $_getN(5);
  @$pb.TagNumber(6)
  set lat($core.double v) { $_setDouble(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasLat() => $_has(5);
  @$pb.TagNumber(6)
  void clearLat() => clearField(6);

  @$pb.TagNumber(7)
  $core.double get lng => $_getN(6);
  @$pb.TagNumber(7)
  set lng($core.double v) { $_setDouble(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasLng() => $_has(6);
  @$pb.TagNumber(7)
  void clearLng() => clearField(7);

  @$pb.TagNumber(8)
  $core.double get maxRangeMeters => $_getN(7);
  @$pb.TagNumber(8)
  set maxRangeMeters($core.double v) { $_setFloat(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasMaxRangeMeters() => $_has(7);
  @$pb.TagNumber(8)
  void clearMaxRangeMeters() => clearField(8);

  @$pb.TagNumber(9)
  $core.String get mobilityMode => $_getSZ(8);
  @$pb.TagNumber(9)
  set mobilityMode($core.String v) { $_setString(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasMobilityMode() => $_has(8);
  @$pb.TagNumber(9)
  void clearMobilityMode() => clearField(9);

  @$pb.TagNumber(10)
  $core.String get note => $_getSZ(9);
  @$pb.TagNumber(10)
  set note($core.String v) { $_setString(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasNote() => $_has(9);
  @$pb.TagNumber(10)
  void clearNote() => clearField(10);
}

/// 媒合意向 (EventType.MATCH_INTENT)
class MatchIntentData extends $pb.GeneratedMessage {
  factory MatchIntentData({
    $core.String? requestId,
    $core.String? resourceId,
    $core.List<$core.int>? requesterPubKey,
    $core.List<$core.int>? providerPubKey,
    $core.double? matchScore,
    $fixnum.Int64? matchExpiresAt,
  }) {
    final $result = create();
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (resourceId != null) {
      $result.resourceId = resourceId;
    }
    if (requesterPubKey != null) {
      $result.requesterPubKey = requesterPubKey;
    }
    if (providerPubKey != null) {
      $result.providerPubKey = providerPubKey;
    }
    if (matchScore != null) {
      $result.matchScore = matchScore;
    }
    if (matchExpiresAt != null) {
      $result.matchExpiresAt = matchExpiresAt;
    }
    return $result;
  }
  MatchIntentData._() : super();
  factory MatchIntentData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MatchIntentData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MatchIntentData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOS(2, _omitFieldNames ? '' : 'resourceId')
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'requesterPubKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'providerPubKey', $pb.PbFieldType.OY)
    ..a<$core.double>(5, _omitFieldNames ? '' : 'matchScore', $pb.PbFieldType.OF)
    ..aInt64(6, _omitFieldNames ? '' : 'matchExpiresAt')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MatchIntentData clone() => MatchIntentData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MatchIntentData copyWith(void Function(MatchIntentData) updates) => super.copyWith((message) => updates(message as MatchIntentData)) as MatchIntentData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MatchIntentData create() => MatchIntentData._();
  MatchIntentData createEmptyInstance() => create();
  static $pb.PbList<MatchIntentData> createRepeated() => $pb.PbList<MatchIntentData>();
  @$core.pragma('dart2js:noInline')
  static MatchIntentData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MatchIntentData>(create);
  static MatchIntentData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasResourceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearResourceId() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get requesterPubKey => $_getN(2);
  @$pb.TagNumber(3)
  set requesterPubKey($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasRequesterPubKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequesterPubKey() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get providerPubKey => $_getN(3);
  @$pb.TagNumber(4)
  set providerPubKey($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasProviderPubKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearProviderPubKey() => clearField(4);

  @$pb.TagNumber(5)
  $core.double get matchScore => $_getN(4);
  @$pb.TagNumber(5)
  set matchScore($core.double v) { $_setFloat(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasMatchScore() => $_has(4);
  @$pb.TagNumber(5)
  void clearMatchScore() => clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get matchExpiresAt => $_getI64(5);
  @$pb.TagNumber(6)
  set matchExpiresAt($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasMatchExpiresAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearMatchExpiresAt() => clearField(6);
}

/// 物理交割憑證 (EventType.PHYSICAL_HANDSHAKE)
class PhysicalHandshakeData extends $pb.GeneratedMessage {
  factory PhysicalHandshakeData({
    $core.String? resourceId,
    $core.String? requestId,
    $core.List<$core.int>? requesterPubKey,
    $core.List<$core.int>? providerPubKey,
    $core.List<$core.int>? requesterSignature,
    $core.List<$core.int>? providerSignature,
    $core.String? method,
  }) {
    final $result = create();
    if (resourceId != null) {
      $result.resourceId = resourceId;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (requesterPubKey != null) {
      $result.requesterPubKey = requesterPubKey;
    }
    if (providerPubKey != null) {
      $result.providerPubKey = providerPubKey;
    }
    if (requesterSignature != null) {
      $result.requesterSignature = requesterSignature;
    }
    if (providerSignature != null) {
      $result.providerSignature = providerSignature;
    }
    if (method != null) {
      $result.method = method;
    }
    return $result;
  }
  PhysicalHandshakeData._() : super();
  factory PhysicalHandshakeData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PhysicalHandshakeData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PhysicalHandshakeData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'resourceId')
    ..aOS(2, _omitFieldNames ? '' : 'requestId')
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'requesterPubKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'providerPubKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(5, _omitFieldNames ? '' : 'requesterSignature', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(6, _omitFieldNames ? '' : 'providerSignature', $pb.PbFieldType.OY)
    ..aOS(7, _omitFieldNames ? '' : 'method')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PhysicalHandshakeData clone() => PhysicalHandshakeData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PhysicalHandshakeData copyWith(void Function(PhysicalHandshakeData) updates) => super.copyWith((message) => updates(message as PhysicalHandshakeData)) as PhysicalHandshakeData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PhysicalHandshakeData create() => PhysicalHandshakeData._();
  PhysicalHandshakeData createEmptyInstance() => create();
  static $pb.PbList<PhysicalHandshakeData> createRepeated() => $pb.PbList<PhysicalHandshakeData>();
  @$core.pragma('dart2js:noInline')
  static PhysicalHandshakeData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PhysicalHandshakeData>(create);
  static PhysicalHandshakeData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get resourceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set resourceId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasResourceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearResourceId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRequestId() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get requesterPubKey => $_getN(2);
  @$pb.TagNumber(3)
  set requesterPubKey($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasRequesterPubKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequesterPubKey() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get providerPubKey => $_getN(3);
  @$pb.TagNumber(4)
  set providerPubKey($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasProviderPubKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearProviderPubKey() => clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get requesterSignature => $_getN(4);
  @$pb.TagNumber(5)
  set requesterSignature($core.List<$core.int> v) { $_setBytes(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasRequesterSignature() => $_has(4);
  @$pb.TagNumber(5)
  void clearRequesterSignature() => clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get providerSignature => $_getN(5);
  @$pb.TagNumber(6)
  set providerSignature($core.List<$core.int> v) { $_setBytes(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasProviderSignature() => $_has(5);
  @$pb.TagNumber(6)
  void clearProviderSignature() => clearField(6);

  @$pb.TagNumber(7)
  $core.String get method => $_getSZ(6);
  @$pb.TagNumber(7)
  set method($core.String v) { $_setString(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasMethod() => $_has(6);
  @$pb.TagNumber(7)
  void clearMethod() => clearField(7);
}

/// 動態危險標記 (EventType.HAZARD_MARKER)
class HazardData extends $pb.GeneratedMessage {
  factory HazardData({
    $core.String? hazardId,
    $core.String? hazardType,
    $core.int? severity,
    $core.double? centerLat,
    $core.double? centerLng,
    $core.double? radiusMeters,
    $fixnum.Int64? observedAt,
    $core.String? description,
    $core.bool? isConfirmation,
  }) {
    final $result = create();
    if (hazardId != null) {
      $result.hazardId = hazardId;
    }
    if (hazardType != null) {
      $result.hazardType = hazardType;
    }
    if (severity != null) {
      $result.severity = severity;
    }
    if (centerLat != null) {
      $result.centerLat = centerLat;
    }
    if (centerLng != null) {
      $result.centerLng = centerLng;
    }
    if (radiusMeters != null) {
      $result.radiusMeters = radiusMeters;
    }
    if (observedAt != null) {
      $result.observedAt = observedAt;
    }
    if (description != null) {
      $result.description = description;
    }
    if (isConfirmation != null) {
      $result.isConfirmation = isConfirmation;
    }
    return $result;
  }
  HazardData._() : super();
  factory HazardData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory HazardData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'HazardData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'hazardId')
    ..aOS(2, _omitFieldNames ? '' : 'hazardType')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'severity', $pb.PbFieldType.OU3)
    ..a<$core.double>(4, _omitFieldNames ? '' : 'centerLat', $pb.PbFieldType.OD)
    ..a<$core.double>(5, _omitFieldNames ? '' : 'centerLng', $pb.PbFieldType.OD)
    ..a<$core.double>(6, _omitFieldNames ? '' : 'radiusMeters', $pb.PbFieldType.OF)
    ..aInt64(7, _omitFieldNames ? '' : 'observedAt')
    ..aOS(8, _omitFieldNames ? '' : 'description')
    ..aOB(9, _omitFieldNames ? '' : 'isConfirmation')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  HazardData clone() => HazardData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  HazardData copyWith(void Function(HazardData) updates) => super.copyWith((message) => updates(message as HazardData)) as HazardData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HazardData create() => HazardData._();
  HazardData createEmptyInstance() => create();
  static $pb.PbList<HazardData> createRepeated() => $pb.PbList<HazardData>();
  @$core.pragma('dart2js:noInline')
  static HazardData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<HazardData>(create);
  static HazardData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get hazardId => $_getSZ(0);
  @$pb.TagNumber(1)
  set hazardId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasHazardId() => $_has(0);
  @$pb.TagNumber(1)
  void clearHazardId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get hazardType => $_getSZ(1);
  @$pb.TagNumber(2)
  set hazardType($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasHazardType() => $_has(1);
  @$pb.TagNumber(2)
  void clearHazardType() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get severity => $_getIZ(2);
  @$pb.TagNumber(3)
  set severity($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSeverity() => $_has(2);
  @$pb.TagNumber(3)
  void clearSeverity() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get centerLat => $_getN(3);
  @$pb.TagNumber(4)
  set centerLat($core.double v) { $_setDouble(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasCenterLat() => $_has(3);
  @$pb.TagNumber(4)
  void clearCenterLat() => clearField(4);

  @$pb.TagNumber(5)
  $core.double get centerLng => $_getN(4);
  @$pb.TagNumber(5)
  set centerLng($core.double v) { $_setDouble(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasCenterLng() => $_has(4);
  @$pb.TagNumber(5)
  void clearCenterLng() => clearField(5);

  @$pb.TagNumber(6)
  $core.double get radiusMeters => $_getN(5);
  @$pb.TagNumber(6)
  set radiusMeters($core.double v) { $_setFloat(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasRadiusMeters() => $_has(5);
  @$pb.TagNumber(6)
  void clearRadiusMeters() => clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get observedAt => $_getI64(6);
  @$pb.TagNumber(7)
  set observedAt($fixnum.Int64 v) { $_setInt64(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasObservedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearObservedAt() => clearField(7);

  @$pb.TagNumber(8)
  $core.String get description => $_getSZ(7);
  @$pb.TagNumber(8)
  set description($core.String v) { $_setString(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasDescription() => $_has(7);
  @$pb.TagNumber(8)
  void clearDescription() => clearField(8);

  @$pb.TagNumber(9)
  $core.bool get isConfirmation => $_getBF(8);
  @$pb.TagNumber(9)
  set isConfirmation($core.bool v) { $_setBool(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasIsConfirmation() => $_has(8);
  @$pb.TagNumber(9)
  void clearIsConfirmation() => clearField(9);
}

/// 惡意節點檢舉投票 (EventType.QUARANTINE_VOTE)
class QuarantineVoteData extends $pb.GeneratedMessage {
  factory QuarantineVoteData({
    $core.List<$core.int>? targetPubKey,
    $core.String? reason,
    $core.double? voteWeight,
  }) {
    final $result = create();
    if (targetPubKey != null) {
      $result.targetPubKey = targetPubKey;
    }
    if (reason != null) {
      $result.reason = reason;
    }
    if (voteWeight != null) {
      $result.voteWeight = voteWeight;
    }
    return $result;
  }
  QuarantineVoteData._() : super();
  factory QuarantineVoteData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory QuarantineVoteData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'QuarantineVoteData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'targetPubKey', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..a<$core.double>(3, _omitFieldNames ? '' : 'voteWeight', $pb.PbFieldType.OF)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  QuarantineVoteData clone() => QuarantineVoteData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  QuarantineVoteData copyWith(void Function(QuarantineVoteData) updates) => super.copyWith((message) => updates(message as QuarantineVoteData)) as QuarantineVoteData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QuarantineVoteData create() => QuarantineVoteData._();
  QuarantineVoteData createEmptyInstance() => create();
  static $pb.PbList<QuarantineVoteData> createRepeated() => $pb.PbList<QuarantineVoteData>();
  @$core.pragma('dart2js:noInline')
  static QuarantineVoteData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<QuarantineVoteData>(create);
  static QuarantineVoteData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get targetPubKey => $_getN(0);
  @$pb.TagNumber(1)
  set targetPubKey($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTargetPubKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearTargetPubKey() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => clearField(2);

  @$pb.TagNumber(3)
  $core.double get voteWeight => $_getN(2);
  @$pb.TagNumber(3)
  set voteWeight($core.double v) { $_setFloat(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasVoteWeight() => $_has(2);
  @$pb.TagNumber(3)
  void clearVoteWeight() => clearField(3);
}

/// 釋放配對 (EventType.MATCH_CANCEL)
class MatchCancelData extends $pb.GeneratedMessage {
  factory MatchCancelData({
    $core.String? requestId,
    $core.String? resourceId,
    $core.String? reason,
    $core.String? negotiationId,
  }) {
    final $result = create();
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (resourceId != null) {
      $result.resourceId = resourceId;
    }
    if (reason != null) {
      $result.reason = reason;
    }
    if (negotiationId != null) {
      $result.negotiationId = negotiationId;
    }
    return $result;
  }
  MatchCancelData._() : super();
  factory MatchCancelData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MatchCancelData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MatchCancelData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOS(2, _omitFieldNames ? '' : 'resourceId')
    ..aOS(3, _omitFieldNames ? '' : 'reason')
    ..aOS(4, _omitFieldNames ? '' : 'negotiationId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MatchCancelData clone() => MatchCancelData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MatchCancelData copyWith(void Function(MatchCancelData) updates) => super.copyWith((message) => updates(message as MatchCancelData)) as MatchCancelData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MatchCancelData create() => MatchCancelData._();
  MatchCancelData createEmptyInstance() => create();
  static $pb.PbList<MatchCancelData> createRepeated() => $pb.PbList<MatchCancelData>();
  @$core.pragma('dart2js:noInline')
  static MatchCancelData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MatchCancelData>(create);
  static MatchCancelData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasResourceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearResourceId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(3)
  set reason($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearReason() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get negotiationId => $_getSZ(3);
  @$pb.TagNumber(4)
  set negotiationId($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasNegotiationId() => $_has(3);
  @$pb.TagNumber(4)
  void clearNegotiationId() => clearField(4);
}

/// 醫療卡摘要 (附加在 SOS 廣播 payload 中，僅包含用戶授權的欄位)
class MedicalSummary extends $pb.GeneratedMessage {
  factory MedicalSummary({
    $core.String? name,
    $core.int? age,
    $core.int? heightCm,
    $core.int? weightKg,
    $core.String? bloodType,
    $core.Iterable<$core.String>? conditions,
    $core.Iterable<AllergyEntry>? allergies,
    $core.Iterable<$core.String>? medications,
    EmergencyContact? emergencyContact,
    $core.bool? organDonor,
    $core.String? primaryLanguage,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (age != null) {
      $result.age = age;
    }
    if (heightCm != null) {
      $result.heightCm = heightCm;
    }
    if (weightKg != null) {
      $result.weightKg = weightKg;
    }
    if (bloodType != null) {
      $result.bloodType = bloodType;
    }
    if (conditions != null) {
      $result.conditions.addAll(conditions);
    }
    if (allergies != null) {
      $result.allergies.addAll(allergies);
    }
    if (medications != null) {
      $result.medications.addAll(medications);
    }
    if (emergencyContact != null) {
      $result.emergencyContact = emergencyContact;
    }
    if (organDonor != null) {
      $result.organDonor = organDonor;
    }
    if (primaryLanguage != null) {
      $result.primaryLanguage = primaryLanguage;
    }
    return $result;
  }
  MedicalSummary._() : super();
  factory MedicalSummary.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MedicalSummary.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MedicalSummary', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'age', $pb.PbFieldType.O3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'heightCm', $pb.PbFieldType.O3)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'weightKg', $pb.PbFieldType.O3)
    ..aOS(5, _omitFieldNames ? '' : 'bloodType')
    ..pPS(6, _omitFieldNames ? '' : 'conditions')
    ..pc<AllergyEntry>(7, _omitFieldNames ? '' : 'allergies', $pb.PbFieldType.PM, subBuilder: AllergyEntry.create)
    ..pPS(8, _omitFieldNames ? '' : 'medications')
    ..aOM<EmergencyContact>(9, _omitFieldNames ? '' : 'emergencyContact', subBuilder: EmergencyContact.create)
    ..aOB(10, _omitFieldNames ? '' : 'organDonor')
    ..aOS(11, _omitFieldNames ? '' : 'primaryLanguage')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MedicalSummary clone() => MedicalSummary()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MedicalSummary copyWith(void Function(MedicalSummary) updates) => super.copyWith((message) => updates(message as MedicalSummary)) as MedicalSummary;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MedicalSummary create() => MedicalSummary._();
  MedicalSummary createEmptyInstance() => create();
  static $pb.PbList<MedicalSummary> createRepeated() => $pb.PbList<MedicalSummary>();
  @$core.pragma('dart2js:noInline')
  static MedicalSummary getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MedicalSummary>(create);
  static MedicalSummary? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get age => $_getIZ(1);
  @$pb.TagNumber(2)
  set age($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasAge() => $_has(1);
  @$pb.TagNumber(2)
  void clearAge() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get heightCm => $_getIZ(2);
  @$pb.TagNumber(3)
  set heightCm($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasHeightCm() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeightCm() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get weightKg => $_getIZ(3);
  @$pb.TagNumber(4)
  set weightKg($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasWeightKg() => $_has(3);
  @$pb.TagNumber(4)
  void clearWeightKg() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get bloodType => $_getSZ(4);
  @$pb.TagNumber(5)
  set bloodType($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasBloodType() => $_has(4);
  @$pb.TagNumber(5)
  void clearBloodType() => clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.String> get conditions => $_getList(5);

  @$pb.TagNumber(7)
  $core.List<AllergyEntry> get allergies => $_getList(6);

  @$pb.TagNumber(8)
  $core.List<$core.String> get medications => $_getList(7);

  @$pb.TagNumber(9)
  EmergencyContact get emergencyContact => $_getN(8);
  @$pb.TagNumber(9)
  set emergencyContact(EmergencyContact v) { setField(9, v); }
  @$pb.TagNumber(9)
  $core.bool hasEmergencyContact() => $_has(8);
  @$pb.TagNumber(9)
  void clearEmergencyContact() => clearField(9);
  @$pb.TagNumber(9)
  EmergencyContact ensureEmergencyContact() => $_ensure(8);

  @$pb.TagNumber(10)
  $core.bool get organDonor => $_getBF(9);
  @$pb.TagNumber(10)
  set organDonor($core.bool v) { $_setBool(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasOrganDonor() => $_has(9);
  @$pb.TagNumber(10)
  void clearOrganDonor() => clearField(10);

  @$pb.TagNumber(11)
  $core.String get primaryLanguage => $_getSZ(10);
  @$pb.TagNumber(11)
  set primaryLanguage($core.String v) { $_setString(10, v); }
  @$pb.TagNumber(11)
  $core.bool hasPrimaryLanguage() => $_has(10);
  @$pb.TagNumber(11)
  void clearPrimaryLanguage() => clearField(11);
}

/// 過敏原條目
class AllergyEntry extends $pb.GeneratedMessage {
  factory AllergyEntry({
    $core.String? allergen,
    $core.String? reaction,
  }) {
    final $result = create();
    if (allergen != null) {
      $result.allergen = allergen;
    }
    if (reaction != null) {
      $result.reaction = reaction;
    }
    return $result;
  }
  AllergyEntry._() : super();
  factory AllergyEntry.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AllergyEntry.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AllergyEntry', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'allergen')
    ..aOS(2, _omitFieldNames ? '' : 'reaction')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AllergyEntry clone() => AllergyEntry()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AllergyEntry copyWith(void Function(AllergyEntry) updates) => super.copyWith((message) => updates(message as AllergyEntry)) as AllergyEntry;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AllergyEntry create() => AllergyEntry._();
  AllergyEntry createEmptyInstance() => create();
  static $pb.PbList<AllergyEntry> createRepeated() => $pb.PbList<AllergyEntry>();
  @$core.pragma('dart2js:noInline')
  static AllergyEntry getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AllergyEntry>(create);
  static AllergyEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get allergen => $_getSZ(0);
  @$pb.TagNumber(1)
  set allergen($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasAllergen() => $_has(0);
  @$pb.TagNumber(1)
  void clearAllergen() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get reaction => $_getSZ(1);
  @$pb.TagNumber(2)
  set reaction($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasReaction() => $_has(1);
  @$pb.TagNumber(2)
  void clearReaction() => clearField(2);
}

/// 緊急聯絡人
class EmergencyContact extends $pb.GeneratedMessage {
  factory EmergencyContact({
    $core.String? phone,
    $core.String? relation,
  }) {
    final $result = create();
    if (phone != null) {
      $result.phone = phone;
    }
    if (relation != null) {
      $result.relation = relation;
    }
    return $result;
  }
  EmergencyContact._() : super();
  factory EmergencyContact.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EmergencyContact.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'EmergencyContact', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'phone')
    ..aOS(2, _omitFieldNames ? '' : 'relation')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  EmergencyContact clone() => EmergencyContact()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  EmergencyContact copyWith(void Function(EmergencyContact) updates) => super.copyWith((message) => updates(message as EmergencyContact)) as EmergencyContact;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EmergencyContact create() => EmergencyContact._();
  EmergencyContact createEmptyInstance() => create();
  static $pb.PbList<EmergencyContact> createRepeated() => $pb.PbList<EmergencyContact>();
  @$core.pragma('dart2js:noInline')
  static EmergencyContact getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EmergencyContact>(create);
  static EmergencyContact? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get phone => $_getSZ(0);
  @$pb.TagNumber(1)
  set phone($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPhone() => $_has(0);
  @$pb.TagNumber(1)
  void clearPhone() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get relation => $_getSZ(1);
  @$pb.TagNumber(2)
  set relation($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasRelation() => $_has(1);
  @$pb.TagNumber(2)
  void clearRelation() => clearField(2);
}

///  433MHz RF 住警器火警訊號 (EventType.FIRE_ALARM_RF)
///  由 Tier 0 基地台接收傳統住警器 RF 訊號後轉譯生成，自動設為 SOS_RED 優先級
///
///  ⚠ Wire-format 注意：
///    tag 2 在舊版草稿中曾定義為 uint32 rf_frequency_mhz；
///    此版本改為 int32 rssi，語意不同但 wire-type 相同（varint）。
///    因 0.2.0 尚未部署，目前無在野 payload，判定向後相容風險可接受。
///    若日後需新增 rf_frequency_mhz，請使用 tag 8 或更高。
///    tags 5–7 保留給未來擴充 (detected_at, raw_rf_payload 等)。
class FireAlarmRfData extends $pb.GeneratedMessage {
  factory FireAlarmRfData({
    $core.String? detectorBrand,
    $core.int? rssi,
    $core.double? stationLat,
    $core.double? stationLng,
  }) {
    final $result = create();
    if (detectorBrand != null) {
      $result.detectorBrand = detectorBrand;
    }
    if (rssi != null) {
      $result.rssi = rssi;
    }
    if (stationLat != null) {
      $result.stationLat = stationLat;
    }
    if (stationLng != null) {
      $result.stationLng = stationLng;
    }
    return $result;
  }
  FireAlarmRfData._() : super();
  factory FireAlarmRfData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FireAlarmRfData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FireAlarmRfData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'detectorBrand')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'rssi', $pb.PbFieldType.O3)
    ..a<$core.double>(3, _omitFieldNames ? '' : 'stationLat', $pb.PbFieldType.OD)
    ..a<$core.double>(4, _omitFieldNames ? '' : 'stationLng', $pb.PbFieldType.OD)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FireAlarmRfData clone() => FireAlarmRfData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FireAlarmRfData copyWith(void Function(FireAlarmRfData) updates) => super.copyWith((message) => updates(message as FireAlarmRfData)) as FireAlarmRfData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FireAlarmRfData create() => FireAlarmRfData._();
  FireAlarmRfData createEmptyInstance() => create();
  static $pb.PbList<FireAlarmRfData> createRepeated() => $pb.PbList<FireAlarmRfData>();
  @$core.pragma('dart2js:noInline')
  static FireAlarmRfData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FireAlarmRfData>(create);
  static FireAlarmRfData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get detectorBrand => $_getSZ(0);
  @$pb.TagNumber(1)
  set detectorBrand($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasDetectorBrand() => $_has(0);
  @$pb.TagNumber(1)
  void clearDetectorBrand() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get rssi => $_getIZ(1);
  @$pb.TagNumber(2)
  set rssi($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasRssi() => $_has(1);
  @$pb.TagNumber(2)
  void clearRssi() => clearField(2);

  @$pb.TagNumber(3)
  $core.double get stationLat => $_getN(2);
  @$pb.TagNumber(3)
  set stationLat($core.double v) { $_setDouble(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasStationLat() => $_has(2);
  @$pb.TagNumber(3)
  void clearStationLat() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get stationLng => $_getN(3);
  @$pb.TagNumber(4)
  set stationLng($core.double v) { $_setDouble(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasStationLng() => $_has(3);
  @$pb.TagNumber(4)
  void clearStationLng() => clearField(4);
}

/// 媒合確認 (EventType.MATCH_CONFIRM)
class MatchConfirmData extends $pb.GeneratedMessage {
  factory MatchConfirmData({
    $core.String? requestId,
    $core.String? resourceId,
    $core.List<$core.int>? requesterPubKey,
    $core.List<$core.int>? providerPubKey,
  }) {
    final $result = create();
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (resourceId != null) {
      $result.resourceId = resourceId;
    }
    if (requesterPubKey != null) {
      $result.requesterPubKey = requesterPubKey;
    }
    if (providerPubKey != null) {
      $result.providerPubKey = providerPubKey;
    }
    return $result;
  }
  MatchConfirmData._() : super();
  factory MatchConfirmData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MatchConfirmData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MatchConfirmData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOS(2, _omitFieldNames ? '' : 'resourceId')
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'requesterPubKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'providerPubKey', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MatchConfirmData clone() => MatchConfirmData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MatchConfirmData copyWith(void Function(MatchConfirmData) updates) => super.copyWith((message) => updates(message as MatchConfirmData)) as MatchConfirmData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MatchConfirmData create() => MatchConfirmData._();
  MatchConfirmData createEmptyInstance() => create();
  static $pb.PbList<MatchConfirmData> createRepeated() => $pb.PbList<MatchConfirmData>();
  @$core.pragma('dart2js:noInline')
  static MatchConfirmData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MatchConfirmData>(create);
  static MatchConfirmData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasResourceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearResourceId() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get requesterPubKey => $_getN(2);
  @$pb.TagNumber(3)
  set requesterPubKey($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasRequesterPubKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequesterPubKey() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get providerPubKey => $_getN(3);
  @$pb.TagNumber(4)
  set providerPubKey($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasProviderPubKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearProviderPubKey() => clearField(4);
}

/// 媒合拒絕 (EventType.MATCH_REJECT)
class MatchRejectData extends $pb.GeneratedMessage {
  factory MatchRejectData({
    $core.String? requestId,
    $core.String? resourceId,
    $core.String? reason,
  }) {
    final $result = create();
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (resourceId != null) {
      $result.resourceId = resourceId;
    }
    if (reason != null) {
      $result.reason = reason;
    }
    return $result;
  }
  MatchRejectData._() : super();
  factory MatchRejectData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MatchRejectData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MatchRejectData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOS(2, _omitFieldNames ? '' : 'resourceId')
    ..aOS(3, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MatchRejectData clone() => MatchRejectData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MatchRejectData copyWith(void Function(MatchRejectData) updates) => super.copyWith((message) => updates(message as MatchRejectData)) as MatchRejectData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MatchRejectData create() => MatchRejectData._();
  MatchRejectData createEmptyInstance() => create();
  static $pb.PbList<MatchRejectData> createRepeated() => $pb.PbList<MatchRejectData>();
  @$core.pragma('dart2js:noInline')
  static MatchRejectData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MatchRejectData>(create);
  static MatchRejectData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasResourceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearResourceId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(3)
  set reason($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearReason() => clearField(3);
}

/// 物資確認詢問 (EventType.MATCH_INQUIRY)
class MatchInquiryData extends $pb.GeneratedMessage {
  factory MatchInquiryData({
    $core.String? resourceId,
    $core.List<$core.int>? inquirerPubKey,
    $core.String? inquiryId,
  }) {
    final $result = create();
    if (resourceId != null) {
      $result.resourceId = resourceId;
    }
    if (inquirerPubKey != null) {
      $result.inquirerPubKey = inquirerPubKey;
    }
    if (inquiryId != null) {
      $result.inquiryId = inquiryId;
    }
    return $result;
  }
  MatchInquiryData._() : super();
  factory MatchInquiryData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MatchInquiryData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MatchInquiryData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'resourceId')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'inquirerPubKey', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'inquiryId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MatchInquiryData clone() => MatchInquiryData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MatchInquiryData copyWith(void Function(MatchInquiryData) updates) => super.copyWith((message) => updates(message as MatchInquiryData)) as MatchInquiryData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MatchInquiryData create() => MatchInquiryData._();
  MatchInquiryData createEmptyInstance() => create();
  static $pb.PbList<MatchInquiryData> createRepeated() => $pb.PbList<MatchInquiryData>();
  @$core.pragma('dart2js:noInline')
  static MatchInquiryData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MatchInquiryData>(create);
  static MatchInquiryData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get resourceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set resourceId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasResourceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearResourceId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get inquirerPubKey => $_getN(1);
  @$pb.TagNumber(2)
  set inquirerPubKey($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasInquirerPubKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearInquirerPubKey() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get inquiryId => $_getSZ(2);
  @$pb.TagNumber(3)
  set inquiryId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasInquiryId() => $_has(2);
  @$pb.TagNumber(3)
  void clearInquiryId() => clearField(3);
}

/// 物資確認回覆 (EventType.MATCH_AVAILABLE / MATCH_GONE)
class MatchInquiryResponse extends $pb.GeneratedMessage {
  factory MatchInquiryResponse({
    $core.String? inquiryId,
    $core.String? resourceId,
    $core.bool? isAvailable,
  }) {
    final $result = create();
    if (inquiryId != null) {
      $result.inquiryId = inquiryId;
    }
    if (resourceId != null) {
      $result.resourceId = resourceId;
    }
    if (isAvailable != null) {
      $result.isAvailable = isAvailable;
    }
    return $result;
  }
  MatchInquiryResponse._() : super();
  factory MatchInquiryResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MatchInquiryResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MatchInquiryResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'inquiryId')
    ..aOS(2, _omitFieldNames ? '' : 'resourceId')
    ..aOB(3, _omitFieldNames ? '' : 'isAvailable')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MatchInquiryResponse clone() => MatchInquiryResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MatchInquiryResponse copyWith(void Function(MatchInquiryResponse) updates) => super.copyWith((message) => updates(message as MatchInquiryResponse)) as MatchInquiryResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MatchInquiryResponse create() => MatchInquiryResponse._();
  MatchInquiryResponse createEmptyInstance() => create();
  static $pb.PbList<MatchInquiryResponse> createRepeated() => $pb.PbList<MatchInquiryResponse>();
  @$core.pragma('dart2js:noInline')
  static MatchInquiryResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MatchInquiryResponse>(create);
  static MatchInquiryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get inquiryId => $_getSZ(0);
  @$pb.TagNumber(1)
  set inquiryId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasInquiryId() => $_has(0);
  @$pb.TagNumber(1)
  void clearInquiryId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasResourceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearResourceId() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isAvailable => $_getBF(2);
  @$pb.TagNumber(3)
  set isAvailable($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasIsAvailable() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsAvailable() => clearField(3);
}

/// 聊天訊息 (EventType.CHAT_MESSAGE)
class ChatMessageData extends $pb.GeneratedMessage {
  factory ChatMessageData({
    $core.String? roomId,
    $core.String? roomType,
    $core.String? content,
    $core.String? replyTo,
  }) {
    final $result = create();
    if (roomId != null) {
      $result.roomId = roomId;
    }
    if (roomType != null) {
      $result.roomType = roomType;
    }
    if (content != null) {
      $result.content = content;
    }
    if (replyTo != null) {
      $result.replyTo = replyTo;
    }
    return $result;
  }
  ChatMessageData._() : super();
  factory ChatMessageData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ChatMessageData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ChatMessageData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'roomType')
    ..aOS(3, _omitFieldNames ? '' : 'content')
    ..aOS(4, _omitFieldNames ? '' : 'replyTo')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ChatMessageData clone() => ChatMessageData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ChatMessageData copyWith(void Function(ChatMessageData) updates) => super.copyWith((message) => updates(message as ChatMessageData)) as ChatMessageData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChatMessageData create() => ChatMessageData._();
  ChatMessageData createEmptyInstance() => create();
  static $pb.PbList<ChatMessageData> createRepeated() => $pb.PbList<ChatMessageData>();
  @$core.pragma('dart2js:noInline')
  static ChatMessageData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ChatMessageData>(create);
  static ChatMessageData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get roomType => $_getSZ(1);
  @$pb.TagNumber(2)
  set roomType($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasRoomType() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoomType() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get content => $_getSZ(2);
  @$pb.TagNumber(3)
  set content($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasContent() => $_has(2);
  @$pb.TagNumber(3)
  void clearContent() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get replyTo => $_getSZ(3);
  @$pb.TagNumber(4)
  set replyTo($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasReplyTo() => $_has(3);
  @$pb.TagNumber(4)
  void clearReplyTo() => clearField(4);
}

/// 媒合中位置同步 (EventType.LOCATION_UPDATE)
class LocationUpdateData extends $pb.GeneratedMessage {
  factory LocationUpdateData({
    $core.String? sessionId,
    $core.double? lat,
    $core.double? lng,
    $fixnum.Int64? timestamp,
  }) {
    final $result = create();
    if (sessionId != null) {
      $result.sessionId = sessionId;
    }
    if (lat != null) {
      $result.lat = lat;
    }
    if (lng != null) {
      $result.lng = lng;
    }
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    return $result;
  }
  LocationUpdateData._() : super();
  factory LocationUpdateData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LocationUpdateData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LocationUpdateData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..a<$core.double>(2, _omitFieldNames ? '' : 'lat', $pb.PbFieldType.OD)
    ..a<$core.double>(3, _omitFieldNames ? '' : 'lng', $pb.PbFieldType.OD)
    ..aInt64(4, _omitFieldNames ? '' : 'timestamp')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LocationUpdateData clone() => LocationUpdateData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LocationUpdateData copyWith(void Function(LocationUpdateData) updates) => super.copyWith((message) => updates(message as LocationUpdateData)) as LocationUpdateData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LocationUpdateData create() => LocationUpdateData._();
  LocationUpdateData createEmptyInstance() => create();
  static $pb.PbList<LocationUpdateData> createRepeated() => $pb.PbList<LocationUpdateData>();
  @$core.pragma('dart2js:noInline')
  static LocationUpdateData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LocationUpdateData>(create);
  static LocationUpdateData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => clearField(1);

  @$pb.TagNumber(2)
  $core.double get lat => $_getN(1);
  @$pb.TagNumber(2)
  set lat($core.double v) { $_setDouble(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasLat() => $_has(1);
  @$pb.TagNumber(2)
  void clearLat() => clearField(2);

  @$pb.TagNumber(3)
  $core.double get lng => $_getN(2);
  @$pb.TagNumber(3)
  set lng($core.double v) { $_setDouble(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasLng() => $_has(2);
  @$pb.TagNumber(3)
  void clearLng() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get timestamp => $_getI64(3);
  @$pb.TagNumber(4)
  set timestamp($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasTimestamp() => $_has(3);
  @$pb.TagNumber(4)
  void clearTimestamp() => clearField(4);
}

/// 聊天室設定
class ChatRoomConfig extends $pb.GeneratedMessage {
  factory ChatRoomConfig({
    $core.String? roomId,
    $core.String? roomName,
    $core.String? roomType,
    $core.int? rateLimitSeconds,
    $core.bool? adminOnly,
    $core.String? joinTokenHash,
    $core.Iterable<$core.List<$core.int>>? adminPubKeys,
  }) {
    final $result = create();
    if (roomId != null) {
      $result.roomId = roomId;
    }
    if (roomName != null) {
      $result.roomName = roomName;
    }
    if (roomType != null) {
      $result.roomType = roomType;
    }
    if (rateLimitSeconds != null) {
      $result.rateLimitSeconds = rateLimitSeconds;
    }
    if (adminOnly != null) {
      $result.adminOnly = adminOnly;
    }
    if (joinTokenHash != null) {
      $result.joinTokenHash = joinTokenHash;
    }
    if (adminPubKeys != null) {
      $result.adminPubKeys.addAll(adminPubKeys);
    }
    return $result;
  }
  ChatRoomConfig._() : super();
  factory ChatRoomConfig.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ChatRoomConfig.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ChatRoomConfig', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'roomName')
    ..aOS(3, _omitFieldNames ? '' : 'roomType')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'rateLimitSeconds', $pb.PbFieldType.O3)
    ..aOB(5, _omitFieldNames ? '' : 'adminOnly')
    ..aOS(6, _omitFieldNames ? '' : 'joinTokenHash')
    ..p<$core.List<$core.int>>(7, _omitFieldNames ? '' : 'adminPubKeys', $pb.PbFieldType.PY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ChatRoomConfig clone() => ChatRoomConfig()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ChatRoomConfig copyWith(void Function(ChatRoomConfig) updates) => super.copyWith((message) => updates(message as ChatRoomConfig)) as ChatRoomConfig;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChatRoomConfig create() => ChatRoomConfig._();
  ChatRoomConfig createEmptyInstance() => create();
  static $pb.PbList<ChatRoomConfig> createRepeated() => $pb.PbList<ChatRoomConfig>();
  @$core.pragma('dart2js:noInline')
  static ChatRoomConfig getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ChatRoomConfig>(create);
  static ChatRoomConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get roomName => $_getSZ(1);
  @$pb.TagNumber(2)
  set roomName($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasRoomName() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoomName() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get roomType => $_getSZ(2);
  @$pb.TagNumber(3)
  set roomType($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasRoomType() => $_has(2);
  @$pb.TagNumber(3)
  void clearRoomType() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get rateLimitSeconds => $_getIZ(3);
  @$pb.TagNumber(4)
  set rateLimitSeconds($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasRateLimitSeconds() => $_has(3);
  @$pb.TagNumber(4)
  void clearRateLimitSeconds() => clearField(4);

  @$pb.TagNumber(5)
  $core.bool get adminOnly => $_getBF(4);
  @$pb.TagNumber(5)
  set adminOnly($core.bool v) { $_setBool(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasAdminOnly() => $_has(4);
  @$pb.TagNumber(5)
  void clearAdminOnly() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get joinTokenHash => $_getSZ(5);
  @$pb.TagNumber(6)
  set joinTokenHash($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasJoinTokenHash() => $_has(5);
  @$pb.TagNumber(6)
  void clearJoinTokenHash() => clearField(6);

  @$pb.TagNumber(7)
  $core.List<$core.List<$core.int>> get adminPubKeys => $_getList(6);
}

/// 媒合出價 — Provider 發起，帶有 negotiation_id 追蹤協商狀態
class MatchOfferData extends $pb.GeneratedMessage {
  factory MatchOfferData({
    $core.String? negotiationId,
    $core.String? resourceId,
    $core.String? requestId,
    $core.List<$core.int>? providerPubKey,
    $core.List<$core.int>? requesterPubKey,
    $core.double? offeredQty,
    $core.double? matchScore,
    $fixnum.Int64? expiresAt,
  }) {
    final $result = create();
    if (negotiationId != null) {
      $result.negotiationId = negotiationId;
    }
    if (resourceId != null) {
      $result.resourceId = resourceId;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (providerPubKey != null) {
      $result.providerPubKey = providerPubKey;
    }
    if (requesterPubKey != null) {
      $result.requesterPubKey = requesterPubKey;
    }
    if (offeredQty != null) {
      $result.offeredQty = offeredQty;
    }
    if (matchScore != null) {
      $result.matchScore = matchScore;
    }
    if (expiresAt != null) {
      $result.expiresAt = expiresAt;
    }
    return $result;
  }
  MatchOfferData._() : super();
  factory MatchOfferData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MatchOfferData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MatchOfferData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'negotiationId')
    ..aOS(2, _omitFieldNames ? '' : 'resourceId')
    ..aOS(3, _omitFieldNames ? '' : 'requestId')
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'providerPubKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(5, _omitFieldNames ? '' : 'requesterPubKey', $pb.PbFieldType.OY)
    ..a<$core.double>(6, _omitFieldNames ? '' : 'offeredQty', $pb.PbFieldType.OF)
    ..a<$core.double>(7, _omitFieldNames ? '' : 'matchScore', $pb.PbFieldType.OF)
    ..aInt64(8, _omitFieldNames ? '' : 'expiresAt')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MatchOfferData clone() => MatchOfferData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MatchOfferData copyWith(void Function(MatchOfferData) updates) => super.copyWith((message) => updates(message as MatchOfferData)) as MatchOfferData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MatchOfferData create() => MatchOfferData._();
  MatchOfferData createEmptyInstance() => create();
  static $pb.PbList<MatchOfferData> createRepeated() => $pb.PbList<MatchOfferData>();
  @$core.pragma('dart2js:noInline')
  static MatchOfferData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MatchOfferData>(create);
  static MatchOfferData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get negotiationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set negotiationId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasNegotiationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNegotiationId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasResourceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearResourceId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get requestId => $_getSZ(2);
  @$pb.TagNumber(3)
  set requestId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasRequestId() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequestId() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get providerPubKey => $_getN(3);
  @$pb.TagNumber(4)
  set providerPubKey($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasProviderPubKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearProviderPubKey() => clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get requesterPubKey => $_getN(4);
  @$pb.TagNumber(5)
  set requesterPubKey($core.List<$core.int> v) { $_setBytes(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasRequesterPubKey() => $_has(4);
  @$pb.TagNumber(5)
  void clearRequesterPubKey() => clearField(5);

  @$pb.TagNumber(6)
  $core.double get offeredQty => $_getN(5);
  @$pb.TagNumber(6)
  set offeredQty($core.double v) { $_setFloat(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasOfferedQty() => $_has(5);
  @$pb.TagNumber(6)
  void clearOfferedQty() => clearField(6);

  @$pb.TagNumber(7)
  $core.double get matchScore => $_getN(6);
  @$pb.TagNumber(7)
  set matchScore($core.double v) { $_setFloat(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasMatchScore() => $_has(6);
  @$pb.TagNumber(7)
  void clearMatchScore() => clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get expiresAt => $_getI64(7);
  @$pb.TagNumber(8)
  set expiresAt($fixnum.Int64 v) { $_setInt64(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasExpiresAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearExpiresAt() => clearField(8);
}

/// 媒合請求 — Requester 發起，帶有 negotiation_id
class MatchRequestData extends $pb.GeneratedMessage {
  factory MatchRequestData({
    $core.String? negotiationId,
    $core.String? resourceId,
    $core.String? requestId,
    $core.List<$core.int>? providerPubKey,
    $core.List<$core.int>? requesterPubKey,
    $core.double? requestedQty,
    $fixnum.Int64? expiresAt,
  }) {
    final $result = create();
    if (negotiationId != null) {
      $result.negotiationId = negotiationId;
    }
    if (resourceId != null) {
      $result.resourceId = resourceId;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (providerPubKey != null) {
      $result.providerPubKey = providerPubKey;
    }
    if (requesterPubKey != null) {
      $result.requesterPubKey = requesterPubKey;
    }
    if (requestedQty != null) {
      $result.requestedQty = requestedQty;
    }
    if (expiresAt != null) {
      $result.expiresAt = expiresAt;
    }
    return $result;
  }
  MatchRequestData._() : super();
  factory MatchRequestData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MatchRequestData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MatchRequestData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'negotiationId')
    ..aOS(2, _omitFieldNames ? '' : 'resourceId')
    ..aOS(3, _omitFieldNames ? '' : 'requestId')
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'providerPubKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(5, _omitFieldNames ? '' : 'requesterPubKey', $pb.PbFieldType.OY)
    ..a<$core.double>(6, _omitFieldNames ? '' : 'requestedQty', $pb.PbFieldType.OF)
    ..aInt64(7, _omitFieldNames ? '' : 'expiresAt')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MatchRequestData clone() => MatchRequestData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MatchRequestData copyWith(void Function(MatchRequestData) updates) => super.copyWith((message) => updates(message as MatchRequestData)) as MatchRequestData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MatchRequestData create() => MatchRequestData._();
  MatchRequestData createEmptyInstance() => create();
  static $pb.PbList<MatchRequestData> createRepeated() => $pb.PbList<MatchRequestData>();
  @$core.pragma('dart2js:noInline')
  static MatchRequestData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MatchRequestData>(create);
  static MatchRequestData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get negotiationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set negotiationId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasNegotiationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNegotiationId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasResourceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearResourceId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get requestId => $_getSZ(2);
  @$pb.TagNumber(3)
  set requestId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasRequestId() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequestId() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get providerPubKey => $_getN(3);
  @$pb.TagNumber(4)
  set providerPubKey($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasProviderPubKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearProviderPubKey() => clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get requesterPubKey => $_getN(4);
  @$pb.TagNumber(5)
  set requesterPubKey($core.List<$core.int> v) { $_setBytes(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasRequesterPubKey() => $_has(4);
  @$pb.TagNumber(5)
  void clearRequesterPubKey() => clearField(5);

  @$pb.TagNumber(6)
  $core.double get requestedQty => $_getN(5);
  @$pb.TagNumber(6)
  set requestedQty($core.double v) { $_setFloat(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasRequestedQty() => $_has(5);
  @$pb.TagNumber(6)
  void clearRequestedQty() => clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get expiresAt => $_getI64(6);
  @$pb.TagNumber(7)
  set expiresAt($fixnum.Int64 v) { $_setInt64(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasExpiresAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearExpiresAt() => clearField(7);
}

/// 媒合接受 — 任一方接受出價/請求
class MatchAcceptData extends $pb.GeneratedMessage {
  factory MatchAcceptData({
    $core.String? negotiationId,
    $core.String? resourceId,
    $core.String? requestId,
    $core.List<$core.int>? acceptorPubKey,
    $core.double? agreedQty,
  }) {
    final $result = create();
    if (negotiationId != null) {
      $result.negotiationId = negotiationId;
    }
    if (resourceId != null) {
      $result.resourceId = resourceId;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (acceptorPubKey != null) {
      $result.acceptorPubKey = acceptorPubKey;
    }
    if (agreedQty != null) {
      $result.agreedQty = agreedQty;
    }
    return $result;
  }
  MatchAcceptData._() : super();
  factory MatchAcceptData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MatchAcceptData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MatchAcceptData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'negotiationId')
    ..aOS(2, _omitFieldNames ? '' : 'resourceId')
    ..aOS(3, _omitFieldNames ? '' : 'requestId')
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'acceptorPubKey', $pb.PbFieldType.OY)
    ..a<$core.double>(5, _omitFieldNames ? '' : 'agreedQty', $pb.PbFieldType.OF)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MatchAcceptData clone() => MatchAcceptData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MatchAcceptData copyWith(void Function(MatchAcceptData) updates) => super.copyWith((message) => updates(message as MatchAcceptData)) as MatchAcceptData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MatchAcceptData create() => MatchAcceptData._();
  MatchAcceptData createEmptyInstance() => create();
  static $pb.PbList<MatchAcceptData> createRepeated() => $pb.PbList<MatchAcceptData>();
  @$core.pragma('dart2js:noInline')
  static MatchAcceptData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MatchAcceptData>(create);
  static MatchAcceptData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get negotiationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set negotiationId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasNegotiationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNegotiationId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasResourceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearResourceId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get requestId => $_getSZ(2);
  @$pb.TagNumber(3)
  set requestId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasRequestId() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequestId() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get acceptorPubKey => $_getN(3);
  @$pb.TagNumber(4)
  set acceptorPubKey($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasAcceptorPubKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearAcceptorPubKey() => clearField(4);

  @$pb.TagNumber(5)
  $core.double get agreedQty => $_getN(4);
  @$pb.TagNumber(5)
  set agreedQty($core.double v) { $_setFloat(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasAgreedQty() => $_has(4);
  @$pb.TagNumber(5)
  void clearAgreedQty() => clearField(5);
}

/// 媒合拒絕（協商層）— 區別於 MatchRejectData（廣播層）
class MatchDeclineData extends $pb.GeneratedMessage {
  factory MatchDeclineData({
    $core.String? negotiationId,
    $core.String? resourceId,
    $core.String? requestId,
    $core.String? reason,
  }) {
    final $result = create();
    if (negotiationId != null) {
      $result.negotiationId = negotiationId;
    }
    if (resourceId != null) {
      $result.resourceId = resourceId;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (reason != null) {
      $result.reason = reason;
    }
    return $result;
  }
  MatchDeclineData._() : super();
  factory MatchDeclineData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MatchDeclineData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MatchDeclineData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'negotiationId')
    ..aOS(2, _omitFieldNames ? '' : 'resourceId')
    ..aOS(3, _omitFieldNames ? '' : 'requestId')
    ..aOS(4, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MatchDeclineData clone() => MatchDeclineData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MatchDeclineData copyWith(void Function(MatchDeclineData) updates) => super.copyWith((message) => updates(message as MatchDeclineData)) as MatchDeclineData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MatchDeclineData create() => MatchDeclineData._();
  MatchDeclineData createEmptyInstance() => create();
  static $pb.PbList<MatchDeclineData> createRepeated() => $pb.PbList<MatchDeclineData>();
  @$core.pragma('dart2js:noInline')
  static MatchDeclineData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MatchDeclineData>(create);
  static MatchDeclineData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get negotiationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set negotiationId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasNegotiationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNegotiationId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasResourceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearResourceId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get requestId => $_getSZ(2);
  @$pb.TagNumber(3)
  set requestId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasRequestId() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequestId() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get reason => $_getSZ(3);
  @$pb.TagNumber(4)
  set reason($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasReason() => $_has(3);
  @$pb.TagNumber(4)
  void clearReason() => clearField(4);
}

/// 據點領取請求
class StationClaimData extends $pb.GeneratedMessage {
  factory StationClaimData({
    $core.String? resourceId,
    $core.String? requestId,
    $core.List<$core.int>? requesterPubKey,
    $core.String? category,
    $core.double? requestedQty,
  }) {
    final $result = create();
    if (resourceId != null) {
      $result.resourceId = resourceId;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (requesterPubKey != null) {
      $result.requesterPubKey = requesterPubKey;
    }
    if (category != null) {
      $result.category = category;
    }
    if (requestedQty != null) {
      $result.requestedQty = requestedQty;
    }
    return $result;
  }
  StationClaimData._() : super();
  factory StationClaimData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory StationClaimData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'StationClaimData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'resourceId')
    ..aOS(2, _omitFieldNames ? '' : 'requestId')
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'requesterPubKey', $pb.PbFieldType.OY)
    ..aOS(4, _omitFieldNames ? '' : 'category')
    ..a<$core.double>(5, _omitFieldNames ? '' : 'requestedQty', $pb.PbFieldType.OF)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  StationClaimData clone() => StationClaimData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  StationClaimData copyWith(void Function(StationClaimData) updates) => super.copyWith((message) => updates(message as StationClaimData)) as StationClaimData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StationClaimData create() => StationClaimData._();
  StationClaimData createEmptyInstance() => create();
  static $pb.PbList<StationClaimData> createRepeated() => $pb.PbList<StationClaimData>();
  @$core.pragma('dart2js:noInline')
  static StationClaimData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StationClaimData>(create);
  static StationClaimData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get resourceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set resourceId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasResourceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearResourceId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRequestId() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get requesterPubKey => $_getN(2);
  @$pb.TagNumber(3)
  set requesterPubKey($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasRequesterPubKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequesterPubKey() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get category => $_getSZ(3);
  @$pb.TagNumber(4)
  set category($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasCategory() => $_has(3);
  @$pb.TagNumber(4)
  void clearCategory() => clearField(4);

  @$pb.TagNumber(5)
  $core.double get requestedQty => $_getN(4);
  @$pb.TagNumber(5)
  set requestedQty($core.double v) { $_setFloat(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasRequestedQty() => $_has(4);
  @$pb.TagNumber(5)
  void clearRequestedQty() => clearField(5);
}

/// 據點領取回應
class StationResponseData extends $pb.GeneratedMessage {
  factory StationResponseData({
    $core.String? resourceId,
    $core.String? requestId,
    $core.List<$core.int>? requesterPubKey,
    $core.bool? approved,
    $core.double? approvedQty,
    $core.String? denyReason,
    $fixnum.Int64? pickupDeadline,
  }) {
    final $result = create();
    if (resourceId != null) {
      $result.resourceId = resourceId;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (requesterPubKey != null) {
      $result.requesterPubKey = requesterPubKey;
    }
    if (approved != null) {
      $result.approved = approved;
    }
    if (approvedQty != null) {
      $result.approvedQty = approvedQty;
    }
    if (denyReason != null) {
      $result.denyReason = denyReason;
    }
    if (pickupDeadline != null) {
      $result.pickupDeadline = pickupDeadline;
    }
    return $result;
  }
  StationResponseData._() : super();
  factory StationResponseData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory StationResponseData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'StationResponseData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'resourceId')
    ..aOS(2, _omitFieldNames ? '' : 'requestId')
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'requesterPubKey', $pb.PbFieldType.OY)
    ..aOB(4, _omitFieldNames ? '' : 'approved')
    ..a<$core.double>(5, _omitFieldNames ? '' : 'approvedQty', $pb.PbFieldType.OF)
    ..aOS(6, _omitFieldNames ? '' : 'denyReason')
    ..aInt64(7, _omitFieldNames ? '' : 'pickupDeadline')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  StationResponseData clone() => StationResponseData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  StationResponseData copyWith(void Function(StationResponseData) updates) => super.copyWith((message) => updates(message as StationResponseData)) as StationResponseData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StationResponseData create() => StationResponseData._();
  StationResponseData createEmptyInstance() => create();
  static $pb.PbList<StationResponseData> createRepeated() => $pb.PbList<StationResponseData>();
  @$core.pragma('dart2js:noInline')
  static StationResponseData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StationResponseData>(create);
  static StationResponseData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get resourceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set resourceId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasResourceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearResourceId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRequestId() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get requesterPubKey => $_getN(2);
  @$pb.TagNumber(3)
  set requesterPubKey($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasRequesterPubKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequesterPubKey() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get approved => $_getBF(3);
  @$pb.TagNumber(4)
  set approved($core.bool v) { $_setBool(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasApproved() => $_has(3);
  @$pb.TagNumber(4)
  void clearApproved() => clearField(4);

  @$pb.TagNumber(5)
  $core.double get approvedQty => $_getN(4);
  @$pb.TagNumber(5)
  set approvedQty($core.double v) { $_setFloat(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasApprovedQty() => $_has(4);
  @$pb.TagNumber(5)
  void clearApprovedQty() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get denyReason => $_getSZ(5);
  @$pb.TagNumber(6)
  set denyReason($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasDenyReason() => $_has(5);
  @$pb.TagNumber(6)
  void clearDenyReason() => clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get pickupDeadline => $_getI64(6);
  @$pb.TagNumber(7)
  set pickupDeadline($fixnum.Int64 v) { $_setInt64(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasPickupDeadline() => $_has(6);
  @$pb.TagNumber(7)
  void clearPickupDeadline() => clearField(7);
}

/// MeshEnvelope — BLE Mesh 廣播頂層封包
/// 所有透過 BLE Transport 傳送的資料都先包裝為此格式，
/// 接收端根據 type 決定是進行 Bloom Filter 比對還是事件處理。
class MeshEnvelope extends $pb.GeneratedMessage {
  factory MeshEnvelope({
    EnvelopeType? type,
    $core.List<$core.int>? payload,
    $core.String? senderId,
  }) {
    final $result = create();
    if (type != null) {
      $result.type = type;
    }
    if (payload != null) {
      $result.payload = payload;
    }
    if (senderId != null) {
      $result.senderId = senderId;
    }
    return $result;
  }
  MeshEnvelope._() : super();
  factory MeshEnvelope.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MeshEnvelope.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MeshEnvelope', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..e<EnvelopeType>(1, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE, defaultOrMaker: EnvelopeType.ENVELOPE_EVENT, valueOf: EnvelopeType.valueOf, enumValues: EnvelopeType.values)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'senderId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MeshEnvelope clone() => MeshEnvelope()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MeshEnvelope copyWith(void Function(MeshEnvelope) updates) => super.copyWith((message) => updates(message as MeshEnvelope)) as MeshEnvelope;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MeshEnvelope create() => MeshEnvelope._();
  MeshEnvelope createEmptyInstance() => create();
  static $pb.PbList<MeshEnvelope> createRepeated() => $pb.PbList<MeshEnvelope>();
  @$core.pragma('dart2js:noInline')
  static MeshEnvelope getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MeshEnvelope>(create);
  static MeshEnvelope? _defaultInstance;

  @$pb.TagNumber(1)
  EnvelopeType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(EnvelopeType v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get payload => $_getN(1);
  @$pb.TagNumber(2)
  set payload($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPayload() => $_has(1);
  @$pb.TagNumber(2)
  void clearPayload() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get senderId => $_getSZ(2);
  @$pb.TagNumber(3)
  set senderId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSenderId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSenderId() => clearField(3);
}

/// ─────────────────────────────────────────────────────────────────────────────
/// HandshakeCompleteData (交割完成憑證)
/// ─────────────────────────────────────────────────────────────────────────────
class HandshakeCompleteData extends $pb.GeneratedMessage {
  factory HandshakeCompleteData({
    $core.String? negotiationId,
    $core.String? resourceId,
    $core.String? requestId,
    $core.List<$core.int>? providerPubKey,
    $core.List<$core.int>? requesterPubKey,
    $core.double? actualDeliveredQty,
    $core.String? method,
    $core.List<$core.int>? providerSignature,
    $core.List<$core.int>? requesterSignature,
    $core.int? schemaVersion,
  }) {
    final $result = create();
    if (negotiationId != null) {
      $result.negotiationId = negotiationId;
    }
    if (resourceId != null) {
      $result.resourceId = resourceId;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (providerPubKey != null) {
      $result.providerPubKey = providerPubKey;
    }
    if (requesterPubKey != null) {
      $result.requesterPubKey = requesterPubKey;
    }
    if (actualDeliveredQty != null) {
      $result.actualDeliveredQty = actualDeliveredQty;
    }
    if (method != null) {
      $result.method = method;
    }
    if (providerSignature != null) {
      $result.providerSignature = providerSignature;
    }
    if (requesterSignature != null) {
      $result.requesterSignature = requesterSignature;
    }
    if (schemaVersion != null) {
      $result.schemaVersion = schemaVersion;
    }
    return $result;
  }
  HandshakeCompleteData._() : super();
  factory HandshakeCompleteData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory HandshakeCompleteData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'HandshakeCompleteData', package: const $pb.PackageName(_omitMessageNames ? '' : 'resqmesh'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'negotiationId')
    ..aOS(2, _omitFieldNames ? '' : 'resourceId')
    ..aOS(3, _omitFieldNames ? '' : 'requestId')
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'providerPubKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(5, _omitFieldNames ? '' : 'requesterPubKey', $pb.PbFieldType.OY)
    ..a<$core.double>(6, _omitFieldNames ? '' : 'actualDeliveredQty', $pb.PbFieldType.OF)
    ..aOS(7, _omitFieldNames ? '' : 'method')
    ..a<$core.List<$core.int>>(8, _omitFieldNames ? '' : 'providerSignature', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(9, _omitFieldNames ? '' : 'requesterSignature', $pb.PbFieldType.OY)
    ..a<$core.int>(10, _omitFieldNames ? '' : 'schemaVersion', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  HandshakeCompleteData clone() => HandshakeCompleteData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  HandshakeCompleteData copyWith(void Function(HandshakeCompleteData) updates) => super.copyWith((message) => updates(message as HandshakeCompleteData)) as HandshakeCompleteData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HandshakeCompleteData create() => HandshakeCompleteData._();
  HandshakeCompleteData createEmptyInstance() => create();
  static $pb.PbList<HandshakeCompleteData> createRepeated() => $pb.PbList<HandshakeCompleteData>();
  @$core.pragma('dart2js:noInline')
  static HandshakeCompleteData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<HandshakeCompleteData>(create);
  static HandshakeCompleteData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get negotiationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set negotiationId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasNegotiationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNegotiationId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasResourceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearResourceId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get requestId => $_getSZ(2);
  @$pb.TagNumber(3)
  set requestId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasRequestId() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequestId() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get providerPubKey => $_getN(3);
  @$pb.TagNumber(4)
  set providerPubKey($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasProviderPubKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearProviderPubKey() => clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get requesterPubKey => $_getN(4);
  @$pb.TagNumber(5)
  set requesterPubKey($core.List<$core.int> v) { $_setBytes(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasRequesterPubKey() => $_has(4);
  @$pb.TagNumber(5)
  void clearRequesterPubKey() => clearField(5);

  @$pb.TagNumber(6)
  $core.double get actualDeliveredQty => $_getN(5);
  @$pb.TagNumber(6)
  set actualDeliveredQty($core.double v) { $_setFloat(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasActualDeliveredQty() => $_has(5);
  @$pb.TagNumber(6)
  void clearActualDeliveredQty() => clearField(6);

  @$pb.TagNumber(7)
  $core.String get method => $_getSZ(6);
  @$pb.TagNumber(7)
  set method($core.String v) { $_setString(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasMethod() => $_has(6);
  @$pb.TagNumber(7)
  void clearMethod() => clearField(7);

  @$pb.TagNumber(8)
  $core.List<$core.int> get providerSignature => $_getN(7);
  @$pb.TagNumber(8)
  set providerSignature($core.List<$core.int> v) { $_setBytes(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasProviderSignature() => $_has(7);
  @$pb.TagNumber(8)
  void clearProviderSignature() => clearField(8);

  @$pb.TagNumber(9)
  $core.List<$core.int> get requesterSignature => $_getN(8);
  @$pb.TagNumber(9)
  set requesterSignature($core.List<$core.int> v) { $_setBytes(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasRequesterSignature() => $_has(8);
  @$pb.TagNumber(9)
  void clearRequesterSignature() => clearField(9);

  /// Stage 6 (commit #10)：wire-format 版本。
  /// 預設 0 = 未升級之舊 client；新 client 寫入 1。
  /// optional：使接收端可用 hasSchemaVersion() 區分「未帶此欄位的舊 payload」。
  @$pb.TagNumber(10)
  $core.int get schemaVersion => $_getIZ(9);
  @$pb.TagNumber(10)
  set schemaVersion($core.int v) { $_setSignedInt32(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasSchemaVersion() => $_has(9);
  @$pb.TagNumber(10)
  void clearSchemaVersion() => clearField(10);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
