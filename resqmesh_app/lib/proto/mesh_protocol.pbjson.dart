//
//  Generated code. Do not modify.
//  source: mesh_protocol.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use eventTypeDescriptor instead')
const EventType$json = {
  '1': 'EventType',
  '2': [
    {'1': 'RESOURCE_REGISTER', '2': 0},
    {'1': 'REQUEST_BROADCAST', '2': 1},
    {'1': 'MATCH_INTENT', '2': 2},
    {'1': 'PHYSICAL_HANDSHAKE', '2': 3},
    {'1': 'HAZARD_MARKER', '2': 4},
    {'1': 'QUARANTINE_VOTE', '2': 5},
    {'1': 'MATCH_CANCEL', '2': 6},
    {'1': 'FIRE_ALARM_RF', '2': 7},
    {'1': 'MATCH_CONFIRM', '2': 8},
    {'1': 'MATCH_REJECT', '2': 9},
    {'1': 'MATCH_INQUIRY', '2': 10},
    {'1': 'MATCH_AVAILABLE', '2': 11},
    {'1': 'MATCH_GONE', '2': 12},
    {'1': 'CHAT_MESSAGE', '2': 13},
    {'1': 'HAZARD_CONFIRM', '2': 14},
    {'1': 'MATCH_LOCATION_UPDATE', '2': 15},
  ],
};

/// Descriptor for `EventType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List eventTypeDescriptor = $convert.base64Decode(
    'CglFdmVudFR5cGUSFQoRUkVTT1VSQ0VfUkVHSVNURVIQABIVChFSRVFVRVNUX0JST0FEQ0FTVB'
    'ABEhAKDE1BVENIX0lOVEVOVBACEhYKElBIWVNJQ0FMX0hBTkRTSEFLRRADEhEKDUhBWkFSRF9N'
    'QVJLRVIQBBITCg9RVUFSQU5USU5FX1ZPVEUQBRIQCgxNQVRDSF9DQU5DRUwQBhIRCg1GSVJFX0'
    'FMQVJNX1JGEAcSEQoNTUFUQ0hfQ09ORklSTRAIEhAKDE1BVENIX1JFSkVDVBAJEhEKDU1BVENI'
    'X0lOUVVJUlkQChITCg9NQVRDSF9BVkFJTEFCTEUQCxIOCgpNQVRDSF9HT05FEAwSEAoMQ0hBVF'
    '9NRVNTQUdFEA0SEgoOSEFaQVJEX0NPTkZJUk0QDhIZChVNQVRDSF9MT0NBVElPTl9VUERBVEUQ'
    'Dw==');

@$core.Deprecated('Use urgencyLevelDescriptor instead')
const UrgencyLevel$json = {
  '1': 'UrgencyLevel',
  '2': [
    {'1': 'INFO', '2': 0},
    {'1': 'RESOURCE', '2': 1},
    {'1': 'SOS_YELLOW', '2': 2},
    {'1': 'SOS_RED', '2': 3},
  ],
};

/// Descriptor for `UrgencyLevel`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List urgencyLevelDescriptor = $convert.base64Decode(
    'CgxVcmdlbmN5TGV2ZWwSCAoESU5GTxAAEgwKCFJFU09VUkNFEAESDgoKU09TX1lFTExPVxACEg'
    'sKB1NPU19SRUQQAw==');

@$core.Deprecated('Use envelopeTypeDescriptor instead')
const EnvelopeType$json = {
  '1': 'EnvelopeType',
  '2': [
    {'1': 'ENVELOPE_EVENT', '2': 0},
    {'1': 'ENVELOPE_BLOOM_FILTER', '2': 1},
  ],
};

/// Descriptor for `EnvelopeType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List envelopeTypeDescriptor = $convert.base64Decode(
    'CgxFbnZlbG9wZVR5cGUSEgoORU5WRUxPUEVfRVZFTlQQABIZChVFTlZFTE9QRV9CTE9PTV9GSU'
    'xURVIQAQ==');

@$core.Deprecated('Use meshEventDescriptor instead')
const MeshEvent$json = {
  '1': 'MeshEvent',
  '2': [
    {'1': 'event_id', '3': 1, '4': 1, '5': 9, '10': 'eventId'},
    {'1': 'sender_pub_key', '3': 2, '4': 1, '5': 12, '10': 'senderPubKey'},
    {'1': 'identity_level', '3': 3, '4': 1, '5': 13, '10': 'identityLevel'},
    {'1': 'type', '3': 4, '4': 1, '5': 14, '6': '.resqmesh.EventType', '10': 'type'},
    {'1': 'urgency', '3': 5, '4': 1, '5': 14, '6': '.resqmesh.UrgencyLevel', '10': 'urgency'},
    {'1': 'hlc_timestamp', '3': 6, '4': 1, '5': 3, '10': 'hlcTimestamp'},
    {'1': 'hlc_counter', '3': 7, '4': 1, '5': 3, '10': 'hlcCounter'},
    {'1': 'ttl', '3': 8, '4': 1, '5': 5, '10': 'ttl'},
    {'1': 'origin_lat', '3': 15, '4': 1, '5': 1, '10': 'originLat'},
    {'1': 'origin_lng', '3': 16, '4': 1, '5': 1, '10': 'originLng'},
    {'1': 'received_lat', '3': 13, '4': 1, '5': 1, '10': 'receivedLat'},
    {'1': 'received_lng', '3': 14, '4': 1, '5': 1, '10': 'receivedLng'},
    {'1': 'chunk_index', '3': 9, '4': 1, '5': 5, '10': 'chunkIndex'},
    {'1': 'total_chunks', '3': 10, '4': 1, '5': 5, '10': 'totalChunks'},
    {'1': 'payload', '3': 11, '4': 1, '5': 12, '10': 'payload'},
    {'1': 'signature', '3': 12, '4': 1, '5': 12, '10': 'signature'},
  ],
};

