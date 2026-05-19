# Envelope v2 Spec — Stage 0a Deliverable

Date: 2026-05-13 (drafted 2026-05-15)
Source brief: `text/resqmesh_v0.3_v0.5_protocol_roadmap_spec_brief_2026-05-13.md` §1, §3.2
Companion spec: `docs/specs/native_transport_v1_2026-05-13.md` (Stage 0b — chunking framing, MTU profiles, capability negotiation)
Status: REVIEW DRAFT — spec-only; no app/proto/Dart/Kotlin/Swift/UI changes.
Scope: v0.3 wire format, EventType enum, signature scope, storage schema, sync/tombstone policy, dev trace log, freeze policy text. Cross-platform implementation lives in Stage 0c.

---

## Table of Contents

1. [Scope, Constraints, and Non-Goals](#1-scope-constraints-and-non-goals)
2. [Relationship to Legacy Wire Format](#2-relationship-to-legacy-wire-format)
3. [EventEnvelope v2 — Proto Definition](#3-eventenvelope-v2--proto-definition)
4. [EventType Enum Grouping](#4-eventtype-enum-grouping)
5. [StatusUpdateData Snapshot Payload](#5-statusupdatedata-snapshot-payload)
6. [Priority × EventType Validation Matrix](#6-priority--eventtype-validation-matrix)
7. [Signature Scope White-List](#7-signature-scope-white-list)
8. [Canonical Encoding Rules](#8-canonical-encoding-rules)
9. [Payload Budget Per Priority](#9-payload-budget-per-priority)
10. [Dedupe & LWW Key Derivation](#10-dedupe--lww-key-derivation)
11. [Category-Specific TTL Defaults](#11-category-specific-ttl-defaults)
12. [DB Schema (Reset Design)](#12-db-schema-reset-design)
13. [Tombstone / Expired Sync Policy](#13-tombstone--expired-sync-policy)
14. [Reconnect Minimum Behavior](#14-reconnect-minimum-behavior)
15. [Dev-Only Mesh Trace Log](#15-dev-only-mesh-trace-log)
16. [Two-Stage STATUS → SUPPLY Relationship](#16-two-stage-status--supply-relationship)
17. [Cross-Platform Conformance Corpus (Envelope Slice)](#17-cross-platform-conformance-corpus-envelope-slice)
18. [Freeze Policy Text](#18-freeze-policy-text-for-claudemd-and-docsprotocolmd)
19. [Acceptance Checklist For 0a Spec Review](#19-acceptance-checklist-for-0a-spec-review)
20. [Decisions Locked (Sign-Off 2026-05-15)](#20-decisions-locked-sign-off-2026-05-15)

---

## 1. Scope, Constraints, and Non-Goals

### 1.1 In scope

- Single-layer top-level `EventEnvelope` v2 proto message and field numbering.
- EventType enum (final grouping, gaps, reserved values).
- `StatusUpdateData` snapshot payload schema.
- Signature scope, canonical encoding, signature algorithm byte.
- Payload budget per priority (concrete bytes).
- Dedupe / LWW key derivation per EventType.
- DB schema reset design (envelope-centric, with `db_version`, dedupe, LWW, tombstone indexes).
- Tombstone / expired sync policy so expired envelopes do not re-circulate via IBLT/Bloom.
- Reconnect minimum UX behavior for expired envelopes.
- Dev-only `Mesh_Trace_Logs` structured table.
- Cross-platform wire conformance corpus requirements for the envelope slice (the joint corpus also covers IBLT/Bloom/chunking — see 0b §3.3.6 of the brief).
- Freeze policy text to be pasted into `CLAUDE.md` and `docs/protocol.md` after spec acceptance.

### 1.2 Hard constraints (per roadmap §8 handoff)

- DO NOT modify app code, proto files, Dart, Kotlin, or Swift sources while writing this spec.
- DO NOT touch the UI prototype document.
- Envelope protobuf **field tags** (numeric proto fields inside `EventEnvelope`) and EventType **enum values** are different and must remain separate.
- v0.3 may wipe internal/dev data; no elaborate compatibility layer is required.
- 30-second disaster install flow is first-launch only (relevant for Stage 1, but documented here so EventEnvelope does not encode any "first launch" state).
- Official alerts are NCDR CAP-first, with CWA as a provider (`OFFICIAL_ALERT_CAP` carries the canonical payload).
- iOS Critical Alerts entitlement must not block protocol or Android work.
- This spec is jointly constrained with 0b (`native_transport_v1`); concrete byte budgets and chunking framing are mutually load-bearing.

### 1.3 Non-goals (v0.3)

- Per-origin rate limiting (deferred — see brief §1.8 threat boundary).
- Replay hardening beyond TTL.
- Anonymous routing.
- Comprehensive trust graph (only static labels in `source_trust`).
- Mesh-summary broadcast of official alerts (deferred to v0.3 Stage 1 if ahead of schedule; otherwise v0.4).
- User-facing mesh dashboard (deferred to v0.4).
- Post-quantum signature implementation (`sig_algo` reserves the bytes; v0.3 ships Ed25519 only).

### 1.4 Wipe stance

v0.3 PERFORMS a clean storage reset on first launch after upgrade:

- `db_version` is checked; if absent or below `2`, the migration helper drops all v0.x application tables and recreates the v0.3 schema described in §12.
- The user is informed in the release notes that local mesh history is wiped.
- After v0.3 is shipped to closed beta, schema changes require proper migrations.

This is allowed because no stable public communication protocol has shipped yet (brief §0).

---

## 2. Relationship to Legacy Wire Format

### 2.1 The current wire reality

The current Dart code (`lib/app/mesh/mesh_event_handler.dart`) decodes the wire bytes directly as `pb.MeshEvent` via `decodeWirePayload`. The legacy `pb.MeshEnvelope` (defined at `lib/app/proto/mesh_protocol.pb.dart:3094` with field tags 1=`type`, 2=`payload`, 3=`senderId`) is dead code — no caller invokes `MeshEnvelope.fromBuffer` or `writeToBuffer`. `BloomFilterSync` (line 290) is exchanged on its dedicated GATT characteristic (`BLOOM_CHAR_UUID`) and is NOT multiplexed through `MeshEnvelope`.

### 2.2 v0.3 stance

- v0.3 adopts a single-layer top-level `EventEnvelope` v2. The legacy `MeshEnvelope` wire shape is **not** the compatibility target.
- The legacy `MeshEnvelope` message MUST be kept in the `.proto` file marked `deprecated = true` with all three field tags reserved INSIDE that legacy message. This keeps the proto file builder-clean and prevents accidental reuse of `MeshEnvelope` field numbers in the deprecated message.
- The new `EventEnvelope` has its **own tag space**, starting from tag 1. Legacy `MeshEnvelope` field tags do not constrain `EventEnvelope` tags.
- `BloomFilterSync` continues on its dedicated GATT characteristic and is OUT of scope for `EventEnvelope`.
- The legacy `MeshEvent` message (top of `mesh_protocol.pb.dart`, line 22) becomes a v0.2 historical artifact. v0.3 readers MUST NOT decode v0.2 bytes — the storage reset wipes them. The message stays in the proto file for one release as `deprecated = true`, then is removed in v0.4 after migration discipline kicks in.

### 2.3 Reserved EventType values

The currently-deprecated values `MATCH_INQUIRY=10`, `MATCH_AVAILABLE=11`, `MATCH_GONE=12` (visible in `mesh_protocol.pbenum.dart:28-30`) are **permanently reserved** in the new `EventType` enum. They MUST NOT be reused by v2 even though they exist in a separate enum declaration. This is documented in §4 as `reserved 10, 11, 12;` in the proto fragment.

All other v0.2 EventType values (`RESOURCE_REGISTER=0` through `LOCATION_UPDATE=14`) are obsolete; their semantic intent is re-expressed under the new `EVENT_TYPE_<GROUP>_<NAME>` naming under §4. They are not technically reserved because the new enum is a fresh declaration in a fresh proto package version; however, §4 calls them out to avoid confusion.

---

## 3. EventEnvelope v2 — Proto Definition

### 3.1 Authoritative proto fragment

```proto
syntax = "proto3";

package resqmesh.v2;

// Top-level wire envelope. Every byte that crosses BLE EVENT_CHAR is either
// (a) a complete EventEnvelope, or (b) a single chunk framed per 0b §3.3.3
// (chunk framing is a transport-layer wrapper; the reassembled body is an
// EventEnvelope).
message EventEnvelope {
  // ── Identity & versioning ───────────────────────────────────────────
  uint32 protocol_version = 1;     // v0.3 == 2 (v2 wire). v0.2 was implicit 1.
  bytes  envelope_id      = 2;     // 16 bytes. MUST be UUIDv7 (locked).
                                   //   Author generates; relays never mutate.
                                   //   Dedupe key. Globally unique;
                                   //   time-sorted prefix aids DB scan.

  // ── Semantics ───────────────────────────────────────────────────────
  EventType event_type    = 3;     // See §4. Required (no UNSPECIFIED on wire).
  Priority  priority      = 4;     // See §6. Required.

  // ── Time (HLC pairs, not wallclock) ─────────────────────────────────
  HlcTimestamp created_at_hlc = 5; // Origin creation time.
  HlcTimestamp expires_at_hlc = 6; // Absolute expiry in HLC time.

  // ── Routing ─────────────────────────────────────────────────────────
  uint32 max_hops         = 7;     // Initial hop budget chosen by author.
                                   //   Receiver-side counter is hop_count_seen
                                   //   (NOT on wire; see below).

  // ── Identity / cryptography ─────────────────────────────────────────
  bytes  author_key       = 8;     // 32 bytes. Ed25519 public key. LWW + sig.
  uint32 sig_algo         = 9;     // uint8 in semantics; uint32 on wire.
                                   //   0x00 reserved (UNSPECIFIED, REJECTED).
                                   //   0x01 = Ed25519 (v0.3 mandatory).
                                   //   0x02-0xFF reserved for crypto agility.
  bytes  signature        = 10;    // 64 bytes for Ed25519. Covers the
                                   //   canonical encoding of the signed
                                   //   field set described in §7-§8. The
                                   //   canonical encoding INCLUDES
                                   //   SHA-256(payload), computed locally
                                   //   on send/receive — there is no
                                   //   payload_hash field on the wire.

  // ── Payload ─────────────────────────────────────────────────────────
  bytes  payload          = 11;    // Typed bytes for this event_type.

  // ── Relay annotation (NOT signed; OPTIONAL on origin) ──────────────
  // last_relay_id is OMITTED by the originating author (no relay yet) and
  // SET by each relay before re-transmit. Present on the wire only when a
  // relay has annotated; excluded from the signature regardless.
  string last_relay_id    = 12;    // node short id of the immediate sender.

  // ── Experimental / local-only flag ──────────────────────────────────
  bool   is_experimental  = 13;    // event_type >= 1000 MUST set true.
                                   //   Relays SHOULD NOT propagate.

  // ── Reserved space ──────────────────────────────────────────────────
  reserved 14 to 31;               // Hot path (varint 1 byte) — leave headroom.

  // ── Reservations from the legacy EventType enum ────────────────────
  // (These are EventType enum reservations, not field reservations; see §4.)
}

message HlcTimestamp {
  uint64 ms_since_epoch = 1;       // Logical wall-clock millis.
  uint32 counter        = 2;       // Tie-breaker for same-ms events.
  // node_id is implicit via author_key; not duplicated here.
}

enum Priority {
  PRIORITY_UNSPECIFIED = 0;        // REJECTED on wire.
  PRIORITY_SOS_RED     = 1;
  PRIORITY_SOS_YELLOW  = 2;
  PRIORITY_ALERT       = 3;        // Official / trusted warning.
  PRIORITY_STATUS      = 4;        // Safety state, battery, shelter status.
  PRIORITY_RESOURCE    = 5;        // Supply request/offer/negotiation.
  PRIORITY_NORMAL      = 6;        // Chat, non-urgent coordination.
}
```

### 3.2 Field-tag rationale

- Tags 1-13 are all single-byte varint-tag-encoded (tag numbers ≤ 15). Every byte counts in a 240 B SOS envelope.
- Tags 14 and 15 are left unused (would still be single-byte) as the first slots for v0.4 additions.
- Tags 16+ become two-byte tags. The `reserved 14 to 31` clause is a guard against accidentally allocating multi-byte tags before the single-byte ones are spoken for.
- Hot-path fields (`event_type`, `priority`, `envelope_id`, `created_at_hlc`, `payload`) get low tag numbers.
- `last_relay_id` is given a low tag (12) deliberately so relays do not pay multi-byte overhead each hop.
- `payload_hash` is NOT a wire field. Both sender and receiver compute `SHA-256(payload)` locally and feed it into the canonical signature input (§8.2). This saves 34 bytes wire per envelope while preserving the same security property (signature binds payload).

### 3.3 Receiver-local fields (NEVER on wire)

These four labels exist only in local DB rows and the in-memory `EventStream` dispatch. They MUST NOT appear in the `.proto` file as wire fields.

- `signature_status` — `enum { VALID, INVALID, MISSING, NOT_CHECKED }`.
- `source_trust` — `enum { SELF, PAIRED, SEEN_BEFORE, UNVERIFIED, OFFICIAL_VERIFIED }`.
- `hop_count_seen` — receiver-local counter; increments each hop on this device.
- `relay_attempt_count` — receiver-local counter for the trace log.

Rationale: putting them on the wire would invite forgery and would split the trust assessment across sender and receiver. Spec is unambiguous: trust is computed on receipt, not transmitted.

### 3.4 Required-field semantics

Proto3 nominally treats every scalar field as optional. v0.3 spec layers required-field semantics on top:

- The conformance corpus (§17) includes negative test vectors for envelopes missing `envelope_id`, `author_key`, `event_type`, `priority`, `created_at_hlc`, `expires_at_hlc`, `sig_algo`, `signature`, and `payload`.
- The Stage 0c decoder MUST reject (drop + trace `decode-required-field-missing`) any envelope missing any of these.
- `last_relay_id` is OPTIONAL: an envelope freshly emitted by its origin author has no `last_relay_id`. Once a relay re-transmits, the relay sets `last_relay_id` to its own short id.
- `is_experimental` is OPTIONAL (defaults to false; absent on the wire when false).

---

## 4. EventType Enum Grouping

### 4.1 Authoritative enum fragment

```proto
enum EventType {
  EVENT_TYPE_UNSPECIFIED = 0;

  // ── 1-19: Personal / status ─────────────────────────────────────────
  EVENT_TYPE_STATUS_UPDATE        = 1;   // §5 snapshot payload
  EVENT_TYPE_BATTERY_STATUS       = 2;
  reserved 3 to 19;                       // headroom for personal events

  // ── 20-49: Request / supply / coordination ─────────────────────────
  EVENT_TYPE_SUPPLY_REQUEST       = 20;
  EVENT_TYPE_SUPPLY_OFFER         = 21;
  EVENT_TYPE_MATCH_INTENT         = 22;
  EVENT_TYPE_NEGOTIATION          = 23;
  EVENT_TYPE_RELAY_TO_CONTACT     = 24;
  reserved 25 to 29;                      // headroom for coordination
  EVENT_TYPE_CHAT_MESSAGE         = 30;   // peer-to-peer / room chat (NORMAL priority)
  reserved 31 to 49;                      // further headroom for coordination

  // ── 50-79: Hazard / disaster report ────────────────────────────────
  EVENT_TYPE_HAZARD_MARKER        = 50;
  EVENT_TYPE_DISASTER_REPORT      = 51;
  EVENT_TYPE_SHELTER_STATUS       = 52;
  reserved 53 to 79;                      // headroom for hazard

  // ── 80-99: Official alerts ─────────────────────────────────────────
  EVENT_TYPE_OFFICIAL_ALERT_CAP     = 80; // NCDR CAP-first; CWA is a provider
  EVENT_TYPE_OFFICIAL_ALERT_SUMMARY = 81; // chunkable summary (mesh-side)
  reserved 82 to 99;                      // headroom for official channels

  // ── 100-129: Mesh / system / control ───────────────────────────────
  EVENT_TYPE_PROTOCOL_HELLO       = 100;  // 0b §3.3.4 capability declaration
  EVENT_TYPE_PROTOCOL_NOTICE      = 101;  // vendor-signed kill switch
  EVENT_TYPE_HEARTBEAT            = 102;
  EVENT_TYPE_TRACE_PING           = 103;
  EVENT_TYPE_TRACE_ACK            = 104;
  reserved 105 to 129;                    // headroom for system

  // ── 1000+: Experimental / local-only ───────────────────────────────
  //   Envelope MUST set is_experimental=true. Relays SHOULD NOT propagate.
  //   Concrete values are not assigned here; out-of-tree feature branches
  //   may pick any value ≥ 1000 that is not present in this enum.

  // ── Permanent reservations from legacy v0.2 enum ───────────────────
  reserved 10, 11, 12;                    // MATCH_INQUIRY/AVAILABLE/GONE
                                          // — never reuse these values.
  reserved 13;                            // legacy CHAT_MESSAGE=13 — the v2
                                          // CHAT_MESSAGE moves to 30 to keep
                                          // chat under the coordination group.
}
```

### 4.2 Naming convention

All EventType values use the `EVENT_TYPE_<GROUP>_<NAME>` prefix. The four group prefixes are `STATUS`/`BATTERY`/`SUPPLY`/`MATCH`/`HAZARD`/`DISASTER`/`SHELTER`/`OFFICIAL_ALERT`/`PROTOCOL`/`HEARTBEAT`/`TRACE`/`RELAY` (i.e., the group is implied by the type name, not an extra token). The protobuf style guide preference for unambiguous prefixes is satisfied because `EVENT_TYPE_` is unique to this enum.

### 4.3 Reservation rationale

- `reserved 10, 11, 12` permanently locks out the deprecated `MATCH_INQUIRY/AVAILABLE/GONE` values from the legacy proto. Even though v0.3 uses a fresh enum in a fresh proto package version (`resqmesh.v2`), the reservation prevents a future agent from re-allocating those numbers under the new enum.
- Each group leaves a gap (e.g., `reserved 3 to 19`) so v0.4 features can extend a group without re-packing the enum.

### 4.4 Receiver dispatch rule

When a receiver encounters an `event_type` it does not recognize:

- If `is_experimental == true`: log to trace, drop silently (do not relay).
- If `is_experimental == false`: log to trace with `drop_reason = unknown-event-type`, drop. Do NOT relay (because a future EventType could become a "spam vector" if relayed blindly).

This means the experimental flag is the ONLY mechanism by which an unknown EventType is acceptable on the wire.

---

## 5. StatusUpdateData Snapshot Payload

### 5.1 Authoritative proto fragment

```proto
message StatusUpdateData {
  enum SafetyState {
    SAFETY_STATE_UNSPECIFIED = 0;        // REJECTED on receive.
    SAFETY_STATE_SAFE        = 1;
    SAFETY_STATE_UNSAFE      = 2;        // present, can move, in danger zone
    SAFETY_STATE_INJURED     = 3;
    SAFETY_STATE_TRAPPED     = 4;        // implies SOS_RED priority floor
  }

  enum NeedCategory {
    NEED_CATEGORY_UNSPECIFIED = 0;       // REJECTED on receive.
    NEED_CATEGORY_WATER       = 1;
    NEED_CATEGORY_POWER       = 2;
    NEED_CATEGORY_MEDICINE    = 3;
    NEED_CATEGORY_FOOD        = 4;
    NEED_CATEGORY_SHELTER     = 5;
    NEED_CATEGORY_EVAC        = 6;
    reserved 7 to 31;
  }

  enum NeedSeverity {
    NEED_SEVERITY_UNSPECIFIED = 0;       // REJECTED on receive.
    NEED_SEVERITY_WANT        = 1;
    NEED_SEVERITY_NEED        = 2;
    NEED_SEVERITY_URGENT      = 3;
  }

  message NeedEntry {
    NeedCategory category         = 1;
    NeedSeverity severity         = 2;
    HlcTimestamp expires_at_hlc   = 3;   // Per-need expiry in HLC time.
  }

  SafetyState safety_state  = 1;
  repeated NeedEntry needs  = 2;
  // No "delta" or "clear" fields: sender always transmits full state.
  // Empty `needs` = "no current needs". A new STATUS_UPDATE with empty
  // needs CLEARS prior needs (snapshot replace).
  reserved 3 to 15;                      // headroom in single-byte tags
}
```

### 5.2 Snapshot LWW semantics

- LWW key = `(author_key, EVENT_TYPE_STATUS_UPDATE)`.
- Latest `created_at_hlc` (HLC-ordered: `ms_since_epoch` ASC, then `counter` ASC, then `author_key` ASC as a final deterministic tiebreaker) wins.
- A new STATUS_UPDATE with `safety_state = SAFE` and empty `needs` FULLY supersedes a prior one with `INJURED` + `NEED_WATER`. No delta merge.
- Per-need `expires_at_hlc` allows a water request to expire faster than an injury status without requiring a fresh STATUS_UPDATE envelope. The UI MUST hide expired needs but the row remains until the next STATUS_UPDATE for this `author_key`.

### 5.3 Sender priority derivation

The sender computes envelope `priority` from the payload as the maximum (most severe) of:

| Payload condition | Implied priority floor |
|---|---|
| `safety_state == SAFETY_STATE_TRAPPED` | `PRIORITY_SOS_RED` |
| `safety_state == SAFETY_STATE_INJURED` | `PRIORITY_SOS_YELLOW` |
| any `needs[].severity == NEED_SEVERITY_URGENT` | `PRIORITY_SOS_YELLOW` |
| `safety_state == SAFETY_STATE_UNSAFE` AND any urgent need | `PRIORITY_SOS_YELLOW` |
| `safety_state ∈ {SAFE, UNSAFE}` with non-urgent needs only | `PRIORITY_STATUS` |
| `safety_state == SAFE` with empty needs | `PRIORITY_STATUS` |

The sender chooses the floor or higher. The receiver re-validates (§6).

### 5.4 Field tag economy

`StatusUpdateData` is designed to fit comfortably in the STATUS payload budget (~50B typed payload). A snapshot with `safety_state=INJURED` + 2 needs each with one HLC pair occupies roughly: 2B safety_state tag/value + 2 × (2B NeedEntry tag/length + 4B inner fields + 8B HLC) ≈ 32B. Well within budget.

---

## 6. Priority × EventType Validation Matrix

### 6.1 Receiver-side enforcement

The receiver MUST validate `(event_type, priority)` against the matrix below on every decoded envelope. Mismatches are handled per the action column. Trace log records `drop_reason = priority-mismatch` or `priority-downgraded`.

| EventType | Allowed priorities | Disallowed → action |
|---|---|---|
| `STATUS_UPDATE` | SOS_RED, SOS_YELLOW, STATUS | NORMAL/RESOURCE/ALERT → downgrade to STATUS |
| `BATTERY_STATUS` | STATUS, NORMAL | SOS_*/ALERT → downgrade to STATUS |
| `SUPPLY_REQUEST` | SOS_YELLOW, RESOURCE | SOS_RED → downgrade to SOS_YELLOW; NORMAL → upgrade to RESOURCE |
| `SUPPLY_OFFER` | RESOURCE | * → downgrade to RESOURCE |
| `MATCH_INTENT` / `NEGOTIATION` | RESOURCE, NORMAL | SOS_*/ALERT → downgrade to RESOURCE |
| `RELAY_TO_CONTACT` | SOS_RED, SOS_YELLOW, ALERT, NORMAL | RESOURCE → downgrade to NORMAL |
| `HAZARD_MARKER` | SOS_RED, SOS_YELLOW, ALERT | NORMAL/RESOURCE/STATUS → downgrade to ALERT |
| `DISASTER_REPORT` | SOS_YELLOW, ALERT | SOS_RED → downgrade to SOS_YELLOW |
| `SHELTER_STATUS` | ALERT, STATUS | SOS_* → downgrade to ALERT |
| `OFFICIAL_ALERT_CAP` | ALERT | SOS_* → downgrade to ALERT only if `source_trust == OFFICIAL_VERIFIED`; else DROP |
| `OFFICIAL_ALERT_SUMMARY` | ALERT, NORMAL | SOS_* → DROP (unverified summary masquerading as SOS) |
| `PROTOCOL_HELLO` | NORMAL | * → DROP |
| `PROTOCOL_NOTICE` | ALERT | * → DROP (only vendor-signed; checked separately) |
| `HEARTBEAT` | NORMAL | * → DROP |
| `TRACE_PING` / `TRACE_ACK` | NORMAL | * → DROP |
| `CHAT_MESSAGE` (= 30) | NORMAL | SOS_* → DROP (priority abuse) |

`EVENT_TYPE_CHAT_MESSAGE = 30` (locked decision; placed under the 20-49 coordination group). Legacy `CHAT_MESSAGE = 13` is permanently reserved (§4.1).

### 6.2 Special rule — `OFFICIAL_ALERT_CAP` with `source_trust != OFFICIAL_VERIFIED`

When the receiver decodes an `OFFICIAL_ALERT_CAP` envelope:

- If the envelope's `author_key` matches the device's stored official-source pubkey list (loaded from `Official_Sources` table in §12.6), set `source_trust = OFFICIAL_VERIFIED` and accept.
- Otherwise, set `source_trust = UNVERIFIED` and SURFACE the envelope but render its alert-status label as "unverified — origin not in trusted source list". Do not silently DROP, because a mesh-relayed alert with a tampered pubkey is still useful diagnostic info and the user deserves to see "unverified alert" rather than "no alert at all".

### 6.3 Sender-side enforcement

Senders MUST refuse to enqueue an envelope whose `(event_type, priority)` would be downgraded or dropped by the matrix above. The Stage 0c implementation MUST expose a `validatePriority(envelope)` function whose contract mirrors the receiver matrix exactly. This prevents priority abuse by buggy clients before the bytes ever hit the wire.

---

## 7. Signature Scope White-List

### 7.1 Signed fields (author commitment)

The Ed25519 signature MUST cover the canonical encoding (§8) of these inputs, and ONLY these inputs:

1. `protocol_version`
2. `envelope_id`
3. `event_type`
4. `priority`
5. `created_at_hlc` (both `ms_since_epoch` and `counter`)
6. `expires_at_hlc` (both `ms_since_epoch` and `counter`)
7. `max_hops` (the INITIAL value chosen by the author; NOT a remaining-hop counter)
8. `author_key`
9. `sig_algo`
10. `SHA-256(payload)` — computed locally on send and on receive; NOT a wire field.

### 7.2 NOT signed (relay-mutable or receiver-local)

- `last_relay_id` — overwritten by each relay before re-transmit.
- `is_experimental` — included on wire but not signed (intentional — see §7.4).
- `signature` itself.
- `payload` (signed by reference via locally computed `SHA-256(payload)`).
- `hop_count_seen` — receiver-local, never on wire.
- `signature_status` — receiver-local, never on wire.
- `source_trust` — receiver-local, never on wire.
- `relay_attempt_count` — receiver-local, never on wire.

### 7.3 Rationale

- A relay must not be able to forge higher priority, longer expiry, different event_type, or different author identity.
- A relay MAY annotate its identity in `last_relay_id` for trace/debug without invalidating the signature.
- The signature input includes `SHA-256(payload)` (32 bytes) rather than full payload bytes, keeping the signature canonical input fixed-size (124 bytes). Both sender and receiver compute `SHA-256(payload)` locally; any wire-level corruption of `payload` produces a different hash, the signature verification fails, and the envelope is dropped with `drop_reason = signature-invalid`. (We dropped the explicit `payload_hash` wire field — it would have added 34 bytes per envelope without strengthening the bind.)

### 7.4 Why `is_experimental` is unsigned

`is_experimental` controls relay behavior, not author intent. It is a transport hint set by the sender. Forging it does not buy the attacker anything (setting it `true` only makes the envelope MORE restricted — relays SHOULD NOT propagate). Therefore unsigned is acceptable and saves 1-2 canonical bytes on every SOS envelope.

### 7.5 Signature verification order on receive

1. Decode envelope from bytes.
2. Verify required fields present (§3.4) — else drop `decode-required-field-missing`.
3. Verify `sig_algo == 0x01` — else drop `unknown-sig-algo` (forward-compat: a v0.4 client with `0x02` PQ sig will appear here as unknown to a v0.3 device, which is correct).
4. Compute `SHA-256(payload)` over the received `payload` bytes.
5. Canonically encode the signed inputs (§8) using the freshly computed payload hash.
6. Verify Ed25519 signature over the canonical bytes using `author_key`. Mismatch → set `signature_status = INVALID`, drop.
7. Validate `(event_type, priority)` against §6 matrix.
8. Validate `payload_budget` (§9). Over-budget SOS → drop.
9. Check `dedupe_key = envelope_id` against `_dispatchedEventIds` and DB tombstone set — duplicate → drop `dedupe-hit`.
10. Check `expires_at_hlc` vs local clock — expired → tombstone path (§13).
11. Otherwise: accept, store, dispatch to typed streams, decide on relay.

---

## 8. Canonical Encoding Rules

### 8.1 Why deterministic protobuf alone is insufficient

A naive "serialize the envelope and sign the bytes" approach fails under proto3 because:

- Different runtimes serialize fields in different orders.
- Default values may or may not appear.
- Unknown fields can change the output between platforms.
- Repeated fields may be sorted differently.

Signature verification must produce bit-identical bytes on Dart, Kotlin, and Swift. Therefore the canonical encoding is explicitly spec'd; it MUST NOT depend on whatever the platform's generated protobuf serializer happens to emit.

### 8.2 Canonical encoding algorithm (`canonicalize_for_signature`)

Input: an `EventEnvelope` after the author has populated all signed fields (§7.1), plus the locally computed `payload_hash = SHA-256(payload)`.

Output: a deterministic byte sequence used as the signature input. NOT a valid `EventEnvelope` proto byte string.

Algorithm:

```text
payload_hash = SHA256(payload)                  # computed locally; not on wire

sig_input = b""
sig_input += u32_le(protocol_version)
sig_input += u8(16) || envelope_id              # length-prefixed (always 16 bytes)
sig_input += u32_le(event_type)
sig_input += u32_le(priority)
sig_input += u64_le(created_at_hlc.ms_since_epoch)
sig_input += u32_le(created_at_hlc.counter)
sig_input += u64_le(expires_at_hlc.ms_since_epoch)
sig_input += u32_le(expires_at_hlc.counter)
sig_input += u32_le(max_hops)
sig_input += u8(32) || author_key               # length-prefixed (always 32 bytes)
sig_input += u8(sig_algo)
sig_input += u8(32) || payload_hash             # length-prefixed (always 32 bytes)
```

Where:

- `u8` / `u32_le` / `u64_le` are unsigned 1/4/8-byte little-endian integer encodings.
- Length prefixes are a defense against length-extension surprises across future field additions.
- Total `sig_input` length is fixed at exactly `4 + 17 + 4 + 4 + 12 + 12 + 4 + 33 + 1 + 33 = 124 bytes` for v2.
- Field order is the order listed in §7.1.
- The `payload_hash` line uses the LOCALLY computed SHA-256 of the payload bytes — there is no wire field for it.

### 8.3 Reference vectors

The conformance corpus (§17) MUST include at least 5 fully worked test envelopes with:

- Plaintext envelope field values (JSON).
- `payload` bytes (hex).
- Computed `SHA-256(payload)` (hex; for verification — confirms each implementation hashes payload bytes identically).
- Computed `sig_input` bytes (hex; 124 bytes for v2).
- A signing private key (test-only).
- The Ed25519 `signature` over `sig_input` (hex).
- The fully serialized `EventEnvelope` proto bytes (hex) that includes the signature (and does NOT include payload_hash, since it is not a wire field).

Required coverage: one SOS_RED, one STATUS_UPDATE, one OFFICIAL_ALERT_CAP, one SUPPLY_OFFER (RESOURCE), and one PROTOCOL_HELLO.

### 8.4 Wire encoding (separate concern)

The bytes on the BLE wire ARE the generated protobuf serializer's output of the full `EventEnvelope` message (including `last_relay_id`, `is_experimental`, and `signature`). The receiver parses normal proto bytes; the canonical encoding is computed only as input to signature verification.

This decouples wire compatibility (proto3 standard) from signature stability (spec-defined). It is the recommended pattern for protobuf-with-signatures.

---

## 9. Payload Budget Per Priority

### 9.1 Concrete byte budgets

Derived from BLE ATT MTU realities documented in 0b (`docs/specs/native_transport_v1_2026-05-13.md` §7 MTU range support matrix). MTU baseline assumed = 247 (common modern phone). Useful single-notify bytes = `MTU - 3 (ATT header) - 18 (chunk header per 0b §4.5) = 226`.

Envelope fixed overhead (rough, single-byte tags only):

| Field | Wire bytes |
|---|---|
| `protocol_version` (varint, value=2) | 2 |
| `envelope_id` (16B + len + tag) | 18 |
| `event_type` (varint) | 2-3 |
| `priority` (varint) | 2 |
| `created_at_hlc` (embedded HlcTimestamp) | ~14 |
| `expires_at_hlc` | ~14 |
| `max_hops` (varint) | 2 |
| `author_key` (32B + len + tag) | 34 |
| `sig_algo` (varint) | 2 |
| `signature` (64B + len + tag) | 66 |
| `payload` (header only, excl. typed bytes) | 2 |
| `last_relay_id` (origin: 0; relayed: ~10) | 0-10 |
| `is_experimental` (absent for false) | 0 |
| **Fixed overhead total (origin emission)** | **≈ 158 B** |
| **Fixed overhead total (after 1+ relay)** | **≈ 168 B** |

SOS envelope budget is **locked at 240 B** (decision; see §20-Decisions). At MTU=247 the single-notify cap is 226 B, so a 240 B envelope spans **2 chunks at MTU=247 and 2 chunks at MTU=185** — the chunk count is symmetric across the modern-phone fleet, and the typed-payload room (~70-80 B) is sufficient for CJK SOS brief text (~25 chars) plus location/category/severity metadata.

| Priority | Total envelope budget | Typed payload budget (origin / post-relay) | Chunking? at MTU=247 / 185 | Rationale |
|---|---|---|---|---|
| `SOS_RED` | ≤ 240 B | ≤ ~82 B / ≤ ~72 B | 2 chunks / 2 chunks | Bumped from 200 B for headroom on CJK brief text; 2-chunk delivery cost at MTU=247 is ≈ +5-10 ms latency, acceptable. Receiver applies §6 priority-mismatch matrix. |
| `SOS_YELLOW` | ≤ 240 B | ≤ ~82 B / ≤ ~72 B | 2 chunks / 2 chunks | Same as SOS_RED. |
| `STATUS` | ≤ 240 B | ≤ ~82 B / ≤ ~72 B | 2 chunks / 2 chunks | StatusUpdateData snapshot is small by design (§5.4); 240 B leaves comfortable room for `safety_state` + 4-6 needs. |
| `ALERT` | ≤ 800 B | ≤ ~640 B | 4 chunks / 5 chunks at MTU=185 | CAP messages are 500 B-2 KB. Chunking required. |
| `RESOURCE` | ≤ 400 B | ≤ ~240 B | 2 chunks / 3 chunks at MTU=185 | Match negotiation; chunking allowed but disfavor for tight loops. |
| `NORMAL` (chat, heartbeat, trace, hello) | no fixed cap up to `MAX_ENVELOPE_BYTES = 2048` (0b §4.6) | typed payload via chunking | up to 16 chunks (0b §4.6) | Bounded by `MAX_ENVELOPE_BYTES`. |

Sender enforcement guarantees the total envelope budget. Receiver re-validates as defense in depth.

### 9.2 Why SOS is hard-capped tight

- Chunking adds reassembly latency (one missed chunk = wait for retransmit).
- Chunking adds reassembly memory.
- Chunking adds a denial-of-storage attack surface (sender floods chunk 0 of many envelopes).
- SOS arrives ONCE and must be visible immediately.
- The ≤240 B SOS envelope budget guarantees AT MOST 2 chunks across the entire MTU 185-512 range. 2 chunks adds ≈ 5-10 ms vs single-notify on modern phones; well inside the 0d acceptance gate p95<60s SOS latency target. The 0d gate explicitly verifies SOS_RED 3-hop p95<60s on a mixed device pool (brief §3.5.2 row 2).
- The ~70-80 B typed payload room comfortably fits `{location_lat:8, location_lng:8, brief_text:<=25 CJK chars, need_category:1, severity:1}` — the realistic SOS data model. Brief text in CJK is 3 bytes/char (UTF-8), so ~25 chars CJK or ~70 chars ASCII (good enough for "我被困在三樓電梯內手機快沒電" + lat/lng).

### 9.3 Sender enforcement

`MessagePublisher.send(envelope)` (Stage 0c, Dart) MUST:

- Compute the serialized envelope byte length BEFORE enqueueing.
- If `priority ∈ {SOS_RED, SOS_YELLOW, STATUS}` AND `total_size > 240B`: **REJECT** with `over-budget-sos-rejected`. Do NOT auto-chunk further. Do NOT auto-truncate the brief text. Surface to the UI as a publish error.
- If `priority == RESOURCE` AND `total_size > 400B`: REJECT.
- If `priority == ALERT` AND `total_size > 800B`: REJECT.
- If `priority == NORMAL` AND `total_size > 2048B` (`MAX_ENVELOPE_BYTES` from 0b §4.6): REJECT.

### 9.4 Receiver enforcement (defense in depth)

Receiver also drops over-budget envelopes:

- `priority ∈ {SOS_RED, SOS_YELLOW, STATUS}` AND `total_size > 240B`: drop `over-budget-sos-received` (treat as priority abuse).
- Other priorities: drop `over-budget-priority` if outside the priority budget.

### 9.5 Joint constraint with 0b

The byte numbers in §9 directly drive the chunking framing (0b §3.3.3) for non-SOS priorities. Each spec-only change to MTU baseline (e.g., if 0b drops MTU=247 baseline to MTU=185) MUST trigger a re-derivation of §9 numbers here. The current locked decision is recorded in §20.6.

---

## 10. Dedupe & LWW Key Derivation

### 10.1 Dedupe key

`dedupe_key = envelope_id` (16 bytes; UUIDv7 MANDATORY).

- Used by mesh relays to drop already-seen envelopes.
- Used by the receiver-side `EventStream._dispatchedEventIds` set to suppress duplicate UI dispatch.
- Persisted in the `Envelopes` table (§12.2) `envelope_id` column with UNIQUE constraint.
- Lifetime: kept until `expires_at_hlc + GRACE_PERIOD`; then converted to tombstone (§13).

### 10.2 LWW key table

Each EventType either participates in LWW (latest snapshot wins, prior superseded) or NOT (each envelope is an independent event). The table below is normative.

| EventType | LWW? | LWW key | Tiebreaker |
|---|---|---|---|
| `STATUS_UPDATE` | yes | `(author_key, EVENT_TYPE_STATUS_UPDATE)` | latest `created_at_hlc`, then `envelope_id` ASC |
| `BATTERY_STATUS` | yes | `(author_key, EVENT_TYPE_BATTERY_STATUS)` | latest `created_at_hlc`, then `envelope_id` ASC |
| `SHELTER_STATUS` | yes | `(shelter_id, EVENT_TYPE_SHELTER_STATUS)` | trust tier (§10.3); then latest `created_at_hlc`; then `envelope_id` ASC |
| `HAZARD_MARKER` | no | n/a (multiple hazards from same author are all relevant) | n/a |
| `DISASTER_REPORT` | no | n/a (multiple reports relevant) | n/a |
| `SUPPLY_REQUEST` | no | n/a (each request stands; cancel is a separate event) | n/a |
| `SUPPLY_OFFER` | no | n/a | n/a |
| `MATCH_INTENT` | no | n/a (negotiation is a sequence of envelopes) | n/a |
| `NEGOTIATION` | no | n/a | n/a |
| `RELAY_TO_CONTACT` | no | n/a | n/a |
| `OFFICIAL_ALERT_CAP` | yes | `(cap_identifier, EVENT_TYPE_OFFICIAL_ALERT_CAP)` | latest `created_at_hlc`; CAP sequence number breaks ties |
| `OFFICIAL_ALERT_SUMMARY` | yes | `(cap_identifier, EVENT_TYPE_OFFICIAL_ALERT_SUMMARY)` | latest `created_at_hlc` |
| `PROTOCOL_HELLO` | local-only | n/a (handled by 0b connection layer) | n/a |
| `PROTOCOL_NOTICE` | yes | `(notice_id, EVENT_TYPE_PROTOCOL_NOTICE)` | latest `created_at_hlc` |
| `HEARTBEAT` | yes | `(author_key, EVENT_TYPE_HEARTBEAT)` | latest `created_at_hlc` |
| `TRACE_PING` / `TRACE_ACK` | no | n/a | n/a |

LWW does NOT apply to SOS_RED / SOS_YELLOW / HAZARD / SUPPLY_REQUEST / SUPPLY_OFFER per brief §3.2.6 — multiple incidents/offers from the same author at different times are all relevant; do not suppress.

### 10.3 SHELTER_STATUS trust-tier tiebreaker

Two operators broadcasting `SHELTER_STATUS` for the same `shelter_id` MAY conflict. Resolution order:

1. Highest trust tier wins. Tiers: `OFFICIAL_VERIFIED` > `PAIRED` > `SEEN_BEFORE` > `UNVERIFIED`.
2. Within the same tier, latest `created_at_hlc` wins.
3. Within the same HLC ms+counter, `author_key` ASC (deterministic).

The UI MUST surface that a conflict exists (e.g., a small "multiple sources reporting" badge) when two non-superseded reports for the same `shelter_id` exist within `SHELTER_CONFLICT_WINDOW = 30 minutes`.

### 10.4 LWW storage strategy

The `Envelopes` table (§12.2) stores ALL received envelopes (both winners and losers, until tombstone). A second `LWW_Index` table (§12.3) holds only the CURRENT WINNER per LWW key. The dispatch layer reads `LWW_Index` for "what is the current status of author X" queries. This keeps history available for debugging while making LWW lookups O(1).

---

## 11. Category-Specific TTL Defaults

The brief §3.2.9 / §8 require category-specific TTL defaults rather than one global TTL. This section is normative.

### 11.1 TTL components

Each EventType has two complementary expiry mechanisms:

- `max_hops` — initial hop budget, signed by author (§7.1 #7). Relays decrement a receiver-local hop counter; when `hop_count_seen >= max_hops`, drop.
- `expires_at_hlc` — absolute HLC time after which the envelope is dropped/tombstoned regardless of hop count.

### 11.2 Default table

| EventType | Default `max_hops` | Default `expires_at_hlc` offset (from `created_at_hlc`) | Rationale |
|---|---|---|---|
| `STATUS_UPDATE` | 6 | 12 hours | Long enough to reach across a small-town mesh; short enough that stale status doesn't haunt the UI. |
| `BATTERY_STATUS` | 4 | 2 hours | Battery state changes quickly. |
| `SUPPLY_REQUEST` | 8 | 24 hours | Help requests may take time to find an offer; longer reach. |
| `SUPPLY_OFFER` | 8 | 12 hours | Offers should not haunt UI when supplier is long gone. |
| `MATCH_INTENT` / `NEGOTIATION` | 4 | 30 minutes | Tight negotiation timeline. |
| `RELAY_TO_CONTACT` | 10 | 6 hours | High reach (relay-to-contact may need to traverse the entire mesh). |
| `HAZARD_MARKER` | 10 | 24 hours | Hazards are durable; need broad reach. |
| `DISASTER_REPORT` | 10 | 48 hours | Disaster reports remain relevant. |
| `SHELTER_STATUS` | 8 | 6 hours | Shelter capacity changes; refresh expected. |
| `OFFICIAL_ALERT_CAP` | 12 | 6 hours (or CAP-defined `expires` field, whichever is sooner) | Official alerts must reach far; respect CAP's own expiry. |
| `OFFICIAL_ALERT_SUMMARY` | 8 | 6 hours | Same expiry semantics as CAP. |
| `PROTOCOL_HELLO` | 0 (never relayed) | 30 seconds | Capability declaration is one-hop only. |
| `PROTOCOL_NOTICE` | 12 | 7 days | Kill switch needs broad reach and persistence. |
| `HEARTBEAT` | 2 | 5 minutes | Liveness signal; short-lived. |
| `TRACE_PING` / `TRACE_ACK` | 6 | 5 minutes | Diagnostic. |
| `CHAT_MESSAGE` (= 30) | 6 | 24 hours | Locked decision §20.1. |

### 11.3 Author override

The author MAY set a SHORTER `expires_at_hlc` than the default; this is the author's commitment to "this is no longer relevant after X". The author MAY NOT set a LONGER `expires_at_hlc` than the default — the Stage 0c sender MUST clamp to the default. Rationale: prevents a chat message from claiming a 7-day expiry and clogging the mesh.

`max_hops` follows the same rule: the author MAY set a smaller value than the default but MUST NOT exceed the default. Receivers MUST drop envelopes whose `max_hops` exceeds the default for the given event_type with `drop_reason = max-hops-overcommit`.

### 11.4 `PROTOCOL_HELLO` zero-hop rule

`PROTOCOL_HELLO.max_hops = 0` means relays MUST NOT propagate it. This is enforced by `MeshRouter.shouldForwardPacket` returning false whenever `event_type == PROTOCOL_HELLO`, regardless of `max_hops` value (defense in depth). The 0b spec §3.3.4 cross-references this.

---

## 12. DB Schema (Reset Design)

### 12.1 `db_version` table (required from day one)

```sql
CREATE TABLE db_version (
  id          INTEGER PRIMARY KEY CHECK (id = 1),  -- single-row table
  schema_ver  INTEGER NOT NULL,                     -- v0.3 == 2
  applied_at  INTEGER NOT NULL                      -- epoch ms
);
INSERT INTO db_version (id, schema_ver, applied_at) VALUES (1, 2, <now>);
```

The Stage 0c migration helper on first launch:

- If table absent OR `schema_ver < 2`: drop all v0.x application tables, recreate the v0.3 schema, set `schema_ver = 2`.
- If `schema_ver == 2`: no-op.
- If `schema_ver > 2`: refuse to start (forward-compat guard) with a banner asking the user to upgrade the app.

### 12.2 `Envelopes` table (primary store)

```sql
CREATE TABLE envelopes (
  -- Identity
  envelope_id        BLOB PRIMARY KEY,         -- 16 bytes
  protocol_version   INTEGER NOT NULL,         -- always 2 in v0.3
  event_type         INTEGER NOT NULL,         -- EventType enum value
  priority           INTEGER NOT NULL,         -- Priority enum value

  -- Time
  created_at_hlc_ms  INTEGER NOT NULL,
  created_at_hlc_ctr INTEGER NOT NULL,
  expires_at_hlc_ms  INTEGER NOT NULL,
  expires_at_hlc_ctr INTEGER NOT NULL,

  -- Routing
  max_hops           INTEGER NOT NULL,
  hop_count_seen     INTEGER NOT NULL DEFAULT 0,  -- receiver-local

  -- Identity / crypto
  author_key         BLOB NOT NULL,           -- 32 bytes
  sig_algo           INTEGER NOT NULL,
  signature          BLOB NOT NULL,           -- 64 bytes Ed25519

  -- Payload (SHA-256(payload) is recomputable on demand; not stored)
  payload            BLOB NOT NULL,

  -- Receiver-local labels (NEVER on wire)
  signature_status   INTEGER NOT NULL,        -- enum: 0=VALID,1=INVALID,2=MISSING,3=NOT_CHECKED
  source_trust       INTEGER NOT NULL,        -- enum: 0=SELF,1=PAIRED,2=SEEN_BEFORE,3=UNVERIFIED,4=OFFICIAL_VERIFIED

  -- Relay / sync state
  last_relay_id      TEXT,                    -- nullable
  is_experimental    INTEGER NOT NULL DEFAULT 0,
  relay_attempt_count INTEGER NOT NULL DEFAULT 0,
  is_tombstoned      INTEGER NOT NULL DEFAULT 0,  -- §13

  -- Local bookkeeping
  received_at_ms     INTEGER NOT NULL,
  first_seen_via     TEXT                       -- peer short id (nullable)
);

CREATE INDEX idx_envelopes_event_type      ON envelopes (event_type);
CREATE INDEX idx_envelopes_priority         ON envelopes (priority);
CREATE INDEX idx_envelopes_created_hlc      ON envelopes (created_at_hlc_ms DESC, created_at_hlc_ctr DESC);
CREATE INDEX idx_envelopes_expires_hlc      ON envelopes (expires_at_hlc_ms);
CREATE INDEX idx_envelopes_author_key       ON envelopes (author_key);
CREATE INDEX idx_envelopes_lww_lookup       ON envelopes (author_key, event_type, created_at_hlc_ms DESC, created_at_hlc_ctr DESC);
CREATE INDEX idx_envelopes_tombstoned       ON envelopes (is_tombstoned);
```

### 12.3 `LWW_Index` table (current-winner cache)

```sql
CREATE TABLE lww_index (
  lww_key_hash       BLOB PRIMARY KEY,         -- SHA-256 of canonical LWW key tuple
  event_type         INTEGER NOT NULL,
  winning_envelope_id BLOB NOT NULL REFERENCES envelopes (envelope_id) ON DELETE CASCADE,
  winning_hlc_ms     INTEGER NOT NULL,
  winning_hlc_ctr    INTEGER NOT NULL,
  updated_at_ms      INTEGER NOT NULL
);
CREATE INDEX idx_lww_index_event_type ON lww_index (event_type);
```

`lww_key_hash` is SHA-256 of the byte concatenation `<event_type:u32_le> || <lww_key_components>` where the components depend on the EventType per §10.2.

### 12.4 `Tombstones` table

```sql
CREATE TABLE tombstones (
  envelope_id        BLOB PRIMARY KEY,         -- 16 bytes
  event_type         INTEGER NOT NULL,
  expired_at_ms      INTEGER NOT NULL,         -- when the envelope first expired
  tombstone_until_ms INTEGER NOT NULL          -- when this tombstone may be GC'd
);
CREATE INDEX idx_tombstones_until ON tombstones (tombstone_until_ms);
```

See §13 for tombstone policy.

### 12.5 `Mesh_Trace_Logs` table (dev only)

See §15.

### 12.6 `Official_Sources` table (NCDR / CWA pubkey list)

```sql
CREATE TABLE official_sources (
  author_key         BLOB PRIMARY KEY,         -- 32 bytes Ed25519 pubkey
  provider_name      TEXT NOT NULL,            -- "NCDR_CAP", "CWA", ...
  added_at_ms        INTEGER NOT NULL,
  trust_label        INTEGER NOT NULL          -- always OFFICIAL_VERIFIED (4) for now
);
```

Pre-populated at install time from a vendor-signed JSON file shipped with the APK/IPA.

### 12.7 `Profiles` / `Status_Latest` / `Shelter_Latest` / `Supply_*` tables

These are payload-typed views maintained by Stage 0c dispatchers. They are OUT of scope for the wire format spec; they exist to make UI queries fast. The 0a spec defines only the envelope layer; payload-specific tables follow each EventType's needs and are introduced as 0c work items.

The naming convention is `<Concept>_Latest` for LWW-projected tables and `<Concept>_Log` for append-only history.

### 12.8 Index strategy summary

- LWW lookup ("current status of author X"): O(1) via `lww_index.lww_key_hash` PK.
- Dedupe ("have we seen envelope E?"): O(1) via `envelopes.envelope_id` PK + `tombstones.envelope_id` PK.
- Expiry sweep ("envelopes expired before T"): range scan on `idx_envelopes_expires_hlc`.
- Priority filter ("show me SOS_RED"): scan on `idx_envelopes_priority` (low cardinality, augmented by event_type filter).

---

## 13. Tombstone / Expired Sync Policy

### 13.1 Problem statement

If node A drops envelope E because `expires_at_hlc < now`, but node B still holds E, the next IBLT/Bloom sync between A and B will surface E as "A missing → B pushes E back to A → A drops again → infinite re-circulation".

### 13.2 Solution

Tombstones. Conceptually: "I know E existed; I have expired it; do not re-send it to me."

### 13.3 Tombstone lifecycle

```text
   created_at_hlc                    expires_at_hlc        +GRACE_PERIOD          +TOMBSTONE_TTL
        │                                  │                       │                       │
        ▼                                  ▼                       ▼                       ▼
   ┌────────── active in DB ──────────────┐
                                           ┌── still in DB, hidden from UI ──┐
                                                                              ┌── tombstone-only ──┐
                                                                                                    │
                                                                                                    ▼
                                                                                              GC'd
```

- `expires_at_hlc`: envelope is hidden from UI, but ROW IS NOT YET DELETED. `is_tombstoned` remains 0.
- `expires_at_hlc + GRACE_PERIOD`: row is converted to tombstone. `is_tombstoned = 1`. Payload is cleared (set to empty bytes) to save storage; envelope_id, event_type, author_key, and HLC fields are retained. Insert a row in `tombstones` table.
- `expires_at_hlc + GRACE_PERIOD + TOMBSTONE_TTL`: row deleted from `envelopes`; tombstone row deleted from `tombstones`.

### 13.4 Constants

| Constant | Value | Per |
|---|---|---|
| `GRACE_PERIOD` (default) | 1 hour | Most EventTypes |
| `GRACE_PERIOD` (SOS_*) | 6 hours | Keep SOS rows around longer for diagnostic |
| `GRACE_PERIOD` (CHAT) | 5 minutes | Chat decays fast |
| `TOMBSTONE_TTL` | 7 days | All EventTypes |

The 0a spec proposes these defaults; tuning is a 0d acceptance gate question (§3.5 of the brief).

### 13.5 IBLT / Bloom membership

A tombstoned envelope_id REMAINS in this node's IBLT bucket set and Bloom bit-vector for the full tombstone lifetime. Receivers thus claim membership during sync (so peers do not push E back).

Spec rule (normative):

> The IBLT / Bloom membership set on each node = `{envelope_id ∈ envelopes WHERE row exists} ∪ {envelope_id ∈ tombstones}`.
> The "live UI" set on each node = `{envelope_id ∈ envelopes WHERE is_tombstoned = 0 AND expires_at_hlc >= now}`.

These two sets are DIFFERENT. Sync uses the first; UI uses the second.

### 13.6 GC schedule

- On app launch (cold-start path before showing the home tab).
- Every 60 minutes while the foreground service is active.
- Triggered immediately when `envelopes` row count exceeds `MAX_ENVELOPE_ROWS = 50_000` (defensive cap).

GC is one transaction per run, with `BEGIN ... COMMIT` so that an OS kill mid-GC leaves the DB consistent.

### 13.7 Cap on tombstone storage

The risk register (§3.6 of the brief, "Tombstone table grows unbounded under attack") is mitigated by:

- Hard cap: `MAX_TOMBSTONE_ROWS = 100_000`. When exceeded, oldest tombstones (by `tombstone_until_ms` ASC) are evicted regardless of remaining lifetime. Trace logs the eviction (`drop_reason = tombstone-cap-evict`).
- Rate-limit on accepting new envelopes per `author_key`: `MAX_ENVELOPES_PER_AUTHOR_PER_HOUR = 120` (i.e., 2/min average; bursts allowed via token bucket of size 20). Picked over the more conservative 60/h to accommodate community-center / shelter-operator scenarios where a single account legitimately broadcasts many SUPPLY_OFFER + SHELTER_STATUS updates during an active disaster. Excess envelopes from the same `author_key` are dropped with `drop_reason = author-rate-limited` BEFORE entering the DB (so they cannot inflate tombstone count).

The 0c implementation MUST expose both numbers as named constants in a `lib/app/db/tombstone_config.dart` file so a future security audit can adjust them without code spelunking. The 0d acceptance gate MAY exercise this number; if real-device data shows 120/h is still tight, raise to 240/h and re-spec.

---

## 14. Reconnect Minimum Behavior

### 14.1 Spec rule

On reconnect (e.g., re-foregrounding the app, regaining BLE adapter, switching peer):

- Envelopes with `expires_at_hlc < now` are HIDDEN from main UI tabs.
- Envelopes with `expires_at_hlc < now` remain visible in `Now > History` (debug list) only when dev mode is enabled.
- Show a lightweight banner "X stale items hidden" ONLY IF at least one of those envelopes was previously surfaced in the UI to this user (i.e., it appeared in a list or notification). Track via the `envelopes.first_surfaced_in_ui_at_ms` column.

Actually — to keep `envelopes` lean we use a small companion bitmap rather than a per-row timestamp:

### 14.2 Surfacing tracking

Add to `envelopes`:

```sql
ALTER TABLE envelopes ADD COLUMN was_surfaced_in_ui INTEGER NOT NULL DEFAULT 0;
```

UI controllers set this column to 1 when they render an envelope. The reconnect banner counts only `WHERE was_surfaced_in_ui = 1 AND expires_at_hlc < now AND received_at_ms > <last_app_resume_at>`.

This avoids the false-positive of banner-flashing for envelopes that traversed 14 hops, arrived already-expired, and were never visible to the user (brief §3.2.9).

### 14.3 Expired SOS / status / hazard handling

Per brief §3.2.9: do not surface expired SOS / status / hazard as active incidents. They remain accessible via dev-mode trace view (§15).

---

## 15. Dev-Only Mesh Trace Log

### 15.1 Table

```sql
CREATE TABLE mesh_trace_logs (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  ts_ms              INTEGER NOT NULL,
  envelope_id        BLOB NOT NULL,
  event_type         INTEGER NOT NULL,
  priority           INTEGER NOT NULL,
  author_key_hash    BLOB NOT NULL,            -- SHA-256(author_key)[:8] for privacy
  last_relay_id      TEXT,
  created_at_hlc_ms  INTEGER NOT NULL,
  expires_at_hlc_ms  INTEGER NOT NULL,

  action             INTEGER NOT NULL,         -- 0=SENT, 1=RECEIVED, 2=DROPPED, 3=RELAYED
  drop_reason        TEXT,                     -- nullable; one of the named codes below
  dedupe_outcome     INTEGER,                  -- 0=miss (new), 1=hit (dup)

  signature_status   INTEGER,                  -- enum value
  source_trust       INTEGER,                  -- enum value
  hop_count_seen     INTEGER,
  relay_attempt_count INTEGER,
  peer_id            TEXT                      -- safe-to-log peer short id
);

CREATE INDEX idx_mesh_trace_ts          ON mesh_trace_logs (ts_ms);
CREATE INDEX idx_mesh_trace_envelope_id ON mesh_trace_logs (envelope_id);
CREATE INDEX idx_mesh_trace_action      ON mesh_trace_logs (action);
CREATE INDEX idx_mesh_trace_drop_reason ON mesh_trace_logs (drop_reason);
```

### 15.2 Named `drop_reason` codes

The 0c implementation MUST emit only these (defined as a Dart `enum DropReason` whose `.name` matches the string):

Envelope-layer drop reasons (EnvelopeDispatcherV2):

- `decode-required-field-missing`
- `unknown-protocol-version` (Stage 0c wave 3E — `protocol_version != 2`)
- `unknown-sig-algo`
- `signature-invalid` (covers both forged signature AND payload tampering, since `SHA-256(payload)` mismatch surfaces as a signature failure)
- `max-hops-overcommit` (§11.3 — `max_hops > default` per event type)
- `envelope-expired` (Stage 0c wave 3E — covers BOTH `expires_at_hlc < created_at_hlc` (logical violation, always-checked) AND `expires_at_hlc < now` (clock-based; gated behind dispatcher `enableClockBasedExpiry` flag — production main.dart wires `true`))
- `tombstone-hit` (peer pushed an envelope we have already tombstoned)
- `dedupe-hit` (Stage 0c wave 3E — peer pushed an envelope we have a LIVE row for; previously this slipped through as silent-accept-not-LWW-winner, now an explicit DROP per §7.5 #9)
- `priority-mismatch`
- `priority-downgraded` (not a drop, but logged with `action = RECEIVED` and this annotation)
- `over-budget-sos-rejected` (sender)
- `over-budget-sos-received` (receiver defense in depth)
- `over-budget-priority`
- `unknown-event-type`
- `is-experimental-not-relayed`
- `author-rate-limited`
- `ttl-zero` (hop count exhausted; emitted by MeshRouter, not the dispatcher)
- `tombstone-cap-evict`

Transport-layer drop reasons (Chunker / Reassembler):

- `chunk-bad-header`
- `invalid-envelope-id`
- `mtu-below-minimum-for-chunked`
- `over-max-chunks`
- `over-max-envelope-bytes`
- `reassembly-envelope-id-mismatch`
- `reassembly-timeout`

Sender / per-peer drop reasons (BleV2Bridge.sendEnvelope):

- `peer-not-ready` (HELLO handshake still in progress)
- `peer-hello-failed`
- `peer-no-chunking` (peer profile cannot reassemble multi-chunk envelopes)
- `native-write-failed`
- `peer-mtu-too-low-for-sos` (SOS at MTU=23 — see 0b §7.2)

DEPRECATED — DO NOT EMIT in v0.3:

- `expired` — superseded by `envelope-expired` (more explicit name; corpus + Stage 0c wave 3E use `envelope-expired`).

### 15.2.1 System events (Stage 0c wave 3E)

Adapter-health + debug-hook observability writes rows to the same
`Mesh_Trace_Logs` table with `drop_reason = '<category>:<action>'` so the
dev-mode trace screen + 0d-gate test runner can read them with the same
queries used for envelope drops. Currently emitted:

- `adapter_health:adapter_idle_too_long`
- `adapter_health:adapter_soft_recover`
- `adapter_health:adapter_hard_recover`
- `adapter_health:adapter_permanent_error`
- `mesh_debug:force_target_mtu`
- `mesh_debug:force_adapter_idle`

In addition, the Android peripheral may emit a transient `iblt_low_mtu_fallback` event on the native channel (not the trace table) when an IBLT response cannot be single-noticed because the per-link MTU is below 517. Payload shape:

```jsonc
{
  "type": "iblt_low_mtu_fallback",
  "device": "<peer address>",
  "response_size": 513,
  "mtu_cap": <effective single-notify cap, e.g. 182 or 244>,
  "event_count": <events in our outbox>
}
```

The peripheral falls back to `pushOutboxToDevice` (blind push of all outbox events) in this case. Sync correctness is preserved; the IBLT delta optimization is lost at low MTU. A future wave introduces a chunked IBLT response with a new control byte; until then this fallback event is the canonical observation channel for "we hit the low-MTU IBLT degradation."

System-event rows use a synthetic `envelope_id` of 16 bytes starting with
ASCII `'SYS'` (0x53 0x59 0x53) followed by zero bytes — distinct from any
real UUIDv7 (version nibble 0x7) and easy to filter out of envelope-flow
queries (`WHERE envelope_id NOT LIKE X'535953%'`).

### 15.3 Retention

- 24-hour TTL — older rows GC'd by the same sweeper that runs the tombstone GC (§13.6).
- Hard cap: `MAX_TRACE_ROWS = 200_000`. Exceeding the cap evicts oldest rows first.

### 15.4 Privacy

- `author_key` is hashed (SHA-256 first 8 bytes) before logging. Never store the full key in trace.
- `payload` is NEVER written to trace.
- `peer_id` (short BLE device id) is logged because it is needed for diagnosis; it is local-only.

### 15.5 Why not fold into `Debug_Logs`

`Debug_Logs` is free-text. Mesh trace MUST be queryable by `action`, `drop_reason`, `event_type`, etc. Folding into a free-text table loses all of that. Per brief §3.2.10: "It is NOT acceptable to fold mesh trace into the free-text `Debug_Logs` table."

### 15.6 Not a UI feature in v0.3

The 0a spec stops at the table. A user-facing dashboard is explicitly deferred to v0.4. v0.3 may include a hidden dev screen (e.g., long-press on About) that lists recent trace rows — that is a Stage 1 implementation detail, NOT a spec requirement.

---

## 16. Two-Stage STATUS → SUPPLY Relationship

### 16.1 Rule

A `STATUS_UPDATE` envelope with any `NeedEntry` is NOT itself a supply-matching event. The supply-matching event is a SEPARATE `SUPPLY_REQUEST` envelope.

- The STATUS_UPDATE carries: "I'm injured, I need water (NEED_URGENT)."
- The SUPPLY_REQUEST carries: "I want 2L of water at this location by 18:00." with a different envelope_id, different `created_at_hlc`, possibly different `priority` (most likely RESOURCE).
- The UI MAY prompt the user "Create a supply request from this need?" but MUST NOT auto-create one without explicit confirmation.

### 16.2 Why two stages

- Compound state ("I am safe but need water") needs a snapshot envelope that does NOT clog the supply-matching system. STATUS_UPDATE is for awareness; SUPPLY_REQUEST is for matching.
- Supply matching has its own lifecycle (offer → match → confirm → cancel) that is not part of status snapshots.
- The 0a LWW table (§10.2) handles each correctly: STATUS_UPDATE is LWW per author; SUPPLY_REQUEST is NOT LWW (multiple requests are independent).

### 16.3 Cross-reference in UI

When STATUS_UPDATE displays a `NeedEntry`, the UI MAY display a small "Create supply request" affordance. This action opens the supply-request composer pre-filled with the need category and severity. The composer ultimately produces a SUPPLY_REQUEST envelope, signed independently with its own envelope_id.

### 16.4 No envelope-level "parent_id" linkage

The 0a spec deliberately does NOT add a `parent_envelope_id` field to envelope or to `SupplyRequestData`. Rationale: the linkage is UI-level convenience, not a wire-level necessity. A SUPPLY_REQUEST stands on its own.

---

## 17. Cross-Platform Conformance Corpus (Envelope Slice)

### 17.1 File

`docs/specs/wire_conformance_v1.json` — a single JSON file co-owned by 0a and 0b. The envelope slice of this corpus is 0a's responsibility.

The corpus is **deterministic** (no live timestamp); it carries a `corpus_revision` string + `spec_date`, currently `v0.3-stage0c-wave3d-1` / `2026-05-13`. A `notes` object documents corpus-wide conventions. Re-generating MUST produce a byte-identical file; see 0b §11.7 for the `--check` mode that enforces this on CI.

### 17.2 Sample shape (envelope slice)

Each envelope sample is one of two flavors. Both carry the structural envelope plus the canonical Ed25519 signature input bytes (the 124-byte block fed into `Ed25519.sign`), per §8.

**Unsigned sample** — used for procedural coverage (per-EventType × per-Priority, size boundaries, chunking shape):

```json
{
  "kind": "envelope",
  "name": "<stable identifier>",
  "description": "<one line>",
  "envelope_struct": {
    "protocol_version": 2,
    "envelope_id_hex": "<32 hex chars>",
    "event_type": 30,
    "priority": 6,
    "created_at_hlc": { "ms_since_epoch": 1747350100000, "counter": 0 },
    "expires_at_hlc": { "ms_since_epoch": 1747436500000, "counter": 0 },
    "max_hops": 6,
    "author_key_hex": "<64 hex chars>",
    "sig_algo": 1,
    "payload_hex": "<hex string for small payloads>",
    /* OR for large payloads, use a generator descriptor instead of inline hex: */
    "payload_generator": { "algorithm": "lcg_byte_pattern_v1", "seed": 12345, "size": 1024 },
    "is_experimental": false
  },
  "payload_sha256_hex": "<64 hex chars>",
  "expected_canonical_sig_input_bytes": 124,
  "expected_canonical_sig_input_hex": "<248 hex chars>"
}
```

Each `envelope_struct` carries exactly ONE of `payload_hex` (raw inline) or `payload_generator` (deterministic descriptor). Inline `payload_hex` is used for small payloads where readability matters; `payload_generator` (currently `lcg_byte_pattern_v1`, documented in `notes.payload_generator_lcg_byte_pattern_v1`) is used for larger payloads to keep the corpus diffable. There is NO `payload_b64` field — payloads are either raw hex or generated bytes.

**Signed sample** — same as above plus a worked Ed25519 signature against a deterministic test-only key. The conformance test verifies these live to catch CanonicalEncoderV2 drift:

```json
{
  "kind": "envelope",
  "name": "...",
  "envelope_struct": { ... },
  "payload_sha256_hex": "...",
  "expected_canonical_sig_input_bytes": 124,
  "expected_canonical_sig_input_hex": "...",
  "derived_author_key_hex": "<64 hex chars = 32-byte Ed25519 public key>",
  "test_only_private_key_hex": "<64 hex chars = 32-byte Ed25519 seed; TEST ONLY>",
  "expected_signature_hex": "<128 hex chars = 64-byte Ed25519 sig>"
}
```

The canonical signature input is the source-of-truth byte stream; the conformance test asserts `len == 124` on every sample. `payload_sha256_hex` is the locally-computed payload hash that feeds the canonical input (per §3.2, §7.1 #10, §8.2) and is NOT a wire field — it's surfaced in the corpus only so consumers can verify the canonical input was built correctly.

### 17.2.1 Coverage (envelope slice)

- ≥ 100 envelope samples (v3D ships 104: ~70 unsigned procedural + ~34 signed).
- ≥ 1 sample per EventType.
- ≥ 1 sample per Priority.
- ≥ 5 SOS_RED samples bracketing the 240 B envelope cap.
- ≥ 5 ALERT samples sized to REQUIRE chunking (> single-notify capacity but ≤ 800 B).
- ≥ 1 RESOURCE sample at the 400 B cap.
- ≥ 1 NORMAL sample at exactly `MAX_ENVELOPE_BYTES = 2048` (the 0b §4.6 cap).
- ≥ 5 worked Ed25519 signature samples per §8.3 (v3D ships 30+).

### 17.3 Negative cases (≥ 10)

Negative cases live in the `negative_cases` array (shared with the transport slice — see 0b §11.5). Each carries a `kind`, a `description`, and an `expected_drop_reason` from the spec-recognized vocabulary.

Envelope-layer negatives covered by v3D corpus:

- `unknown_sig_algo` → `unknown-sig-algo`
- `oversize_sos` → `over-budget-sos-rejected`
- `oversize_envelope` → `over-max-envelope-bytes`
- `unknown_protocol_version` → `unknown-protocol-version`
- `expires_before_created` → `envelope-expired`

Additional envelope-layer negatives planned for follow-up waves (RESOURCE / NORMAL over-budget, signature tampered, CHAT_MESSAGE-at-SOS_RED priority crossing, unknown non-experimental EventType, max_hops over default): tracked but not in v3D. Each addition is a single new entry in `negative_cases` + a generator helper.

### 17.4 CI gate

Each of Dart / Kotlin / Swift MUST encode every positive sample's canonical signature input bit-identically (124 bytes), verify every signed sample with the embedded Ed25519 public key, and reject every negative sample with the documented `expected_drop_reason`. CI is part of the Stage 0c acceptance check (brief §3.4). See 0b §11.6 for the cross-platform consumer-wiring status.

### 17.5 Test vector generation tooling

A Dart-only `tool/generate_wire_conformance_v1.dart` script produces the JSON from a set of hand-authored YAML scenarios PLUS programmatically expanded procedural cases. It is the ONLY source of truth for new test vectors. Kotlin and Swift implementations are CONSUMERS of the JSON; they MUST NOT regenerate the corpus.

The script lives at `resqmesh_app/tool/generate_wire_conformance_v1.dart`. Its YAML inputs live under `resqmesh_app/test/wire_conformance/scenarios/` (sorted by path for determinism). Its output (the JSON) is committed to `docs/specs/wire_conformance_v1.json`. See 0b §11.7 for the `--check` mode contract; the corpus's `corpus_revision` string bumps on any intentional shape change.

---

## 18. Freeze Policy Text (For CLAUDE.md and docs/protocol.md)

The text below is the verbatim block to paste into BOTH `CLAUDE.md` (root) and a new `docs/protocol.md` after v0.3 ships. Do not paste it now — the spec is still in review.

```markdown
## Protocol Freeze Policy (v0.3 onward)

After v0.3 is shipped to public/closed beta, the following rules apply:

1. **Envelope v2 wire format is frozen.**
   - `EventEnvelope` protobuf field tags MUST NOT be reused.
   - Removed fields MUST be reserved via `reserved <tag>;` in the proto.
   - The legacy `MeshEnvelope` and `MeshEvent` messages are deprecated and
     their field tags are reserved within their own messages. They are NOT
     compatibility targets; v0.3+ readers never decode v0.2 bytes.

2. **EventType enum values are frozen.**
   - Values MUST NOT be reused. Removed types MUST be reserved.
   - Legacy values `MATCH_INQUIRY=10`, `MATCH_AVAILABLE=11`, `MATCH_GONE=12`
     are permanently reserved.
   - New EventType values follow the `EVENT_TYPE_<GROUP>_<NAME>` prefix.
   - New values go in the existing group's reserved range; do not allocate
     a new group without a spec amendment.

3. **DB schema changes require migrations.**
   - The `db_version` table bumps with every schema change.
   - Wiping local data is no longer acceptable after v0.3 — write a real
     migration helper.

4. **`PROTOCOL_NOTICE` is the only sanctioned post-freeze emergency channel.**
   - Vendor-signed `PROTOCOL_NOTICE` envelopes (signed by the vendor key
     documented in `docs/protocol.md`) may pause specific EventTypes or
     prompt upgrades. This is the kill switch; do not invent new ones.

5. **Signature scope is frozen.**
   - Adding fields to the signed set requires bumping `protocol_version`
     and a v0.4 spec amendment.
   - The canonical encoding (envelope_v2_spec_2026-05-13.md §8) is the
     normative source — not the generated protobuf serializer.

6. **`sig_algo` reservation discipline.**
   - `0x01` (Ed25519) is the only v0.3 algorithm.
   - `0x02-0xFF` are reserved for crypto agility. Allocations require a
     spec amendment.

7. **Storage reset is not permitted after v0.3 freeze.**
   - The migration helper from v0.3 → v0.4 MUST preserve user data.
```

Required documentation locations after spec acceptance:

- `CLAUDE.md` (root) — append a `## Protocol Freeze Policy` section with the text above.
- `docs/protocol.md` (new file) — same text plus the vendor pubkey for `PROTOCOL_NOTICE` and the canonical encoding worked example.

---

## 19. Acceptance Checklist For 0a Spec Review

Per brief §9.1:

- [x] Legacy `MeshEnvelope` is deprecated; its field tags are scoped to the legacy message; `EventEnvelope` v2 has its own tag space — §2, §3.
- [x] Protobuf field tags are stable, sparse, and future-safe (single-byte hot fields; `reserved 15 to 31`) — §3.2.
- [x] Removed/experimental fields planned with `reserved` behavior — §2.3, §3.1, §4.1.
- [x] EventType enum groups broad enough with gaps — §4.1.
- [x] `EVENT_TYPE_STATUS_UPDATE` is a single type with snapshot payload — §5.
- [x] `StatusUpdateData` models compound state with per-need `expires_at_hlc` — §5.1.
- [x] TTL defaults appropriate per category — §11.
- [x] `max_hops` and `expires_at_hlc` are separate fields — §3.1.
- [x] `expires_at_hlc` in HLC time, not wallclock — §3.1 (`HlcTimestamp`).
- [x] Reconnect filtering avoids resurfacing stale emergencies — §14.
- [x] Tombstone policy defined; expired envelopes do not re-circulate — §13.
- [x] Source trust labels defined; unverified data not pretending to be official — §3.3, §6.2.
- [x] Signature status explicit and testable — §3.3, §7.5.
- [x] Signature scope white-list defined (author-bound vs relay-mutable) — §7.
- [x] `sig_algo` reserved for crypto agility — §3.1, §18.
- [x] Priority validation by receiver enforced against event_type (matrix) — §6.
- [x] Payload budgets concrete (byte numbers) per priority — §9.
- [x] Dedupe and LWW keys explicitly derived per EventType (table) — §10.
- [x] DB schema supports dedupe, expiry, priority, relay state efficiently — §12.
- [x] `db_version` table from day one — §12.1.
- [x] Dedicated `Mesh_Trace_Logs` table — §15.
- [x] LWW snapshot semantics for STATUS_UPDATE by same `author_key` — §5.2, §10.2.
- [x] STATUS_UPDATE ↔ SUPPLY_REQUEST documented as two-stage — §16.
- [x] EventType values use `EVENT_TYPE_<GROUP>_<NAME>` prefix — §4.2.
- [x] `author_key` distinct from `last_relay_id` in storage, signature, trace — §3.1, §7, §15.
- [x] Trace logging is useful without exposing sensitive data — §15.4.
- [x] `PROTOCOL_NOTICE` defined as post-freeze kill switch — §4.1, §18.

---

## 20. Decisions Locked (Sign-Off 2026-05-15)

The previously open questions are CLOSED. Each decision below is the canonical input to Stage 0c. The only items requiring further work are flagged as `[process]` (owner action outside this spec).

| # | Topic | Decision | Section |
|---|---|---|---|
| 20.1 | `CHAT_MESSAGE` slot | `EVENT_TYPE_CHAT_MESSAGE = 30` under 20-49 coordination group; `reserved 13` (legacy value) | §4.1, §6.1 |
| 20.2 | HLC canonical encoding endianness | **Little-endian** (matches Dart/Kotlin/Swift native; computed millions of times per device) | §8.2 |
| 20.3 | `envelope_id` format | **UUIDv7** mandatory. Author generates; relays never mutate. Time-sorted prefix aids `envelopes` table scans. | §3.1, §10.1 |
| 20.4 | `lww_key_hash` storage | 32-byte `BLOB` PK; SHA-256 collision is cryptographically infeasible. | §12.3 |
| 20.5 | `MAX_ENVELOPES_PER_AUTHOR_PER_HOUR` | **120** (token bucket size 20). Picked to accommodate community-center / shelter-operator authors during active disaster. 0d may revisit. | §13.7 |
| 20.6 | SOS envelope budget | **240 B** (bumped from 200 B). Cost: 2 chunks at both MTU=247 and MTU=185 (≈ +5-10 ms latency at MTU=247 vs the 200 B single-notify case); benefit: ~70-80 B typed payload room → ~25 CJK chars brief text. Acceptable for the disaster-mesh use case. | §9 |
| 20.6.1 | MTU baseline | Derived from MTU=247; verified at MTU=185. Numbers reconcile with 0b §7 matrix. | §9, 0b §7 |
| 20.7 | `OFFICIAL_ALERT_CAP` LWW key | Payload-driven `(cap_identifier, EVENT_TYPE_OFFICIAL_ALERT_CAP)`. The dispatcher decodes payload to derive the LWW key. The 0c implementation MUST document this in the OFFICIAL_ALERT_CAP dispatcher with an inline reference to this section. | §10.2 |
| 20.8 | `PROTOCOL_NOTICE` vendor key custody `[process]` | (a) Project owner generates Ed25519 keypair OFFLINE (air-gapped machine) BEFORE v0.3 ships. (b) Pubkey published in `docs/protocol.md` AND baked into the app binary as a compiled-in constant. (c) Private key stored in encrypted offline backup with multi-location replication. (d) Spec is otherwise complete; this is a release-engineering action item. | §18, 0b §5.8 |
| 20.9 | `signature_status = INVALID` handling | DROP from `envelopes` table; FULL row written to `mesh_trace_logs` with `drop_reason = signature-invalid` so dev mode can investigate forgery attempts. | §7.5, §15 |
| 20.10 | `is_experimental` on wire | KEEP as on-wire boolean. Belt-and-suspenders against EventType-range-only signaling; absent (varint default) for `false`, costing at most 2 bytes when set. | §3.1, §7.4 |

### 20.11 Cross-spec reconciliation

This decision table has been mirrored into 0b §15 (Decisions Locked). Both specs MUST be treated as a single design unit; any future amendment to a number in this table requires updating both files plus the roadmap brief.

---

End of envelope_v2_spec_2026-05-13.md.
