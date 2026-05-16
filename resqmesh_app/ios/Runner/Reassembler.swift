import Foundation

/// Receiver-side reassembly for v0.3 chunk-framed envelopes.
///
/// Spec: docs/specs/native_transport_v1_2026-05-13.md §4.4 (decisions §15.5).
///
/// Mirrors `lib/app/mesh/reassembler.dart` and `Reassembler.kt`. Out-of-order
/// delivery is handled trivially. Duplicate chunks are idempotent. Envelopes
/// already dispatched (or tombstoned) are dropped before reassembly state is
/// allocated so a flood of duplicate chunks cannot inflate buffer state.
final class Reassembler {
    typealias Predicate = (Data) -> Bool
    typealias DropHandler = (_ dropReason: String, _ envelopeId: Data) -> Void

    private struct Entry {
        let totalChunks: Int
        let startedAtMs: Int64
        var chunks: [Int: Data] = [:]
        var bufferedBytes: Int = 0
    }

    private let isAlreadyDispatched: Predicate
    private let isTombstoned: Predicate
    private let onDrop: DropHandler?

    private var entries: [Data: Entry] = [:]
    private(set) var totalBufferedBytes: Int = 0

    init(
        isAlreadyDispatched: @escaping Predicate,
        isTombstoned: @escaping Predicate,
        onDrop: DropHandler? = nil
    ) {
        self.isAlreadyDispatched = isAlreadyDispatched
        self.isTombstoned = isTombstoned
        self.onDrop = onDrop
    }

    var inFlight: Int { entries.count }

    /// Feed a single chunk. Returns the fully reassembled envelope bytes when
    /// this chunk completes the envelope; otherwise returns `nil` (and emits a
    /// `drop_reason` via [onDrop] for malformed or duplicate chunks).
    func onChunk(_ chunkBytes: Data, nowMs: Int64 = currentTimeMillis()) -> Data? {
        guard chunkBytes.count >= IgniRelayConstants.CHUNK_HEADER_SIZE else {
            drop(envelopeId: Self.emptyId, reason: "chunk-too-small")
            return nil
        }
        let envelopeId = chunkBytes.subdata(in: 0 ..< 16)
        let chunkIndex = Int(chunkBytes[16])
        let totalChunks = Int(chunkBytes[17])
        let payload = chunkBytes.subdata(in: IgniRelayConstants.CHUNK_HEADER_SIZE ..< chunkBytes.count)

        if totalChunks == 0 || chunkIndex >= totalChunks {
            drop(envelopeId: envelopeId, reason: "chunk-bad-header")
            return nil
        }
        if totalChunks > IgniRelayConstants.MAX_CHUNKS_PER_ENVELOPE {
            drop(envelopeId: envelopeId, reason: "over-max-chunks")
            return nil
        }
        if isAlreadyDispatched(envelopeId) || isTombstoned(envelopeId) {
            drop(envelopeId: envelopeId, reason: "chunk-for-dispatched")
            return nil
        }

        var entry = entries[envelopeId]
        if entry == nil {
            if entries.count >= IgniRelayConstants.MAX_REASSEMBLY_BUFFER_ENTRIES {
                drop(envelopeId: envelopeId, reason: "reassembly-buffer-entries-full")
                return nil
            }
            entry = Entry(totalChunks: totalChunks, startedAtMs: nowMs)
        } else if entry!.totalChunks != totalChunks {
            drop(envelopeId: envelopeId, reason: "chunk-total-mismatch")
            totalBufferedBytes -= entry!.bufferedBytes
            entries.removeValue(forKey: envelopeId)
            return nil
        }

        if entry!.chunks[chunkIndex] != nil {
            return nil
        }

        if totalBufferedBytes + payload.count > IgniRelayConstants.MAX_REASSEMBLY_BUFFER_BYTES {
            drop(envelopeId: envelopeId, reason: "reassembly-buffer-bytes-full")
            totalBufferedBytes -= entry!.bufferedBytes
            entries.removeValue(forKey: envelopeId)
            return nil
        }

        entry!.chunks[chunkIndex] = payload
        entry!.bufferedBytes += payload.count
        totalBufferedBytes += payload.count

        if entry!.chunks.count == totalChunks {
            let assembled = assemble(entry!)
            totalBufferedBytes -= entry!.bufferedBytes
            entries.removeValue(forKey: envelopeId)
            return assembled
        }
        entries[envelopeId] = entry
        return nil
    }

    /// Sweep for entries past REASSEMBLY_TIMEOUT_MS. Caller invokes periodically
    /// (every 5s recommended).
    func sweep(nowMs: Int64 = currentTimeMillis()) {
        let cutoff = nowMs - Int64(IgniRelayConstants.REASSEMBLY_TIMEOUT_MS)
        var stale: [Data] = []
        for (key, entry) in entries where entry.startedAtMs < cutoff {
            stale.append(key)
        }
        for key in stale {
            guard let entry = entries.removeValue(forKey: key) else { continue }
            totalBufferedBytes -= entry.bufferedBytes
            drop(envelopeId: key, reason: "reassembly-timeout")
        }
    }

    /// Drop in-flight reassembly state for a specific envelope_id.
    func forget(_ envelopeId: Data) {
        guard let entry = entries.removeValue(forKey: envelopeId) else { return }
        totalBufferedBytes -= entry.bufferedBytes
    }

    /// Discard all in-flight reassembly state.
    func clear() {
        entries.removeAll()
        totalBufferedBytes = 0
    }

    private func assemble(_ entry: Entry) -> Data {
        var out = Data(capacity: entry.bufferedBytes)
        for i in 0 ..< entry.totalChunks {
            guard let c = entry.chunks[i] else {
                fatalError("missing chunk \(i) in completed entry")
            }
            out.append(c)
        }
        return out
    }

    private func drop(envelopeId: Data, reason: String) {
        onDrop?(reason, envelopeId)
    }

    static let emptyId = Data(count: 16)

    static func currentTimeMillis() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}

/// Module-level helper, mirrors the static method to keep call sites simple.
func currentTimeMillis() -> Int64 {
    Reassembler.currentTimeMillis()
}
