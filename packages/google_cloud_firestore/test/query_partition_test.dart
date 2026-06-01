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
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockFirestoreHttpClient extends Mock implements FirestoreHttpClient {}

void main() {
  group('QueryPartition Unit Tests', () {
    late Firestore firestore;

    setUp(() {
      runZoned(
        () {
          firestore = Firestore(
            settings: const Settings(projectId: 'test-project'),
          );
        },
        zoneValues: {
          envSymbol: <String, String>{'GOOGLE_CLOUD_PROJECT': 'test-project'},
        },
      );
    });

    group('getPartitions validation', () {
      test('validates partition count of zero', () async {
        final query = firestore.collectionGroup('collectionId');

        await expectLater(
          () async {
            await for (final _ in query.getPartitions(0)) {
              // Should not reach here
            }
          }(),
          throwsA(
            isA<FirestoreException>().having(
              (e) => e.message,
              'message',
              'Value for argument "desiredPartitionCount" must be within [1, Infinity] inclusive, but was: 0',
            ),
          ),
        );
      });

      test('validates negative partition count', () async {
        final query = firestore.collectionGroup('collectionId');

        await expectLater(
          () async {
            await for (final _ in query.getPartitions(-1)) {
              // Should not reach here
            }
          }(),
          throwsA(
            isA<FirestoreException>().having(
              (e) => e.message,
              'message',
              'Value for argument "desiredPartitionCount" must be within [1, Infinity] inclusive, but was: -1',
            ),
          ),
        );
      });
    });

    group('getPartitions pagination', () {
      late Firestore mockFirestore;
      late MockFirestoreHttpClient mockHttpClient;

      setUp(() {
        mockHttpClient = MockFirestoreHttpClient();

        // Mock cachedProjectId
        when(() => mockHttpClient.cachedProjectId).thenReturn('test-project');

        // Create Firestore instance with mock http client
        mockFirestore = Firestore.internal(
          settings: const Settings(projectId: 'test-project'),
          client: mockHttpClient,
        );
      });

      test('handles single-page response (no pagination)', () async {
        final mockApi = FakeFirestore(
          partitionQuery: (request) async {
            return firestore_v1.PartitionQueryResponse(
              partitions: [
                firestore_v1.Cursor(
                  values: [
                    firestore_v1.Value(
                      referenceValue:
                          'projects/test-project/databases/(default)/documents/coll/doc1',
                    ),
                  ],
                ),
                firestore_v1.Cursor(
                  values: [
                    firestore_v1.Value(
                      referenceValue:
                          'projects/test-project/databases/(default)/documents/coll/doc2',
                    ),
                  ],
                ),
              ],
            );
          },
        );

        when(
          () => mockHttpClient.v1<firestore_v1.PartitionQueryResponse>(any()),
        ).thenAnswer((invocation) async {
          final fn =
              invocation.positionalArguments[0]
                  as Future<firestore_v1.PartitionQueryResponse> Function(
                    firestore_v1.Firestore,
                    String,
                  );
          return fn(mockApi, 'test-project');
        });

        final collectionGroup = mockFirestore.collectionGroup(
          'test-collection',
        );
        final partitions = await collectionGroup.getPartitions(3).toList();

        // Verify:
        // - 3 partitions returned (2 cursors + 1 final empty partition)
        expect(partitions, hasLength(3));
      });

      test('handles multi-page response with nextPageToken', () async {
        var callCount = 0;

        final mockApi = FakeFirestore(
          partitionQuery: (request) async {
            callCount++;

            if (callCount == 1) {
              // First page with nextPageToken
              return firestore_v1.PartitionQueryResponse(
                partitions: [
                  firestore_v1.Cursor(
                    values: [
                      firestore_v1.Value(
                        referenceValue:
                            'projects/test-project/databases/(default)/documents/coll/doc1',
                      ),
                    ],
                  ),
                  firestore_v1.Cursor(
                    values: [
                      firestore_v1.Value(
                        referenceValue:
                            'projects/test-project/databases/(default)/documents/coll/doc2',
                      ),
                    ],
                  ),
                ],
                nextPageToken: 'page-2-token',
              );
            } else if (callCount == 2) {
              // Second page with nextPageToken
              return firestore_v1.PartitionQueryResponse(
                partitions: [
                  firestore_v1.Cursor(
                    values: [
                      firestore_v1.Value(
                        referenceValue:
                            'projects/test-project/databases/(default)/documents/coll/doc3',
                      ),
                    ],
                  ),
                  firestore_v1.Cursor(
                    values: [
                      firestore_v1.Value(
                        referenceValue:
                            'projects/test-project/databases/(default)/documents/coll/doc4',
                      ),
                    ],
                  ),
                ],
                nextPageToken: 'page-3-token',
              );
            } else {
              // Final page without nextPageToken
              return firestore_v1.PartitionQueryResponse(
                partitions: [
                  firestore_v1.Cursor(
                    values: [
                      firestore_v1.Value(
                        referenceValue:
                            'projects/test-project/databases/(default)/documents/coll/doc5',
                      ),
                    ],
                  ),
                ],
              );
            }
          },
        );

        when(
          () => mockHttpClient.v1<firestore_v1.PartitionQueryResponse>(any()),
        ).thenAnswer((invocation) async {
          final fn =
              invocation.positionalArguments[0]
                  as Future<firestore_v1.PartitionQueryResponse> Function(
                    firestore_v1.Firestore,
                    String,
                  );
          return fn(mockApi, 'test-project');
        });

        final collectionGroup = mockFirestore.collectionGroup(
          'test-collection',
        );
        final partitions = await collectionGroup.getPartitions(10).toList();

        // Verify:
        // - 6 partitions returned (5 cursors from 3 pages + 1 final empty partition)
        // - 3 API calls made (pagination across 3 pages)
        expect(partitions, hasLength(6));
        expect(callCount, equals(3));
      });

      test('handles empty string nextPageToken correctly', () async {
        final mockApi = FakeFirestore(
          partitionQuery: (request) async {
            return firestore_v1.PartitionQueryResponse(
              partitions: [
                firestore_v1.Cursor(
                  values: [
                    firestore_v1.Value(
                      referenceValue:
                          'projects/test-project/databases/(default)/documents/coll/doc1',
                    ),
                  ],
                ),
              ],
              nextPageToken: '', // Empty string should stop pagination
            );
          },
        );

        when(
          () => mockHttpClient.v1<firestore_v1.PartitionQueryResponse>(any()),
        ).thenAnswer((invocation) async {
          final fn =
              invocation.positionalArguments[0]
                  as Future<firestore_v1.PartitionQueryResponse> Function(
                    firestore_v1.Firestore,
                    String,
                  );
          return fn(mockApi, 'test-project');
        });

        final collectionGroup = mockFirestore.collectionGroup(
          'test-collection',
        );
        final partitions = await collectionGroup.getPartitions(5).toList();

        // Verify pagination stops with empty token (1 API call only)
        expect(partitions, hasLength(2)); // 1 cursor + 1 final empty partition
      });

      test('handles null partitions in response', () async {
        final mockApi = FakeFirestore(
          partitionQuery: (request) async {
            return firestore_v1.PartitionQueryResponse();
          },
        );

        when(
          () => mockHttpClient.v1<firestore_v1.PartitionQueryResponse>(any()),
        ).thenAnswer((invocation) async {
          final fn =
              invocation.positionalArguments[0]
                  as Future<firestore_v1.PartitionQueryResponse> Function(
                    firestore_v1.Firestore,
                    String,
                  );
          return fn(mockApi, 'test-project');
        });

        final collectionGroup = mockFirestore.collectionGroup(
          'test-collection',
        );
        final partitions = await collectionGroup.getPartitions(3).toList();

        // Should return only the final empty partition
        expect(partitions, hasLength(1));
        expect(partitions[0].startAt, isNull);
        expect(partitions[0].endBefore, isNull);
      });

      test('handles partitions with null values', () async {
        final mockApi = FakeFirestore(
          partitionQuery: (request) async {
            return firestore_v1.PartitionQueryResponse(
              partitions: [
                firestore_v1.Cursor(), // Null values
                firestore_v1.Cursor(
                  values: [
                    firestore_v1.Value(
                      referenceValue:
                          'projects/test-project/databases/(default)/documents/coll/doc1',
                    ),
                  ],
                ),
              ],
            );
          },
        );

        when(
          () => mockHttpClient.v1<firestore_v1.PartitionQueryResponse>(any()),
        ).thenAnswer((invocation) async {
          final fn =
              invocation.positionalArguments[0]
                  as Future<firestore_v1.PartitionQueryResponse> Function(
                    firestore_v1.Firestore,
                    String,
                  );
          return fn(mockApi, 'test-project');
        });

        final collectionGroup = mockFirestore.collectionGroup(
          'test-collection',
        );
        final partitions = await collectionGroup.getPartitions(3).toList();

        // Should skip the cursor with null values and return 2 partitions
        // (1 valid cursor + 1 final empty partition)
        expect(partitions, hasLength(2));
      });

      test('verifies partitions are sorted across multiple pages', () async {
        var callCount = 0;

        final mockApi = FakeFirestore(
          partitionQuery: (request) async {
            callCount++;

            if (callCount == 1) {
              // First page - doc3, doc1 (unsorted)
              return firestore_v1.PartitionQueryResponse(
                partitions: [
                  firestore_v1.Cursor(
                    values: [
                      firestore_v1.Value(
                        referenceValue:
                            'projects/test-project/databases/(default)/documents/coll/doc3',
                      ),
                    ],
                  ),
                  firestore_v1.Cursor(
                    values: [
                      firestore_v1.Value(
                        referenceValue:
                            'projects/test-project/databases/(default)/documents/coll/doc1',
                      ),
                    ],
                  ),
                ],
                nextPageToken: 'page-2-token',
              );
            } else {
              // Second page - doc4, doc2 (unsorted)
              return firestore_v1.PartitionQueryResponse(
                partitions: [
                  firestore_v1.Cursor(
                    values: [
                      firestore_v1.Value(
                        referenceValue:
                            'projects/test-project/databases/(default)/documents/coll/doc4',
                      ),
                    ],
                  ),
                  firestore_v1.Cursor(
                    values: [
                      firestore_v1.Value(
                        referenceValue:
                            'projects/test-project/databases/(default)/documents/coll/doc2',
                      ),
                    ],
                  ),
                ],
              );
            }
          },
        );

        when(
          () => mockHttpClient.v1<firestore_v1.PartitionQueryResponse>(any()),
        ).thenAnswer((invocation) async {
          final fn =
              invocation.positionalArguments[0]
                  as Future<firestore_v1.PartitionQueryResponse> Function(
                    firestore_v1.Firestore,
                    String,
                  );
          return fn(mockApi, 'test-project');
        });

        final collectionGroup = mockFirestore.collectionGroup(
          'test-collection',
        );
        final partitions = await collectionGroup.getPartitions(10).toList();

        // Verify partitions are sorted: doc1, doc2, doc3, doc4, empty
        expect(partitions, hasLength(5));

        // Extract document names from reference values
        final docNames = partitions.where((p) => p.startAt != null).map((p) {
          final docRef = p.startAt!.first! as DocumentReference;
          return docRef.path.split('/').last;
        }).toList();

        expect(docNames, equals(['doc1', 'doc2', 'doc3', 'doc4']));
      });
    });
  });

  group('QueryPartition Tests [Production]', () {
    late Firestore firestore;
    final collectionGroupsToCleanup = <String>{};

    setUp(() async {
      firestore = Firestore(
        settings: const Settings(projectId: 'dart-firebase-admin'),
      );
    });

    tearDown(() async {
      // Clean up all test collection group documents
      try {
        for (final collectionGroupId in collectionGroupsToCleanup) {
          try {
            final snapshot = await firestore
                .collectionGroup(collectionGroupId)
                .get();

            // Delete all documents in this collection group
            // Use a batch for more efficient deletion
            if (snapshot.docs.isNotEmpty) {
              final batch = firestore.batch();
              for (final doc in snapshot.docs) {
                batch.delete(doc.ref);
              }
              await batch.commit();

              print(
                'Cleaned up ${snapshot.docs.length} documents from collection group: $collectionGroupId',
              );
            }
          } catch (e) {
            // Log error but continue cleanup of other collection groups
            print('Error cleaning up collection group $collectionGroupId: $e');
          }
        }
      } finally {
        collectionGroupsToCleanup.clear();

        // Always terminate the Firestore instance
        await firestore.terminate();
      }
    });

    /// Helper to collect all partitions into a list
    Future<List<QueryPartition<T>>> getPartitions<T extends Object?>(
      CollectionGroup<T> collectionGroup,
      int desiredPartitionCount,
    ) async {
      final partitions = <QueryPartition<T>>[];
      await collectionGroup
          .getPartitions(desiredPartitionCount)
          .forEach(partitions.add);
      return partitions;
    }

    test('empty partition query', () async {
      await runZoned(
        () async {
          const desiredPartitionCount = 3;

          // Use a unique collection group ID that has no documents
          final collectionGroupId =
              'empty-${DateTime.now().millisecondsSinceEpoch}';
          final collectionGroup = firestore.collectionGroup(collectionGroupId);

          final partitions = await getPartitions(
            collectionGroup,
            desiredPartitionCount,
          );

          expect(partitions, hasLength(1));
          expect(partitions[0].startAt, isNull);
          expect(partitions[0].endBefore, isNull);
        },
        zoneValues: {
          envSymbol: <String, String>{}, // Clear FIRESTORE_EMULATOR_HOST
        },
      );
    });

    test('partition query', () async {
      await runZoned(() async {
        const documentCount = 20;
        const desiredPartitionCount = 3;

        // Create documents in a collection group
        final collectionGroupId =
            'partition-test-${DateTime.now().millisecondsSinceEpoch}';
        collectionGroupsToCleanup.add(collectionGroupId);

        // Create documents in different parent collections
        for (var i = 0; i < documentCount; i++) {
          final parentPath = 'parent${i % 5}'; // Create 5 different parents
          await firestore.doc('$parentPath/doc/$collectionGroupId/doc$i').set({
            'value': i,
          });
        }

        final collectionGroup = firestore.collectionGroup(collectionGroupId);
        final partitions = await getPartitions(
          collectionGroup,
          desiredPartitionCount,
        );

        // Verify partition structure
        expect(partitions.length, lessThanOrEqualTo(desiredPartitionCount));
        expect(partitions[0].startAt, isNull);

        for (var i = 0; i < partitions.length - 1; i++) {
          // Each partition's endBefore should equal the next partition's startAt
          expect(partitions[i].endBefore, isNotNull);
          expect(partitions[i + 1].startAt, isNotNull);
        }

        expect(partitions.last.endBefore, isNull);

        // Validate that we can use the partitions to read the original documents
        final allDocuments = <QueryDocumentSnapshot<Map<String, Object?>>>[];
        for (final partition in partitions) {
          final snapshot = await partition.toQuery().get();
          allDocuments.addAll(snapshot.docs);
        }

        expect(allDocuments, hasLength(documentCount));
      }, zoneValues: {envSymbol: <String, String>{}});
    });

    test('partition query with manual cursors', () async {
      await runZoned(() async {
        const documentCount = 15;
        const desiredPartitionCount = 4;

        // Create documents in a collection group
        final collectionGroupId =
            'manual-cursors-${DateTime.now().millisecondsSinceEpoch}';
        collectionGroupsToCleanup.add(collectionGroupId);

        for (var i = 0; i < documentCount; i++) {
          final parentPath = 'parent${i % 3}';
          await firestore.doc('$parentPath/doc/$collectionGroupId/doc$i').set({
            'index': i,
          });
        }

        final collectionGroup = firestore.collectionGroup(collectionGroupId);
        final partitions = await getPartitions(
          collectionGroup,
          desiredPartitionCount,
        );

        // Use manual cursors to query each partition
        final allDocuments = <QueryDocumentSnapshot<Map<String, Object?>>>[];
        for (final partition in partitions) {
          var partitionedQuery = collectionGroup.orderBy(FieldPath.documentId);

          if (partition.startAt != null) {
            partitionedQuery = partitionedQuery.startAt(partition.startAt!);
          }

          if (partition.endBefore != null) {
            partitionedQuery = partitionedQuery.endBefore(partition.endBefore!);
          }

          final snapshot = await partitionedQuery.get();
          allDocuments.addAll(snapshot.docs);
        }

        expect(allDocuments, hasLength(documentCount));
      }, zoneValues: {envSymbol: <String, String>{}});
    });

    test('partition query with converter', () async {
      await runZoned(() async {
        const documentCount = 12;
        const desiredPartitionCount = 3;

        // Create documents
        final collectionGroupId =
            'converter-test-${DateTime.now().millisecondsSinceEpoch}';
        collectionGroupsToCleanup.add(collectionGroupId);

        for (var i = 0; i < documentCount; i++) {
          await firestore.doc('parent/doc/$collectionGroupId/doc$i').set({
            'title': 'Post $i',
            'author': 'Author $i',
          });
        }

        // Define a converter
        final converter = _FirestoreConverter<_Post>(
          fromFirestore: (snapshot) {
            final data = snapshot.data()!;
            return _Post(
              title: data['title']! as String,
              author: data['author']! as String,
            );
          },
          toFirestore: (post) => {'title': post.title, 'author': post.author},
        );

        final collectionGroupWithConverter = firestore
            .collectionGroup(collectionGroupId)
            .withConverter(
              fromFirestore: converter.fromFirestore,
              toFirestore: converter.toFirestore,
            );

        final partitions = await getPartitions(
          collectionGroupWithConverter,
          desiredPartitionCount,
        );

        // Verify all documents can be retrieved with converter
        final allDocuments = <QueryDocumentSnapshot<_Post>>[];
        for (final partition in partitions) {
          final snapshot = await partition.toQuery().get();
          allDocuments.addAll(snapshot.docs);
        }

        expect(allDocuments, hasLength(documentCount));

        // Verify converter was applied
        for (final doc in allDocuments) {
          expect(doc.data(), isA<_Post>());
          expect(doc.data().title, startsWith('Post '));
          expect(doc.data().author, startsWith('Author '));
        }
      }, zoneValues: {envSymbol: <String, String>{}});
    });

    test('requests one less than desired partitions', () async {
      await runZoned(() async {
        const documentCount = 30;
        const desiredPartitionCount = 5;

        // Create enough documents to get multiple partitions
        final collectionGroupId =
            'partition-count-${DateTime.now().millisecondsSinceEpoch}';
        collectionGroupsToCleanup.add(collectionGroupId);

        for (var i = 0; i < documentCount; i++) {
          await firestore
              .doc(
                'parent/doc/$collectionGroupId/doc${i.toString().padLeft(3, '0')}',
              )
              .set({'value': i});
        }

        final collectionGroup = firestore.collectionGroup(collectionGroupId);
        final partitions = await getPartitions(
          collectionGroup,
          desiredPartitionCount,
        );

        // The actual number of partitions may be fewer than requested
        expect(partitions.length, greaterThan(0));
        expect(partitions.length, lessThanOrEqualTo(desiredPartitionCount));

        // Verify partition continuity
        expect(partitions[0].startAt, isNull);
        for (var i = 0; i < partitions.length - 1; i++) {
          expect(partitions[i].endBefore, isNotNull);
          expect(partitions[i + 1].startAt, isNotNull);
        }
        expect(partitions.last.endBefore, isNull);
      }, zoneValues: {envSymbol: <String, String>{}});
    });

    test(
      'partitions are sorted',
      timeout: const Timeout(Duration(minutes: 3)),
      () async {
        await runZoned(() async {
          const documentCount = 25;
          const desiredPartitionCount = 4;

          // Create documents in a collection group
          final collectionGroupId =
              'sorted-partitions-${DateTime.now().millisecondsSinceEpoch}';
          collectionGroupsToCleanup.add(collectionGroupId);

          // Create documents across multiple parent collections
          for (var i = 0; i < documentCount; i++) {
            final parentPath = 'parent${i % 4}';
            await firestore
                .doc(
                  '$parentPath/doc/$collectionGroupId/doc${i.toString().padLeft(3, '0')}',
                )
                .set({'value': i});
          }

          final collectionGroup = firestore.collectionGroup(collectionGroupId);
          final partitions = await getPartitions(
            collectionGroup,
            desiredPartitionCount,
          );

          // Verify partitions are properly sorted
          // Each partition's endBefore should be less than or equal to next partition's startAt
          for (var i = 0; i < partitions.length - 1; i++) {
            final currentEnd = partitions[i].endBefore;
            final nextStart = partitions[i + 1].startAt;

            if (currentEnd != null && nextStart != null) {
              // Verify the partition boundaries are in order
              // The endBefore of partition i should equal the startAt of partition i+1
              expect(
                currentEnd,
                equals(nextStart),
                reason:
                    'Partition $i endBefore should equal partition ${i + 1} startAt',
              );
            }
          }

          // Verify all documents can be read across sorted partitions
          final allDocuments = <QueryDocumentSnapshot<Map<String, Object?>>>[];
          for (final partition in partitions) {
            final snapshot = await partition.toQuery().get();
            allDocuments.addAll(snapshot.docs);
          }

          expect(
            allDocuments,
            hasLength(documentCount),
            reason: 'Should retrieve all documents across partitions',
          );

          // Verify no duplicates (each document appears exactly once)
          final docIds = allDocuments.map((doc) => doc.id).toSet();
          expect(
            docIds,
            hasLength(documentCount),
            reason: 'No duplicate documents across partitions',
          );
        }, zoneValues: {envSymbol: <String, String>{}});
      },
    );

    test(
      'handles paginated partition responses with large partition counts',
      timeout: const Timeout(Duration(minutes: 3)),
      () async {
        await runZoned(() async {
          // Create enough documents to potentially trigger pagination
          // The API typically paginates around 128-256 partitions
          const documentCount = 500;
          const desiredPartitionCount = 300;

          final collectionGroupId =
              'pagination-test-${DateTime.now().millisecondsSinceEpoch}';
          collectionGroupsToCleanup.add(collectionGroupId);

          // Create documents across multiple parents to maximize partition points
          for (var i = 0; i < documentCount; i++) {
            final parentPath = 'parent${i % 10}';
            await firestore
                .doc(
                  '$parentPath/doc/$collectionGroupId/doc${i.toString().padLeft(4, '0')}',
                )
                .set({'value': i});
          }

          final collectionGroup = firestore.collectionGroup(collectionGroupId);
          final partitions = await getPartitions(
            collectionGroup,
            desiredPartitionCount,
          );

          // Verify we got partitions
          expect(partitions.length, greaterThan(0));
          expect(partitions.length, lessThanOrEqualTo(desiredPartitionCount));

          // Verify partition structure
          expect(
            partitions[0].startAt,
            isNull,
            reason: 'First partition starts at beginning',
          );
          expect(
            partitions.last.endBefore,
            isNull,
            reason: 'Last partition ends at end',
          );

          // Verify all partitions are continuous (no gaps)
          for (var i = 0; i < partitions.length - 1; i++) {
            expect(partitions[i].endBefore, isNotNull);
            expect(partitions[i + 1].startAt, isNotNull);
            expect(
              partitions[i].endBefore,
              equals(partitions[i + 1].startAt),
              reason:
                  'Partition $i endBefore must equal partition ${i + 1} startAt',
            );
          }

          // Verify all documents can be retrieved (no data loss)
          final allDocuments = <QueryDocumentSnapshot<Map<String, Object?>>>[];
          for (final partition in partitions) {
            final snapshot = await partition.toQuery().get();
            allDocuments.addAll(snapshot.docs);
          }

          expect(
            allDocuments,
            hasLength(documentCount),
            reason: 'All documents must be retrievable across partitions',
          );

          // Verify no duplicates
          final docIds = allDocuments.map((doc) => doc.id).toSet();
          expect(
            docIds,
            hasLength(documentCount),
            reason: 'No document should appear in multiple partitions',
          );
        }, zoneValues: {envSymbol: <String, String>{}});
      },
    );
  }, tags: 'prod');
}

/// Test class for converter tests
class _Post {
  _Post({required this.title, required this.author});

  final String title;
  final String author;
}

/// Firestore converter for testing
class _FirestoreConverter<T> {
  _FirestoreConverter({required this.fromFirestore, required this.toFirestore});

  final T Function(DocumentSnapshot<Map<String, Object?>>) fromFirestore;
  final Map<String, Object?> Function(T) toFirestore;
}
