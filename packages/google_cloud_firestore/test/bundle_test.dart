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

import 'fixtures/helpers.dart';

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

      final elements = bundleToElementArray(bundle.build());
      expect(elements.length, equals(3));

      final meta = elements[0]['metadata'] as Map<String, dynamic>;
      verifyMetadata(meta, snap1.readTime!, 1);

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

      final elements = bundleToElementArray(bundle.build());
      expect(elements.length, equals(3));

      final meta = elements[0]['metadata'] as Map<String, dynamic>;
      verifyMetadata(meta, snap1.readTime!, 1);

      // Verify doc1Meta and doc1Snap
      final doc1Meta = elements[1]['documentMetadata'] as Map<String, dynamic>;
      final doc1Snap = elements[2]['document'] as Map<String, dynamic>;
      expect(
        doc1Meta,
        equals({
          'name': '$databaseRoot/documents/collectionId/doc1',
          'readTime': {
            'seconds': snap1.readTime!.seconds.toString(),
            'nanos': snap1.readTime!.nanoseconds,
          },
          'exists': true,
        }),
      );
      expect(
        doc1Snap['name'],
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

    test('succeeds when nothing is added', () {
      final bundle = firestore.bundle(testBundleId);

      final elements = bundleToElementArray(bundle.build());
      expect(elements.length, equals(1));

      final meta = elements[0]['metadata'] as Map<String, dynamic>;
      verifyMetadata(
        meta,
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
        (elements[1]['documentMetadata'] as Map<String, dynamic>)['name'],
        equals('$databaseRoot/documents/collectionId_A/doc1'),
      );
      expect(
        (elements[3]['documentMetadata'] as Map<String, dynamic>)['name'],
        equals('$databaseRoot/documents/collectionId_B/doc1'),
      );
    });
  });

  group('BundleBuilder Integration Tests', () {
    late Firestore firestore;

    setUp(() async {
      firestore = await createFirestore();
    });

    test('succeeds with document snapshots', () async {
      final bundle = BundleBuilder(testBundleId);

      // Create test documents
      final doc1Ref = firestore.collection('test-bundle').doc('doc1');
      await doc1Ref.set({'foo': 'value', 'bar': 42});

      final doc2Ref = firestore.collection('test-bundle').doc('doc2');
      await doc2Ref.set({'baz': 'other-value', 'qux': -42});

      // Get snapshots
      final snap1 = await doc1Ref.get();
      final snap2 = await doc2Ref.get();

      // Add to bundle
      bundle.addDocument(snap1);
      bundle.addDocument(snap2);

      // Build and verify
      final elements = bundleToElementArray(bundle.build());

      // Should have: metadata + (doc1Meta + doc1) + (doc2Meta + doc2) = 5 elements
      expect(elements.length, equals(5));

      // Verify metadata
      final meta = elements[0]['metadata'] as Map<String, dynamic>;
      expect(meta['id'], equals(testBundleId));
      expect(meta['version'], equals(testBundleVersion));
      expect(meta['totalDocuments'], equals(2));
      expect(int.parse(meta['totalBytes'] as String), greaterThan(0));

      // Verify documents are present
      final docNames = elements
          .where((e) => e.containsKey('document'))
          .map((e) => (e['document'] as Map<String, dynamic>)['name'])
          .toList();

      expect(docNames.length, equals(2));

      // Clean up
      await doc1Ref.delete();
      await doc2Ref.delete();
    });

    test('succeeds with query snapshots', () async {
      final bundle = BundleBuilder(testBundleId);

      // Create test documents
      final collection = firestore.collection('test-bundle-query');
      await collection.doc('doc1').set({'value': 'test', 'count': 1});
      await collection.doc('doc2').set({'value': 'test', 'count': 2});
      await collection.doc('doc3').set({'value': 'other', 'count': 3});

      // Create query
      final query = collection.where('value', WhereFilter.equal, 'test');
      final querySnapshot = await query.get();

      // Add query to bundle
      bundle.addQuery('test-query', querySnapshot);

      // Build and verify
      final elements = bundleToElementArray(bundle.build());

      // Should have: metadata + namedQuery + (doc1Meta + doc1) + (doc2Meta + doc2) = 6 elements
      expect(elements.length, equals(6));

      // Verify named query exists
      final namedQuery =
          elements.firstWhere((e) => e.containsKey('namedQuery'))['namedQuery']
              as Map<String, dynamic>;

      expect(namedQuery['name'], equals('test-query'));

      // Verify documents have queries array
      final docsWithQueries = elements
          .where(
            (e) =>
                e.containsKey('documentMetadata') &&
                (e['documentMetadata'] as Map<String, dynamic>).containsKey(
                  'queries',
                ),
          )
          .toList();

      expect(docsWithQueries.length, equals(2));

      for (final doc in docsWithQueries) {
        final queries =
            (doc['documentMetadata'] as Map<String, dynamic>)['queries']
                as List;
        expect(queries, contains('test-query'));
      }

      // Clean up
      await collection.doc('doc1').delete();
      await collection.doc('doc2').delete();
      await collection.doc('doc3').delete();
    });

    test('handles same document from multiple queries', () async {
      final bundle = BundleBuilder(testBundleId);

      // Create test document
      final collection = firestore.collection('test-bundle-multi-query');
      await collection.doc('doc1').set({'value': 'test', 'count': 10});

      // Create two queries that both include the same document
      final query1 = collection.where('value', WhereFilter.equal, 'test');
      final query2 = collection.where(
        'count',
        WhereFilter.greaterThanOrEqual,
        5,
      );

      final querySnapshot1 = await query1.get();
      final querySnapshot2 = await query2.get();

      // Add both queries
      bundle.addQuery('query1', querySnapshot1);
      bundle.addQuery('query2', querySnapshot2);

      // Build and verify
      final elements = bundleToElementArray(bundle.build());

      // Verify the document metadata has both queries
      final docMeta =
          elements.firstWhere(
                (e) => e.containsKey('documentMetadata'),
              )['documentMetadata']
              as Map<String, dynamic>;

      final queries = List<String>.from(docMeta['queries'] as List);
      queries.sort();
      expect(queries, equals(['query1', 'query2']));

      // Should only have one document element (not duplicated)
      final docCount = elements.where((e) => e.containsKey('document')).length;
      expect(docCount, equals(1));

      // Clean up
      await collection.doc('doc1').delete();
    });

    test('throws when query name already exists', () async {
      final bundle = BundleBuilder(testBundleId);

      final collection = firestore.collection('test-bundle-duplicate');
      await collection.doc('doc1').set({'value': 'test'});

      final query = collection.where('value', WhereFilter.equal, 'test');
      final querySnapshot = await query.get();

      bundle.addQuery('duplicate-name', querySnapshot);

      expect(
        () => bundle.addQuery('duplicate-name', querySnapshot),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Query name conflict'),
          ),
        ),
      );

      // Clean up
      await collection.doc('doc1').delete();
    });

    test('handles non-existent documents', () async {
      final bundle = BundleBuilder(testBundleId);

      // Get a non-existent document
      final docRef = firestore.collection('test-bundle').doc('non-existent');
      final snap = await docRef.get();

      expect(snap.exists, isFalse);

      // Add to bundle
      bundle.addDocument(snap);

      // Build and verify
      final elements = bundleToElementArray(bundle.build());

      // Should have: metadata + docMeta (no document since it doesn't exist)
      expect(elements.length, equals(2));

      final docMeta = elements[1]['documentMetadata'] as Map<String, dynamic>;
      expect(docMeta['exists'], equals(false));

      // Should not have a document element
      final hasDocument = elements.any((e) => e.containsKey('document'));
      expect(hasDocument, isFalse);
    });

    test('handles documents from different collections with same ID', () async {
      final bundle = BundleBuilder(testBundleId);

      // Create documents with same ID in different collections
      final doc1Ref = firestore.collection('collectionA').doc('same-id');
      await doc1Ref.set({'source': 'A'});

      final doc2Ref = firestore.collection('collectionB').doc('same-id');
      await doc2Ref.set({'source': 'B'});

      // Get snapshots
      final snap1 = await doc1Ref.get();
      final snap2 = await doc2Ref.get();

      // Add to bundle
      bundle.addDocument(snap1);
      bundle.addDocument(snap2);

      // Build and verify
      final elements = bundleToElementArray(bundle.build());

      // Should have both documents
      final docs = elements
          .where((e) => e.containsKey('document'))
          .map((e) => e['document'] as Map<String, dynamic>)
          .toList();

      expect(docs.length, equals(2));

      // Verify they have different paths
      final paths = docs.map((d) => d['name']).toSet();
      expect(paths.length, equals(2));

      // Clean up
      await doc1Ref.delete();
      await doc2Ref.delete();
    });
  }, tags: 'firebase-emulator');
}
