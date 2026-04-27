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

import 'dart:convert';
import 'dart:typed_data';

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:google_cloud_firestore_v1/firestore.dart' as firestore_v1;
import 'package:google_cloud_protobuf/protobuf.dart' as protobuf_v1;
import 'package:test/test.dart';

const testBundleId = 'test-bundle';
const testBundleVersion = 1;
const databaseRoot = 'projects/test-project/databases/(default)';

/// Helper function to parse a length-prefixed bundle buffer into elements.
List<Map<String, dynamic>> bundleToElementArray(Uint8List buffer) {
  final elements = <Map<String, dynamic>>[];
  var offset = 0;
  final str = utf8.decode(buffer);

  while (offset < str.length) {
    // Read the length prefix
    final lengthBuffer = StringBuffer();
    while (offset < str.length &&
        str.codeUnitAt(offset) >= '0'.codeUnitAt(0) &&
        str.codeUnitAt(offset) <= '9'.codeUnitAt(0)) {
      lengthBuffer.write(str[offset]);
      offset++;
    }

    final lengthStr = lengthBuffer.toString();
    if (lengthStr.isEmpty) break;

    final length = int.parse(lengthStr);
    if (offset + length > str.length) break;

    // Read the JSON content
    final jsonStr = str.substring(offset, offset + length);
    offset += length;

    elements.add(jsonDecode(jsonStr) as Map<String, dynamic>);
  }

  return elements;
}

/// Verifies bundle metadata matches expected values.
void verifyMetadata(
  Map<String, dynamic> meta,
  Timestamp createTime,
  int totalDocuments, {
  bool expectEmptyContent = false,
}) {
  if (!expectEmptyContent) {
    expect(int.parse(meta['totalBytes'] as String), greaterThan(0));
  } else {
    expect(int.parse(meta['totalBytes'] as String), equals(0));
  }
  expect(meta['id'], equals(testBundleId));
  expect(meta['version'], equals(testBundleVersion));
  expect(meta['totalDocuments'], equals(totalDocuments));
  expect(
    meta['createTime'],
    equals({
      'seconds': createTime.seconds.toString(),
      'nanos': createTime.nanoseconds,
    }),
  );
}

