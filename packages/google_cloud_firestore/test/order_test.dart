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

import 'dart:typed_data';

import 'package:google_cloud_firestore/src/firestore.dart';
import 'package:google_cloud_firestore_v1/firestore.dart' as firestore_v1;
import 'package:google_cloud_protobuf/protobuf.dart' as protobuf_v1;
import 'package:google_cloud_type/type.dart' as type_v1;
import 'package:test/test.dart';

void main() {
  group('Firestore Value Ordering', () {
    group('compare()', () {
      test('compares null values', () {
        final left = firestore_v1.Value(
          nullValue: protobuf_v1.NullValue.nullValue,
        );
        final right = firestore_v1.Value(
          nullValue: protobuf_v1.NullValue.nullValue,
        );
        expect(compare(left, right), equals(0));
      });

      test('compares boolean values', () {
        final falseValue = firestore_v1.Value(booleanValue: false);
        final trueValue = firestore_v1.Value(booleanValue: true);

        expect(compare(falseValue, trueValue), lessThan(0));
        expect(compare(trueValue, falseValue), greaterThan(0));
        expect(compare(falseValue, falseValue), equals(0));
      });

      test('compares integer values', () {
        final left = firestore_v1.Value(integerValue: 10);
        final right = firestore_v1.Value(integerValue: 20);

        expect(compare(left, right), lessThan(0));
        expect(compare(right, left), greaterThan(0));
        expect(compare(left, left), equals(0));
      });

      test('compares double values', () {
        final left = firestore_v1.Value(doubleValue: 1.5);
        final right = firestore_v1.Value(doubleValue: 2.5);

        expect(compare(left, right), lessThan(0));
        expect(compare(right, left), greaterThan(0));
        expect(compare(left, left), equals(0));
      });

      test('compares NaN values correctly', () {
        final nan1 = firestore_v1.Value(doubleValue: double.nan);
        final nan2 = firestore_v1.Value(doubleValue: double.nan);
        final regular = firestore_v1.Value(doubleValue: 1.0);

        // NaN == NaN
        expect(compare(nan1, nan2), equals(0));
        // NaN < regular number
        expect(compare(nan1, regular), lessThan(0));
        expect(compare(regular, nan1), greaterThan(0));
      });

      test('compares mixed integer and double values', () {
        final intValue = firestore_v1.Value(integerValue: 10);
        final doubleValue = firestore_v1.Value(doubleValue: 10.5);

        expect(compare(intValue, doubleValue), lessThan(0));
        expect(compare(doubleValue, intValue), greaterThan(0));
      });

      test('compares string values', () {
        final left = firestore_v1.Value(stringValue: 'abc');
        final right = firestore_v1.Value(stringValue: 'xyz');

        expect(compare(left, right), lessThan(0));
        expect(compare(right, left), greaterThan(0));
        expect(compare(left, left), equals(0));
      });

      test('compares timestamp values', () {
        final left = firestore_v1.Value(
          timestampValue: protobuf_v1.Timestamp(seconds: 1577836800),
        ); // 2020-01-01
        final right = firestore_v1.Value(
          timestampValue: protobuf_v1.Timestamp(seconds: 1609459200),
        ); // 2021-01-01

        expect(compare(left, right), lessThan(0));
        expect(compare(right, left), greaterThan(0));
        expect(compare(left, left), equals(0));
      });

      test('compares reference values', () {
        final left = firestore_v1.Value(
          referenceValue:
              'projects/test/databases/kDefaultDatabase/documents/coll/doc1',
        );
        final right = firestore_v1.Value(
          referenceValue:
              'projects/test/databases/kDefaultDatabase/documents/coll/doc2',
        );

        expect(compare(left, right), lessThan(0));
        expect(compare(right, left), greaterThan(0));
        expect(compare(left, left), equals(0));
      });

      test('compares blob values', () {
        final left = firestore_v1.Value(
          bytesValue: Uint8List.fromList([97, 98, 99]),
        ); // "abc"
        final right = firestore_v1.Value(
          bytesValue: Uint8List.fromList([120, 121, 122]),
        ); // "xyz"

        expect(compare(left, right), lessThan(0));
        expect(compare(right, left), greaterThan(0));
        expect(compare(left, left), equals(0));
      });

      test('compares geopoint values', () {
        final left = firestore_v1.Value(
          geoPointValue: type_v1.LatLng(latitude: 37.7, longitude: -122.4),
        );
        final right = firestore_v1.Value(
          geoPointValue: type_v1.LatLng(latitude: 37.8, longitude: -122.4),
        );

        expect(compare(left, right), lessThan(0));
        expect(compare(right, left), greaterThan(0));
        expect(compare(left, left), equals(0));
      });

      test('compares array values', () {
        final left = firestore_v1.Value(
          arrayValue: firestore_v1.ArrayValue(
            values: [
              firestore_v1.Value(integerValue: 1),
              firestore_v1.Value(integerValue: 2),
            ],
          ),
        );
        final right = firestore_v1.Value(
          arrayValue: firestore_v1.ArrayValue(
            values: [
              firestore_v1.Value(integerValue: 1),
              firestore_v1.Value(integerValue: 3),
            ],
          ),
        );

        expect(compare(left, right), lessThan(0));
        expect(compare(right, left), greaterThan(0));
        expect(compare(left, left), equals(0));
      });

      test('compares array values of different lengths', () {
        final shorter = firestore_v1.Value(
          arrayValue: firestore_v1.ArrayValue(
            values: [firestore_v1.Value(integerValue: 1)],
          ),
        );
        final longer = firestore_v1.Value(
          arrayValue: firestore_v1.ArrayValue(
            values: [
              firestore_v1.Value(integerValue: 1),
              firestore_v1.Value(integerValue: 2),
            ],
          ),
        );

        expect(compare(shorter, longer), lessThan(0));
        expect(compare(longer, shorter), greaterThan(0));
      });

      test('compares map values', () {
        final left = firestore_v1.Value(
          mapValue: firestore_v1.MapValue(
            fields: {
              'a': firestore_v1.Value(integerValue: 1),
              'b': firestore_v1.Value(integerValue: 2),
            },
          ),
        );
        final right = firestore_v1.Value(
          mapValue: firestore_v1.MapValue(
            fields: {
              'a': firestore_v1.Value(integerValue: 1),
              'b': firestore_v1.Value(integerValue: 3),
            },
          ),
        );

        expect(compare(left, right), lessThan(0));
        expect(compare(right, left), greaterThan(0));
        expect(compare(left, left), equals(0));
      });

      test('cross-type ordering', () {
        final nullValue = firestore_v1.Value(
          nullValue: protobuf_v1.NullValue.nullValue,
        );
        final boolValue = firestore_v1.Value(booleanValue: true);
        final numberValue = firestore_v1.Value(integerValue: 1);
        final timestampValue = firestore_v1.Value(
          timestampValue: protobuf_v1.Timestamp(seconds: 1609459200),
        );
        final stringValue = firestore_v1.Value(stringValue: 'a');
        final blobValue = firestore_v1.Value(
          bytesValue: Uint8List.fromList([97, 98, 99]),
        );
        final refValue = firestore_v1.Value(referenceValue: 'ref/1');
        final geoValue = firestore_v1.Value(
          geoPointValue: type_v1.LatLng(latitude: 0, longitude: 0),
        );
        final arrayValue = firestore_v1.Value(
          arrayValue: firestore_v1.ArrayValue(values: []),
        );
        final mapValue = firestore_v1.Value(
          mapValue: firestore_v1.MapValue(fields: {}),
        );

        expect(compare(nullValue, boolValue), lessThan(0));
        expect(compare(boolValue, numberValue), lessThan(0));
        expect(compare(numberValue, timestampValue), lessThan(0));
        expect(compare(timestampValue, stringValue), lessThan(0));
        expect(compare(stringValue, blobValue), lessThan(0));
        expect(compare(blobValue, refValue), lessThan(0));
        expect(compare(refValue, geoValue), lessThan(0));
        expect(compare(geoValue, arrayValue), lessThan(0));
        expect(compare(arrayValue, mapValue), lessThan(0));
      });

      test('compares strings using UTF-8 lexicographical order', () {
        // "𐐷" is U+10437, UTF-16: 0xD801 0xDC37, UTF-8: 0xF0 0x90 0x90 0xB7
        // "ÿ" is U+00FF, UTF-16: 0x00FF, UTF-8: 0xC3 0xBF
        final emoji = firestore_v1.Value(stringValue: '𐐷');
        final replacement = firestore_v1.Value(stringValue: 'ÿ');

        expect(compare(replacement, emoji), lessThan(0));

        final str1 = firestore_v1.Value(stringValue: 'a');
        final str2 = firestore_v1.Value(stringValue: 'b');
        expect(compare(str1, str2), lessThan(0));
      });
    });

    group('compareArrays()', () {
      test('compares arrays element by element', () {
        final left = [
          firestore_v1.Value(integerValue: 1),
          firestore_v1.Value(integerValue: 2),
        ];
        final right = [
          firestore_v1.Value(integerValue: 1),
          firestore_v1.Value(integerValue: 3),
        ];

        expect(compareArrays(left, right), lessThan(0));
        expect(compareArrays(right, left), greaterThan(0));
        expect(compareArrays(left, left), equals(0));
      });

      test('compares empty and non-empty arrays', () {
        final empty = <firestore_v1.Value>[];
        final nonEmpty = [firestore_v1.Value(integerValue: 1)];

        expect(compareArrays(empty, empty), equals(0));
        expect(compareArrays(empty, nonEmpty), lessThan(0));
        expect(compareArrays(nonEmpty, empty), greaterThan(0));
      });

      test('compares nested arrays', () {
        final partition1 = [
          firestore_v1.Value(
            arrayValue: firestore_v1.ArrayValue(
              values: [firestore_v1.Value(integerValue: 1)],
            ),
          ),
        ];
        final partition2 = [
          firestore_v1.Value(
            arrayValue: firestore_v1.ArrayValue(
              values: [firestore_v1.Value(integerValue: 2)],
            ),
          ),
        ];

        expect(compareArrays(partition1, partition2), lessThan(0));
        expect(compareArrays(partition2, partition1), greaterThan(0));
      });
    });
  });
}
