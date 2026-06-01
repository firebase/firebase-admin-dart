// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:google_cloud_firestore/src/firestore.dart';
import 'package:test/test.dart';

void main() {
  group('RateLimiter', () {
    group('accepts and rejects requests based on capacity', () {
      test('initial available tokens equal the initial capacity', () {
        final limiter = RateLimiter(500, 1.5, 5 * 60 * 1000, 1000 * 1000);
        expect(limiter.availableTokens, closeTo(500, 1));
      });

      test('tryMakeRequest succeeds when within available capacity', () {
        final limiter = RateLimiter(500, 1.5, 5 * 60 * 1000, 1000 * 1000);
        expect(limiter.tryMakeRequest(500), isTrue);
      });

      test('tryMakeRequest deducts tokens from available balance', () {
        final limiter = RateLimiter(500, 1.5, 5 * 60 * 1000, 1000 * 1000);
        limiter.tryMakeRequest(200);
        expect(limiter.availableTokens, closeTo(300, 1));
      });

      test(
        'tryMakeRequest returns false when request exceeds available tokens',
        () {
          final limiter = RateLimiter(500, 1.5, 5 * 60 * 1000, 1000 * 1000);
          limiter.tryMakeRequest(500);
          expect(limiter.tryMakeRequest(1), isFalse);
        },
      );
    });

    group('getNextRequestDelayMs()', () {
      test('returns 0 when request is exactly equal to available tokens', () {
        final limiter = RateLimiter(500, 1.5, 5 * 60 * 1000, 1000 * 1000);
        expect(limiter.getNextRequestDelayMs(500), 0);
      });

      test('returns 0 when request is less than available tokens', () {
        final limiter = RateLimiter(500, 1.5, 5 * 60 * 1000, 1000 * 1000);
        expect(limiter.getNextRequestDelayMs(100), 0);
      });

      test('returns -1 when request exceeds maximum capacity', () {
        final limiter = RateLimiter(500, 1.5, 5 * 60 * 1000, 500);
        expect(limiter.getNextRequestDelayMs(501), -1);
      });
    });

    group('calculateCapacity()', () {
      test('maximumCapacity getter returns configured maximum', () {
        final limiter = RateLimiter(500, 1.5, 5 * 60 * 1000, 10000);
        expect(limiter.maximumCapacity, 10000);
      });

      test('maximumCapacity uses 500/50/5 default BulkWriter limits', () {
        final limiter = RateLimiter(500, 1.5, 5 * 60 * 1000, 10000);
        expect(limiter.maximumCapacity, 10000);
        expect(limiter.availableTokens, closeTo(500, 1));
      });
    });
  });
}
