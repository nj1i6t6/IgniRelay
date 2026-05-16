# ResQMesh / IgniRelay v0.3-v0.5 Protocol Roadmap Spec Brief

Date: 2026-05-13 (revised 2026-05-15 — Stage 0 restructured into 0a/0b/0c/0d; spec decisions locked)
Status: review draft for human / agent alignment
Scope: planning and specification only; do not implement from this document. The follow-up specs are:
- `docs/specs/envelope_v2_spec_2026-05-13.md` — Stage 0a deliverable (decisions locked: see §20)
- `docs/specs/native_transport_v1_2026-05-13.md` — Stage 0b deliverable (decisions locked: see §15)

> **Note for future agents:** the previously-open spec questions are CLOSED. Read `envelope_v2_spec_2026-05-13.md §20` and `native_transport_v1_2026-05-13.md §15` for the locked decisions before suggesting any change to envelope tags, payload budgets, chunking, or HELLO behavior.

## 0. Core Decision

The project has not shipped a stable public communication protocol yet. Therefore v0.3 may use a destructive protocol and storage reset.

This changes the strategy:

- Do not spend v0.3 effort on backwards compatibility layers for pre-release message formats.
- Do not write complex migrations for existing internal/dev data unless a specific beta dataset must be preserved.
- Use this window to design the wire format, DB schema, EventType enum layout, TTL behavior, native transport parity, and tests correctly.
- After v0.3 protocol freeze, future releases must follow migration and compatibility discipline.

The guiding principle:

> v0.3 builds the clean protocol/storage skeleton AND the native transport foundation; v0.4 builds collaboration features on top; v0.5+ is driven by beta and real-device feedback.

Stage 0 of v0.3 is now sub-staged into 0a (envelope/storage spec) + 0b (native transport spec) + 0c (implementation) + 0d (real-device acceptance gate). See §3.

## 1. Non-Negotiable Clarifications

These points must be explicit in any agent handoff:

1. Envelope message field tags and EventType enum values are different things.
   - Protobuf field tags are the numeric fields inside `EventEnvelope`.
   - EventType enum values classify payload semantics.
   - Design the envelope message structure first, then finalize EventType enum grouping.

2. v0.3 may wipe local development/internal-beta data.
   - Before closed beta, wipe is acceptable.
   - During closed beta, release notes must clearly say local data may be reset.
   - After v0.3 freeze, schema changes require proper migrations.

3. Mesh trace mode belongs in v0.3 as an internal/dev diagnostic log.
   - Do not build a user-facing dashboard in v0.3.
   - v0.4 may expose a simple mesh health dashboard.

4. Official alerts should be named as a general capability, not hard-coded as CWA only.
   - NCDR CAP should be treated as the first-class alert source.
   - CWA can be a provider under the official alerts pipeline.

5. iOS Critical Alerts entitlement can be requested early, but must not block the roadmap.
   - Android high-priority notification can be implemented first.
   - iOS critical alert support should remain conditional on entitlement approval.

6. The 30-second disaster install flow is first-launch only.
   - Existing users should not be asked "Are you safe?" on every app launch.
   - Re-entry should be available from a visible status action.

7. Freeze policy must be documented in both places after the v0.3 protocol spec is accepted:
   - `CLAUDE.md` for future agents.
   - `docs/protocol.md` for human maintainers.

8. v0.3 must include a minimal threat boundary.
   - v0.3 defends against duplicate relay through dedupe.
   - v0.3 defends against stale incident resurfacing through TTL/expiresAt.
   - v0.3 defends against priority abuse through receiver-side validation.
   - v0.3 defends against unverified alert masquerading through source trust and signature status labels.
   - v0.3 deliberately defers per-origin rate limiting, replay hardening beyond TTL, anonymous routing, and a comprehensive trust graph.
   - A full threat model is required before public launch.

9. v0.3 Stage 0 is sub-staged 0a → 0b → 0c → 0d.
   - 0a = envelope v2 / EventType / DB / sync spec.
   - 0b = native transport parity + low-MTU + capability contract spec.
   - 0a and 0b are drafted in parallel (their payload budgets and MTU profiles are mutually constraining) and cross-reviewed before 0c begins.
   - 0c = Dart + Android + iOS implementation, gated on both 0a and 0b spec acceptance.
   - 0d = real-device acceptance gate. Stage 1 may NOT begin until 0d passes.

10. The Android `IgniRelayForegroundService.kt` has a P0 silent-data-corruption bug.
    - `pushOutboxToDevice` (line ~607) and `pushDiffToDevice` (line ~940) silently truncate notify payloads to 514 bytes via `event.copyOf(514)` while reporting success.
    - Receivers fail Ed25519 verification on truncated bytes and silently drop the event; senders show "success" in logs. This is silent data corruption, not a soft limit.
    - v0.3 Stage 0b spec MUST replace this with app-level chunking + reassembly driven by the actual negotiated `ATT_MTU`, not a hard-coded byte cap.
    - Until 0b lands, the truncation bug must be tracked in the 0b spec and PR checklist as a P0. Do not touch app code just to add TODO comments during the spec-only phase.

11. iOS native is at MVP, materially behind Android.
    - Missing in `ios/Runner/BlePlugin.swift`: IBLT Fast Path (no `IBLT.swift`), Bloom-diff push (`pushOutboxToSubscriber` blind-pushes the full outbox), Long Write / Prepared Write support, MTU upcall to Dart, and the 10-second subscribe→Bloom fallback timer.
    - Effect: cross-platform mesh is asymmetric. iOS-as-peripheral is bandwidth-inefficient; iOS-as-Long-Write-sender silently fails on large payloads.
    - 0b spec MUST define the iOS parity work as part of v0.3 acceptance.

12. The existing `MeshEnvelope` protobuf (`lib/app/proto/mesh_protocol.pb.dart:3094`) is unused design legacy.
    - It carries only `type / payload / senderId`. No application code calls `pb.MeshEnvelope.fromBuffer` or `writeToBuffer` — the wire format is the inner `MeshEvent` decoded directly by `MeshEventHandler.decodeWirePayload`.
    - v0.3 adopts a single-layer top-level `EventEnvelope`. The legacy `MeshEnvelope` wire shape is not the compatibility target; if the legacy message is kept in proto, mark it deprecated and reserve its old fields inside that legacy message. The new `EventEnvelope` owns its own field tags.
    - `BloomFilterSync` continues to live on its own GATT characteristic (`BLOOM_CHAR_UUID`), not as a multiplexed payload.

13. STATUS broadcast is one EventType (`EVENT_TYPE_STATUS_UPDATE`) with a snapshot payload.
    - The earlier draft of this brief suggested separate types (`SAFE / NEED_HELP / INJURED / NEED_WATER / NEED_POWER / NEED_MEDICINE`). That design is dropped.
    - Reason: compound states like "I am safe but need water" are real; a flat enum forces unnatural mutual exclusion and complicates LWW.
    - Payload model: `{ safety_state: enum, needs: repeated NeedEntry { category, severity, expires_at_hlc } }` — full snapshot, not delta. See §3.2.3.
    - Each STATUS_UPDATE supersedes the prior STATUS_UPDATE from the same `author_key` (snapshot LWW).
    - Author sets envelope `priority` explicitly based on intent (SAFE → STATUS priority; INJURED → SOS_YELLOW; trapped/unable to move → SOS_RED). Receiver validates `(eventType, priority)` matrix to drop abuse.

