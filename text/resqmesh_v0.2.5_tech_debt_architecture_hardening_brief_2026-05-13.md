# ResQMesh / IgniRelay v0.2.5 Technical Debt & Architecture Hardening Brief

Date: 2026-05-13
Status: locked brief for implementation-spec drafting
Scope: architecture brief and agent handoff source. Do not modify production code directly from this document; first produce a follow-up implementation spec with exact APIs, migration order, rollback plan, and per-stage verification.
Companion document: `text/resqmesh_v0.3_v0.5_protocol_roadmap_spec_brief_2026-05-13.md` (v0.3 protocol roadmap; feature work is blocked by the v0.2.5 gates below)

## 0. Core Decision

v0.3 user-facing feature work is blocked until v0.2.5 completes.

The project sits in a pre-launch window where the wire protocol can still be broken without compatibility cost. v0.3 will exercise that window to redesign the protocol. But the protocol-layer changes will be entangled with UI, DB, and proto coupling violations unless the boundaries are cleaned first.

This brief defines that cleanup as a dedicated sprint, not a side task in v0.3.

Three-tier goal:

1. Pay down existing technical debt that would otherwise force v0.3 to touch UI files for protocol-only changes.
2. Install architectural guardrails so new code cannot reintroduce the same debt.
3. Bound the blast radius so that future debt, when it appears, stays inside its module instead of cascading across UI / app / platform.

After Stage 1 and Stage 2A are green, v0.3 Envelope v2 spec / mesh-layer preparation may proceed in parallel with Stage 2B. v0.3 user-facing features remain blocked until all v0.2.5 completion criteria are green. After v0.2.5 completes, the protocol can be redesigned cleanly inside `app/mesh/` with no UI churn.

## 1. Non-Negotiable Clarifications

These points must be explicit in any agent handoff:

1. v0.2.5 is not a feature sprint. No new user-facing capability ships from this work.
2. UI behavior must not change. Tests that exercise UI behavior must pass before and after each commit.
3. The protocol wire format is NOT redesigned in v0.2.5. EventType / proto mismatch identified in audit is folded into v0.3 Envelope v2.
4. God-file splitting in v0.2.5 covers UI files only. Mesh-layer god files (`event_manager.dart`, `mesh_event_handler.dart`, `ble_manager.dart`) are rewritten by v0.3 Envelope v2 and explicitly NOT split twice.
5. `platform/` is redefined in v0.2.5 as "pure native adapter". `native_ble_transport.dart` is moved out because it does not match this definition.
6. New CI rules in `tool/check_layers.dart` are baselined at zero violations after v0.2.5. Future PRs that introduce new violations must fail CI.
7. `tool/check_layers.dart` rule additions must support an explicit exception list, so legitimate edge cases (e.g., test-only utilities) can be allowed without disabling the rule.
8. v0.2.5 must not introduce new `.instance` / factory-singleton entry points for newly added facades, repositories, or controllers. New dependencies are constructed at the app root and passed by constructor injection, then exposed to UI through Provider. Existing legacy singletons may be wrapped as dependencies, but they must not leak into UI or new v0.2.5 APIs.
9. v0.2.5 must remove direct UI access to legacy app-layer singletons and factory-singletons as part of the cleanup. Existing singleton classes may remain internally, but `lib/ui/` must not call `.instance`, `EventManager()`, `MeshEventHandler()`, `DatabaseHelper()`, or other app service/controller singleton constructors directly after v0.2.5.
10. v0.2.5 must produce documentation that the next agent (and future humans) can read without re-reading code: layer rules in `CLAUDE.md`, decisions in `docs/architecture/ADR-*.md`.

## 2. Current State Audit

All findings below have been independently verified against current source.

### 2.1 What Is Already Clean

- `lib/ui/` does not import `lib/platform/`. `tool/check_layers.dart` enforces this; baseline is empty.
- `lib/app/` does not import `lib/ui/`. Same enforcement, baseline is empty.
- Test suite is green. `flutter analyze` passes. `flutter test` reports 414 passed / 3 skipped.
- Architectural intent is documented in code:
  - `app/controllers/mesh_runtime_controller.dart:6-9` states UI must go through controller facade.
  - `app/mesh/mesh_event_handler.dart:17-19` states UI may re-export through app layer, not touch platform.
  - `ui/screens/map/map_screen_controller.dart:3-34` documents controller pattern with explicit principles.

### 2.2 Architectural Gaps Confirmed in Audit

#### 2.2.1 `tool/check_layers.dart` enforces only one boundary

Reference: `tool/check_layers.dart:38-50`.

Two rules only:
- `ui-cannot-import-platform`
- `app-cannot-import-ui`

Missing rules:
- `ui-cannot-import-mesh` (`lib/ui/**` importing `lib/app/mesh/**`)
- `ui-cannot-import-proto` (`lib/ui/**` importing `lib/app/proto/**`)
- `ui-cannot-import-db` (`lib/ui/**` importing `lib/app/db/**`)
- `platform-cannot-import-app` (`lib/platform/**` importing `lib/app/**`)

This enforcement gap is the root cause of accumulated coupling. The team understands the layering rules (see code comments cited above), but only one is mechanically enforced.

#### 2.2.2 UI directly couples to mesh / proto / db internals

Quantified callsite counts, verified by grep:

| API surface | UI callsites | UI files affected |
|---|---|---|
| `EventManager()` direct call | 10 | 9 |
| `MeshEventHandler()` direct call | 8 | 6 |
| `DatabaseHelper()` direct call | 14 | 9 |
| `pb.X.fromBuffer(...)` (proto decode in UI) | 6 | 3 |

Representative violations:

