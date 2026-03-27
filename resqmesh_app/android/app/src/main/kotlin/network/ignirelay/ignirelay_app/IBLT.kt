package network.ignirelay.ignirelay_app

import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Invertible Bloom Lookup Table for BLE mesh differential sync.
 * 56 buckets x 9 bytes = 504 bytes (fits in 1 MTU of 517)
 * Bucket: count(1B signed) + keySum(4B CRC32) + hashSum(4B FNV-1a)
 * Tolerates ~38 item differences (56 / 1.5 safety factor)
 *
 * Must stay bit-identical with the Dart implementation in lib/mesh/iblt.dart.
 */
class IBLT private constructor(val buckets: Array<IBLTBucket>) {

    constructor() : this(Array(BUCKET_COUNT) { IBLTBucket() })

    companion object {
        const val BUCKET_COUNT = 56
        const val BUCKET_SIZE = 9        // 1 + 4 + 4
        const val TOTAL_BYTES = BUCKET_COUNT * BUCKET_SIZE // 504
        const val HASH_FUNCTIONS = 3

        /** Deserialize from bytes (Little Endian, matching Dart side). */
        fun fromBytes(bytes: ByteArray): IBLT {
            require(bytes.size >= TOTAL_BYTES) {
                "IBLT data too short: ${bytes.size} < $TOTAL_BYTES"
            }
            val buf = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
            val buckets = Array(BUCKET_COUNT) { i ->
                val offset = i * BUCKET_SIZE
                IBLTBucket(
                    count = buf.get(offset).toInt(),                       // signed byte
                    keySum = buf.getInt(offset + 1).toLong() and 0xFFFFFFFFL,  // unsigned 32
                    hashSum = buf.getInt(offset + 5).toLong() and 0xFFFFFFFFL  // unsigned 32
                )
            }
            return IBLT(buckets)
        }

        // ── Hash Functions (static, matching Dart exactly) ──

        /** CRC32 for keySum — identical to Dart _crc32. */
        fun crc32(s: String): Long {
            var crc = 0xFFFFFFFFL
            for (b in s.toCharArray()) {
                crc = crc xor (b.code.toLong() and 0xFFL)
                for (j in 0 until 8) {
                    crc = if (crc and 1L == 1L) (crc ushr 1) xor 0xEDB88320L else crc ushr 1
                }
            }
            return (crc xor 0xFFFFFFFFL) and 0xFFFFFFFFL
        }

        /** FNV-1a for hashSum — identical to Dart _fnv1a. */
        fun fnv1a(s: String): Long {
            var h = 0x811c9dc5L
            for (b in s.toCharArray()) {
                h = h xor (b.code.toLong() and 0xFFL)
                h = (h * 0x01000193L) and 0xFFFFFFFFL
            }
            return h
        }

        /**
         * MurmurHash3-like for bucket index selection — identical to Dart _murmurHash.
         * Operates on char code units (same as Dart's codeUnits).
         */
        fun murmurHash(bytes: List<Int>, seed: Int): Long {
            var h = seed.toLong() and 0xFFFFFFFFL
            for (i in bytes.indices) {
                var k = bytes[i].toLong() and 0xFFFFFFFFL
                k = (k * 0xcc9e2d51L) and 0xFFFFFFFFL
                k = ((k shl 15) or (k ushr 17)) and 0xFFFFFFFFL
                k = (k * 0x1b873593L) and 0xFFFFFFFFL
                h = h xor k
                h = ((h shl 13) or (h ushr 19)) and 0xFFFFFFFFL
                h = (h * 5L + 0xe6546b64L) and 0xFFFFFFFFL
            }
            h = h xor bytes.size.toLong()
            h = h xor (h ushr 16)
            h = (h * 0x85ebca6bL) and 0xFFFFFFFFL
            h = h xor (h ushr 13)
            h = (h * 0xc2b2ae35L) and 0xFFFFFFFFL
            h = h xor (h ushr 16)
            return h
        }
    }

    // ── Public API ──

    /** Insert an event ID into the IBLT. */
    fun insert(eventId: String) {
        val keyHash = crc32(eventId)
        val checkHash = fnv1a(eventId)
        val indices = getIndices(eventId)
        for (idx in indices) {
            buckets[idx].count += 1
            buckets[idx].keySum = buckets[idx].keySum xor keyHash
            buckets[idx].hashSum = buckets[idx].hashSum xor checkHash
        }
    }

    /** Remove an event ID from the IBLT. */
    fun remove(eventId: String) {
        val keyHash = crc32(eventId)
        val checkHash = fnv1a(eventId)
        val indices = getIndices(eventId)
        for (idx in indices) {
            buckets[idx].count -= 1
            buckets[idx].keySum = buckets[idx].keySum xor keyHash
            buckets[idx].hashSum = buckets[idx].hashSum xor checkHash
        }
    }

    /** Subtract another IBLT from this one (this - other). */
    fun subtract(other: IBLT): IBLT {
        val result = IBLT()
        for (i in 0 until BUCKET_COUNT) {
            result.buckets[i].count = buckets[i].count - other.buckets[i].count
            result.buckets[i].keySum = buckets[i].keySum xor other.buckets[i].keySum
            result.buckets[i].hashSum = buckets[i].hashSum xor other.buckets[i].hashSum
        }
        return result
    }

