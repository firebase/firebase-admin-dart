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

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:google_cloud_firestore/src/firestore_http_client.dart';
import 'package:google_cloud_firestore_v1/firestore.dart' as firestore_v1;
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'fixtures/helpers.dart';

class MockFirestoreHttpClient extends Mock implements FirestoreHttpClient {}

final _connectionClosedError = http.ClientException(
  'Connection closed before full header was received',
);

void main() {
  group(
    'Transaction.getAggregateQuery() retries on transient connection errors (unit)',
    () {
      late MockFirestoreHttpClient mockClient;
      late Firestore firestore;

      setUp(() {
        mockClient = MockFirestoreHttpClient();
        firestore = Firestore.internal(
          settings: const Settings(projectId: mockProjectId),
          client: mockClient,
        );

        when(() => mockClient.cachedProjectId).thenReturn(mockProjectId);
      });

      test(
        'retries a read-only snapshot read (no active transaction) and succeeds',
        () async {
          var callCount = 0;
          when(
            () => mockClient
                .v1<Stream<firestore_v1.RunAggregationQueryResponse>>(any()),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) {
              return Stream<firestore_v1.RunAggregationQueryResponse>.error(
                _connectionClosedError,
              );
            }
            return Stream.fromIterable([
              firestore_v1.RunAggregationQueryResponse(
                result: firestore_v1.AggregationResult(
                  aggregateFields: {
                    'count': firestore_v1.Value(integerValue: 42),
                  },
                ),
              ),
            ]);
          });

          final aggregateQuery = firestore.collection('numbers').count();
          final snapshot = await firestore.runTransaction(
            (tx) => tx.getAggregateQuery(aggregateQuery),
            transactionOptions: ReadOnlyTransactionOptions(
              readTime: Timestamp.now(),
            ),
          );

          expect(callCount, 2);
          expect(snapshot.count, 42);
        },
      );

      test('does not retry a read within an active transaction', () async {
        // The failed transaction attempt triggers a best-effort rollback.
        when(() => mockClient.v1<void>(any())).thenAnswer((_) async {});

        var callCount = 0;
        when(
          () => mockClient.v1<Stream<firestore_v1.RunAggregationQueryResponse>>(
            any(),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            // First read starts the transaction successfully.
            return Stream.fromIterable([
              firestore_v1.RunAggregationQueryResponse(
                transaction: Uint8List.fromList([1, 2, 3]),
              ),
            ]);
          }
          // Second read, already inside the now-active transaction, fails
          // and must not be retried by the reader itself.
          return Stream<firestore_v1.RunAggregationQueryResponse>.error(
            _connectionClosedError,
          );
        });

        final aggregateQuery = firestore.collection('numbers').count();

        await expectLater(
          firestore.runTransaction((tx) async {
            await tx.getAggregateQuery(aggregateQuery);
            return tx.getAggregateQuery(aggregateQuery);
          }),
          throwsA(isA<http.ClientException>()),
        );

        expect(callCount, 2);
      });
    },
  );

  group('Transaction - Aggregation Queries', () {
    late Firestore firestore;
    late CollectionReference<DocumentData> collection;

    setUp(() async {
      firestore = await createFirestore();
      collection = firestore.collection(
        'transaction-agg-test-${DateTime.now().millisecondsSinceEpoch}',
      );
    });

    test('getAggregateQuery() with count works', () async {
      await collection.add({'name': 'Alice', 'age': 30});
      await collection.add({'name': 'Bob', 'age': 25});
      await collection.add({'name': 'Charlie', 'age': 30});

      final snapshot = await firestore.runTransaction((transaction) async {
        return transaction.getAggregateQuery(collection.count());
      });

      expect(snapshot.count, 3);
      expect(snapshot.readTime, isNotNull);
    });

    test('getAggregateQuery() with sum works', () async {
      await collection.add({'price': 10});
      await collection.add({'price': 20});
      await collection.add({'price': 30});

      final snapshot = await firestore.runTransaction((transaction) async {
        return transaction.getAggregateQuery(collection.sum('price'));
      });

      expect(snapshot.getSum('price'), 60);
    });

    test('getAggregateQuery() with average works', () async {
      await collection.add({'score': 80});
      await collection.add({'score': 90});
      await collection.add({'score': 100});

      final snapshot = await firestore.runTransaction((transaction) async {
        return transaction.getAggregateQuery(collection.average('score'));
      });

      expect(snapshot.getAverage('score'), 90.0);
    });

    test('getAggregateQuery() with multiple aggregations works', () async {
      await collection.add({'value': 10, 'category': 'A'});
      await collection.add({'value': 20, 'category': 'A'});
      await collection.add({'value': 30, 'category': 'B'});

      final query = collection.where('category', WhereFilter.equal, 'A');
      final aggregation = query.aggregate(
        const count(),
        const sum('value'),
        const average('value'),
      );

      final snapshot = await firestore.runTransaction((transaction) async {
        return transaction.getAggregateQuery(aggregation);
      });

      expect(snapshot.count, 2);
      expect(snapshot.getSum('value'), 30);
      expect(snapshot.getAverage('value'), 15.0);
    });

    test('getAggregateQuery() throws on read-after-write', () async {
      await collection.add({'value': 10});
      final docRef = collection.doc('test-doc');

      expect(
        firestore.runTransaction((transaction) async {
          transaction.set(docRef, {'value': 20});
          // Trying to read after write should throw
          return transaction.getAggregateQuery(collection.count());
        }),
        throwsA(
          isA<FirestoreException>().having(
            (e) => e.errorCode,
            'errorCode',
            FirestoreClientErrorCode.failedPrecondition,
          ),
        ),
      );
    });

    test('getAggregateQuery() works in read-only transaction', () async {
      await collection.add({'price': 100});
      await collection.add({'price': 200});

      final snapshot = await firestore.runTransaction((transaction) async {
        return transaction.getAggregateQuery(collection.sum('price'));
      }, transactionOptions: ReadOnlyTransactionOptions());

      expect(snapshot.getSum('price'), 300);
    });

    test('getAggregateQuery() works with filtered queries', () async {
      await collection.add({'price': 10, 'category': 'A'});
      await collection.add({'price': 20, 'category': 'B'});
      await collection.add({'price': 30, 'category': 'A'});

      final query = collection.where('category', WhereFilter.equal, 'A');

      final snapshot = await firestore.runTransaction((transaction) async {
        return transaction.getAggregateQuery(query.sum('price'));
      });

      expect(snapshot.getSum('price'), 40);
    });

    test('getAggregateQuery() provides consistent snapshot', () async {
      await collection.add({'value': 10});
      await collection.add({'value': 20});
      final results = await firestore.runTransaction((transaction) async {
        final agg1 = await transaction.getAggregateQuery(collection.count());
        final agg2 = await transaction.getAggregateQuery(
          collection.sum('value'),
        );

        return {
          'count': agg1.count,
          'sum': agg2.getSum('value'),
          'readTime1': agg1.readTime,
          'readTime2': agg2.readTime,
        };
      });

      expect(results['count'], 2);
      expect(results['sum'], 30);
      // Both aggregations should have readTime values (transaction snapshot)
      expect(results['readTime1'], isNotNull);
      expect(results['readTime2'], isNotNull);
    });

    test('getAggregateQuery() works with converter', () async {
      // Add documents to regular collection
      await collection.add({'value': 10});
      await collection.add({'value': 20});

      // Use aggregation on the collection - converters don't affect aggregations
      final snapshot = await firestore.runTransaction((transaction) async {
        return transaction.getAggregateQuery(collection.sum('value'));
      });

      expect(snapshot.getSum('value'), 30);
    });

    test('getAggregateQuery() works with collection groups', () async {
      final doc1 = collection.doc('doc1');
      final doc2 = collection.doc('doc2');

      await doc1.set({'type': 'parent'});
      await doc2.set({'type': 'parent'});

      await doc1.collection('items').add({'price': 10});
      await doc1.collection('items').add({'price': 20});
      await doc2.collection('items').add({'price': 30});

      final collectionGroup = firestore.collectionGroup('items');

      final snapshot = await firestore.runTransaction((transaction) async {
        return transaction.getAggregateQuery(
          collectionGroup.aggregate(const count(), const sum('price')),
        );
      });

      expect(snapshot.count, 3);
      expect(snapshot.getSum('price'), 60);
    });

    test('multiple getAggregateQuery() calls in same transaction', () async {
      await collection.add({'value': 10, 'category': 'A'});
      await collection.add({'value': 20, 'category': 'B'});
      await collection.add({'value': 30, 'category': 'A'});

      final results = await firestore.runTransaction((transaction) async {
        final totalCount = await transaction.getAggregateQuery(
          collection.count(),
        );
        final categoryA = await transaction.getAggregateQuery(
          collection.where('category', WhereFilter.equal, 'A').count(),
        );
        final totalSum = await transaction.getAggregateQuery(
          collection.sum('value'),
        );

        return {
          'total': totalCount.count,
          'categoryA': categoryA.count,
          'sum': totalSum.getSum('value'),
        };
      });

      expect(results['total'], 3);
      expect(results['categoryA'], 2);
      expect(results['sum'], 60);
    });

    test('getAggregateQuery() mixed with getQuery() in transaction', () async {
      await collection.add({'name': 'Alice', 'score': 80});
      await collection.add({'name': 'Bob', 'score': 90});
      await collection.add({'name': 'Charlie', 'score': 100});

      final result = await firestore.runTransaction((transaction) async {
        final aggSnapshot = await transaction.getAggregateQuery(
          collection.average('score'),
        );
        final querySnapshot = await transaction.getQuery(collection.limit(2));

        return {
          'averageScore': aggSnapshot.getAverage('score'),
          'firstTwoDocs': querySnapshot.docs.length,
          'names': querySnapshot.docs.map((d) => d.get('name')).toList(),
        };
      });

      expect(result['averageScore'], 90.0);
      expect(result['firstTwoDocs'], 2);
      expect((result['names']! as List).length, 2);
    });

    test('getAggregateQuery() with empty results', () async {
      final snapshot = await firestore.runTransaction((transaction) async {
        return transaction.getAggregateQuery(
          collection.where('nonexistent', WhereFilter.equal, 'value').count(),
        );
      });

      expect(snapshot.count, 0);
    });

    test('getAggregateQuery() with complex filter', () async {
      await collection.add({'price': 10, 'category': 'A', 'available': true});
      await collection.add({'price': 20, 'category': 'B', 'available': false});
      await collection.add({'price': 30, 'category': 'A', 'available': true});
      await collection.add({'price': 40, 'category': 'B', 'available': true});

      final filter = Filter.and([
        Filter.where('available', WhereFilter.equal, true),
        Filter.or([
          Filter.where('category', WhereFilter.equal, 'A'),
          Filter.where('price', WhereFilter.greaterThanOrEqual, 40),
        ]),
      ]);

      final snapshot = await firestore.runTransaction((transaction) async {
        return transaction.getAggregateQuery(
          collection.whereFilter(filter).sum('price'),
        );
      });

      expect(snapshot.getSum('price'), 80); // 10 + 30 + 40
    });

    test('getAggregateQuery() mixed with get() in transaction', () async {
      final doc1 = await collection.add({'name': 'Alice', 'score': 80});
      await collection.add({'name': 'Bob', 'score': 90});

      final result = await firestore.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(doc1);
        final aggSnapshot = await transaction.getAggregateQuery(
          collection.average('score'),
        );

        return {
          'docName': docSnapshot.data()!['name'],
          'docScore': docSnapshot.data()!['score'],
          'avgScore': aggSnapshot.getAverage('score'),
        };
      });

      expect(result['docName'], 'Alice');
      expect(result['docScore'], 80);
      expect(result['avgScore'], 85.0); // (80 + 90) / 2
    });
  }, tags: 'firebase-emulator');
}