- `ui/shell/main_shell.dart:85` — direct SQL: `db.query('Event_Logs', where: 'event_type = ? AND urgency >= 2 AND hlc_timestamp > ?', ...)`
- `ui/shell/main_shell.dart:111,154,157` — direct proto decode: `pb.RequestData.fromBuffer(payload)`, `pb.MatchOfferData.fromBuffer(payload)`, `pb.MatchRequestData.fromBuffer(payload)`
- `ui/shell/main_shell.dart:135` — raw EventType literal in SQL: `event_type = 2 OR event_type = 15`
- `ui/sheets/hazard_dialog.dart:35` — direct mesh publish: `await EventManager().publishHazard(...)`
- `ui/screens/map/sheets/event_info_sheet.dart:119,125` — proto decode in sheet
- `ui/secondary/navigation_screen.dart:136` — direct SQL to `Match_Negotiations` table
- `ui/secondary/physical_handoff.dart:85` — direct SQL to `Match_Negotiations` table
- `ui/secondary/station_supply_screen.dart:1182` — direct SQL update to `Station_Quotas` table
- `ui/screens/map/map_screen_controller.dart:524` — direct SQL to `Event_Logs`

#### 2.2.3 `platform/` is not a pure native adapter

Reference: `lib/platform/native_ble_transport.dart:3-9`.

Imports from `platform/` into `app/`:

- `app/mesh/ble_manager.dart` (line 3)
- `app/mesh/event_manager.dart` (line 4)
- `app/mesh/mesh_event_handler.dart` (line 6)
- `app/mesh/triage_queue.dart` (line 8)
- `app/crypto/identity_manager.dart` (line 9)

The other three files in `platform/` are clean. The violation is concentrated in `native_ble_transport.dart`, which is doing mesh-aware transport orchestration rather than pure native bridging.

This is a definition problem, not just a placement problem. If `platform/` means "raw native adapters", `native_ble_transport.dart` does not belong there. If `platform/` means "transport including app-aware routing", then the directory name is misleading and the layer rule changes.

v0.2.5 resolves this by tightening the definition and moving the file.

#### 2.2.4 Singleton ubiquity

Five high-profile singletons that UI currently reaches directly via parameterless constructors or `.instance` (not an exhaustive list of all singletons in the codebase — these are the architecturally relevant ones for v0.2.5 boundary work):

- `EventManager()` — `app/mesh/event_manager.dart:37-39`
- `MeshEventHandler()` — `app/mesh/mesh_event_handler.dart:62-64`
- `BleManager()` — `app/mesh/ble_manager.dart:19-21`
- `MeshRuntimeController.instance` — `app/controllers/mesh_runtime_controller.dart:22`
- `EmergencyModeController.instance` — `app/emergency/emergency_mode_controller.dart`

This pattern is not itself a bug. The bug is that UI calls these singletons directly with no facade in between, which is what the new layering rules will block.

v0.2.5 does NOT eliminate all existing singleton classes internally. Full removal or rewrite of the existing app singleton graph is out of scope. However, v0.2.5 DOES forbid adding new singleton entry points for newly created facades, repositories, or controllers, and it DOES remove direct UI access to existing singleton entry points. New v0.2.5 code must use constructor injection and root Provider wiring so the cleanup does not recreate the same debt under a different name.

### 2.3 Protocol-Level Latent Bug (Folded Into v0.3)

#### 2.3.1 EventType / proto enum mismatch

References:
- Dart: `lib/app/mesh/event_types.dart:14-17` defines `matchRequest=15, handshakeComplete=16, stationClaim=17, stationResponse=18`.
- Proto: `protos/mesh_protocol.proto:5-21` defines EventType enum only through `LOCATION_UPDATE=14`.
- Generated: `lib/app/proto/mesh_protocol.pbenum.dart:18-50` matches the proto, only 0-14.
- Encoder fallback: `lib/app/mesh/mesh_event_handler.dart:525-526` silently falls back to `RESOURCE_REGISTER` when `pb.EventType.valueOf(eventType)` returns null.
- Existing test: `test/proto/event_type_enum_test.dart:40-42` asserts `valueOf(15) returns null (out of range)` — documents the gap but does not protect against it.

Production impact (per user confirmation): no cross-device flow has actually exercised EventType 15-18. The latent bug has not manifested.

Resolution: v0.2.5 does NOT add a hot-fix to sync proto. v0.3 Envelope v2 resets the EventType enum design. v0.2.5 DOES add a new golden test that fires until the mismatch is resolved (see §4.4.1).

### 2.4 UI God Files

Files over 800 lines that touch mesh / proto / db boundaries, or exceed 1000 lines unconditionally:

| File | Lines | Coupling | Split decision |
|---|---|---|---|
| `ui/secondary/station_supply_screen.dart` | 1344 | DB×2, proto×1, EventManager×2 | Split (highest priority) |
| `ui/secondary/medical_card_screen.dart` | 1031 | DB×1 | Split (form sub-widget extraction) |
| `ui/screens/match/match_screen.dart` | 972 | EventManager×1, MeshEventHandler×1 | Split (audit first; tabs are already separate files, shell may be thin already) |
| `ui/screens/map/map_screen_controller.dart` | 980 | DB, mesh imports | Do not split (controller pattern with documented header rules) |
| `ui/screens/me/profile_screen.dart` | 866 | DB×1 | Split (section extraction) |
| `ui/secondary/physical_handoff.dart` | 778 | EventManager, DB×2 | Split (FSM controller + step views) |
| `ui/secondary/survival_mode_screen.dart` | 775 | EventManager, MeshEventHandler×3, DB×3 | Split (debug page; simplified split acceptable) |

Files explicitly excluded from v0.2.5:
- `ui/screens/map/map_screen_controller.dart` — already organized
- `ui/screens/design_showcase_screen.dart` — 686 lines, pure demo, no boundary coupling
- `ui/secondary/onboarding_screen.dart`, `ui/secondary/battery_optimization_guide.dart` — under threshold

### 2.5 Mesh-Layer God Files (Owned by v0.3, Not v0.2.5)

