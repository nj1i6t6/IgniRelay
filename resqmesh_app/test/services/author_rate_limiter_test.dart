// v0.3 Stage 0c — author rate limiter (token bucket per spec §13.7).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/mesh/mesh_constants.dart';
import 'package:ignirelay_app/app/services/author_rate_limiter.dart';

void main() {
  final author = Uint8List.fromList(List.generate(32, (i) => 0xC0 | i));
  final otherAuthor = Uint8List.fromList(List.generate(32, (i) => 0x40 | i));

  test('first envelope from a new author is accepted', () {
    final rl = AuthorRateLimiter();
    expect(rl.tryAccept(author), true);
  });

  test('burst up to bucket capacity is accepted; next is rejected', () {
    // Use a tiny bucket and refill rate of zero so the test is deterministic.
    final rl = AuthorRateLimiter(capacity: 3, perSecond: 0.0);
    final t0 = DateTime.fromMillisecondsSinceEpoch(1000000);
    expect(rl.tryAccept(author, now: t0), true);
    expect(rl.tryAccept(author, now: t0), true);
    expect(rl.tryAccept(author, now: t0), true);
    expect(rl.tryAccept(author, now: t0), false, reason: 'capacity exhausted');
  });

  test('refill restores tokens proportional to elapsed time', () {
    // 1 token per second; capacity 3; burn all 3, then wait 2 s → 2 accepts.
    final rl = AuthorRateLimiter(capacity: 3, perSecond: 1.0);
    final t0 = DateTime.fromMillisecondsSinceEpoch(1000000);
    expect(rl.tryAccept(author, now: t0), true);
    expect(rl.tryAccept(author, now: t0), true);
    expect(rl.tryAccept(author, now: t0), true);
    expect(rl.tryAccept(author, now: t0), false);

    final t1 = t0.add(const Duration(seconds: 2));
    expect(rl.tryAccept(author, now: t1), true);
    expect(rl.tryAccept(author, now: t1), true);
    expect(rl.tryAccept(author, now: t1), false);
  });

  test('per-author isolation', () {
    final rl = AuthorRateLimiter(capacity: 1, perSecond: 0.0);
    final t0 = DateTime.fromMillisecondsSinceEpoch(1000000);
    expect(rl.tryAccept(author, now: t0), true);
    expect(rl.tryAccept(author, now: t0), false);
    // Different author still has its own bucket.
    expect(rl.tryAccept(otherAuthor, now: t0), true);
    expect(rl.tryAccept(otherAuthor, now: t0), false);
  });

  test('default ctor uses spec constants', () {
    final rl = AuthorRateLimiter();
    expect(rl.capacity, kAuthorRateLimitBucketSize);
    expect(
      rl.tokensPerSecond,
      closeTo(kMaxEnvelopesPerAuthorPerHour / 3600.0, 1e-9),
    );
  });
}
