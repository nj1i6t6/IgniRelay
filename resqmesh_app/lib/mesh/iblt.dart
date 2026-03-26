import 'dart:typed_data';

/// Invertible Bloom Lookup Table for BLE mesh differential sync.
/// 56 buckets × 9 bytes = 504 bytes (fits in 1 MTU of 517)
/// Bucket: count(1B signed) + keySum(4B CRC32) + hashSum(4B checksum)
/// Tolerates ~38 item differences (56 / 1.5 safety factor)
class IBLT {
  static const int bucketCount = 56;
  static const int bucketSize = 9; // 1 + 4 + 4
  static const int totalBytes = bucketCount * bucketSize; // 504
  static const int hashFunctions = 3;

  final List<IBLTBucket> buckets;

  IBLT() : buckets = List.generate(bucketCount, (_) => IBLTBucket());

  IBLT._(this.buckets);

  /// Insert an event ID into the IBLT
  void insert(String eventId) {
    final keyHash = _crc32(eventId);
    final checkHash = _fnv1a(eventId);
    final indices = _getIndices(eventId);
    for (final idx in indices) {
      buckets[idx].count += 1;
      buckets[idx].keySum ^= keyHash;
      buckets[idx].hashSum ^= checkHash;
    }
  }

  /// Remove an event ID from the IBLT
  void remove(String eventId) {
    final keyHash = _crc32(eventId);
    final checkHash = _fnv1a(eventId);
    final indices = _getIndices(eventId);
    for (final idx in indices) {
      buckets[idx].count -= 1;
      buckets[idx].keySum ^= keyHash;
      buckets[idx].hashSum ^= checkHash;
    }
  }

  /// Subtract another IBLT from this one (this - other)
  IBLT subtract(IBLT other) {
    final result = IBLT();
    for (int i = 0; i < bucketCount; i++) {
      result.buckets[i].count = buckets[i].count - other.buckets[i].count;
      result.buckets[i].keySum = buckets[i].keySum ^ other.buckets[i].keySum;
      result.buckets[i].hashSum = buckets[i].hashSum ^ other.buckets[i].hashSum;
    }
    return result;
  }

  /// Peel the IBLT to extract differences
  /// Returns null if peeling fails (too many differences, need Slow Path)
  IBLTPeelResult? peel() {
    final onlyInA = <int>{}; // keyHashes only in self
    final onlyInB = <int>{}; // keyHashes only in other

    // Create working copy
    final work = List.generate(bucketCount, (i) => IBLTBucket()
      ..count = buckets[i].count
      ..keySum = buckets[i].keySum
      ..hashSum = buckets[i].hashSum);

    bool changed = true;
    int iterations = 0;
    const maxIterations = 1000;

    while (changed && iterations < maxIterations) {
      changed = false;
      iterations++;
      for (int i = 0; i < bucketCount; i++) {
        if (work[i].count == 1) {
          // Pure cell: element only in A
          final key = work[i].keySum;
          final check = work[i].hashSum;
          if (_verifyChecksum(key, check)) {
            onlyInA.add(key);
            // Remove from all buckets that contain this key
            final indices = _getIndicesFromHash(key);
            for (final idx in indices) {
              work[idx].count -= 1;
              work[idx].keySum ^= key;
              work[idx].hashSum ^= check;
            }
            changed = true;
          }
        } else if (work[i].count == -1) {
          // Pure cell: element only in B
          final key = work[i].keySum;
          final check = work[i].hashSum;
          if (_verifyChecksum(key, check)) {
            onlyInB.add(key);
            final indices = _getIndicesFromHash(key);
            for (final idx in indices) {
              work[idx].count += 1;
              work[idx].keySum ^= key;
              work[idx].hashSum ^= check;
            }
            changed = true;
          }
        }
      }
    }

    // Check if fully peeled
    for (int i = 0; i < bucketCount; i++) {
      if (work[i].count != 0) return null; // Failed to peel
    }

    return IBLTPeelResult(onlyInA: onlyInA, onlyInB: onlyInB);
  }