14. v0.3 MUST include the following artefacts before 0c implementation can start:
    - Cross-platform wire conformance corpus (JSON test vectors covering envelope encode/decode, IBLT bucket state, Bloom bit-vector, chunk framing). See §3.3.6.
    - Risk register with concrete mitigations. See §3.6.
    - Real-device acceptance gate definition with quantified pass criteria. See §3.5.
    - Tombstone / expired sync policy: spec MUST define how expired envelopes are excluded from IBLT/Bloom sync so they do not re-circulate forever. See §3.2.8.

## 2. NOW: Work Before v0.3 Implementation

### 2.1 Dogfood v0.2

Run real-device dogfood before deep v0.3 work proceeds too far.

Focus:

- Auto-recenter fix from commit `5c0d378`.
- Dense city pan/zoom feel.
- Supply matching.
- Mesh chat reliability.
- Battery impact.
- Onboarding friction.

### 2.2 Closed Beta Channel

Prepare a trusted closed beta group of 10-20 people.

This is not a public launch. It is a dogfood and feedback loop.

Beta disclosure must include:

- Data may be wiped during v0.3 development.
- Protocol is not frozen yet.
- The app is not a replacement for official emergency services.
- Testers should report screenshots, device model, Android/iOS version, and reproduction steps.

### 2.3 Critical Alerts Entitlement

If iOS support is in scope, start the entitlement process early. This is administrative work and must not block Android or protocol development.

## 3. v0.3 — Stage 0a / 0b / 0c / 0d → Stage 1

Theme: build the protocol AND native transport skeletons correctly, prove them on real devices, then ship the smallest useful disaster loop.

### 3.1 Stage Map

```text
┌─ 0a — Envelope v2 / EventType / DB / sync spec ──────┐
│   docs/specs/envelope_v2_spec_2026-05-13.md          │
│                                                      │
│        parallel; budgets are mutually constraining   │
│                                                      │
┌─ 0b — Native transport parity + capability spec ─────┐
│   docs/specs/native_transport_v1_2026-05-13.md       │
└──────────────────────────────────────────────────────┘
                       ↓ both specs accepted
┌─ 0c — Implementation ────────────────────────────────┐
│   0c1 Dart envelope/store/sync                       │
│   0c2 Android native (drop 514-truncation, chunking) │   parallel
│   0c3 iOS native (IBLT, Bloom diff, Long Write, MTU) │
└──────────────────────────────────────────────────────┘
                       ↓ all three lanes integrated
┌─ 0d — Real-device acceptance gate ───────────────────┐
│   6 phones × pairwise × 10 scenarios with quantified │
│   pass criteria; failures block Stage 1              │
└──────────────────────────────────────────────────────┘
                       ↓ gate passed
                Stage 1 — UI / user-facing features
```

Stages 0a and 0b are spec-only. Stage 0c is implementation. Stage 0d is verification. Stage 1 begins only after 0d passes.

### 3.2 Stage 0a — Envelope v2 / EventType / DB / Sync Spec

Output: `docs/specs/envelope_v2_spec_2026-05-13.md`.

Stage 0a is a protocol spec and storage design task. It is not a UI feature task and not an implementation task. The deliverable is a reviewable document.

Required outputs:

- Single-layer `EventEnvelope` v2 protobuf message definition. The legacy `MeshEnvelope` is not reused as the v2 wire contract; if kept in proto, it is deprecated/reserved separately.
- EventType enum value grouping (final).
- DB schema centered on envelope v2.
- `db_version` table from the start.
- TTL split: `max_hops` (hop count) and `expires_at_hlc` (time) are separate fields.
- Signature scope white-list (author-bound vs relay-mutable fields).
- Dedupe key derivation.
- LWW key derivation per EventType.
- Payload budget per priority (with concrete byte numbers).
- Tombstone / expired sync policy (so expired envelopes do not re-circulate via IBLT/Bloom).
- Dev-only mesh trace log schema (dedicated table, not folded into `Debug_Logs`).
- Cross-platform wire conformance corpus requirements (the corpus is produced jointly with 0b — see §3.3.6).
- Freeze policy text for later insertion into `CLAUDE.md` and `docs/protocol.md`.

Recommended order:

1. Lock the top-level `EventEnvelope` field set and tags.
2. Define payload categories and EventType enum grouping.
3. Define TTL / dedupe / LWW / signature semantics.
4. Define DB schema around envelope storage and indexing.
5. Define send / receive / drop / tombstone rules.
6. Define reconnect and expiry UX.
7. Define golden tests and trace diagnostics.
8. Only after spec review, hand off to 0c implementation.

#### 3.2.1 EventEnvelope v2 Required Concepts

The exact proto is designed in the 0a spec; this brief enumerates the required concepts.

| Concept | Purpose |
|---|---|
| `protocol_version` | Allows future decoding and migration discipline. |
| `envelope_id` | Stable message id for dedupe, tracing, and user reports. |
| `event_type` | Payload semantic category (see §3.2.2). |
| `priority` | SOS / alert / status / normal handling. Author sets; receiver validates. |
| `created_at_hlc` | Origin creation time as HLC pair (timestamp_ms, counter). |
| `expires_at_hlc` | Expiry as HLC timestamp (NOT wallclock). Distinct from hop count. |
| `max_hops` | Hop count limit. Relays decrement; reaches 0 → drop. Distinct from time-based expiry. |
| `dedupe_key` | = `envelope_id`. Prevents repeated relays and duplicate UI cards. |
| `author_key` | Ed25519 public key of the message creator. Used for payload signature verification AND LWW key derivation. |
| `last_relay_id` | Immediate sender at this hop. Used for local trace/debug and loop diagnosis. Mutable; **NOT signed**. |
| `hop_count_seen` | Receiver-local counter. **NOT signed.** |
| `signature` | Ed25519 over the canonical encoding of author-bound fields (see §3.2.4). |
| `sig_algo` | `uint8`. Reserved for crypto agility (post-quantum sigs etc.). v0.3 = `0x01` Ed25519. |
| `signature_status` | Receiver-set label: valid / invalid / missing / not_checked. **Local-only, not on wire.** |
| `source_trust` | Receiver-set label: self / paired / seen-before / unverified / official-verified. **Local-only, not on wire.** |
| `payload` | Typed payload bytes for this `event_type`. |
| `payload_budget` | Enforced size limit by priority (see §3.2.5). |

Priority values (final):

