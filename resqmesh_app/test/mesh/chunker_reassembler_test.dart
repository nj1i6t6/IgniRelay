// v0.3 Stage 0c1 — unit tests for the cross-platform Chunker + Reassembler.
//
// Spec: docs/specs/native_transport_v1_2026-05-13.md §4.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/mesh/chunker.dart';
import 'package:ignirelay_app/app/mesh/mesh_constants.dart';
import 'package:ignirelay_app/app/mesh/reassembler.dart';

void main() {
  group('Chunker.split', () {
    final id = Uint8List.fromList(List.generate(16, (i) => 0xA0 | (i & 0x0F)));

    test('SOS budget at MTU=247 → 2 chunks', () {
      final envelope = _filled(kSosEnvelopeBudgetBytes);
      final chunks = Chunker.split(envelopeId: id, envelopeBytes: envelope, mtu: 247);
      expect(chunks.length, 2);
      expect(chunks.first.length,
          kChunkHeaderSize + (247 - kAttHeaderSize - kChunkHeaderSize));
    });

    test('SOS budget at MTU=185 → 2 chunks', () {
      final envelope = _filled(kSosEnvelopeBudgetBytes);
      final chunks = Chunker.split(envelopeId: id, envelopeBytes: envelope, mtu: 185);
      expect(chunks.length, 2);
    });

    test('SOS budget at MTU=512 → 1 chunk', () {
      final envelope = _filled(kSosEnvelopeBudgetBytes);
      final chunks = Chunker.split(envelopeId: id, envelopeBytes: envelope, mtu: 512);
      expect(chunks.length, 1);
    });

    test('chunk header layout: envelope_id || u8 index || u8 total', () {
      final envelope = _filled(kSosEnvelopeBudgetBytes);
      final chunks = Chunker.split(envelopeId: id, envelopeBytes: envelope, mtu: 247);
      for (var i = 0; i < chunks.length; i++) {
        expect(chunks[i].sublist(0, 16), id);
        expect(chunks[i][16], i);
        expect(chunks[i][17], chunks.length);
      }
    });

    test('rejects oversize envelope > MAX_ENVELOPE_BYTES', () {
      final envelope = _filled(kMaxEnvelopeBytes + 1);
      expect(
        () => Chunker.split(envelopeId: id, envelopeBytes: envelope, mtu: 247),
        throwsA(isA<ChunkingError>().having(
            (e) => e.dropReason, 'dropReason', 'over-max-envelope-bytes')),
      );
    });

    test('rejects MTU below chunk-header minimum', () {
      final envelope = _filled(100);
      expect(
        () => Chunker.split(envelopeId: id, envelopeBytes: envelope, mtu: 20),
        throwsA(isA<ChunkingError>().having(
            (e) => e.dropReason, 'dropReason', 'mtu-below-minimum-for-chunked')),
      );
    });

    test('rejects when chunk count would exceed cap', () {
      // 16 chunks × tiny payload at MTU=23 → SOS budget needs ~120 chunks
      final envelope = _filled(kSosEnvelopeBudgetBytes);
      expect(
        () => Chunker.split(envelopeId: id, envelopeBytes: envelope, mtu: 23),
        throwsA(isA<ChunkingError>().having(
            (e) => e.dropReason, 'dropReason', 'over-max-chunks')),
      );
    });

    test('chunks reassemble bit-identically (split → flatten)', () {
      final envelope = _filled(800); // ALERT-class size
      final chunks = Chunker.split(envelopeId: id, envelopeBytes: envelope, mtu: 247);
      // Strip the 18-byte chunk header from each and concat — should match original.
      final flat = <int>[];
      for (final c in chunks) {
        flat.addAll(c.sublist(kChunkHeaderSize));
      }
      expect(Uint8List.fromList(flat), envelope);
    });
  });

  group('Reassembler', () {
    final id = Uint8List.fromList(List.generate(16, (i) => 0xC0 | (i & 0x0F)));

    Reassembler newRA() => Reassembler(
          isAlreadyDispatched: (_) => false,
          isTombstoned: (_) => false,
        );

    test('in-order delivery returns assembled envelope on last chunk', () {
      final envelope = _filled(kSosEnvelopeBudgetBytes);
      final chunks = Chunker.split(envelopeId: id, envelopeBytes: envelope, mtu: 247);
      final ra = newRA();
      Uint8List? assembled;
      for (final c in chunks) {
        final maybe = ra.onChunk(c);
        if (maybe != null) assembled = maybe;
      }
      expect(assembled, isNotNull);
      expect(assembled, envelope);
      expect(ra.inFlight, 0, reason: 'completed entry must be dropped');
      expect(ra.bufferedBytes, 0);
    });

    test('out-of-order delivery still assembles correctly', () {
      final envelope = _filled(800);
      final chunks = Chunker.split(envelopeId: id, envelopeBytes: envelope, mtu: 247);
      final ra = newRA();
      // Reverse delivery.
      Uint8List? assembled;
      for (final c in chunks.reversed) {
        final maybe = ra.onChunk(c);
        if (maybe != null) assembled = maybe;
      }
      expect(assembled, envelope);
    });

    test('duplicate chunk is idempotent', () {
      final envelope = _filled(400);
      final chunks = Chunker.split(envelopeId: id, envelopeBytes: envelope, mtu: 247);
      final ra = newRA();
      final maybeFirst = ra.onChunk(chunks[0]);
      expect(maybeFirst, isNull);
      // Re-feed the same chunk; buffered bytes must not grow.
      final beforeBytes = ra.bufferedBytes;
      ra.onChunk(chunks[0]);
      expect(ra.bufferedBytes, beforeBytes);
      // Final chunk completes the envelope.
      final maybeLast = ra.onChunk(chunks[1]);
      expect(maybeLast, isNotNull);
      expect(maybeLast, envelope);
    });

    test('chunk for already-dispatched envelope_id is dropped', () {
      final droppedReasons = <String>[];
      final ra = Reassembler(
        isAlreadyDispatched: (_) => true,
        isTombstoned: (_) => false,
        onDrop: (reason, _) => droppedReasons.add(reason),
      );
      final envelope = _filled(50);
      final chunks = Chunker.split(envelopeId: id, envelopeBytes: envelope, mtu: 247);
      final out = ra.onChunk(chunks.first);
      expect(out, isNull);
      expect(droppedReasons, ['chunk-for-dispatched']);
    });

    test('total_chunks mismatch evicts entry and drops', () {
      final droppedReasons = <String>[];
      final ra = Reassembler(
        isAlreadyDispatched: (_) => false,
        isTombstoned: (_) => false,
        onDrop: (reason, _) => droppedReasons.add(reason),
      );
      final envelope = _filled(800);
      final chunks = Chunker.split(envelopeId: id, envelopeBytes: envelope, mtu: 247);
      ra.onChunk(chunks[0]);
      // Forge a second chunk whose header advertises a different total_chunks
      // value (still within the cap, so we test mismatch-not-cap).
      final forged = Uint8List.fromList(chunks[1]);
      forged[17] = (chunks.length + 1) & 0xFF;
      ra.onChunk(forged);
      expect(droppedReasons, contains('chunk-total-mismatch'));
      expect(ra.inFlight, 0);
    });

    test('sweep evicts entries older than REASSEMBLY_TIMEOUT_MS', () {
      final droppedReasons = <String>[];
      final ra = Reassembler(
        isAlreadyDispatched: (_) => false,
        isTombstoned: (_) => false,
        onDrop: (reason, _) => droppedReasons.add(reason),
      );
      final envelope = _filled(400);
      final chunks = Chunker.split(envelopeId: id, envelopeBytes: envelope, mtu: 247);
      final t0 = DateTime.fromMillisecondsSinceEpoch(1000000);
      ra.onChunk(chunks.first, now: t0);
      expect(ra.inFlight, 1);
      // Sweep just before the timeout: nothing is evicted.
      ra.sweep(now: t0.add(const Duration(milliseconds: kReassemblyTimeoutMs - 1)));
      expect(ra.inFlight, 1);
      // Sweep past the timeout: entry is evicted.
      ra.sweep(now: t0.add(const Duration(milliseconds: kReassemblyTimeoutMs + 1)));
      expect(ra.inFlight, 0);
      expect(droppedReasons, ['reassembly-timeout']);
    });
  });
}

Uint8List _filled(int size) {
  final out = Uint8List(size);
  for (var i = 0; i < size; i++) {
    out[i] = (i * 31) & 0xFF;
  }
  return out;
}
