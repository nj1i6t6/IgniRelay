# ResQMesh / IgniRelay v0.3-v0.5 Protocol Roadmap Spec Brief

Date: 2026-05-13  
Status: review draft for human / agent alignment  
Scope: planning and specification only; do not implement from this document without a follow-up implementation spec.

## 0. Core Decision

The project has not shipped a stable public communication protocol yet. Therefore v0.3 may use a destructive protocol and storage reset.

This changes the strategy:

- Do not spend v0.3 effort on backwards compatibility layers for pre-release message formats.
- Do not write complex migrations for existing internal/dev data unless a specific beta dataset must be preserved.
- Use this window to design the wire format, DB schema, EventType enum layout, TTL behavior, and tests correctly.
- After v0.3 protocol freeze, future releases must follow migration and compatibility discipline.

The guiding principle:

> v0.3 builds the clean protocol/storage skeleton; v0.4 builds collaboration features on top; v0.5+ is driven by beta and real-device feedback.

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

## 3. v0.3: Protocol / Storage Reset + Disaster Minimum Loop

Theme: build the protocol skeleton correctly, then ship the smallest useful disaster loop.

Estimated shape: Stage 0 first, then Stage 1.

### 3.1 Stage 0: Envelope v2 + Storage Reset

Stage 0 is a protocol spec and storage design task. It is not a UI feature task.

Required outputs:

- `EventEnvelope` v2 protobuf/message definition.
- EventType enum value grouping.
- New DB schema centered on envelope v2.
- `db_version` table from the start.
- TTL / expiresAt / reconnect filtering behavior.
- Wire-format golden tests.
- Dev-only mesh trace log.
- Freeze policy text for later insertion into `CLAUDE.md` and `docs/protocol.md`.

Recommended order:

1. Design `EventEnvelope` message structure.
2. Define payload categories and EventType enum grouping.
3. Design DB schema around envelope storage and indexing.
4. Define send/receive/drop rules.
5. Define reconnect and expiry UX.
6. Define golden tests and trace diagnostics.
7. Only after review, implement code.

### 3.2 EventEnvelope v2 Required Concepts

The exact proto should be designed in the implementation spec, but it should include these concepts:

| Concept | Purpose |
|---|---|
| schema/protocol version | Allows future decoding and migration discipline. |
| envelope id | Stable message id for dedupe, tracing, and user reports. |
| event type | Payload semantic category. |
| priority | SOS / alert / status / normal handling. |
| createdAt | Origin creation time. |
| expiresAt or TTL | Expiry behavior for mesh hygiene and reconnect filtering. |
| dedupe key | Prevents repeated relays and duplicate UI cards. |
| author key | Ed25519 identity of the message creator; used for payload signature verification. |
| last relay id | Immediate sender at this hop; used for local trace/debug and loop diagnosis. |
| signature status | Valid / invalid / missing / not checked. |
| source trust | Self / paired / seen-before / unverified / official-verified. |
| hop count / relay metadata | Traceability and loop prevention. |
| payload bytes | Typed payload carried by the envelope. |
| payload budget | Enforced size limit by priority/category. |

Priority suggestion:

- `SOS`: highest, smallest, shortest relay path bias, user-visible immediately.
- `ALERT`: official or trusted warning, high but must mark verification state.
- `STATUS`: safety state, battery, shelter status.
- `NORMAL`: chat, non-urgent coordination.

Priority must be validated by the receiver against `event_type`. A normal chat or low-trust payload claiming SOS priority must be downgraded, dropped, or surfaced as suspicious according to the Envelope v2 spec.

### 3.3 EventType Enum Grouping

Keep groups broad and leave gaps.

Suggested layout:

```text
0      EVENT_TYPE_UNSPECIFIED

1-19   Personal / status
       SAFE, NEED_HELP, INJURED, NEED_WATER, NEED_POWER, NEED_MEDICINE, BATTERY_STATUS

20-49  Request / supply / coordination
       SUPPLY_REQUEST, SUPPLY_OFFER, MATCH_INTENT, NEGOTIATION, RELAY_TO_CONTACT

50-79  Hazard / disaster report
       HAZARD_MARKER, DISASTER_REPORT, SHELTER_STATUS

80-99  Official alerts
       OFFICIAL_ALERT_CAP, OFFICIAL_ALERT_SUMMARY

100-129 Mesh / system / control
       HEARTBEAT, TRACE_PING, TRACE_ACK, PROTOCOL_NOTICE

1000+  Experimental / local-only
```

Do not overfit the enum to current UI screens. The enum should model wire semantics.

### 3.4 Storage Reset Guidance

Because the app is still pre-stable:

- It is acceptable to redesign tables around envelope v2.
- It is acceptable to wipe local dev/internal beta DB.
- Avoid writing elaborate migration code for the old pre-freeze schema.

Minimum storage requirements:

- `db_version` table.
- Envelope table with indexes for:
  - `event_type`
  - `priority`
  - `created_at`
  - `expires_at`
  - `dedupe_key`
  - `author_key`
  - sync/relay state
- Payload/detail tables only when needed for query efficiency.

For LWW status lookup, consider a composite index on (`author_key`, `event_type`, `created_at` DESC).

Hidden is not deleted. The storage spec must define periodic garbage collection, such as running on app launch and every N hours while active. Hard-delete envelopes only after `expiresAt + grace_period < now`; the grace period preserves short-term trace/debug history without letting stale incidents reappear in the active UI.

### 3.5 Reconnect Minimum