/// Descriptor for `MeshEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List meshEventDescriptor = $convert.base64Decode(
    'CglNZXNoRXZlbnQSGQoIZXZlbnRfaWQYASABKAlSB2V2ZW50SWQSJAoOc2VuZGVyX3B1Yl9rZX'
    'kYAiABKAxSDHNlbmRlclB1YktleRIlCg5pZGVudGl0eV9sZXZlbBgDIAEoDVINaWRlbnRpdHlM'
    'ZXZlbBInCgR0eXBlGAQgASgOMhMucmVzcW1lc2guRXZlbnRUeXBlUgR0eXBlEjAKB3VyZ2VuY3'
    'kYBSABKA4yFi5yZXNxbWVzaC5VcmdlbmN5TGV2ZWxSB3VyZ2VuY3kSIwoNaGxjX3RpbWVzdGFt'
    'cBgGIAEoA1IMaGxjVGltZXN0YW1wEh8KC2hsY19jb3VudGVyGAcgASgDUgpobGNDb3VudGVyEh'
    'AKA3R0bBgIIAEoBVIDdHRsEh0KCm9yaWdpbl9sYXQYDyABKAFSCW9yaWdpbkxhdBIdCgpvcmln'
    'aW5fbG5nGBAgASgBUglvcmlnaW5MbmcSIQoMcmVjZWl2ZWRfbGF0GA0gASgBUgtyZWNlaXZlZE'
    'xhdBIhCgxyZWNlaXZlZF9sbmcYDiABKAFSC3JlY2VpdmVkTG5nEh8KC2NodW5rX2luZGV4GAkg'
    'ASgFUgpjaHVua0luZGV4EiEKDHRvdGFsX2NodW5rcxgKIAEoBVILdG90YWxDaHVua3MSGAoHcG'
    'F5bG9hZBgLIAEoDFIHcGF5bG9hZBIcCglzaWduYXR1cmUYDCABKAxSCXNpZ25hdHVyZQ==');

@$core.Deprecated('Use bloomFilterSyncDescriptor instead')
const BloomFilterSync$json = {
  '1': 'BloomFilterSync',
  '2': [
    {'1': 'filter_data', '3': 1, '4': 1, '5': 12, '10': 'filterData'},
    {'1': 'num_hash_funcs', '3': 2, '4': 1, '5': 5, '10': 'numHashFuncs'},
    {'1': 'capacity', '3': 3, '4': 1, '5': 5, '10': 'capacity'},
  ],
};

/// Descriptor for `BloomFilterSync`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bloomFilterSyncDescriptor = $convert.base64Decode(
    'Cg9CbG9vbUZpbHRlclN5bmMSHwoLZmlsdGVyX2RhdGEYASABKAxSCmZpbHRlckRhdGESJAoObn'
    'VtX2hhc2hfZnVuY3MYAiABKAVSDG51bUhhc2hGdW5jcxIaCghjYXBhY2l0eRgDIAEoBVIIY2Fw'
    'YWNpdHk=');

@$core.Deprecated('Use resourceDataDescriptor instead')
const ResourceData$json = {
  '1': 'ResourceData',
  '2': [
    {'1': 'resource_id', '3': 1, '4': 1, '5': 9, '10': 'resourceId'},
    {'1': 'resource_type', '3': 2, '4': 1, '5': 9, '10': 'resourceType'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'quantity', '3': 4, '4': 1, '5': 2, '10': 'quantity'},
    {'1': 'unit', '3': 5, '4': 1, '5': 9, '10': 'unit'},
    {'1': 'max_range_meters', '3': 6, '4': 1, '5': 2, '10': 'maxRangeMeters'},
    {'1': 'lat', '3': 7, '4': 1, '5': 1, '10': 'lat'},
    {'1': 'lng', '3': 8, '4': 1, '5': 1, '10': 'lng'},
    {'1': 'expires_at', '3': 9, '4': 1, '5': 3, '10': 'expiresAt'},
    {'1': 'is_station', '3': 10, '4': 1, '5': 8, '10': 'isStation'},
    {'1': 'per_user_category_limit', '3': 11, '4': 1, '5': 5, '10': 'perUserCategoryLimit'},
    {'1': 'per_user_total_limit', '3': 12, '4': 1, '5': 5, '10': 'perUserTotalLimit'},
    {'1': 'reset_interval_ms', '3': 13, '4': 1, '5': 3, '10': 'resetIntervalMs'},
    {'1': 'visible_zones', '3': 14, '4': 3, '5': 9, '10': 'visibleZones'},
    {'1': 'visible_township', '3': 15, '4': 1, '5': 9, '10': 'visibleTownship'},
  ],
};

