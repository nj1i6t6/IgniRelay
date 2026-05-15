# ADR-002: Mesh-to-UI Contract

Date: 2026-05-13
Status: Accepted

## Context
UI files previously imported `EventManager`, `MeshEventHandler`, `DatabaseHelper`, and protobuf types directly. This created a leaky abstraction where protocol changes required UI changes.

## Decision
Four facade types mediate all mesh-to-UI communication:
1. **EventPublisher** - outbound: UI publishes events through this facade
2. **EventStream** - inbound: UI subscribes to typed event streams through this facade
3. **EventDecoder** - payload decoding: all proto decode lives here, returns plain Dart
4. **EventStore** + domain repos - data access: all SQL queries go through domain-specific repositories

All facades are constructed via `MultiProvider` at the app root. UI must access them through `context.read<T>()` - never through `.instance` directly. App-layer code receives them through constructors. v0.2.5 facades/repos/controllers must not expose `.instance` at all.

`EventStream.rawEvents` is restricted to debug screens only (`survival_mode_screen.dart`). Production UI must use typed streams: `sosAlerts`, `matchUpdates`, `hazardEvents`, `supplyChanges`.

New facades require an ADR amendment.

## Consequences
- UI never sees protobuf types, raw SQL, `EventManager`/`MeshEventHandler`, or raw `MeshDataReceived` directly.
- Constructor injection + root Provider wiring makes facade dependencies explicit and testable.
- v0.3 Envelope v2 can rewrite mesh internals without touching UI.
- Domain-specific repos (NegotiationRepo, StationSupplyRepo, MedicalCardRepo, ProfileRepo) prevent a god-EventStore anti-pattern.

## Open Questions
- How does this contract evolve under v0.3 Envelope v2? (Answer: EventStream's underlying stream type may change; typed streams stay stable.)
- Does EventPublisher survive v0.3? (Answer: likely yes, method signatures may evolve but facade pattern remains.)

## Status
Accepted on 2026-05-13.
