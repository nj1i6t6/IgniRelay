// Generated from protos/mesh_protocol.proto — DO NOT EDIT
// ignore_for_file: non_constant_identifier_names, camel_case_types, unnecessary_this
// ignore_for_file: annotate_overrides, prefer_single_quotes, always_specify_types
// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:core' as $core;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:fixnum/fixnum.dart' as $fixnum;

import 'mesh_protocol.pbenum.dart';

export 'mesh_protocol.pbenum.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MeshEvent (核心事件結構)
// ─────────────────────────────────────────────────────────────────────────────

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
    if (eventId != null) $result.eventId = eventId;
    if (senderPubKey != null) $result.senderPubKey = senderPubKey;
    if (identityLevel != null) $result.identityLevel = identityLevel;
    if (type != null) $result.type = type;
    if (urgency != null) $result.urgency = urgency;
    if (hlcTimestamp != null) $result.hlcTimestamp = hlcTimestamp;
    if (hlcCounter != null) $result.hlcCounter = hlcCounter;
    if (ttl != null) $result.ttl = ttl;
    if (chunkIndex != null) $result.chunkIndex = chunkIndex;
    if (totalChunks != null) $result.totalChunks = totalChunks;
    if (payload != null) $result.payload = payload;
    if (signature != null) $result.signature = signature;
    if (receivedLat != null) $result.receivedLat = receivedLat;
    if (receivedLng != null) $result.receivedLng = receivedLng;
    if (originLat != null) $result.originLat = originLat;
    if (originLng != null) $result.originLng = originLng;
    return $result;
  }

  MeshEvent._() : super();

  factory MeshEvent.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  factory MeshEvent.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('MeshEvent',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'eventId', protoName: 'event_id')
    ..a<$core.List<$core.int>>(2, 'senderPubKey', $pb.PbFieldType.OY,
        protoName: 'sender_pub_key')
    ..a<$core.int>(3, 'identityLevel', $pb.PbFieldType.OU3,
        protoName: 'identity_level')
    ..e<EventType>(4, 'type', $pb.PbFieldType.OE,
        defaultOrMaker: EventType.RESOURCE_REGISTER,
        valueOf: EventType.valueOf,
        enumValues: EventType.values)
    ..e<UrgencyLevel>(5, 'urgency', $pb.PbFieldType.OE,
        defaultOrMaker: UrgencyLevel.INFO,
        valueOf: UrgencyLevel.valueOf,
        enumValues: UrgencyLevel.values)
    ..aInt64(6, 'hlcTimestamp', protoName: 'hlc_timestamp')
    ..aInt64(7, 'hlcCounter', protoName: 'hlc_counter')
    ..a<$core.int>(8, 'ttl', $pb.PbFieldType.O3)
    ..a<$core.int>(9, 'chunkIndex', $pb.PbFieldType.O3,
        protoName: 'chunk_index')
    ..a<$core.int>(10, 'totalChunks', $pb.PbFieldType.O3,
        protoName: 'total_chunks')
    ..a<$core.List<$core.int>>(11, 'payload', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(12, 'signature', $pb.PbFieldType.OY)
    ..a<$core.double>(13, 'receivedLat', $pb.PbFieldType.OD,
        protoName: 'received_lat')
    ..a<$core.double>(14, 'receivedLng', $pb.PbFieldType.OD,
        protoName: 'received_lng')
    ..a<$core.double>(15, 'originLat', $pb.PbFieldType.OD,
        protoName: 'origin_lat')
    ..a<$core.double>(16, 'originLng', $pb.PbFieldType.OD,
        protoName: 'origin_lng')
    ..hasRequiredFields = false;

  @$core.override
  MeshEvent createEmptyInstance() => create();
  static MeshEvent create() => MeshEvent._();
  @$core.override
  MeshEvent clone() => MeshEvent()..mergeFromMessage(this);
  static $pb.PbList<MeshEvent> createRepeated() => $pb.PbList<MeshEvent>();
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  // ── field accessors ──

  @$pb.TagNumber(1)
  $core.String get eventId => $_getSZ(0);
  @$pb.TagNumber(1)
  set eventId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.List<$core.int> get senderPubKey => $_getN(1);
  @$pb.TagNumber(2)
  set senderPubKey($core.List<$core.int> v) {
    $_setBytes(1, v);
  }

  @$pb.TagNumber(3)
  $core.int get identityLevel => $_getIZ(2);
  @$pb.TagNumber(3)
  set identityLevel($core.int v) {
    $_setUnsignedInt32(2, v);
  }

  @$pb.TagNumber(4)
  EventType get type => $_getN(3);
  @$pb.TagNumber(4)
  set type(EventType v) {
    setField(4, v);
  }

  @$pb.TagNumber(5)
  UrgencyLevel get urgency => $_getN(4);
  @$pb.TagNumber(5)
  set urgency(UrgencyLevel v) {
    setField(5, v);
  }

  @$pb.TagNumber(6)
  $fixnum.Int64 get hlcTimestamp => $_getI64(5);
  @$pb.TagNumber(6)
  set hlcTimestamp($fixnum.Int64 v) {
    $_setInt64(5, v);
  }

  @$pb.TagNumber(7)
  $fixnum.Int64 get hlcCounter => $_getI64(6);
  @$pb.TagNumber(7)
  set hlcCounter($fixnum.Int64 v) {
    $_setInt64(6, v);
  }

  @$pb.TagNumber(8)
  $core.int get ttl => $_getIZ(7);
  @$pb.TagNumber(8)
  set ttl($core.int v) {
    $_setSignedInt32(7, v);
  }

  @$pb.TagNumber(9)
  $core.int get chunkIndex => $_getIZ(8);
  @$pb.TagNumber(9)
  set chunkIndex($core.int v) {
    $_setSignedInt32(8, v);
  }

  @$pb.TagNumber(10)
  $core.int get totalChunks => $_getIZ(9);
  @$pb.TagNumber(10)
  set totalChunks($core.int v) {
    $_setSignedInt32(9, v);
  }

  @$pb.TagNumber(11)
  $core.List<$core.int> get payload => $_getN(10);
  @$pb.TagNumber(11)
  set payload($core.List<$core.int> v) {
    $_setBytes(10, v);
  }

  @$pb.TagNumber(12)
  $core.List<$core.int> get signature => $_getN(11);
  @$pb.TagNumber(12)
  set signature($core.List<$core.int> v) {
    $_setBytes(11, v);
  }

  @$pb.TagNumber(13)
  $core.double get receivedLat => $_getN(12);
  @$pb.TagNumber(13)
  set receivedLat($core.double v) {
    $_setDouble(12, v);
  }

  @$pb.TagNumber(14)
  $core.double get receivedLng => $_getN(13);
  @$pb.TagNumber(14)
  set receivedLng($core.double v) {
    $_setDouble(13, v);
  }

  @$pb.TagNumber(15)
  $core.double get originLat => $_getN(14);
  @$pb.TagNumber(15)
  set originLat($core.double v) {
    $_setDouble(14, v);
  }

  @$pb.TagNumber(16)
  $core.double get originLng => $_getN(15);
  @$pb.TagNumber(16)
  set originLng($core.double v) {
    $_setDouble(15, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BloomFilterSync
// ─────────────────────────────────────────────────────────────────────────────

class BloomFilterSync extends $pb.GeneratedMessage {
  factory BloomFilterSync({
    $core.List<$core.int>? filterData,
    $core.int? numHashFuncs,
    $core.int? capacity,
  }) {
    final $result = create();
    if (filterData != null) $result.filterData = filterData;
    if (numHashFuncs != null) $result.numHashFuncs = numHashFuncs;
    if (capacity != null) $result.capacity = capacity;
    return $result;
  }

  BloomFilterSync._() : super();

  factory BloomFilterSync.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('BloomFilterSync',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, 'filterData', $pb.PbFieldType.OY,
        protoName: 'filter_data')
    ..a<$core.int>(2, 'numHashFuncs', $pb.PbFieldType.O3,
        protoName: 'num_hash_funcs')
    ..a<$core.int>(3, 'capacity', $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  @$core.override
  BloomFilterSync createEmptyInstance() => create();
  static BloomFilterSync create() => BloomFilterSync._();
  @$core.override
  BloomFilterSync clone() => BloomFilterSync()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.List<$core.int> get filterData => $_getN(0);
  @$pb.TagNumber(1)
  set filterData($core.List<$core.int> v) {
    $_setBytes(0, v);
  }

  @$pb.TagNumber(2)
  $core.int get numHashFuncs => $_getIZ(1);
  @$pb.TagNumber(2)
  set numHashFuncs($core.int v) {
    $_setSignedInt32(1, v);
  }

  @$pb.TagNumber(3)
  $core.int get capacity => $_getIZ(2);
  @$pb.TagNumber(3)
  set capacity($core.int v) {
    $_setSignedInt32(2, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ResourceData (物資登記)
// ─────────────────────────────────────────────────────────────────────────────

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
    if (resourceId != null) $result.resourceId = resourceId;
    if (resourceType != null) $result.resourceType = resourceType;
    if (description != null) $result.description = description;
    if (quantity != null) $result.quantity = quantity;
    if (unit != null) $result.unit = unit;
    if (maxRangeMeters != null) $result.maxRangeMeters = maxRangeMeters;
    if (lat != null) $result.lat = lat;
    if (lng != null) $result.lng = lng;
    if (expiresAt != null) $result.expiresAt = expiresAt;
    if (deliveryMode != null) $result.deliveryMode = deliveryMode;
    return $result;
  }

  ResourceData._() : super();

  factory ResourceData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('ResourceData',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'resourceId', protoName: 'resource_id')
    ..aOS(2, 'resourceType', protoName: 'resource_type')
    ..aOS(3, 'description')
    ..a<$core.double>(4, 'quantity', $pb.PbFieldType.OF)
    ..aOS(5, 'unit')
    ..a<$core.double>(6, 'maxRangeMeters', $pb.PbFieldType.OF,
        protoName: 'max_range_meters')
    ..a<$core.double>(7, 'lat', $pb.PbFieldType.OD)
    ..a<$core.double>(8, 'lng', $pb.PbFieldType.OD)
    ..aInt64(9, 'expiresAt', protoName: 'expires_at')
    ..aOS(16, 'deliveryMode', protoName: 'delivery_mode')
    ..hasRequiredFields = false;

  @$core.override
  ResourceData createEmptyInstance() => create();
  static ResourceData create() => ResourceData._();
  @$core.override
  ResourceData clone() => ResourceData()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get resourceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set resourceId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.String get resourceType => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceType($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(4)
  $core.double get quantity => $_getN(3);
  @$pb.TagNumber(4)
  set quantity($core.double v) {
    $_setFloat(3, v);
  }

  @$pb.TagNumber(5)
  $core.String get unit => $_getSZ(4);
  @$pb.TagNumber(5)
  set unit($core.String v) {
    $_setString(4, v);
  }

  @$pb.TagNumber(6)
  $core.double get maxRangeMeters => $_getN(5);
  @$pb.TagNumber(6)
  set maxRangeMeters($core.double v) {
    $_setFloat(5, v);
  }

  @$pb.TagNumber(7)
  $core.double get lat => $_getN(6);
  @$pb.TagNumber(7)
  set lat($core.double v) {
    $_setDouble(6, v);
  }

  @$pb.TagNumber(8)
  $core.double get lng => $_getN(7);
  @$pb.TagNumber(8)
  set lng($core.double v) {
    $_setDouble(7, v);
  }

  @$pb.TagNumber(9)
  $fixnum.Int64 get expiresAt => $_getI64(8);
  @$pb.TagNumber(9)
  set expiresAt($fixnum.Int64 v) {
    $_setInt64(8, v);
  }

  @$pb.TagNumber(16)
  $core.String get deliveryMode => $_getSZ(9);
  @$pb.TagNumber(16)
  set deliveryMode($core.String v) {
    $_setString(9, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RequestData (需求廣播)
// ─────────────────────────────────────────────────────────────────────────────

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
    if (requestId != null) $result.requestId = requestId;
    if (resourceType != null) $result.resourceType = resourceType;
    if (description != null) $result.description = description;
    if (quantityNeeded != null) $result.quantityNeeded = quantityNeeded;
    if (urgency != null) $result.urgency = urgency;
    if (lat != null) $result.lat = lat;
    if (lng != null) $result.lng = lng;
    if (maxRangeMeters != null) $result.maxRangeMeters = maxRangeMeters;
    if (mobilityMode != null) $result.mobilityMode = mobilityMode;
    if (note != null) $result.note = note;
    return $result;
  }

  RequestData._() : super();

  factory RequestData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('RequestData',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'requestId', protoName: 'request_id')
    ..aOS(2, 'resourceType', protoName: 'resource_type')
    ..aOS(3, 'description')
    ..a<$core.double>(4, 'quantityNeeded', $pb.PbFieldType.OF,
        protoName: 'quantity_needed')
    ..e<UrgencyLevel>(5, 'urgency', $pb.PbFieldType.OE,
        defaultOrMaker: UrgencyLevel.INFO,
        valueOf: UrgencyLevel.valueOf,
        enumValues: UrgencyLevel.values)
    ..a<$core.double>(6, 'lat', $pb.PbFieldType.OD)
    ..a<$core.double>(7, 'lng', $pb.PbFieldType.OD)
    ..a<$core.double>(8, 'maxRangeMeters', $pb.PbFieldType.OF,
        protoName: 'max_range_meters')
    ..aOS(9, 'mobilityMode', protoName: 'mobility_mode')
    ..aOS(10, 'note')
    ..hasRequiredFields = false;

  @$core.override
  RequestData createEmptyInstance() => create();
  static RequestData create() => RequestData._();
  @$core.override
  RequestData clone() => RequestData()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.String get resourceType => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceType($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(4)
  $core.double get quantityNeeded => $_getN(3);
  @$pb.TagNumber(4)
  set quantityNeeded($core.double v) {
    $_setFloat(3, v);
  }

  @$pb.TagNumber(5)
  UrgencyLevel get urgency => $_getN(4);
  @$pb.TagNumber(5)
  set urgency(UrgencyLevel v) {
    setField(5, v);
  }

  @$pb.TagNumber(6)
  $core.double get lat => $_getN(5);
  @$pb.TagNumber(6)
  set lat($core.double v) {
    $_setDouble(5, v);
  }

  @$pb.TagNumber(7)
  $core.double get lng => $_getN(6);
  @$pb.TagNumber(7)
  set lng($core.double v) {
    $_setDouble(6, v);
  }

  @$pb.TagNumber(8)
  $core.double get maxRangeMeters => $_getN(7);
  @$pb.TagNumber(8)
  set maxRangeMeters($core.double v) {
    $_setFloat(7, v);
  }

  @$pb.TagNumber(9)
  $core.String get mobilityMode => $_getSZ(8);
  @$pb.TagNumber(9)
  set mobilityMode($core.String v) {
    $_setString(8, v);
  }

  @$pb.TagNumber(10)
  $core.String get note => $_getSZ(9);
  @$pb.TagNumber(10)
  set note($core.String v) {
    $_setString(9, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MatchIntentData (媒合意向)
// ─────────────────────────────────────────────────────────────────────────────

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
    if (requestId != null) $result.requestId = requestId;
    if (resourceId != null) $result.resourceId = resourceId;
    if (requesterPubKey != null) $result.requesterPubKey = requesterPubKey;
    if (providerPubKey != null) $result.providerPubKey = providerPubKey;
    if (matchScore != null) $result.matchScore = matchScore;
    if (matchExpiresAt != null) $result.matchExpiresAt = matchExpiresAt;
    return $result;
  }

  MatchIntentData._() : super();

  factory MatchIntentData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('MatchIntentData',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'requestId', protoName: 'request_id')
    ..aOS(2, 'resourceId', protoName: 'resource_id')
    ..a<$core.List<$core.int>>(3, 'requesterPubKey', $pb.PbFieldType.OY,
        protoName: 'requester_pub_key')
    ..a<$core.List<$core.int>>(4, 'providerPubKey', $pb.PbFieldType.OY,
        protoName: 'provider_pub_key')
    ..a<$core.double>(5, 'matchScore', $pb.PbFieldType.OF,
        protoName: 'match_score')
    ..aInt64(6, 'matchExpiresAt', protoName: 'match_expires_at')
    ..hasRequiredFields = false;

  @$core.override
  MatchIntentData createEmptyInstance() => create();
  static MatchIntentData create() => MatchIntentData._();
  @$core.override
  MatchIntentData clone() => MatchIntentData()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(3)
  $core.List<$core.int> get requesterPubKey => $_getN(2);
  @$pb.TagNumber(3)
  set requesterPubKey($core.List<$core.int> v) {
    $_setBytes(2, v);
  }

  @$pb.TagNumber(4)
  $core.List<$core.int> get providerPubKey => $_getN(3);
  @$pb.TagNumber(4)
  set providerPubKey($core.List<$core.int> v) {
    $_setBytes(3, v);
  }

  @$pb.TagNumber(5)
  $core.double get matchScore => $_getN(4);
  @$pb.TagNumber(5)
  set matchScore($core.double v) {
    $_setFloat(4, v);
  }

  @$pb.TagNumber(6)
  $fixnum.Int64 get matchExpiresAt => $_getI64(5);
  @$pb.TagNumber(6)
  set matchExpiresAt($fixnum.Int64 v) {
    $_setInt64(5, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PhysicalHandshakeData (物理交割憑證)
// ─────────────────────────────────────────────────────────────────────────────

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
    if (resourceId != null) $result.resourceId = resourceId;
    if (requestId != null) $result.requestId = requestId;
    if (requesterPubKey != null) $result.requesterPubKey = requesterPubKey;
    if (providerPubKey != null) $result.providerPubKey = providerPubKey;
    if (requesterSignature != null)
      $result.requesterSignature = requesterSignature;
    if (providerSignature != null)
      $result.providerSignature = providerSignature;
    if (method != null) $result.method = method;
    return $result;
  }

  PhysicalHandshakeData._() : super();

  factory PhysicalHandshakeData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('PhysicalHandshakeData',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'resourceId', protoName: 'resource_id')
    ..aOS(2, 'requestId', protoName: 'request_id')
    ..a<$core.List<$core.int>>(3, 'requesterPubKey', $pb.PbFieldType.OY,
        protoName: 'requester_pub_key')
    ..a<$core.List<$core.int>>(4, 'providerPubKey', $pb.PbFieldType.OY,
        protoName: 'provider_pub_key')
    ..a<$core.List<$core.int>>(5, 'requesterSignature', $pb.PbFieldType.OY,
        protoName: 'requester_signature')
    ..a<$core.List<$core.int>>(6, 'providerSignature', $pb.PbFieldType.OY,
        protoName: 'provider_signature')
    ..aOS(7, 'method')
    ..hasRequiredFields = false;

  @$core.override
  PhysicalHandshakeData createEmptyInstance() => create();
  static PhysicalHandshakeData create() => PhysicalHandshakeData._();
  @$core.override
  PhysicalHandshakeData clone() =>
      PhysicalHandshakeData()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get resourceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set resourceId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(3)
  $core.List<$core.int> get requesterPubKey => $_getN(2);
  @$pb.TagNumber(3)
  set requesterPubKey($core.List<$core.int> v) {
    $_setBytes(2, v);
  }

  @$pb.TagNumber(4)
  $core.List<$core.int> get providerPubKey => $_getN(3);
  @$pb.TagNumber(4)
  set providerPubKey($core.List<$core.int> v) {
    $_setBytes(3, v);
  }

  @$pb.TagNumber(5)
  $core.List<$core.int> get requesterSignature => $_getN(4);
  @$pb.TagNumber(5)
  set requesterSignature($core.List<$core.int> v) {
    $_setBytes(4, v);
  }

  @$pb.TagNumber(6)
  $core.List<$core.int> get providerSignature => $_getN(5);
  @$pb.TagNumber(6)
  set providerSignature($core.List<$core.int> v) {
    $_setBytes(5, v);
  }

  @$pb.TagNumber(7)
  $core.String get method => $_getSZ(6);
  @$pb.TagNumber(7)
  set method($core.String v) {
    $_setString(6, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HazardData (動態危險標記)
// ─────────────────────────────────────────────────────────────────────────────

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
    if (hazardId != null) $result.hazardId = hazardId;
    if (hazardType != null) $result.hazardType = hazardType;
    if (severity != null) $result.severity = severity;
    if (centerLat != null) $result.centerLat = centerLat;
    if (centerLng != null) $result.centerLng = centerLng;
    if (radiusMeters != null) $result.radiusMeters = radiusMeters;
    if (observedAt != null) $result.observedAt = observedAt;
    if (description != null) $result.description = description;
    if (isConfirmation != null) $result.isConfirmation = isConfirmation;
    return $result;
  }

  HazardData._() : super();

  factory HazardData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('HazardData',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'hazardId', protoName: 'hazard_id')
    ..aOS(2, 'hazardType', protoName: 'hazard_type')
    ..a<$core.int>(3, 'severity', $pb.PbFieldType.OU3)
    ..a<$core.double>(4, 'centerLat', $pb.PbFieldType.OD,
        protoName: 'center_lat')
    ..a<$core.double>(5, 'centerLng', $pb.PbFieldType.OD,
        protoName: 'center_lng')
    ..a<$core.double>(6, 'radiusMeters', $pb.PbFieldType.OF,
        protoName: 'radius_meters')
    ..aInt64(7, 'observedAt', protoName: 'observed_at')
    ..aOS(8, 'description')
    ..aOB(9, 'isConfirmation', protoName: 'is_confirmation')
    ..hasRequiredFields = false;

  @$core.override
  HazardData createEmptyInstance() => create();
  static HazardData create() => HazardData._();
  @$core.override
  HazardData clone() => HazardData()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get hazardId => $_getSZ(0);
  @$pb.TagNumber(1)
  set hazardId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.String get hazardType => $_getSZ(1);
  @$pb.TagNumber(2)
  set hazardType($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(3)
  $core.int get severity => $_getIZ(2);
  @$pb.TagNumber(3)
  set severity($core.int v) {
    $_setUnsignedInt32(2, v);
  }

  @$pb.TagNumber(4)
  $core.double get centerLat => $_getN(3);
  @$pb.TagNumber(4)
  set centerLat($core.double v) {
    $_setDouble(3, v);
  }

  @$pb.TagNumber(5)
  $core.double get centerLng => $_getN(4);
  @$pb.TagNumber(5)
  set centerLng($core.double v) {
    $_setDouble(4, v);
  }

  @$pb.TagNumber(6)
  $core.double get radiusMeters => $_getN(5);
  @$pb.TagNumber(6)
  set radiusMeters($core.double v) {
    $_setFloat(5, v);
  }

  @$pb.TagNumber(7)
  $fixnum.Int64 get observedAt => $_getI64(6);
  @$pb.TagNumber(7)
  set observedAt($fixnum.Int64 v) {
    $_setInt64(6, v);
  }

  @$pb.TagNumber(8)
  $core.String get description => $_getSZ(7);
  @$pb.TagNumber(8)
  set description($core.String v) {
    $_setString(7, v);
  }

  @$pb.TagNumber(9)
  $core.bool get isConfirmation => $_getBF(8);
  @$pb.TagNumber(9)
  set isConfirmation($core.bool v) {
    $_setBool(8, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QuarantineVoteData (惡意節點檢舉投票)
// ─────────────────────────────────────────────────────────────────────────────

class QuarantineVoteData extends $pb.GeneratedMessage {
  factory QuarantineVoteData({
    $core.List<$core.int>? targetPubKey,
    $core.String? reason,
    $core.double? voteWeight,
  }) {
    final $result = create();
    if (targetPubKey != null) $result.targetPubKey = targetPubKey;
    if (reason != null) $result.reason = reason;
    if (voteWeight != null) $result.voteWeight = voteWeight;
    return $result;
  }

  QuarantineVoteData._() : super();

  factory QuarantineVoteData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('QuarantineVoteData',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, 'targetPubKey', $pb.PbFieldType.OY,
        protoName: 'target_pub_key')
    ..aOS(2, 'reason')
    ..a<$core.double>(3, 'voteWeight', $pb.PbFieldType.OF,
        protoName: 'vote_weight')
    ..hasRequiredFields = false;

  @$core.override
  QuarantineVoteData createEmptyInstance() => create();
  static QuarantineVoteData create() => QuarantineVoteData._();
  @$core.override
  QuarantineVoteData clone() => QuarantineVoteData()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.List<$core.int> get targetPubKey => $_getN(0);
  @$pb.TagNumber(1)
  set targetPubKey($core.List<$core.int> v) {
    $_setBytes(0, v);
  }

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(3)
  $core.double get voteWeight => $_getN(2);
  @$pb.TagNumber(3)
  set voteWeight($core.double v) {
    $_setFloat(2, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MatchCancelData (釋放配對)
// ─────────────────────────────────────────────────────────────────────────────

class MatchCancelData extends $pb.GeneratedMessage {
  factory MatchCancelData({
    $core.String? requestId,
    $core.String? resourceId,
    $core.String? reason,
    $core.String? negotiationId,
  }) {
    final $result = create();
    if (requestId != null) $result.requestId = requestId;
    if (resourceId != null) $result.resourceId = resourceId;
    if (reason != null) $result.reason = reason;
    if (negotiationId != null) $result.negotiationId = negotiationId;
    return $result;
  }

  MatchCancelData._() : super();

  factory MatchCancelData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('MatchCancelData',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'requestId', protoName: 'request_id')
    ..aOS(2, 'resourceId', protoName: 'resource_id')
    ..aOS(3, 'reason')
    ..aOS(4, 'negotiationId', protoName: 'negotiation_id')
    ..hasRequiredFields = false;

  @$core.override
  MatchCancelData createEmptyInstance() => create();
  static MatchCancelData create() => MatchCancelData._();
  @$core.override
  MatchCancelData clone() => MatchCancelData()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(3)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(3)
  set reason($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(4)
  $core.String get negotiationId => $_getSZ(3);
  @$pb.TagNumber(4)
  set negotiationId($core.String v) {
    $_setString(3, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AllergyEntry (過敏原條目)
// ─────────────────────────────────────────────────────────────────────────────

class AllergyEntry extends $pb.GeneratedMessage {
  factory AllergyEntry({
    $core.String? allergen,
    $core.String? reaction,
  }) {
    final $result = create();
    if (allergen != null) $result.allergen = allergen;
    if (reaction != null) $result.reaction = reaction;
    return $result;
  }

  AllergyEntry._() : super();

  factory AllergyEntry.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('AllergyEntry',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'allergen')
    ..aOS(2, 'reaction')
    ..hasRequiredFields = false;

  @$core.override
  AllergyEntry createEmptyInstance() => create();
  static AllergyEntry create() => AllergyEntry._();
  @$core.override
  AllergyEntry clone() => AllergyEntry()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get allergen => $_getSZ(0);
  @$pb.TagNumber(1)
  set allergen($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.String get reaction => $_getSZ(1);
  @$pb.TagNumber(2)
  set reaction($core.String v) {
    $_setString(1, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EmergencyContact (緊急聯絡人)
// ─────────────────────────────────────────────────────────────────────────────

class EmergencyContact extends $pb.GeneratedMessage {
  factory EmergencyContact({
    $core.String? phone,
    $core.String? relation,
  }) {
    final $result = create();
    if (phone != null) $result.phone = phone;
    if (relation != null) $result.relation = relation;
    return $result;
  }

  EmergencyContact._() : super();

  factory EmergencyContact.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('EmergencyContact',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'phone')
    ..aOS(2, 'relation')
    ..hasRequiredFields = false;

  @$core.override
  EmergencyContact createEmptyInstance() => create();
  static EmergencyContact create() => EmergencyContact._();
  @$core.override
  EmergencyContact clone() => EmergencyContact()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get phone => $_getSZ(0);
  @$pb.TagNumber(1)
  set phone($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.String get relation => $_getSZ(1);
  @$pb.TagNumber(2)
  set relation($core.String v) {
    $_setString(1, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MedicalSummary (醫療卡摘要 - 附加在 SOS 廣播中)
// ─────────────────────────────────────────────────────────────────────────────

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
    if (name != null) $result.name = name;
    if (age != null) $result.age = age;
    if (heightCm != null) $result.heightCm = heightCm;
    if (weightKg != null) $result.weightKg = weightKg;
    if (bloodType != null) $result.bloodType = bloodType;
    if (conditions != null) $result.conditions.addAll(conditions);
    if (allergies != null) $result.allergies.addAll(allergies);
    if (medications != null) $result.medications.addAll(medications);
    if (emergencyContact != null) $result.emergencyContact = emergencyContact;
    if (organDonor != null) $result.organDonor = organDonor;
    if (primaryLanguage != null) $result.primaryLanguage = primaryLanguage;
    return $result;
  }

  MedicalSummary._() : super();

  factory MedicalSummary.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('MedicalSummary',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'name')
    ..a<$core.int>(2, 'age', $pb.PbFieldType.O3)
    ..a<$core.int>(3, 'heightCm', $pb.PbFieldType.O3, protoName: 'height_cm')
    ..a<$core.int>(4, 'weightKg', $pb.PbFieldType.O3, protoName: 'weight_kg')
    ..aOS(5, 'bloodType', protoName: 'blood_type')
    ..pPS(6, 'conditions')
    ..pc<AllergyEntry>(7, 'allergies', $pb.PbFieldType.PM,
        subBuilder: AllergyEntry.create)
    ..pPS(8, 'medications')
    ..aOM<EmergencyContact>(9, 'emergencyContact',
        protoName: 'emergency_contact', subBuilder: EmergencyContact.create)
    ..aOB(10, 'organDonor', protoName: 'organ_donor')
    ..aOS(11, 'primaryLanguage', protoName: 'primary_language')
    ..hasRequiredFields = false;

  @$core.override
  MedicalSummary createEmptyInstance() => create();
  static MedicalSummary create() => MedicalSummary._();
  @$core.override
  MedicalSummary clone() => MedicalSummary()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.int get age => $_getIZ(1);
  @$pb.TagNumber(2)
  set age($core.int v) {
    $_setSignedInt32(1, v);
  }

  @$pb.TagNumber(3)
  $core.int get heightCm => $_getIZ(2);
  @$pb.TagNumber(3)
  set heightCm($core.int v) {
    $_setSignedInt32(2, v);
  }

  @$pb.TagNumber(4)
  $core.int get weightKg => $_getIZ(3);
  @$pb.TagNumber(4)
  set weightKg($core.int v) {
    $_setSignedInt32(3, v);
  }

  @$pb.TagNumber(5)
  $core.String get bloodType => $_getSZ(4);
  @$pb.TagNumber(5)
  set bloodType($core.String v) {
    $_setString(4, v);
  }

  @$pb.TagNumber(6)
  $core.List<$core.String> get conditions => $_getList(5);

  @$pb.TagNumber(7)
  $core.List<AllergyEntry> get allergies => $_getList(6);

  @$pb.TagNumber(8)
  $core.List<$core.String> get medications => $_getList(7);

  @$pb.TagNumber(9)
  EmergencyContact get emergencyContact => $_getN(8);
  @$pb.TagNumber(9)
  set emergencyContact(EmergencyContact v) {
    setField(9, v);
  }
  @$pb.TagNumber(9)
  $core.bool hasEmergencyContact() => $_has(8);

  @$pb.TagNumber(10)
  $core.bool get organDonor => $_getBF(9);
  @$pb.TagNumber(10)
  set organDonor($core.bool v) {
    $_setBool(9, v);
  }

  @$pb.TagNumber(11)
  $core.String get primaryLanguage => $_getSZ(10);
  @$pb.TagNumber(11)
  set primaryLanguage($core.String v) {
    $_setString(10, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MeshEnvelope (Bridgefy 廣播驅動頂層封包)
// ─────────────────────────────────────────────────────────────────────────────

class MeshEnvelope extends $pb.GeneratedMessage {
  factory MeshEnvelope({
    EnvelopeType? type,
    $core.List<$core.int>? payload,
    $core.String? senderId,
  }) {
    final $result = create();
    if (type != null) $result.type = type;
    if (payload != null) $result.payload = payload;
    if (senderId != null) $result.senderId = senderId;
    return $result;
  }

  MeshEnvelope._() : super();

  factory MeshEnvelope.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  factory MeshEnvelope.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('MeshEnvelope',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..e<EnvelopeType>(1, 'type', $pb.PbFieldType.OE,
        defaultOrMaker: EnvelopeType.ENVELOPE_EVENT,
        valueOf: EnvelopeType.valueOf,
        enumValues: EnvelopeType.values)
    ..a<$core.List<$core.int>>(2, 'payload', $pb.PbFieldType.OY)
    ..aOS(3, 'senderId', protoName: 'sender_id')
    ..hasRequiredFields = false;

  @$core.override
  MeshEnvelope createEmptyInstance() => create();

  static MeshEnvelope create() => MeshEnvelope._();

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.override
  MeshEnvelope clone() => MeshEnvelope()..mergeFromMessage(this);

  // Field 1: type (EnvelopeType)
  @$pb.TagNumber(1)
  EnvelopeType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(EnvelopeType v) {
    setField(1, v);
  }
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);

  // Field 2: payload (bytes)
  @$pb.TagNumber(2)
  $core.List<$core.int> get payload => $_getN(1);
  @$pb.TagNumber(2)
  set payload($core.List<$core.int> v) {
    $_setBytes(1, v);
  }

  // Field 3: sender_id (string)
  @$pb.TagNumber(3)
  $core.String get senderId => $_getSZ(2);
  @$pb.TagNumber(3)
  set senderId($core.String v) {
    $_setString(2, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FireAlarmRfData (433MHz 煙霧偵測器 RF 信號)
// ─────────────────────────────────────────────────────────────────────────────

class FireAlarmRfData extends $pb.GeneratedMessage {
  factory FireAlarmRfData({
    $core.String? detectorBrand,
    $core.int? rssi,
    $core.double? stationLat,
    $core.double? stationLng,
  }) {
    final $result = create();
    if (detectorBrand != null) $result.detectorBrand = detectorBrand;
    if (rssi != null) $result.rssi = rssi;
    if (stationLat != null) $result.stationLat = stationLat;
    if (stationLng != null) $result.stationLng = stationLng;
    return $result;
  }

  FireAlarmRfData._() : super();

  factory FireAlarmRfData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('FireAlarmRfData',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'detectorBrand', protoName: 'detector_brand')
    ..a<$core.int>(2, 'rssi', $pb.PbFieldType.O3)
    ..a<$core.double>(3, 'stationLat', $pb.PbFieldType.OD,
        protoName: 'station_lat')
    ..a<$core.double>(4, 'stationLng', $pb.PbFieldType.OD,
        protoName: 'station_lng')
    ..hasRequiredFields = false;

  @$core.override
  FireAlarmRfData createEmptyInstance() => create();
  static FireAlarmRfData create() => FireAlarmRfData._();
  @$core.override
  FireAlarmRfData clone() => FireAlarmRfData()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get detectorBrand => $_getSZ(0);
  @$pb.TagNumber(1)
  set detectorBrand($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.int get rssi => $_getIZ(1);
  @$pb.TagNumber(2)
  set rssi($core.int v) {
    $_setSignedInt32(1, v);
  }

  @$pb.TagNumber(3)
  $core.double get stationLat => $_getN(2);
  @$pb.TagNumber(3)
  set stationLat($core.double v) {
    $_setDouble(2, v);
  }

  @$pb.TagNumber(4)
  $core.double get stationLng => $_getN(3);
  @$pb.TagNumber(4)
  set stationLng($core.double v) {
    $_setDouble(3, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MatchConfirmData (媒合確認)
// ─────────────────────────────────────────────────────────────────────────────

class MatchConfirmData extends $pb.GeneratedMessage {
  factory MatchConfirmData({
    $core.String? requestId,
    $core.String? resourceId,
    $core.List<$core.int>? requesterPubKey,
    $core.List<$core.int>? providerPubKey,
  }) {
    final $result = create();
    if (requestId != null) $result.requestId = requestId;
    if (resourceId != null) $result.resourceId = resourceId;
    if (requesterPubKey != null) $result.requesterPubKey = requesterPubKey;
    if (providerPubKey != null) $result.providerPubKey = providerPubKey;
    return $result;
  }

  MatchConfirmData._() : super();

  factory MatchConfirmData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('MatchConfirmData',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'requestId', protoName: 'request_id')
    ..aOS(2, 'resourceId', protoName: 'resource_id')
    ..a<$core.List<$core.int>>(3, 'requesterPubKey', $pb.PbFieldType.OY, protoName: 'requester_pub_key')
    ..a<$core.List<$core.int>>(4, 'providerPubKey', $pb.PbFieldType.OY, protoName: 'provider_pub_key')
    ..hasRequiredFields = false;

  @$core.override
  MatchConfirmData createEmptyInstance() => create();
  static MatchConfirmData create() => MatchConfirmData._();
  @$core.override
  MatchConfirmData clone() => MatchConfirmData()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(3)
  $core.List<$core.int> get requesterPubKey => $_getN(2);
  @$pb.TagNumber(3)
  set requesterPubKey($core.List<$core.int> v) {
    $_setBytes(2, v);
  }

  @$pb.TagNumber(4)
  $core.List<$core.int> get providerPubKey => $_getN(3);
  @$pb.TagNumber(4)
  set providerPubKey($core.List<$core.int> v) {
    $_setBytes(3, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MatchRejectData (媒合拒絕)
// ─────────────────────────────────────────────────────────────────────────────

class MatchRejectData extends $pb.GeneratedMessage {
  factory MatchRejectData({
    $core.String? requestId,
    $core.String? resourceId,
    $core.String? reason,
  }) {
    final $result = create();
    if (requestId != null) $result.requestId = requestId;
    if (resourceId != null) $result.resourceId = resourceId;
    if (reason != null) $result.reason = reason;
    return $result;
  }

  MatchRejectData._() : super();

  factory MatchRejectData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('MatchRejectData',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'requestId', protoName: 'request_id')
    ..aOS(2, 'resourceId', protoName: 'resource_id')
    ..aOS(3, 'reason')
    ..hasRequiredFields = false;

  @$core.override
  MatchRejectData createEmptyInstance() => create();
  static MatchRejectData create() => MatchRejectData._();
  @$core.override
  MatchRejectData clone() => MatchRejectData()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(3)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(3)
  set reason($core.String v) {
    $_setString(2, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LocationUpdateData (媒合中位置同步)
// ─────────────────────────────────────────────────────────────────────────────

class LocationUpdateData extends $pb.GeneratedMessage {
  factory LocationUpdateData({
    $core.String? sessionId,
    $core.double? lat,
    $core.double? lng,
    $fixnum.Int64? timestamp,
  }) {
    final $result = create();
    if (sessionId != null) $result.sessionId = sessionId;
    if (lat != null) $result.lat = lat;
    if (lng != null) $result.lng = lng;
    if (timestamp != null) $result.timestamp = timestamp;
    return $result;
  }

  LocationUpdateData._() : super();

  factory LocationUpdateData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('LocationUpdateData',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'sessionId', protoName: 'session_id')
    ..a<$core.double>(2, 'lat', $pb.PbFieldType.OD)
    ..a<$core.double>(3, 'lng', $pb.PbFieldType.OD)
    ..aInt64(4, 'timestamp')
    ..hasRequiredFields = false;

  @$core.override
  LocationUpdateData createEmptyInstance() => create();
  static LocationUpdateData create() => LocationUpdateData._();
  @$core.override
  LocationUpdateData clone() => LocationUpdateData()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.double get lat => $_getN(1);
  @$pb.TagNumber(2)
  set lat($core.double v) {
    $_setDouble(1, v);
  }

  @$pb.TagNumber(3)
  $core.double get lng => $_getN(2);
  @$pb.TagNumber(3)
  set lng($core.double v) {
    $_setDouble(2, v);
  }

  @$pb.TagNumber(4)
  $fixnum.Int64 get timestamp => $_getI64(3);
  @$pb.TagNumber(4)
  set timestamp($fixnum.Int64 v) {
    $_setInt64(3, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MatchOfferData (媒合出價)
// ─────────────────────────────────────────────────────────────────────────────

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
    if (negotiationId != null) $result.negotiationId = negotiationId;
    if (resourceId != null) $result.resourceId = resourceId;
    if (requestId != null) $result.requestId = requestId;
    if (providerPubKey != null) $result.providerPubKey = providerPubKey;
    if (requesterPubKey != null) $result.requesterPubKey = requesterPubKey;
    if (offeredQty != null) $result.offeredQty = offeredQty;
    if (matchScore != null) $result.matchScore = matchScore;
    if (expiresAt != null) $result.expiresAt = expiresAt;
    return $result;
  }

  MatchOfferData._() : super();

  factory MatchOfferData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('MatchOfferData',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'negotiationId', protoName: 'negotiation_id')
    ..aOS(2, 'resourceId', protoName: 'resource_id')
    ..aOS(3, 'requestId', protoName: 'request_id')
    ..a<$core.List<$core.int>>(4, 'providerPubKey', $pb.PbFieldType.OY,
        protoName: 'provider_pub_key')
    ..a<$core.List<$core.int>>(5, 'requesterPubKey', $pb.PbFieldType.OY,
        protoName: 'requester_pub_key')
    ..a<$core.double>(6, 'offeredQty', $pb.PbFieldType.OF,
        protoName: 'offered_qty')
    ..a<$core.double>(7, 'matchScore', $pb.PbFieldType.OF,
        protoName: 'match_score')
    ..aInt64(8, 'expiresAt', protoName: 'expires_at')
    ..hasRequiredFields = false;

  @$core.override
  MatchOfferData createEmptyInstance() => create();
  static MatchOfferData create() => MatchOfferData._();
  @$core.override
  MatchOfferData clone() => MatchOfferData()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get negotiationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set negotiationId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(3)
  $core.String get requestId => $_getSZ(2);
  @$pb.TagNumber(3)
  set requestId($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(4)
  $core.List<$core.int> get providerPubKey => $_getN(3);
  @$pb.TagNumber(4)
  set providerPubKey($core.List<$core.int> v) {
    $_setBytes(3, v);
  }

  @$pb.TagNumber(5)
  $core.List<$core.int> get requesterPubKey => $_getN(4);
  @$pb.TagNumber(5)
  set requesterPubKey($core.List<$core.int> v) {
    $_setBytes(4, v);
  }

  @$pb.TagNumber(6)
  $core.double get offeredQty => $_getN(5);
  @$pb.TagNumber(6)
  set offeredQty($core.double v) {
    $_setFloat(5, v);
  }

  @$pb.TagNumber(7)
  $core.double get matchScore => $_getN(6);
  @$pb.TagNumber(7)
  set matchScore($core.double v) {
    $_setFloat(6, v);
  }

  @$pb.TagNumber(8)
  $fixnum.Int64 get expiresAt => $_getI64(7);
  @$pb.TagNumber(8)
  set expiresAt($fixnum.Int64 v) {
    $_setInt64(7, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MatchRequestData (媒合請求)
// ─────────────────────────────────────────────────────────────────────────────

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
    if (negotiationId != null) $result.negotiationId = negotiationId;
    if (resourceId != null) $result.resourceId = resourceId;
    if (requestId != null) $result.requestId = requestId;
    if (providerPubKey != null) $result.providerPubKey = providerPubKey;
    if (requesterPubKey != null) $result.requesterPubKey = requesterPubKey;
    if (requestedQty != null) $result.requestedQty = requestedQty;
    if (expiresAt != null) $result.expiresAt = expiresAt;
    return $result;
  }

  MatchRequestData._() : super();

  factory MatchRequestData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('MatchRequestData',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'negotiationId', protoName: 'negotiation_id')
    ..aOS(2, 'resourceId', protoName: 'resource_id')
    ..aOS(3, 'requestId', protoName: 'request_id')
    ..a<$core.List<$core.int>>(4, 'providerPubKey', $pb.PbFieldType.OY,
        protoName: 'provider_pub_key')
    ..a<$core.List<$core.int>>(5, 'requesterPubKey', $pb.PbFieldType.OY,
        protoName: 'requester_pub_key')
    ..a<$core.double>(6, 'requestedQty', $pb.PbFieldType.OF,
        protoName: 'requested_qty')
    ..aInt64(7, 'expiresAt', protoName: 'expires_at')
    ..hasRequiredFields = false;

  @$core.override
  MatchRequestData createEmptyInstance() => create();
  static MatchRequestData create() => MatchRequestData._();
  @$core.override
  MatchRequestData clone() => MatchRequestData()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get negotiationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set negotiationId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(3)
  $core.String get requestId => $_getSZ(2);
  @$pb.TagNumber(3)
  set requestId($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(4)
  $core.List<$core.int> get providerPubKey => $_getN(3);
  @$pb.TagNumber(4)
  set providerPubKey($core.List<$core.int> v) {
    $_setBytes(3, v);
  }

  @$pb.TagNumber(5)
  $core.List<$core.int> get requesterPubKey => $_getN(4);
  @$pb.TagNumber(5)
  set requesterPubKey($core.List<$core.int> v) {
    $_setBytes(4, v);
  }

  @$pb.TagNumber(6)
  $core.double get requestedQty => $_getN(5);
  @$pb.TagNumber(6)
  set requestedQty($core.double v) {
    $_setFloat(5, v);
  }

  @$pb.TagNumber(7)
  $fixnum.Int64 get expiresAt => $_getI64(6);
  @$pb.TagNumber(7)
  set expiresAt($fixnum.Int64 v) {
    $_setInt64(6, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MatchAcceptData (媒合接受)
// ─────────────────────────────────────────────────────────────────────────────

class MatchAcceptData extends $pb.GeneratedMessage {
  factory MatchAcceptData({
    $core.String? negotiationId,
    $core.String? resourceId,
    $core.String? requestId,
    $core.List<$core.int>? acceptorPubKey,
    $core.double? agreedQty,
  }) {
    final $result = create();
    if (negotiationId != null) $result.negotiationId = negotiationId;
    if (resourceId != null) $result.resourceId = resourceId;
    if (requestId != null) $result.requestId = requestId;
    if (acceptorPubKey != null) $result.acceptorPubKey = acceptorPubKey;
    if (agreedQty != null) $result.agreedQty = agreedQty;
    return $result;
  }

  MatchAcceptData._() : super();

  factory MatchAcceptData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('MatchAcceptData',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'negotiationId', protoName: 'negotiation_id')
    ..aOS(2, 'resourceId', protoName: 'resource_id')
    ..aOS(3, 'requestId', protoName: 'request_id')
    ..a<$core.List<$core.int>>(4, 'acceptorPubKey', $pb.PbFieldType.OY,
        protoName: 'acceptor_pub_key')
    ..a<$core.double>(5, 'agreedQty', $pb.PbFieldType.OF,
        protoName: 'agreed_qty')
    ..hasRequiredFields = false;

  @$core.override
  MatchAcceptData createEmptyInstance() => create();
  static MatchAcceptData create() => MatchAcceptData._();
  @$core.override
  MatchAcceptData clone() => MatchAcceptData()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get negotiationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set negotiationId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(3)
  $core.String get requestId => $_getSZ(2);
  @$pb.TagNumber(3)
  set requestId($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(4)
  $core.List<$core.int> get acceptorPubKey => $_getN(3);
  @$pb.TagNumber(4)
  set acceptorPubKey($core.List<$core.int> v) {
    $_setBytes(3, v);
  }

  @$pb.TagNumber(5)
  $core.double get agreedQty => $_getN(4);
  @$pb.TagNumber(5)
  set agreedQty($core.double v) {
    $_setFloat(4, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MatchDeclineData (媒合拒絕)
// ─────────────────────────────────────────────────────────────────────────────

class MatchDeclineData extends $pb.GeneratedMessage {
  factory MatchDeclineData({
    $core.String? negotiationId,
    $core.String? resourceId,
    $core.String? requestId,
    $core.String? reason,
  }) {
    final $result = create();
    if (negotiationId != null) $result.negotiationId = negotiationId;
    if (resourceId != null) $result.resourceId = resourceId;
    if (requestId != null) $result.requestId = requestId;
    if (reason != null) $result.reason = reason;
    return $result;
  }

  MatchDeclineData._() : super();

  factory MatchDeclineData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('MatchDeclineData',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'negotiationId', protoName: 'negotiation_id')
    ..aOS(2, 'resourceId', protoName: 'resource_id')
    ..aOS(3, 'requestId', protoName: 'request_id')
    ..aOS(4, 'reason')
    ..hasRequiredFields = false;

  @$core.override
  MatchDeclineData createEmptyInstance() => create();
  static MatchDeclineData create() => MatchDeclineData._();
  @$core.override
  MatchDeclineData clone() => MatchDeclineData()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get negotiationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set negotiationId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(3)
  $core.String get requestId => $_getSZ(2);
  @$pb.TagNumber(3)
  set requestId($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(4)
  $core.String get reason => $_getSZ(3);
  @$pb.TagNumber(4)
  set reason($core.String v) {
    $_setString(3, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HandshakeCompleteData (交割完成憑證)
// ─────────────────────────────────────────────────────────────────────────────

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
  }) {
    final $result = create();
    if (negotiationId != null) $result.negotiationId = negotiationId;
    if (resourceId != null) $result.resourceId = resourceId;
    if (requestId != null) $result.requestId = requestId;
    if (providerPubKey != null) $result.providerPubKey = providerPubKey;
    if (requesterPubKey != null) $result.requesterPubKey = requesterPubKey;
    if (actualDeliveredQty != null)
      $result.actualDeliveredQty = actualDeliveredQty;
    if (method != null) $result.method = method;
    if (providerSignature != null)
      $result.providerSignature = providerSignature;
    if (requesterSignature != null)
      $result.requesterSignature = requesterSignature;
    return $result;
  }

  HandshakeCompleteData._() : super();

  factory HandshakeCompleteData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('HandshakeCompleteData',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'negotiationId', protoName: 'negotiation_id')
    ..aOS(2, 'resourceId', protoName: 'resource_id')
    ..aOS(3, 'requestId', protoName: 'request_id')
    ..a<$core.List<$core.int>>(4, 'providerPubKey', $pb.PbFieldType.OY,
        protoName: 'provider_pub_key')
    ..a<$core.List<$core.int>>(5, 'requesterPubKey', $pb.PbFieldType.OY,
        protoName: 'requester_pub_key')
    ..a<$core.double>(6, 'actualDeliveredQty', $pb.PbFieldType.OF,
        protoName: 'actual_delivered_qty')
    ..aOS(7, 'method')
    ..a<$core.List<$core.int>>(8, 'providerSignature', $pb.PbFieldType.OY,
        protoName: 'provider_signature')
    ..a<$core.List<$core.int>>(9, 'requesterSignature', $pb.PbFieldType.OY,
        protoName: 'requester_signature')
    ..hasRequiredFields = false;

  @$core.override
  HandshakeCompleteData createEmptyInstance() => create();
  static HandshakeCompleteData create() => HandshakeCompleteData._();
  @$core.override
  HandshakeCompleteData clone() =>
      HandshakeCompleteData()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get negotiationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set negotiationId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.String get resourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(3)
  $core.String get requestId => $_getSZ(2);
  @$pb.TagNumber(3)
  set requestId($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(4)
  $core.List<$core.int> get providerPubKey => $_getN(3);
  @$pb.TagNumber(4)
  set providerPubKey($core.List<$core.int> v) {
    $_setBytes(3, v);
  }

  @$pb.TagNumber(5)
  $core.List<$core.int> get requesterPubKey => $_getN(4);
  @$pb.TagNumber(5)
  set requesterPubKey($core.List<$core.int> v) {
    $_setBytes(4, v);
  }

  @$pb.TagNumber(6)
  $core.double get actualDeliveredQty => $_getN(5);
  @$pb.TagNumber(6)
  set actualDeliveredQty($core.double v) {
    $_setFloat(5, v);
  }

  @$pb.TagNumber(7)
  $core.String get method => $_getSZ(6);
  @$pb.TagNumber(7)
  set method($core.String v) {
    $_setString(6, v);
  }

  @$pb.TagNumber(8)
  $core.List<$core.int> get providerSignature => $_getN(7);
  @$pb.TagNumber(8)
  set providerSignature($core.List<$core.int> v) {
    $_setBytes(7, v);
  }

  @$pb.TagNumber(9)
  $core.List<$core.int> get requesterSignature => $_getN(8);
  @$pb.TagNumber(9)
  set requesterSignature($core.List<$core.int> v) {
    $_setBytes(8, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StationClaimData (據點領取請求)
// ─────────────────────────────────────────────────────────────────────────────

class StationClaimData extends $pb.GeneratedMessage {
  factory StationClaimData({
    $core.String? resourceId,
    $core.String? requestId,
    $core.List<$core.int>? requesterPubKey,
    $core.String? category,
    $core.double? requestedQty,
  }) {
    final $result = create();
    if (resourceId != null) $result.resourceId = resourceId;
    if (requestId != null) $result.requestId = requestId;
    if (requesterPubKey != null) $result.requesterPubKey = requesterPubKey;
    if (category != null) $result.category = category;
    if (requestedQty != null) $result.requestedQty = requestedQty;
    return $result;
  }

  StationClaimData._() : super();

  factory StationClaimData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('StationClaimData',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'resourceId', protoName: 'resource_id')
    ..aOS(2, 'requestId', protoName: 'request_id')
    ..a<$core.List<$core.int>>(3, 'requesterPubKey', $pb.PbFieldType.OY,
        protoName: 'requester_pub_key')
    ..aOS(4, 'category')
    ..a<$core.double>(5, 'requestedQty', $pb.PbFieldType.OF,
        protoName: 'requested_qty')
    ..hasRequiredFields = false;

  @$core.override
  StationClaimData createEmptyInstance() => create();
  static StationClaimData create() => StationClaimData._();
  @$core.override
  StationClaimData clone() => StationClaimData()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get resourceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set resourceId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(3)
  $core.List<$core.int> get requesterPubKey => $_getN(2);
  @$pb.TagNumber(3)
  set requesterPubKey($core.List<$core.int> v) {
    $_setBytes(2, v);
  }

  @$pb.TagNumber(4)
  $core.String get category => $_getSZ(3);
  @$pb.TagNumber(4)
  set category($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(5)
  $core.double get requestedQty => $_getN(4);
  @$pb.TagNumber(5)
  set requestedQty($core.double v) {
    $_setFloat(4, v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StationResponseData (據點領取回應)
// ─────────────────────────────────────────────────────────────────────────────

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
    if (resourceId != null) $result.resourceId = resourceId;
    if (requestId != null) $result.requestId = requestId;
    if (requesterPubKey != null) $result.requesterPubKey = requesterPubKey;
    if (approved != null) $result.approved = approved;
    if (approvedQty != null) $result.approvedQty = approvedQty;
    if (denyReason != null) $result.denyReason = denyReason;
    if (pickupDeadline != null) $result.pickupDeadline = pickupDeadline;
    return $result;
  }

  StationResponseData._() : super();

  factory StationResponseData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('StationResponseData',
      package: const $pb.PackageName('resqmesh'), createEmptyInstance: create)
    ..aOS(1, 'resourceId', protoName: 'resource_id')
    ..aOS(2, 'requestId', protoName: 'request_id')
    ..a<$core.List<$core.int>>(3, 'requesterPubKey', $pb.PbFieldType.OY,
        protoName: 'requester_pub_key')
    ..aOB(4, 'approved')
    ..a<$core.double>(5, 'approvedQty', $pb.PbFieldType.OF,
        protoName: 'approved_qty')
    ..aOS(6, 'denyReason', protoName: 'deny_reason')
    ..aInt64(7, 'pickupDeadline', protoName: 'pickup_deadline')
    ..hasRequiredFields = false;

  @$core.override
  StationResponseData createEmptyInstance() => create();
  static StationResponseData create() => StationResponseData._();
  @$core.override
  StationResponseData clone() =>
      StationResponseData()..mergeFromMessage(this);
  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$pb.TagNumber(1)
  $core.String get resourceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set resourceId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(3)
  $core.List<$core.int> get requesterPubKey => $_getN(2);
  @$pb.TagNumber(3)
  set requesterPubKey($core.List<$core.int> v) {
    $_setBytes(2, v);
  }

  @$pb.TagNumber(4)
  $core.bool get approved => $_getBF(3);
  @$pb.TagNumber(4)
  set approved($core.bool v) {
    $_setBool(3, v);
  }

  @$pb.TagNumber(5)
  $core.double get approvedQty => $_getN(4);
  @$pb.TagNumber(5)
  set approvedQty($core.double v) {
    $_setFloat(4, v);
  }

  @$pb.TagNumber(6)
  $core.String get denyReason => $_getSZ(5);
  @$pb.TagNumber(6)
  set denyReason($core.String v) {
    $_setString(5, v);
  }

  @$pb.TagNumber(7)
  $fixnum.Int64 get pickupDeadline => $_getI64(6);
  @$pb.TagNumber(7)
  set pickupDeadline($fixnum.Int64 v) {
    $_setInt64(6, v);
  }
}