- `SOS_RED` — highest, smallest, shortest relay path bias, user-visible immediately.
- `SOS_YELLOW` — urgent help but not life-threatening.
- `ALERT` — official or trusted warning, high but must mark verification state.
- `STATUS` — safety state, battery, shelter status.
- `RESOURCE` — supply requests and offers.
- `NORMAL` — chat, non-urgent coordination.

Priority must be validated by the receiver against `event_type`. A `CHAT_MESSAGE` claiming `SOS_RED` must be downgraded, dropped, or surfaced as suspicious according to the matrix in the 0a spec.

#### 3.2.2 EventType Enum Grouping

Keep groups broad and leave gaps.

```text
0      EVENT_TYPE_UNSPECIFIED

1-19   Personal / status
       EVENT_TYPE_STATUS_UPDATE     (snapshot — see §3.2.3)
       EVENT_TYPE_BATTERY_STATUS

20-49  Request / supply / coordination
       EVENT_TYPE_SUPPLY_REQUEST, EVENT_TYPE_SUPPLY_OFFER,
       EVENT_TYPE_MATCH_INTENT, EVENT_TYPE_NEGOTIATION,
       EVENT_TYPE_RELAY_TO_CONTACT

50-79  Hazard / disaster report
       EVENT_TYPE_HAZARD_MARKER, EVENT_TYPE_DISASTER_REPORT,
       EVENT_TYPE_SHELTER_STATUS

80-99  Official alerts
       EVENT_TYPE_OFFICIAL_ALERT_CAP, EVENT_TYPE_OFFICIAL_ALERT_SUMMARY

100-129 Mesh / system / control
       EVENT_TYPE_PROTOCOL_HELLO    (see §3.3.4)
       EVENT_TYPE_PROTOCOL_NOTICE   (vendor-signed kill switch)
       EVENT_TYPE_HEARTBEAT
       EVENT_TYPE_TRACE_PING, EVENT_TYPE_TRACE_ACK

1000+  Experimental / local-only
       Envelope MUST set is_experimental=true; relays SHOULD NOT propagate.
```

Do not overfit the enum to current UI screens. The enum models wire semantics.

EventType values use the `EVENT_TYPE_<GROUP>_<NAME>` prefix convention.

The currently-deprecated EventType values in legacy proto (`MATCH_INQUIRY=10, MATCH_AVAILABLE=11, MATCH_GONE=12`) are reserved permanently and MUST NOT be reused by v2. Legacy `MeshEnvelope` field tags are scoped to that legacy message; they do not constrain the new `EventEnvelope` field numbering.

#### 3.2.3 STATUS_UPDATE Snapshot Payload

`EVENT_TYPE_STATUS_UPDATE` carries a complete state snapshot (NOT a delta). Each new STATUS_UPDATE from the same `author_key` fully supersedes the previous one (snapshot LWW).

Illustrative schema (final canonical proto is defined in the 0a spec):

```proto
message StatusUpdateData {
  enum SafetyState {
    SAFETY_STATE_UNSPECIFIED = 0;
    SAFETY_STATE_SAFE        = 1;
    SAFETY_STATE_UNSAFE      = 2;  // present, can move, in danger zone
    SAFETY_STATE_INJURED     = 3;
    SAFETY_STATE_TRAPPED     = 4;  // implies SOS_RED priority by default
  }
  enum NeedCategory {
    NEED_CATEGORY_UNSPECIFIED = 0;
    NEED_CATEGORY_WATER       = 1;
    NEED_CATEGORY_POWER       = 2;
    NEED_CATEGORY_MEDICINE    = 3;
    NEED_CATEGORY_FOOD        = 4;
    NEED_CATEGORY_SHELTER     = 5;
    NEED_CATEGORY_EVAC        = 6;
  }
  enum NeedSeverity {
    NEED_SEVERITY_UNSPECIFIED = 0;
    NEED_SEVERITY_WANT        = 1;
    NEED_SEVERITY_NEED        = 2;
    NEED_SEVERITY_URGENT      = 3;
  }
  message NeedEntry {
    NeedCategory category = 1;
    NeedSeverity severity = 2;
    int64 expires_at_hlc  = 3;  // per-need expiry; UI hides expired entries
  }

  SafetyState safety_state    = 1;
  repeated NeedEntry needs    = 2;
  // No "delta" or "clear" fields: sender always transmits full state.
}
```

Notes:
- Empty `needs` array means "no current needs". A new STATUS_UPDATE with empty needs clears prior needs (snapshot replace).
- Per-need `expires_at_hlc` lets a water request expire faster than an injury status without requiring a new STATUS_UPDATE.
- LWW key for replacement: `(author_key, EVENT_TYPE_STATUS_UPDATE)`; greatest `created_at_hlc` wins.
- Author sets envelope `priority` based on the worst component (`SAFETY_STATE_TRAPPED` ⇒ `SOS_RED`; any `NEED_SEVERITY_URGENT` ⇒ at least `SOS_YELLOW`).
- A STATUS_UPDATE with `NEED_*` is NOT itself the supply matching event. If the UI offers to create a supply request from the status, that produces a separate `EVENT_TYPE_SUPPLY_REQUEST` envelope (two-stage relationship).

#### 3.2.4 Signature Scope (White-List)

Ed25519 signature MUST cover the canonical encoding of these author-bound fields, and NO others.

Signed (author commitment):
- `protocol_version`
- `envelope_id`
- `event_type`
- `priority`
- `created_at_hlc` (timestamp + counter)
- `expires_at_hlc`
- `max_hops` (the initial value chosen by the author)
- `author_key`
- `sig_algo`
- locally computed `SHA-256(payload)` (included in canonical signature input; not a wire field)

Not signed (relay-mutable or receiver-local):
- `last_relay_id` — overwritten by each relay.
- `hop_count_seen` — receiver-local counter.
- `signature_status` — receiver-local label, never on wire.
- `source_trust` — receiver-local label, never on wire.

Rationale: a relay must not be able to forge higher priority, longer expiry, or different event_type. A relay MAY annotate its identity in `last_relay_id` for trace/debug without invalidating the signature.

Large payloads sign the locally computed `SHA-256(payload)` rather than expanded payload fields — this keeps canonical-form size stable without carrying a `payload_hash` wire field.

Canonical encoding rule: the signature input MUST be a spec-defined byte sequence, not whatever a platform's generated protobuf serializer happens to emit. The 0a spec may use deterministic protobuf as that canonical form only if it defines field order, unknown-field stripping, defaults, and repeated-field ordering explicitly. The 0a spec MUST include reference bytes for at least 5 test envelopes (covers SOS, STATUS_UPDATE, OFFICIAL_ALERT, MATCH_OFFER, PROTOCOL_HELLO).

#### 3.2.5 Payload Budget Per Priority

BLE ATT MTU in the field is commonly 247 bytes (185-512 range). With transport framing, useful envelope bytes per notify = MTU - 3 (ATT header) - 18 (chunk header). Envelope fixed overhead is roughly 150-170 bytes depending on relay metadata. Therefore typed `payload` budget per priority must target bounded chunk counts:

| Priority | Total envelope budget | Typed payload budget | Chunking allowed? |
|---|---|---|---|
| `SOS_RED` | ≤ 240B (locked 2026-05-15; was 200B) | ≤ ~70B | bounded — 2 chunks at MTU 247, 2 chunks at MTU 185, 1 chunk at MTU 512 |
| `SOS_YELLOW` | ≤ 240B | ≤ ~70B | bounded — same as SOS_RED |
| `STATUS` | ≤ 240B | ≤ ~70B | bounded — STATUS_UPDATE is small by design |
| `RESOURCE` | ≤ 400B | ≤ ~230B | yes, but disfavor for negotiation |
| `ALERT` | ≤ 800B | ≤ ~630B | yes (CAP messages are 500B-2KB; allow chunking) |
| `NORMAL` (chat) | no fixed cap | typed payload via chunking | yes |

SOS-class envelopes that exceed budget are REJECTED by the sender (must not enter the queue). Receivers also drop over-budget SOS envelopes as a defense-in-depth measure (treat as priority abuse).

Chunking framing is specified in 0b (`docs/specs/native_transport_v1_2026-05-13.md`).

#### 3.2.6 Dedupe / LWW Key Derivation

- `dedupe_key` = `envelope_id`. Used by mesh relays and the receiver-side stream dispatcher to drop already-seen envelopes (the existing `_dispatchedEventIds` set in `EventStream` continues to work).
- `lww_key` for STATUS_UPDATE = `(author_key, EVENT_TYPE_STATUS_UPDATE)`; latest `created_at_hlc` wins.
- `lww_key` for SHELTER_STATUS = `(shelter_id, EVENT_TYPE_SHELTER_STATUS)`; the 0a spec MUST describe a trust-tier tiebreaker for conflicting operators.
- `lww_key` for BATTERY_STATUS = `(author_key, EVENT_TYPE_BATTERY_STATUS)`.
- LWW does NOT apply to SOS_RED / SOS_YELLOW / HAZARD_MARKER / SUPPLY_REQUEST / SUPPLY_OFFER (multiple incidents/offers from the same author at different times are all relevant).

The 0a spec MUST enumerate the LWW key per EventType in a single table.

#### 3.2.7 Storage Reset Guidance

Because the app is still pre-stable:

- It is acceptable to redesign tables around envelope v2.
- It is acceptable to wipe local dev/internal beta DB.
- Avoid writing elaborate migration code for the old pre-freeze schema.

Minimum storage requirements:

- `db_version` table.
- Envelope table with indexes for:
  - `event_type`
  - `priority`
  - `created_at_hlc`
  - `expires_at_hlc`
  - `dedupe_key` (= envelope_id)
  - `author_key`
  - sync/relay state
- Payload/detail tables only when needed for query efficiency.

For LWW status lookup, use a composite index on (`author_key`, `event_type`, `created_at_hlc` DESC).

#### 3.2.8 Tombstone / Expired Sync Policy

Problem: if node A drops envelope E because `expires_at_hlc < now`, but node B still has E in its store, the next IBLT/Bloom sync between A and B will surface E as "A missing" → B pushes E back to A → A drops again → A's bloom still says "missing E" → infinite re-circulation.

Solution: tombstones.

- When an envelope hits `expires_at_hlc + GRACE_PERIOD`, A inserts `envelope_id` into a tombstone table (or marks the envelope row as `expired`) BUT keeps the `envelope_id` in its IBLT/Bloom membership set.
- A no longer surfaces the envelope in active UI but still claims membership during sync.
- Tombstone entries are GC'd after `expires_at_hlc + GRACE_PERIOD + TOMBSTONE_TTL` (e.g., 7 days), under the assumption that no peer will be that out-of-date during a single disaster event.

The 0a spec MUST define:
- `GRACE_PERIOD` per event class (SOS may want longer grace for debugging; chat may have shorter).
- `TOMBSTONE_TTL`.
- Tombstone table schema and index strategy.
- Bloom/IBLT rebuild policy when tombstones exist (do tombstone IDs participate in IBLT subtraction the same way live IDs do? — yes, by design; spec MUST state explicitly).

Hidden is not deleted. The storage spec must define periodic garbage collection, running on app launch and every N hours while active.

#### 3.2.9 Reconnect Minimum

Reconnect behavior is part of envelope v2, not a separate v0.4 feature.

Minimum v0.3 behavior:

