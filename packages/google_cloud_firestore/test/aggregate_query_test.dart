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
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'fixtures/helpers.dart';

class MockFirestoreHttpClient extends Mock implements FirestoreHttpClient {}

firestore_v1.RunAggregationQueryResponse _countResponse(int count) {
  return firestore_v1.RunAggregationQueryResponse(
    result: firestore_v1.AggregationResult(
      aggregateFields: {'count': firestore_v1.Value(integerValue: count)},
    ),
  );
}

final _connectionClosedError = http.ClientException(
  'Connection closed before full header was received',
);

void main() {
  group(
    'AggregateQuery.get() retries on transient connection errors (unit)',
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

      test('retries once and succeeds after a ClientException', () async {
        var callCount = 0;
        when(
          () => mockClient.v1<Stream<firestore_v1.RunAggregationQueryResponse>>(
            any(),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return Stream<firestore_v1.RunAggregationQueryResponse>.error(
              _connectionClosedError,
            );
          }
          return Stream.fromIterable([_countResponse(42)]);
        });

        final snapshot = await firestore.collection('numbers').count().get();

        expect(callCount, 2);
        expect(snapshot.count, 42);
      });

      test('gives up and rethrows after repeated ClientExceptions', () async {
        var callCount = 0;
        when(
          () => mockClient.v1<Stream<firestore_v1.RunAggregationQueryResponse>>(
            any(),
          ),
        ).thenAnswer((_) async {
          callCount++;
          return Stream<firestore_v1.RunAggregationQueryResponse>.error(
            _connectionClosedError,
          );
        });

        await expectLater(
          firestore.collection('numbers').count().get(),
          throwsA(isA<http.ClientException>()),
        );

        expect(callCount, greaterThan(1));
      });
    },
  );

  group('AggregateQuery', () {
    late Firestore firestore;
    late CollectionReference<DocumentData> collection;

    setUp(() async {
      firestore = await createFirestore();
      collection = firestore.collection(
        'aggregate-test-${DateTime.now().millisecondsSinceEpoch}',
      );
    });

    test('count() on empty collection returns 0', () async {
      final query = collection.where('foo', WhereFilter.equal, 'bar');
      final aggregateQuery = query.count();
      final snapshot = await aggregateQuery.get();

      expect(snapshot.count, 0);
    });

    test('count() returns correct count for matching documents', () async {
      // Add some test documents
      await collection.add({'name': 'Alice', 'age': 30});
      await collection.add({'name': 'Bob', 'age': 25});
      await collection.add({'name': 'Charlie', 'age': 30});
      await collection.add({'name': 'David', 'age': 35});

      // Test count without filter
      final allCount = await collection.count().get();
      expect(allCount.count, 4);

      // Test count with filter
      final filtered = await collection
          .where('age', WhereFilter.equal, 30)
          .count()
          .get();
      expect(filtered.count, 2);
    });

    test('count() works with complex queries', () async {
      // Add test documents
      await collection.add({
        'category': 'books',
        'price': 15.99,
        'inStock': true,
      });
      await collection.add({
        'category': 'books',
        'price': 25.99,
        'inStock': false,
      });
      await collection.add({
        'category': 'books',
        'price': 9.99,
        'inStock': true,
      });
      await collection.add({
        'category': 'electronics',
        'price': 199.99,
        'inStock': true,
      });
      await collection.add({
        'category': 'electronics',
        'price': 299.99,
        'inStock': false,
      });

      // Test with multiple where conditions
      final query = collection
          .where('category', WhereFilter.equal, 'books')
          .where('inStock', WhereFilter.equal, true);
      final count = await query.count().get();
      expect(count.count, 2);

      // Test with range query
      final rangeQuery = collection
          .where('price', WhereFilter.greaterThanOrEqual, 20)
          .where('price', WhereFilter.lessThan, 200);
      final rangeCount = await rangeQuery.count().get();
      expect(rangeCount.count, 2);
    });

    test('count() works with orderBy and limit', () async {
      // Add test documents
      for (var i = 1; i <= 10; i++) {
        await collection.add({'value': i});
      }

      // Test with limit
      final limitQuery = collection.orderBy('value').limit(5);
      final limitCount = await limitQuery.count().get();
      expect(limitCount.count, 5);

      // Test with limitToLast
      final limitToLastQuery = collection.orderBy('value').limitToLast(3);
      final limitToLastCount = await limitToLastQuery.count().get();
      expect(limitToLastCount.count, 3);
    });

    test('count() works with startAt and endAt', () async {
      // Add test documents
      for (var i = 1; i <= 10; i++) {
        await collection.add({'value': i});
      }

      // Test with startAt
      final startAtQuery = collection.orderBy('value').startAt([5]);
      final startAtCount = await startAtQuery.count().get();
      expect(startAtCount.count, 6); // values 5-10

      // Test with endBefore
      final endBeforeQuery = collection.orderBy('value').endBefore([7]);
      final endBeforeCount = await endBeforeQuery.count().get();
      expect(endBeforeCount.count, 6); // values 1-6

      // Test with both startAfter and endAt
      final rangeQuery = collection.orderBy('value').startAfter([3]).endAt([8]);
      final rangeCount = await rangeQuery.count().get();
      expect(rangeCount.count, 5); // values 4-8
    });

    test('count() works with collection groups', () async {
      // Create documents with subcollections
      final doc1 = collection.doc('doc1');
      final doc2 = collection.doc('doc2');

      await doc1.set({'type': 'parent'});
      await doc2.set({'type': 'parent'});

      await doc1.collection('items').add({'name': 'item1'});
      await doc1.collection('items').add({'name': 'item2'});
      await doc2.collection('items').add({'name': 'item3'});

      // Count collection group
      final collectionGroup = firestore.collectionGroup('items');
      final groupCount = await collectionGroup.count().get();
      expect(groupCount.count, 3);
    });

    test('AggregateQuerySnapshot provides readTime', () async {
      await collection.add({'test': true});

      final snapshot = await collection.count().get();
      expect(snapshot.count, 1);
      expect(snapshot.readTime, isNotNull);
    });

    test('AggregateQuery equality', () {
      final query1 = collection.where('foo', WhereFilter.equal, 'bar');
      final query2 = collection.where('foo', WhereFilter.equal, 'bar');
      final query3 = collection.where('foo', WhereFilter.equal, 'baz');

      final aggregate1 = query1.count();
      final aggregate2 = query2.count();
      final aggregate3 = query3.count();

      expect(aggregate1, equals(aggregate2));
      expect(aggregate1, isNot(equals(aggregate3)));
      expect(aggregate1.hashCode, equals(aggregate2.hashCode));
    });

    test('AggregateQuerySnapshot equality', () async {
      await collection.add({'test': true});

      final aggregate = collection.count();
      final snapshot1 = await aggregate.get();
      final snapshot2 = await aggregate.get();

      // Note: These won't be equal because readTime will be different
      // But we can test the structure
      expect(snapshot1.query, equals(snapshot2.query));
      expect(snapshot1.count, equals(snapshot2.count));
    });

    test('count() with composite filters', () async {
      await collection.add({'a': 1, 'b': 'x'});
      await collection.add({'a': 2, 'b': 'y'});
      await collection.add({'a': 3, 'b': 'x'});
      await collection.add({'a': 1, 'b': 'y'});

      // Test AND filter
      final andFilter = Filter.and([
        Filter.where('a', WhereFilter.greaterThan, 1),
        Filter.where('b', WhereFilter.equal, 'x'),
      ]);
      final andCount = await collection.whereFilter(andFilter).count().get();
      expect(andCount.count, 1); // Only {a: 3, b: 'x'} matches

      // Test OR filter
      final orFilter = Filter.or([
        Filter.where('a', WhereFilter.equal, 1),
        Filter.where('b', WhereFilter.equal, 'y'),
      ]);
      final orCount = await collection.whereFilter(orFilter).count().get();
      expect(
        orCount.count,
        3,
      ); // {a: 1, b: 'x'}, {a: 2, b: 'y'}, {a: 1, b: 'y'}
    });

    test('getField() returns correct values', () async {
      await collection.add({'test': true});

      final snapshot = await collection.count().get();
      expect(snapshot.getField('count'), equals(snapshot.count));
      expect(snapshot.getField('nonexistent'), isNull);
    });

    test('sum() aggregation works correctly', () async {
      await collection.add({'price': 10.5});
      await collection.add({'price': 20.0});
      await collection.add({'price': 15.5});

      final snapshot = await collection.aggregate(const sum('price')).get();

      expect(snapshot.getSum('price'), equals(46.0));
    });

    test('average() aggregation works correctly', () async {
      await collection.add({'score': 80});
      await collection.add({'score': 90});
      await collection.add({'score': 100});

      final snapshot = await collection.aggregate(const average('score')).get();

      expect(snapshot.getAverage('score'), equals(90.0));
    });

    test('multiple aggregations work together', () async {
      await collection.add({'value': 10, 'category': 'A'});
      await collection.add({'value': 20, 'category': 'A'});
      await collection.add({'value': 30, 'category': 'B'});
      await collection.add({'value': 40, 'category': 'B'});

      final snapshot = await collection
          .where('category', WhereFilter.equal, 'A')
          .aggregate(const count(), const sum('value'), const average('value'))
          .get();

      expect(snapshot.count, equals(2));
      expect(snapshot.getSum('value'), equals(30));
      expect(snapshot.getAverage('value'), equals(15.0));
    });

    test('aggregate() with single field works', () async {
      await collection.add({'amount': 100});
      await collection.add({'amount': 200});

      final snapshot = await collection.aggregate(const count()).get();

      expect(snapshot.count, equals(2));
    });

    // Tests for the convenience sum() method
    group('sum() convenience method', () {
      test('sum() on empty collection returns 0', () async {
        final snapshot = await collection.sum('price').get();
        // Sum on empty collection returns 0, not null
        expect(snapshot.getSum('price'), equals(0));
      });

      test('sum() returns correct sum for numeric values', () async {
        await collection.add({'price': 10});
        await collection.add({'price': 20});
        await collection.add({'price': 30});

        final snapshot = await collection.sum('price').get();
        expect(snapshot.getSum('price'), equals(60));
      });

      test('sum() works with double values', () async {
        await collection.add({'amount': 10.5});
        await collection.add({'amount': 20.25});
        await collection.add({'amount': 15.75});

        final snapshot = await collection.sum('amount').get();
        expect(snapshot.getSum('amount'), equals(46.5));
      });

      test('sum() works with mixed int and double values', () async {
        await collection.add({'value': 10});
        await collection.add({'value': 20.5});
        await collection.add({'value': 15});

        final snapshot = await collection.sum('value').get();
        expect(snapshot.getSum('value'), equals(45.5));
      });

      test('sum() works with filtered query', () async {
        await collection.add({'price': 10, 'category': 'A'});
        await collection.add({'price': 20, 'category': 'B'});
        await collection.add({'price': 30, 'category': 'A'});
        await collection.add({'price': 40, 'category': 'B'});

        final snapshot = await collection
            .where('category', WhereFilter.equal, 'A')
            .sum('price')
            .get();

        expect(snapshot.getSum('price'), equals(40));
      });

      test('sum() works with complex queries', () async {
        await collection.add({'price': 10, 'inStock': true});
        await collection.add({'price': 20, 'inStock': false});
        await collection.add({'price': 30, 'inStock': true});
        await collection.add({'price': 40, 'inStock': true});
        await collection.add({'price': 50, 'inStock': false});

        final snapshot = await collection
            .where('inStock', WhereFilter.equal, true)
            .where('price', WhereFilter.greaterThanOrEqual, 20)
            .sum('price')
            .get();

        expect(snapshot.getSum('price'), equals(70)); // 30 + 40
      });

      test('sum() works with orderBy and limit', () async {
        await collection.add({'value': 5, 'order': 1});
        await collection.add({'value': 10, 'order': 2});
        await collection.add({'value': 15, 'order': 3});
        await collection.add({'value': 20, 'order': 4});
        await collection.add({'value': 25, 'order': 5});

        final snapshot = await collection
            .orderBy('order')
            .limit(3)
            .sum('value')
            .get();

        expect(snapshot.getSum('value'), equals(30)); // 5 + 10 + 15
      });

      test('sum() works with startAt and endAt', () async {
        await collection.add({'value': 10, 'order': 1});
        await collection.add({'value': 20, 'order': 2});
        await collection.add({'value': 30, 'order': 3});
        await collection.add({'value': 40, 'order': 4});
        await collection.add({'value': 50, 'order': 5});

        final snapshot = await collection
            .orderBy('order')
            .startAt([2])
            .endAt([4])
            .sum('value')
            .get();

        expect(snapshot.getSum('value'), equals(90)); // 20 + 30 + 40
      });

      test('sum() works with composite filters', () async {
        await collection.add({'price': 10, 'category': 'A', 'available': true});
        await collection.add({
          'price': 20,
          'category': 'B',
          'available': false,
        });
        await collection.add({'price': 30, 'category': 'A', 'available': true});
        await collection.add({'price': 40, 'category': 'B', 'available': true});

        final filter = Filter.and([
          Filter.where('available', WhereFilter.equal, true),
          Filter.or([
            Filter.where('category', WhereFilter.equal, 'A'),
            Filter.where('price', WhereFilter.greaterThanOrEqual, 40),
          ]),
        ]);

        final snapshot = await collection
            .whereFilter(filter)
            .sum('price')
            .get();

        expect(snapshot.getSum('price'), equals(80)); // 10 + 30 + 40
      });

      test('sum() returns null for documents without the field', () async {
        await collection.add({'price': 10});
        await collection.add({'other': 20}); // missing 'price' field
        await collection.add({'price': 30});

        final snapshot = await collection.sum('price').get();

        // Sum should only include documents with the field
        expect(snapshot.getSum('price'), equals(40));
      });
    });

    // Tests for the convenience average() method
    group('average() convenience method', () {
      test('average() on empty collection returns null or NaN', () async {
        final snapshot = await collection.average('score').get();
        // Average on empty collection returns null (can't divide by zero)
        final avg = snapshot.getAverage('score');
        expect(avg == null || avg.isNaN, isTrue);
      });

      test('average() returns correct average for integer values', () async {
        await collection.add({'score': 80});
        await collection.add({'score': 90});
        await collection.add({'score': 100});

        final snapshot = await collection.average('score').get();
        expect(snapshot.getAverage('score'), equals(90.0));
      });

      test('average() works with double values', () async {
        await collection.add({'rating': 4.5});
        await collection.add({'rating': 3.5});
        await collection.add({'rating': 5.0});

        final snapshot = await collection.average('rating').get();
        expect(snapshot.getAverage('rating'), closeTo(4.333, 0.001));
      });

      test('average() works with mixed int and double values', () async {
        await collection.add({'value': 10});
        await collection.add({'value': 20.5});
        await collection.add({'value': 15.5});

        final snapshot = await collection.average('value').get();
        expect(snapshot.getAverage('value'), closeTo(15.333, 0.001));
      });

      test('average() works with filtered query', () async {
        await collection.add({'score': 80, 'category': 'A'});
        await collection.add({'score': 60, 'category': 'B'});
        await collection.add({'score': 90, 'category': 'A'});
        await collection.add({'score': 70, 'category': 'B'});

        final snapshot = await collection
            .where('category', WhereFilter.equal, 'A')
            .average('score')
            .get();

        expect(snapshot.getAverage('score'), equals(85.0));
      });

      test('average() works with complex queries', () async {
        await collection.add({'score': 50, 'passed': false});
        await collection.add({'score': 80, 'passed': true});
        await collection.add({'score': 90, 'passed': true});
        await collection.add({'score': 70, 'passed': true});
        await collection.add({'score': 40, 'passed': false});

        final snapshot = await collection
            .where('passed', WhereFilter.equal, true)
            .where('score', WhereFilter.greaterThanOrEqual, 75)
            .average('score')
            .get();

        expect(snapshot.getAverage('score'), equals(85.0)); // (80 + 90) / 2
      });

      test('average() works with orderBy and limit', () async {
        await collection.add({'value': 10, 'order': 1});
        await collection.add({'value': 20, 'order': 2});
        await collection.add({'value': 30, 'order': 3});
        await collection.add({'value': 40, 'order': 4});
        await collection.add({'value': 50, 'order': 5});

        final snapshot = await collection
            .orderBy('order')
            .limit(3)
            .average('value')
            .get();

        expect(
          snapshot.getAverage('value'),
          equals(20.0),
        ); // (10 + 20 + 30) / 3
      });

      test('average() works with startAt and endAt', () async {
        await collection.add({'value': 10, 'order': 1});
        await collection.add({'value': 20, 'order': 2});
        await collection.add({'value': 30, 'order': 3});
        await collection.add({'value': 40, 'order': 4});
        await collection.add({'value': 50, 'order': 5});

        final snapshot = await collection
            .orderBy('order')
            .startAt([2])
            .endAt([4])
            .average('value')
            .get();

        expect(
          snapshot.getAverage('value'),
          equals(30.0),
        ); // (20 + 30 + 40) / 3
      });

      test('average() works with composite filters', () async {
        await collection.add({'price': 100, 'category': 'A', 'premium': true});
        await collection.add({'price': 50, 'category': 'B', 'premium': false});
        await collection.add({'price': 150, 'category': 'A', 'premium': true});
        await collection.add({'price': 200, 'category': 'B', 'premium': true});

        final filter = Filter.and([
          Filter.where('premium', WhereFilter.equal, true),
          Filter.or([
            Filter.where('category', WhereFilter.equal, 'A'),
            Filter.where('price', WhereFilter.greaterThanOrEqual, 200),
          ]),
        ]);

        final snapshot = await collection
            .whereFilter(filter)
            .average('price')
            .get();

        expect(
          snapshot.getAverage('price'),
          equals(150.0),
        ); // (100 + 150 + 200) / 3
      });

      test('average() returns null for documents without the field', () async {
        await collection.add({'score': 80});
        await collection.add({'other': 90}); // missing 'score' field
        await collection.add({'score': 100});

        final snapshot = await collection.average('score').get();

        // Average should only include documents with the field
        expect(snapshot.getAverage('score'), equals(90.0));
      });

      test('average() with single document', () async {
        await collection.add({'value': 42});

        final snapshot = await collection.average('value').get();
        expect(snapshot.getAverage('value'), equals(42.0));
      });
    });

    // Combined tests for sum(), average(), and count()
    group('combined aggregations', () {
      test('sum() and average() work together', () async {
        await collection.add({'value': 10});
        await collection.add({'value': 20});
        await collection.add({'value': 30});

        final snapshot = await collection
            .aggregate(const sum('value'), const average('value'))
            .get();

        expect(snapshot.getSum('value'), equals(60));
        expect(snapshot.getAverage('value'), equals(20.0));
      });

      test('count(), sum(), and average() work together', () async {
        await collection.add({'price': 10, 'category': 'A'});
        await collection.add({'price': 20, 'category': 'A'});
        await collection.add({'price': 30, 'category': 'B'});

        final snapshot = await collection
            .where('category', WhereFilter.equal, 'A')
            .aggregate(
              const count(),
              const sum('price'),
              const average('price'),
            )
            .get();

        expect(snapshot.count, equals(2));
        expect(snapshot.getSum('price'), equals(30));
        expect(snapshot.getAverage('price'), equals(15.0));
      });

      test('multiple sum() and average() aggregations', () async {
        await collection.add({'price': 10, 'quantity': 5});
        await collection.add({'price': 20, 'quantity': 3});
        await collection.add({'price': 15, 'quantity': 4});

        // Test with up to 3 aggregations (max allowed by aggregate method)
        final snapshot = await collection
            .aggregate(
              const sum('price'),
              const average('price'),
              const sum('quantity'),
            )
            .get();

        expect(snapshot.getSum('price'), equals(45));
        expect(snapshot.getSum('quantity'), equals(12));
        expect(snapshot.getAverage('price'), equals(15.0));
      });

      test('sum() and average() on different fields', () async {
        await collection.add({'price': 10, 'quantity': 5});
        await collection.add({'price': 20, 'quantity': 3});
        await collection.add({'price': 15, 'quantity': 4});

        // Test average on quantity separately
        final snapshot = await collection.average('quantity').get();
        expect(snapshot.getAverage('quantity'), equals(4.0));
      });

      test('aggregations work with collection groups', () async {
        final doc1 = collection.doc('doc1');
        final doc2 = collection.doc('doc2');

        await doc1.set({'type': 'parent'});
        await doc2.set({'type': 'parent'});

        await doc1.collection('items').add({'price': 10});
        await doc1.collection('items').add({'price': 20});
        await doc2.collection('items').add({'price': 30});

        final collectionGroup = firestore.collectionGroup('items');
        final snapshot = await collectionGroup
            .aggregate(
              const count(),
              const sum('price'),
              const average('price'),
            )
            .get();

        expect(snapshot.count, equals(3));
        expect(snapshot.getSum('price'), equals(60));
        expect(snapshot.getAverage('price'), equals(20.0));
      });
    });

    // Edge case tests
    group('edge cases', () {
      test('sum() with zero values', () async {
        await collection.add({'value': 0});
        await collection.add({'value': 0});
        await collection.add({'value': 0});

        final snapshot = await collection.sum('value').get();
        expect(snapshot.getSum('value'), equals(0));
      });

      test('average() with zero values', () async {
        await collection.add({'value': 0});
        await collection.add({'value': 0});
        await collection.add({'value': 0});

        final snapshot = await collection.average('value').get();
        expect(snapshot.getAverage('value'), equals(0.0));
      });

      test('sum() with negative values', () async {
        await collection.add({'value': -10});
        await collection.add({'value': 20});
        await collection.add({'value': -5});

        final snapshot = await collection.sum('value').get();
        expect(snapshot.getSum('value'), equals(5));
      });

      test('average() with negative values', () async {
        await collection.add({'value': -10});
        await collection.add({'value': 20});
        await collection.add({'value': -20});

        final snapshot = await collection.average('value').get();
        expect(snapshot.getAverage('value'), closeTo(-3.333, 0.001));
      });

      test('sum() with very large numbers', () async {
        await collection.add({'value': 1000000000});
        await collection.add({'value': 2000000000});
        await collection.add({'value': 3000000000});

        final snapshot = await collection.sum('value').get();
        expect(snapshot.getSum('value'), equals(6000000000));
      });

      test('average() with very small numbers', () async {
        await collection.add({'value': 0.001});
        await collection.add({'value': 0.002});
        await collection.add({'value': 0.003});

        final snapshot = await collection.average('value').get();
        expect(snapshot.getAverage('value'), closeTo(0.002, 0.0001));
      });

      test('aggregations provide consistent readTime', () async {
        await collection.add({'value': 10});

        final snapshot = await collection
            .aggregate(
              const count(),
              const sum('value'),
              const average('value'),
            )
            .get();

        expect(snapshot.readTime, isNotNull);
        expect(snapshot.count, equals(1));
        expect(snapshot.getSum('value'), equals(10));
        expect(snapshot.getAverage('value'), equals(10.0));
      });
    });

    group('FieldPath support', () {
      test('sum() works with FieldPath for nested fields', () async {
        await collection.add({
          'product': {'price': 10},
        });
        await collection.add({
          'product': {'price': 20},
        });
        await collection.add({
          'product': {'price': 15},
        });

        final snapshot = await collection
            .sum(FieldPath(const ['product', 'price']))
            .get();

        expect(snapshot.getSum('product.price'), equals(45));
      });

      test('average() works with FieldPath for nested fields', () async {
        await collection.add({
          'product': {'price': 10},
        });
        await collection.add({
          'product': {'price': 20},
        });
        await collection.add({
          'product': {'price': 15},
        });

        final snapshot = await collection
            .average(FieldPath(const ['product', 'price']))
            .get();

        expect(snapshot.getAverage('product.price'), equals(15.0));
      });

      test('AggregateField.sum() works with FieldPath', () async {
        await collection.add({
          'nested': {'value': 100},
        });
        await collection.add({
          'nested': {'value': 200},
        });

        final snapshot = await collection
            .aggregate(AggregateField.sum(FieldPath(const ['nested', 'value'])))
            .get();

        expect(snapshot.getSum('nested.value'), equals(300));
      });

      test('AggregateField.average() works with FieldPath', () async {
        await collection.add({
          'nested': {'score': 85},
        });
        await collection.add({
          'nested': {'score': 90},
        });
        await collection.add({
          'nested': {'score': 95},
        });

        final snapshot = await collection
            .aggregate(
              AggregateField.average(FieldPath(const ['nested', 'score'])),
            )
            .get();

        expect(snapshot.getAverage('nested.score'), equals(90.0));
      });

      test('combined aggregations work with FieldPath', () async {
        await collection.add({
          'data': {'price': 10, 'quantity': 5},
        });
        await collection.add({
          'data': {'price': 20, 'quantity': 3},
        });

        final snapshot = await collection
            .aggregate(
              AggregateField.sum(FieldPath(const ['data', 'price'])),
              AggregateField.average(FieldPath(const ['data', 'quantity'])),
            )
            .get();

        expect(snapshot.getSum('data.price'), equals(30));
        expect(snapshot.getAverage('data.quantity'), equals(4.0));
      });

      test('FieldPath works with deeply nested fields', () async {
        await collection.add({
          'level1': {
            'level2': {
              'level3': {'value': 42},
            },
          },
        });
        await collection.add({
          'level1': {
            'level2': {
              'level3': {'value': 58},
            },
          },
        });

        final snapshot = await collection
            .sum(FieldPath(const ['level1', 'level2', 'level3', 'value']))
            .get();

        expect(snapshot.getSum('level1.level2.level3.value'), equals(100));
      });

      test('FieldPath and String fields can be mixed', () async {
        await collection.add({
          'price': 10,
          'nested': {'cost': 5},
        });
        await collection.add({
          'price': 20,
          'nested': {'cost': 10},
        });

        final snapshot = await collection
            .aggregate(
              const sum('price'),
              AggregateField.sum(FieldPath(const ['nested', 'cost'])),
            )
            .get();

        expect(snapshot.getSum('price'), equals(30));
        expect(snapshot.getSum('nested.cost'), equals(15));
      });

      test('AggregateField.sum() rejects invalid field types', () {
        expect(() => AggregateField.sum(123), throwsA(isA<AssertionError>()));
      });

      test('AggregateField.average() rejects invalid field types', () {
        expect(
          () => AggregateField.average(123),
          throwsA(isA<AssertionError>()),
        );
      });

      test('Query.sum() rejects invalid field types', () {
        expect(() => collection.sum(123), throwsA(isA<AssertionError>()));
      });

      test('Query.average() rejects invalid field types', () {
        expect(() => collection.average(123), throwsA(isA<AssertionError>()));
      });
    });
  }, tags: 'firebase-emulator');
}