| File | Lines | v0.3 plan |
|---|---|---|
| `app/mesh/event_manager.dart` | 903 | Decomposed into EnvelopeCodec / EventPublisher / RateLimiter / MedicalCardExtractor |
| `app/mesh/mesh_event_handler.dart` | 738 | Decomposed into EnvelopeCodec (shared) / EnvelopeStore / EventProjector / MeshEventBus |
| `app/mesh/ble_manager.dart` | 817 | Stays or splits per v0.3 transport design |

v0.2.5 does NOT touch these files internally. v0.2.5 only inserts facades in front of them so UI callsites can be redirected without changing the legacy singletons' implementation. Those facades are not themselves singletons; they receive the legacy dependencies through constructors.

## 3. Splitting Criteria (Lock This Rule)

For consistency and to prevent scope creep, any file split in v0.2.5 must meet at least one of:

1. File exceeds 800 lines AND contains at least one import of `app/mesh/`, `app/proto/`, or `app/db/`.
2. File exceeds 1000 lines, regardless of coupling.
3. File is being modified during Stage 1 boundary cleanup anyway (one-pass principle).

Files NOT split, even if large:
- Under 800 lines.
- Over 800 lines but no mesh / proto / db coupling (e.g., demo screens).
- Already organized in controller / view / repository pattern (e.g., `map_screen_controller.dart`).

Files NOT split because v0.3 will rewrite them:
- `app/mesh/event_manager.dart`
- `app/mesh/mesh_event_handler.dart`
- `app/mesh/ble_manager.dart`

## 4. Stage Breakdown

v0.2.5 has five stages. Stages 1-2 must complete before Stages 3-5 start. Stages 3-5 may run in parallel.

### 4.1 Stage 1: Protocol Boundary Facade

Estimated: ~3 days.

Goal: UI callsites stop reaching mesh / proto / db directly. New facade objects in `app/controllers/` and `app/services/` mediate every cross-layer access.

#### 4.1.1 New facade and repository files to create

Domain-specific repositories prevent the new EventStore from becoming a god repository. Each domain owns its own SQL.

All new files listed here must be regular injectable classes: public constructors with explicit dependencies, no private singleton constructors, no `static final instance`, and no factory constructor that hides a singleton. `main.dart` owns construction and Provider registration.

| New file | Wraps | Replaces UI usage of |
|---|---|---|
| `app/controllers/event_publisher.dart` | `EventManager().publish*()` | 10 UI callsites |
| `app/controllers/event_stream.dart` | `MeshEventHandler().events` + high-level event types | 8 UI callsites |
| `app/services/event_decoder.dart` | All `pb.X.fromBuffer(...)` calls; returns plain Dart objects | 6 UI callsites |
| `app/services/event_store.dart` (new) | `DatabaseHelper().database` queries against `Event_Logs` only | ~4 UI callsites (SOS scan, marker overlay, debug log) |
| `app/services/negotiation_repo.dart` (extend existing) | Queries against `Match_Negotiations` | ~3 UI callsites (navigation_screen, physical_handoff) |
| `app/services/station_supply_repo.dart` (new) | Queries against `Station_Quotas` and related tables | ~3 UI callsites (station_supply_screen) |
| `app/db/medical_card_repo.dart` (extend existing) | Medical card SQL | ~1 UI callsite (medical_card_screen) |
| `app/services/profile_repo.dart` (new) | Profile / debug-log queries used by profile_screen and survival_mode_screen | ~3 UI callsites |

Note on existing files: `app/services/negotiation_repo.dart` already exists (301 lines). Extend it; do not create a parallel. Similarly `app/db/medical_card_repo.dart` already exists. The implementation spec must catalogue which repos already exist and which are new.

#### 4.1.2 Facade and repository API contract (high-level)

Exact method signatures are deferred to the implementation spec. The contract is shape only.

`EventPublisher` (controller-layer facade):
- `publishHazard(...)`, `publishSupplyRequest(...)`, `publishMatch*(...)`, etc.
- Wraps but does not change `EventManager` internal semantics.
- Returns plain Dart result objects, not protobuf types.
- Receives `EventManager` through its constructor. It must not expose `EventPublisher.instance`.

`EventStream` (controller-layer facade):
- Typed high-level streams: `Stream<SosAlert>`, `Stream<MatchUpdate>`, `Stream<HazardEvent>`, `Stream<SupplyChange>`.
- Internally subscribes to `MeshEventHandler().events`, decodes via `EventDecoder`, dispatches to typed streams.
- UI no longer cares about raw `MeshDataReceived`.
- Receives `MeshEventHandler` and `EventDecoder` through its constructor. It must not expose `EventStream.instance`.

`EventDecoder` (service-layer):
- `decodeRequestData(List<int> payload) -> RequestData?` returning plain Dart class, not `pb.RequestData`.
- All `fromBuffer` calls live here.
- Throws or returns null on failure; UI never sees raw protobuf exceptions.
- Stateless class with a public constructor. It must not expose `EventDecoder.instance`.

`EventStore` (service-layer, narrow scope):
- ONLY `Event_Logs` table.
- `queryRecentSos({Duration window})`, `queryMarkersInBounds(...)`, etc.
- Does NOT cover `Match_Negotiations`, `Station_Quotas`, or any other tables.
- Receives database access through its constructor. It must not expose `EventStore.instance`.

`NegotiationRepo` (extends existing):
- `Match_Negotiations` access.
- `queryNegotiation(String id)`, `queryPeerLocationForNegotiation(...)`, etc.

`StationSupplyRepo` (new):
- `Station_Quotas` and station-supply-related tables.
- `queryStation(...)`, `updateStationQuota(...)`, `resetStationUsage(...)`.
- Receives database access through its constructor. It must not expose `StationSupplyRepo.instance`.

`MedicalCardRepo` (extends existing):
- Medical card SQL kept inside this file.

`ProfileRepo` (new):
- Profile data, debug log queries.
- Includes the queries used by `survival_mode_screen.dart`.
- Receives database access through its constructor. It must not expose `ProfileRepo.instance`.

