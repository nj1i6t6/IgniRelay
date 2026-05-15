# 烽傳 IgniRelay — resqmesh_app

Flutter app for the IgniRelay disaster-mesh project. Paths below are relative to
this directory (`resqmesh_app/`).

## Architecture Layer Rules

### Forbidden Import Rules
1. `ui-cannot-import-platform`: `lib/ui/**` must NOT import `lib/platform/**`
2. `app-cannot-import-ui`: `lib/app/**` must NOT import `lib/ui/**`
3. `ui-cannot-import-mesh`: `lib/ui/**` must NOT import `lib/app/mesh/**`
4. `ui-cannot-import-proto`: `lib/ui/**` must NOT import `lib/app/proto/**`
5. `ui-cannot-import-db`: `lib/ui/**` must NOT import `lib/app/db/**`
6. `platform-cannot-import-app`: `lib/platform/**` must NOT import `lib/app/**`

Enforced by: `dart run tool/check_layers.dart --strict`

### Facade Access Pattern
All v0.2.5 facades/repos/controllers are constructed via `MultiProvider` at the root (`main.dart`). UI accesses them via `context.read<T>()`. App-layer controllers/services receive them through constructors. Newly added v0.2.5 code must not use `.instance`.

- UI: `context.read<EventPublisher>()`  (NEVER `EventPublisher.instance`)
- App layer: constructor-injected `EventPublisher` (NEVER `EventPublisher.instance`)

### Facade Locations
- `app/controllers/event_publisher.dart` - wraps all `EventManager().publish*()` calls
- `app/controllers/event_stream.dart` - wraps `MeshEventHandler().events`, exposes typed streams
- `app/services/event_decoder.dart` - wraps all `pb.X.fromBuffer()` calls, returns plain Dart
- `app/services/event_store.dart` - wraps `Event_Logs` table queries
- `app/services/negotiation_repo.dart` - wraps `Match_Negotiations` queries (extended)
- `app/services/station_supply_repo.dart` - wraps `Station_Quotas` queries
- `app/services/profile_repo.dart` - wraps profile and debug log queries

### Rules
- Do NOT add new `.instance` / factory-singleton entry points for v0.2.5 facades, repositories, or controllers.
- New dependencies are wired at the app root and injected through constructors. Existing legacy singletons may be wrapped as dependencies, but must not leak into UI or new public APIs.
- UI must not directly call legacy app-layer singleton entry points (`.instance`, `EventManager()`, `MeshEventHandler()`, `DatabaseHelper()`, `LocationService()`, `ChatService()`, etc.).
- Do NOT let UI files exceed 500 lines if they touch facade. Use Controller / View / Repository pattern.
- Do NOT use `EventStream.rawEvents` in production UI. It is restricted to `survival_mode_screen.dart` (debug page). Use typed streams (`sosAlerts`, `matchUpdates`, `hazardEvents`, `supplyChanges`) instead.
- Reference pattern: `ui/screens/map/map_screen_controller.dart`
