// Copyright 2020, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Tags(['firebase-emulator'])
library;

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';
import 'fixtures/helpers.dart' as helpers;

void main() {
  group('Transaction Query', () {
    late Firestore firestore;

    setUp(() async {
      firestore = await helpers.createFirestore();
    });

    Future<CollectionReference<Map<String, dynamic>>> initializeCollection(
      String path,
    ) async {
      final prefixedPath = 'flutter-tests/test-doc/$path';
      final collection = firestore.collection(prefixedPath);

      // Clean up existing documents
      final existingDocs = await collection.get();
      for (final doc in existingDocs.docs) {
        await doc.ref.delete();
      }

      addTearDown(() async {
        final docs = await collection.get();
        for (final doc in docs.docs) {
          await doc.ref.delete();
        }
      });

      return collection;
    }

    test('get query results in a transaction', () async {
      final collection = await initializeCollection('query-test');

      // Add test documents
      await collection.doc('doc1').set({'value': 1, 'type': 'test'});
      await collection.doc('doc2').set({'value': 2, 'type': 'test'});
      await collection.doc('doc3').set({'value': 3, 'type': 'other'});

      final result = await firestore.runTransaction((transaction) async {
        final query = collection.where('type', WhereFilter.equal, 'test');
        final snapshot = await transaction.getQuery(query);
        return snapshot.docs.length;
      });

      expect(result, 2);
    });

    test('get query with orderBy in a transaction', () async {
      final collection = await initializeCollection('query-order-test');

      await collection.doc('doc1').set({'value': 3});
      await collection.doc('doc2').set({'value': 1});
      await collection.doc('doc3').set({'value': 2});

      final result = await firestore.runTransaction((transaction) async {
        final query = collection.orderBy('value');
        final snapshot = await transaction.getQuery(query);
        return snapshot.docs.map((doc) => doc.data()['value']).toList();
      });

      expect(result, [1, 2, 3]);
    });

    test('get query with limit in a transaction', () async {
      final collection = await initializeCollection('query-limit-test');

      await collection.doc('doc1').set({'value': 1});
      await collection.doc('doc2').set({'value': 2});
      await collection.doc('doc3').set({'value': 3});

      final result = await firestore.runTransaction((transaction) async {
        final query = collection.limit(2);
        final snapshot = await transaction.getQuery(query);
        return snapshot.docs.length;
      });

      expect(result, 2);
    });

    test('get empty query results in a transaction', () async {
      final collection = await initializeCollection('query-empty-test');

      final result = await firestore.runTransaction((transaction) async {
        final query = collection.where('value', WhereFilter.equal, 999);
        final snapshot = await transaction.getQuery(query);
        return snapshot.docs.length;
      });

      expect(result, 0);
    });

    test('get query and then write in a transaction', () async {
      final collection = await initializeCollection('query-write-test');

      await collection.doc('doc1').set({'value': 1, 'processed': false});
      await collection.doc('doc2').set({'value': 2, 'processed': false});

      await firestore.runTransaction((transaction) async {
        final query = collection.where('processed', WhereFilter.equal, false);
        final snapshot = await transaction.getQuery(query);

        for (final doc in snapshot.docs) {
          transaction.update(doc.ref, {'processed': true});
        }
      });

      final updatedDocs = await collection.get();
      for (final doc in updatedDocs.docs) {
        expect(doc.data()['processed'], true);
      }
    });

    test('prevent getQuery after write in a transaction', () async {
      final collection = await initializeCollection('query-after-write-test');
      await collection.doc('doc1').set({'value': 1});

      expect(
        () async {
          await firestore.runTransaction((transaction) async {
            transaction.set(collection.doc('doc2'), {'value': 2});
            final query = collection.where('value', WhereFilter.equal, 1);
            return transaction.getQuery(query);
          });
          fail('Transaction should not have resolved');
        },
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains(Transaction.readAfterWriteErrorMsg),
          ),
        ),
      );
    });

    test('multiple getQuery calls in same transaction', () async {
      final collection = await initializeCollection('query-multiple-test');

      await collection.doc('doc1').set({'type': 'A', 'value': 1});
      await collection.doc('doc2').set({'type': 'B', 'value': 2});
      await collection.doc('doc3').set({'type': 'A', 'value': 3});

      final result = await firestore.runTransaction((transaction) async {
        final queryA = collection.where('type', WhereFilter.equal, 'A');
        final queryB = collection.where('type', WhereFilter.equal, 'B');

        final snapshotA = await transaction.getQuery(queryA);
        final snapshotB = await transaction.getQuery(queryB);

        return {
          'countA': snapshotA.docs.length,
          'countB': snapshotB.docs.length,
        };
      });

      expect(result['countA'], 2);
      expect(result['countB'], 1);
    });

    test('getQuery with complex where clauses in a transaction', () async {
      final collection = await initializeCollection('query-complex-test');

      await collection.doc('doc1').set({'age': 25, 'active': true});
      await collection.doc('doc2').set({'age': 30, 'active': true});
      await collection.doc('doc3').set({'age': 35, 'active': false});

      final result = await firestore.runTransaction((transaction) async {
        final query = collection
            .where('age', WhereFilter.greaterThan, 20)
            .where('active', WhereFilter.equal, true);
        final snapshot = await transaction.getQuery(query);
        return snapshot.docs.length;
      });

      expect(result, 2);
    });

    test('getQuery works with withConverter in a transaction', () async {
      final collection = await initializeCollection('query-converter-test');

      final typedCollection = collection.withConverter<int>(
        fromFirestore: (snapshot) => snapshot.data()['value']! as int,
        toFirestore: (value) => {'value': value},
      );

      await typedCollection.doc('doc1').set(10);
      await typedCollection.doc('doc2').set(20);
      await typedCollection.doc('doc3').set(30);

      final result = await firestore.runTransaction<List<int>>((
        transaction,
      ) async {
        final query = typedCollection.where(
          'value',
          WhereFilter.greaterThan,
          15,
        );
        final snapshot = await transaction.getQuery(query);
        return snapshot.docs.map((doc) => doc.data()).toList();
      });

      expect(result, [20, 30]);
    });

    test('detects document change during query transaction', () async {
      final collection = await initializeCollection('query-conflict-test');
      await collection.doc('doc1').set({'value': 1});

      expect(
        () async {
          await firestore.runTransaction((transaction) async {
            final query = collection.where('value', WhereFilter.equal, 1);
            await transaction.getQuery(query);

            // Intentionally modify document during transaction
            await collection.doc('doc1').set({'value': 2});

            transaction.set(collection.doc('doc2'), {'value': 3});
          }, transactionOptions: ReadWriteTransactionOptions(maxAttempts: 1));
          fail('Transaction should not have resolved');
        },
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Transaction max attempts exceeded'),
          ),
        ),
      );
    });

    test('getQuery in read-only transaction', () async {
      final collection = await initializeCollection('query-readonly-test');

      await collection.doc('doc1').set({'value': 1});
      await collection.doc('doc2').set({'value': 2});

      final result = await firestore.runTransaction((transaction) async {
        final query = collection.where('value', WhereFilter.greaterThan, 0);
        final snapshot = await transaction.getQuery(query);
        return snapshot.docs.length;
      }, transactionOptions: ReadOnlyTransactionOptions());

      expect(result, 2);
    });

    test('getQuery with startAt and endAt cursors in transaction', () async {
      final collection = await initializeCollection('query-cursor-test');

      await collection.doc('doc1').set({'value': 10});
      await collection.doc('doc2').set({'value': 20});
      await collection.doc('doc3').set({'value': 30});
      await collection.doc('doc4').set({'value': 40});

      final result = await firestore.runTransaction((transaction) async {
        final query = collection.orderBy('value').startAt([15]).endAt([35]);
        final snapshot = await transaction.getQuery(query);
        return snapshot.docs.map((doc) => doc.data()['value']).toList();
      });

      expect(result, [20, 30]);
    });

    test('getQuery with offset in transaction', () async {
      final collection = await initializeCollection('query-offset-test');

      await collection.doc('doc1').set({'value': 1});
      await collection.doc('doc2').set({'value': 2});
      await collection.doc('doc3').set({'value': 3});
      await collection.doc('doc4').set({'value': 4});

      final result = await firestore.runTransaction((transaction) async {
        final query = collection.orderBy('value').offset(2);
        final snapshot = await transaction.getQuery(query);
        return snapshot.docs.map((doc) => doc.data()['value']).toList();
      });

      expect(result, [3, 4]);
    });

    test('combine get and getQuery in same transaction', () async {
      final collection = await initializeCollection('query-get-combo-test');

      await collection.doc('doc1').set({'value': 1, 'type': 'A'});
      await collection.doc('doc2').set({'value': 2, 'type': 'A'});
      await collection.doc('doc3').set({'value': 3, 'type': 'B'});

      final result = await firestore.runTransaction((transaction) async {
        // Get single document
        final singleDoc = await transaction.get(collection.doc('doc1'));

        // Get query results
        final query = collection.where('type', WhereFilter.equal, 'A');
        final querySnapshot = await transaction.getQuery(query);

        return {
          'singleValue': singleDoc.data()!['value'],
          'queryCount': querySnapshot.docs.length,
        };
      });

      expect(result['singleValue'], 1);
      expect(result['queryCount'], 2);
    });
  });
}