Anti-pattern guard: if during implementation a new query needs to span tables across domains (e.g., joining `Event_Logs` to `Match_Negotiations`), expose the join as a method on the domain that the query *primarily* serves, not in `EventStore`. Document the cross-domain coupling in the implementation spec.

#### 4.1.3 UI callsite migration

Every UI file in the 11-file violation set is touched. Each file's diff is:
- Remove import of `app/mesh/`, `app/proto/`, `app/db/`.
- Add import of relevant facade or repository.
- Replace direct calls with facade or repository calls.

No business logic changes. No behavior changes. Same tests pass.

The implementation spec must define the migration order (which file first, which last) and the rationale (typically: lowest-risk files first, highest-coupling files last).

#### 4.1.4 `app/mesh/` directory scope cleanup

Today `app/mesh/` mixes mesh-networking files with map / geographic data files. This blocks the new `ui-cannot-import-mesh` rule because legitimate map UI code currently imports from this directory.

Files mis-located in `app/mesh/`:

- `app/mesh/mbtiles_loader.dart` → tile loader for offline vector map. Not mesh-related.
- `app/mesh/poi_query.dart` → POI lookup on offline map. Not mesh-related.
- `app/mesh/geo_context_resolver.dart` → resolves administrative region for a coordinate. Geo, not mesh.

UI imports affected:
- `ui/screens/map/map_screen_controller.dart:53,55` imports `mbtiles_loader`, `poi_query`.
- `ui/screens/map/widgets/map_location_header.dart:4` imports `poi_query`.
- `ui/secondary/navigation_screen.dart:13` imports `mbtiles_loader`.
- `ui/sheets/resource_request_sheet.dart:4` imports `geo_context_resolver`.
- `ui/secondary/supply_registration.dart:4` imports `geo_context_resolver`.

Move plan:

| Current path | New path |
|---|---|
| `lib/app/mesh/mbtiles_loader.dart` | `lib/app/map/mbtiles_loader.dart` (new directory) |
| `lib/app/mesh/poi_query.dart` | `lib/app/map/poi_query.dart` |
| `lib/app/mesh/geo_context_resolver.dart` | `lib/app/geo/geo_context_resolver.dart` (existing directory) |

After the move:
- `app/mesh/` contains only mesh-networking code (event_manager, mesh_event_handler, ble_manager, iblt, mesh_router, mesh_constants, event_types, triage_queue, tier_manager, hazard_manager, plus the moved native_ble_transport_adapter).
- `app/map/` contains map data / tile / POI logic.
- `app/geo/` contains geographic-region resolution.
- UI map widgets import from `app/map/`, not `app/mesh/`. The new `ui-cannot-import-mesh` rule no longer false-positives on map code.

This move is required before §4.3 CI rule activation. Otherwise the new rule blocks legitimate map imports and forces ugly exception entries.

#### 4.1.5 `platform/` cleanup

Move two files out of `lib/platform/`:

| Current path | New path | Reason |
|---|---|---|
| `lib/platform/native_ble_transport.dart` | `lib/app/mesh/native_ble_transport_adapter.dart` | Imports 4 mesh files + 1 crypto file; mesh-aware transport orchestration |
| `lib/platform/transport_factory.dart` | `lib/app/mesh/transport_factory.dart` | Factories belong near what they factory; would violate `platform-cannot-import-app` if left behind |

`main.dart` updated to import `transport_factory` from the new location.

After the move, `platform/` is purely native bridge:
- `mesh_transport.dart` — abstract interface (no imports of `app/`)
- `native_bridge.dart` — MethodChannel wrapper (no imports of `app/`)
- `native_bridge_facade.dart` — test seam (no imports of `app/`)

Verification: `grep -r "import 'package:ignirelay_app/app/" lib/platform/` returns empty after the move.

This is the resolution to Open Question §10 item 1. No exception in `platform/`. Decisive move.

### 4.2 Stage 2: UI God File Splits

Estimated: ~5-7 days total. Split into Stage 2A (critical path) and Stage 2B (parallel-acceptable) for risk management.

Goal: Apply the splitting criteria (§3) to the 6 god-file targets identified in §2.4.

Note on line counts: All line numbers in this brief are raw `wc -l` (total lines including blank and comment). Other metrics (non-blank-non-comment SLOC) yield smaller numbers but preserve the same relative ordering. The implementation spec must use raw `wc -l` consistently to avoid confusion.

#### 4.2.1 Stage 2A vs 2B split rationale

After Stage 1 completes, no UI file imports `app/mesh/`, `app/proto/`, or `app/db/` directly. The boundary problem is solved. What remains is the file size problem.

Stage 2A targets files that v0.3 user features will extend (status broadcast, supply prompt, Official Alerts integration). Keeping these as 1000+ line god files means v0.3 features get bolted on, growing the god file further. These must be split before v0.3 Stage 1.

Stage 2B targets files that v0.3 will NOT touch. They are still debt and still get split during v0.2.5, but if scope creep occurs, Stage 2B can run in parallel with v0.3 Stage 0 (Envelope v2 design / implementation, which is mesh-layer only and does not depend on these files).

| File | Stage | Reason |
|---|---|---|
| `station_supply_screen.dart` (1344) | 2A | v0.3 status broadcast → "create supply request?" prompt extends this screen |
| `match_screen.dart` (972) | 2A | v0.3 status broadcast feeds match flow; this screen will grow |
| `physical_handoff.dart` (778) | 2A | v0.3 STATUS / SUPPLY_REQUEST two-stage flow may touch handoff completion |
| `survival_mode_screen.dart` (775) | 2A | Debug page reads many event types; v0.3 EventType reset will require updates here |
| `medical_card_screen.dart` (1031) | 2B | Pure form UI; v0.3 does not touch medical card schema |
| `profile_screen.dart` (866) | 2B | Pure settings UI; v0.3 features do not bolt on here |

