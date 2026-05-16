// Hand-written EventEnvelope v2 wire types (v0.3 Stage 0c second wave).
//
// Spec: docs/specs/envelope_v2_spec_2026-05-13.md §3, §4, §5.
//
// Mirrors the .proto fragment in `protos/mesh_protocol.proto` but does not
// depend on `protoc`. Wire format is plain proto3; the canonical SIGNATURE
// input is computed separately via `lib/app/crypto/canonical_encoder_v2.dart`
// and is NOT this proto encoding.

import 'dart:typed_data';

import 'proto_wire.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums (frozen by spec §4 / §6 / §5).
// ─────────────────────────────────────────────────────────────────────────────

class EventTypeV2 {
  static const int unspecified = 0;

  // 1-19 personal/status
  static const int statusUpdate = 1;
  static const int batteryStatus = 2;

  // 20-49 coordination
  static const int supplyRequest = 20;
  static const int supplyOffer = 21;
  static const int matchIntent = 22;
  static const int negotiation = 23;
  static const int relayToContact = 24;
  static const int chatMessage = 30;

  // 50-79 hazard
  static const int hazardMarker = 50;
  static const int disasterReport = 51;
  static const int shelterStatus = 52;

  // 80-99 official
  static const int officialAlertCap = 80;
  static const int officialAlertSummary = 81;

  // 100-129 control
  static const int protocolHello = 100;
  static const int protocolNotice = 101;
  static const int heartbeat = 102;
  static const int tracePing = 103;
  static const int traceAck = 104;

  // 1000+ experimental — out of tree

  /// True if this value is one of the spec-known values.
  static bool isKnown(int v) {
    switch (v) {
      case statusUpdate:
      case batteryStatus:
      case supplyRequest:
      case supplyOffer:
      case matchIntent:
      case negotiation:
      case relayToContact:
      case chatMessage:
      case hazardMarker:
      case disasterReport:
      case shelterStatus:
      case officialAlertCap:
      case officialAlertSummary:
      case protocolHello:
      case protocolNotice:
      case heartbeat:
      case tracePing:
      case traceAck:
        return true;
      default:
        return false;
    }
  }
}

class PriorityV2 {
  static const int unspecified = 0;
  static const int sosRed = 1;
  static const int sosYellow = 2;
  static const int alert = 3;
  static const int status = 4;
  static const int resource = 5;
  static const int normal = 6;

  /// Lower number = higher priority. Useful for receiver-side downgrade
  /// computations (max(a, b) chooses the more severe one when both > 0).
  static int moreSevere(int a, int b) {
    if (a == unspecified) return b;
    if (b == unspecified) return a;
    return a < b ? a : b;
  }
}

class SigAlgo {
  static const int unspecified = 0;
  static const int ed25519 = 0x01;
}

class HlcTimestampV2 {
  final int msSinceEpoch;
  final int counter;

  const HlcTimestampV2({required this.msSinceEpoch, required this.counter});

  static const HlcTimestampV2 zero = HlcTimestampV2(msSinceEpoch: 0, counter: 0);

  /// Stable order: ms ASC, counter ASC. Returns negative / zero / positive.
  int compareTo(HlcTimestampV2 other) {
    final dms = msSinceEpoch.compareTo(other.msSinceEpoch);
    if (dms != 0) return dms;
    return counter.compareTo(other.counter);
  }

  Uint8List encode() {
    final w = ProtoWriter();
    w.writeUint64(1, msSinceEpoch);
    w.writeUint32(2, counter);
    return w.toBytes();
  }

