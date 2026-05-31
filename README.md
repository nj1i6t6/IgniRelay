<div align="center">

# IgniRelay · 烽傳

**Offline BLE-Mesh Emergency Response System**

**English** · [繁體中文](README.zh-Hant.md)

[![CI](https://github.com/nj1i6t6/IgniRelay/actions/workflows/ci.yml/badge.svg)](https://github.com/nj1i6t6/IgniRelay/actions/workflows/ci.yml)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey.svg)](#platform-support)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B.svg?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%E2%89%A53.2-0175C2.svg?logo=dart)](https://dart.dev)
[![Status](https://img.shields.io/badge/status-active%20development-orange.svg)](#project-status)

When cell towers fall and the internet goes dark, phones still relay messages, SOS calls and supply matches to each other — hop by hop.

</div>

---

> **TL;DR** — IgniRelay is an offline-first, event-sourced disaster-response mobile app.
> When cellular and internet are down, nearby phones form a **Bluetooth-LE mesh** that signs,
> stores, relays and replays emergency events (SOS / hazards / supply matching / geofenced chat)
> across devices — with **no servers, no internet, no accounts**. Built with Flutter + native BLE
> (Android Nordic BLE, iOS CoreBluetooth), backed by a SQLite event log + projection tables,
> Ed25519 signatures and a Hybrid Logical Clock.

## What this is

The heart of IgniRelay is **not the UI**. It is the problem of *"how, with no network, do you spread
events safely between phones and persist them locally as queryable state?"*

It packs the following into a single mobile product:

- 📍 **Offline maps & local POI lookup** — bundled Taiwan vector maps; locate yourself and see hazard markers even fully offline.
- 📡 **BLE-mesh broadcast / GATT sync / store-and-forward relay** — every phone is a node; messages propagate hop by hop.
- 🆘 **SOS / supply / hazard events** — each one Ed25519-signed, persisted, projected and replayable.
- 🤝 **Two-way supply ↔ demand matching** — negotiation state machine, navigation, physical-handoff handshake.
- 💬 **Geofenced chat rooms** — auto-join by country / county / township / village.
- 🩺 **Medical card & Health Connect import** — carry critical medical info into an SOS.

> Treating this as "just a Flutter app" badly underestimates it. More precisely: the UI is only the
> outermost shell — **the SQLite projection is the core state surface, Ed25519 + HLC are the
> consistency and trust foundation, and the native BLE bridge is what makes the whole product
> possible at all.**

## Why it is designed this way

A disaster scene assumes **no network, no server, and no trust in unknown nodes**. So the entire
backbone is event-driven and offline-first:

```
Create event locally
  → Sign with Ed25519
    → Write to Event_Logs (raw event-sourcing store)
      → Project into business tables (Materials_State / Requests_State / Hazards_State …)
        → Enqueue into the BLE-mesh send queue (priority triage)
          → Nearby devices receive over GATT / advertising
            → Verify sig · dedup · HLC merge · geofence routing decision
              → Persist again + project
                → UI re-queries the DB on a stream refresh signal and shows the latest state
```

The UI **never renders directly from raw protobuf events** — it queries projection tables. The event
log keeps the raw mesh events for provenance and as a second line of dedup defense.

## Platform support

| Platform | Requirements | Mesh role |
|---|---|---|
| **Android** | minSdk 26 / targetSdk 35 / compileSdk 36 | Nordic BLE central + foreground GATT server |
| **iOS** | iOS 13+, CocoaPods | CoreBluetooth central / peripheral (background BLE) |

> ⚠️ BLE is **not optional here — it is the core feature**. A physical device with Bluetooth LE is
> required; emulators cannot validate mesh behavior.

## Tech stack

| Area | Used |
|---|---|
| App framework | Flutter 3.x / Dart ≥ 3.2 |
| State management | `provider` + singleton services + SQLite projection + event streams + local `ChangeNotifier` |
| Local storage | `sqflite` (schema v8, event log + projection tables), `flutter_secure_storage`, `shared_preferences` |
| Crypto / identity | Ed25519 (`cryptography`), `crypto`; keys in secure storage, identity levels 0–3 |
| Consistency / time | Hybrid Logical Clock (HLC); release builds inject `BUILD_TIMESTAMP` as a drift-protection baseline |
| Transport | Native BLE (Android Nordic BLE / iOS CoreBluetooth) over MethodChannel / EventChannel |
| Wire format | Protocol Buffers (`protos/mesh_protocol.proto`) |
| Maps | Offline MBTiles vector maps (`flutter_map` + `vector_map_tiles`), native `sqlite3` |
| Localization | Traditional Chinese / English (`app_zh.arb` / `app_en.arb`) |

## Project structure (monorepo)

The repo root is the governance entrypoint; the Flutter app lives in `resqmesh_app/`.

```text
.
├── CLAUDE.md              # Architecture layer rules (governance entrypoint)
├── LICENSE                # GNU AGPL-3.0
├── SECURITY.md            # Security policy / vulnerability reporting
├── README.md              # English (shown by default on GitHub)
├── README.zh-Hant.md      # Traditional Chinese
└── resqmesh_app/          # Flutter app
    ├── lib/
    │   ├── main.dart      # Staged startup sequence
    │   ├── app/           # application / services / mesh / crypto / db / proto …
    │   ├── platform/      # native bridge (MeshTransport abstraction)
    │   ├── ui/            # screens / widgets (four-tab shell)
    │   └── l10n/          # localization strings
    ├── android/           # Kotlin: Nordic BLE, foreground GATT service
    ├── ios/               # Swift: CoreBluetooth plugin
    ├── assets/            # offline maps, POI, village boundaries, map styles
    ├── protos/            # mesh_protocol.proto
    ├── test/              # unit / sqflite-ffi / integration tests
    └── tool/              # check_layers.dart (import-boundary checker)
```

### Architecture layers

The code keeps a clear four-layer separation, with import boundaries enforced by tooling:

1. **UI layer** `lib/ui/**` — screens, widgets, controller binding.
2. **Application / Service layer** `lib/app/services/**`, `lib/app/controllers/**` — negotiation state machine, queries, flow control.
3. **Communication / Mesh layer** `lib/app/mesh/**`, `lib/platform/**` — signing, send/receive, verification, routing, persistence.
4. **Native layer** `android/`, `ios/` — MethodChannel / EventChannel, BLE central / peripheral.

> The full layer rules (forbidden imports, facade access pattern, 500-line cap, etc.) live in
> [`CLAUDE.md`](CLAUDE.md) and are enforced by `dart run tool/check_layers.dart --strict`.

## Development requirements

- Flutter 3.x, Dart ≥ 3.2.0
- Android Studio Ladybug+, Android SDK (minSdk 26 / targetSdk 35 / compileSdk 36)
- Xcode 15+ (iOS)

## Quick start

```bash
cd resqmesh_app

# Install dependencies
flutter pub get

# Run on a connected physical device (BLE required)
flutter run
```

### iOS extra step

```bash
cd resqmesh_app/ios
pod install   # requires Flutter/Generated.xcconfig to exist first
```

### Android release example

HLC drift protection needs a build timestamp injected into release builds:

```bash
flutter build apk --release --dart-define=BUILD_TIMESTAMP=1777334400000
```

> Without `android/key.properties`, release builds fall back to debug signing.

## Testing & quality checks

```bash
cd resqmesh_app

# All tests
flutter test

# Scoped tests
flutter test test/mesh/
flutter test test/event/
flutter test test/services/

# Architecture import-boundary check
dart run tool/check_layers.dart --strict
```

Tests fall into three tiers: pure Dart, `sqflite_ffi` in-memory DB, and integration tests that need
geodata or a real device. See `resqmesh_app/test/TEST_INDEX.md` for the overview.

## Deeper documentation

This README is the entrypoint. For the **full technical anatomy** (startup sequence, data tables,
the mesh receive pipeline, routing strategy, native integration, known gaps & risks, and a suggested
reading order), see:

📖 **[`resqmesh_app/README.md`](resqmesh_app/README.md)**

## Project status

`pubspec.yaml` version `0.2.5+31`, **active development**. Some protocol events (e.g.
`QUARANTINE_VOTE`, `FIRE_ALARM_RF`) are currently reserved / no-op on the receive side, and the
medical summary is not yet wired into the SOS wire payload. When reading the proto, do not assume
every message is fully connected to the UI — see "Known gaps & risks" in the technical README.

## Security

This project processes untrusted input from unknown nearby devices and contains signing and crypto
logic. If you find a security issue, please **report it privately** as described in
[`SECURITY.md`](SECURITY.md) — do not open a public issue.

## License

This project is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)** — full text
in [`LICENSE`](LICENSE).

In plain terms, for users:

- ✅ You **may** freely read, study, modify, self-host and use this software.
- ⚠️ But if you **distribute a modified version, or offer it (including a modified version) as a
  network service**, you **must release your complete corresponding source code under the same
  AGPL-3.0 license** (including your modifications).
- 🚫 This means the project **cannot be quietly folded into a closed-source / commercial product**
  without also being open-sourced — which is exactly the point of the AGPL.

> **Want closed-source / commercial use?** Copyright remains with the author. If you need a
> commercial license not bound by the AGPL copyleft, contact the author to discuss
> **commercial (dual) licensing**.

```
Copyright (C) 2026 IgniRelay (https://github.com/nj1i6t6/IgniRelay)

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU Affero General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version. This program is distributed WITHOUT ANY WARRANTY. See the GNU
Affero General Public License for more details.
```

### Third-party assets & attribution

The project's code license (AGPL-3.0) **does not cover** the bundled third-party data and libraries.
When using / redistributing, you must also comply with their respective terms, including but not
limited to:

- **Offline map data (`assets/maps/*.mbtiles`)** — largely derived from **OpenStreetMap**, governed
  by the **ODbL**; you must keep the attribution "© OpenStreetMap contributors". Vector styles /
  schema may additionally come from OpenMapTiles.
- **Village / POI and other geodata** — under the license of their original source (e.g. government
  open-data terms).
- **Flutter / Dart packages, the Nordic BLE Library, native dependencies** — under their respective
  open-source licenses.

> If you fork and redistribute this project, make sure you have the right to redistribute the bundled
> map / geodata and that you keep the required attributions.
