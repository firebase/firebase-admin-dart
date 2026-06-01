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
  group('FieldValue', () {
    group('increment()', () {
      test('creates increment transform with positive value', () {
        const increment = FieldValue.increment(1);
        expect(increment, isA<FieldValue>());
      });

      test('creates increment transform with negative value', () {
        const increment = FieldValue.increment(-1);
        expect(increment, isA<FieldValue>());
      });

      test('creates increment transform with floating point value', () {
        const increment = FieldValue.increment(1.5);
        expect(increment, isA<FieldValue>());
      });

      test('creates increment transform with zero', () {
        const increment = FieldValue.increment(0);
        expect(increment, isA<FieldValue>());
      });
    });

    group('arrayUnion()', () {
      test('creates array union transform with single element', () {
        const arrayUnion = FieldValue.arrayUnion(['foo']);
        expect(arrayUnion, isA<FieldValue>());
      });

      test('creates array union transform with multiple elements', () {
        const arrayUnion = FieldValue.arrayUnion(['foo', 'bar']);
        expect(arrayUnion, isA<FieldValue>());
      });

      test('creates array union transform with empty array', () {
        const arrayUnion = FieldValue.arrayUnion([]);
        expect(arrayUnion, isA<FieldValue>());
      });

      test('creates array union transform with mixed types', () {
        const arrayUnion = FieldValue.arrayUnion(['foo', 1, true, null]);
        expect(arrayUnion, isA<FieldValue>());
      });
    });

    group('arrayRemove()', () {
      test('creates array remove transform with single element', () {
        const arrayRemove = FieldValue.arrayRemove(['foo']);
        expect(arrayRemove, isA<FieldValue>());
      });

      test('creates array remove transform with multiple elements', () {
        const arrayRemove = FieldValue.arrayRemove(['foo', 'bar']);
        expect(arrayRemove, isA<FieldValue>());
      });

      test('creates array remove transform with empty array', () {
        const arrayRemove = FieldValue.arrayRemove([]);
        expect(arrayRemove, isA<FieldValue>());
      });

      test('creates array remove transform with mixed types', () {
        const arrayRemove = FieldValue.arrayRemove(['foo', 1, true, null]);
        expect(arrayRemove, isA<FieldValue>());
      });
    });

    group('delete', () {
      test('is a FieldValue sentinel', () {
        expect(FieldValue.delete, isA<FieldValue>());
      });

      test('returns same instance', () {
        const delete1 = FieldValue.delete;
        const delete2 = FieldValue.delete;
        expect(identical(delete1, delete2), isTrue);
      });
    });

    group('serverTimestamp', () {
      test('is a FieldValue sentinel', () {
        expect(FieldValue.serverTimestamp, isA<FieldValue>());
      });

      test('returns same instance', () {
        const timestamp1 = FieldValue.serverTimestamp;
        const timestamp2 = FieldValue.serverTimestamp;
        expect(identical(timestamp1, timestamp2), isTrue);
      });
    });

    group('vector()', () {
      test('creates VectorValue with valid array', () {
        final vector = FieldValue.vector([1.0, 2.0, 3.0]);
        expect(vector, isA<VectorValue>());
      });

      test('creates VectorValue with empty array', () {
        final vector = FieldValue.vector([]);
        expect(vector, isA<VectorValue>());
      });

      test('creates VectorValue with single element', () {
        final vector = FieldValue.vector([1.0]);
        expect(vector, isA<VectorValue>());
      });

      test('VectorValue.toArray() returns copy of values', () {
        final vector = FieldValue.vector([1.0, 2.0, 3.0]);
        final array = vector.toArray();
        expect(array, [1.0, 2.0, 3.0]);
      });

      test('VectorValue.toArray() returns independent copy', () {
        final vector = FieldValue.vector([1.0, 2.0, 3.0]);
        final array = vector.toArray();
        array[0] = 999.0;
        // Original vector should not be affected
        expect(vector.toArray(), [1.0, 2.0, 3.0]);
      });

      test('VectorValue.isEqual() compares values', () {
        final vector1 = FieldValue.vector([1.0, 2.0, 3.0]);
        final vector2 = FieldValue.vector([1.0, 2.0, 3.0]);
        final vector3 = FieldValue.vector([1.0, 2.0, 4.0]);

        expect(vector1.isEqual(vector2), isTrue);
        expect(vector1.isEqual(vector3), isFalse);
      });

      test('VectorValue.isEqual() returns false for different lengths', () {
        final vector1 = FieldValue.vector([1.0, 2.0]);
        final vector2 = FieldValue.vector([1.0, 2.0, 3.0]);

        expect(vector1.isEqual(vector2), isFalse);
      });

      test('VectorValue equality operator works', () {
        final vector1 = FieldValue.vector([1.0, 2.0, 3.0]);
        final vector2 = FieldValue.vector([1.0, 2.0, 3.0]);
        final vector3 = FieldValue.vector([1.0, 2.0, 4.0]);

        expect(vector1 == vector2, isTrue);
        expect(vector1 == vector3, isFalse);
      });
    });
  });
}
