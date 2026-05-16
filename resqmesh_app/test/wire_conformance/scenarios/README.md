# Wire Conformance Scenarios (v0.3 Stage 0c)

YAML inputs for `tool/generate_wire_conformance_v1.dart`.

Spec: docs/specs/envelope_v2_spec_2026-05-13.md §17 +
docs/specs/native_transport_v1_2026-05-13.md §11.

The generator script consumes these YAML files and emits a single
`docs/specs/wire_conformance_v1.json` that is the cross-platform conformance
corpus. Dart, Kotlin, and Swift implementations all consume the JSON; only the
Dart generator regenerates it. Spec mandate: **the Dart side is the SOLE source
of truth for new test vectors** (envelope_v2_spec §17.5).

Each YAML file describes one test scenario. Required coverage (envelope slice):

- ≥ 100 envelope encode/decode samples covering every EventType, every
  Priority, both single-chunk and multi-chunk cases.
- ≥ 5 SOS_RED samples at sizes around the 240-byte cap (≈150B, 190B, 220B,
  235B, exactly 240B).
- ≥ 5 ALERT samples that REQUIRE chunking.
- ≥ 1 RESOURCE sample at exactly the 400-byte cap.
- ≥ 1 NORMAL sample at exactly `MAX_ENVELOPE_BYTES = 2048`.
- ≥ 5 worked Ed25519 signature samples (per §8.3).

Transport slice (added in 0b):

- ≥ 50 IBLT bucket-state samples.
- ≥ 30 Bloom bit-vector samples (with magic header).
- ≥ 20 chunking samples.
- ≥ 10 negative cases.

Until the generator + scenarios land in full, this directory holds the
seed scenario `sos_red_minimal.yaml` so the runner has something to chew on.