    /**
     * Peel the IBLT to extract differences.
     * Returns null if peeling fails (too many differences — need Slow Path).
     */
    fun peel(): IBLTPeelResult? {
        val onlyInA = mutableSetOf<Long>() // keyHashes only in self
        val onlyInB = mutableSetOf<Long>() // keyHashes only in other

        // Create working copy
        val work = Array(BUCKET_COUNT) { i ->
            IBLTBucket(
                count = buckets[i].count,
                keySum = buckets[i].keySum,
                hashSum = buckets[i].hashSum
            )
        }

        var changed = true
        var iterations = 0
        val maxIterations = 1000

        while (changed && iterations < maxIterations) {
            changed = false
            iterations++
            for (i in 0 until BUCKET_COUNT) {
                if (work[i].count == 1) {
                    // Pure cell: element only in A
                    val key = work[i].keySum
                    val check = work[i].hashSum
                    if (verifyChecksum(key, check)) {
                        onlyInA.add(key)
                        val indices = getIndicesFromHash(key)
                        for (idx in indices) {
                            work[idx].count -= 1
                            work[idx].keySum = work[idx].keySum xor key
                            work[idx].hashSum = work[idx].hashSum xor check
                        }
                        changed = true
                    }
                } else if (work[i].count == -1) {
                    // Pure cell: element only in B
                    val key = work[i].keySum
                    val check = work[i].hashSum
                    if (verifyChecksum(key, check)) {
                        onlyInB.add(key)
                        val indices = getIndicesFromHash(key)
                        for (idx in indices) {
                            work[idx].count += 1
                            work[idx].keySum = work[idx].keySum xor key
                            work[idx].hashSum = work[idx].hashSum xor check
                        }
                        changed = true
                    }
                }
            }
        }

        // Check if fully peeled
        for (i in 0 until BUCKET_COUNT) {
            if (work[i].count != 0) return null // Failed to peel
        }

        return IBLTPeelResult(onlyInA = onlyInA, onlyInB = onlyInB)
    }

    /** Serialize to bytes (504 bytes, Little Endian — matching Dart side). */
    fun toBytes(): ByteArray {
        val buf = ByteBuffer.allocate(TOTAL_BYTES).order(ByteOrder.LITTLE_ENDIAN)
        for (i in 0 until BUCKET_COUNT) {
            val offset = i * BUCKET_SIZE
            buf.put(offset, buckets[i].count.toByte())
            buf.putInt(offset + 1, buckets[i].keySum.toInt())
            buf.putInt(offset + 5, buckets[i].hashSum.toInt())
        }
        return buf.array()
    }

    // ── Private helpers ──

    /** Get bucket indices for an event ID (MurmurHash3 with k=3 seeds). */
    private fun getIndices(eventId: String): List<Int> {
        val codeUnits = eventId.map { it.code }
        return listOf(
            (murmurHash(codeUnits, 0) % BUCKET_COUNT).toInt(),
            (murmurHash(codeUnits, 1) % BUCKET_COUNT).toInt(),
            (murmurHash(codeUnits, 2) % BUCKET_COUNT).toInt(),
        )
    }

    /**
     * Get bucket indices from a key hash (used during peeling).
     * Matches Dart _getIndicesFromHash exactly.
     */
    private fun getIndicesFromHash(keyHash: Long): List<Int> {
        return listOf(
            ((keyHash) and 0xFFFFL).toInt() % BUCKET_COUNT,
            ((keyHash ushr 8) and 0xFFFFL).toInt() % BUCKET_COUNT,
            ((keyHash ushr 16) and 0xFFFFL).toInt() % BUCKET_COUNT,
        )
    }

    /**
     * Verify that keySum and hashSum match.
     * FNV-1a of the keySum's 4 LE bytes should equal hashSum.
     */
    private fun verifyChecksum(keySum: Long, hashSum: Long): Boolean {
        val keyBytes = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN)
            .putInt(keySum.toInt()).array()
        var h = 0x811c9dc5L
        for (i in 0 until 4) {
            h = h xor (keyBytes[i].toLong() and 0xFFL)
            h = (h * 0x01000193L) and 0xFFFFFFFFL
        }
        return h == hashSum
    }
}

/** Single IBLT bucket: count (signed byte range) + keySum (uint32) + hashSum (uint32). */
data class IBLTBucket(
    var count: Int = 0,     // signed, kept in byte range during serialization
    var keySum: Long = 0L,  // unsigned 32-bit stored as Long to avoid sign issues
    var hashSum: Long = 0L  // unsigned 32-bit stored as Long
)

/** Result of IBLT peeling — the symmetric differences. */
data class IBLTPeelResult(
    val onlyInA: Set<Long>,  // keyHashes only in self (peer needs these)
    val onlyInB: Set<Long>   // keyHashes only in other (we need these)
) {
    val isEmpty: Boolean get() = onlyInA.isEmpty() && onlyInB.isEmpty()
}