Stage 2A is on the v0.2.5 critical path. v0.3 cannot start until 2A is done.

Stage 2B is in v0.2.5 scope and should complete in v0.2.5. If unforeseen complexity surfaces, 2B may run alongside v0.3 Stage 0 (Envelope v2 spec drafting / mesh-layer implementation) without blocking the protocol work. 2B must complete before v0.3 Stage 1 (user features) begins.

#### 4.2.2 Generic split pattern (apply to each target)

For each god UI file, extract:

- `*Controller` (`ChangeNotifier`): owns state, lifecycle, async generation tokens. No `BuildContext`.
- `*View` (`StatefulWidget` or `StatelessWidget`): pure presentation. No SQL, no mesh subscription.
- Repository access goes through the Stage 1 repos (`EventStore`, `NegotiationRepo`, `StationSupplyRepo`, etc.) by domain.

The pattern follows `map_screen_controller.dart` which is already done correctly.

#### 4.2.3 Stage 2A file-by-file split plan

##### `ui/secondary/station_supply_screen.dart` (1344 → target ~300 + sub-files)

Extract:
- `StationSupplyController` — state, queries via `StationSupplyRepo`, publishes via `EventPublisher`.
- `StationSupplyListView`, `StationSupplyDetailSheet`, `StationSupplyEditDialog`, etc. — split by tab / sheet / dialog.
- Raw SQL fully moved out by Stage 1.

##### `ui/screens/match/match_screen.dart` (972 → target verify)

Audit first. If most lines are tab orchestration with 4 tab files already separate (`match_tab_requests`, `match_tab_negotiations`, `match_tab_supplies`, `match_tab_community`), the shell may be thin already. If a controller is needed, extract `MatchScreenController` for shared state across tabs.

The implementation spec must include the audit result and adjust scope. Acceptable outcomes: full split, light split, or "already thin, no further split needed" with line-count justification.

##### `ui/secondary/physical_handoff.dart` (778 → target ~300 + FSM)

Extract:
- `PhysicalHandoffController` — state machine: PENDING → CONFIRMING → COMPLETING → DONE / FAILED.
- Step views: `HandoffPrepView`, `HandoffConfirmView`, `HandoffSuccessView`, `HandoffFailureView`.
- Repository access via Stage 1 `NegotiationRepo`.

##### `ui/secondary/survival_mode_screen.dart` (775 → target ~300 minimum)

This is a debug page. Simplified split acceptable:
- `SurvivalModeController` for state.
- Debug log viewer as separate widget.
- Settings panel as separate widget.

This is the resolution to Open Question §10 item 4 — minimum viable split is acceptable because ROI is lower than other 2A targets.

#### 4.2.4 Stage 2B file-by-file split plan

##### `ui/secondary/medical_card_screen.dart` (1031 → target ~400 + sub-widgets)

Extract:
- `MedicalCardController` — form state, validation.
- Section widgets: `BasicInfoSection`, `MedicalConditionsSection`, `AllergiesSection`, `MedicationsSection`, `EmergencyContactSection`, `PrivacyFlagsSection`.
- Form is form — the goal is one section per file, not deep architectural changes.

##### `ui/screens/me/profile_screen.dart` (866 → target ~300 + sub-widgets)

Extract section widgets:
- `IdentitySection`, `MeshStatusSection` (already separate), `MedicalCardEntrySection`, `SettingsSection`, `DebugSection`.
- One file per section.

#### 4.2.5 Splitting completion criteria

For each split file:
- New files compile.
- Existing tests pass.
- Behavior unchanged (validated by smoke test on each affected UI screen).
- New top-level files under 500 lines each. Existing files may exceed temporarily for legitimate reasons (state machine, generated code), documented in a comment.

### 4.3 Stage 3: CI Enforcement

Estimated: ~0.5 day.

Goal: Extend `tool/check_layers.dart` with new rules and baseline to zero.

#### 4.3.1 New rules

Add to `_rules` const list in `tool/check_layers.dart`:

```dart
_Rule(
  name: 'ui-cannot-import-mesh',
  sourcePrefix: 'lib/ui/',
  forbiddenPrefix: 'lib/app/mesh/',
),
_Rule(
  name: 'ui-cannot-import-proto',
  sourcePrefix: 'lib/ui/',
  forbiddenPrefix: 'lib/app/proto/',
),
_Rule(
  name: 'ui-cannot-import-db',
  sourcePrefix: 'lib/ui/',
  forbiddenPrefix: 'lib/app/db/',
),
_Rule(
  name: 'platform-cannot-import-app',
  sourcePrefix: 'lib/platform/',
  forbiddenPrefix: 'lib/app/',
),
```

#### 4.3.2 Exception list mechanism

Add an `_exceptions` list to `check_layers.dart` to allow legitimate edge cases without disabling rules. Example shape:

```dart
const _exceptions = <_Exception>{
  _Exception(rule: 'ui-cannot-import-mesh', file: 'lib/ui/screens/map/widgets/map_view.dart', reason: 'flutter_map TileLayer types'),
};
```

Note: After Stage 1+2 complete, the expected `_exceptions` list is empty. Exceptions are documented escape hatches, not blanket waivers.

#### 4.3.3 CI integration

- After v0.2.5 ships, the baseline file must be empty (only comments).
- Run `dart run tool/check_layers.dart --strict` as a CI gate.
- Any new PR that introduces a violation must fail. No baseline grandfathering after v0.2.5.

### 4.4 Stage 4: Wire-Format Golden Tests

Estimated: ~1 day.

Goal: Lock down protocol behavior that tests currently leak through.

#### 4.4.1 EventType drift test (high priority)

Replace `test/proto/event_type_enum_test.dart:40-42` (the `valueOf(15) returns null` assertion) with:

