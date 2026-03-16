// Generated from protos/mesh_protocol.proto — DO NOT EDIT
// ignore_for_file: non_constant_identifier_names, camel_case_types, constant_identifier_names, use_super_parameters
import 'dart:core' as $core;
import 'package:protobuf/protobuf.dart' as $pb;

class EventType extends $pb.ProtobufEnum {
  static const EventType RESOURCE_REGISTER =
      EventType._(0, 'RESOURCE_REGISTER');
  static const EventType REQUEST_BROADCAST =
      EventType._(1, 'REQUEST_BROADCAST');
  static const EventType MATCH_INTENT = EventType._(2, 'MATCH_INTENT');
  static const EventType PHYSICAL_HANDSHAKE =
      EventType._(3, 'PHYSICAL_HANDSHAKE');
  static const EventType HAZARD_MARKER = EventType._(4, 'HAZARD_MARKER');
  static const EventType QUARANTINE_VOTE = EventType._(5, 'QUARANTINE_VOTE');
  static const EventType MATCH_CANCEL = EventType._(6, 'MATCH_CANCEL');
  static const EventType FIRE_ALARM_RF = EventType._(7, 'FIRE_ALARM_RF');

  static const $core.List<EventType> values = <EventType>[
    RESOURCE_REGISTER,
    REQUEST_BROADCAST,
    MATCH_INTENT,
    PHYSICAL_HANDSHAKE,
    HAZARD_MARKER,
    QUARANTINE_VOTE,
    MATCH_CANCEL,
    FIRE_ALARM_RF,
  ];

  static final $core.Map<$core.int, EventType> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static EventType? valueOf($core.int value) => _byValue[value];

  const EventType._($core.int v, $core.String n) : super(v, n);
}

class UrgencyLevel extends $pb.ProtobufEnum {
  static const UrgencyLevel INFO = UrgencyLevel._(0, 'INFO');
  static const UrgencyLevel RESOURCE = UrgencyLevel._(1, 'RESOURCE');
  static const UrgencyLevel SOS_YELLOW = UrgencyLevel._(2, 'SOS_YELLOW');
  static const UrgencyLevel SOS_RED = UrgencyLevel._(3, 'SOS_RED');

  static const $core.List<UrgencyLevel> values = <UrgencyLevel>[
    INFO,
    RESOURCE,
    SOS_YELLOW,
    SOS_RED,
  ];

  static final $core.Map<$core.int, UrgencyLevel> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static UrgencyLevel? valueOf($core.int value) => _byValue[value];

  const UrgencyLevel._($core.int v, $core.String n) : super(v, n);
}

class EnvelopeType extends $pb.ProtobufEnum {
  static const EnvelopeType ENVELOPE_EVENT =
      EnvelopeType._(0, 'ENVELOPE_EVENT');
  static const EnvelopeType ENVELOPE_BLOOM_FILTER =
      EnvelopeType._(1, 'ENVELOPE_BLOOM_FILTER');

  static const $core.List<EnvelopeType> values = <EnvelopeType>[
    ENVELOPE_EVENT,
    ENVELOPE_BLOOM_FILTER,
  ];

  static final $core.Map<$core.int, EnvelopeType> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static EnvelopeType? valueOf($core.int value) => _byValue[value];

  const EnvelopeType._($core.int v, $core.String n) : super(v, n);
}
