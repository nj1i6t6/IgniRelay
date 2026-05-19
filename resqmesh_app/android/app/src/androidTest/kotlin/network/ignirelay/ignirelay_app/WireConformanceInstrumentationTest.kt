package network.ignirelay.ignirelay_app

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith
import java.security.MessageDigest

/**
 * v0.3 Stage 0c wave 3F — Kotlin-side consumer of the cross-platform wire
 * conformance corpus.
 *
 * Mirrors `ios/RunnerTests/WireConformanceTests.swift` and
 * `test/conformance/wire_conformance_corpus_test.dart`. The Dart generator
 * at `resqmesh_app/tool/generate_wire_conformance_v1.dart` is the SOLE
 * source of truth — Kotlin / Swift only consume.
 *
 * The corpus JSON is bundled into the androidTest APK via the
 * `assets.srcDir(rootProject.file("../../docs/specs"))` line in
 * `android/app/build.gradle.kts`. It is loaded here via
 * `InstrumentationRegistry.getInstrumentation().context.assets.open`.
 *
 * Coverage in this 3F landing:
 *   ✓ corpus metadata + count thresholds (spec §11.7)
 *   ✓ IBLT samples (insert / insert+remove / subtract) — byte-identical
 *     to expected_bytes_hex / expected_diff_bytes_hex via IBLT.kt.
 *   ✓ Bloom samples — Kotlin inline buildBitVectorBloom matches
 *     expected_bytes_sha256_hex. ASCII-only enforced.
 *   ✓ Chunking samples — Chunker.split produces the expected chunk count
 *     and first/last chunk SHA256 for every sample.
 *
 * IMPORTANT: this test runs ON DEVICE / EMULATOR via:
 *   ./gradlew :app:connectedDebugAndroidTest
 * It is NOT run by `flutter test`. The Windows host has no Android device
 * connected at wave 3F time — verifier must run on an actual ADB-connected
 * device (the same one used for the 0d gate) before claiming Stage 0c green.
 */
@RunWith(AndroidJUnit4::class)
class WireConformanceInstrumentationTest {

    // ── corpus loading ────────────────────────────────────────────────

    private fun loadCorpus(): JSONObject {
        val ctx = InstrumentationRegistry.getInstrumentation().context
        val text = ctx.assets.open("wire_conformance_v1.json")
            .bufferedReader(Charsets.UTF_8)
            .use { it.readText() }
        return JSONObject(text)
    }

    @Test
    fun corpusMetadata() {
        val corpus = loadCorpus()
        assertEquals("v0.3-stage0c-wave3d-1", corpus.getString("corpus_revision"))
        assertEquals("2026-05-13", corpus.getString("spec_date"))
        assertTrue(
            "corpus must be deterministic; live timestamp leaked in",
            !corpus.has("generated_at_iso")
        )
        assertNotNull(corpus.getJSONObject("notes"))
    }

    @Test
    fun corpusCountThresholds() {
        val corpus = loadCorpus()
        assertTrue(
            "envelope_samples >= 100",
            corpus.getJSONArray("envelope_samples").length() >= 100
        )
        assertTrue(
            "chunking_samples >= 20",
            corpus.getJSONArray("chunking_samples").length() >= 20
        )
        assertTrue(
            "iblt_samples >= 50",
            corpus.getJSONArray("iblt_samples").length() >= 50
        )
        assertTrue(
            "bloom_samples >= 30",
            corpus.getJSONArray("bloom_samples").length() >= 30
        )
        assertTrue(
            "negative_cases >= 10",
            corpus.getJSONArray("negative_cases").length() >= 10
        )
    }

    // ── IBLT byte-parity ──────────────────────────────────────────────

    @Test
    fun ibltSamplesMatchKotlin() {
        val corpus = loadCorpus()
        val samples = corpus.getJSONArray("iblt_samples")
        var checked = 0
        for (i in 0 until samples.length()) {
            val sample = samples.getJSONObject(i)
            val name = sample.optString("name", "?")
            when (val kind = sample.optString("kind", "?")) {
                "iblt" -> {
                    val ops = sample.getJSONArray("operations")
                    val iblt = buildIbltFromOps(ops)
                    val expected = sample.optString("expected_bytes_hex", "")
                    assertEquals(
                        "IBLT sample $name diverged from Dart oracle",
                        expected,
                        toHex(iblt.toBytes())
                    )
                }
                "iblt_subtract" -> {
                    val aOps = sample.getJSONArray("a_operations")
                    val bOps = sample.getJSONArray("b_operations")
                    val a = buildIbltFromOps(aOps)
                    val b = buildIbltFromOps(bOps)
                    val diff = a.subtract(b)
                    assertEquals(
                        "IBLT $name A bytes diverged",
                        sample.optString("expected_a_bytes_hex", ""),
                        toHex(a.toBytes())
                    )
                    assertEquals(
                        "IBLT $name B bytes diverged",
                        sample.optString("expected_b_bytes_hex", ""),
                        toHex(b.toBytes())
                    )
                    assertEquals(
                        "IBLT $name diff bytes diverged",
                        sample.optString("expected_diff_bytes_hex", ""),
                        toHex(diff.toBytes())
                    )
                }
                else -> fail("unknown IBLT sample kind: $kind")
            }
            checked += 1
        }
        assertTrue("spec requires >= 50 IBLT samples", checked >= 50)
    }

