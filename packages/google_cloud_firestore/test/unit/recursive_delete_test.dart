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

import '../fixtures/helpers.dart';

// Mock classes
class MockFirestoreHttpClient extends Mock implements FirestoreHttpClient {}

// Helper to create a RunQueryResponse with a document
firestore_v1.RunQueryResponse createDocumentResponse(String docId) {
  final now = protobuf_v1.Timestamp(seconds: DateTime.now().millisecondsSinceEpoch ~/ 1000);
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
          final fn = invocation.positionalArguments[0]
              as Future<void> Function(firestore_v1.Firestore, String);
          return fn(mockApi, projectId);
        });

        // Use a return type of Stream<firestore_v1.RunQueryResponse> for runQuery
        when(() => mockClient.v1<Stream<firestore_v1.RunQueryResponse>>(any()))
            .thenAnswer((invocation) async {
          final fn = invocation.positionalArguments[0] as Future<
              Stream<firestore_v1.RunQueryResponse>> Function(
            firestore_v1.Firestore,
            String,
          );
          return fn(mockApi, projectId);
        });
        
         when(() => mockClient.v1<firestore_v1.BatchWriteResponse>(any()))
            .thenAnswer((invocation) async {
          final fn = invocation.positionalArguments[0] as Future<
              firestore_v1.BatchWriteResponse> Function(
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
                firestore_v1.WriteResult(updateTime: protobuf_v1.Timestamp(seconds: 1)),
              ],
            );
          },
        );

        when(() => mockClient.v1<void>(any())).thenAnswer((invocation) async {
          final fn = invocation.positionalArguments[0]
              as Future<void> Function(firestore_v1.Firestore, String);
          return fn(mockApi, projectId);
        });

        when(() => mockClient.v1<Stream<firestore_v1.RunQueryResponse>>(any()))
            .thenAnswer((invocation) async {
          final fn = invocation.positionalArguments[0] as Future<
              Stream<firestore_v1.RunQueryResponse>> Function(
            firestore_v1.Firestore,
            String,
          );
          return fn(mockApi, projectId);
        });
        
        when(() => mockClient.v1<firestore_v1.BatchWriteResponse>(any()))
            .thenAnswer((invocation) async {
          final fn = invocation.positionalArguments[0] as Future<
              firestore_v1.BatchWriteResponse> Function(
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

        when(() => mockClient.v1<Stream<firestore_v1.RunQueryResponse>>(any()))
            .thenAnswer((invocation) async {
          final fn = invocation.positionalArguments[0] as Future<
              Stream<firestore_v1.RunQueryResponse>> Function(
            firestore_v1.Firestore,
            String,
          );
          return fn(mockApi, projectId);
        });
        
        when(() => mockClient.v1<firestore_v1.BatchWriteResponse>(any()))
            .thenAnswer((invocation) async {
          final fn = invocation.positionalArguments[0] as Future<
              firestore_v1.BatchWriteResponse> Function(
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
}
