# PR Review Checklist

## Architecture
- [ ] No new imports from `lib/ui/` to `lib/app/mesh/`, `lib/app/proto/`, or `lib/app/db/`.
- [ ] No new imports from `lib/platform/` to `lib/app/`.
- [ ] `dart run tool/check_layers.dart` passes locally.
- [ ] No new file exceeds 800 lines without Controller / View / Repository split.
- [ ] No new `.instance` / factory-singleton entry point added for v0.2.5 facades, repositories, or controllers.
- [ ] New dependencies are wired at the app root and injected through constructors.
- [ ] UI code accesses facades via `context.read<T>()`, not `.instance`.
- [ ] UI code does not directly call legacy app-layer singleton entry points (`.instance`, `EventManager()`, `MeshEventHandler()`, `DatabaseHelper()`, `LocationService()`, `ChatService()`, etc.).

## Wire Format
- [ ] No raw `pb.X.fromBuffer(...)` outside `app/services/event_decoder.dart`.
- [ ] No new EventType constant added without corresponding proto enum value.
- [ ] Wire format golden tests still pass.
- [ ] No production UI uses `EventStream.rawEvents`. It is restricted to the survival-mode debug feature (`survival_mode_screen.dart` + `survival_mode_controller.dart`).

## Tests
- [ ] `flutter analyze` introduces no new issues beyond the accepted baseline (currently 7 info-level `use_build_context_synchronously` findings in pre-existing files). No new errors or warnings.
- [ ] `flutter test` passes.
- [ ] New behavior has test coverage.