    private fun buildIbltFromOps(ops: JSONArray): IBLT {
        val iblt = IBLT()
        for (i in 0 until ops.length()) {
            val op = ops.getJSONObject(i)
            val opKind = op.optString("op", "")
            val gen = op.getJSONObject("event_ids_generator")
            val ids = asciiSeqIds(
                prefix = gen.optString("prefix", ""),
                start = gen.optInt("start", 0),
                count = gen.optInt("count", 0),
                width = gen.optInt("width", 8)
            )
            when (opKind) {
                "insert" -> ids.forEach { iblt.insert(it) }
                "remove" -> ids.forEach { iblt.remove(it) }
                else -> fail("unknown IBLT op: $opKind")
            }
        }
        return iblt
    }

    // ── Bloom byte-parity (sha256 sanity, ASCII inputs only) ──────────

    @Test
    fun bloomSamplesMatchKotlin() {
        val corpus = loadCorpus()
        val samples = corpus.getJSONArray("bloom_samples")
        var checked = 0
        for (i in 0 until samples.length()) {
            val sample = samples.getJSONObject(i)
            val name = sample.optString("name", "?")
            assertEquals(
                "bloom sample $name missing ascii_only=true",
                true,
                sample.optBoolean("ascii_only", false)
            )
            val gen = sample.getJSONObject("event_ids_generator")
            val ids = asciiSeqIds(
                prefix = gen.optString("prefix", ""),
                start = gen.optInt("start", 0),
                count = gen.optInt("count", 0),
                width = gen.optInt("width", 8)
            )
            for (id in ids) {
                assertTrue(
                    "bloom sample $name: id $id is non-ASCII; corpus invariant broken",
                    isAscii(id)
                )
            }
            val bytes = buildBloomV2(ids)
            assertEquals(
                "bloom sample $name byte length mismatch",
                sample.getInt("expected_bytes_size"),
                bytes.size
            )
            val sha = sha256Hex(bytes)
            assertEquals(
                "bloom sample $name sha256 diverged from Dart oracle",
                sample.optString("expected_bytes_sha256_hex", ""),
                sha
            )
            checked += 1
        }
        assertTrue("spec requires >= 30 Bloom samples", checked >= 30)
    }

    /**
     * Inline Kotlin Bloom v2 builder. Mirrors
     * `IgniRelayForegroundService.buildBitVectorBloom` (which is `private`,
     * so we re-implement here rather than open a test-only window into the
     * service class). Identical for ASCII inputs; corpus invariant enforces
     * ASCII. Parameters MUST match `IgniRelayForegroundService.BLOOM_*`
     * constants: 2048 bytes (16384 bits), 7 hash functions, magic header.
     */
    private fun buildBloomV2(eventIds: List<String>): ByteArray {
        val out = ByteArray(4 + 2048)
        out[0] = 0xFF.toByte()
        out[1] = 0xBF.toByte()
        out[2] = 0x02
        out[3] = 0x00
        val totalBits = 2048L * 8L
        for (id in eventIds) {
            for (seed in 0 until 7) {
                val h = bloomMurmurHash(id, seed)
                val idx = ((h.toLong() and 0xFFFFFFFFL) % totalBits).toInt()
                out[4 + (idx shr 3)] =
                    (out[4 + (idx shr 3)].toInt() or (1 shl (idx and 7))).toByte()
            }
        }
        return out
    }

    /** Mirror of `IgniRelayForegroundService.murmurHash` (also `private`). */
    private fun bloomMurmurHash(s: String, seed: Int): Int {
        var h = seed
        for (c in s.toCharArray()) {
            var k = c.code
            k = (k.toLong() * 0xcc9e2d51L and 0xFFFFFFFFL).toInt()
            k = (k shl 15) or (k ushr 17)
            k = (k.toLong() * 0x1b873593L and 0xFFFFFFFFL).toInt()
            h = h xor k
            h = (h shl 13) or (h ushr 19)
            h = (h.toLong() * 5L + 0xe6546b64L and 0xFFFFFFFFL).toInt()
        }
        h = h xor s.length
        h = h xor (h ushr 16)
        h = (h.toLong() * 0x85ebca6bL and 0xFFFFFFFFL).toInt()
        h = h xor (h ushr 13)
        h = (h.toLong() * 0xc2b2ae35L and 0xFFFFFFFFL).toInt()
        h = h xor (h ushr 16)
        return h
    }

