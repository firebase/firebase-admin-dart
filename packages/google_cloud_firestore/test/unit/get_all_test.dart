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
import 'package:google_cloud_firestore/src/firestore_http_client.dart';
import 'package:google_cloud_firestore_v1/firestore.dart' as firestore_v1;
import 'package:google_cloud_protobuf/protobuf.dart' as protobuf_v1;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

const projectId = 'test-project';

class MockFirestoreHttpClient extends Mock implements FirestoreHttpClient {}

firestore_v1.BatchGetDocumentsResponse createFoundResponse({
  required String documentPath,
  required Map<String, Object?> fields,
  required Firestore firestore,
}) {
  final now = protobuf_v1.Timestamp(
    seconds: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );
  return firestore_v1.BatchGetDocumentsResponse(
    found: firestore_v1.Document(
      name: 'projects/$projectId/databases/(default)/documents/$documentPath',
      fields: fields.map((key, value) {
        // Use SDK's serializer to properly encode values
        final encoded = firestore.serializer.encodeValue(value);
        return MapEntry(key, encoded!);
      }),
      createTime: now,
      updateTime: now,
    ),
    readTime: now,
  );
}

firestore_v1.BatchGetDocumentsResponse createMissingResponse(
  String documentPath,
) {
  final now = protobuf_v1.Timestamp(
    seconds: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );
  return firestore_v1.BatchGetDocumentsResponse(
    missing: 'projects/$projectId/databases/(default)/documents/$documentPath',
    readTime: now,
  );
}

