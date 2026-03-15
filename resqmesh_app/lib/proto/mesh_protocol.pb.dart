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
  }) {
    final $result = create();
    if (hazardId != null) $result.hazardId = hazardId;
    if (hazardType != null) $result.hazardType = hazardType;
    if (severity != null) $result.severity = severity;
    if (centerLat != null) $result.centerLat = centerLat;
    if (centerLng != null) $result.centerLng = centerLng;
    if (radiusMeters != null) $result.radiusMeters = radiusMeters;
    if (observedAt != null) $result.observedAt = observedAt;
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
  }) {
    final $result = create();
    if (requestId != null) $result.requestId = requestId;
    if (resourceId != null) $result.resourceId = resourceId;
    if (reason != null) $result.reason = reason;
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