void main() {
  group('Bundle Builder', () {
    late Firestore firestore;

    setUp(() {
      firestore = Firestore(
        settings: const Settings(projectId: 'test-project'),
      );
    });

    tearDown(() async {
      await firestore.terminate();
    });

    test('succeeds to read length prefixed json with testing function', () {
      const bundleString =
          '20{"a":"string value"}9{"b":123}26{"c":{"d":"nested value"}}';
      final elements = bundleToElementArray(
        Uint8List.fromList(bundleString.codeUnits),
      );
      expect(
        elements,
        equals([
          {'a': 'string value'},
          {'b': 123},
          {
            'c': {'d': 'nested value'},
          },
        ]),
      );
    });

    test('throws when bundleId is empty', () {
      expect(() => BundleBuilder(''), throwsA(isA<ArgumentError>()));
    });

    test('succeeds with document snapshots', () {
      final bundle = firestore.bundle(testBundleId);

      final snap1 = firestore.snapshot_(
        firestore_v1.Document(
          name: '$databaseRoot/documents/collectionId/doc1',
          fields: {
            'foo': firestore_v1.Value(stringValue: 'value'),
            'bar': firestore_v1.Value(integerValue: 42),
          },
          createTime: protobuf_v1.Timestamp(seconds: 1, nanos: 2000000),
          updateTime: protobuf_v1.Timestamp(seconds: 3, nanos: 4000),
        ),
        // This should be the bundle read time.
        Timestamp(seconds: 1577840405, nanoseconds: 6),
      );

      // Same document but older read time.
      final snap2 = firestore.snapshot_(
        firestore_v1.Document(
          name: '$databaseRoot/documents/collectionId/doc1',
          fields: {
            'foo': firestore_v1.Value(stringValue: 'value'),
            'bar': firestore_v1.Value(integerValue: -42),
          },
          createTime: protobuf_v1.Timestamp(seconds: 1, nanos: 2000000),
          updateTime: protobuf_v1.Timestamp(seconds: 3, nanos: 4000),
        ),
        Timestamp(seconds: 5, nanoseconds: 6),
      );

      bundle.addDocument(snap1);
      bundle.addDocument(snap2);

      final bundleBuffer = bundle.build();
      final elements = bundleToElementArray(bundleBuffer);

      expect(elements, hasLength(3));

      verifyMetadata(
        elements[0]['metadata'] as Map<String, dynamic>,
        Timestamp(seconds: 1577840405, nanoseconds: 6),
        1,
      );

      // Verify doc1Meta and doc1Snap
      final docMeta = elements[1]['documentMetadata'] as Map<String, dynamic>;
      expect(
        docMeta,
        equals({
          'name': '$databaseRoot/documents/collectionId/doc1',
          'exists': true,
          'readTime': {'seconds': '1577840405', 'nanos': 6},
        }),
      );

      // Verify doc1Meta and doc1Snap
      final docSnap = elements[2]['document'] as Map<String, dynamic>;
      expect(
        docSnap['name'],
        equals('$databaseRoot/documents/collectionId/doc1'),
      );
      expect(docSnap['fields'], isNotNull);
    });

    test('succeeds with query snapshots', () {
      // XXX - XXX - XXX - XXX - XXX - XXX
      final bundle = firestore.bundle(testBundleId);

      final snap =
          firestore.snapshot_(
                firestore_v1.Document(
                  name: '$databaseRoot/documents/collectionId/doc1',
                  fields: {'foo': firestore_v1.Value(stringValue: 'value')},
                  createTime: protobuf_v1.Timestamp(seconds: 1, nanos: 2000000),
                  updateTime: protobuf_v1.Timestamp(seconds: 3, nanos: 4000),
                ),
                Timestamp(seconds: 1577840405, nanoseconds: 6),
              )
              as QueryDocumentSnapshot<Object?>;

      final query = firestore.collection('collectionId').limit(1);
      final querySnapshot = firestore.querySnapshot_(
        query,
        Timestamp(seconds: 1577840405, nanoseconds: 6),
        [snap],
      );

      bundle.addQuery('query-name', querySnapshot);

      final bundleBuffer = bundle.build();
      final elements = bundleToElementArray(bundleBuffer);

      expect(elements, hasLength(4));

      verifyMetadata(
        elements[0]['metadata'] as Map<String, dynamic>,
        Timestamp(seconds: 1577840405, nanoseconds: 6),
        1,
      );

      // Verify docMeta and docSnap
      final namedQuery = elements[1]['namedQuery'] as Map<String, dynamic>;
      expect(namedQuery['name'], equals('query-name'));
      expect(namedQuery['readTime'], isNotNull);

      // 3. Document Metadata
      final docMeta = elements[2]['documentMetadata'] as Map<String, dynamic>;
      expect(
        docMeta['name'],
        equals('$databaseRoot/documents/collectionId/doc1'),
      );

      // 4. Document
      final docSnap = elements[3]['document'] as Map<String, dynamic>;
      expect(
        docSnap['name'],
        equals('$databaseRoot/documents/collectionId/doc1'),
      );
    });

    test('succeeds with multiple calls to build()', () {
      final bundle = firestore.bundle(testBundleId);

      final snap1 = firestore.snapshot_(
        firestore_v1.Document(
          name: '$databaseRoot/documents/collectionId/doc1',
          fields: {
            'foo': firestore_v1.Value(stringValue: 'value'),
            'bar': firestore_v1.Value(integerValue: 42),
          },
          createTime: protobuf_v1.Timestamp(seconds: 1, nanos: 2000000),
          updateTime: protobuf_v1.Timestamp(seconds: 3, nanos: 4000),
        ),
        Timestamp(seconds: 1577840405, nanoseconds: 6),
      );

      bundle.addDocument(snap1);

      final bundleBuffer1 = bundle.build();
      final elements1 = bundleToElementArray(bundleBuffer1);
      expect(elements1, hasLength(3));

      final doc1Meta = elements1[1]['documentMetadata'] as Map<String, dynamic>;
      expect(doc1Meta, containsPair('exists', true));
      expect(
        doc1Meta['name'],
        equals('$databaseRoot/documents/collectionId/doc1'),
      );

      // Add another document
      final snap2 = firestore.snapshot_(
        firestore_v1.Document(
          name: '$databaseRoot/documents/collectionId/doc2',
          fields: {
            'foo': firestore_v1.Value(stringValue: 'value'),
            'bar': firestore_v1.Value(integerValue: -42),
          },
          createTime: protobuf_v1.Timestamp(seconds: 1, nanos: 2000000),
          updateTime: protobuf_v1.Timestamp(seconds: 3, nanos: 4000),
        ),
        Timestamp(seconds: 5, nanoseconds: 6),
      );

      bundle.addDocument(snap2);

      final bundleBuffer2 = bundle.build();
      final elements2 = bundleToElementArray(bundleBuffer2);

      // metadata + (doc1Meta + doc1) + (doc2Meta + doc2)
      expect(elements2, hasLength(5));
      verifyMetadata(
        elements2[0]['metadata'] as Map<String, dynamic>,
        Timestamp(seconds: 1577840405, nanoseconds: 6),
        2,
      );
    });

    test('succeeds with empty content', () {
      final bundle = firestore.bundle(testBundleId);
      final bundleBuffer = bundle.build();

      final elements = bundleToElementArray(bundleBuffer);
      expect(elements, hasLength(1));

      verifyMetadata(
        elements[0]['metadata'] as Map<String, dynamic>,
        Timestamp(seconds: 0, nanoseconds: 0),
        0,
        expectEmptyContent: true,
      );
    });

    test('handles identical document id from different collections', () {
      final bundle = firestore.bundle(testBundleId);

      final snap1 = firestore.snapshot_(
        firestore_v1.Document(
          name: '$databaseRoot/documents/collectionId_A/doc1',
          fields: {
            'foo': firestore_v1.Value(stringValue: 'value'),
            'bar': firestore_v1.Value(integerValue: 42),
          },
          createTime: protobuf_v1.Timestamp(seconds: 1, nanos: 2000000),
          updateTime: protobuf_v1.Timestamp(seconds: 3, nanos: 4000),
        ),
        Timestamp(seconds: 1577840405, nanoseconds: 6),
      );

      // Same document id but different collection
      final snap2 = firestore.snapshot_(
        firestore_v1.Document(
          name: '$databaseRoot/documents/collectionId_B/doc1',
          fields: {
            'foo': firestore_v1.Value(stringValue: 'value'),
            'bar': firestore_v1.Value(integerValue: -42),
          },
          createTime: protobuf_v1.Timestamp(seconds: 1, nanos: 2000000),
          updateTime: protobuf_v1.Timestamp(seconds: 3, nanos: 4000),
        ),
        Timestamp(seconds: 5, nanoseconds: 6),
      );

      bundle.addDocument(snap1);
      bundle.addDocument(snap2);

      final bundleBuffer = bundle.build();
      final elements = bundleToElementArray(bundleBuffer);

      // metadata + (docA_Meta + docA) + (docB_Meta + docB)
      expect(elements, hasLength(5));

      verifyMetadata(
        elements[0]['metadata'] as Map<String, dynamic>,
        Timestamp(seconds: 1577840405, nanoseconds: 6),
        2,
      );

      expect(
        elements[1]['documentMetadata']['name'],
        equals('$databaseRoot/documents/collectionId_A/doc1'),
      );
      expect(
        elements[3]['documentMetadata']['name'],
        equals('$databaseRoot/documents/collectionId_B/doc1'),
      );
    });
  });
}
