# Security Policy

IgniRelay is safety-critical software: it relays emergency events (SOS, hazards, supply matching)
between phones during disasters. It processes **untrusted input from unknown nearby devices** and
contains cryptographic signing/verification and trust logic. Security issues here can have
real-world consequences, so we take them seriously.

> 中文：本專案會處理來自陌生裝置的未驗證輸入，並含簽章與信任邏輯。發現安全問題請依下方方式
> **私下回報**，請勿直接開公開 issue。

## Reporting a vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Report privately through either channel:

1. **GitHub Private Vulnerability Reporting** (preferred) — go to the repository's
   **Security → Report a vulnerability** tab and submit a private advisory.
2. **Email** — `simon@bochengsu.com` with the subject line `[IgniRelay Security]`.

Please include, as far as you can:

- A description of the issue and its potential impact.
- Steps to reproduce, or a proof of concept.
- Affected component(s) — e.g. the receive pipeline, signature verification, routing, native BLE
  bridge, local storage.
- Affected version / commit and platform (Android / iOS).

We aim to acknowledge a report within **7 days** and to keep you updated on remediation. Please give
us a reasonable window to fix the issue before any public disclosure (coordinated disclosure). With
your consent, we are happy to credit you once a fix ships.

## Scope & threat model

This project assumes there is **no server, no internet, and no trust in unknown nodes**. Areas where
security reports are especially valuable:

- **Receive pipeline** (`lib/app/mesh/**`): malformed / oversized packet handling, deserialization
  of untrusted protobuf, dedup bypass, denial-of-service via flooding.
- **Signatures & identity** (`lib/app/crypto/**`): Ed25519 signing/verification correctness,
  signature bypass, event forgery, replay, identity / trust-level escalation.
- **Routing** (`lib/app/mesh/mesh_router.dart`): geofence/TTL rules being abused to suppress or
  over-propagate events (e.g. forging or hiding an SOS).
- **Local storage** (`lib/app/db/**`, `flutter_secure_storage`): key handling, data at rest.
- **Native BLE bridges** (`android/`, `ios/`): handling of untrusted GATT writes and advertising data.

## Supported versions

The project is in **active development** (currently `0.2.x`). Security fixes target the latest commit
on the default branch (`main`). There is no long-term-support branch yet.

| Version | Supported |
|---|---|
| latest `main` | ✅ |
| older tags / branches | ❌ |

## A note on disclosure

Because IgniRelay is meant to be used when networks are down, there is **no server-side hotfix path**
— a fix must reach users as an app update. Coordinated, responsible disclosure therefore matters even
more than usual. Thank you for helping keep people who rely on it safe.