/// Descriptor for `ResourceData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resourceDataDescriptor = $convert.base64Decode(
    'CgxSZXNvdXJjZURhdGESHwoLcmVzb3VyY2VfaWQYASABKAlSCnJlc291cmNlSWQSIwoNcmVzb3'
    'VyY2VfdHlwZRgCIAEoCVIMcmVzb3VyY2VUeXBlEiAKC2Rlc2NyaXB0aW9uGAMgASgJUgtkZXNj'
    'cmlwdGlvbhIaCghxdWFudGl0eRgEIAEoAlIIcXVhbnRpdHkSEgoEdW5pdBgFIAEoCVIEdW5pdB'
    'IoChBtYXhfcmFuZ2VfbWV0ZXJzGAYgASgCUg5tYXhSYW5nZU1ldGVycxIQCgNsYXQYByABKAFS'
    'A2xhdBIQCgNsbmcYCCABKAFSA2xuZxIdCgpleHBpcmVzX2F0GAkgASgDUglleHBpcmVzQXQSHQ'
    'oKaXNfc3RhdGlvbhgKIAEoCFIJaXNTdGF0aW9uEjUKF3Blcl91c2VyX2NhdGVnb3J5X2xpbWl0'
    'GAsgASgFUhRwZXJVc2VyQ2F0ZWdvcnlMaW1pdBIvChRwZXJfdXNlcl90b3RhbF9saW1pdBgMIA'
    'EoBVIRcGVyVXNlclRvdGFsTGltaXQSKgoRcmVzZXRfaW50ZXJ2YWxfbXMYDSABKANSD3Jlc2V0'
    'SW50ZXJ2YWxNcxIjCg12aXNpYmxlX3pvbmVzGA4gAygJUgx2aXNpYmxlWm9uZXMSKQoQdmlzaW'
    'JsZV90b3duc2hpcBgPIAEoCVIPdmlzaWJsZVRvd25zaGlw');

@$core.Deprecated('Use requestDataDescriptor instead')
const RequestData$json = {
  '1': 'RequestData',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'resource_type', '3': 2, '4': 1, '5': 9, '10': 'resourceType'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'quantity_needed', '3': 4, '4': 1, '5': 2, '10': 'quantityNeeded'},
    {'1': 'urgency', '3': 5, '4': 1, '5': 14, '6': '.resqmesh.UrgencyLevel', '10': 'urgency'},
    {'1': 'lat', '3': 6, '4': 1, '5': 1, '10': 'lat'},
    {'1': 'lng', '3': 7, '4': 1, '5': 1, '10': 'lng'},
    {'1': 'max_range_meters', '3': 8, '4': 1, '5': 2, '10': 'maxRangeMeters'},
  ],
};

/// Descriptor for `RequestData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List requestDataDescriptor = $convert.base64Decode(
    'CgtSZXF1ZXN0RGF0YRIdCgpyZXF1ZXN0X2lkGAEgASgJUglyZXF1ZXN0SWQSIwoNcmVzb3VyY2'
    'VfdHlwZRgCIAEoCVIMcmVzb3VyY2VUeXBlEiAKC2Rlc2NyaXB0aW9uGAMgASgJUgtkZXNjcmlw'
    'dGlvbhInCg9xdWFudGl0eV9uZWVkZWQYBCABKAJSDnF1YW50aXR5TmVlZGVkEjAKB3VyZ2VuY3'
    'kYBSABKA4yFi5yZXNxbWVzaC5VcmdlbmN5TGV2ZWxSB3VyZ2VuY3kSEAoDbGF0GAYgASgBUgNs'
    'YXQSEAoDbG5nGAcgASgBUgNsbmcSKAoQbWF4X3JhbmdlX21ldGVycxgIIAEoAlIObWF4UmFuZ2'
    'VNZXRlcnM=');

@$core.Deprecated('Use matchIntentDataDescriptor instead')
const MatchIntentData$json = {
  '1': 'MatchIntentData',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'resource_id', '3': 2, '4': 1, '5': 9, '10': 'resourceId'},
    {'1': 'requester_pub_key', '3': 3, '4': 1, '5': 12, '10': 'requesterPubKey'},
    {'1': 'provider_pub_key', '3': 4, '4': 1, '5': 12, '10': 'providerPubKey'},
    {'1': 'match_score', '3': 5, '4': 1, '5': 2, '10': 'matchScore'},
    {'1': 'match_expires_at', '3': 6, '4': 1, '5': 3, '10': 'matchExpiresAt'},
  ],
};

/// Descriptor for `MatchIntentData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List matchIntentDataDescriptor = $convert.base64Decode(
    'Cg9NYXRjaEludGVudERhdGESHQoKcmVxdWVzdF9pZBgBIAEoCVIJcmVxdWVzdElkEh8KC3Jlc2'
    '91cmNlX2lkGAIgASgJUgpyZXNvdXJjZUlkEioKEXJlcXVlc3Rlcl9wdWJfa2V5GAMgASgMUg9y'
    'ZXF1ZXN0ZXJQdWJLZXkSKAoQcHJvdmlkZXJfcHViX2tleRgEIAEoDFIOcHJvdmlkZXJQdWJLZX'
    'kSHwoLbWF0Y2hfc2NvcmUYBSABKAJSCm1hdGNoU2NvcmUSKAoQbWF0Y2hfZXhwaXJlc19hdBgG'
    'IAEoA1IObWF0Y2hFeHBpcmVzQXQ=');

