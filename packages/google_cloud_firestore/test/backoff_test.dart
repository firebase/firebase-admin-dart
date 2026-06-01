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

import 'package:google_cloud_firestore/src/backoff.dart';
import 'package:test/test.dart';

void main() {
  group('ExponentialBackoff', () {
    test('first backoffAndWait() has no delay', () async {
      final backoff = ExponentialBackoff(
        options: const ExponentialBackoffSetting(
          initialDelayMs: 1000,
          jitterFactor: 0,
        ),
      );
      final before = DateTime.now();
      await backoff.backoffAndWait();
      final elapsedMs = DateTime.now().difference(before).inMilliseconds;
      expect(elapsedMs, lessThan(100));
    });

    test('respects the initial retry delay on second call', () async {
      final backoff = ExponentialBackoff(
        options: const ExponentialBackoffSetting(
          initialDelayMs: 50,
          backoffFactor: 2,
          maxDelayMs: 5000,
          jitterFactor: 0,
        ),
      );
      await backoff.backoffAndWait();

      final before = DateTime.now();
      await backoff.backoffAndWait();
      final elapsedMs = DateTime.now().difference(before).inMilliseconds;
      expect(elapsedMs, greaterThanOrEqualTo(50));
    });

    test('exponentially increases the delay', () async {
      final backoff = ExponentialBackoff(
        options: const ExponentialBackoffSetting(
          initialDelayMs: 10,
          backoffFactor: 2,
          maxDelayMs: 5000,
          jitterFactor: 0,
        ),
      );
      await backoff.backoffAndWait();
      await backoff.backoffAndWait();

      final before = DateTime.now();
      await backoff.backoffAndWait();
      final elapsedMs = DateTime.now().difference(before).inMilliseconds;
      expect(elapsedMs, greaterThanOrEqualTo(20));
    });

    test('delay increases until maximum then stays capped', () async {
      final backoff = ExponentialBackoff(
        options: const ExponentialBackoffSetting(
          initialDelayMs: 10,
          backoffFactor: 2,
          maxDelayMs: 35,
          jitterFactor: 0,
        ),
      );
      await backoff.backoffAndWait();
      await backoff.backoffAndWait();
      await backoff.backoffAndWait();

      final before = DateTime.now();
      await backoff.backoffAndWait();
      final elapsed = DateTime.now().difference(before).inMilliseconds;
      expect(elapsed, greaterThanOrEqualTo(35));

      final before2 = DateTime.now();
      await backoff.backoffAndWait();
      final elapsed2 = DateTime.now().difference(before2).inMilliseconds;
      expect(elapsed2, greaterThanOrEqualTo(35));
    });

    test('reset() resets delay and retry count to zero', () async {
      final backoff = ExponentialBackoff(
        options: const ExponentialBackoffSetting(
          initialDelayMs: 50,
          backoffFactor: 2,
          maxDelayMs: 5000,
          jitterFactor: 0,
        ),
      );
      await backoff.backoffAndWait();
      await backoff.backoffAndWait();

      backoff.reset();

      final before = DateTime.now();
      await backoff.backoffAndWait();
      final elapsedMs = DateTime.now().difference(before).inMilliseconds;
      expect(elapsedMs, lessThan(25));
    });

    test('resetToMax() causes next delay to use maxDelayMs', () async {
      final backoff = ExponentialBackoff(
        options: const ExponentialBackoffSetting(
          initialDelayMs: 10,
          backoffFactor: 2,
          maxDelayMs: 50,
          jitterFactor: 0,
        ),
      );
      await backoff.backoffAndWait();
      backoff.resetToMax();

      final before = DateTime.now();
      await backoff.backoffAndWait();
      final elapsedMs = DateTime.now().difference(before).inMilliseconds;
      expect(elapsedMs, greaterThanOrEqualTo(50));
    });

    test('applies jitter within expected variance bounds', () async {
      final backoff = ExponentialBackoff(
        options: const ExponentialBackoffSetting(
          initialDelayMs: 100,
          backoffFactor: 1,
          maxDelayMs: 100,
          jitterFactor: 0.5,
        ),
      );
      await backoff.backoffAndWait();

      final before = DateTime.now();
      await backoff.backoffAndWait();
      final elapsedMs = DateTime.now().difference(before).inMilliseconds;
      expect(elapsedMs, greaterThanOrEqualTo(50));
      expect(elapsedMs, lessThan(200));
    });

    test(
      'tracks retry attempts and throws after maxRetryAttempts+1 calls',
      () async {
        final backoff = ExponentialBackoff(
          options: const ExponentialBackoffSetting(
            initialDelayMs: 0,
            maxDelayMs: 0,
            jitterFactor: 0,
          ),
        );
        for (var i = 0; i <= ExponentialBackoff.maxRetryAttempts; i++) {
          await backoff.backoffAndWait();
        }
        await expectLater(
          backoff.backoffAndWait(),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Exceeded maximum number of retries'),
            ),
          ),
        );
      },
    );

    test('reset() clears retry count so attempts can start fresh', () async {
      final backoff = ExponentialBackoff(
        options: const ExponentialBackoffSetting(
          initialDelayMs: 0,
          maxDelayMs: 0,
          jitterFactor: 0,
        ),
      );
      for (var i = 0; i <= ExponentialBackoff.maxRetryAttempts; i++) {
        await backoff.backoffAndWait();
      }
      backoff.reset();
      await expectLater(backoff.backoffAndWait(), completes);
    });

    test('cannot queue two backoffAndWait() calls simultaneously', () async {
      final backoff = ExponentialBackoff(
        options: const ExponentialBackoffSetting(
          initialDelayMs: 50,
          backoffFactor: 1,
          maxDelayMs: 50,
          jitterFactor: 0,
        ),
      );
      await backoff.backoffAndWait();

      final future1 = backoff.backoffAndWait();
      expect(
        backoff.backoffAndWait,
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('already in progress'),
          ),
        ),
      );
      await future1;
    });
  });
}
