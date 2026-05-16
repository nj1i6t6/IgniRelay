package network.ignirelay.ignirelay_app

/**
 * Receiver-side reassembly for v0.3 chunk-framed envelopes.
 *
 * Spec: docs/specs/native_transport_v1_2026-05-13.md §4.4 (decisions §15.5).
 *
 * Mirrors `lib/app/mesh/reassembler.dart`. Out-of-order delivery is handled
 * trivially. Duplicate chunks are idempotent. Envelopes already dispatched (or
 * tombstoned) are dropped before reassembly state is allocated so a flood of
 * duplicate chunks cannot inflate buffer state.
 */
class Reassembler(
    private val isAlreadyDispatched: (ByteArray) -> Boolean,
    private val isTombstoned: (ByteArray) -> Boolean,
    private val onDrop: ((dropReason: String, envelopeId: ByteArray) -> Unit)? = null,
) {
    private data class Entry(
        val totalChunks: Int,
        val startedAtMs: Long,
        val chunks: HashMap<Int, ByteArray> = HashMap(),
        var bufferedBytes: Int = 0,
    )

    private val entries = HashMap<String, Entry>()
    private var bufferedBytes = 0

    val inFlight: Int get() = entries.size
    val totalBufferedBytes: Int get() = bufferedBytes

    /**
     * Feed a single chunk. Returns the fully reassembled envelope bytes when
     * this chunk completes the envelope; otherwise returns `null` (and emits a
     * `drop_reason` via [onDrop] for malformed or duplicate chunks).
     */
    fun onChunk(chunkBytes: ByteArray, nowMs: Long = System.currentTimeMillis()): ByteArray? {
        if (chunkBytes.size < IgniRelayConstants.CHUNK_HEADER_SIZE) {
            drop(EMPTY_ID, "chunk-too-small")
            return null
        }
        val envelopeId = chunkBytes.copyOfRange(0, 16)
        val chunkIndex = chunkBytes[16].toInt() and 0xFF
        val totalChunks = chunkBytes[17].toInt() and 0xFF
        val payload = chunkBytes.copyOfRange(IgniRelayConstants.CHUNK_HEADER_SIZE, chunkBytes.size)

        if (totalChunks == 0 || chunkIndex >= totalChunks) {
            drop(envelopeId, "chunk-bad-header")
            return null
        }
        if (totalChunks > IgniRelayConstants.MAX_CHUNKS_PER_ENVELOPE) {
            drop(envelopeId, "over-max-chunks")
            return null
        }
        if (isAlreadyDispatched(envelopeId) || isTombstoned(envelopeId)) {
            drop(envelopeId, "chunk-for-dispatched")
            return null
        }

        val key = idKey(envelopeId)
        var entry = entries[key]
        if (entry == null) {
            if (entries.size >= IgniRelayConstants.MAX_REASSEMBLY_BUFFER_ENTRIES) {
                drop(envelopeId, "reassembly-buffer-entries-full")
                return null
            }
            entry = Entry(totalChunks, nowMs)
            entries[key] = entry
        } else if (entry.totalChunks != totalChunks) {
            drop(envelopeId, "chunk-total-mismatch")
            bufferedBytes -= entry.bufferedBytes
            entries.remove(key)
            return null
        }

        if (entry.chunks.containsKey(chunkIndex)) return null

        if (bufferedBytes + payload.size > IgniRelayConstants.MAX_REASSEMBLY_BUFFER_BYTES) {
            drop(envelopeId, "reassembly-buffer-bytes-full")
            bufferedBytes -= entry.bufferedBytes
            entries.remove(key)
            return null
        }

        entry.chunks[chunkIndex] = payload
        entry.bufferedBytes += payload.size
        bufferedBytes += payload.size

        return if (entry.chunks.size == totalChunks) {
            val out = assemble(entry)
            bufferedBytes -= entry.bufferedBytes
            entries.remove(key)
            out
        } else null
    }

    /**
     * Sweep for entries past REASSEMBLY_TIMEOUT_MS. Caller invokes periodically
     * (every 5s recommended).
     */
    fun sweep(nowMs: Long = System.currentTimeMillis()) {
        val cutoff = nowMs - IgniRelayConstants.REASSEMBLY_TIMEOUT_MS
        val stale = ArrayList<String>()
        for ((key, entry) in entries) {
            if (entry.startedAtMs < cutoff) stale.add(key)
        }
        for (key in stale) {
            val entry = entries.remove(key) ?: continue
            bufferedBytes -= entry.bufferedBytes
            drop(idFromKey(key), "reassembly-timeout")
        }
    }

    /** Drop in-flight reassembly state for a specific envelope_id. */
    fun forget(envelopeId: ByteArray) {
        val entry = entries.remove(idKey(envelopeId)) ?: return
        bufferedBytes -= entry.bufferedBytes
    }

    /** Discard all in-flight reassembly state. */
    fun clear() {
        entries.clear()
        bufferedBytes = 0
    }

    private fun assemble(entry: Entry): ByteArray {
        val out = ByteArray(entry.bufferedBytes)
        var offset = 0
        for (i in 0 until entry.totalChunks) {
            val c = entry.chunks[i] ?: error("missing chunk $i in completed entry")
            System.arraycopy(c, 0, out, offset, c.size)
            offset += c.size
        }
        return out
    }

    private fun drop(envelopeId: ByteArray, reason: String) {
        onDrop?.invoke(reason, envelopeId)
    }

    private fun idKey(id: ByteArray): String {
        val sb = StringBuilder(32)
        for (b in id) sb.append(String.format("%02x", b.toInt() and 0xFF))
        return sb.toString()
    }

    private fun idFromKey(key: String): ByteArray {
        val out = ByteArray(16)
        for (i in 0 until 16) {
            out[i] = key.substring(i * 2, i * 2 + 2).toInt(16).toByte()
        }
        return out
    }

    companion object {
        private val EMPTY_ID = ByteArray(16)
    }
}