@$core.Deprecated('Use physicalHandshakeDataDescriptor instead')
const PhysicalHandshakeData$json = {
  '1': 'PhysicalHandshakeData',
  '2': [
    {'1': 'resource_id', '3': 1, '4': 1, '5': 9, '10': 'resourceId'},
    {'1': 'request_id', '3': 2, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'requester_pub_key', '3': 3, '4': 1, '5': 12, '10': 'requesterPubKey'},
    {'1': 'provider_pub_key', '3': 4, '4': 1, '5': 12, '10': 'providerPubKey'},
    {'1': 'requester_signature', '3': 5, '4': 1, '5': 12, '10': 'requesterSignature'},
    {'1': 'provider_signature', '3': 6, '4': 1, '5': 12, '10': 'providerSignature'},
    {'1': 'method', '3': 7, '4': 1, '5': 9, '10': 'method'},
  ],
};

/// Descriptor for `PhysicalHandshakeData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List physicalHandshakeDataDescriptor = $convert.base64Decode(
    'ChVQaHlzaWNhbEhhbmRzaGFrZURhdGESHwoLcmVzb3VyY2VfaWQYASABKAlSCnJlc291cmNlSW'
    'QSHQoKcmVxdWVzdF9pZBgCIAEoCVIJcmVxdWVzdElkEioKEXJlcXVlc3Rlcl9wdWJfa2V5GAMg'
    'ASgMUg9yZXF1ZXN0ZXJQdWJLZXkSKAoQcHJvdmlkZXJfcHViX2tleRgEIAEoDFIOcHJvdmlkZX'
    'JQdWJLZXkSLwoTcmVxdWVzdGVyX3NpZ25hdHVyZRgFIAEoDFIScmVxdWVzdGVyU2lnbmF0dXJl'
    'Ei0KEnByb3ZpZGVyX3NpZ25hdHVyZRgGIAEoDFIRcHJvdmlkZXJTaWduYXR1cmUSFgoGbWV0aG'
    '9kGAcgASgJUgZtZXRob2Q=');

@$core.Deprecated('Use hazardDataDescriptor instead')
const HazardData$json = {
  '1': 'HazardData',
  '2': [
    {'1': 'hazard_id', '3': 1, '4': 1, '5': 9, '10': 'hazardId'},
    {'1': 'hazard_type', '3': 2, '4': 1, '5': 9, '10': 'hazardType'},
    {'1': 'severity', '3': 3, '4': 1, '5': 13, '10': 'severity'},
    {'1': 'center_lat', '3': 4, '4': 1, '5': 1, '10': 'centerLat'},
    {'1': 'center_lng', '3': 5, '4': 1, '5': 1, '10': 'centerLng'},
    {'1': 'radius_meters', '3': 6, '4': 1, '5': 2, '10': 'radiusMeters'},
    {'1': 'observed_at', '3': 7, '4': 1, '5': 3, '10': 'observedAt'},
    {'1': 'description', '3': 8, '4': 1, '5': 9, '10': 'description'},
  ],
};

/// Descriptor for `HazardData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List hazardDataDescriptor = $convert.base64Decode(
    'CgpIYXphcmREYXRhEhsKCWhhemFyZF9pZBgBIAEoCVIIaGF6YXJkSWQSHwoLaGF6YXJkX3R5cG'
    'UYAiABKAlSCmhhemFyZFR5cGUSGgoIc2V2ZXJpdHkYAyABKA1SCHNldmVyaXR5Eh0KCmNlbnRl'
    'cl9sYXQYBCABKAFSCWNlbnRlckxhdBIdCgpjZW50ZXJfbG5nGAUgASgBUgljZW50ZXJMbmcSIw'
    'oNcmFkaXVzX21ldGVycxgGIAEoAlIMcmFkaXVzTWV0ZXJzEh8KC29ic2VydmVkX2F0GAcgASgD'
    'UgpvYnNlcnZlZEF0EiAKC2Rlc2NyaXB0aW9uGAggASgJUgtkZXNjcmlwdGlvbg==');

@$core.Deprecated('Use hazardConfirmDataDescriptor instead')
const HazardConfirmData$json = {
  '1': 'HazardConfirmData',
  '2': [
    {'1': 'hazard_id', '3': 1, '4': 1, '5': 9, '10': 'hazardId'},
    {'1': 'hazard_type', '3': 2, '4': 1, '5': 9, '10': 'hazardType'},
    {'1': 'severity', '3': 3, '4': 1, '5': 13, '10': 'severity'},
    {'1': 'center_lat', '3': 4, '4': 1, '5': 1, '10': 'centerLat'},
    {'1': 'center_lng', '3': 5, '4': 1, '5': 1, '10': 'centerLng'},
    {'1': 'radius_meters', '3': 6, '4': 1, '5': 2, '10': 'radiusMeters'},
    {'1': 'observed_at', '3': 7, '4': 1, '5': 3, '10': 'observedAt'},
    {'1': 'description', '3': 8, '4': 1, '5': 9, '10': 'description'},
    {'1': 'confirmer_pub_key', '3': 9, '4': 1, '5': 12, '10': 'confirmerPubKey'},
  ],
};

