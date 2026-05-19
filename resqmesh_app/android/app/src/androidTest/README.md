# Android instrumentation tests

This directory hosts on-device instrumentation tests for the Kotlin / native
half of the v0.3 transport stack.

## Running

You need an ADB-connected device or emulator with API ≥ 26 and the app's
permissions allowed once.

```bash
cd resqmesh_app
./gradlew :app:connectedDebugAndroidTest
```

Results land in
`android/app/build/reports/androidTests/connected/<device>/index.html`.

## What runs here

- `WireConformanceInstrumentationTest` — cross-platform wire-format parity
  consumer. Loads `<repo>/docs/specs/wire_conformance_v1.json` (bundled
  into the test APK via `sourceSets.androidTest.assets.srcDir` in
  `android/app/build.gradle.kts`) and asserts Kotlin `Chunker.kt` /
  `IBLT.kt` / inline Bloom v2 builder produce byte-identical output to the
  Dart oracle (`resqmesh_app/tool/generate_wire_conformance_v1.dart`).

  Mirrors `ios/RunnerTests/WireConformanceTests.swift` and
  `test/conformance/wire_conformance_corpus_test.dart` — same corpus,
  three independent consumers.

## What does NOT run here

- BLE behavior (scan / advertise / GATT) — needs two devices and physical
  RF, lives in the 0d real-device gate (manually driven via dev-mode trace
  screen for wave 3F).
- Anything that touches CoreBluetooth — iOS only, see
  `ios/RunnerTests/`.

## Adding a new consumer test

Each consumer test should:

1. Load the corpus via `InstrumentationRegistry.getInstrumentation()
   .context.assets.open("wire_conformance_v1.json")`.
2. Mirror the deterministic generators (`ascii_seq_v1`,
   `lcg_byte_pattern_v1`) inline rather than depending on production code
   for them — the corpus IS the contract.
3. Compare byte-for-byte (`expected_*_hex` / `expected_*_sha256_hex`)
   against the Dart oracle. Asymmetric tests (e.g., behavior-only) belong
   in the unit-test suite instead.
