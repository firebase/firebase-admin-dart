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

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

void main() {
  group('Timestamp', () {
    test('constructor', () {
      final now = DateTime.now().toUtc();
      final seconds = now.millisecondsSinceEpoch ~/ 1000;
      final nanoseconds =
          (now.microsecondsSinceEpoch - seconds * 1000 * 1000) * 1000;

      expect(
        Timestamp(seconds: seconds, nanoseconds: nanoseconds),
        Timestamp.fromDate(now),
      );
    });

    test('fromDate constructor', () {
      final now = DateTime.now().toUtc();
      final timestamp = Timestamp.fromDate(now);

      expect(timestamp.seconds, now.millisecondsSinceEpoch ~/ 1000);
    });

    test('fromMillis constructor', () {
      final now = DateTime.now().toUtc();
      final timestamp = Timestamp.fromMillis(now.millisecondsSinceEpoch);

      expect(timestamp.seconds, now.millisecondsSinceEpoch ~/ 1000);
      expect(
        timestamp.nanoseconds,
        (now.millisecondsSinceEpoch % 1000) * (1000 * 1000),
      );
    });

    test('fromMicros constructor', () {
      final now = DateTime.now().toUtc();
      final timestamp = Timestamp.fromMicros(now.microsecondsSinceEpoch);

      expect(timestamp.seconds, now.microsecondsSinceEpoch ~/ (1000 * 1000));
      expect(
        timestamp.nanoseconds,
        (now.microsecondsSinceEpoch % (1000 * 1000)) * 1000,
      );
    });

    test('toDate() converts to DateTime with millisecond precision', () {
      // Test with specific values
      final timestamp = Timestamp(seconds: -14182920, nanoseconds: 123000000);
      final date = timestamp.toDate();

      expect(date.millisecondsSinceEpoch, -14182920 * 1000 + 123);
      expect(date.isUtc, true);
    });

    test('toDate() rounds nanoseconds correctly', () {
      // Test rounding: 500000 nanoseconds = 0.5 milliseconds, should round to 1ms
      final timestamp1 = Timestamp(seconds: 1234567890, nanoseconds: 500000);
      final date1 = timestamp1.toDate();
      expect(date1.millisecondsSinceEpoch, 1234567890001);

      // Test rounding: 400000 nanoseconds = 0.4 milliseconds, should round to 0ms
      final timestamp2 = Timestamp(seconds: 1234567890, nanoseconds: 400000);
      final date2 = timestamp2.toDate();
      expect(date2.millisecondsSinceEpoch, 1234567890000);
    });

    test('toMillis() returns milliseconds since epoch', () {
      final timestamp = Timestamp(seconds: -14182920, nanoseconds: 123000000);
      expect(timestamp.toMillis(), -14182920 * 1000 + 123);
    });

    test('toMillis() floors nanoseconds to millisecond', () {
      // 999999 nanoseconds = 0.999999 milliseconds, should floor to 0ms
      final timestamp = Timestamp(seconds: 1234567890, nanoseconds: 999999);
      expect(timestamp.toMillis(), 1234567890000);
    });

    test('toDate() and fromDate() roundtrip', () {
      // Use millisecond precision to avoid microsecond truncation issues
      final millis = DateTime.now().millisecondsSinceEpoch;
      final now = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      final timestamp = Timestamp.fromDate(now);
      final converted = timestamp.toDate();

      // Should be equal at millisecond precision
      expect(converted.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });

    test('toMillis() and fromMillis() roundtrip', () {
      final millis = DateTime.now().millisecondsSinceEpoch;
      final timestamp = Timestamp.fromMillis(millis);
      expect(timestamp.toMillis(), millis);
    });
  });
}
