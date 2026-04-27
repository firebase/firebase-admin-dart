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
          final fn = invocation.positionalArguments[0] as Future<
              firestore_v1.PartitionQueryResponse> Function(
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
          final fn = invocation.positionalArguments[0] as Future<
              firestore_v1.PartitionQueryResponse> Function(
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
          final fn = invocation.positionalArguments[0] as Future<
              firestore_v1.PartitionQueryResponse> Function(
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
          final fn = invocation.positionalArguments[0] as Future<
              firestore_v1.PartitionQueryResponse> Function(
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
          final fn = invocation.positionalArguments[0] as Future<
              firestore_v1.PartitionQueryResponse> Function(
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
          final fn = invocation.positionalArguments[0] as Future<
              firestore_v1.PartitionQueryResponse> Function(
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
}
