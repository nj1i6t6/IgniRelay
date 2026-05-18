import XCTest
import CryptoKit
@testable import Runner

/// v0.3 Stage 0c wave 3D — Swift-side consumer of the cross-platform wire
/// conformance corpus.
///
/// Reads the fixture committed at
/// `docs/specs/wire_conformance_v1.json` (the Dart generator at
/// `resqmesh_app/tool/generate_wire_conformance_v1.dart` is the SOLE
/// source of truth — Swift / Kotlin only consume) and asserts the Swift
/// implementation produces byte-identical output for every IBLT and
/// Bloom sample.
///
/// Coverage in this 3D landing:
///   ✓ corpus loads + metadata sanity
///   ✓ IBLT samples (insert / insert+remove / subtract) — byte-identical
///     to expected_bytes_hex / expected_diff_bytes_hex.
///   ✓ Bloom samples — Swift bloomMurmurHash + bit-vector build matches
///     expected_bytes_sha256_hex. ASCII-only inputs (corpus enforced).
///   ◯ Chunking samples — TODO. Swift does not yet have a Chunker port;
///     covered Dart-side by wire_conformance_corpus_test.dart determinism
///     gate (which re-runs Chunker.split against every sample). Wire
///     Swift consumer after the Swift Chunker port lands.
///   ◯ Envelope signature verification — TODO. Needs a Swift port of
///     CanonicalEncoderV2.buildSignatureInput. Covered Dart-side.
///
/// IMPORTANT: this XCTest has NOT been run on macOS as of the 3D
/// checkpoint commit; the Windows development host has no xcodebuild.
/// Verifier should run `xcodebuild test -workspace ios/Runner.xcworkspace
/// -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 15'`
/// before the 0d real-device gate. Any drift surfaces as a single failed
/// assertion pointing at the diverged sample name.
final class WireConformanceTests: XCTestCase {

    // MARK: - corpus loading