/// Descriptor for `HazardConfirmData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List hazardConfirmDataDescriptor = $convert.base64Decode(
    'ChFIYXphcmRDb25maXJtRGF0YRIbCgloYXphcmRfaWQYASABKAlSCGhhemFyZElkEh8KC2hhem'
    'FyZF90eXBlGAIgASgJUgpoYXphcmRUeXBlEhoKCHNldmVyaXR5GAMgASgNUghzZXZlcml0eRId'
    'CgpjZW50ZXJfbGF0GAQgASgBUgljZW50ZXJMYXQSHQoKY2VudGVyX2xuZxgFIAEoAVIJY2VudG'
    'VyTG5nEiMKDXJhZGl1c19tZXRlcnMYBiABKAJSDHJhZGl1c01ldGVycxIfCgtvYnNlcnZlZF9h'
    'dBgHIAEoA1IKb2JzZXJ2ZWRBdBIgCgtkZXNjcmlwdGlvbhgIIAEoCVILZGVzY3JpcHRpb24SKg'
    'oRY29uZmlybWVyX3B1Yl9rZXkYCSABKAxSD2NvbmZpcm1lclB1YktleQ==');

@$core.Deprecated('Use quarantineVoteDataDescriptor instead')
const QuarantineVoteData$json = {
  '1': 'QuarantineVoteData',
  '2': [
    {'1': 'target_pub_key', '3': 1, '4': 1, '5': 12, '10': 'targetPubKey'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'vote_weight', '3': 3, '4': 1, '5': 2, '10': 'voteWeight'},
  ],
};

/// Descriptor for `QuarantineVoteData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List quarantineVoteDataDescriptor = $convert.base64Decode(
    'ChJRdWFyYW50aW5lVm90ZURhdGESJAoOdGFyZ2V0X3B1Yl9rZXkYASABKAxSDHRhcmdldFB1Yk'
    'tleRIWCgZyZWFzb24YAiABKAlSBnJlYXNvbhIfCgt2b3RlX3dlaWdodBgDIAEoAlIKdm90ZVdl'
    'aWdodA==');

@$core.Deprecated('Use matchCancelDataDescriptor instead')
const MatchCancelData$json = {
  '1': 'MatchCancelData',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'resource_id', '3': 2, '4': 1, '5': 9, '10': 'resourceId'},
    {'1': 'reason', '3': 3, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `MatchCancelData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List matchCancelDataDescriptor = $convert.base64Decode(
    'Cg9NYXRjaENhbmNlbERhdGESHQoKcmVxdWVzdF9pZBgBIAEoCVIJcmVxdWVzdElkEh8KC3Jlc2'
    '91cmNlX2lkGAIgASgJUgpyZXNvdXJjZUlkEhYKBnJlYXNvbhgDIAEoCVIGcmVhc29u');

@$core.Deprecated('Use medicalSummaryDescriptor instead')
const MedicalSummary$json = {
  '1': 'MedicalSummary',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
    {'1': 'age', '3': 2, '4': 1, '5': 5, '9': 1, '10': 'age', '17': true},
    {'1': 'height_cm', '3': 3, '4': 1, '5': 5, '9': 2, '10': 'heightCm', '17': true},
    {'1': 'weight_kg', '3': 4, '4': 1, '5': 5, '9': 3, '10': 'weightKg', '17': true},
    {'1': 'blood_type', '3': 5, '4': 1, '5': 9, '9': 4, '10': 'bloodType', '17': true},
    {'1': 'conditions', '3': 6, '4': 3, '5': 9, '10': 'conditions'},
    {'1': 'allergies', '3': 7, '4': 3, '5': 11, '6': '.resqmesh.AllergyEntry', '10': 'allergies'},
    {'1': 'medications', '3': 8, '4': 3, '5': 9, '10': 'medications'},
    {'1': 'emergency_contact', '3': 9, '4': 1, '5': 11, '6': '.resqmesh.EmergencyContact', '9': 5, '10': 'emergencyContact', '17': true},
    {'1': 'organ_donor', '3': 10, '4': 1, '5': 8, '9': 6, '10': 'organDonor', '17': true},
    {'1': 'primary_language', '3': 11, '4': 1, '5': 9, '9': 7, '10': 'primaryLanguage', '17': true},
  ],
  '8': [
    {'1': '_name'},
    {'1': '_age'},
    {'1': '_height_cm'},
    {'1': '_weight_kg'},
    {'1': '_blood_type'},
    {'1': '_emergency_contact'},
    {'1': '_organ_donor'},
    {'1': '_primary_language'},
  ],
};

/// Descriptor for `MedicalSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List medicalSummaryDescriptor = $convert.base64Decode(
    'Cg5NZWRpY2FsU3VtbWFyeRIXCgRuYW1lGAEgASgJSABSBG5hbWWIAQESFQoDYWdlGAIgASgFSA'
    'FSA2FnZYgBARIgCgloZWlnaHRfY20YAyABKAVIAlIIaGVpZ2h0Q22IAQESIAoJd2VpZ2h0X2tn'
    'GAQgASgFSANSCHdlaWdodEtniAEBEiIKCmJsb29kX3R5cGUYBSABKAlIBFIJYmxvb2RUeXBliA'
    'EBEh4KCmNvbmRpdGlvbnMYBiADKAlSCmNvbmRpdGlvbnMSNAoJYWxsZXJnaWVzGAcgAygLMhYu'
    'cmVzcW1lc2guQWxsZXJneUVudHJ5UglhbGxlcmdpZXMSIAoLbWVkaWNhdGlvbnMYCCADKAlSC2'
    '1lZGljYXRpb25zEkwKEWVtZXJnZW5jeV9jb250YWN0GAkgASgLMhoucmVzcW1lc2guRW1lcmdl'
    'bmN5Q29udGFjdEgFUhBlbWVyZ2VuY3lDb250YWN0iAEBEiQKC29yZ2FuX2Rvbm9yGAogASgISA'
    'ZSCm9yZ2FuRG9ub3KIAQESLgoQcHJpbWFyeV9sYW5ndWFnZRgLIAEoCUgHUg9wcmltYXJ5TGFu'
    'Z3VhZ2WIAQFCBwoFX25hbWVCBgoEX2FnZUIMCgpfaGVpZ2h0X2NtQgwKCl93ZWlnaHRfa2dCDQ'
    'oLX2Jsb29kX3R5cGVCFAoSX2VtZXJnZW5jeV9jb250YWN0Qg4KDF9vcmdhbl9kb25vckITChFf'
    'cHJpbWFyeV9sYW5ndWFnZQ==');

@$core.Deprecated('Use allergyEntryDescriptor instead')
const AllergyEntry$json = {
  '1': 'AllergyEntry',
  '2': [
    {'1': 'allergen', '3': 1, '4': 1, '5': 9, '10': 'allergen'},
    {'1': 'reaction', '3': 2, '4': 1, '5': 9, '10': 'reaction'},
  ],
};

/// Descriptor for `AllergyEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List allergyEntryDescriptor = $convert.base64Decode(
    'CgxBbGxlcmd5RW50cnkSGgoIYWxsZXJnZW4YASABKAlSCGFsbGVyZ2VuEhoKCHJlYWN0aW9uGA'
    'IgASgJUghyZWFjdGlvbg==');