```dart
test('Dart EventType constants must all have proto counterparts', () {
  final dartValues = <int>{
    EventType.resourceRegister, EventType.requestBroadcast,
    EventType.matchOffer, EventType.physicalHandshake,
    // ... all entries in EventType class
  };
  for (final v in dartValues) {
    expect(pb.EventType.valueOf(v), isNotNull,
      reason: 'EventType constant $v has no matching proto enum value. '
              'Sync protos/mesh_protocol.proto before adding new EventType constants.');
  }
});
```

This test will FIRE on current code due to the 15-18 gap. That is intentional. The test documents that the gap exists and must be fixed by v0.3 Envelope v2. Once v0.3 ships the new EventType layout, the test naturally goes green.

To avoid breaking CI during v0.2.5, mark this test as `@Skip('Resolved by v0.3 Envelope v2 reset')` with a tracking reference. The test exists in code but does not block CI. When v0.3 ships, the `@Skip` is removed.

#### 4.4.2 Envelope encode golden tests

Snapshot the current wire format for representative messages (one per EventType currently working: 0-14). These act as a baseline so v0.3 Envelope v2 can be diffed against the v0.2.5 baseline to confirm what changed.

Tests live in `test/proto/wire_format_golden_test.dart`. Each test:
- Constructs a `MeshEvent` with fixed inputs.
- Calls `writeToBuffer()`.
- Compares the hex output against a stored golden file.

Goldens are committed in `test/proto/goldens/`.

These tests are NOT meant to lock the format forever. They are meant to make protocol changes in v0.3 visible and reviewable.

### 4.5 Stage 5: Documentation

Estimated: ~0.5 day.

Goal: Capture the layer rules and architecture decisions in places future agents and humans will find them.

#### 4.5.1 `CLAUDE.md` updates

Add a new section: "Architecture Layer Rules". Content:

- 4 forbidden import rules (the new check_layers rules).
- Facade location: `app/controllers/event_publisher.dart`, `app/controllers/event_stream.dart`, `app/services/event_store.dart`, `app/services/event_decoder.dart`.
- "Do not add new singletons for v0.2.5 facades, repositories, or controllers. New dependencies are constructed at the app root and injected through constructors. UI obtains them with `context.read<T>()`."
- "Existing legacy singletons may be wrapped by new facades, but must not leak into UI or new public APIs."
- "UI must not directly call existing app-layer singleton entry points (`.instance`, `EventManager()`, `MeshEventHandler()`, `DatabaseHelper()`, etc.). Existing singletons are implementation details behind Provider-wired facades/controllers/services."
- "Do not let UI files exceed 500 lines if they touch facade. Use the Controller / View / Repository pattern. See `map_screen_controller.dart` for reference."

#### 4.5.2 ADR-001: Layering Rules

File: `docs/architecture/ADR-001-layering-rules.md`.

Content:
- Context: why the existing single-rule enforcement was insufficient.
- Decision: four-rule enforcement as defined in §4.3.
- Consequences: explicit list of what changes in PR review workflow.
- Status: Accepted on (date), reviewed by (people).

#### 4.5.3 ADR-002: Mesh-to-UI Contract

File: `docs/architecture/ADR-002-mesh-to-ui-contract.md`.

Content:
- Context: UI used to import mesh / proto / db directly.
- Decision: 4-facade pattern (`EventPublisher`, `EventStream`, `EventStore`, `EventDecoder`).
- Decision: new facades and repositories use constructor injection + root Provider wiring, not `.instance` singletons.
- Decision: UI no longer directly invokes legacy app-layer singleton entry points; legacy singletons may remain only behind injected dependencies.
- Consequences: every cross-layer interaction goes through one of these four. New facades require ADR amendment.
- Open questions: how this contract evolves under v0.3 Envelope v2.

#### 4.5.4 PR Review Checklist

File: `.github/pull_request_template.md` or `docs/PR_CHECKLIST.md`.

Content:

```
## Architecture
- [ ] No new imports from `lib/ui/` to `lib/app/mesh/`, `lib/app/proto/`, or `lib/app/db/`.
- [ ] No new imports from `lib/platform/` to `lib/app/`.
- [ ] `dart run tool/check_layers.dart` passes locally.
- [ ] No new file exceeds 800 lines without Controller / View / Repository split.
- [ ] No new `.instance` / factory-singleton entry point added for v0.2.5 facades, repositories, or controllers.
- [ ] New dependencies are wired at the app root and injected through constructors; UI uses `context.read<T>()`.
- [ ] No direct UI calls to legacy app-layer singleton entry points (`.instance`, `EventManager()`, `MeshEventHandler()`, `DatabaseHelper()`, `LocationService()`, `ChatService()`, etc.).

## Wire Format
- [ ] No raw `pb.X.fromBuffer(...)` outside `app/services/event_decoder.dart`.
- [ ] No new EventType constant added without corresponding proto enum value.
- [ ] Wire format golden tests still pass.

## Tests
- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] New behavior has test coverage.
```

## 5. Completion Criteria

v0.2.5 is complete when ALL of the following are green:

### 5.1 Mechanical checks

- `dart run tool/check_layers.dart --strict` passes. Baseline file contains only comments.
- `flutter analyze` passes.
- `flutter test` passes. No new failures introduced. Exactly one new `@Skip`-marked test is allowed: the EventType drift test, tracked to v0.3 Envelope v2 resolution.
- `grep -r "import 'package:ignirelay_app/app/mesh/" lib/ui/` returns empty.
- `grep -r "import 'package:ignirelay_app/app/proto/" lib/ui/` returns empty.
- `grep -r "import 'package:ignirelay_app/app/db/" lib/ui/` returns empty.
- `grep -r "import 'package:ignirelay_app/app/" lib/platform/` returns empty.
- `wc -l lib/ui/secondary/station_supply_screen.dart` reports under 500 lines (was 1344).
- `wc -l lib/ui/secondary/medical_card_screen.dart` reports under 500 lines (was 1031).
- Each god file in §2.4 (except `map_screen_controller.dart`) is under 500 lines OR has an explicit comment explaining why it exceeds.