    /// Walks up from this source file to the monorepo root, then into
    /// docs/specs/. Avoids needing Xcode bundle resource setup.
    ///
    ///   ios/RunnerTests/WireConformanceTests.swift
    ///     -> ios/RunnerTests   (deletingLastPathComponent x1)
    ///     -> ios               (x2)
    ///     -> resqmesh_app      (x3)
    ///     -> <monorepo root>   (x4)
    ///     -> docs/specs/wire_conformance_v1.json
    private func loadCorpus() throws -> [String: Any] {
        let thisFile = URL(fileURLWithPath: #file)
        let monorepoRoot = thisFile
            .deletingLastPathComponent()    // RunnerTests
            .deletingLastPathComponent()    // ios
            .deletingLastPathComponent()    // resqmesh_app
            .deletingLastPathComponent()    // <root>
        let url = monorepoRoot
            .appendingPathComponent("docs")
            .appendingPathComponent("specs")
            .appendingPathComponent("wire_conformance_v1.json")
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "WireConformanceTests", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "corpus not a JSON object"])
        }
        return json
    }

    func testCorpusMetadata() throws {
        let corpus = try loadCorpus()
        XCTAssertEqual(corpus["corpus_revision"] as? String, "v0.3-stage0c-wave3d-1")
        XCTAssertEqual(corpus["spec_date"] as? String, "2026-05-13")
        XCTAssertNil(corpus["generated_at_iso"],
                     "corpus must be deterministic; live timestamp leaked in")
        XCTAssertNotNil(corpus["notes"] as? [String: Any])
    }

    func testCorpusCountThresholds() throws {
        let corpus = try loadCorpus()
        XCTAssertGreaterThanOrEqual((corpus["envelope_samples"] as? [Any])?.count ?? 0, 100)
        XCTAssertGreaterThanOrEqual((corpus["chunking_samples"] as? [Any])?.count ?? 0, 20)
        XCTAssertGreaterThanOrEqual((corpus["iblt_samples"] as? [Any])?.count ?? 0, 50)
        XCTAssertGreaterThanOrEqual((corpus["bloom_samples"] as? [Any])?.count ?? 0, 30)
        XCTAssertGreaterThanOrEqual((corpus["negative_cases"] as? [Any])?.count ?? 0, 10)
    }

    // MARK: - IBLT byte-parity

    func testIbltSamplesMatchSwift() throws {
        let corpus = try loadCorpus()
        guard let samples = corpus["iblt_samples"] as? [[String: Any]] else {
            XCTFail("iblt_samples missing"); return
        }
        var checked = 0
        for sample in samples {
            let name = (sample["name"] as? String) ?? "?"
            let kind = (sample["kind"] as? String) ?? "?"
            switch kind {
            case "iblt":
                let ops = sample["operations"] as? [[String: Any]] ?? []
                let iblt = buildIbltFromOps(ops)
                let expected = (sample["expected_bytes_hex"] as? String) ?? ""
                XCTAssertEqual(toHex(iblt.toBytes()), expected,
                               "IBLT sample \(name) diverged from Dart oracle")
            case "iblt_subtract":
                let aOps = sample["a_operations"] as? [[String: Any]] ?? []
                let bOps = sample["b_operations"] as? [[String: Any]] ?? []
                let a = buildIbltFromOps(aOps)
                let b = buildIbltFromOps(bOps)
                let diff = a.subtract(b)
                XCTAssertEqual(toHex(a.toBytes()),
                               (sample["expected_a_bytes_hex"] as? String) ?? "",
                               "IBLT \(name) A bytes diverged")
                XCTAssertEqual(toHex(b.toBytes()),
                               (sample["expected_b_bytes_hex"] as? String) ?? "",
                               "IBLT \(name) B bytes diverged")
                XCTAssertEqual(toHex(diff.toBytes()),
                               (sample["expected_diff_bytes_hex"] as? String) ?? "",
                               "IBLT \(name) diff bytes diverged")
            default:
                XCTFail("unknown IBLT sample kind: \(kind)")
            }
            checked += 1
        }
        XCTAssertGreaterThanOrEqual(checked, 50, "spec requires >= 50 IBLT samples")
    }

    private func buildIbltFromOps(_ ops: [[String: Any]]) -> IBLT {
        let iblt = IBLT()
        for op in ops {
            let opKind = (op["op"] as? String) ?? ""
            let gen = op["event_ids_generator"] as? [String: Any] ?? [:]
            let ids = asciiSeqIds(
                prefix: (gen["prefix"] as? String) ?? "",
                start: (gen["start"] as? Int) ?? 0,
                count: (gen["count"] as? Int) ?? 0,
                width: (gen["width"] as? Int) ?? 8
            )
            switch opKind {
            case "insert": for id in ids { iblt.insert(id) }
            case "remove": for id in ids { iblt.remove(id) }
            default: XCTFail("unknown IBLT op: \(opKind)")
            }
        }
        return iblt
    }

    // MARK: - Bloom byte-parity (sha256 sanity, ASCII inputs only)

    func testBloomSamplesMatchSwift() throws {
        let corpus = try loadCorpus()
        guard let samples = corpus["bloom_samples"] as? [[String: Any]] else {
            XCTFail("bloom_samples missing"); return
        }
        var checked = 0
        for sample in samples {
            let name = (sample["name"] as? String) ?? "?"
            // Corpus asserts inputs are ASCII; Swift bloomMurmurHash uses
            // `codeUnit & 0xFF`, equivalent to Kotlin oracle for ASCII.
            XCTAssertEqual(sample["ascii_only"] as? Bool, true,
                           "bloom sample \(name) missing ascii_only=true")
            let gen = sample["event_ids_generator"] as? [String: Any] ?? [:]
            let ids = asciiSeqIds(
                prefix: (gen["prefix"] as? String) ?? "",
                start: (gen["start"] as? Int) ?? 0,
                count: (gen["count"] as? Int) ?? 0,
                width: (gen["width"] as? Int) ?? 8
            )
            for id in ids {
                XCTAssertTrue(isAscii(id),
                              "bloom sample \(name): id \(id) is non-ASCII; corpus invariant broken")
            }
            let bytes = buildBloomV2(eventIds: ids)
            XCTAssertEqual(bytes.count,
                           (sample["expected_bytes_size"] as? Int) ?? -1,
                           "bloom sample \(name) byte length mismatch")
            let sha = sha256Hex(bytes)
            XCTAssertEqual(sha,
                           (sample["expected_bytes_sha256_hex"] as? String) ?? "",
                           "bloom sample \(name) sha256 diverged from Dart oracle")
            checked += 1
        }
        XCTAssertGreaterThanOrEqual(checked, 30, "spec requires >= 30 Bloom samples")
    }

    /// Inline Swift Bloom v2 builder. Mirrors Kotlin
    /// IgniRelayForegroundService.buildBitVectorBloom + Dart inline
    /// _buildBloomV2 in tool/generate_wire_conformance_v1.dart. Identical
    /// for ASCII inputs; corpus invariant enforces ASCII.
    private func buildBloomV2(eventIds: [String]) -> Data {
        var out = Data(count: 4 + 2048)
        out[0] = 0xFF; out[1] = 0xBF; out[2] = 0x02; out[3] = 0x00
        let totalBits = UInt32(2048 * 8)
        for id in eventIds {
            for seed in 0..<UInt32(7) {
                let h = BlePlugin.bloomMurmurHash(id, seed: seed)
                let idx = Int(h % totalBits)
                out[4 + (idx >> 3)] |= UInt8(1 << (idx & 7))
            }
        }
        return out
    }

    // MARK: - generators (mirror Dart ascii_seq_v1)

    private func asciiSeqIds(prefix: String, start: Int, count: Int, width: Int) -> [String] {
        var out: [String] = []
        out.reserveCapacity(count)
        for i in start..<(start + count) {
            let padded = String(format: "%0\(width)d", i)
            out.append("\(prefix)\(padded)")
        }
        return out
    }

    private func isAscii(_ s: String) -> Bool {
        for c in s.utf16 { if c > 0x7F { return false } }
        return true
    }

    // MARK: - helpers

    private func toHex(_ bytes: Data) -> String {
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