@$core.Deprecated('Use emergencyContactDescriptor instead')
const EmergencyContact$json = {
  '1': 'EmergencyContact',
  '2': [
    {'1': 'phone', '3': 1, '4': 1, '5': 9, '10': 'phone'},
    {'1': 'relation', '3': 2, '4': 1, '5': 9, '10': 'relation'},
  ],
};

/// Descriptor for `EmergencyContact`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List emergencyContactDescriptor = $convert.base64Decode(
    'ChBFbWVyZ2VuY3lDb250YWN0EhQKBXBob25lGAEgASgJUgVwaG9uZRIaCghyZWxhdGlvbhgCIA'
    'EoCVIIcmVsYXRpb24=');

@$core.Deprecated('Use fireAlarmRfDataDescriptor instead')
const FireAlarmRfData$json = {
  '1': 'FireAlarmRfData',
  '2': [
    {'1': 'detector_brand', '3': 1, '4': 1, '5': 9, '10': 'detectorBrand'},
    {'1': 'rf_frequency_mhz', '3': 2, '4': 1, '5': 13, '10': 'rfFrequencyMhz'},
    {'1': 'station_lat', '3': 3, '4': 1, '5': 1, '10': 'stationLat'},
    {'1': 'station_lng', '3': 4, '4': 1, '5': 1, '10': 'stationLng'},
    {'1': 'rssi_dbm', '3': 5, '4': 1, '5': 5, '10': 'rssiDbm'},
    {'1': 'detected_at', '3': 6, '4': 1, '5': 3, '10': 'detectedAt'},
    {'1': 'raw_rf_payload', '3': 7, '4': 1, '5': 12, '10': 'rawRfPayload'},
  ],
};

/// Descriptor for `FireAlarmRfData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fireAlarmRfDataDescriptor = $convert.base64Decode(
    'Cg9GaXJlQWxhcm1SZkRhdGESJQoOZGV0ZWN0b3JfYnJhbmQYASABKAlSDWRldGVjdG9yQnJhbm'
    'QSKAoQcmZfZnJlcXVlbmN5X21oehgCIAEoDVIOcmZGcmVxdWVuY3lNaHoSHwoLc3RhdGlvbl9s'
    'YXQYAyABKAFSCnN0YXRpb25MYXQSHwoLc3RhdGlvbl9sbmcYBCABKAFSCnN0YXRpb25MbmcSGQ'
    'oIcnNzaV9kYm0YBSABKAVSB3Jzc2lEYm0SHwoLZGV0ZWN0ZWRfYXQYBiABKANSCmRldGVjdGVk'
    'QXQSJAoOcmF3X3JmX3BheWxvYWQYByABKAxSDHJhd1JmUGF5bG9hZA==');

