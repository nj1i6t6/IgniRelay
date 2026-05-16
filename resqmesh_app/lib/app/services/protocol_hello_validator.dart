// Pure validator for ProtocolHelloData payloads (v0.3 Stage 0c wave 3A).
//
// Spec: docs/specs/native_transport_v1_2026-05-13.md §5.7, §15.9.
//
// Operates on the already-decoded EventEnvelope's `payload` bytes (i.e.,
// the signature has already been verified by EnvelopeDispatcherV2). All
// failure modes here describe a HELLO whose envelope WAS authentic but
// whose contents contradict the spec — see drop-reason constants for the
// spec-named codes that mesh_trace_logs will record.

import 'dart:typed_data';

import 'package:ignirelay_app/app/mesh/capability_profile.dart';
import 'package:ignirelay_app/app/mesh/mesh_constants.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/proto/proto_wire.dart';

/// Outcome of validating one HELLO payload.
class HelloValidationResult {
  /// Decoded HELLO, present iff `isAccepted`.
  final ProtocolHelloData? hello;

  /// Resolved profile, present iff `isAccepted`.
  final CapabilityProfile? profile;

  /// Spec drop-reason code, present iff `!isAccepted`.
  final String? dropReason;

  /// Free-text detail, never null when dropped (for trace logs).
  final String? detail;

  bool get isAccepted => dropReason == null;

  const HelloValidationResult._({
    this.hello,
    this.profile,
    this.dropReason,
    this.detail,
  });

  factory HelloValidationResult.accepted(
    ProtocolHelloData hello,
    CapabilityProfile profile,
  ) =>
      HelloValidationResult._(hello: hello, profile: profile);

  factory HelloValidationResult.dropped(String reason, String detail) =>
      HelloValidationResult._(dropReason: reason, detail: detail);
}

class ProtocolHelloValidator {
  /// §5.7: explicit `peer_kind = PHONE_V1_LEGACY` in HELLO.
  /// Decision §15.9 — drop the connection.
  static const String dropSelfDeclaredLegacy = 'hello-self-declared-legacy';

  /// §5.7: HELLO with `protocol_version != 2`. Receiver disconnects.
  static const String dropProtocolIncompatible =
      'hello-protocol-version-incompatible';

  /// §5.7: malformed HELLO payload — decode error, UNSPECIFIED peer_kind,
  /// unknown peer_kind, missing required fields.
  static const String dropPayloadInvalid = 'hello-payload-invalid';

  /// Run the spec §5.7 checks against the raw payload bytes carried inside
  /// the (already signature-verified) HELLO envelope.
  static HelloValidationResult validate(Uint8List payloadBytes) {
    ProtocolHelloData hello;
    try {
      hello = ProtocolHelloData.decode(payloadBytes);
    } on ProtoDecodeException catch (e) {
      return HelloValidationResult.dropped(
        dropPayloadInvalid,
        'decode failed: ${e.message}',
      );
    }

    if (hello.protocolVersion != kProtocolVersionV2) {
      return HelloValidationResult.dropped(
        dropProtocolIncompatible,
        'protocol_version=${hello.protocolVersion} '
            'expected=$kProtocolVersionV2',
      );
    }

    if (hello.peerKind == PeerKind.unspecified) {
      return HelloValidationResult.dropped(
        dropPayloadInvalid,
        'peer_kind=UNSPECIFIED',
      );
    }

    if (hello.peerKind == PeerKind.phoneV1Legacy) {
      return HelloValidationResult.dropped(
        dropSelfDeclaredLegacy,
        'peer self-declared PEER_KIND_PHONE_V1_LEGACY (§15.9)',
      );
    }

    final profile = CapabilityProfileCatalog.fromPeerKind(hello.peerKind);
    if (profile == null) {
      return HelloValidationResult.dropped(
        dropPayloadInvalid,
        'unknown peer_kind=${hello.peerKind}',
      );
    }

    return HelloValidationResult.accepted(hello, profile);
  }
}
