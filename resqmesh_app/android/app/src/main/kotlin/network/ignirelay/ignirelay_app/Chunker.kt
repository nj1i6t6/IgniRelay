package network.ignirelay.ignirelay_app

/**
 * App-level chunk framing for v0.3 envelope transport.
 *
 * Spec: docs/specs/native_transport_v1_2026-05-13.md §4 (decisions §15.1, §15.5).
 *
 * Mirrors `lib/app/mesh/chunker.dart`. Every envelope on the wire is wrapped
 * in chunk framing (Option B in §4.5):
 *
 *   ┌────────────────┬─────────────┬─────────────┬─────────────────┐
 *   │ envelope_id    │ chunk_index │ total_chunks│ chunk_payload   │
 *   │ 16 bytes       │ 1 byte u8   │ 1 byte u8   │ remaining bytes │
 *   └────────────────┴─────────────┴─────────────┴─────────────────┘
 */
object Chunker {
    /**
     * Split a serialized envelope into MTU-sized chunks for the negotiated MTU.
     * `envelopeId` MUST be exactly 16 bytes.
     *
     * @throws ChunkingException when the envelope is too large, the MTU is too
     *   low, or the resulting chunk count would exceed MAX_CHUNKS_PER_ENVELOPE.
     */
    @Throws(ChunkingException::class)
    fun split(envelopeId: ByteArray, envelopeBytes: ByteArray, mtu: Int): List<ByteArray> {
        require(envelopeId.size == 16) {
            "envelope_id must be 16 bytes; got ${envelopeId.size}"
        }
        if (envelopeBytes.size > IgniRelayConstants.MAX_ENVELOPE_BYTES) {
            throw ChunkingException(
                ChunkingException.Kind.OVER_MAX_ENVELOPE_BYTES,
                "envelope ${envelopeBytes.size} B exceeds MAX_ENVELOPE_BYTES=${IgniRelayConstants.MAX_ENVELOPE_BYTES}"
            )
        }
        val chunkPayloadSize = mtu - IgniRelayConstants.ATT_HEADER_SIZE - IgniRelayConstants.CHUNK_HEADER_SIZE
        if (chunkPayloadSize < 1) {
            throw ChunkingException(
                ChunkingException.Kind.MTU_BELOW_MINIMUM,
                "mtu=$mtu leaves $chunkPayloadSize B for chunk payload"
            )
        }
        if (envelopeBytes.isEmpty()) {
            return listOf(frame(envelopeId, 0, 1, ByteArray(0)))
        }
        val total = (envelopeBytes.size + chunkPayloadSize - 1) / chunkPayloadSize
        if (total > IgniRelayConstants.MAX_CHUNKS_PER_ENVELOPE) {
            throw ChunkingException(
                ChunkingException.Kind.OVER_MAX_CHUNKS,
                "envelope needs $total chunks at chunk_payload=$chunkPayloadSize; cap=${IgniRelayConstants.MAX_CHUNKS_PER_ENVELOPE}"
            )
        }
        val out = ArrayList<ByteArray>(total)
        var offset = 0
        for (i in 0 until total) {
            val end = (offset + chunkPayloadSize).coerceAtMost(envelopeBytes.size)
            val slice = envelopeBytes.copyOfRange(offset, end)
            out.add(frame(envelopeId, i, total, slice))
            offset = end
        }
        return out
    }

    private fun frame(envelopeId: ByteArray, chunkIndex: Int, totalChunks: Int, chunkPayload: ByteArray): ByteArray {
        require(envelopeId.size == 16)
        require(chunkIndex in 0..255)
        require(totalChunks in 1..255)
        val out = ByteArray(IgniRelayConstants.CHUNK_HEADER_SIZE + chunkPayload.size)
        System.arraycopy(envelopeId, 0, out, 0, 16)
        out[16] = chunkIndex.toByte()
        out[17] = totalChunks.toByte()
        System.arraycopy(chunkPayload, 0, out, 18, chunkPayload.size)
        return out
    }
}

/**
 * Errors raised by [Chunker.split]. Each maps to a documented `drop_reason`
 * from `mesh_trace_logs.drop_reason` (envelope_v2_spec §15.2).
 */
class ChunkingException(
    val kind: Kind,
    message: String
) : RuntimeException(message) {
    enum class Kind(val dropReason: String) {
        OVER_MAX_ENVELOPE_BYTES("over-max-envelope-bytes"),
        OVER_MAX_CHUNKS("over-max-chunks"),
        MTU_BELOW_MINIMUM("mtu-below-minimum-for-chunked"),
    }

    val dropReason: String get() = kind.dropReason
}