@$core.Deprecated('Use matchConfirmDataDescriptor instead')
const MatchConfirmData$json = {
  '1': 'MatchConfirmData',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'resource_id', '3': 2, '4': 1, '5': 9, '10': 'resourceId'},
    {'1': 'requester_pub_key', '3': 3, '4': 1, '5': 12, '10': 'requesterPubKey'},
    {'1': 'provider_pub_key', '3': 4, '4': 1, '5': 12, '10': 'providerPubKey'},
  ],
};

/// Descriptor for `MatchConfirmData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List matchConfirmDataDescriptor = $convert.base64Decode(
    'ChBNYXRjaENvbmZpcm1EYXRhEh0KCnJlcXVlc3RfaWQYASABKAlSCXJlcXVlc3RJZBIfCgtyZX'
    'NvdXJjZV9pZBgCIAEoCVIKcmVzb3VyY2VJZBIqChFyZXF1ZXN0ZXJfcHViX2tleRgDIAEoDFIP'
    'cmVxdWVzdGVyUHViS2V5EigKEHByb3ZpZGVyX3B1Yl9rZXkYBCABKAxSDnByb3ZpZGVyUHViS2'
    'V5');

@$core.Deprecated('Use matchRejectDataDescriptor instead')
const MatchRejectData$json = {
  '1': 'MatchRejectData',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'resource_id', '3': 2, '4': 1, '5': 9, '10': 'resourceId'},
    {'1': 'requester_pub_key', '3': 3, '4': 1, '5': 12, '10': 'requesterPubKey'},
    {'1': 'provider_pub_key', '3': 4, '4': 1, '5': 12, '10': 'providerPubKey'},
    {'1': 'reason', '3': 5, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `MatchRejectData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List matchRejectDataDescriptor = $convert.base64Decode(
    'Cg9NYXRjaFJlamVjdERhdGESHQoKcmVxdWVzdF9pZBgBIAEoCVIJcmVxdWVzdElkEh8KC3Jlc2'
    '91cmNlX2lkGAIgASgJUgpyZXNvdXJjZUlkEioKEXJlcXVlc3Rlcl9wdWJfa2V5GAMgASgMUg9y'
    'ZXF1ZXN0ZXJQdWJLZXkSKAoQcHJvdmlkZXJfcHViX2tleRgEIAEoDFIOcHJvdmlkZXJQdWJLZX'
    'kSFgoGcmVhc29uGAUgASgJUgZyZWFzb24=');

@$core.Deprecated('Use matchInquiryDataDescriptor instead')
const MatchInquiryData$json = {
  '1': 'MatchInquiryData',
  '2': [
    {'1': 'resource_id', '3': 1, '4': 1, '5': 9, '10': 'resourceId'},
    {'1': 'inquirer_pub_key', '3': 2, '4': 1, '5': 12, '10': 'inquirerPubKey'},
    {'1': 'inquiry_id', '3': 3, '4': 1, '5': 9, '10': 'inquiryId'},
  ],
};

/// Descriptor for `MatchInquiryData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List matchInquiryDataDescriptor = $convert.base64Decode(
    'ChBNYXRjaElucXVpcnlEYXRhEh8KC3Jlc291cmNlX2lkGAEgASgJUgpyZXNvdXJjZUlkEigKEG'
    'lucXVpcmVyX3B1Yl9rZXkYAiABKAxSDmlucXVpcmVyUHViS2V5Eh0KCmlucXVpcnlfaWQYAyAB'
    'KAlSCWlucXVpcnlJZA==');

@$core.Deprecated('Use matchInquiryResponseDescriptor instead')
const MatchInquiryResponse$json = {
  '1': 'MatchInquiryResponse',
  '2': [
    {'1': 'inquiry_id', '3': 1, '4': 1, '5': 9, '10': 'inquiryId'},
    {'1': 'resource_id', '3': 2, '4': 1, '5': 9, '10': 'resourceId'},
    {'1': 'is_available', '3': 3, '4': 1, '5': 8, '10': 'isAvailable'},
  ],
};

/// Descriptor for `MatchInquiryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List matchInquiryResponseDescriptor = $convert.base64Decode(
    'ChRNYXRjaElucXVpcnlSZXNwb25zZRIdCgppbnF1aXJ5X2lkGAEgASgJUglpbnF1aXJ5SWQSHw'
    'oLcmVzb3VyY2VfaWQYAiABKAlSCnJlc291cmNlSWQSIQoMaXNfYXZhaWxhYmxlGAMgASgIUgtp'
    'c0F2YWlsYWJsZQ==');

@$core.Deprecated('Use chatMessageDataDescriptor instead')
const ChatMessageData$json = {
  '1': 'ChatMessageData',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'room_type', '3': 2, '4': 1, '5': 9, '10': 'roomType'},
    {'1': 'content', '3': 3, '4': 1, '5': 9, '10': 'content'},
    {'1': 'reply_to', '3': 4, '4': 1, '5': 9, '10': 'replyTo'},
  ],
};