  static HlcTimestampV2 decode(Uint8List bytes) {
    final r = ProtoReader(bytes);
    var ms = 0;
    var ctr = 0;
    while (!r.isAtEnd) {
      final tag = r.readTag();
      final field = tagFieldNumber(tag);
      final wire = tagWireType(tag);
      switch (field) {
        case 1:
          if (wire != wireVarint) throw ProtoDecodeException('hlc.ms wire-type mismatch');
          ms = r.readUint64();
          break;
        case 2:
          if (wire != wireVarint) throw ProtoDecodeException('hlc.counter wire-type mismatch');
          ctr = r.readUint32();
          break;
        default:
          r.skipValue(wire);
      }
    }
    return HlcTimestampV2(msSinceEpoch: ms, counter: ctr);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EventEnvelopeV2 — top-level wire envelope.
// ─────────────────────────────────────────────────────────────────────────────

class EventEnvelopeV2 {
  /// Wire protocol version. v0.3 == 2.
  final int protocolVersion;

  /// 16 bytes; UUIDv7 (locked §20.3).
  final Uint8List envelopeId;

  final int eventType; // EventTypeV2.*
  final int priority;  // PriorityV2.*

  final HlcTimestampV2 createdAtHlc;
  final HlcTimestampV2 expiresAtHlc;

  /// Initial hop budget chosen by the author.
  final int maxHops;

  /// 32 bytes Ed25519 pubkey.
  final Uint8List authorKey;

  /// 0x01 == Ed25519 (v0.3 mandatory); 0x02-0xFF reserved for future.
  final int sigAlgo;

  /// 64 bytes (Ed25519). Covers canonical signature input incl. SHA-256(payload).
  final Uint8List signature;

  /// Typed bytes for this event_type.
  final Uint8List payload;

  /// OPTIONAL on origin; set by relays. Empty string == absent on wire.
  final String lastRelayId;

  /// event_type >= 1000 MUST set true.
  final bool isExperimental;

  EventEnvelopeV2({
    this.protocolVersion = 2,
    required this.envelopeId,
    required this.eventType,
    required this.priority,
    required this.createdAtHlc,
    required this.expiresAtHlc,
    required this.maxHops,
    required this.authorKey,
    this.sigAlgo = SigAlgo.ed25519,
    required this.signature,
    required this.payload,
    this.lastRelayId = '',
    this.isExperimental = false,
  });

  /// Full proto3 wire-encode. The receiver gets exactly these bytes inside the
  /// chunk-framed body (per native_transport_v1 §4.5 Option B).
  Uint8List encode() {
    final w = ProtoWriter();
    w.writeUint32(1, protocolVersion);
    w.writeBytes(2, envelopeId);
    w.writeEnum(3, eventType);
    w.writeEnum(4, priority);
    w.writeMessage(5, createdAtHlc.encode());
    w.writeMessage(6, expiresAtHlc.encode());
    w.writeUint32(7, maxHops);
    w.writeBytes(8, authorKey);
    w.writeUint32(9, sigAlgo);
    w.writeBytes(10, signature);
    w.writeBytes(11, payload);
    w.writeString(12, lastRelayId);
    w.writeBool(13, isExperimental);
    return w.toBytes();
  }

  /// Strict wire-decode. Drops on missing-required fields with the documented
  /// `decode-required-field-missing` `drop_reason` (envelope_v2_spec §3.4).
  static EventEnvelopeV2 decode(Uint8List bytes) {
    final r = ProtoReader(bytes);
    var protocolVersion = 0;
    Uint8List? envelopeId;
    var eventType = 0;
    var priority = 0;
    HlcTimestampV2? createdAtHlc;
    HlcTimestampV2? expiresAtHlc;
    var maxHops = 0;
    Uint8List? authorKey;
    var sigAlgo = 0;
    Uint8List? signature;
    Uint8List? payload;
    var lastRelayId = '';
    var isExperimental = false;

    while (!r.isAtEnd) {
      final tag = r.readTag();
      final field = tagFieldNumber(tag);
      final wire = tagWireType(tag);
      switch (field) {
        case 1:
          if (wire != wireVarint) throw ProtoDecodeException('protocol_version wire-type');
          protocolVersion = r.readUint32();
          break;
        case 2:
          if (wire != wireLengthDelimited) throw ProtoDecodeException('envelope_id wire-type');
          envelopeId = Uint8List.fromList(r.readLengthDelimited());
          break;
        case 3:
          if (wire != wireVarint) throw ProtoDecodeException('event_type wire-type');
          eventType = r.readUint32();
          break;
        case 4:
          if (wire != wireVarint) throw ProtoDecodeException('priority wire-type');
          priority = r.readUint32();
          break;
        case 5:
          if (wire != wireLengthDelimited) throw ProtoDecodeException('created_at_hlc wire-type');
          createdAtHlc = HlcTimestampV2.decode(r.readLengthDelimited());
          break;
        case 6:
          if (wire != wireLengthDelimited) throw ProtoDecodeException('expires_at_hlc wire-type');
          expiresAtHlc = HlcTimestampV2.decode(r.readLengthDelimited());
          break;
        case 7:
          if (wire != wireVarint) throw ProtoDecodeException('max_hops wire-type');
          maxHops = r.readUint32();
          break;
        case 8:
          if (wire != wireLengthDelimited) throw ProtoDecodeException('author_key wire-type');
          authorKey = Uint8List.fromList(r.readLengthDelimited());
          break;
        case 9:
          if (wire != wireVarint) throw ProtoDecodeException('sig_algo wire-type');
          sigAlgo = r.readUint32();
          break;
        case 10:
          if (wire != wireLengthDelimited) throw ProtoDecodeException('signature wire-type');
          signature = Uint8List.fromList(r.readLengthDelimited());
          break;
        case 11:
          if (wire != wireLengthDelimited) throw ProtoDecodeException('payload wire-type');
          payload = Uint8List.fromList(r.readLengthDelimited());
          break;
        case 12:
          if (wire != wireLengthDelimited) throw ProtoDecodeException('last_relay_id wire-type');
          lastRelayId = r.readString();
          break;
        case 13:
          if (wire != wireVarint) throw ProtoDecodeException('is_experimental wire-type');
          isExperimental = r.readBool();
          break;
        default:
          r.skipValue(wire);
      }
    }

    if (envelopeId == null || envelopeId.length != 16) {
      throw ProtoDecodeException('envelope_id missing or not 16 bytes');
    }
    if (authorKey == null || authorKey.length != 32) {
      throw ProtoDecodeException('author_key missing or not 32 bytes');
    }
    if (signature == null || signature.length != 64) {
      throw ProtoDecodeException('signature missing or not 64 bytes');
    }
    if (createdAtHlc == null) {
      throw ProtoDecodeException('created_at_hlc missing');
    }
    if (expiresAtHlc == null) {
      throw ProtoDecodeException('expires_at_hlc missing');
    }
    if (eventType == 0) {
      throw ProtoDecodeException('event_type missing or UNSPECIFIED');
    }
    if (priority == 0) {
      throw ProtoDecodeException('priority missing or UNSPECIFIED');
    }
    return EventEnvelopeV2(
      protocolVersion: protocolVersion,
      envelopeId: envelopeId,
      eventType: eventType,
      priority: priority,
      createdAtHlc: createdAtHlc,
      expiresAtHlc: expiresAtHlc,
      maxHops: maxHops,
      authorKey: authorKey,
      sigAlgo: sigAlgo,
      signature: signature,
      payload: payload ?? Uint8List(0),
      lastRelayId: lastRelayId,
      isExperimental: isExperimental,
    );
  }

  /// Hex string of envelope_id; convenient for trace logs.
  String get envelopeIdHex {
    final sb = StringBuffer();
    for (final b in envelopeId) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StatusUpdateData — payload for EVENT_TYPE_STATUS_UPDATE (snapshot).
// ─────────────────────────────────────────────────────────────────────────────

class SafetyState {
  static const int unspecified = 0;
  static const int safe = 1;
  static const int unsafe = 2;
  static const int injured = 3;
  static const int trapped = 4;
}

class NeedCategory {
  static const int unspecified = 0;
  static const int water = 1;
  static const int power = 2;
  static const int medicine = 3;
  static const int food = 4;
  static const int shelter = 5;
  static const int evac = 6;
}

class NeedSeverity {
  static const int unspecified = 0;
  static const int want = 1;
  static const int need = 2;
  static const int urgent = 3;
}

class NeedEntry {
  final int category;
  final int severity;
  final HlcTimestampV2 expiresAtHlc;

  const NeedEntry({
    required this.category,
    required this.severity,
    required this.expiresAtHlc,
  });

  Uint8List encode() {
    final w = ProtoWriter();
    w.writeEnum(1, category);
    w.writeEnum(2, severity);
    w.writeMessage(3, expiresAtHlc.encode());
    return w.toBytes();
  }

  static NeedEntry decode(Uint8List bytes) {
    final r = ProtoReader(bytes);
    var category = 0;
    var severity = 0;
    HlcTimestampV2 expires = HlcTimestampV2.zero;
    while (!r.isAtEnd) {
      final tag = r.readTag();
      final field = tagFieldNumber(tag);
      final wire = tagWireType(tag);
      switch (field) {
        case 1:
          category = r.readUint32();
          break;
        case 2:
          severity = r.readUint32();
          break;
        case 3:
          expires = HlcTimestampV2.decode(r.readLengthDelimited());
          break;
        default:
          r.skipValue(wire);
      }
    }
    return NeedEntry(category: category, severity: severity, expiresAtHlc: expires);
  }
}

class StatusUpdateData {
  final int safetyState;
  final List<NeedEntry> needs;

  const StatusUpdateData({
    required this.safetyState,
    this.needs = const <NeedEntry>[],
  });

  Uint8List encode() {
    final w = ProtoWriter();
    w.writeEnum(1, safetyState);
    for (final n in needs) {
      w.writeMessage(2, n.encode());
    }
    return w.toBytes();
  }

  static StatusUpdateData decode(Uint8List bytes) {
    final r = ProtoReader(bytes);
    var state = 0;
    final needs = <NeedEntry>[];
    while (!r.isAtEnd) {
      final tag = r.readTag();
      final field = tagFieldNumber(tag);
      final wire = tagWireType(tag);
      switch (field) {
        case 1:
          state = r.readUint32();
          break;
        case 2:
          needs.add(NeedEntry.decode(r.readLengthDelimited()));
          break;
        default:
          r.skipValue(wire);
      }
    }
    return StatusUpdateData(safetyState: state, needs: needs);
  }

  /// Spec §5.3 — sender-side priority floor derived from payload contents.
  int impliedPriorityFloor() {
    var p = PriorityV2.status;
    if (safetyState == SafetyState.trapped) {
      p = PriorityV2.moreSevere(p, PriorityV2.sosRed);
    }
    if (safetyState == SafetyState.injured) {
      p = PriorityV2.moreSevere(p, PriorityV2.sosYellow);
    }
    for (final n in needs) {
      if (n.severity == NeedSeverity.urgent) {
        p = PriorityV2.moreSevere(p, PriorityV2.sosYellow);
      }
    }
    return p;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ProtocolHelloData — capability declaration carried in PROTOCOL_HELLO.payload.
// ─────────────────────────────────────────────────────────────────────────────

class PeerKind {
  static const int unspecified = 0;
  static const int phoneV1 = 1;
  static const int bleNodeV1 = 2;
  static const int tier0Mule = 3;
  static const int phoneV1Legacy = 4;
}

class BgState {
  static const int unspecified = 0;
  static const int foreground = 1;
  static const int background = 2;
  static const int doze = 3;
}

class ProtocolHelloData {
  final int protocolVersion;
  final int peerKind;
  final int maxRxEnvelopeBytes;
  final bool supportsIblt;
  final bool supportsBloomV2;
  final bool supportsChunking;
  final int minNegotiatedMtu;
  final List<String> capabilities;
  final int bgState;

  const ProtocolHelloData({
    this.protocolVersion = 2,
    required this.peerKind,
    required this.maxRxEnvelopeBytes,
    this.supportsIblt = false,
    this.supportsBloomV2 = false,
    this.supportsChunking = false,
    required this.minNegotiatedMtu,
    this.capabilities = const <String>[],
    this.bgState = BgState.unspecified,
  });

  Uint8List encode() {
    final w = ProtoWriter();
    w.writeUint32(1, protocolVersion);
    w.writeEnum(2, peerKind);
    w.writeUint32(3, maxRxEnvelopeBytes);
    w.writeBool(4, supportsIblt);
    w.writeBool(5, supportsBloomV2);
    w.writeBool(6, supportsChunking);
    w.writeUint32(7, minNegotiatedMtu);
    w.writeRepeatedString(8, capabilities);
    w.writeEnum(9, bgState);
    return w.toBytes();
  }

  static ProtocolHelloData decode(Uint8List bytes) {
    final r = ProtoReader(bytes);
    var pv = 0;
    var kind = 0;
    var maxRx = 0;
    var iblt = false;
    var bloom = false;
    var chunking = false;
    var minMtu = 0;
    final caps = <String>[];
    var bg = 0;
    while (!r.isAtEnd) {
      final tag = r.readTag();
      final field = tagFieldNumber(tag);
      final wire = tagWireType(tag);
      switch (field) {
        case 1:
          pv = r.readUint32();
          break;
        case 2:
          kind = r.readUint32();
          break;
        case 3:
          maxRx = r.readUint32();
          break;
        case 4:
          iblt = r.readBool();
          break;
        case 5:
          bloom = r.readBool();
          break;
        case 6:
          chunking = r.readBool();
          break;
        case 7:
          minMtu = r.readUint32();
          break;
        case 8:
          caps.add(r.readString());
          break;
        case 9:
          bg = r.readUint32();
          break;
        default:
          r.skipValue(wire);
      }
    }
    return ProtocolHelloData(
      protocolVersion: pv,
      peerKind: kind,
      maxRxEnvelopeBytes: maxRx,
      supportsIblt: iblt,
      supportsBloomV2: bloom,
      supportsChunking: chunking,
      minNegotiatedMtu: minMtu,
      capabilities: caps,
      bgState: bg,
    );
  }
}
