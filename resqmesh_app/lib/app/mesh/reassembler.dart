import 'dart:typed_data';

import 'mesh_constants.dart';

/// Receiver-side reassembly for v0.3 chunk-framed envelopes.
///
/// Spec: docs/specs/native_transport_v1_2026-05-13.md §4.4 (decisions §15.5).
///
/// Out-of-order delivery is handled trivially (chunks are keyed by
/// `chunk_index`). Duplicate chunks are idempotent. Envelopes already in
/// `dispatchedSet` (or tombstoned) are dropped before reassembly state is
/// allocated so a flood of duplicate chunks cannot inflate buffer state.
class Reassembler {
  final Map<String, _ReassemblyEntry> _entries = <String, _ReassemblyEntry>{};
  int _bufferedBytes = 0;

  /// Whether an envelope_id has already been dispatched on this device. Caller
  /// owns this set (typically `EventStream._dispatchedEventIds`).
  final bool Function(Uint8List envelopeId) isAlreadyDispatched;

  /// Whether an envelope_id is in the local tombstone set.
  final bool Function(Uint8List envelopeId) isTombstoned;

  /// Optional callback for trace logging. The reassembler does not read the DB
  /// itself; the caller wires this to `mesh_trace_logs`.
  final void Function(String dropReason, Uint8List envelopeId)? onDrop;

  Reassembler({
    required this.isAlreadyDispatched,
    required this.isTombstoned,
    this.onDrop,
  });

  /// Number of in-flight envelope_ids being reassembled (visible for diagnostics).
  int get inFlight => _entries.length;

  /// Bytes currently buffered across all in-flight reassembly entries.
  int get bufferedBytes => _bufferedBytes;

  /// Feed a single chunk.
  ///
  /// Returns the fully reassembled envelope bytes when this chunk completes
  /// the envelope; otherwise returns `null`. Returns `null` and emits a
  /// `drop_reason` via [onDrop] for malformed or duplicate chunks.
  Uint8List? onChunk(Uint8List chunkBytes, {DateTime? now}) {
    if (chunkBytes.length < kChunkHeaderSize) {
      _drop(_emptyId, 'chunk-too-small');
      return null;
    }
    final envelopeId = Uint8List.sublistView(chunkBytes, 0, 16);
    final chunkIndex = chunkBytes[16];
    final totalChunks = chunkBytes[17];
    final payload = Uint8List.sublistView(chunkBytes, kChunkHeaderSize);

    if (totalChunks == 0 || chunkIndex >= totalChunks) {
      _drop(envelopeId, 'chunk-bad-header');
      return null;
    }
    if (totalChunks > kMaxChunksPerEnvelope) {
      _drop(envelopeId, 'over-max-chunks');
      return null;
    }
    if (isAlreadyDispatched(envelopeId) || isTombstoned(envelopeId)) {
      _drop(envelopeId, 'chunk-for-dispatched');
      return null;
    }

    final key = _idKey(envelopeId);
    var entry = _entries[key];
    if (entry == null) {
      // Enforce per-device caps before allocating.
      if (_entries.length >= kMaxReassemblyBufferEntries) {
        _drop(envelopeId, 'reassembly-buffer-entries-full');
        return null;
      }
      entry = _ReassemblyEntry(totalChunks, now ?? DateTime.now());
      _entries[key] = entry;
    } else if (entry.totalChunks != totalChunks) {
      _drop(envelopeId, 'chunk-total-mismatch');
      _bufferedBytes -= entry.bufferedBytes;
      _entries.remove(key);
      return null;
    }

    if (entry.chunks.containsKey(chunkIndex)) {
      // Duplicate chunk; idempotent — overwrite with identical bytes is a no-op.
      // Do not double-count buffered bytes.
      return null;
    }

    if (_bufferedBytes + payload.length > kMaxReassemblyBufferBytes) {
      _drop(envelopeId, 'reassembly-buffer-bytes-full');
      _bufferedBytes -= entry.bufferedBytes;
      _entries.remove(key);
      return null;
    }

    entry.chunks[chunkIndex] = payload;
    entry.bufferedBytes += payload.length;
    _bufferedBytes += payload.length;

    if (entry.chunks.length == totalChunks) {
      final assembled = _assemble(entry);
      _bufferedBytes -= entry.bufferedBytes;
      _entries.remove(key);
      return assembled;
    }
    return null;
  }

  /// Sweep for entries past [kReassemblyTimeoutMs]. Caller invokes periodically
  /// (every 5s recommended).
  void sweep({DateTime? now}) {
    final cutoff = (now ?? DateTime.now())
        .subtract(const Duration(milliseconds: kReassemblyTimeoutMs));
    final stale = <String>[];
    _entries.forEach((key, entry) {
      if (entry.startedAt.isBefore(cutoff)) {
        stale.add(key);
      }
    });
    for (final key in stale) {
      final entry = _entries.remove(key)!;
      _bufferedBytes -= entry.bufferedBytes;
      _drop(_idFromKey(key), 'reassembly-timeout');
    }
  }

  /// Drop in-flight reassembly state for a specific envelope_id (e.g., when the
  /// peer disconnects or the envelope was received in full from another peer).
  void forget(Uint8List envelopeId) {
    final key = _idKey(envelopeId);
    final entry = _entries.remove(key);
    if (entry != null) {
      _bufferedBytes -= entry.bufferedBytes;
    }
  }

  /// Discard all in-flight reassembly state.
  void clear() {
    _entries.clear();
    _bufferedBytes = 0;
  }

  Uint8List _assemble(_ReassemblyEntry entry) {
    final out = Uint8List(entry.bufferedBytes);
    var offset = 0;
    for (var i = 0; i < entry.totalChunks; i++) {
      final c = entry.chunks[i]!;
      out.setRange(offset, offset + c.length, c);
      offset += c.length;
    }
    return out;
  }

  void _drop(Uint8List envelopeId, String reason) {
    final cb = onDrop;
    if (cb != null) cb(reason, envelopeId);
  }

  static String _idKey(Uint8List id) {
    final sb = StringBuffer();
    for (final b in id) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static Uint8List _idFromKey(String key) {
    final out = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      out[i] = int.parse(key.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static final Uint8List _emptyId = Uint8List(16);
}

class _ReassemblyEntry {
  final int totalChunks;
  final DateTime startedAt;
  final Map<int, Uint8List> chunks = <int, Uint8List>{};
  int bufferedBytes = 0;

  _ReassemblyEntry(this.totalChunks, this.startedAt);
}
