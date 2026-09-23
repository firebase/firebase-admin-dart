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
import 'package:google_cloud_firestore_v1/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockFirestoreHttpClient extends Mock implements FirestoreHttpClient {}

const _documentsPath = 'projects/test-project/databases/(default)/documents';

void main() {
  late Firestore firestore;
  late MockFirestoreHttpClient mockHttpClient;

  setUp(() {
    mockHttpClient = MockFirestoreHttpClient();
    when(() => mockHttpClient.cachedProjectId).thenReturn('test-project');

    firestore = Firestore.internal(
      settings: const Settings(projectId: 'test-project'),
      client: mockHttpClient,
    );
  });

  void stubApi<R>(firestore_v1.Firestore api) {
    when(() => mockHttpClient.v1<R>(any())).thenAnswer((invocation) async {
      final fn =
          invocation.positionalArguments[0]
              as Future<R> Function(firestore_v1.Firestore, String);
      return fn(api, 'test-project');
    });
  }

  group('CollectionReference.listDocuments()', () {
    test('follows nextPageToken across pages', () async {
      final pageTokens = <String>[];

      stubApi<firestore_v1.ListDocumentsResponse>(
        FakeFirestore(
          listDocuments: (request) async {
            pageTokens.add(request.pageToken);

            return switch (request.pageToken) {
              '' => firestore_v1.ListDocumentsResponse(
                documents: [
                  firestore_v1.Document(name: '$_documentsPath/col/a'),
                  firestore_v1.Document(name: '$_documentsPath/col/b'),
                ],
                nextPageToken: 'page-2',
              ),
              'page-2' => firestore_v1.ListDocumentsResponse(
                documents: [
                  firestore_v1.Document(name: '$_documentsPath/col/c'),
                ],
              ),
              _ => throw StateError('Unexpected token ${request.pageToken}'),
            };
          },
        ),
      );

      final collection = firestore.collection('col');
      final documents = await collection.listDocuments();

      expect(pageTokens, ['', 'page-2']);
      expect(
        documents,
        orderedEquals([
          collection.doc('a'),
          collection.doc('b'),
          collection.doc('c'),
        ]),
      );
    });
  });

  group('DocumentReference.listCollections()', () {
    test('follows nextPageToken across pages', () async {
      final pageTokens = <String>[];

      stubApi<firestore_v1.ListCollectionIdsResponse>(
        FakeFirestore(
          listCollectionIds: (request) async {
            pageTokens.add(request.pageToken);

            return switch (request.pageToken) {
              '' => firestore_v1.ListCollectionIdsResponse(
                collectionIds: ['c', 'a'],
                nextPageToken: 'page-2',
              ),
              'page-2' => firestore_v1.ListCollectionIdsResponse(
                collectionIds: ['b'],
              ),
              _ => throw StateError('Unexpected token ${request.pageToken}'),
            };
          },
        ),
      );

      final document = firestore.doc('col/doc');
      final collections = await document.listCollections();

      expect(pageTokens, ['', 'page-2']);
      expect(
        collections,
        orderedEquals([
          document.collection('a'),
          document.collection('b'),
          document.collection('c'),
        ]),
      );
    });
  });
}