### 5.2 Documentation checks

- `CLAUDE.md` contains "Architecture Layer Rules" section.
- `docs/architecture/ADR-001-layering-rules.md` exists.
- `docs/architecture/ADR-002-mesh-to-ui-contract.md` exists.
- PR checklist exists (location per Stage 5 §4.5.4).

### 5.3 Behavioral checks

- All existing smoke tests of UI behavior pass.
- Manual smoke test of each affected UI screen confirms identical behavior:
  - SOS alert in main shell
  - Hazard dialog publish
  - Match negotiation flow end-to-end
  - Station supply create / claim / quota reset
  - Medical card create / edit / save
  - Physical handoff full flow
  - Map screen pan / zoom / hazard / event display

If any behavioral regression is detected, v0.2.5 is NOT complete regardless of mechanical checks.

## 6. Explicit Out-of-Scope

To prevent scope creep, the following are explicitly NOT done in v0.2.5:

| Item | Reason | Owner |
|---|---|---|
| Protocol redesign (EventType enum, envelope format, TTL, priority) | Wire format work is v0.3 | v0.3 Envelope v2 |
| Splitting `event_manager.dart`, `mesh_event_handler.dart`, `ble_manager.dart` | v0.3 rewrites these; double work otherwise | v0.3 |
| Removing every internal legacy singleton implementation | v0.2.5 removes UI direct access to legacy singleton entry points and blocks new singleton debt, but it does not rewrite every existing internal singleton class in the app | v0.4 or later |
| `map_screen_controller.dart` split | Already organized | Never |
| `design_showcase_screen.dart` cleanup | Demo file, no boundary coupling | Never |
| New features | v0.2.5 is debt-only | v0.3 Stage 1 |
| Performance optimization | Recent perf work covers current targets | v0.3 dogfood feedback |
| iOS support hardening | Independent track | TBD |
| L10n (l10n) cleanup | Generated files, no boundary impact | Never |
| Test refactoring | Existing tests stay; new tests added | v0.2.5 |

## 7. Effort Estimate

| Stage | Estimate (agent full-time) |
|---|---|
| Stage 1: Protocol boundary facade + repository split + `app/mesh/` & `platform/` directory cleanup | ~3-4 days |
| Stage 2A: UI god file splits (critical path) | ~3-4 days |
| Stage 2B: UI god file splits (parallel-acceptable) | ~2-3 days |
| Stage 3: CI enforcement | ~0.5 day |
| Stage 4: Wire-format golden tests | ~1 day |
| Stage 5: Documentation | ~0.5 day |
| Total | ~10-13 days |

This estimate assumes:
- One agent working sequentially.
- Stages 3-5 can overlap with end of Stage 2.
- Stage 2B can overlap with Stage 2A end or with v0.3 Stage 0 if needed (see §4.2.1).
- No unexpected behavior regressions discovered mid-sprint.

Risk factors that could extend estimate:
- `match_screen.dart` split larger than expected if shell is not thin.
- Behavioral regressions surfaced during god-file splits (most common in physical_handoff FSM).
- Move of `mbtiles_loader` / `poi_query` / `geo_context_resolver` reveals additional dependencies not surfaced in audit.
- Existing repos (`negotiation_repo`, `medical_card_repo`) need larger extensions than expected.

If the work expands beyond ~15 days, stop and revisit scope rather than rushing the last 20%.

## 8. Agent Handoff Instruction

Use this when asking an agent to draft the implementation spec:

```text
Please draft the implementation spec for the v0.2.5 Technical Debt & Architecture Hardening Sprint. Do not modify production code yet.

Source: text/resqmesh_v0.2.5_tech_debt_architecture_hardening_brief_2026-05-13.md
Companion: text/resqmesh_v0.3_v0.5_protocol_roadmap_spec_brief_2026-05-13.md
Output spec location: docs/specs/v0_2_5_implementation_spec_2026-05-13.md

Important:
- v0.2.5 is debt-only. No new features. No behavior changes.
- Wire format is NOT redesigned in v0.2.5. EventType / proto mismatch is handled by v0.3 Envelope v2.
- God-file splits in v0.2.5 are UI-side only. Mesh-layer god files (event_manager, mesh_event_handler, ble_manager) are NOT split.
- Stage ordering: Stage 1 first (includes `app/mesh/` and `platform/` directory cleanup). Stage 2A on critical path. Stage 2B can overlap Stage 2A end or v0.3 Stage 0. Stages 3-5 can overlap end of Stage 2.
- Repository design: domain-specific repos, not one mega-EventStore. Extend existing `negotiation_repo.dart` and `medical_card_repo.dart`; create new `station_supply_repo.dart` and `profile_repo.dart`.
- Directory cleanup: move `mbtiles_loader.dart`, `poi_query.dart`, `geo_context_resolver.dart` out of `app/mesh/` before activating the `ui-cannot-import-mesh` CI rule. Move `native_ble_transport.dart` AND `transport_factory.dart` out of `platform/`.
- Dependency policy: newly added v0.2.5 facades/repos/controllers must NOT expose `.instance`, private singleton constructors, or factory-singleton constructors. Use constructor injection and root Provider wiring. Existing legacy singletons may be passed into these classes as dependencies, but must not leak into UI or new APIs.
- Legacy UI access policy: `lib/ui/` must not directly call existing app-layer singleton entry points after v0.2.5. Existing singleton classes may remain internally, but UI must receive them through Provider or through injected facades/controllers/services.

Stage outputs required for review:
- Stage 1: facade file definitions, UI callsite migration plan (file-by-file).
- Stage 2: per-god-file split layout (Controller / View / Repository decomposition).
- Stage 3: new check_layers.dart code, exception list mechanism.
- Stage 4: EventType drift test code (marked @Skip during v0.2.5), wire format golden test plan.
- Stage 5: CLAUDE.md update text, ADR-001 / ADR-002 content, PR checklist text.

Spec MUST also address:
- The exact API of EventPublisher, EventStream, EventStore, EventDecoder (method signatures, return types as plain Dart, not protobuf).
- The exact split of station_supply_screen.dart (1344 lines) into Controller / View / sub-widgets.
- A rollback plan for each stage in case of behavioral regression.
- Migration order for the 11 UI files affected by Stage 1: which file first, which last, why.
- Treatment of `transport_factory.dart` under the new `platform-cannot-import-app` rule.

Important:
- Splitting criteria (brief §3) is locked. Do not split files outside the criteria.
- Use the existing controller pattern (map_screen_controller.dart) as the reference.
- Do not introduce new singletons. In this brief, that specifically means no new `.instance` or factory-singleton entry points for v0.2.5 facades, repositories, or controllers.
- Do not modify generated files (lib/app/proto/*.pb*.dart, lib/l10n/generated/*).
- The `MeshEventHandler` `Stream<MeshDataReceived> events` API stays during v0.2.5. The new `EventStream` facade wraps it. v0.3 may change the underlying stream type.

Return the spec for review. Do not implement code until the spec is approved.
```

