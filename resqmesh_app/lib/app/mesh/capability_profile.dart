// Capability profile catalog (v0.3 Stage 0c wave 3A).
//
// Spec: docs/specs/native_transport_v1_2026-05-13.md §6.
//
// Pure value types — no async, no IO, no dependencies beyond the v2 wire
// enums. The state machine in `peer_capability_registry.dart` and the
// orchestrator in `protocol_hello_service.dart` consume these.

import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';

/// The four capability profiles defined by native_transport_v1 §6.1.
///
/// Profile assignment rules (§6.2):
///   1. Valid HELLO with one of phoneV1 / bleNodeV1 / tier0Mule → that profile.
///   2. No HELLO before 5s timeout                              → phoneV1Legacy.
///   3. Invalid HELLO (incl. self-declared legacy)              → connection drop;
///      registry records `failed` status, profile stays defensive (phoneV1Legacy).
enum CapabilityProfile {
  phoneV1Legacy,
  phoneV1,
  bleNodeV1,
  tier0Mule,
}

/// Immutable normative spec for one [CapabilityProfile] — what the local TX
/// path is allowed to do when talking to a peer of this kind.
class CapabilityProfileSpec {
  /// Per-§6.1 maximum serialized envelope this profile can RECEIVE.
  ///   phoneV1Legacy → single-notify cap at MTU=185 (164 B post-headers)
  ///   bleNodeV1     → 226 B (single-notify at MTU=247)
  ///   phoneV1, tier0Mule → MAX_ENVELOPE_BYTES (2048)
  final int maxRxEnvelopeBytes;

  /// True if the peer reassembles multi-chunk envelopes.
  final bool supportsChunking;

  /// True if the peer participates in IBLT fast-path sync.
  ///
  /// Stage 0c wave 3E clarification: this is a CAPABILITY bit — it declares
  /// the peer can RECEIVE an IBLT request and compute an IBLT response. It
  /// does NOT promise that the response payload (≈513 B = 1 control byte +
  /// 8 B watermark + 504 B bucket array) will fit single-notify at the
  /// per-link negotiated MTU.
  ///
  /// Runtime constraint (native_transport_v1 §6.1.2 + §7.1):
  /// the IBLT response is ≈513 B + 3 B ATT header = 516 B. Negotiated
  /// MTU 247 (the §7.1 "common modern phone" baseline) cannot single-notify
  /// it; the responder MUST chunk via [Chunker.split] (16-chunk cap is
  /// reached at MTU=23, well below v0.3 MUST-support MTUs).
  ///
  /// Wave 3E-r2 — Android `IgniRelayForegroundService.handleIBLTRequest`
  /// now CORRECTLY detects when the 513-byte response cannot single-notify
  /// at the per-link MTU and falls back to a blind push of the outbox via
  /// `pushOutboxToDevice`. The central still receives all events; the IBLT
  /// fast-path's bandwidth optimization is lost at low MTU but correctness
  /// is preserved. The wave 3E-r1 bug (`bloomReceivedDevices` was marked
  /// even after the failed notify, which also suppressed the 10-second
  /// blind-push timer fallback) is fixed. A chunked IBLT response (new
  /// control byte + receiver-side reassembly) is still queued as a wave
  /// 3F-or-later bandwidth improvement, but is no longer a correctness
  /// gap. iOS BLE plugin parity work should land both the single-notify
  /// path AND the low-MTU blind-push fallback from the start.
  final bool supportsIblt;

  /// True if the peer understands the v2 magic-headered Bloom bit-vector.
  final bool supportsBloomV2;

  const CapabilityProfileSpec({
    required this.maxRxEnvelopeBytes,
    required this.supportsChunking,
    required this.supportsIblt,
    required this.supportsBloomV2,
  });
}

class CapabilityProfileCatalog {
  /// §6.1.1 — conservative defaults for peers whose HELLO timed out.
  /// NOT a v0.2 wire-compatibility layer; v0.3 does not decode legacy
  /// MeshEvent bytes. This profile gates outbound traffic to avoid sending
  /// shapes the peer cannot reasonably accept.
  static const CapabilityProfileSpec phoneV1Legacy = CapabilityProfileSpec(
    maxRxEnvelopeBytes: 164,
    supportsChunking: false,
    supportsIblt: false,
    supportsBloomV2: false,
  );

  /// §6.1.2 — full-feature v0.3 phone profile.
  static const CapabilityProfileSpec phoneV1 = CapabilityProfileSpec(
    maxRxEnvelopeBytes: 2048,
    supportsChunking: true,
    supportsIblt: true,
    supportsBloomV2: true,
  );

  /// §6.1.3 — low-power constrained node (future v0.5 hardware).
  static const CapabilityProfileSpec bleNodeV1 = CapabilityProfileSpec(
    maxRxEnvelopeBytes: 226,
    supportsChunking: false,
    supportsIblt: true,
    supportsBloomV2: true,
  );

  /// §6.1.4 — existing Tier-0 mule (always-on relay).
  static const CapabilityProfileSpec tier0Mule = CapabilityProfileSpec(
    maxRxEnvelopeBytes: 2048,
    supportsChunking: true,
    supportsIblt: true,
    supportsBloomV2: true,
  );

  static CapabilityProfileSpec specOf(CapabilityProfile p) {
    switch (p) {
      case CapabilityProfile.phoneV1Legacy:
        return phoneV1Legacy;
      case CapabilityProfile.phoneV1:
        return phoneV1;
      case CapabilityProfile.bleNodeV1:
        return bleNodeV1;
      case CapabilityProfile.tier0Mule:
        return tier0Mule;
    }
  }

  /// Map an on-wire `PeerKind` value to a profile. Returns `null` for values
  /// that MUST NOT be auto-assigned (UNSPECIFIED, PHONE_V1_LEGACY, or any
  /// unknown PeerKind). Self-declared legacy is explicitly disallowed per
  /// §5.7 / §15.9 — callers should treat `null` here as a HELLO error.
  static CapabilityProfile? fromPeerKind(int peerKind) {
    switch (peerKind) {
      case PeerKind.phoneV1:
        return CapabilityProfile.phoneV1;
      case PeerKind.bleNodeV1:
        return CapabilityProfile.bleNodeV1;
      case PeerKind.tier0Mule:
        return CapabilityProfile.tier0Mule;
      case PeerKind.unspecified:
      case PeerKind.phoneV1Legacy:
      default:
        return null;
    }
  }
}