/// Descriptor for `ChatMessageData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatMessageDataDescriptor = $convert.base64Decode(
    'Cg9DaGF0TWVzc2FnZURhdGESFwoHcm9vbV9pZBgBIAEoCVIGcm9vbUlkEhsKCXJvb21fdHlwZR'
    'gCIAEoCVIIcm9vbVR5cGUSGAoHY29udGVudBgDIAEoCVIHY29udGVudBIZCghyZXBseV90bxgE'
    'IAEoCVIHcmVwbHlUbw==');

@$core.Deprecated('Use matchLocationUpdateDataDescriptor instead')
const MatchLocationUpdateData$json = {
  '1': 'MatchLocationUpdateData',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'resource_id', '3': 2, '4': 1, '5': 9, '10': 'resourceId'},
    {'1': 'requester_pub_key', '3': 3, '4': 1, '5': 12, '10': 'requesterPubKey'},
    {'1': 'provider_pub_key', '3': 4, '4': 1, '5': 12, '10': 'providerPubKey'},
    {'1': 'sender_pub_key', '3': 5, '4': 1, '5': 12, '10': 'senderPubKey'},
    {'1': 'lat', '3': 6, '4': 1, '5': 1, '10': 'lat'},
    {'1': 'lng', '3': 7, '4': 1, '5': 1, '10': 'lng'},
    {'1': 'observed_at', '3': 8, '4': 1, '5': 3, '10': 'observedAt'},
  ],
};

/// Descriptor for `MatchLocationUpdateData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List matchLocationUpdateDataDescriptor = $convert.base64Decode(
    'ChdNYXRjaExvY2F0aW9uVXBkYXRlRGF0YRIdCgpyZXF1ZXN0X2lkGAEgASgJUglyZXF1ZXN0SW'
    'QSHwoLcmVzb3VyY2VfaWQYAiABKAlSCnJlc291cmNlSWQSKgoRcmVxdWVzdGVyX3B1Yl9rZXkY'
    'AyABKAxSD3JlcXVlc3RlclB1YktleRIoChBwcm92aWRlcl9wdWJfa2V5GAQgASgMUg5wcm92aW'
    'RlclB1YktleRIkCg5zZW5kZXJfcHViX2tleRgFIAEoDFIMc2VuZGVyUHViS2V5EhAKA2xhdBgG'
    'IAEoAVIDbGF0EhAKA2xuZxgHIAEoAVIDbG5nEh8KC29ic2VydmVkX2F0GAggASgDUgpvYnNlcn'
    'ZlZEF0');

@$core.Deprecated('Use chatRoomConfigDescriptor instead')
const ChatRoomConfig$json = {
  '1': 'ChatRoomConfig',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'room_name', '3': 2, '4': 1, '5': 9, '10': 'roomName'},
    {'1': 'room_type', '3': 3, '4': 1, '5': 9, '10': 'roomType'},
    {'1': 'rate_limit_seconds', '3': 4, '4': 1, '5': 5, '10': 'rateLimitSeconds'},
    {'1': 'admin_only', '3': 5, '4': 1, '5': 8, '10': 'adminOnly'},
    {'1': 'join_token_hash', '3': 6, '4': 1, '5': 9, '10': 'joinTokenHash'},
    {'1': 'admin_pub_keys', '3': 7, '4': 3, '5': 12, '10': 'adminPubKeys'},
  ],
};

/// Descriptor for `ChatRoomConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatRoomConfigDescriptor = $convert.base64Decode(
    'Cg5DaGF0Um9vbUNvbmZpZxIXCgdyb29tX2lkGAEgASgJUgZyb29tSWQSGwoJcm9vbV9uYW1lGA'
    'IgASgJUghyb29tTmFtZRIbCglyb29tX3R5cGUYAyABKAlSCHJvb21UeXBlEiwKEnJhdGVfbGlt'
    'aXRfc2Vjb25kcxgEIAEoBVIQcmF0ZUxpbWl0U2Vjb25kcxIdCgphZG1pbl9vbmx5GAUgASgIUg'
    'lhZG1pbk9ubHkSJgoPam9pbl90b2tlbl9oYXNoGAYgASgJUg1qb2luVG9rZW5IYXNoEiQKDmFk'
    'bWluX3B1Yl9rZXlzGAcgAygMUgxhZG1pblB1YktleXM=');

@$core.Deprecated('Use meshEnvelopeDescriptor instead')
const MeshEnvelope$json = {
  '1': 'MeshEnvelope',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 14, '6': '.resqmesh.EnvelopeType', '10': 'type'},
    {'1': 'payload', '3': 2, '4': 1, '5': 12, '10': 'payload'},
    {'1': 'sender_id', '3': 3, '4': 1, '5': 9, '10': 'senderId'},
  ],
};

/// Descriptor for `MeshEnvelope`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List meshEnvelopeDescriptor = $convert.base64Decode(
    'CgxNZXNoRW52ZWxvcGUSKgoEdHlwZRgBIAEoDjIWLnJlc3FtZXNoLkVudmVsb3BlVHlwZVIEdH'
    'lwZRIYCgdwYXlsb2FkGAIgASgMUgdwYXlsb2FkEhsKCXNlbmRlcl9pZBgDIAEoCVIIc2VuZGVy'
    'SWQ=');