Reconnect behavior is part of envelope v2, not a separate v0.4 feature.

Minimum v0.3 behavior:

- Drop or hide messages where `expiresAt < now`, unless user explicitly opens history/debug.
- Show a lightweight toast/banner when stale queued messages were discarded.
- Do not surface expired SOS/status/hazard as active incidents.
- Keep trace/debug records for diagnosis if dev mode is enabled.

### 3.6 Dev-Only Mesh Trace Log

v0.3 should include internal trace logging for protocol debugging.

Trace fields should include:

- envelope id
- event type
- priority
- author_key, truncated or hashed if needed for privacy
- last_relay_id
- createdAt / expiresAt
- sent / received / dropped
- drop reason
- dedupe hit/miss
- signature status
- hop count
- relay attempt count
- peer/device id when safe to log

This is not a user-facing dashboard in v0.3.

### 3.7 Wire Golden Tests

Before implementation is accepted, add tests that lock:

- Envelope v2 binary encoding for representative messages.
- Unknown field tolerance.
- Unknown EventType behavior.
- Expired message filtering.
- Dedupe behavior.
- Signature status mapping.
- Payload budget rejection.

These tests are the beginning of protocol freeze discipline.

### 3.8 Freeze Policy

After v0.3 spec is accepted and implemented, document:

- Envelope v2 wire format is frozen after v0.3.
- Protobuf field tags must not be reused.
- Removed fields must be reserved.
- EventType enum values must not be reused.
- DB changes after freeze require migrations.

Required documentation locations after spec acceptance:

- `CLAUDE.md`
- `docs/protocol.md`

## 4. v0.3 Stage 1: User-Facing Disaster Minimum Loop

Stage 1 should start only after Stage 0 spec is reviewed.

### 4.1 Status Broadcast

Broadcast options:

- I am safe.
- I need help.
- I am injured.
- I need water.
- I need power.
- I need medicine.

Notes:

- "Unknown/offline" is not a broadcast option. It is inferred when heartbeat/status is stale.
- Needs such as water/power/medicine should show a "Create supply request?" prompt.
- Do not auto-create supply requests without user confirmation.

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

Do not implement mesh alert summary broadcast in v0.3 unless Stage 0 and Stage 1 are ahead of schedule.

## 5. v0.4: Disaster Collaboration

Theme: build collaborative workflows on the clean v0.3 protocol skeleton.

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
   - Do not promise DND/critical override unless OS permission supports it.

9. QR family/team pairing + TOFU trust.
   - Pairing and trust bootstrapping should be designed together.

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
Please write the Envelope v2 implementation spec first. Do not modify app code yet.

Use the roadmap in text/resqmesh_v0.3_v0.5_protocol_roadmap_spec_brief_2026-05-13.md as source context.

Write the spec to docs/specs/envelope_v2_spec_2026-05-13.md.

The spec must include:
- EventEnvelope v2 protobuf/message structure.
- EventType enum grouping.
- DB schema reset design.
- TTL/expiresAt/priority/dedupe/sourceTrust/signatureStatus rules.
- payload size budgets.
- reconnect expired-message filtering.
- dev-only mesh trace log format.
- wire golden test plan.
- freeze policy text for CLAUDE.md and docs/protocol.md.

Spec MUST also address:
- LWW semantics for status updates. For example, the same author changing from injured to safe must supersede the older active status instead of showing both.
- The two-stage relationship between STATUS events and SUPPLY_REQUEST events. A status such as need water may prompt a supply request, but it is not itself the supply matching event.
- Category-specific TTL defaults, such as SOS, status, hazard, alert, chat, and heartbeat/control messages. Do not invent one global TTL.
- Protobuf naming convention. EventType values should use explicit prefixes such as EVENT_TYPE_STATUS_SAFE rather than bare names such as SAFE.

Important:
- Envelope protobuf field tags and EventType enum values are different; keep them separate.
- Envelope message structure should be designed before EventType enum finalization.
- v0.3 may wipe internal/dev data; no elaborate compatibility layer is required.
- 30-second disaster install flow is first-launch only.
- Official alerts should be NCDR CAP-first, with CWA as a provider.
- iOS Critical Alerts entitlement must not block Android/v0.4 work.

Return the spec for review. Do not implement code until the spec is approved.
```

## 9. Review Checklist For Other Agents

When reviewing the Envelope v2 spec, check:

- Are protobuf field tags stable, sparse, and future-safe?
- Are removed/experimental fields planned with `reserved` behavior?
- Are EventType enum groups broad enough?
- Are TTL defaults appropriate for SOS, status, hazard, alert, and normal messages?
- Are category-specific TTL defaults explicit for SOS, status, hazard, alert, chat, and heartbeat/control messages?
- Does reconnect filtering avoid resurfacing stale emergencies?
- Is source trust clear without pretending unverified data is official?
- Is signature status explicit and testable?
- Is priority validation by receiver enforced against event_type?
- Are payload budgets realistic for BLE mesh?
- Are golden tests sufficient to freeze the wire format?
- Does the DB schema support dedupe, expiry, priority, and relay state efficiently?
- Is the GC policy defined with a grace period after expiresAt?
- Does the spec define LWW semantics for status updates by the same author_key?
- Is the relationship between STATUS events and SUPPLY_REQUEST events clearly documented as two-stage?
- Do EventType values use the EVENT_TYPE_<GROUP>_<NAME> prefix convention?
- Is author_key distinct from last_relay_id in the storage and trace layers?
- Is trace logging useful without exposing sensitive data?