## 9. Review Checklist For Other Agents

When reviewing the v0.2.5 implementation spec, check:

### Layer rules
- Are all 4 new check_layers rules defined precisely (sourcePrefix, forbiddenPrefix)?
- Is the exception list mechanism explicit and minimal?
- Is the baseline policy clear (must be empty after v0.2.5)?

### Facade and repository design
- Do EventPublisher / EventStream / EventDecoder + per-domain repos cover ALL 38 UI callsites identified in §2.2.2?
- Is `EventStore` scope limited to `Event_Logs` only (not a god repository)?
- Is each non-event domain handled by its own repo (NegotiationRepo / StationSupplyRepo / MedicalCardRepo / ProfileRepo)?
- Do facade method signatures return plain Dart types, not protobuf?
- Is the migration order for 11 UI files documented?
- Is there a behavioral parity test plan for each migration?
- Does the spec catalogue which repos already exist vs. which are new, to avoid duplicate parallel repos?
- Do all newly added facades/repos/controllers use constructor injection instead of `.instance` / factory-singleton entry points?
- Is root Provider wiring specified for every new facade/repo/controller that UI consumes?
- Are legacy singletons wrapped as dependencies instead of being exposed to UI or new public APIs?
- Does the implementation spec include a mechanical grep gate proving `lib/ui/` no longer directly calls legacy app-layer singleton entry points?

### `app/mesh/` directory cleanup
- Are `mbtiles_loader.dart`, `poi_query.dart`, `geo_context_resolver.dart` moved out of `app/mesh/`?
- Do all UI imports of these files resolve to the new locations?
- After the move, do any non-mesh files remain in `app/mesh/`?

### God-file splits
- Is the Stage 2A vs 2B classification explicit per file?
- Does each god-file plan name explicit sub-files with line targets (using raw `wc -l`)?
- Is the split pattern consistent across files (Controller / View / Repository)?
- Are split files all under 500 lines, or is the exception justified?
- Is the smoke test plan covering each split file's UI behavior?

### Platform cleanup
- Is `native_ble_transport.dart` move target precise (new path)?
- Is `transport_factory.dart` also moved out of `platform/`?
- Does `main.dart` import the factory from its new location?
- After the move, does `grep -r "import 'package:ignirelay_app/app/" lib/platform/` return empty?
- Are tests covering the moved files updated?

### Wire-format golden tests
- Does the EventType drift test cite the exact regression it prevents?
- Is the @Skip marker tracked to v0.3 Envelope v2?
- Do wire format goldens cover all 15 currently-working EventTypes (0-14)?

### Documentation
- Does CLAUDE.md update cover all 4 new rules?
- Do ADR-001 and ADR-002 follow the standard ADR format (Context / Decision / Consequences / Status)?
- Does the PR checklist match the rules and is enforceable?

### Out of scope
- Does the spec explicitly NOT touch mesh-layer god files?
- Does the spec explicitly NOT change behavior?
- Does the spec explicitly NOT redesign protocol?

## 10. Resolved Decisions

All previously open questions are now resolved. Listed here for traceability.

| # | Question | Resolution | Reference |
|---|---|---|---|
| 1 | `transport_factory.dart` placement under new `platform-cannot-import-app` rule | Move to `app/mesh/`. No exception in `platform/`. | §4.1.5 |
| 2 | `survival_mode_screen.dart` split priority | Minimum viable split (extract Controller, leave debug log viewer inline). | §4.2.3 |
| 3 | Completion gate enforcement | v0.3 user-facing feature work is blocked until all v0.2.5 completion criteria are green. v0.3 Envelope spec / mesh-layer preparation may start after Stage 1 + Stage 2A are green, and may overlap Stage 2B if necessary. | §0, §6 |
| 4 | EventType drift test behavior | Option A. Mark new test as `@Skip('Resolved by v0.3 Envelope v2 reset')`. CI stays green during v0.2.5. The `@Skip` is removed in v0.3 once proto / Dart alignment ships. | §4.4.1 |
| 5 | `match_screen.dart` split scope | Audit first. Implementation spec must include the audit result. Acceptable outcomes: full split, light split, or "already thin" with line-count justification. | §4.2.3 |
| 6 | Stage 2B hard-requirement for v0.2.5 completion | Option A. Stage 2B is required for v0.2.5 to be marked complete. Stage 2B can overlap v0.3 Stage 0 if scope creep occurs, but must finish before v0.3 Stage 1 (user features) begins. This honors the "pay down all known debt before v0.3 features" principle. | §4.2.1 |

No further human product/architecture decisions are required before an agent drafts the implementation spec. The brief is locked for implementation-spec drafting, not for direct production-code changes.
