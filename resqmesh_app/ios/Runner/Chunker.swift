import Foundation

/// App-level chunk framing for v0.3 envelope transport.
///
/// Spec: docs/specs/native_transport_v1_2026-05-13.md §4 (decisions §15.1, §15.5).
///
/// Mirrors `lib/app/mesh/chunker.dart` and `Chunker.kt`. Every envelope on the
/// wire is wrapped in chunk framing (Option B in §4.5):
///
///   ┌────────────────┬─────────────┬─────────────┬─────────────────┐
///   │ envelope_id    │ chunk_index │ total_chunks│ chunk_payload   │
///   │ 16 bytes       │ 1 byte u8   │ 1 byte u8   │ remaining bytes │
///   └────────────────┴─────────────┴─────────────┴─────────────────┘
enum Chunker {
    enum ChunkingError: Error {
        case overMaxEnvelopeBytes(actual: Int, cap: Int)
        case overMaxChunks(actual: Int, cap: Int)
        case mtuBelowMinimum(mtu: Int, payloadAvailable: Int)
        case invalidEnvelopeId(actual: Int)

        /// drop_reason string for `mesh_trace_logs.drop_reason`
        /// (envelope_v2_spec §15.2).
        var dropReason: String {
            switch self {
            case .overMaxEnvelopeBytes: return "over-max-envelope-bytes"
            case .overMaxChunks: return "over-max-chunks"
            case .mtuBelowMinimum: return "mtu-below-minimum-for-chunked"
            case .invalidEnvelopeId: return "invalid-envelope-id"
            }
        }
    }

    /// Split a serialized envelope into MTU-sized chunks for the negotiated MTU.
    /// `envelopeId` MUST be exactly 16 bytes.
    static func split(envelopeId: Data, envelopeBytes: Data, mtu: Int) throws -> [Data] {
        guard envelopeId.count == 16 else {
            throw ChunkingError.invalidEnvelopeId(actual: envelopeId.count)
        }
        if envelopeBytes.count > IgniRelayConstants.MAX_ENVELOPE_BYTES {
            throw ChunkingError.overMaxEnvelopeBytes(
                actual: envelopeBytes.count,
                cap: IgniRelayConstants.MAX_ENVELOPE_BYTES)
        }
        let chunkPayloadSize = mtu - IgniRelayConstants.ATT_HEADER_SIZE - IgniRelayConstants.CHUNK_HEADER_SIZE
        if chunkPayloadSize < 1 {
            throw ChunkingError.mtuBelowMinimum(mtu: mtu, payloadAvailable: chunkPayloadSize)
        }
        if envelopeBytes.isEmpty {
            return [frame(envelopeId: envelopeId, chunkIndex: 0, totalChunks: 1, chunkPayload: Data())]
        }
        let total = (envelopeBytes.count + chunkPayloadSize - 1) / chunkPayloadSize
        if total > IgniRelayConstants.MAX_CHUNKS_PER_ENVELOPE {
            throw ChunkingError.overMaxChunks(
                actual: total,
                cap: IgniRelayConstants.MAX_CHUNKS_PER_ENVELOPE)
        }
        var out: [Data] = []
        out.reserveCapacity(total)
        var offset = 0
        for i in 0 ..< total {
            let end = min(offset + chunkPayloadSize, envelopeBytes.count)
            let slice = envelopeBytes.subdata(in: offset ..< end)
            out.append(frame(envelopeId: envelopeId, chunkIndex: i, totalChunks: total, chunkPayload: slice))
            offset = end
        }
        return out
    }

    private static func frame(
        envelopeId: Data,
        chunkIndex: Int,
        totalChunks: Int,
        chunkPayload: Data
    ) -> Data {
        precondition(envelopeId.count == 16)
        precondition((0 ..< 256).contains(chunkIndex))
        precondition((1 ..< 256).contains(totalChunks))
        var out = Data(capacity: IgniRelayConstants.CHUNK_HEADER_SIZE + chunkPayload.count)
        out.append(envelopeId)
        out.append(UInt8(chunkIndex))
        out.append(UInt8(totalChunks))
        out.append(chunkPayload)
        return out
    }
}