- Drop or hide envelopes where `expires_at_hlc < now`, unless user explicitly opens history/debug.
- Show a lightweight toast/banner when stale queued envelopes were discarded ONLY if the envelope had previously been shown to the user (false-positive avoidance: don't banner-flash for envelopes that travelled 14 hops and arrive already-expired without ever being surfaced).
- Do not surface expired SOS / status / hazard as active incidents.
- Keep trace/debug records for diagnosis if dev mode is enabled.
- Tombstone policy (§3.2.8) prevents expired envelopes from re-circulating via sync.

#### 3.2.10 Dev-Only Mesh Trace Log

v0.3 includes structured internal trace logging for protocol debugging.

Trace fields:

- `envelope_id`
- `event_type`
- `priority`
- `author_key`, truncated or hashed for privacy
- `last_relay_id`
- `created_at_hlc / expires_at_hlc`
- `sent / received / dropped`
- `drop_reason` (dedupe-hit, sig-fail, ttl-zero, expired, priority-mismatch, budget-exceeded, ...)
- `dedupe hit/miss`
- `signature_status`
- `source_trust`
- `hop_count_seen`
- `relay_attempt_count`
- `peer/device id` when safe to log

This is NOT a user-facing dashboard in v0.3.

DB schema: trace logs MUST have a dedicated `Mesh_Trace_Logs` table with a 24h TTL (similar in retention shape to the existing `Debug_Logs` table). It is NOT acceptable to fold mesh trace into the free-text `Debug_Logs` table — trace must be structured for query.

#### 3.2.11 Freeze Policy

After v0.3 spec is accepted and implemented, document:

- Envelope v2 wire format is frozen after v0.3.
- Protobuf field tags must not be reused.
- Removed fields must be reserved.
- EventType enum values must not be reused. The legacy values `MATCH_INQUIRY=10, MATCH_AVAILABLE=11, MATCH_GONE=12` are reserved permanently. Legacy `MeshEnvelope` fields are reserved only within the deprecated legacy message; `EventEnvelope` v2 has its own tag space.
- DB changes after freeze require migrations.
- `PROTOCOL_NOTICE` (see §3.3.4) is the only sanctioned mechanism for post-freeze emergency behavior changes.

Required documentation locations after spec acceptance:

- `CLAUDE.md`
- `docs/protocol.md`

### 3.3 Stage 0b — Native Transport Parity + Low-MTU + Capability Contract Spec

Output: `docs/specs/native_transport_v1_2026-05-13.md`.

Stage 0b is a native-layer spec. Its byte budgets, chunking framing, and capability fields are mutually constraining with 0a (envelope size budget); the two specs MUST be drafted in parallel and cross-reviewed.

Required outputs:

- iOS parity work plan (`IBLT.swift`, Bloom-diff push, Long Write / Prepared Write, MTU upcall, 10s subscribe fallback).
- Removal plan for Android's 514-byte silent truncation (replace with dynamic MTU + chunking).
- App-level chunking + reassembly framing (cross-platform, deterministic, order-independent).
- `PROTOCOL_HELLO` timing, fields, and degradation rules.
- Capability profile catalog (PhoneV1-legacy, PhoneV1, BleNodeV1, Tier0Mule, ...).
- iOS background advertising notes and Android foreground-service notes.
- Cross-platform wire conformance corpus requirements (jointly with 0a).
- MTU range support matrix (23 / 185 / 247 / 512).
- BLE adapter recovery story (overheating, scan starvation, advertising failure).

#### 3.3.1 Android 514-byte Truncation — P0 Removal

Current state: `IgniRelayForegroundService.kt:607` and `:940` truncate notify payloads to 514 bytes via `event.copyOf(514)` while reporting success. This is silent data corruption — receivers fail Ed25519 verification on truncated bytes; senders see "success" in logs.

Required:
1. Remove both `copyOf(514)` calls.
2. Replace with an app-level chunking layer (see §3.3.3) that:
   - Queries actual negotiated `ATT_MTU` via the `onMtuChanged` callback.
   - Computes `chunk_size = ATT_MTU - 3 - chunk_header_size`.
   - Rejects envelopes whose unchunked size exceeds `MAX_ENVELOPE_BYTES = 2048` at send time, instead of corrupting them at notify time.
3. Until 0b lands, both truncation lines MUST be referenced from the 0b spec / PR checklist as P0 silent data corruption so contributors do not "fix" the symptom by bumping the cap. Do not modify code during the spec-only phase just to add comments.

#### 3.3.2 iOS Parity Gaps — Required Implementation

The iOS native layer at `ios/Runner/BlePlugin.swift` is at MVP. The following items MUST reach Android parity in 0b:

| Gap | Current iOS | Required |
|---|---|---|
| IBLT Fast Path | absent | new `IBLT.swift`, bit-identical hash output (CRC32, FNV-1a, MurmurHash3) with Dart `lib/app/mesh/iblt.dart` and Android `IBLT.kt` |
| Bloom-diff push | `pushOutboxToSubscriber` blind-pushes the full outbox | port Android `pushDiffToDevice` logic, including bit-vector magic-header detection |
| Long Write / Prepared Write | absent | implement Prepared Write buffering for incoming writes; chunk outgoing writes via app-level chunking (§3.3.3) |
| MTU upcall to Dart | absent | implement `peripheral(_:didNegotiateMtu:)` and emit `gatt_mtu` event to Dart EventChannel |
| 10s subscribe→Bloom fallback | absent | implement fallback timer for legacy peers that subscribe but do not write Bloom |
| `peripheralManagerDidStartAdvertising` error events | minimal | match Android's `gatt_server_error` event-emission shape so the Dart-side error handling is symmetric |

iOS background advertising note: iOS strips `CBAdvertisementDataLocalNameKey` when the app is in background; peer-side scanners see only the `SERVICE_UUID`. Android's `NordicMeshManager` software-filtering already handles UUID-only advertisements correctly; the 0b spec MUST confirm that the iOS scanner side handles its own UUID-only advertisements when both apps are in background.

#### 3.3.3 App-Level Chunking + Reassembly Framing

For envelopes larger than the negotiated single-notify capacity, app-level chunking is required. The 0b spec MUST define:

- Chunk header: minimal (envelope_id 16B + chunk_index uint8 + total_chunks uint8 + chunk_payload). Cross-platform identical layout.
- Maximum chunk count per envelope (e.g., 16) — bounds reassembly memory.
- Reassembly timeout (e.g., 30 seconds) — partial chunks past this are discarded.
- Out-of-order delivery handling (BLE notify is not strictly ordered across multiple subscribers; reassembly must be order-independent per envelope).
- Behavior when a chunked envelope arrives concurrently from multiple peers via mesh — first complete reassembly wins; duplicates dropped by `envelope_id` dedupe.
- Signature is computed over the FULL reassembled envelope, not per chunk. Chunks are transport-layer only.

#### 3.3.4 PROTOCOL_HELLO — Capability Negotiation

`EVENT_TYPE_PROTOCOL_HELLO` is a small control envelope exchanged at the start of every BLE connection. It is a capability declaration, not a feature.

Timing:
- Triggered AFTER: GATT connect → MTU negotiation → service discovery completes.
- Both peers send HELLO independently — no request/response, no race.
- 5-second timeout: if the peer's HELLO does not arrive, assume `PhoneV1-legacy` (lowest capability profile) and proceed.

Transport: HELLO is written via `EVENT_CHAR` like any other envelope (do not open a new GATT characteristic).

Payload fields:
- `protocol_version` — uint32; current = 1.
- `peer_kind` — enum { PHONE_V1, PHONE_V2, BLE_NODE_V1, ... }.
- `max_rx_envelope_bytes` — uint32; the peer's per-envelope receive cap.
- `supports_iblt` — bool.
- `supports_bloom_v2` — bool (current bit-vector with magic header).
- `supports_chunking` — bool (MUST be true for v1 phones post-0b).
- `min_negotiated_mtu` — uint32; lowest MTU the peer commits to handle.
- `capabilities` — repeated string; opt-in capabilities (e.g., `"shelter_status"`, `"battery_share"`, reserved for v0.4 features).

`PROTOCOL_NOTICE` (separate EventType slot in the 100-129 range): vendor-signed control envelope for emergency post-freeze actions. Examples: "pause `EVENT_TYPE_FOO` propagation due to discovered bug", "show upgrade banner with URL". The v0.3 implementation only needs to accept and surface; the vendor key + signing tooling is documented in `docs/protocol.md` but not exercised.

#### 3.3.5 Capability Profile Catalog

The 0b spec MUST enumerate at least:

- `PhoneV1-legacy` — conservative no-HELLO capability profile, not a v0.2 wire-compatibility layer. Implied for peers whose HELLO does not arrive within 5s.
- `PhoneV1` — post-0b Phone with full IBLT + chunking + MTU upcall.
- `BleNodeV1` — future low-MTU node (~247 MTU). Receives but does not advertise; smaller envelope cap; subset of EventTypes.
- `Tier0Mule` — existing Tier 0 hardware-mule concept. Exempt from geo-fenced relay rules per `MeshRouter.shouldForwardPacket`.

Each profile entry MUST specify: supported MTU range, supported EventTypes, max envelope size, `supports_chunking`, `supports_iblt`, `supports_bloom_v2`, advertising behavior, foreground/background notes.

#### 3.3.6 Cross-Platform Wire Conformance Corpus

A single JSON test-vector corpus (`docs/specs/wire_conformance_v1.json`) MUST be produced jointly with 0a and 0b. All three implementations (Dart, Kotlin, Swift) MUST pass.

Corpus contents:

- ≥ 100 `(envelope_struct, expected_canonical_bytes_hex, expected_signature_hex)` samples covering every EventType, every priority, and both single-chunk and multi-chunk cases.
- ≥ 50 `(iblt_input_event_ids, expected_bucket_state_hex)` samples covering empty, single, near-capacity, and overflow cases.
- ≥ 30 `(bloom_input_event_ids, expected_bit_vector_hex)` samples with magic header.
- ≥ 20 `(chunked_envelope, expected_chunk_bytes_hex_array)` samples to lock the chunking framing.
- ≥ 10 negative cases that MUST fail decode (bad signature, bad sig_algo, over-budget SOS, unknown event_type without `is_experimental` flag).

CI gate: each of Dart / Kotlin / Swift MUST encode and decode every positive sample bit-identically and reject every negative sample.

This corpus replaces the prior "wire golden tests" language. The unit of conformance is the corpus, not per-platform fixtures.

### 3.4 Stage 0c — Implementation

Stage 0c can begin only after 0a + 0b spec acceptance. Three lanes run in parallel:

- **0c1 (Dart)** — envelope v2 encode/decode, DB schema with `db_version`, EventStore / EventStream / EventDecoder updates, dedupe + tombstone tables, dev `Mesh_Trace_Logs` table, signature scope changes in `Signer`, conformance corpus runner.
- **0c2 (Android native)** — remove 514-byte truncation, implement app-level chunking + reassembly, MTU-aware notify path. `onMtuChanged` already exists; verify the Dart side consumes it. `PROTOCOL_HELLO` handling is data-path and largely Dart-side; native supports MTU upcall and chunking.
- **0c3 (iOS native)** — port `IBLT.swift`, `pushDiffToDevice` equivalent, Long Write / Prepared Write, MTU upcall, 10s subscribe fallback, advertising error events.

Integration order: 0c1 + 0c2 first (Android↔Android passes), then 0c3 (iOS↔iOS and Android↔iOS pass). Implementation may not skip writing the conformance corpus runner in 0c1.

Acceptance check before moving to 0d:
- Cross-platform conformance corpus is green on all three implementations.
- Unit tests for envelope round-trip, signature verification, dedupe, LWW, tombstone, and chunking are green.
- `tool/check_layers.dart --strict` still passes; no new UI-to-platform shortcuts.

### 3.5 Stage 0d — Real-Device Acceptance Gate

Stage 1 may NOT begin until 0d passes.

#### 3.5.1 Device Pool (Minimum)

Six phones, pairwise tested:

- Pixel 7 or later (Qualcomm)
- Xiaomi / Redmi recent (MediaTek)
- OPPO recent (MediaTek; this is the known-bad GATT-server vendor)
- Samsung S22 or later (Exynos)
- iPhone 12 on iOS 16
- iPhone 15 on iOS 17

All 15 pairs MUST pass all scenarios.

#### 3.5.2 Scenarios and Pass Criteria

| # | Scenario | Pass criterion |
|---|---|---|
| 1 | Cold start → peer discovery | Both screens show the other peer in < 30s on ≥ 70% of trials (10 attempts) |
| 2 | SOS_RED broadcast over 3 hops | From SOS button press to 3rd-hop device receiving alert: p50 < 15s, p95 < 60s |
| 3 | STATUS_UPDATE LWW | Sender flips SAFE → INJURED → SAFE three times within 30s; receiver's final state is SAFE on 100% of trials |
| 4 | Background ↔ foreground | App switch through 5 other apps then return: SOS receivable within 30s; no state loss |
| 5 | Low battery (< 20%) | Mesh remains functional; receive-only mode acceptable; must not crash |
| 6 | MTU range coverage | Scenarios 1-4 pass on negotiated MTU = 185, 247, and 512 (use BLE debug tooling to constrain) |
| 7 | Reconnect after disruption | Force-disconnect for 30s; both peers re-discover within 60s |
| 8 | Chunked envelope delivery | ALERT envelope ~800B delivered correctly across the 4-chunk boundary; signature verifies on receiver |
| 9 | Tombstone exclusion | Expired SOS does NOT re-circulate after 2 minutes of further mesh activity |
| 10 | Handoff PIN | Cross-platform PIN handoff succeeds; wrong PIN is rejected via GATT response status (Android `GATT_FAILURE`, iOS `.writeNotPermitted`) |
| 11 | BLE adapter recovery (added 2026-05-15) | Force adapter idle for 6 minutes (debug toggle in 0c). Mesh recovers within 60 seconds of automatic soft restart. No crash. Trace log shows `adapter_soft_recover`. Verifies the §8 recovery story in the 0b spec. |

#### 3.5.3 Failure Handling

Any pair × scenario failure blocks Stage 1 until either:
- The failure is fixed in 0c, or
- The failure is explicitly waived in the risk register (§3.6) with stakeholder sign-off and a tracked follow-up.

Acceptance is recorded as a matrix (`device_pair × scenario`) attached to the v0.3 release notes.

### 3.6 Risk Register

Concrete risks tracked through 0a → 0d. Each requires a written mitigation BEFORE 0c implementation begins.

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| iOS background BLE limits stricter than expected (no advertising under certain bg conditions) | medium | high (SOS undelivered to bg iOS) | `PROTOCOL_HELLO.peer_kind` includes a `bg_state` capability bit; UI surfaces "iOS peer in background" so users understand degradation |
| BLE-node firmware slips past v0.5 | high | low (phone-only mesh still works) | `PROTOCOL_HELLO` + capability profile lets phones run without nodes; node integration is purely additive |
| 514-truncation-like silent corruption discovered post-freeze | medium | critical (cannot patch wire format) | `EVENT_TYPE_PROTOCOL_NOTICE` (vendor-signed kill switch) can suspend specific EventTypes or prompt upgrade |
| Ed25519 needs replacement (post-quantum) | low | high (cannot rotate signature algorithm) | `sig_algo` byte in envelope; spec reserves values `0x02-0xFF` for future algorithms |
| BLE chip thermal throttle / scan starvation | medium | medium (mesh silently dies) | Foreground-service health watchdog; UI notifies user when adapter idle > 5 minutes despite expected mesh activity |
| Cross-platform IBLT / Bloom hash divergence | medium | high (sync fails silently between platforms) | Cross-platform conformance corpus (§3.3.6) gates 0c acceptance |
| Tombstone table grows unbounded under attack | low | medium (storage exhaustion) | `TOMBSTONE_TTL` with hard cap; rate-limit acceptance of new envelopes per `author_key` |
| Priority abuse (forged SOS) | high | medium (UI noise, attention exhaustion) | Receiver-side `(event_type, priority)` matrix validation; downgrade or drop mismatches; over-budget SOS dropped |
| iOS Critical Alerts entitlement denied | medium | low (Android still has high-priority path) | Conditional ship of iOS SOS notification; never block Android or protocol work on this |
| Chunking reassembly memory exhaustion | low | medium | Hard cap on `total_chunks` per envelope; reassembly timeout; rate-limit per peer |

Risk register is a living document; new risks discovered during 0c or 0d MUST be added before Stage 1 begins.

## 4. v0.3 Stage 1: User-Facing Disaster Minimum Loop

Stage 1 may begin only after the 0d real-device gate passes.

### 4.1 Status Broadcast

The UI flow lets the user broadcast a status. Under the hood, every broadcast is a single `EVENT_TYPE_STATUS_UPDATE` envelope with a snapshot payload (see §3.2.3) — never a separate-EventType emission per state label.

User-facing options (UI affordances; the payload is always a snapshot underneath):

- I am safe.
- I need help.
- I am injured.
- I need water.
- I need power.
- I need medicine.

Notes:

- "Unknown/offline" is not a broadcast option. It is inferred when heartbeat/status is stale.
- Needs such as water/power/medicine should show a "Create supply request?" prompt.
- Do not auto-create supply requests without user confirmation. The status update and the supply request are TWO different envelopes (two-stage relationship, per §3.2.3).

### 4.2 30-Second Disaster Install Flow

First launch only.

Goal:

- Do not trap disaster-time users in normal onboarding.
- Open quickly into map/SOS/status capability.
- Ask the minimal question: "Are you safe?"
- Defer optional profile, tutorials, and non-critical setup.

The first-launch answer sets local state only. It must not automatically broadcast a status event to the mesh. Sharing the status requires an explicit user action from the status sheet or equivalent status control.

### 4.3 Offline Response Task Cards

Small set only:

- Earthquake.
- Fire.
- Bleeding / first aid.
- Communication outage.
- Evacuation movement.

Requirements:

- Store as local assets.
- Content source must be traceable.
- Keep steps short and actionable.
- Avoid unsupported medical claims.

### 4.4 Accessibility First Wave

Required:

- Larger text support.
- High contrast mode.
- Semantics labels for map buttons.
- Sheets must be closable and not trap the user.
- SOS/status controls must not be obscured by overlays.

### 4.5 Official Alerts Online Fetch / Cache / Map Display

v0.3 target:

- Online fetch.
- Local cache.
- Map/list display.
- Last updated timestamp.
- Source label.

Preferred naming: Official Alerts.

Preferred source order:

1. NCDR CAP.
2. CWA provider.
3. Future local government / road closure providers.

Do not implement mesh alert summary broadcast in v0.3 unless Stages 0a-0d and Stage 1 are ahead of schedule. The mesh-summary form follows the ALERT priority budget (§3.2.5) and chunking framing from 0b.

## 5. v0.4: Disaster Collaboration

Theme: build collaborative workflows on the clean v0.3 protocol skeleton.

v0.4 features may begin DESIGN in parallel with Stage 1 UI work, BUT may not SHIP before Stage 1 is complete. Each v0.4 feature MUST additionally specify any `PROTOCOL_HELLO.capabilities` entry it requires for opt-in negotiation.

Recommended dependency order:

1. Battery sharing.
   - Heartbeat extension.
   - Opt-in display.
   - Low payload cost.

2. Shelter status.
   - POI metadata.
   - LWW CRDT.
   - Open/full/needs-water/needs-power/needs-medical.
   - Last update time and source trust.

3. Skill/resource registration.
   - Local-first.
   - Share on demand, not broad active exposure.

4. Disaster photo report.
   - Extends hazard/disaster report.
   - Offline queue.
   - EXIF stripping.
   - Mesh carries summary/hash/thumbnail only, not full image by default.

5. Relay-to-Contact.
   - B-side confirmation.
   - No automatic dialing.
   - Mask phone numbers where possible.
   - App-owned emergency contacts or OS contacts permission; do not assume Health Connect provides emergency contacts.

6. Official alert mesh summary.
   - Include source, timestamp, hash, signature/verification state.
   - Unverified alerts must be clearly marked.

7. Mesh health dashboard.
   - Simple user view plus deeper dev mode.
   - Nearby node count, last sync time, queue size, recent drops.

8. Nearby SOS high-priority notification.
   - Android first.
   - User opt-in.
   - Do not promise DND / critical override unless OS permission supports it.

9. QR family/team pairing + TOFU trust.
   - Pairing and trust bootstrapping should be designed together.
   - Pairing establishes the `paired` value for `source_trust` (§3.2.1).

## 6. v0.5+ Research Pool

No delivery commitment until closed beta and real-device feedback justify the feature.

Candidates:

- Volunteer task board.
- Village relay / old-phone relay mode.
- Dead man's switch.
- Open Location Code.
- Offline routing to shelters.
- Voice PTT over BLE.
- Supply/demand heatmap.
- More complete trust graph.

## 7. Closed Beta Tester Onboarding Draft

Short message template:

```text
我們正在測試 IgniRelay / 烽傳的封閉測試版。這不是正式救災工具，也不能取代 119/官方通報。

這版想請你幫忙測：
1. 地圖平移/縮放是否順。
2. 定位是否會亂跳回來。
3. SOS / 物資媒合 / 聊天是否能正常操作。
4. 電量消耗是否異常。
5. 遇到卡頓、閃退、怪畫面時請截圖，並附手機型號、Android/iOS 版本、操作步驟。

注意：v0.3 前資料和通訊協議仍可能重設，本機資料可能會被清掉。
```

Tester checklist:

- Install APK/Build.
- Complete first launch.
- Grant location/notification/Bluetooth permissions.
- Verify auto-recenter fix:
  - Wait for location.
  - Drag away.
  - Wait for later GPS update.
  - Confirm map does not snap back.
- Test dense area map:
  - Taipei/Xinyi or similar dense area.
  - 30 seconds pan.
  - 30 seconds zoom.
  - Report subjective smoothness.
- Test SOS flow.
- Test supply request/offer flow.
- Test chat room display.
- Record battery drain over 15-30 minutes if possible.
- Test airplane mode / pure offline behavior.
- Test low battery behavior below 20%.
- Revoke Bluetooth/location permissions mid-session and confirm the app degrades gracefully.

## 8. Agent Handoff Instruction

Use this when asking an implementation agent to proceed:

```text
Please write the v0.3 Stage 0a and Stage 0b implementation specs first. Do not modify app code, proto files, Dart, Kotlin, or Swift sources.

Use the roadmap in text/resqmesh_v0.3_v0.5_protocol_roadmap_spec_brief_2026-05-13.md as source context.

Write TWO specs:
1. docs/specs/envelope_v2_spec_2026-05-13.md      — Stage 0a deliverable
2. docs/specs/native_transport_v1_2026-05-13.md   — Stage 0b deliverable

The two specs MUST be drafted in parallel and cross-reviewed; their payload budgets and MTU profiles are mutually constraining.

The 0a spec (envelope_v2_spec) must include:
- Single-layer EventEnvelope v2 protobuf message. The legacy MeshEnvelope wire shape is dead; if the old message remains in proto, deprecate/reserve it separately. Do not treat legacy MeshEnvelope tags as EventEnvelope v2 tags.
- EventType enum grouping per roadmap §3.2.2. STATUS is ONE EventType with snapshot payload, NOT a flat enum per state.
- StatusUpdateData snapshot payload schema per roadmap §3.2.3.
- Signature scope white-list per roadmap §3.2.4 (sign envelope_id, event_type, priority, created_at_hlc, expires_at_hlc, max_hops, author_key, sig_algo, locally computed SHA-256(payload); do NOT sign last_relay_id, hop_count_seen, signature_status, source_trust).
- Payload budget per priority per roadmap §3.2.5 (SOS ≤ 240B envelope; ALERT ≤ 800B; etc.).
- Dedupe key = envelope_id; LWW key table per EventType per roadmap §3.2.6.
- DB schema reset design with db_version table and required indexes per roadmap §3.2.7.
- Tombstone / expired sync policy per roadmap §3.2.8.
- Reconnect minimum behavior per roadmap §3.2.9.
- Dev-only Mesh_Trace_Logs structured table per roadmap §3.2.10 (NOT a string blob in Debug_Logs).
- Freeze policy text for CLAUDE.md and docs/protocol.md per roadmap §3.2.11.

The 0b spec (native_transport_v1) must include:
- P0 removal plan for Android's 514-byte truncation per roadmap §3.3.1.
- iOS parity work plan per roadmap §3.3.2 (IBLT.swift, Bloom-diff push, Long Write / Prepared Write, MTU upcall, 10s subscribe fallback, advertising error events).
- App-level chunking + reassembly framing per roadmap §3.3.3 (chunk header, max chunks, reassembly timeout; signature scope is full envelope, not per-chunk).
- PROTOCOL_HELLO timing + fields + 5s degradation per roadmap §3.3.4.
- Capability profile catalog per roadmap §3.3.5 (PhoneV1-legacy, PhoneV1, BleNodeV1, Tier0Mule).
- Cross-platform wire conformance corpus requirements per roadmap §3.3.6 (jointly with 0a).
- MTU range support matrix (23 / 185 / 247 / 512).
- BLE adapter recovery story.
- Risk register additions specific to native transport.

Both specs MUST address:
- LWW snapshot semantics for STATUS_UPDATE (snapshot replace; the same author's STATUS_UPDATE supersedes prior — never a delta).
- Two-stage STATUS → SUPPLY_REQUEST relationship: a STATUS_UPDATE with NEED_WATER may prompt a separate SUPPLY_REQUEST envelope, but the STATUS_UPDATE is not itself the supply-matching event.
- Category-specific TTL defaults per EventType (SOS, status, hazard, alert, chat, heartbeat/control) — do not invent one global TTL.
- Protobuf naming convention: EVENT_TYPE_<GROUP>_<NAME> prefix.

Hard constraints:
- DO NOT modify app code, proto files, Dart, Kotlin, or Swift sources while writing these specs.
- DO NOT touch the prototype UI document at text/prototype_v0_3_to_v0_5_update_instructions_2026-05-13.md (UI prototype is a separate lane and must not absorb protocol detail).
- Envelope protobuf field tags and EventType enum values are different; keep them separate.
- v0.3 may wipe internal/dev data; no elaborate compatibility layer is required.
- 30-second disaster install flow is first-launch only.
- Official alerts should be NCDR CAP-first, with CWA as a provider.
- iOS Critical Alerts entitlement must not block Android or v0.4 work.

Return the two specs for review. Stage 0c (implementation) does not begin until both specs are reviewed and accepted.
```

## 9. Review Checklist For Other Agents

### 9.1 When reviewing the 0a Envelope v2 spec

- Is the legacy `MeshEnvelope` clearly deprecated or removed without confusing its per-message field tags with the new `EventEnvelope` tag space?
- Are protobuf field tags stable, sparse, and future-safe?
- Are removed/experimental fields planned with `reserved` behavior?
- Are EventType enum groups broad enough?
- Is `EVENT_TYPE_STATUS_UPDATE` a single type carrying a snapshot payload (NOT a flat per-state enum)?
- Does `StatusUpdateData` model compound state (safe + needs) correctly with per-need `expires_at_hlc`?
- Are TTL defaults appropriate for SOS, status, hazard, alert, and normal messages?
- Are `max_hops` and `expires_at_hlc` separate fields with separate semantics?
- Is `expires_at_hlc` in HLC time, not wallclock?
- Does reconnect filtering avoid resurfacing stale emergencies?
- Is the tombstone policy defined so expired envelopes do not re-circulate via IBLT/Bloom?
- Is source trust clear without pretending unverified data is official?
- Is signature status explicit and testable?
- Is the signature scope white-list well-defined (author-bound vs relay-mutable)?
- Is `sig_algo` reserved for crypto agility?
- Is priority validation by the receiver enforced against event_type (per a matrix)?
- Are payload budgets concrete (with byte numbers) and per priority?
- Are dedupe and LWW keys explicitly derived per EventType in a table?
- Does the DB schema support dedupe, expiry, priority, and relay state efficiently?
- Is there a `db_version` table from day one?
- Is there a dedicated `Mesh_Trace_Logs` table (not a string blob in `Debug_Logs`)?
- Does the spec define LWW snapshot semantics for STATUS_UPDATE by the same `author_key`?
- Is the relationship between STATUS_UPDATE and SUPPLY_REQUEST documented as two-stage?
- Do EventType values use the `EVENT_TYPE_<GROUP>_<NAME>` prefix?
- Is `author_key` distinct from `last_relay_id` in storage, signature scope, and trace layers?
- Is trace logging useful without exposing sensitive data?
- Is `PROTOCOL_NOTICE` defined as the post-freeze kill switch?

### 9.2 When reviewing the 0b Native transport spec

- Is the Android 514-byte truncation removal plan concrete (not just "remove the line")?
- Are iOS parity items each scoped (IBLT.swift, Bloom-diff push, Long Write, MTU upcall, 10s fallback, advertising error events)?
- Is the chunking framing deterministic and order-independent?
- Is the signature computed over the FULL reassembled envelope, not per chunk?
- Does `PROTOCOL_HELLO` fire at the right time (after MTU + service discovery, before any event payload)?
- Are `PROTOCOL_HELLO` fields sufficient to negotiate capability without round-trip races (both peers send independently; 5s fallback)?
- Is the capability profile catalog enumerated with explicit MTU / EventType / chunking support per profile?
- Does the cross-platform conformance corpus cover envelope, IBLT, Bloom, and chunking — both positive and negative cases?
- Is the MTU range (23-512) covered with concrete test cases?
- Is the BLE adapter recovery story defined (overheating, scan starvation, advertising failure)?
- Are iOS background advertising constraints addressed (no `LocalName` in background; UUID-only scan path)?

### 9.3 When reviewing the 0d real-device gate

- Are pass criteria quantified (latency p50/p95, success-rate threshold)?
- Are all 6 phones × 15 pairs covered?
- Are MTU 185 / 247 / 512 each exercised?
- Is failure-handling defined (block Stage 1 vs explicit waiver via risk register)?
- Is the acceptance matrix attached to the v0.3 release notes?
