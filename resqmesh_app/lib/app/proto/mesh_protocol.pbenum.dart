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

import 'package:protobuf/protobuf.dart' as $pb;

/// 定義事件型別
class EventType extends $pb.ProtobufEnum {
  static const EventType RESOURCE_REGISTER = EventType._(0, _omitEnumNames ? '' : 'RESOURCE_REGISTER');
  static const EventType REQUEST_BROADCAST = EventType._(1, _omitEnumNames ? '' : 'REQUEST_BROADCAST');
  static const EventType MATCH_INTENT = EventType._(2, _omitEnumNames ? '' : 'MATCH_INTENT');
  static const EventType PHYSICAL_HANDSHAKE = EventType._(3, _omitEnumNames ? '' : 'PHYSICAL_HANDSHAKE');
  static const EventType HAZARD_MARKER = EventType._(4, _omitEnumNames ? '' : 'HAZARD_MARKER');
  static const EventType QUARANTINE_VOTE = EventType._(5, _omitEnumNames ? '' : 'QUARANTINE_VOTE');
  static const EventType MATCH_CANCEL = EventType._(6, _omitEnumNames ? '' : 'MATCH_CANCEL');
  static const EventType FIRE_ALARM_RF = EventType._(7, _omitEnumNames ? '' : 'FIRE_ALARM_RF');
  static const EventType MATCH_CONFIRM = EventType._(8, _omitEnumNames ? '' : 'MATCH_CONFIRM');
  static const EventType MATCH_REJECT = EventType._(9, _omitEnumNames ? '' : 'MATCH_REJECT');
  static const EventType MATCH_INQUIRY = EventType._(10, _omitEnumNames ? '' : 'MATCH_INQUIRY');
  static const EventType MATCH_AVAILABLE = EventType._(11, _omitEnumNames ? '' : 'MATCH_AVAILABLE');
  static const EventType MATCH_GONE = EventType._(12, _omitEnumNames ? '' : 'MATCH_GONE');
  static const EventType CHAT_MESSAGE = EventType._(13, _omitEnumNames ? '' : 'CHAT_MESSAGE');
  static const EventType LOCATION_UPDATE = EventType._(14, _omitEnumNames ? '' : 'LOCATION_UPDATE');
  static const EventType MATCH_REQUEST = EventType._(15, _omitEnumNames ? '' : 'MATCH_REQUEST');
  static const EventType HANDSHAKE_COMPLETE = EventType._(16, _omitEnumNames ? '' : 'HANDSHAKE_COMPLETE');
  static const EventType STATION_CLAIM = EventType._(17, _omitEnumNames ? '' : 'STATION_CLAIM');
  static const EventType STATION_RESPONSE = EventType._(18, _omitEnumNames ? '' : 'STATION_RESPONSE');

  static const $core.List<EventType> values = <EventType> [
    RESOURCE_REGISTER,
    REQUEST_BROADCAST,
    MATCH_INTENT,
    PHYSICAL_HANDSHAKE,
    HAZARD_MARKER,
    QUARANTINE_VOTE,
    MATCH_CANCEL,
    FIRE_ALARM_RF,
    MATCH_CONFIRM,
    MATCH_REJECT,
    MATCH_INQUIRY,
    MATCH_AVAILABLE,
    MATCH_GONE,
    CHAT_MESSAGE,
    LOCATION_UPDATE,
    MATCH_REQUEST,
    HANDSHAKE_COMPLETE,
    STATION_CLAIM,
    STATION_RESPONSE,
  ];

  static final $core.Map<$core.int, EventType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static EventType? valueOf($core.int value) => _byValue[value];

  const EventType._($core.int v, $core.String n) : super(v, n);
}

/// 檢傷及優先級定義 (QoS & Triage)
class UrgencyLevel extends $pb.ProtobufEnum {
  static const UrgencyLevel INFO = UrgencyLevel._(0, _omitEnumNames ? '' : 'INFO');
  static const UrgencyLevel RESOURCE = UrgencyLevel._(1, _omitEnumNames ? '' : 'RESOURCE');
  static const UrgencyLevel SOS_YELLOW = UrgencyLevel._(2, _omitEnumNames ? '' : 'SOS_YELLOW');
  static const UrgencyLevel SOS_RED = UrgencyLevel._(3, _omitEnumNames ? '' : 'SOS_RED');

  static const $core.List<UrgencyLevel> values = <UrgencyLevel> [
    INFO,
    RESOURCE,
    SOS_YELLOW,
    SOS_RED,
  ];

  static final $core.Map<$core.int, UrgencyLevel> _byValue = $pb.ProtobufEnum.initByValue(values);
  static UrgencyLevel? valueOf($core.int value) => _byValue[value];

  const UrgencyLevel._($core.int v, $core.String n) : super(v, n);
}

/// MeshEnvelope 封裝類型（區分 Bloom Filter 交換與事件傳輸）
class EnvelopeType extends $pb.ProtobufEnum {
  static const EnvelopeType ENVELOPE_EVENT = EnvelopeType._(0, _omitEnumNames ? '' : 'ENVELOPE_EVENT');
  static const EnvelopeType ENVELOPE_BLOOM_FILTER = EnvelopeType._(1, _omitEnumNames ? '' : 'ENVELOPE_BLOOM_FILTER');

  static const $core.List<EnvelopeType> values = <EnvelopeType> [
    ENVELOPE_EVENT,
    ENVELOPE_BLOOM_FILTER,
  ];

  static final $core.Map<$core.int, EnvelopeType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static EnvelopeType? valueOf($core.int value) => _byValue[value];

  const EnvelopeType._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
