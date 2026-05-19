# Native Transport v1 Spec — Stage 0b Deliverable

Date: 2026-05-13 (drafted 2026-05-15)
Source brief: `text/resqmesh_v0.3_v0.5_protocol_roadmap_spec_brief_2026-05-13.md` §1, §3.3
Companion spec: `docs/specs/envelope_v2_spec_2026-05-13.md` (Stage 0a — wire format, signature, payload budgets, DB)
Status: REVIEW DRAFT — spec-only; no app/proto/Dart/Kotlin/Swift/UI changes.
Scope: BLE transport parity between Android (Kotlin), iOS (Swift), and Dart. App-level chunking + reassembly, P0 removal of Android's 514-byte truncation, iOS parity work plan, `PROTOCOL_HELLO` capability negotiation, capability profile catalog, MTU range matrix, BLE adapter recovery story, conformance corpus (transport slice), risk register additions.

---

## Table of Contents

1. [Scope, Constraints, and Non-Goals](#1-scope-constraints-and-non-goals)
2. [P0: Android 514-Byte Silent Truncation Removal Plan](#2-p0-android-514-byte-silent-truncation-removal-plan)
3. [iOS Parity Work Plan](#3-ios-parity-work-plan)
4. [App-Level Chunking + Reassembly Framing](#4-app-level-chunking--reassembly-framing)
5. [PROTOCOL_HELLO — Capability Negotiation](#5-protocol_hello--capability-negotiation)
6. [Capability Profile Catalog](#6-capability-profile-catalog)
7. [MTU Range Support Matrix](#7-mtu-range-support-matrix)
8. [BLE Adapter Recovery Story](#8-ble-adapter-recovery-story)
9. [iOS Background Advertising Notes](#9-ios-background-advertising-notes)
10. [Android Foreground-Service Notes](#10-android-foreground-service-notes)
11. [Cross-Platform Conformance Corpus (Transport Slice)](#11-cross-platform-conformance-corpus-transport-slice)
12. [Cross-Spec Constraints with 0a](#12-cross-spec-constraints-with-0a)
13. [Risk Register — Native Transport Additions](#13-risk-register--native-transport-additions)
14. [Acceptance Checklist For 0b Spec Review](#14-acceptance-checklist-for-0b-spec-review)
15. [Decisions Locked (Sign-Off 2026-05-15)](#15-decisions-locked-sign-off-2026-05-15)

---

## 1. Scope, Constraints, and Non-Goals

### 1.1 In scope

- Concrete plan to remove the 514-byte silent truncation in Android's foreground service (`IgniRelayForegroundService.kt:607` and `:940`), replacing it with MTU-driven app-level chunking.
- iOS parity work plan against Android: `IBLT.swift`, Bloom-diff push, Long Write / Prepared Write, MTU upcall, 10-second subscribe→Bloom fallback timer, advertising error events.
- App-level chunking + reassembly framing (cross-platform, deterministic, order-independent).
- `EVENT_TYPE_PROTOCOL_HELLO` envelope: timing, fields, 5-second degradation rule.
- Capability profile catalog: `PhoneV1-legacy`, `PhoneV1`, `BleNodeV1`, `Tier0Mule`.
- MTU range support matrix: 23 / 185 / 247 / 512.
- BLE adapter recovery story: overheating, scan starvation, advertising failure.
- Cross-platform wire conformance corpus requirements for chunking, IBLT bucket state, Bloom bit-vector (the envelope slice is owned by 0a §17).
- Risk register entries specific to native transport.

### 1.2 Hard constraints (per roadmap §8 handoff)

- DO NOT modify app code, proto files, Dart, Kotlin, or Swift sources while writing this spec.
- DO NOT touch the UI prototype document.
- 0b's chunk framing and MTU baseline are mutually constraining with 0a payload budgets; both specs MUST agree on numbers.
- iOS Critical Alerts entitlement does NOT block this spec; it is documented for awareness only.
- Until 0c lands, the truncation bug remains tracked here as P0 silent data corruption. Do not modify code in this spec phase just to add TODO comments.

### 1.3 Non-goals (v0.3)

- Wire fragmentation BELOW the BLE link layer (link-layer fragmentation is the OS's job; spec does not depend on it).
- Battery-aware scan duty cycling (deferred to v0.4 — current 0b focus is correctness, not power optimization).
- Multi-radio (Wi-Fi Direct / LoRa) transport. v0.3 is BLE-only. Capability profile groundwork accommodates future radios but does not implement them.
- iOS Critical Alerts entitlement integration. Independent track.
- A user-facing "mesh health" dashboard (deferred to v0.4 per brief §1.3).

### 1.4 Stage relationship

```text
0a (envelope_v2_spec) ──────┐
                            ├── cross-reviewed before 0c
0b (native_transport_v1) ───┘
                ↓ spec acceptance
0c implementation (Dart + Android + iOS, parallel lanes)
                ↓ all lanes integrated
0d real-device acceptance gate
                ↓ pass
Stage 1 — UI / user-facing features
```

This spec is 0b. It MUST be readable independently, but design decisions reference 0a where the wire format constrains the transport (and vice versa).

---

## 2. P0: Android 514-Byte Silent Truncation Removal Plan

### 2.1 Bug statement (current state)

**Files & lines (verified 2026-05-15):**

- `resqmesh_app/android/app/src/main/kotlin/network/ignirelay/ignirelay_app/IgniRelayForegroundService.kt:607` — inside `pushOutboxToDevice`:
  ```kotlin
  val safeEvent = if (event.size > 514) event.copyOf(514) else event
  ```
- Same file `:940` — inside `pushDiffToDevice`:
  ```kotlin
  val safePacket = if (packet.size > 514) packet.copyOf(514) else packet
  ```

**Behavior:**

- The notify path silently truncates payloads larger than 514 bytes to exactly 514 bytes.
- The notify call returns success because the BLE stack accepts the truncated bytes.
- The receiver fails Ed25519 verification on the truncated bytes (envelope is now incomplete) and silently drops the event.
- The sender's logs show "success".
- Neither side surfaces "data was lost".

**Severity classification:** P0 silent data corruption. Not a soft cap, not a defensive guard.

**Why 514 specifically:** the historical assumption was MTU = 517 (the BLE 5.x maximum) minus 3 bytes for the ATT header. In reality the negotiated MTU is often LOWER than 517 on Android peers, so even the 514 constant overshoots; AND when payloads exceed it, truncation silently corrupts.

### 2.2 Spec goal

Replace both lines with an MTU-aware app-level chunker (§4) that:

1. Refuses to send envelopes whose total serialized size exceeds `MAX_ENVELOPE_BYTES = 2048` AT ENQUEUE TIME (publish-side rejection).
2. For envelopes within budget, splits into chunks sized by the actually negotiated `ATT_MTU` (Android already exposes this via `onMtuChanged` at `IgniRelayForegroundService.kt:457`).
3. Emits chunks via the existing notify path with no truncation.
4. The receiver reassembles per §4 before signature verification.

### 2.3 Required code changes for Stage 0c (NOT this spec)

This list is the punch list 0c2 (Android) executes; spec only declares it.

| Change | File | Line (current) | Change kind |
|---|---|---|---|
| Remove `event.copyOf(514)` | `IgniRelayForegroundService.kt` | 607 | DELETE; replace with `chunker.split(event, mtu).forEach { notify(it) }` |
| Remove `packet.copyOf(514)` | `IgniRelayForegroundService.kt` | 940 | DELETE; same replacement |
| Add `Chunker` class | `IgniRelayForegroundService.kt` (or new `Chunker.kt`) | new | implements §4 framing |
| Add `Reassembler` class | `IgniRelayForegroundService.kt` (or new `Reassembler.kt`) | new | implements §4 reassembly |
| Wire `onMtuChanged` to update per-device MTU map | `IgniRelayForegroundService.kt` | 457 | EXTEND; current handler exists but does not feed the chunker because no chunker exists yet |
| Add publish-side size check | Dart `MessagePublisher` (Stage 0c1) | new | reject `> MAX_ENVELOPE_BYTES` |

### 2.4 Spec rule

The strings `copyOf(514)` and the literal integer `514` MUST NOT appear in `IgniRelayForegroundService.kt` after Stage 0c2 lands. CI guard: a `tool/check_no_truncation.dart` script greps for these patterns and fails the Stage 0c2 PR if either is found.

### 2.5 Why the truncation cannot be "fixed" by raising the constant

Raising 514 → 600 (or 517) does NOT fix the bug:

- The negotiated MTU varies per pair. On a phone that negotiates MTU=185, anything >182 will still be silently truncated.
- The bug is "we silently corrupt anything bigger than a hard-coded constant"; the fix is "we never silently corrupt; we either chunk or reject".

This rationale MUST be in the PR description for the Stage 0c2 changes so that future contributors do not "fix" the bug by bumping the constant.

### 2.6 Tracking until 0c lands

Per brief §1.10:
- This spec section is the canonical reference for the bug.
- The Stage 0c2 PR checklist (to be drafted in Stage 0c) MUST link to this section by anchor.
- DO NOT touch app code in this spec-only phase to add TODO comments. The bug is documented here; that is sufficient.

---

## 3. iOS Parity Work Plan

### 3.1 Current iOS state (verified 2026-05-15)

`resqmesh_app/ios/Runner/BlePlugin.swift` is at MVP. The following gaps relative to Android are confirmed by code inspection:

| Gap | Current iOS | Android reference |
|---|---|---|
| IBLT Fast Path | absent — no `IBLT.swift` file | `IBLT.kt` (504-byte bucket array, CRC32+FNV-1a+MurmurHash3) |
| Bloom-diff push | `pushOutboxToSubscriber(_ central:)` at line 476 blind-pushes the full outbox via `peripheralManager?.updateValue` without any difference check | `pushDiffToDevice` at `IgniRelayForegroundService.kt:867` does Bloom-bit-vector diff first |
| Long Write / Prepared Write | absent (no `peripheralManager(_:didReceiveRead:)` or `prepareWrite` handling for incoming writes) | (Note: Android receives Long Writes by default through GATT server) |
| MTU upcall to Dart | absent (no `peripheral(_:didNegotiateMtu:)` and no `gatt_mtu` event) | `IgniRelayForegroundService.kt:457` `onMtuChanged` calls into Dart EventChannel |
| 10s subscribe→Bloom fallback timer | absent | implicit in Android — relies on receiving a Bloom write within reasonable time, but on iOS there is no fallback when the subscribe completes and no Bloom arrives |
| `peripheralManagerDidStartAdvertising` error events | minimal — line 604 logs locally; no event emitted to Dart | Android emits `gatt_server_error` event with shape `{kind, message}` |

### 3.2 Required deliverables (Stage 0c3)

Stage 0c3 (iOS native lane) implements the following. Each must reach BIT-IDENTICAL behavior with the Android counterpart, verified by the conformance corpus (§11).

#### 3.2.1 `ios/Runner/IBLT.swift`

- Port `IBLT.kt` 1:1.
- Constants: `bucketCount = 56`, `bucketSize = 9`, `totalBytes = 504`, `hashFunctions = 3`.
- Bucket layout: `count: Int8, keySum: UInt32, hashSum: UInt32` (1+4+4 = 9 bytes per bucket).
- Hash functions:
  - `_crc32(eventId)` — CRC32 of UTF-8-encoded `eventId` string.
  - `_fnv1a(eventId)` — FNV-1a 32-bit of UTF-8-encoded `eventId`.
  - `_murmurHash(bytes, seed)` — MurmurHash3 32-bit, used 3 times with seeds 0/1/2 to derive bucket indices.
- Endianness: explicit little-endian for serialization to BLE bytes (`UInt32` → 4-byte LE on the wire). The Dart `iblt.dart` and Kotlin `IBLT.kt` MUST match — see §11 conformance corpus.
- Public surface: `insert(_ eventId: String)`, `remove(_ eventId: String)`, `subtract(_ other: IBLT) -> IBLT`, `peel() -> IBLTPeelResult?`, `toBytes() -> Data`, `static func fromBytes(_ data: Data) -> IBLT?`.

#### 3.2.2 Bloom-diff push (replacement for `pushOutboxToSubscriber`)

- Move the existing blind-push into a fallback path used only when no Bloom write arrives (see §3.2.5).
- Add a new `pushDiffToSubscriber(_ central: CBCentral, remoteBloomBytes: Data)` method that mirrors Android's `pushDiffToDevice` logic:
  - Decode `remoteBloomBytes` as a Bloom bit-vector (with the magic-header detection — see §11).
  - For each envelope in the local outbox, compute its Bloom-membership index; if absent in `remoteBloomBytes`, push it.
  - Apply the same `MAX_PUSH_BUDGET_PER_SYNC` cap as Android (defined in `IgniRelayConstants.kt`; mirrored in Swift constants).
- The chunker (§4) wraps each outgoing envelope.

#### 3.2.3 Long Write / Prepared Write incoming handling

- Implement `peripheralManager(_:didReceiveWrite:)` for `requests.count > 1` (multi-write Long Write transactions).
- Buffer prepared writes per-central in a dictionary keyed by `central.identifier`.
- On `peripheralManager(_:didReceiveExecuteWrite:)`, concatenate the buffered fragments, decode as one BLE-link-layer payload, then hand to the chunker reassembler (§4).
- This is the OS-level Long Write mechanism (BLE 4.0+ spec). It is DISTINCT from app-level chunking (§4): Long Write covers a SINGLE BLE write that exceeds MTU; app-level chunking covers an envelope split across MULTIPLE BLE notify operations. Both layers must be present.

#### 3.2.4 MTU upcall

- Implement `peripheral(_:didOpen:)` and observe MTU via `peripheral.maximumWriteValueLength(for: .withResponse)` once service discovery completes. iOS does not expose a `didNegotiateMtu` callback directly; the equivalent is `peripheral.maximumWriteValueLength(for:)` after `didDiscoverServices`.
- Emit a Flutter EventChannel event `{ event: "gatt_mtu", peer_id: <peerId>, mtu: <int> }` to Dart, mirroring the Android shape so the Dart-side handler is symmetric.
- Maintain a per-peer MTU map. Default to `185` (the conservative low-end) until the upcall fires.

#### 3.2.5 10-second subscribe→Bloom fallback timer

- After `peripheralManager(_:central:didSubscribeTo:)`, start a 10-second timer per `central.identifier`.
- If a Bloom write arrives on `BLOOM_CHAR_UUID` within 10 seconds, cancel the timer and execute `pushDiffToSubscriber`.
- If the timer fires first (peer never wrote Bloom), fall back to the existing `pushOutboxToSubscriber` blind-push path. Outbound bytes still respect the peer's capability profile: if the selected profile does not support chunking, the sender MUST reject envelopes that require chunking with `peer-no-chunking`.
- This 10-second window MUST be a constant in `IgniRelayConstants.swift` matching `IgniRelayConstants.kt`; 10 seconds is locked by decision §15.4.

#### 3.2.6 Advertising error events

- In `peripheralManagerDidStartAdvertising(_:error:)` at line 604, when `error != nil`, emit a Flutter EventChannel event:
  ```json
  { "event": "gatt_server_error", "kind": "advertising_failed", "message": "<error.localizedDescription>" }
  ```
- This shape mirrors Android's `gatt_server_error` so the Dart-side handler is symmetric.

### 3.3 iOS background advertising note

iOS strips `CBAdvertisementDataLocalNameKey` from advertising packets when the app is in the background. Peer-side scanners then see only the `SERVICE_UUID`. Confirmed:

- Android scanner (`NordicMeshManager`) software-filters by `SERVICE_UUID` and accepts UUID-only advertisements correctly.
- iOS scanner (in `BlePlugin.swift`'s `centralManager` setup, line 309) ALSO filters by `SERVICE_UUID` only (the `withServices: [BlePlugin.SERVICE_UUID]` parameter). Therefore iOS-scanning-iOS works in background too.

The 0b spec confirms this and requires the Stage 0c3 implementation to add an integration test where:

- Both phones are iOS, both apps backgrounded.
- Both successfully discover each other within 30 seconds.

If this test fails, the 0d acceptance gate (brief §3.5) blocks Stage 1.

### 3.4 iOS background advertising — duty cycle reality

When iOS is in the background, advertising rate is throttled by the OS. Empirically:

- Foreground iOS advertises at ~10 Hz.
- Backgrounded iOS advertises at ~1 Hz, slowing further when the device sleeps the screen.
- A UUID-only advertisement at 1 Hz is enough for peer discovery within 30 seconds (the 0d acceptance gate criterion) but introduces user-visible latency.

The spec accepts this latency as inherent to iOS background BLE limits. The UI MUST surface "iOS peer in background — discovery may take longer" via a `bg_state` capability bit in `PROTOCOL_HELLO` (see §5.4).

---

## 4. App-Level Chunking + Reassembly Framing

### 4.1 When chunking applies

| Envelope size | Chunking? |
|---|---|
| ≤ `mtu - 3 - chunk_header_size` | Single framed chunk with `total_chunks=1, chunk_index=0`; no multi-chunk reassembly is needed. |
| > single-notify capacity AND ≤ `MAX_ENVELOPE_BYTES = 2048` | Chunked per §4. |
| > `MAX_ENVELOPE_BYTES` | REJECTED at sender publish time. Receiver also drops if observed. |

`MAX_ENVELOPE_BYTES = 2048` is the hard cap. This is a defensive bound, not a soft cap; it bounds reassembly memory and chunk count.

### 4.2 Chunk framing (normative)

Every chunk on the wire is:

```text
┌────────────────┬───────────────┬───────────────┬──────────────────┐
│ envelope_id    │ chunk_index   │ total_chunks  │ chunk_payload    │
│ 16 bytes       │ 1 byte (u8)   │ 1 byte (u8)   │ remaining bytes  │
└────────────────┴───────────────┴───────────────┴──────────────────┘
```

- `envelope_id`: 16 bytes, MUST equal the `EventEnvelope.envelope_id` of the reassembled envelope.
- `chunk_index`: 0-indexed.
- `total_chunks`: total number of chunks (1-16).
- `chunk_payload`: bytes of the serialized `EventEnvelope` proto for this chunk; `chunk_index * chunk_payload_size_for_this_send` through end of slice.

**Chunk header size** = 16 + 1 + 1 = **18 bytes**.

### 4.3 Sender algorithm

```text
fn split(envelope_bytes, mtu):
    chunk_payload_size = mtu - 3 (ATT header) - 18 (chunk header)
    if mtu < 23 + 18 + 3:
        REJECT with reason "mtu-below-minimum-for-chunked"
    if envelope_bytes.size > MAX_ENVELOPE_BYTES:
        REJECT with reason "over-max-envelope-bytes"
    total = ceil(envelope_bytes.size / chunk_payload_size)
    if total > MAX_CHUNKS_PER_ENVELOPE (= 16):
        REJECT with reason "over-max-chunks"
    for i in 0 until total:
        slice = envelope_bytes[i*chunk_payload_size .. min((i+1)*chunk_payload_size, end)]
        emit envelope_id || u8(i) || u8(total) || slice
```

Note: chunk_payload_size depends on the negotiated MTU at send time. Different sends to different peers may produce different chunk counts for the same envelope. That is correct — the chunk header carries `total_chunks` so the receiver can size its buffer correctly.

### 4.4 Receiver algorithm

```text
state: reassembly_buffer: Map<envelope_id, ReassemblyEntry>
       ReassemblyEntry: { total_chunks: u8, received: BitSet, chunks: Map<u8, bytes>, started_at: ms }

fn on_chunk(bytes):
    envelope_id = bytes[0..16]
    chunk_index = bytes[16]
    total_chunks = bytes[17]
    chunk_payload = bytes[18..]

    if envelope_id in dispatched_set OR envelope_id in tombstones:
        DROP "chunk-for-dispatched" (suppress duplicate reassembly)
        return

    entry = reassembly_buffer.getOrCreate(envelope_id, total_chunks)
    if entry.total_chunks != total_chunks:
        DROP "chunk-total-mismatch"
        return
    entry.chunks[chunk_index] = chunk_payload
    entry.received.set(chunk_index)

    if entry.received.count == total_chunks:
        full_bytes = concat(entry.chunks[0..total_chunks-1])
        reassembly_buffer.remove(envelope_id)
        dispatched_set.add(envelope_id)
        return EventEnvelope.parseFrom(full_bytes)

fn sweep():  // run every 5 seconds
    for (envelope_id, entry) in reassembly_buffer:
        if now - entry.started_at > REASSEMBLY_TIMEOUT_MS (= 30_000):
            reassembly_buffer.remove(envelope_id)
            trace_log(action=DROPPED, drop_reason="reassembly-timeout", envelope_id=envelope_id)
```

### 4.5 Single-chunk pseudo-chunking rule

For envelopes that fit in a single notify, the sender MAY:

- Option A: send raw envelope bytes directly with NO chunk header. Receiver detects "no chunk header" by attempting to parse the bytes as `EventEnvelope` first; if that succeeds, it is a single-notify envelope.
- Option B: ALWAYS wrap in a single-chunk frame (`total_chunks = 1, chunk_index = 0`). Receiver always strips the 18-byte header.

The 0b spec MANDATES **Option B** for v0.3. Rationale:

- Receivers do not have to guess between "raw envelope" and "framed chunk".
- The 18-byte overhead is a minor cost (compared to envelope_id + signature etc.) and worth the simpler receiver code.
- The conformance corpus test surface is smaller (one shape, not two).

This means EVERY envelope on the wire is preceded by an 18-byte chunk header. The chunk header is an APP-LAYER framing, not a protobuf-layer one; it sits OUTSIDE the `EventEnvelope` proto bytes.

### 4.6 Constants (cross-platform; MUST match across Dart/Kotlin/Swift)

| Constant | Value | Reason |
|---|---|---|
| `MAX_ENVELOPE_BYTES` | 2048 | Hard cap on serialized envelope size. |
| `MAX_CHUNKS_PER_ENVELOPE` | 16 | Bounds reassembly memory; with 18B header and MTU=185 → 18 × 16 = 288 bytes header overhead per max-size envelope, acceptable. |
| `REASSEMBLY_TIMEOUT_MS` | 30_000 | 30 seconds. Partial chunks past this are discarded. |
| `MAX_REASSEMBLY_BUFFER_BYTES` | 65_536 | Hard cap on total in-flight reassembly state per device. |
| `MAX_REASSEMBLY_BUFFER_ENTRIES` | 64 | Hard cap on number of in-flight envelope_ids. |
| `chunk_payload_size_min` | `23 - 3 - 18 = 2` | Minimum useful chunk payload at MTU=23 (BLE default). |

**Single source of truth for these constants (locked):** the values are hand-maintained in three sibling files — `lib/app/mesh/mesh_constants.dart`, `android/app/src/main/kotlin/network/ignirelay/ignirelay_app/IgniRelayConstants.kt`, and `ios/Runner/IgniRelayConstants.swift`. A CI script (`tool/check_constants_parity.dart`) greps each file for the named constants and fails the PR if any of the three diverge. This matches existing project style; no code generation is involved.

### 4.7 Out-of-order delivery

BLE notify across multiple subscribers is not strictly ordered. The receiver MUST handle:

- Chunks arriving out of order (handled trivially — keyed by `chunk_index`).
- Duplicate chunks (idempotent — overwriting `entry.chunks[i]` with the same bytes is a no-op).
- Chunks for the same envelope_id arriving via DIFFERENT peers (mesh delivery). Solution: first complete reassembly wins; the dispatched_set check at the start of `on_chunk` suppresses subsequent peers. The trace log records `drop_reason="chunk-for-dispatched"`.

### 4.8 Signature scope

After reassembly, the receiver parses `EventEnvelope` and verifies the 0a canonical signature input, including the locally computed `SHA-256(payload)`. Signature verification is NOT per chunk and is NOT over raw serialized wire bytes. Chunks are transport-layer only. There is NO per-chunk signature; the chunk header is unauthenticated. Defense against chunk forgery rests on the assumption that an attacker who can inject chunks could equally inject a complete envelope; the envelope-level signature catches forgery. Spec note: this means a malicious peer CAN waste reassembly buffer by injecting chunks for envelopes they cannot complete — mitigated by §4.6 `MAX_REASSEMBLY_BUFFER_*` caps.

### 4.9 Why not use BLE Long Write for chunking

iOS Long Write (Prepared Write + Execute Write) covers a SINGLE write transaction larger than MTU. It does NOT solve "envelope across multiple notify operations to multiple subscribers". App-level chunking is the cross-platform solution. iOS Long Write is still required (§3.2.3) for the case where ONE peer sends ONE big write to us; the chunker handles the multi-notify case.

Both layers coexist:

- Long Write = OS layer, for ONE big write that exceeds MTU.
- App-level chunking = application layer, for ONE envelope split into MULTIPLE notify operations (e.g., outbox push of an ALERT envelope to multiple subscribed centrals).

---

## 5. PROTOCOL_HELLO — Capability Negotiation

### 5.1 Overview

`EVENT_TYPE_PROTOCOL_HELLO = 100` (per 0a §4.1) is a small control envelope exchanged at the start of every BLE connection. It is a CAPABILITY DECLARATION, not a feature.

### 5.2 Timing

```text
GATT connect ─→ MTU negotiation ─→ service discovery ─→ HELLO sent (both peers, independent)
                                                            │
                                                            ├─ HELLO from peer received → cancel fallback timer, set profile
                                                            └─ 5-second timer fires → assume PhoneV1-legacy profile, proceed
```

- Triggered AFTER GATT connect, MTU negotiation, AND service discovery complete.
- Both peers send HELLO independently — no request/response, no race.
- 5-second timeout, **measured from the service-discovery-complete event** (NOT from connect). Some BLE stacks take 3-4 seconds for service discovery alone; starting the timer at connect would let the timer expire before HELLO can fire. If the peer's HELLO does not arrive within 5 s of service-discovery-complete, assume `PhoneV1-legacy` (lowest capability) and proceed.

### 5.3 Transport

HELLO is written via `EVENT_CHAR` like any other envelope. DO NOT open a new GATT characteristic. The framing is the standard chunk framing (§4); a HELLO comfortably fits in a single chunk on any reasonable MTU.

### 5.4 Payload

`message ProtocolHelloData` (carried in `EventEnvelope.payload` for `event_type = EVENT_TYPE_PROTOCOL_HELLO`):

```proto
message ProtocolHelloData {
  uint32 protocol_version          = 1;   // 2 in v0.3
  PeerKind peer_kind               = 2;
  uint32 max_rx_envelope_bytes     = 3;   // peer's per-envelope receive cap
  bool   supports_iblt             = 4;
  bool   supports_bloom_v2         = 5;   // current bit-vector with magic header
  bool   supports_chunking         = 6;   // MUST be true for PhoneV1; false for legacy
  uint32 min_negotiated_mtu        = 7;   // lowest MTU the peer commits to handle
  repeated string capabilities     = 8;   // opt-in flags (e.g., "shelter_status",
                                          //   "battery_share", "bg_state",
                                          //   reserved for v0.4 features)
  BgState bg_state                 = 9;   // see §5.5
  reserved 10 to 15;

  enum PeerKind {
    PEER_KIND_UNSPECIFIED   = 0;          // REJECTED on receive.
    PEER_KIND_PHONE_V1      = 1;          // post-0b Phone with full IBLT + chunking
    PEER_KIND_BLE_NODE_V1   = 2;          // future low-MTU node
    PEER_KIND_TIER0_MULE    = 3;          // existing Tier 0 mule
    PEER_KIND_PHONE_V1_LEGACY = 4;        // pre-0b Phone (HELLO timeout assumed value)
  }

  enum BgState {
    BG_STATE_UNSPECIFIED = 0;
    BG_STATE_FOREGROUND  = 1;
    BG_STATE_BACKGROUND  = 2;             // iOS-specific concern; Android uses foreground service
    BG_STATE_DOZE        = 3;             // Android Doze mode hint
  }
}
```

### 5.5 `bg_state` rationale

`bg_state = BACKGROUND` triggers a UI affordance "iOS peer in background — discovery may take longer" per the brief's risk-register entry on iOS background BLE. This is the only spec-recognized signal; if iOS background limits get worse in a future iOS release, the spec MAY add new BgState values.

### 5.6 Signature

`PROTOCOL_HELLO` envelopes are signed normally per 0a §7. The signing key is the device's Ed25519 identity key. Receivers verify the signature and use `author_key` to set initial `source_trust = SEEN_BEFORE` (or `PAIRED` if the key is in the local pairing store).

### 5.7 Failure modes

- Peer sends no HELLO before timeout: receiver assumes `PhoneV1-legacy` and proceeds with conservative defaults. Trace logs the timeout.
- Peer sends malformed HELLO or HELLO with invalid signature: receiver drops the connection/session. Do not silently downgrade, because that creates a downgrade attack.
- Peer sends valid HELLO but with `protocol_version != 2`: receiver downgrades to the LOWER of the two protocol versions and uses the v1 (legacy) feature set. v0.3 has no v1 fallback in code; if `protocol_version < 2`, the receiver disconnects (treat as incompatible).
- Peer sends valid HELLO but with `supports_chunking = false`: receiver MUST avoid sending envelopes that require chunking (i.e., > single-notify capacity at the negotiated MTU). Senders reject such envelopes at publish time per §4 with reason `peer-no-chunking`.
- Peer sends valid HELLO with `peer_kind = PEER_KIND_PHONE_V1_LEGACY` (self-declares legacy): receiver treats this as a HELLO error and drops the connection. Rationale: the legacy profile means "no HELLO at all"; declaring it via HELLO is contradictory and may indicate a misconfigured / probing peer. Trace logs `drop_reason = hello-self-declared-legacy`.

### 5.8 `PROTOCOL_NOTICE` — separate channel

`EVENT_TYPE_PROTOCOL_NOTICE = 101` is the post-freeze kill switch documented in 0a §4 and §18. It is not part of HELLO; it is a vendor-signed envelope that may pause specific EventTypes or prompt upgrades. The 0c implementation only needs to ACCEPT and SURFACE; the vendor key + signing tooling is documented in `docs/protocol.md` but not exercised by v0.3 tests.

---

## 6. Capability Profile Catalog

### 6.1 Profiles

Each profile entry below is normative. The Stage 0c implementation SHOULD encode these as a Dart `enum CapabilityProfile` with a const lookup table.

#### 6.1.1 `PhoneV1-legacy`

`PhoneV1-legacy` is a conservative capability profile for peers whose HELLO timed out. It is NOT a v0.2 wire-compatibility layer; v0.3 does not decode legacy `MeshEvent` bytes (0a §2). If the peer is truly pre-v0.3, interoperability is best-effort and not a release requirement.

- **MTU range**: assume 23-185.
- **Supported EventTypes**: subset — STATUS_UPDATE, BATTERY_STATUS, SUPPLY_REQUEST, SUPPLY_OFFER, MATCH_INTENT / NEGOTIATION, HAZARD_MARKER, CHAT_MESSAGE. NO support for PROTOCOL_HELLO/NOTICE, OFFICIAL_ALERT, SHELTER_STATUS.
- **Max envelope size**: single-notify only; cap to negotiated capacity. Do not send envelopes that require chunking.
- **`supports_chunking`**: false.
- **`supports_iblt`**: false.
- **`supports_bloom_v2`**: false.
- **Advertising**: Foreground only; iOS background advertising not supported.
- **Foreground/background notes**: assumed Android foreground-service or iOS foreground.
- **Implied for**: peers whose HELLO does not arrive within 5s.

#### 6.1.2 `PhoneV1`

- **MTU range**: 185-512 (full range per §7).
- **Supported EventTypes**: ALL of §4.1 in 0a.
- **Max envelope size**: `MAX_ENVELOPE_BYTES = 2048`.
- **`supports_chunking`**: true (mandatory).
- **`supports_iblt`**: true.
- **`supports_bloom_v2`**: true.
- **Advertising**: iOS background advertises UUID-only; Android foreground service.
- **Foreground/background notes**: handles `bg_state` upcalls.
- **Implied for**: peers whose HELLO declares `peer_kind = PEER_KIND_PHONE_V1`.

#### 6.1.3 `BleNodeV1`

- **MTU range**: 23-247 (low-power constrained).
- **Supported EventTypes**: subset — STATUS_UPDATE, HAZARD_MARKER, OFFICIAL_ALERT_CAP (relay only). NO chat, NO supply matching.
- **Max envelope size**: 226 bytes (single framed notify on negotiated MTU=247: 247 - 3 ATT header - 18 chunk header; never multi-chunked because BleNodeV1 has limited reassembly memory).
- **`supports_chunking`**: false (RECEIVES single-chunk envelopes only; SENDS are also single-chunk).
- **`supports_iblt`**: true.
- **`supports_bloom_v2`**: true.
- **Advertising**: continuous BLE advertise (it is a fixed device).
- **Foreground/background notes**: N/A (always on).
- **Implied for**: peers whose HELLO declares `peer_kind = PEER_KIND_BLE_NODE_V1`. Future v0.5 hardware.

#### 6.1.4 `Tier0Mule`

- **MTU range**: 247-512.
- **Supported EventTypes**: ALL relayable types (everything except control).
- **Max envelope size**: `MAX_ENVELOPE_BYTES = 2048`.
- **`supports_chunking`**: true.
- **`supports_iblt`**: true.
- **`supports_bloom_v2`**: true.
- **Advertising**: continuous.
- **Foreground/background notes**: special routing rule — `MeshRouter.shouldForwardPacket` exempts Tier0Mule from geo-fenced relay restrictions.
- **Implied for**: peers whose HELLO declares `peer_kind = PEER_KIND_TIER0_MULE`. Existing concept; preserved.

### 6.2 Profile lookup rule

Receiver computes peer profile in this order:

1. If HELLO arrived AND signature valid: use HELLO's `peer_kind`.
2. If HELLO arrived AND signature invalid: drop the connection (do not pretend the HELLO came through).
3. If 5s timeout: assume `PhoneV1-legacy`.

---

## 7. MTU Range Support Matrix

### 7.1 Matrix

| MTU | Status | Single-notify envelope cap (= MTU - 3 - 18 chunk header) | Notes |
|---|---|---|---|
| 23 | MUST support (BLE default) | 2 bytes payload per chunk | All envelopes require chunking. SOS may not be deliverable in a sane number of chunks; spec accepts that MTU=23 is degraded mode. |
| 185 | MUST support (low-end Android baseline) | 164 bytes envelope | A 240 B SOS envelope needs 2 chunks; this is allowed and covered by §7.3. |
| 247 | MUST support (common modern phone) | 226 bytes envelope | A 240 B SOS envelope needs 2 chunks (just over the single-notify cap). RESOURCE-small and STATUS at ≤ 226 B fit single-notify. |
| 512 | SHOULD support (high-end iOS) | 491 bytes envelope | A 240 B SOS fits single-notify. ALERT may still need chunking for big CAP messages. |

Note: the "single-notify envelope cap" column accounts for both the ATT header (3 bytes) AND the §4 chunk header (18 bytes), since the §4.5 mandate is that EVERY envelope is wrapped in chunk framing.

### 7.2 SOS at MTU=23

A 240-byte SOS envelope at MTU=23 requires `ceil(240 / (23 - 3 - 18)) = ceil(240 / 2) = 120` chunks. This EXCEEDS `MAX_CHUNKS_PER_ENVELOPE = 16`. Therefore:

- At MTU=23, SOS_RED CANNOT BE DELIVERED via the standard chunking path.
- Stage 0c MUST detect MTU=23 negotiation outcome and trace `peer-mtu-too-low-for-sos`.
- The UI MUST surface a "peer too constrained for SOS" indicator.
- This is a known v0.3 limitation. v0.4 may add a special small-SOS encoding for MTU=23 peers (if BleNodeV1 hardware actually emerges).

### 7.3 SOS chunk count at MTU=185 and MTU=247

- MTU=185: `chunk_payload_size = 185 - 3 - 18 = 164`. 240 B envelope ⇒ `ceil(240/164) = 2` chunks. ✓
- MTU=247: `chunk_payload_size = 247 - 3 - 18 = 226`. 240 B envelope ⇒ `ceil(240/226) = 2` chunks. ✓
- MTU=512: `chunk_payload_size = 512 - 3 - 18 = 491`. 240 B envelope ⇒ 1 chunk. ✓

The 0a §9 SOS budget is locked at 240 B (decision in 0a §20.6). At the two MUST-support MTUs (185, 247) the chunk count is **symmetric at 2**, which simplifies reasoning; at MTU=512 it falls back to single-notify. The ≈ +5-10 ms latency vs single-notify at MTU=247 is well inside the 0d acceptance gate p95<60s SOS-over-3-hops target.

### 7.4 Tooling for MTU constraint testing

The 0d acceptance gate (brief §3.5.2 row 6) requires testing at MTU=185, 247, 512. The 0c implementation MUST expose a debug-mode toggle to FORCE a target MTU (clamped via the BLE adapter API), so 0d can exercise each MTU on the same hardware pair. The toggle lives in the dev-mode trace screen.

**Implementation status — Android source-wired; Dart gates green; device preflight pending. iOS code-wired-only (Stage 0c wave 3F-r3):**

"Source-wired" means: native handlers compile, Dart facade exercises them, and `flutter analyze` + `flutter test` + layer / parity / corpus checks all pass. It does NOT mean an Android device pair has executed the 0d real-device gate — that preflight is the next step after Stage 0c source-complete and is owned outside this wave.

- Dart-side facade: `MeshDebugController.forceTargetMtu({deviceId, targetMtu})` (`lib/app/services/mesh_debug_controller.dart`) — writes a trace row + invokes the method channel.
- Method channel name: `debugForceTargetMtu` on `network.ignirelay/native`, payload `{deviceId: String, targetMtu: int?}`. `targetMtu = null` clears the override.
- Android handler — **SOURCE-WIRED, GATES GREEN, DEVICE PREFLIGHT PENDING**: `MainActivity.kt` writes to `IgniRelayForegroundService.debugMtuOverrideByDevice`. The clamp is applied in BOTH `IgniRelayForegroundService.onMtuChanged` (peripheral side) AND `NordicMeshManager.connect.done{}` (central side) so the higher layers see a consistent effective MTU.
- iOS handler — **CODE WIRED, NOT VERIFIED**: `BlePlugin.swift` writes to instance-scoped `debugMtuOverrideByDevice`. The clamp is applied at THREE points so all downstream sizing sees the same effective MTU: (1) `PeripheralDelegate.didDiscoverCharacteristicsFor` (central-role: clamps the value reported via `gatt_mtu` / `peer_ready_for_hello`), (2) `peripheralManager.didSubscribeTo` (peripheral-role: same), (3) `notifyEventChunk` (uses the stored clamped MTU for oversize rejection, so forced MTU=185 actually rejects 247-byte payloads instead of letting CoreBluetooth's real-MTU through). **The iOS source has not been `xcodebuild`-built or XCTest-run since this wave landed — dev host is Windows.**

The clamp is `min(actual_negotiated_mtu, target_mtu)` — a clamp never raises MTU, it only lowers it. Out-of-range targets (< 23 or > 512) are rejected by Dart before the channel call AND by both native handlers as defense in depth.

**Release-build policy:** the native handlers are DELIBERATELY UNGATED on `BuildConfig.DEBUG` (Android) and the DEBUG Info.plist key (iOS) so the 0d acceptance gate can drive RELEASE binaries (the gate exercises what users install). Impact is bounded — MTU clamp and tick suppression only; no wire-format mutation, no signature bypass.

**Still required before §3.4 Stage 0c sign-off:** the §7.4 surface code is present on both platforms but only Android has been smoke-tested. iOS needs (a) `xcodebuild` on macOS / CI, (b) `IBLTParityTests` / `WireConformanceTests` pass, (c) at least one iOS-pair 0d dry run on hardware. Until (a)–(c) land, Stage 0c remains "Android-pair preflight ready" and the iPhone-12 / iPhone-15 / Android↔iOS rows of §3.5.1 stay blocked.

---

## 8. BLE Adapter Recovery Story

### 8.1 Failure modes addressed

- BLE chip thermal throttle (long advertising/scanning sessions cause SoC throttling).
- Scan starvation (Android `startScan` returns success but never delivers `onScanResult`).
- Advertising failure (`onStartFailure` or `peripheralManagerDidStartAdvertising` error).
- GATT server crash (Android `BluetoothGattServer` returns an error code).
- Bluetooth toggled off by user mid-session.

### 8.2 Detection

The Stage 0c implementation MUST add a per-platform `AdapterHealthMonitor`:

- **Android**: every 60 seconds, check `lastSuccessfulScanResult_at_ms` and `lastSuccessfulAdvertise_at_ms`. If both are > 5 minutes stale AND foreground service is active AND there are subscribed peers, flag `adapter_idle_too_long`.
- **iOS**: equivalent via the `centralManager.state` and `peripheralManager.state` observers + `lastSuccessfulCallback_at_ms`.

**Native event channel — Android source-wired; Dart gates green; device preflight pending. iOS code-wired-only (Stage 0c wave 3F-r3):** the Dart-side `AdapterHealthMonitor` (`lib/app/services/adapter_health_monitor.dart`) consumes `adapter_health_tick` events from `network.ignirelay/events`. Payload shape:

```jsonc
{
  "type": "adapter_health_tick",
  "kind": "scan" | "advertise" | "gatt_op",
  "ts_ms": <epoch ms when the tick fired>
}
```

The Dart monitor tracks the LAST timestamp per `kind`. The staleness rule is: BOTH `scan` AND `advertise` ticks must be > 5 minutes stale to flag `adapter_idle_too_long`; `gatt_op` is informational only.

Android emit sites:

- `IgniRelayForegroundService.adapterHealthTickRunnable` (every 30 s while `isAdvertising`) emits `advertise`.
- `NordicMeshManager.onScanResult` emits `scan` for every BLE advertisement seen (whether it matches our service or not).
- `IgniRelayForegroundService` GATT callbacks (`onCharacteristicWriteRequest`, `onCharacteristicReadRequest`, `onNotificationSent`, `onConnectionStateChange`, `onMtuChanged`) emit `gatt_op`; the periodic runnable also emits `gatt_op` when there is ≥ 1 notify subscriber.

iOS emit sites (mirror of Android, via `BlePlugin.emitAdapterTick`; **code present, not yet `xcodebuild`-verified**):

- `BlePlugin.advertiseHealthTickTimer` (every 30 s while `peripheralManager.isAdvertising`) emits `advertise`. `peripheralManagerDidStartAdvertising` success also emits `advertise` as the "we've started" anchor.
- `centralManager(_:didDiscover:)` emits `scan` for every advertisement seen.
- `peripheralManager` callbacks `didReceiveRead`, `didReceiveWrite`, `didSubscribeTo`, `didUnsubscribeFrom`, plus `PeripheralDelegate` `didDiscoverCharacteristicsFor` / `didUpdateValueFor` / `didWriteValueFor`, plus `notifyEventChunk` on successful `updateValue`, all emit `gatt_op`. The periodic timer also emits `gatt_op` when `subscribedCentrals` is non-empty.

All emissions go through `emitAdapterTick`, which on BOTH platforms (a) skips delivery to the Dart event sink AND (b) skips updating the per-kind `lastXxxTickAtMs` companion field while the `debugForceAdapterIdle` suppression window (§8.5) is active. Skipping (b) is deliberate so the native-side recovery watchdog (§8.3) exercises end-to-end: the watchdog reads the same staleness clock the Dart monitor does, so forcing idle makes BOTH escalation paths fire.

### 8.3 Recovery actions (in order)

1. **Soft restart**: `stopScan` + `startScan` ; `stopAdvertising` + `startAdvertising`. If the adapter recovers within 10 seconds, log `adapter_soft_recover`.
2. **Hard restart**: stop the foreground service, cleanup all GATT connections, restart the foreground service. Android-specific. iOS does the equivalent dance via re-init `CBCentralManager` and `CBPeripheralManager`.
3. **User notification**: emit a banner "Mesh adapter idle for 5+ minutes — tap to restart". User-triggered restart re-runs step 2.
4. **Permanent error**: if even step 2 fails twice in a row, the adapter is treated as broken; the foreground service exits with a logged error and the UI displays "Bluetooth subsystem unavailable — restart your phone".

### 8.4 Bluetooth toggled off

When the user toggles BT off:

- `BluetoothAdapter.STATE_OFF` callback (Android) / `centralManager.state == .poweredOff` (iOS) MUST be observed.
- All connections drop gracefully.
- The foreground service notification updates to "Bluetooth disabled — mesh paused".
- When BT is toggled back on, the service automatically resumes scanning + advertising.

### 8.5 Spec acceptance

The 0c implementation MUST add a debug-mode "force adapter idle" toggle that disables scan/advertise emissions for 6 minutes, so the recovery monitor can be exercised in 0d.

The 0d acceptance gate (§3.5 of brief) now includes scenario #11 — "force adapter idle for 6 minutes; mesh recovers within 60 seconds of soft restart" — locked by decision §15.6.

**Implementation status — Android source-wired; Dart gates green; device preflight pending. iOS code-wired-only (Stage 0c wave 3F-r3):**

- Dart-side facade: `MeshDebugController.forceAdapterIdle({duration})` (`lib/app/services/mesh_debug_controller.dart`).
- Method channel name: `debugForceAdapterIdle` on `network.ignirelay/native`, payload `{durationMs: int}`. `durationMs <= 0` clears the suppression window.
- Android handler — **SOURCE-WIRED, GATES GREEN, DEVICE PREFLIGHT PENDING**: `MainActivity.kt` writes `IgniRelayForegroundService.adapterIdleSuppressedUntilMs = now + durationMs`. While the window is active, `emitAdapterTick` returns immediately without delivering to the event sink AND without updating the per-kind staleness clock, so BOTH the Dart-side `AdapterHealthMonitor` AND the native-side `adapterRecoveryRunnable` observe the artificial silence and exercise their §8.2 / §8.3 paths.
- iOS handler — **CODE WIRED, NOT VERIFIED**: `BlePlugin.swift` writes `adapterIdleSuppressedUntilMs`. Same suppression semantics as Android. No macOS `xcodebuild` / XCTest run yet — dev host is Windows.

**Recovery action is implemented in source on both platforms (wave 3F).** The §8.3 ladder is split per-platform between the native foreground service / plugin AND the Dart-side `AdapterHealthMonitor.onIdleDetected` callback (wired in `main.dart`):

| Step | Trigger                                          | Android implementation                                                                                                  | iOS implementation                                                                                                                            | Event emitted                       |
|------|--------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------|
| 1    | bothStale && isAdvertising && subscribers > 0    | **FS**: `attemptSoftRestart` — stop+restart advertising. **Dart**: `onIdleDetected` — `NativeBridge.stopNordicScan` + delay + `startNordicScan` (scan bounce; FS cannot reach `NordicMeshManager`). | `BlePlugin.attemptSoftRestart` — stop+restart scan AND stop+restart advertising in one process. Dart `onIdleDetected` also fires (idempotent). | `adapter_native_soft_restart` + Dart `AdapterIdleTooLong` |
| 2    | step 1 ineffective for 2 consecutive eval cycles | `attemptHardRestart` — `stopBlePeripheral` + delayed `startBlePeripheral`                                               | `attemptHardRestart` — tear down `CBPeripheralManager` + `ensurePeripheralManager` after delay                                                | `adapter_native_hard_restart`       |
| 3    | (UI banner; unchanged — owned by Dart monitor)   | n/a (Dart `AdapterHealthMonitor` → Provider → UI)                                                                       | n/a                                                                                                                                           | (Dart `AdapterIdleTooLong`)         |
| 4    | step 2 ineffective for 2 consecutive eval cycles | `emitPermanentError` — also resets escalation counters                                                                  | `emitPermanentError` — same                                                                                                                   | `adapter_native_permanent_error`    |

The native escalation counters reset to 0 the moment a real (non-suppressed) tick lands and `evaluateAndRecover` sees both `scan` and `advertise` fresh again — so a 6-minute `debugForceAdapterIdle` window followed by natural recovery does NOT permanently wedge the watchdog. Native events (`adapter_native_*`) are distinct from Dart's `AdapterSoftRecover` / `AdapterHardRecover` so QA can attribute the action to the native side vs. the Dart-side observation.

**Why scan bounce lives in Dart on Android, not in the FS:** `NordicMeshManager` (which owns the Nordic BLE scanner) is held by `MainActivity`. The foreground service is a separate component and cannot reach `MainActivity` instance state without an IPC dance. The Dart-side `AdapterHealthMonitor` already observes the same tick stream as the FS watchdog; wiring the scan bounce into its `onIdleDetected` callback is the natural split. iOS doesn't have this problem because `BlePlugin` owns both `CBCentralManager` and `CBPeripheralManager` in one process.

**Scenario #11 status on each platform:**
- **Android↔Android**: SOURCE-COMPLETE and ready for device preflight as of wave 3F-r3. Drive `debugForceAdapterIdle(6 min)` via dev-mode trace screen → expect `adapter_native_soft_restart` event within 60 s → expect `AdapterSoftRecover` Dart event when ticks resume. The native + Dart code paths are wired and unit-test green; the actual two-device run has NOT been executed yet (Windows dev host; preflight is the next step).
- **iOS↔iOS / Android↔iOS**: BLOCKED on macOS build + XCTest + device smoke. The Swift implementation is structurally complete but has not executed on hardware once.

---

## 9. iOS Background Advertising Notes

### 9.1 Confirmed limits

- iOS strips `CBAdvertisementDataLocalNameKey` in background.
- iOS strips solicited service UUIDs in background.
- iOS advertises `CBAdvertisementDataServiceUUIDsKey` in a SLOWER duty cycle in background (~1 Hz observed; varies with screen state).
- iOS REQUIRES the `bluetooth-peripheral` background mode in `Info.plist` for any background advertising at all.
- iOS REQUIRES the `bluetooth-central` background mode to keep `centralManager.scanForPeripherals` alive in background.

### 9.2 Verification in 0d

The 0d gate scenario 4 ("Background ↔ foreground") MUST be run with both phones backgrounded for at least one of the trials, not only with one foregrounded. Failure to discover within 30 seconds in this configuration is a recognized iOS limit, NOT a v0.3 defect — it is recorded in the acceptance matrix and surfaced to the user via `bg_state` (§5.5).

### 9.3 Scanner side

The iOS scanner already filters by SERVICE_UUID only (`BlePlugin.swift:309`'s `withServices: [BlePlugin.SERVICE_UUID]`). This is correct — the scanner does not depend on `CBAdvertisementDataLocalNameKey` to discover peers. Spec confirms; no change needed.

### 9.4 Android symmetric behavior

Android's `NordicMeshManager` already software-filters by SERVICE_UUID and accepts UUID-only advertisements. Confirmed; no change needed.

---

## 10. Android Foreground-Service Notes

### 10.1 Foreground service state

The Android foreground service (`IgniRelayForegroundService.kt`) is the cornerstone of Android's BLE persistence. Spec preserves the following invariants:

- The foreground service notification MUST be visible at all times when mesh is active.
- The notification text reflects mesh health: peer count, last sync time, queue size (subset of v0.4 mesh dashboard but minimal here for "is the service alive" debugging).
- The service MUST request `FOREGROUND_SERVICE_CONNECTED_DEVICE` foreground service type (Android 14+) — confirmed already in the manifest.

### 10.2 Doze mode

When the device enters Doze:

- The foreground service continues running (foreground services are exempt from Doze).
- BUT the BLE adapter may be paused by the OS depending on vendor.
- The `AdapterHealthMonitor` (§8.2) detects this as scan starvation.
- Recovery is automatic per §8.3.

The `bg_state = BG_STATE_DOZE` HELLO field (§5.4) is set when the Android peer detects it is in Doze (via `PowerManager.isDeviceIdleMode()`). This signals to remote peers that delivery latency may increase.

### 10.3 Battery saver

When battery saver is enabled, the OS may further restrict BLE operations. The foreground service detects this via `PowerManager.isPowerSaveMode()` and adds a `power_save_mode` capability string to its HELLO `capabilities` repeated field. UI surfaces the bit symmetrically.

---

## 11. Cross-Platform Conformance Corpus (Transport Slice)

### 11.1 File

`docs/specs/wire_conformance_v1.json` — the same single JSON file co-owned with 0a (envelope slice in 0a §17). The transport slice is 0b's responsibility.

The corpus is **deterministic** (no live timestamp) and carries a `corpus_revision` string + `spec_date`; the current revision is `v0.3-stage0c-wave3d-1`. A `notes` object documents corpus-wide conventions (`bloom_hash_ascii_only`, `payload_generator_lcg_byte_pattern_v1`, `event_id_generator_ascii_seq_v1`, `iblt_peel_quirk`). Re-generating MUST produce a byte-identical file; the Dart `tool/generate_wire_conformance_v1.dart --check` mode enforces this.

#### 11.1.1 Size discipline (Stage 0c wave 3D decision)

To keep the JSON file readable in code review and prevent it from ballooning across waves, the corpus uses two indirections instead of raw inline bytes wherever the input is large or determined by a generator:

1. **Deterministic input generators** — large `event_ids` arrays and large `envelope_bytes` are emitted as a small generator descriptor (algorithm name + parameters) rather than expanded inline. The consumer reproduces the bytes from the descriptor at test time using the algorithm documented in `notes.*`.
2. **SHA-256 of expected output** — large expected outputs (Bloom bit-vectors, the first/last chunk of a chunking sample) are stored as `*_sha256_hex` plus an `expected_*_size` integer rather than raw hex. The IBLT slice still uses raw hex (`expected_bytes_hex` is only 504 bytes — small enough to inline and small enough that drift is easier to read off the diff).

Concretely:

| Slice | Inputs | Expected output |
|---|---|---|
| IBLT | `operations[]` describing `insert` / `remove` waves, each with an `event_ids_generator: ascii_seq_v1` descriptor | Raw `expected_bytes_hex` (1008 chars = 504 B) |
| Bloom | `event_ids_generator: ascii_seq_v1` | `expected_bytes_size: 2052` + `expected_bytes_sha256_hex` |
| Chunking | `envelope_bytes_generator: lcg_byte_pattern_v1` + `envelope_id_hex` | `expected_chunk_count` + `expected_first_chunk_sha256_hex` + `expected_last_chunk_sha256_hex` (plus the tiny first/last raw `bytes` for sanity) |

The generator descriptor algorithms (`ascii_seq_v1`, `lcg_byte_pattern_v1`) are normatively documented inside the corpus `notes` field. Any addition to the generator vocabulary requires a new `notes.<generator_name>` key plus a 0a/0b spec amendment.

### 11.2 IBLT slice (≥ 50 samples)

Each sample is one of two `kind`s.

**Kind `iblt`** — single bucket state after a sequence of operations:

```json
{
  "kind": "iblt",
  "name": "iblt_insert_30",
  "operations": [
    {
      "op": "insert",
      "event_ids_generator": {
        "algorithm": "ascii_seq_v1",
        "prefix": "evt-",
        "start": 0,
        "count": 30,
        "width": 8
      }
    }
  ],
  "expected_bytes_hex": "<1008 hex chars = 504 bytes = 56 buckets × 9 bytes>"
}
```

**Kind `iblt_subtract`** — two bucket states plus their subtract result, used to verify the wire-level `subtract()` operator:

```json
{
  "kind": "iblt_subtract",
  "name": "iblt_subtract_a_minus_b",
  "a_operations": [ /* insert/remove waves */ ],
  "b_operations": [ /* insert/remove waves */ ],
  "expected_a_bytes_hex": "...",
  "expected_b_bytes_hex": "...",
  "expected_diff_bytes_hex": "..."
}
```

`op` is `insert` or `remove`; both consume an `event_ids_generator` descriptor (currently `ascii_seq_v1`).

Coverage:

- Empty IBLT (0 inserts).
- Single insert.
- 30 inserts (mid-load).
- 50 inserts (near 56-bucket capacity, but see peel quirk below).
- 100 inserts (overflow).
- Subtraction tests: A and B both built from operations, with the expected `subtract(A, B)` bytes.
- Inserts + removes within a single sample (verifies `count` going back to 0 and `keySum/hashSum` XOR-ing back out).

**Peel coverage — DEFERRED.** `IBLT.peel()` results are NOT in the v3D corpus because of a pre-existing implementation quirk documented in `notes.iblt_peel_quirk`: Dart/Kotlin/Swift `peel()` uses a CRC-derived index lookup while `insert/remove` use MurmurHash-derived indices. The wire-level contract (bucket bytes, subtract bytes) IS covered byte-identically and is sufficient for cross-platform sync because peel is a receiver-local recovery operation that doesn't go on the wire. Adding peel coverage requires first fixing the index-space mismatch; tracked as a future protocol cleanup, NOT a 3D scope item.

The Dart IBLT (`resqmesh_app/lib/app/mesh/iblt.dart`) uses CRC32 + FNV-1a + MurmurHash3. The Kotlin and Swift implementations MUST produce bit-identical bucket bytes for every input set. The corpus is the verifier.

### 11.3 Bloom slice (≥ 30 samples)

Each sample uses an `event_ids_generator` descriptor (no raw event ID lists inline) and stores expected output as a SHA-256 hash plus byte-length sanity:

```json
{
  "kind": "bloom_v2",
  "name": "bloom_v2_n100",
  "event_ids_generator": {
    "algorithm": "ascii_seq_v1",
    "prefix": "bloom-",
    "start": 0,
    "count": 100,
    "width": 8
  },
  "ascii_only": true,
  "expected_bytes_size": 2052,
  "expected_bytes_sha256_hex": "<64 hex chars = sha256(magic || bit_vector)>"
}
```

The 2052-byte total is the 4-byte magic header `[0xFF, 0xBF, 0x02, 0x00]` plus the 2048-byte bit vector. The magic header lets the receiver distinguish Bloom v2 bytes from raw envelope bytes on the shared `BLOOM_CHAR_UUID` characteristic.

Coverage:

- Empty bloom.
- 1 / 10 / 50 / 100 / 500 / 1000 inserts, plus several intermediate sizes to push past 30 samples.

**ASCII-only invariant (load-bearing).** `ascii_only: true` MUST be present on every Bloom sample, and the `prefix` plus `ascii_seq_v1`'s zero-padded decimal output guarantees only ASCII bytes feed into `bloomMurmurHash`. This is the corpus-side mitigation for the Kotlin/Swift Bloom hash divergence documented in `notes.bloom_hash_ascii_only` — Kotlin's `c.code` is unmasked while Swift's `codeUnit & 0xFF` masks to a byte; the two converge on ASCII inputs but diverge for code points ≥ 0x80. The Dart generator (and the conformance test) MUST throw if any sample feeds a non-ASCII event ID into Bloom. Fixing the runtime divergence is tracked as a future protocol cleanup, NOT a 3D scope item.

The Bloom v2 magic-header byte layout is asserted bit-identically by the Dart consumer test and the Swift `WireConformanceTests`. The Kotlin consumer is covered by the existing Android `IgniRelayForegroundService.buildBitVectorBloom` path; an Android instrumentation test will be wired in a later wave.

### 11.4 Chunking slice (≥ 20 samples)

Each sample carries an `envelope_bytes_generator` descriptor plus the SHA-256 of the first and last chunk:

```json
{
  "kind": "chunking",
  "name": "mtu247_size800",
  "envelope_bytes_generator": {
    "algorithm": "lcg_byte_pattern_v1",
    "seed": 7012,
    "size": 800
  },
  "envelope_id_hex": "<32 hex chars = 16-byte envelope_id>",
  "negotiated_mtu": 247,
  "expected_chunk_count": 4,
  "expected_first_chunk_sha256_hex": "...",
  "expected_last_chunk_sha256_hex": "...",
  "expected_first_chunk_bytes": 244,
  "expected_last_chunk_bytes": 86
}
```

`expected_first_chunk_bytes` and `expected_last_chunk_bytes` are **integer byte lengths** (NOT raw byte arrays). They provide a cheap sanity check that the consumer's chunk-payload sizing math is correct before it bothers to compute SHA-256. The byte-parity gate is:

- `expected_chunk_count` — total chunks the consumer's `Chunker.split` must produce.
- `expected_first_chunk_sha256_hex` — SHA-256 of chunk 0 (full bytes including 18-byte chunk header).
- `expected_last_chunk_sha256_hex` — SHA-256 of chunk `total_chunks - 1`.

Middle chunks (if any) are NOT individually fingerprinted; first + last + count is sufficient to catch any chunker drift since chunk_payload sizing is uniform except for the trailing chunk.

Coverage:

- 1-chunk envelopes at MTU=185 across several sizes from 1 B up to the single-notify cap.
- 1-chunk vs 2-chunk boundary cases at MTU=185 (sizes 163 / 164 / 165 exercise the off-by-one around `chunk_payload = mtu - 3 - 18 = 164`).
- 2-chunk envelopes at MTU=185 (240 B SOS — see §7.3).
- Multi-chunk envelopes at MTU=247 (ALERT ~800 B → 4 chunks).
- Larger envelopes at MTU=247 and MTU=512 to cover the full MTU matrix from §7. Max `expected_chunk_count` in the positive chunking slice is **5** (mtu=512, envelope=2048 B). The 16-chunk `MAX_CHUNKS_PER_ENVELOPE` cap is NOT exercised by positive samples — cap-rejection is covered by the `over_max_chunks` negative case (§11.5) at MTU=121.

**Reassembly behavior — DEFERRED to additional coverage.** Out-of-order delivery, duplicate chunks, and `reassembly-timeout` are NOT covered by per-sample fixtures in the v3D corpus. The transport-layer contract `Chunker.split` is fully covered; the receiver-layer contract `Reassembler.onChunk` is covered by the existing Dart unit tests (`test/mesh/chunker_reassembler_test.dart`) and the Android/iOS native implementations are covered by their own unit tests. A future wave will add cross-platform `reassembly_samples` (input chunk order + expected reassembled envelope bytes); when that lands, this section will be updated and `notes.reassembly_samples_v1` added.

### 11.5 Negative cases (≥ 10)

Each negative case carries a `kind`, a human-readable `description`, and an `expected_drop_reason` drawn from the spec-recognized vocabulary. The conformance test asserts the vocabulary is closed (no rogue drop reasons sneak into the corpus).

Coverage in v3D corpus (11 negatives):

| `kind` | `expected_drop_reason` | Verifier |
|---|---|---|
| `oversize_sos` | `over-budget-sos-rejected` | publish-side budget check (Dart) |
| `oversize_envelope` | `over-max-envelope-bytes` | `Chunker.split` (Dart, Kotlin, Swift) |
| `unknown_sig_algo` | `unknown-sig-algo` | envelope decoder |
| `chunk_total_zero` | `chunk-bad-header` | `Chunker.split` / receiver |
| `chunk_index_oob` | `chunk-bad-header` | `Chunker.split` / receiver |
| `chunk_bad_envelope_id_length` | `invalid-envelope-id` | `Chunker.split` (verified live) |
| `mtu_below_minimum` | `mtu-below-minimum-for-chunked` | `Chunker.split` (verified live) |
| `over_max_chunks` | `over-max-chunks` | `Chunker.split` (verified live; mtu read dynamically from corpus, see below) |
| `unknown_protocol_version` | `unknown-protocol-version` | envelope decoder |
| `expires_before_created` | `envelope-expired` | dispatcher |
| `invalid_envelope_id_in_chunk` | `reassembly-envelope-id-mismatch` | `Reassembler` |

The Chunker-structural negatives (`chunk_bad_envelope_id_length`, `mtu_below_minimum`, `over_max_chunks`, plus the `over-max-envelope-bytes` case) are RE-RUN against live `Chunker.split` in `test/conformance/wire_conformance_corpus_test.dart`. Test code MUST read `mtu` / `envelope_bytes_hex_length` / `expected_drop_reason` from the corpus rather than hard-coding them, so that a corpus drift surfaces immediately rather than silently passing against stale hard-coded constants.

The decoder/dispatcher negatives (`unknown_sig_algo`, `unknown_protocol_version`, `envelope-expired`, `reassembly-envelope-id-mismatch`) are covered by the existing decoder / dispatcher / reassembler test suites; cross-platform parity for these is enforced by re-decoding the negative envelope bytes in each language's test runner (Kotlin/Swift coverage to land in a later wave; v3D ships Dart-side coverage only).

### 11.6 CI gate

Each of Dart / Kotlin / Swift MUST encode and decode every positive sample bit-identically (or, where applicable, match the SHA-256 hash of the expected output and the documented byte-length) and reject every negative sample with the documented `expected_drop_reason`. CI is part of the Stage 0c acceptance check (brief §3.4).

As of Stage 0c wave 3D the Dart consumer (`test/conformance/wire_conformance_corpus_test.dart`) and the Swift consumer (`ios/RunnerTests/WireConformanceTests.swift`) are wired. Kotlin and Android instrumentation consumers are scheduled for a follow-up wave; the Android runtime is already exercised through end-to-end pair tests but does not yet read the JSON corpus directly.

### 11.7 Generation tooling

Per 0a §17.5: the Dart `tool/generate_wire_conformance_v1.dart` script is the SOLE generator. It produces the joint corpus (envelope + IBLT + Bloom + chunking + negatives). Kotlin and Swift consume the JSON; they MUST NOT regenerate.

The generator exposes two modes:

- `dart run tool/generate_wire_conformance_v1.dart` — regenerates the corpus on disk.
- `dart run tool/generate_wire_conformance_v1.dart --check` — regenerates in memory, compares to the on-disk file, and exits non-zero on drift. CI runs `--check`; the Dart conformance test ALSO calls `buildCorpus()` directly and compares to the on-disk bytes, so the determinism gate fails either as a tool exit code or as a test assertion (whichever runs first).

The generator MUST be deterministic: no `DateTime.now()`, no implicit map ordering, no filesystem-order dependence (YAML scenarios are explicitly sorted by path). The corpus's `corpus_revision` string bumps on any intentional shape change.

---

## 12. Cross-Spec Constraints with 0a

### 12.1 Mutually load-bearing constants

The numbers in this table appear in both 0a and 0b. A change in either spec MUST trigger a re-derivation in the other.

| Constant | 0a (envelope) | 0b (transport) | Joint rationale |
|---|---|---|---|
| `MAX_ENVELOPE_BYTES = 2048` | NORMAL priority hard cap (§9) | Sender rejects, receiver drops (§4.1, §4.6) | Bounds reassembly memory AND DB row size. |
| SOS envelope budget = **240 B** (locked; 0a §20.6) | Priority budget table (§9) | At both MTU=185 and MTU=247, fits in 2 chunks (§7.3); single-notify at MTU=512 | SOS must be deliverable on low-end devices with comfortable CJK brief-text room. |
| ALERT envelope budget = 800 B | Priority budget table (§9) | Requires chunking; 4 chunks at MTU=247 | CAP messages are 500-2000 B; allow chunking. |
| `MAX_CHUNKS_PER_ENVELOPE = 16` | (Implicit cap on payload size) | Reassembly memory bound (§4.6) | Bounds reassembly DoS vector. |
| Single-notify capacity baseline | Derived from MTU=247 minus 18 B chunk header (§9) | MTU range matrix baseline (§7) | If 0b changes baseline, 0a re-derives byte budgets. |
| Chunk header size = 18 B | Affects fixed envelope overhead derivation (§9) | Mandated by §4.5 (Option B always-wrap) | Single source of truth: 0b §4.2. |
| `payload_hash` is NOT a wire field; computed locally as `SHA-256(payload)` and fed into signature canonical input | 0a §3.2, §7.1 #10, §8.2 | n/a (transport carries `payload` bytes; receiver hashes after reassembly) | Decision: save 34 B per envelope wire; binding to payload preserved via `signature-invalid` on tampering. |
| `protocol_version = 2` | EventEnvelope.protocol_version (§3) | PROTOCOL_HELLO.protocol_version (§5.4) | Same value; HELLO declares the version of the envelope spec it speaks. |
| `EVENT_TYPE_PROTOCOL_HELLO = 100` | EventType enum (§4.1) | This spec §5 | Single source of truth: 0a §4. |
| `EVENT_TYPE_PROTOCOL_NOTICE = 101` | EventType enum (§4.1) | This spec §5.8, §13 | Single source of truth: 0a §4. |

### 12.2 Two-stage STATUS → SUPPLY

0a §16 declares the rule: STATUS_UPDATE with NEED_WATER does not auto-create SUPPLY_REQUEST. 0b confirms: the transport layer treats STATUS_UPDATE and SUPPLY_REQUEST as INDEPENDENT envelopes with their own envelope_ids and chunk frames. There is no cross-envelope linkage at the transport layer.

### 12.3 Snapshot LWW for STATUS_UPDATE

0a §5.2 declares snapshot LWW. 0b confirms: the transport layer does not need to know about LWW; it simply delivers envelopes. LWW is computed by the receiver after reassembly + signature verification.

### 12.4 Category-specific TTL

0a §11 sets per-EventType TTL defaults. 0b confirms: transport does not enforce TTL (that is the dispatcher's job); transport only delivers chunk bytes.

### 12.5 Naming convention

0a §4.2 mandates `EVENT_TYPE_<GROUP>_<NAME>`. 0b respects: this spec uses `EVENT_TYPE_PROTOCOL_HELLO` and `EVENT_TYPE_PROTOCOL_NOTICE`, conforming to the convention.

---

## 13. Risk Register — Native Transport Additions

These are the 0b-specific entries to be merged into the master risk register (brief §3.6). Each requires a written mitigation BEFORE Stage 0c2/0c3 implementation begins.

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Android 514-truncation discovered in OTHER transports (e.g., a third-party BLE library wraps notify and adds its own truncation) | low | critical (silent corruption recurrence) | The §2.4 CI grep guard. Plus a Stage 0c2 unit test that sends a 600-byte envelope and asserts the receiver gets all 600 bytes via reassembly. |
| iOS Long Write reassembly buffer overflow attack | low | medium (memory exhaustion) | `MAX_REASSEMBLY_BUFFER_BYTES = 65_536` in §4.6; per-central buffer cap. |
| Chunk reassembly DoS by dropping chunk N-1 | medium | medium (reassembly buffer fills up with stuck envelopes) | `REASSEMBLY_TIMEOUT_MS = 30_000` (§4.6). Plus `MAX_REASSEMBLY_BUFFER_ENTRIES = 64` (§4.6) bounds the attack surface. |
| MTU=23 SOS undeliverable | high (legacy hardware) | medium (degraded but not fatal — phones rarely fall back to MTU=23) | UI surfaces `peer-mtu-too-low-for-sos` indicator; v0.4 may add a small-SOS encoding for BleNodeV1 (§7.2). |
| iOS background advertising silently throttled to <1 Hz on certain iOS versions | medium | medium (slow discovery) | `bg_state = BACKGROUND` HELLO field surfaces it in UI; 0d test pair iOS-bg ↔ iOS-bg verifies; spec accepts the latency floor. |
| Cross-platform IBLT hash divergence between Dart MurmurHash3 and Kotlin/Swift implementations | medium | high (sync silently broken) | Conformance corpus IBLT slice (§11.2) MUST pass before 0c acceptance. |
| Cross-platform Bloom magic-header divergence | low | high (peer can't tell bloom from envelope on shared characteristic) | Conformance corpus Bloom slice (§11.3); the magic header is verified bit-identically. |
| GATT server crash on OPPO devices (known-bad vendor per brief §3.5.1) | medium | high (entire mesh dies on OPPO peers) | `AdapterHealthMonitor` (§8.2) hard-restart path; 0d gate explicitly tests OPPO. |
| HELLO fallback triggers prematurely (5s too short under high BLE congestion) | low | low (peer treated as legacy, but functional) | Logged; tunable; 0d may indicate raising to 10s. |
| Chunk header allocates a different envelope_id space than envelope's `envelope_id` | low | high (reassembly wins/loses incorrectly) | §4.2 explicitly mandates equality. Conformance corpus chunking slice (§11.4) verifies. |

---

## 14. Acceptance Checklist For 0b Spec Review

Per brief §9.2:

- [x] Android 514-byte truncation removal plan is concrete (not just "remove the line") — §2.
- [x] iOS parity items each scoped (IBLT.swift, Bloom-diff push, Long Write, MTU upcall, 10s fallback, advertising error events) — §3.
- [x] Chunking framing is deterministic and order-independent — §4.
- [x] Signature is computed over the FULL reassembled envelope, not per chunk — §4.8.
- [x] `PROTOCOL_HELLO` fires at the right time (after MTU + service discovery, before any event payload) — §5.2.
- [x] `PROTOCOL_HELLO` fields sufficient to negotiate capability without round-trip races (both peers send independently; 5s fallback) — §5.2, §5.4.
- [x] Capability profile catalog enumerates explicit MTU / EventType / chunking support per profile — §6.
- [x] Cross-platform conformance corpus covers envelope (0a §17), IBLT, Bloom, and chunking — both positive and negative cases — §11.
- [x] MTU range (23-512) covered with concrete test cases — §7.
- [x] BLE adapter recovery story defined (overheating, scan starvation, advertising failure) — §8.
- [x] iOS background advertising constraints addressed (no `LocalName` in background; UUID-only scan path) — §3.3, §9.

---

## 15. Decisions Locked (Sign-Off 2026-05-15)

The previously open questions are CLOSED. Each decision below is the canonical input to Stage 0c2 / 0c3.

| # | Topic | Decision | Section |
|---|---|---|---|
| 15.1 | Chunk header size at low MTU | **Single 18-byte chunk header for v0.3.** No SHORT-header variant. MTU=23 is documented as degraded mode; the realistic low-MTU peer (BleNodeV1) negotiates MTU=247. v0.4 may revisit if real-device data shows MTU=23 commonly. | §4.2, §7.2 |
| 15.2 | 5-second HELLO fallback timer start | **Timer starts at service-discovery-complete**, NOT at GATT connect. Some BLE stacks take 3-4 s for service discovery alone. | §5.2 |
| 15.3 | `MAX_ENVELOPE_BYTES` | **2048**. Balances reassembly memory (16 × 226 B ≈ 3.6 KB peak in flight, comfortable on phones) with CAP-message growth (NCDR CAP messages observed up to ~1.8 KB). | §4.6 |
| 15.4 | 10 s subscribe→Bloom fallback | **Keep 10 s** for v0.3. 0d will tell us if it bites; tunable. | §3.2.5 |
| 15.5 | Chunk dedupe gossip across mesh paths | **NO** chunk-level gossip in v0.3. The IBLT/Bloom membership set already handles "you have this envelope; stop sending". A second mechanism would be duplicative. | §4.7 |
| 15.6 | 0d acceptance gate scenario #11 — adapter recovery | **Approved.** Roadmap §3.5.2 amended in this pass to add scenario #11: "force adapter idle for 6 minutes; mesh recovers within 60 seconds of soft restart". | §8.5; roadmap §3.5.2 |
| 15.7 | `BG_STATE_DOZE` detection on Android | **Accept 1-2 s mismatch** between HELLO emission and Doze entry. Correctness is unaffected; UI surfaces "may be slow" labeling rather than committed timing promises. | §10.2 |
| 15.8 | Cross-platform constants — single source of truth | **Hand-maintained in three sibling files** (`mesh_constants.dart`, `IgniRelayConstants.kt`, `IgniRelayConstants.swift`) with a CI script `tool/check_constants_parity.dart` greping each and failing the PR on divergence. No code generation. | §4.6 (closing note) |
| 15.9 | Explicit `peer_kind = PEER_KIND_PHONE_V1_LEGACY` in HELLO | **Drop the connection** with `drop_reason = hello-self-declared-legacy`. The legacy profile means "no HELLO at all"; declaring it via HELLO is contradictory and may indicate a probing/misconfigured peer. | §5.7 |
| 15.10 | `is_experimental` envelopes and chunking | **Always reassemble**, then check `is_experimental` after the EventEnvelope is parsed. Chunks are transport-layer; semantic decisions are envelope-layer. | §4.4 (cross-ref to 0a §4.4) |

### 15.11 Cross-spec reconciliation

This decision table mirrors 0a §20 (Decisions Locked). Both specs are a single design unit; any future amendment to a number above requires updating both files plus the roadmap brief.

---

End of native_transport_v1_2026-05-13.md.
