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

import 'dart:async';

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:google_cloud_firestore/src/firestore_http_client.dart';
import 'package:google_cloud_firestore_v1/firestore.dart' as firestore_v1;
import 'package:google_cloud_firestore_v1/testing.dart';
import 'package:google_cloud_protobuf/protobuf.dart' as protobuf_v1;
import 'package:google_cloud_rpc/rpc.dart' as rpc;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'fixtures/helpers.dart';

// Mock classes
class MockFirestoreHttpClient extends Mock implements FirestoreHttpClient {}

// Helper to create a RunQueryResponse with a document
firestore_v1.RunQueryResponse createDocumentResponse(String docId) {
  final now = protobuf_v1.Timestamp(
    seconds: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );
  return firestore_v1.RunQueryResponse(
    document: firestore_v1.Document(
      name:
          'projects/$projectId/databases/(default)/documents/collectionId/$docId',
      fields: {},
      createTime: now,
      updateTime: now,
    ),
    readTime: now,
  );
}

void main() {
  group('recursiveDelete() Unit Tests', () {
    late MockFirestoreHttpClient mockClient;
    late Firestore firestore;
    late List<String> deletedPaths;

    setUp(() {
      mockClient = MockFirestoreHttpClient();
      deletedPaths = [];

      firestore = Firestore.internal(
        settings: const Settings(projectId: projectId),
        client: mockClient,
      );

      when(() => mockClient.cachedProjectId).thenReturn(projectId);
    });

    group('deletion behavior', () {
      test('deletes a collection with documents', () async {
        final mockApi = FakeFirestore(
          runQuery: (request) {
            return Stream.fromIterable([
              createDocumentResponse('doc1'),
              createDocumentResponse('doc2'),
            ]);
          },
          batchWrite: (request) async {
            for (final write in request.writes) {
              if (write.delete != null) {
                deletedPaths.add(write.delete!);
              }
            }
            return firestore_v1.BatchWriteResponse(
              status: List.generate(
                request.writes.length,
                (_) => rpc.Status(code: 0),
              ),
              writeResults: List.generate(
                request.writes.length,
                (_) => firestore_v1.WriteResult(
                  updateTime: protobuf_v1.Timestamp(seconds: 1),
                ),
              ),
            );
          },
        );

        when(() => mockClient.v1<void>(any())).thenAnswer((invocation) async {
          final fn =
              invocation.positionalArguments[0]
                  as Future<void> Function(firestore_v1.Firestore, String);
          return fn(mockApi, projectId);
        });

        // Use a return type of Stream<firestore_v1.RunQueryResponse> for runQuery
        when(
          () => mockClient.v1<Stream<firestore_v1.RunQueryResponse>>(any()),
        ).thenAnswer((invocation) async {
          final fn =
              invocation.positionalArguments[0]
                  as Future<Stream<firestore_v1.RunQueryResponse>> Function(
                    firestore_v1.Firestore,
                    String,
                  );
          return fn(mockApi, projectId);
        });

        when(
          () => mockClient.v1<firestore_v1.BatchWriteResponse>(any()),
        ).thenAnswer((invocation) async {
          final fn =
              invocation.positionalArguments[0]
                  as Future<firestore_v1.BatchWriteResponse> Function(
                    firestore_v1.Firestore,
                    String,
                  );
          return fn(mockApi, projectId);
        });

        final collection = firestore.collection('collectionId');
        await firestore.recursiveDelete(collection);

        expect(deletedPaths, contains(endsWith('collectionId/doc1')));
        expect(deletedPaths, contains(endsWith('collectionId/doc2')));
        expect(deletedPaths, hasLength(2));
      });

      test('deletes a document reference', () async {
        final docRef = firestore.doc('collectionId/doc1');

        final mockApi = FakeFirestore(
          runQuery: (request) {
            // Document has no subcollections
            return const Stream.empty();
          },
          batchWrite: (request) async {
            for (final write in request.writes) {
              if (write.delete != null) {
                deletedPaths.add(write.delete!);
              }
            }
            return firestore_v1.BatchWriteResponse(
              status: [rpc.Status(code: 0)],
              writeResults: [
                firestore_v1.WriteResult(
                  updateTime: protobuf_v1.Timestamp(seconds: 1),
                ),
              ],
            );
          },
        );

        when(() => mockClient.v1<void>(any())).thenAnswer((invocation) async {
          final fn =
              invocation.positionalArguments[0]
                  as Future<void> Function(firestore_v1.Firestore, String);
          return fn(mockApi, projectId);
        });

        when(
          () => mockClient.v1<Stream<firestore_v1.RunQueryResponse>>(any()),
        ).thenAnswer((invocation) async {
          final fn =
              invocation.positionalArguments[0]
                  as Future<Stream<firestore_v1.RunQueryResponse>> Function(
                    firestore_v1.Firestore,
                    String,
                  );
          return fn(mockApi, projectId);
        });

        when(
          () => mockClient.v1<firestore_v1.BatchWriteResponse>(any()),
        ).thenAnswer((invocation) async {
          final fn =
              invocation.positionalArguments[0]
                  as Future<firestore_v1.BatchWriteResponse> Function(
                    firestore_v1.Firestore,
                    String,
                  );
          return fn(mockApi, projectId);
        });

        await firestore.recursiveDelete(docRef);

        expect(deletedPaths, [endsWith('collectionId/doc1')]);
      });

      test('throws error when deletes fail', () async {
        final collection = firestore.collection('collectionId');

        final mockApi = FakeFirestore(
          runQuery: (request) {
            return Stream.fromIterable([createDocumentResponse('doc1')]);
          },
          batchWrite: (request) async {
            // We can't easily create a ServiceException because it needs a response.
            // But we can throw a generic exception which BulkWriter should catch.
            throw Exception('Internal Server Error');
          },
        );

        when(
          () => mockClient.v1<Stream<firestore_v1.RunQueryResponse>>(any()),
        ).thenAnswer((invocation) async {
          final fn =
              invocation.positionalArguments[0]
                  as Future<Stream<firestore_v1.RunQueryResponse>> Function(
                    firestore_v1.Firestore,
                    String,
                  );
          return fn(mockApi, projectId);
        });

        when(
          () => mockClient.v1<firestore_v1.BatchWriteResponse>(any()),
        ).thenAnswer((invocation) async {
          final fn =
              invocation.positionalArguments[0]
                  as Future<firestore_v1.BatchWriteResponse> Function(
                    firestore_v1.Firestore,
                    String,
                  );
          return fn(mockApi, projectId);
        });

        expect(
          () => firestore.recursiveDelete(collection),
          throwsA(isA<FirestoreException>()),
        );
      });
    });
  });

  group('Firestore', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    group('recursiveDelete() integration tests', () {
      late CollectionReference<DocumentData> randomCol;

      // Declare both functions first for mutual recursion
      late final Future<int> Function(DocumentReference<Object?>)
      countDocumentChildren;
      late final Future<int> Function(CollectionReference<Object?>)
      countCollectionChildren;

      // Now define them
      countDocumentChildren = (ref) async {
        var count = 0;
        final collections = await ref.listCollections();
        for (final collection in collections) {
          count += await countCollectionChildren(collection);
        }
        return count;
      };

      countCollectionChildren = (ref) async {
        var count = 0;
        final docs = await ref.listDocuments();
        for (final doc in docs) {
          count += (await countDocumentChildren(doc)) + 1;
        }
        return count;
      };

      setUp(() async {
        randomCol = firestore.collection(
          'recursiveDelete-${DateTime.now().millisecondsSinceEpoch}',
        );

        final batch = firestore.batch();
        batch.set(randomCol.doc('anna'), {'name': 'anna'});
        batch.set(randomCol.doc('bob'), {'name': 'bob'});
        batch.set(randomCol.doc('bob/parentsCol/charlie'), {'name': 'charlie'});
        batch.set(randomCol.doc('bob/parentsCol/daniel'), {'name': 'daniel'});
        batch.set(randomCol.doc('bob/parentsCol/daniel/childCol/ernie'), {
          'name': 'ernie',
        });
        batch.set(randomCol.doc('bob/parentsCol/daniel/childCol/francis'), {
          'name': 'francis',
        });
        await batch.commit();
      });

      test('on top-level collection', () async {
        await firestore.recursiveDelete(randomCol);
        expect(await countCollectionChildren(randomCol), equals(0));
      });

      test('on nested collection', () async {
        final coll = randomCol.doc('bob').collection('parentsCol');
        await firestore.recursiveDelete(coll);

        expect(await countCollectionChildren(coll), equals(0));
        expect(await countCollectionChildren(randomCol), equals(2));
      });

      test('on nested document', () async {
        final doc = randomCol.doc('bob/parentsCol/daniel');
        await firestore.recursiveDelete(doc);

        final docSnap = await doc.get();
        expect(docSnap.exists, isFalse);
        expect(await countDocumentChildren(randomCol.doc('bob')), equals(1));
        expect(await countCollectionChildren(randomCol), equals(3));
      });

      test('on leaf document', () async {
        final doc = randomCol.doc('bob/parentsCol/daniel/childCol/ernie');
        await firestore.recursiveDelete(doc);

        final docSnap = await doc.get();
        expect(docSnap.exists, isFalse);
        expect(await countCollectionChildren(randomCol), equals(5));
      });

      test('does not affect other collections', () async {
        // Add other nested collection that shouldn't be deleted.
        final collB = firestore.collection(
          'doggos-${DateTime.now().millisecondsSinceEpoch}',
        );
        await collB.doc('doggo').set({'name': 'goodboi'});

        await firestore.recursiveDelete(collB);
        expect(await countCollectionChildren(randomCol), equals(6));
        expect(await countCollectionChildren(collB), equals(0));
      });

      test('with custom BulkWriter instance', () async {
        final bulkWriter = firestore.bulkWriter();
        var callbackCount = 0;
        bulkWriter.onWriteResult((ref, result) {
          callbackCount++;
        });
        await firestore.recursiveDelete(randomCol, bulkWriter);
        expect(callbackCount, equals(6));
        await bulkWriter.close();
      });

      test('throws for invalid reference type', () {
        expect(
          () => firestore.recursiveDelete('invalid'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  }, tags: 'firebase-emulator');
}
