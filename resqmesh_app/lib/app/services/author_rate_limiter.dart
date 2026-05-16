// Per-author rate limiter (v0.3 Stage 0c).
//
// Spec: docs/specs/envelope_v2_spec_2026-05-13.md §13.7.
//
// Token bucket per `author_key`: refill rate = MAX_ENVELOPES_PER_AUTHOR_PER_HOUR
// over 1 hour, capacity = AUTHOR_RATE_LIMIT_BUCKET_SIZE. Receivers drop excess
// envelopes with `drop_reason = author-rate-limited` BEFORE inserting into
// `Envelopes_V2` so the tombstone count cannot be inflated by a flood.
//
// In-memory only (intentionally — survives only for the foreground service
// session; cold-start grace is acceptable per spec §13.7).

import 'dart:typed_data';

import 'package:ignirelay_app/app/mesh/mesh_constants.dart';

class _Bucket {
  double tokens;
  DateTime lastRefill;

  _Bucket(this.tokens, this.lastRefill);
}

class AuthorRateLimiter {
  /// Bucket capacity (max burst). Default per `kAuthorRateLimitBucketSize`.
  final int capacity;

  /// Steady-state tokens per second. Default per
  /// `kMaxEnvelopesPerAuthorPerHour / 3600`.
  final double tokensPerSecond;

  final Map<String, _Bucket> _buckets = <String, _Bucket>{};

  AuthorRateLimiter({
    this.capacity = kAuthorRateLimitBucketSize,
    double? perSecond,
  }) : tokensPerSecond = perSecond ?? (kMaxEnvelopesPerAuthorPerHour / 3600.0);

  /// Try to consume one token for [authorKey]. Returns true on accept;
  /// false when the limiter would drop the envelope.
  bool tryAccept(Uint8List authorKey, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final key = _hex(authorKey);
    final bucket = _buckets[key];
    if (bucket == null) {
      _buckets[key] = _Bucket(capacity - 1.0, clock);
      return true;
    }
    final elapsedSec = clock.difference(bucket.lastRefill).inMicroseconds / 1e6;
    final refill = elapsedSec * tokensPerSecond;
    bucket.tokens = (bucket.tokens + refill).clamp(0.0, capacity.toDouble());
    bucket.lastRefill = clock;
    if (bucket.tokens >= 1.0) {
      bucket.tokens -= 1.0;
      return true;
    }
    return false;
  }

  /// Drop tracking state for an author (testing / reset).
  void forget(Uint8List authorKey) {
    _buckets.remove(_hex(authorKey));
  }

  /// Total authors currently being tracked (for diagnostics).
  int get trackedAuthors => _buckets.length;

  static String _hex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