  /// Serialize to bytes (504 bytes)
  Uint8List toBytes() {
    final data = ByteData(totalBytes);
    for (int i = 0; i < bucketCount; i++) {
      final offset = i * bucketSize;
      data.setInt8(offset, buckets[i].count);
      data.setUint32(offset + 1, buckets[i].keySum, Endian.little);
      data.setUint32(offset + 5, buckets[i].hashSum, Endian.little);
    }
    return data.buffer.asUint8List();
  }

  /// Deserialize from bytes
  static IBLT fromBytes(Uint8List bytes) {
    if (bytes.length < totalBytes) {
      throw ArgumentError('IBLT data too short: ${bytes.length} < $totalBytes');
    }
    final data = ByteData.sublistView(bytes);
    final buckets = <IBLTBucket>[];
    for (int i = 0; i < bucketCount; i++) {
      final offset = i * bucketSize;
      buckets.add(IBLTBucket()
        ..count = data.getInt8(offset)
        ..keySum = data.getUint32(offset + 1, Endian.little)
        ..hashSum = data.getUint32(offset + 5, Endian.little));
    }
    return IBLT._(buckets);
  }

  /// Get bucket indices for an event ID
  List<int> _getIndices(String eventId) {
    final bytes = eventId.codeUnits;
    return [
      _murmurHash(bytes, 0) % bucketCount,
      _murmurHash(bytes, 1) % bucketCount,
      _murmurHash(bytes, 2) % bucketCount,
    ];
  }

  /// Get bucket indices from a key hash
  List<int> _getIndicesFromHash(int keyHash) {
    return [
      ((keyHash) & 0xFFFF) % bucketCount,
      ((keyHash >> 8) & 0xFFFF) % bucketCount,
      ((keyHash >> 16) & 0xFFFF) % bucketCount,
    ];
  }

  /// Verify that keySum and hashSum match
  bool _verifyChecksum(int keySum, int hashSum) {
    // FNV-1a of the key bytes should match hashSum
    final keyBytes = ByteData(4)..setUint32(0, keySum, Endian.little);
    int h = 0x811c9dc5;
    for (int i = 0; i < 4; i++) {
      h ^= keyBytes.getUint8(i);
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h == hashSum;
  }

  // ── Hash Functions ──

  /// CRC32 for keySum
  static int _crc32(String s) {
    int crc = 0xFFFFFFFF;
    for (final b in s.codeUnits) {
      crc ^= b;
      for (int j = 0; j < 8; j++) {
        crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
      }
    }
    return crc ^ 0xFFFFFFFF;
  }

  /// FNV-1a for hashSum (checksum)
  static int _fnv1a(String s) {
    int h = 0x811c9dc5;
    for (final b in s.codeUnits) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  /// MurmurHash3-like for bucket index selection
  static int _murmurHash(List<int> bytes, int seed) {
    int h = seed & 0xFFFFFFFF;
    for (int i = 0; i < bytes.length; i++) {
      int k = bytes[i];
      k = (k * 0xcc9e2d51) & 0xFFFFFFFF;
      k = ((k << 15) | (k >> 17)) & 0xFFFFFFFF;
      k = (k * 0x1b873593) & 0xFFFFFFFF;
      h ^= k;
      h = ((h << 13) | (h >> 19)) & 0xFFFFFFFF;
      h = (h * 5 + 0xe6546b64) & 0xFFFFFFFF;
    }
    h ^= bytes.length;
    h ^= h >> 16;
    h = (h * 0x85ebca6b) & 0xFFFFFFFF;
    h ^= h >> 13;
    h = (h * 0xc2b2ae35) & 0xFFFFFFFF;
    h ^= h >> 16;
    return h;
  }
}

class IBLTBucket {
  int count = 0;    // signed byte (-128 to 127)
  int keySum = 0;   // uint32
  int hashSum = 0;  // uint32
}

class IBLTPeelResult {
  final Set<int> onlyInA; // keyHashes only in self (peer needs these)
  final Set<int> onlyInB; // keyHashes only in other (we need these)

  IBLTPeelResult({required this.onlyInA, required this.onlyInB});

  bool get isEmpty => onlyInA.isEmpty && onlyInB.isEmpty;
}