void main() {
  group('Firestore.getAll()', () {
    late MockFirestoreHttpClient mockClient;
    late Firestore firestore;

    setUp(() {
      mockClient = MockFirestoreHttpClient();
      firestore = Firestore.internal(
        settings: const Settings(projectId: projectId),
        client: mockClient,
      );

      when(() => mockClient.cachedProjectId).thenReturn(projectId);
    });

    test('accepts single document', () async {
      when(
        () => mockClient.v1<Stream<firestore_v1.BatchGetDocumentsResponse>>(
          any(),
        ),
      ).thenAnswer((_) async {
        return Stream.fromIterable([
          createFoundResponse(
            documentPath: 'collectionId/documentId',
            fields: {'foo': 'bar'},
            firestore: firestore,
          ),
        ]);
      });

      final doc = firestore.doc('collectionId/documentId');
      final results = await firestore.getAll([doc]);

      expect(results, hasLength(1));
      expect(results[0].exists, isTrue);
      expect(results[0].id, 'documentId');
      expect(results[0].get('foo')?.value, 'bar');
    });

    test('accepts multiple documents', () async {
      when(
        () => mockClient.v1<Stream<firestore_v1.BatchGetDocumentsResponse>>(
          any(),
        ),
      ).thenAnswer((_) async {
        return Stream.fromIterable([
          createFoundResponse(
            documentPath: 'col/doc1',
            fields: {'a': 1},
            firestore: firestore,
          ),
          createFoundResponse(
            documentPath: 'col/doc2',
            fields: {'b': 2},
            firestore: firestore,
          ),
        ]);
      });

      final doc1 = firestore.doc('col/doc1');
      final doc2 = firestore.doc('col/doc2');
      final results = await firestore.getAll([doc1, doc2]);

      expect(results, hasLength(2));
      expect(results[0].exists, isTrue);
      expect(results[0].id, 'doc1');
      expect(results[0].get('a')?.value, 1);
      expect(results[1].exists, isTrue);
      expect(results[1].id, 'doc2');
      expect(results[1].get('b')?.value, 2);
    });

    test('returns missing documents', () async {
      when(
        () => mockClient.v1<Stream<firestore_v1.BatchGetDocumentsResponse>>(
          any(),
        ),
      ).thenAnswer((_) async {
        return Stream.fromIterable([createMissingResponse('col/missing')]);
      });

      final doc = firestore.doc('col/missing');
      final results = await firestore.getAll([doc]);

      expect(results, hasLength(1));
      expect(results[0].exists, isFalse);
      expect(results[0].id, 'missing');
    });

    test('handles mix of found and missing documents', () async {
      when(
        () => mockClient.v1<Stream<firestore_v1.BatchGetDocumentsResponse>>(
          any(),
        ),
      ).thenAnswer((_) async {
        return Stream.fromIterable([
          createFoundResponse(
            documentPath: 'col/found',
            fields: {'exists': true},
            firestore: firestore,
          ),
          createMissingResponse('col/missing'),
        ]);
      });

      final doc1 = firestore.doc('col/found');
      final doc2 = firestore.doc('col/missing');
      final results = await firestore.getAll([doc1, doc2]);

      expect(results, hasLength(2));
      expect(results[0].exists, isTrue);
      expect(results[0].get('exists')?.value, true);
      expect(results[1].exists, isFalse);
    });

    test('rejects empty array', () async {
      expect(
        () => firestore.getAll([]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('must not be an empty array'),
          ),
        ),
      );
    });

    test('verifies document order is preserved', () async {
      when(
        () => mockClient.v1<Stream<firestore_v1.BatchGetDocumentsResponse>>(
          any(),
        ),
      ).thenAnswer((_) async {
        // Return in different order than requested
        return Stream.fromIterable([
          createFoundResponse(
            documentPath: 'col/doc3',
            fields: {'n': 3},
            firestore: firestore,
          ),
          createFoundResponse(
            documentPath: 'col/doc1',
            fields: {'n': 1},
            firestore: firestore,
          ),
          createFoundResponse(
            documentPath: 'col/doc2',
            fields: {'n': 2},
            firestore: firestore,
          ),
        ]);
      });

      final doc1 = firestore.doc('col/doc1');
      final doc2 = firestore.doc('col/doc2');
      final doc3 = firestore.doc('col/doc3');
      final results = await firestore.getAll([doc1, doc2, doc3]);

      // Results should be in request order, not response order
      expect(results, hasLength(3));
      expect(results[0].id, 'doc1');
      expect(results[1].id, 'doc2');
      expect(results[2].id, 'doc3');
    });

    test('accepts same document multiple times', () async {
      when(
        () => mockClient.v1<Stream<firestore_v1.BatchGetDocumentsResponse>>(
          any(),
        ),
      ).thenAnswer((_) async {
        // Only returns unique documents
        return Stream.fromIterable([
          createFoundResponse(
            documentPath: 'col/a',
            fields: {'val': 'a'},
            firestore: firestore,
          ),
          createFoundResponse(
            documentPath: 'col/b',
            fields: {'val': 'b'},
            firestore: firestore,
          ),
        ]);
      });

      final docA = firestore.doc('col/a');
      final docB = firestore.doc('col/b');

      // Request same doc multiple times
      final results = await firestore.getAll([docA, docA, docB, docA]);

      // Results should include duplicates in request order
      expect(results, hasLength(4));
      expect(results[0].id, 'a');
      expect(results[1].id, 'a');
      expect(results[2].id, 'b');
      expect(results[3].id, 'a');
    });

    test('applies field mask with FieldPath', () async {
      when(
        () => mockClient.v1<Stream<firestore_v1.BatchGetDocumentsResponse>>(
          any(),
        ),
      ).thenAnswer((_) async {
        return Stream.fromIterable([
          createFoundResponse(
            documentPath: 'col/doc',
            fields: {'foo': 'included'},
            firestore: firestore,
          ),
        ]);
      });

      final doc = firestore.doc('col/doc');
      final results = await firestore.getAll(
        [doc],
        ReadOptions(
          fieldMask: [
            FieldMask.fieldPath(FieldPath(const ['foo', 'bar'])),
          ],
        ),
      );

      // Should return successfully with field mask
      expect(results, hasLength(1));
      expect(results[0].exists, isTrue);
    });

    test('applies field mask with strings', () async {
      when(
        () => mockClient.v1<Stream<firestore_v1.BatchGetDocumentsResponse>>(
          any(),
        ),
      ).thenAnswer((_) async {
        return Stream.fromIterable([
          createFoundResponse(
            documentPath: 'col/doc',
            fields: {'foo': 'bar'},
            firestore: firestore,
          ),
        ]);
      });

      final doc = firestore.doc('col/doc');
      final results = await firestore.getAll(
        [doc],
        ReadOptions(
          fieldMask: [FieldMask.field('foo'), FieldMask.field('bar.baz')],
        ),
      );

      // Should return successfully with field mask
      expect(results, hasLength(1));
      expect(results[0].get('foo')?.value, 'bar');
    });
  });
}
