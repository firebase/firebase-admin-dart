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

import 'fixtures/helpers.dart' as helpers;

const _unitTestProjectId = 'test-project';

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
      name:
          'projects/$_unitTestProjectId/databases/(default)/documents/$documentPath',
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
    missing:
        'projects/$_unitTestProjectId/databases/(default)/documents/$documentPath',
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
        settings: const Settings(projectId: _unitTestProjectId),
        client: mockClient,
      );

      when(() => mockClient.cachedProjectId).thenReturn(_unitTestProjectId);
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

  group('Firestore.getAll() Integration Tests', () {
    late Firestore firestore;

    setUp(() async {
      firestore = await helpers.createFirestore();
    });

    Future<DocumentReference<Map<String, dynamic>>> initializeTest(
      String path,
    ) async {
      final prefixedPath = 'flutter-tests/$path';
      await firestore.doc(prefixedPath).delete();
      addTearDown(() => firestore.doc(prefixedPath).delete());

      return firestore.doc(prefixedPath);
    }

    test('retrieves multiple documents', () async {
      final docRef1 = await initializeTest('getAll1');
      final docRef2 = await initializeTest('getAll2');
      final docRef3 = await initializeTest('getAll3');

      await docRef1.set({'value': 42});
      await docRef2.set({'value': 44});
      await docRef3.set({'value': 'foo'});

      final snapshots = await firestore.getAll([docRef1, docRef2, docRef3]);

      expect(snapshots.length, 3);
      expect(snapshots[0].data()!['value'], 42);
      expect(snapshots[1].data()!['value'], 44);
      expect(snapshots[2].data()!['value'], 'foo');
    });

    test('retrieves single document', () async {
      final docRef = await initializeTest('getAll-single');

      await docRef.set({'name': 'Alice', 'age': 30});

      final snapshots = await firestore.getAll([docRef]);

      expect(snapshots.length, 1);
      expect(snapshots[0].data()!['name'], 'Alice');
      expect(snapshots[0].data()!['age'], 30);
    });

    test('handles missing documents', () async {
      final docRef1 = await initializeTest('getAll-exists');
      final docRef2 = await initializeTest('getAll-missing');

      await docRef1.set({'exists': true});
      // docRef2 is not created, so it will be missing

      final snapshots = await firestore.getAll([docRef1, docRef2]);

      expect(snapshots.length, 2);
      expect(snapshots[0].exists, isTrue);
      expect(snapshots[0].data()!['exists'], true);
      expect(snapshots[1].exists, isFalse);
      expect(snapshots[1].data(), isNull);
    });

    test('handles all missing documents', () async {
      final docRef1 = await initializeTest('getAll-missing1');
      final docRef2 = await initializeTest('getAll-missing2');

      // Neither document is created

      final snapshots = await firestore.getAll([docRef1, docRef2]);

      expect(snapshots.length, 2);
      expect(snapshots[0].exists, isFalse);
      expect(snapshots[1].exists, isFalse);
    });

    test('applies field mask', () async {
      final docRef1 = await initializeTest('getAll-mask1');
      final docRef2 = await initializeTest('getAll-mask2');

      await docRef1.set({'name': 'Alice', 'age': 30, 'city': 'NYC'});
      await docRef2.set({'name': 'Bob', 'age': 25, 'city': 'LA'});

      final snapshots = await firestore.getAll(
        [docRef1, docRef2],
        ReadOptions(
          fieldMask: [
            FieldMask.fieldPath(FieldPath(const ['name'])),
            FieldMask.fieldPath(FieldPath(const ['age'])),
          ],
        ),
      );

      expect(snapshots.length, 2);
      expect(snapshots[0].data(), {'name': 'Alice', 'age': 30});
      expect(snapshots[0].data()!.containsKey('city'), isFalse);
      expect(snapshots[1].data(), {'name': 'Bob', 'age': 25});
      expect(snapshots[1].data()!.containsKey('city'), isFalse);
    });

    test('applies field mask with string paths', () async {
      final docRef = await initializeTest('getAll-mask-string');

      await docRef.set({
        'user': {'name': 'Alice', 'email': 'alice@example.com', 'age': 30},
        'settings': {'theme': 'dark', 'notifications': true},
      });

      final snapshots = await firestore.getAll(
        [docRef],
        ReadOptions(
          fieldMask: [
            FieldMask.fieldPath(FieldPath(const ['user', 'name'])),
            FieldMask.fieldPath(FieldPath(const ['settings', 'theme'])),
          ],
        ),
      );

      expect(snapshots.length, 1);
      final data = snapshots[0].data()!;
      final user = data['user'] as Map<String, dynamic>;
      final settings = data['settings'] as Map<String, dynamic>;
      expect(user['name'], 'Alice');
      expect(user.containsKey('email'), isFalse);
      expect(user.containsKey('age'), isFalse);
      expect(settings['theme'], 'dark');
      expect(settings.containsKey('notifications'), isFalse);
    });

    test('preserves document order', () async {
      final docRef1 = await initializeTest('getAll-order1');
      final docRef2 = await initializeTest('getAll-order2');
      final docRef3 = await initializeTest('getAll-order3');

      await docRef1.set({'index': 1});
      await docRef2.set({'index': 2});
      await docRef3.set({'index': 3});

      // Request in specific order
      final snapshots = await firestore.getAll([
        docRef3,
        docRef1,
        docRef2,
        docRef3,
      ]);

      expect(snapshots.length, 4);
      expect(snapshots[0].data()!['index'], 3);
      expect(snapshots[1].data()!['index'], 1);
      expect(snapshots[2].data()!['index'], 2);
      expect(snapshots[3].data()!['index'], 3);
    });

    test('handles duplicate document references', () async {
      final docRef = await initializeTest('getAll-duplicate');

      await docRef.set({'count': 100});

      final snapshots = await firestore.getAll([docRef, docRef, docRef]);

      expect(snapshots.length, 3);
      expect(snapshots[0].data()!['count'], 100);
      expect(snapshots[1].data()!['count'], 100);
      expect(snapshots[2].data()!['count'], 100);
      // Verify all snapshots refer to the same document
      expect(snapshots[0].ref.path, docRef.path);
      expect(snapshots[1].ref.path, docRef.path);
      expect(snapshots[2].ref.path, docRef.path);
    });

    test('includes read time on all snapshots', () async {
      final docRef1 = await initializeTest('getAll-readtime1');
      final docRef2 = await initializeTest('getAll-readtime2');

      await docRef1.set({'value': 1});
      await docRef2.set({'value': 2});

      final snapshots = await firestore.getAll([docRef1, docRef2]);

      expect(snapshots.length, 2);
      expect(snapshots[0].readTime, isNotNull);
      expect(snapshots[1].readTime, isNotNull);
      // Read times should be very close (same batch read)
      expect(snapshots[0].readTime, snapshots[1].readTime);
    });

    test('includes create and update times', () async {
      final docRef = await initializeTest('getAll-timestamps');

      await docRef.set({'initial': true});
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await docRef.update({'updated': true});

      final snapshots = await firestore.getAll([docRef]);

      expect(snapshots.length, 1);
      final snapshot = snapshots[0];
      expect(snapshot.createTime, isNotNull);
      expect(snapshot.updateTime, isNotNull);
      expect(
        snapshot.updateTime!.toDate().isAfter(snapshot.createTime!.toDate()),
        isTrue,
      );
    });

    test('works with documents from different paths', () async {
      final docRef1 = await initializeTest('getAll-path1');
      final docRef2 = await initializeTest('getAll-path2');
      final docRef3 = await initializeTest('getAll-path3');

      await docRef1.set({'path': 1});
      await docRef2.set({'path': 2});
      await docRef3.set({'path': 3});

      final snapshots = await firestore.getAll([docRef1, docRef2, docRef3]);

      expect(snapshots.length, 3);
      expect(snapshots[0].data()!['path'], 1);
      expect(snapshots[1].data()!['path'], 2);
      expect(snapshots[2].data()!['path'], 3);
    });

    test('throws on empty document array', () async {
      expect(() => firestore.getAll([]), throwsA(isA<ArgumentError>()));
    });
  }, tags: 'firebase-emulator');
}