    // ── Chunking byte-parity ──────────────────────────────────────────

    @Test
    fun chunkingSamplesMatchKotlin() {
        val corpus = loadCorpus()
        val samples = corpus.getJSONArray("chunking_samples")
        var checked = 0
        for (i in 0 until samples.length()) {
            val sample = samples.getJSONObject(i)
            val name = sample.optString("name", "?")
            val mtu = sample.getInt("negotiated_mtu")
            val envIdHex = sample.getString("envelope_id_hex")
            val envId = hexToBytes(envIdHex)
            assertEquals(
                "envelope_id_hex for $name must decode to 16 bytes",
                16,
                envId.size
            )
            val gen = sample.getJSONObject("envelope_bytes_generator")
            val envBytes = lcgByteGen(
                seed = gen.getLong("seed"),
                size = gen.getInt("size")
            )
            val expectedCount = sample.getInt("expected_chunk_count")
            val expectedFirstSha = sample.getString("expected_first_chunk_sha256_hex")
            val expectedLastSha = sample.getString("expected_last_chunk_sha256_hex")
            val expectedFirstBytes = sample.getInt("expected_first_chunk_bytes")
            val expectedLastBytes = sample.getInt("expected_last_chunk_bytes")

            val chunks = Chunker.split(envId, envBytes, mtu)
            assertEquals(
                "chunking sample $name: chunk count mismatch",
                expectedCount,
                chunks.size
            )
            assertEquals(
                "chunking sample $name: first chunk byte length",
                expectedFirstBytes,
                chunks.first().size
            )
            assertEquals(
                "chunking sample $name: last chunk byte length",
                expectedLastBytes,
                chunks.last().size
            )
            assertEquals(
                "chunking sample $name: first chunk sha256 diverged from Dart oracle",
                expectedFirstSha,
                sha256Hex(chunks.first())
            )
            assertEquals(
                "chunking sample $name: last chunk sha256 diverged from Dart oracle",
                expectedLastSha,
                sha256Hex(chunks.last())
            )
            checked += 1
        }
        assertTrue("spec requires >= 20 chunking samples", checked >= 20)
    }

    // ── Deterministic generators (mirror Dart) ────────────────────────

    /**
     * Mirror of Dart `ascii_seq_v1`: yield `prefix + zeroPadded(i, width)` for
     * i in [start, start + count).
     */
    private fun asciiSeqIds(
        prefix: String,
        start: Int,
        count: Int,
        width: Int
    ): List<String> {
        val out = ArrayList<String>(count)
        for (i in start until (start + count)) {
            out.add("$prefix${i.toString().padStart(width, '0')}")
        }
        return out
    }

    /**
     * Mirror of Dart `lcg_byte_pattern_v1`: state := seed (uint32);
     * for i in [0, size): state := (state * 1664525 + 1013904223) mod 2^32;
     * out[i] := state & 0xFF.
     */
    private fun lcgByteGen(seed: Long, size: Int): ByteArray {
        var state = seed and 0xFFFFFFFFL
        val out = ByteArray(size)
        for (i in 0 until size) {
            state = (state * 1664525L + 1013904223L) and 0xFFFFFFFFL
            out[i] = (state and 0xFFL).toByte()
        }
        return out
    }

    // ── Helpers ───────────────────────────────────────────────────────

    private fun toHex(bytes: ByteArray): String {
        val sb = StringBuilder(bytes.size * 2)
        for (b in bytes) sb.append(String.format("%02x", b))
        return sb.toString()
    }

    private fun hexToBytes(hex: String): ByteArray {
        require(hex.length % 2 == 0) { "hex string length must be even" }
        val out = ByteArray(hex.length / 2)
        var i = 0
        while (i < hex.length) {
            out[i / 2] = ((Character.digit(hex[i], 16) shl 4) +
                Character.digit(hex[i + 1], 16)).toByte()
            i += 2
        }
        return out
    }

    private fun sha256Hex(bytes: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        return toHex(digest)
    }

    private fun isAscii(s: String): Boolean {
        for (c in s.toCharArray()) {
            if (c.code > 0x7F) return false
        }
        return true
    }
}
