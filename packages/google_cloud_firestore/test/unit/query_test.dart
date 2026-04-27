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
import 'package:google_cloud_firestore_v1/firestore.dart' as firestore_v1;
import 'package:test/test.dart';

import '../fixtures/helpers.dart';

void main() {
  group('query interface', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test('overrides ==', () {
      final queryA = firestore.collection('col1');
      final queryB = firestore.collection('col1');

      void queryEquals(
        List<Query<Object?>> equals, [
        List<Query<Object?>> notEquals = const [],
      ]) {
        for (var i = 0; i < equals.length; ++i) {
          for (final equal in equals) {
            expect(equals[i], equal);
            expect(equal, equals[i]);
          }

          for (final notEqual in notEquals) {
            expect(equals[i], isNot(notEqual));
            expect(notEqual, isNot(equals[i]));
          }
        }
      }

      queryEquals([
        queryA.where('a', WhereFilter.equal, '1'),
        queryB.where('a', WhereFilter.equal, '1'),
      ]);

      queryEquals([
        queryA
            .where('a', WhereFilter.equal, '1')
            .where('b', WhereFilter.equal, 2),
        queryB
            .where('a', WhereFilter.equal, '1')
            .where('b', WhereFilter.equal, 2),
      ]);

      queryEquals(
        [
          queryA.orderBy('__name__'),
          queryA.orderBy('__name__', descending: false),
          queryB.orderBy(FieldPath.documentId),
        ],
        [
          queryA.orderBy('foo'),
          queryB.orderBy(FieldPath.documentId, descending: true),
        ],
      );

      queryEquals(
        [queryA.limit(0), queryB.limit(0).limit(0)],
        [queryA, queryB.limit(10)],
      );

      queryEquals(
        [queryA.offset(0), queryB.offset(0).offset(0)],
        [queryA, queryB.offset(10)],
      );

      queryEquals(
        [
          queryA.orderBy('foo').startAt(['a']),
          queryB.orderBy('foo').startAt(['a']),
        ],
        [
          queryA.orderBy('foo').startAfter(['a']),
          queryB.orderBy('foo').endAt(['a']),
          queryA.orderBy('foo').endBefore(['a']),
          queryB.orderBy('foo').startAt(['b']),
          queryA.orderBy('bar').startAt(['a']),
        ],
      );

      queryEquals(
        [
          queryA.orderBy('foo').startAfter(['a']),
          queryB.orderBy('foo').startAfter(['a']),
        ],
        [
          queryA.orderBy('foo').startAfter(['b']),
          queryB.orderBy('bar').startAfter(['a']),
        ],
      );

      queryEquals(
        [
          queryA.orderBy('foo').endBefore(['a']),
          queryB.orderBy('foo').endBefore(['a']),
        ],
        [
          queryA.orderBy('foo').endBefore(['b']),
          queryB.orderBy('bar').endBefore(['a']),
        ],
      );

      queryEquals(
        [
          queryA.orderBy('foo').endAt(['a']),
          queryB.orderBy('foo').endAt(['a']),
        ],
        [
          queryA.orderBy('foo').endAt(['b']),
          queryB.orderBy('bar').endAt(['a']),
        ],
      );

      queryEquals([
        queryA.orderBy('foo').orderBy('__name__').startAt([
          'b',
          queryA.doc('c'),
        ]),
        queryB.orderBy('foo').orderBy('__name__').startAt([
          'b',
          queryA.doc('c'),
        ]),
      ]);
    });

    test('accepts all variations', () async {
      final query = firestore
          .collection('allVarations')
          .where('foo', WhereFilter.equal, '1')
          .orderBy('foo')
          .limit(10);

      final snapshot = await query.get();

      expect(snapshot.docs, isEmpty);
      expect(snapshot.query, query);
    });

    test('Supports empty gets', () async {
      final snapshot = await firestore.collection('emptyget').get();

      expect(snapshot.docs, isEmpty);
      expect(snapshot.readTime, isNotNull);
    });

    // TODO handle retries

    test('propagates withConverter() through QueryOptions', () async {
      final collection = firestore
          .collection('withConverterQueryOptions')
          .withConverter<int>(
            fromFirestore: (snapshot) => snapshot.data()['value']! as int,
            toFirestore: (value) => {'value': value},
          );

      await collection.doc('doc').set(42);
      await collection.doc('doc2').set(1);

      final query = collection.where('value', WhereFilter.equal, 1);
      expect(query, isA<Query<int>>());

      final snapshot = await query.get();

      expect(snapshot.docs.single.ref, collection.doc('doc2'));
      expect(snapshot.docs.single.data(), 1);
    });

    test('supports OR queries with cursors', () async {
      final collection = firestore.collection('orQueryWithCursors');
      final query = collection
          .orderBy('a')
          .whereFilter(
            Filter.or([
              Filter.where('a', WhereFilter.greaterThanOrEqual, 4),
              Filter.where('a', WhereFilter.equal, 2),
              // Unused due to startAt
              Filter.where('a', WhereFilter.equal, 0),
            ]),
          )
          .startAt([1])
          .limit(3);

      await Future.wait([
        collection.doc('0').set({'a': 0}),
        collection.doc('1').set({'a': 1}),
        collection.doc('2').set({'a': 2}),
        collection.doc('3').set({'a': 3}),
        collection.doc('4').set({'a': 4}),
        collection.doc('5').set({'a': 5}),
        collection.doc('6').set({'a': 6}),
      ]);

      final snapshot = await query.get();

      expect(snapshot.docs.map((doc) => doc.id), ['2', '4', '5']);
    });
  });

  group('where()', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test('handles all operators', () {
      expect(
        WhereFilter.equal.proto,
        firestore_v1.StructuredQuery_FieldFilter_Operator.equal,
      );
      expect(
        WhereFilter.greaterThan.proto,
        firestore_v1.StructuredQuery_FieldFilter_Operator.greaterThan,
      );
      expect(
        WhereFilter.greaterThanOrEqual.proto,
        firestore_v1.StructuredQuery_FieldFilter_Operator.greaterThanOrEqual,
      );
      expect(
        WhereFilter.lessThan.proto,
        firestore_v1.StructuredQuery_FieldFilter_Operator.lessThan,
      );
      expect(
        WhereFilter.lessThanOrEqual.proto,
        firestore_v1.StructuredQuery_FieldFilter_Operator.lessThanOrEqual,
      );
      expect(
        WhereFilter.notEqual.proto,
        firestore_v1.StructuredQuery_FieldFilter_Operator.notEqual,
      );
      expect(
        WhereFilter.isIn.proto,
        firestore_v1.StructuredQuery_FieldFilter_Operator.in$,
      );
      expect(
        WhereFilter.notIn.proto,
        firestore_v1.StructuredQuery_FieldFilter_Operator.notIn,
      );
      expect(
        WhereFilter.arrayContains.proto,
        firestore_v1.StructuredQuery_FieldFilter_Operator.arrayContains,
      );
      expect(
        WhereFilter.arrayContainsAny.proto,
        firestore_v1.StructuredQuery_FieldFilter_Operator.arrayContainsAny,
      );
    });

    test('accepts objects', () async {
      final collection = firestore.collection('whereObjects');
      final doc = collection.doc('doc');

      await doc.set({
        'a': {'b': 1},
      });

      final snapshot = await collection.where('a', WhereFilter.equal, {
        'b': 1,
      }).get();

      expect(snapshot.docs.single.ref, doc);
    });

    test('supports field path objects', () async {
      final collection = firestore.collection('whereFieldPathObj');
      final doc = collection.doc('doc');

      await doc.set({
        'a': {'b': 1},
      });

      final snapshot = await collection
          .where(FieldPath(const ['a', 'b']), WhereFilter.equal, 1)
          .get();

      expect(snapshot.docs.single.ref, doc);
    });

    test('supports reference array for IN queries', () async {
      final collection = firestore.collection('whereReferenceArray');

      final doc2 = collection.doc('doc');
      await doc2.set({});
      await collection.doc('doc2').set({});

      final snapshot = await collection.where(
        FieldPath.documentId,
        WhereFilter.isIn,
        [doc2],
      ).get();

      expect(snapshot.docs.single.ref, doc2);
    });

    test('Fields of IN queries are not used in implicit order by', () async {
      final collection = firestore.collection('whereInImplicitOrderBy');

      await collection.doc('b').set({'foo': 'bar'});
      await collection.doc('a').set({'foo': 'bar'});

      final snapshot = await collection.where('foo', WhereFilter.isIn, [
        'bar',
      ]).get();

      expect(snapshot.docs.map((doc) => doc.id), ['a', 'b']);
    });

    test('throws if in/not-in have non-reference values', () {
      final collection = firestore.collection('whereInValidation');

      expect(
        () => collection.where(FieldPath.documentId, WhereFilter.isIn, [1]),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => collection.where(FieldPath.documentId, WhereFilter.notIn, [1]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'throws if FieldPath.documentId is used with array-contains/array-contains-any',
      () {
        final collection = firestore.collection('whereArrayContainsValidation');

        expect(
          () => collection.where(
            FieldPath.documentId,
            WhereFilter.arrayContains,
            [collection.doc('doc')],
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => collection.where(
            FieldPath.documentId,
            WhereFilter.arrayContainsAny,
            [collection.doc('doc')],
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('rejects field paths as value', () {
      final collection = firestore.collection('whereFieldPathValue');

      expect(
        () => collection.where('foo', WhereFilter.equal, FieldPath.documentId),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects field delete as value', () {
      final collection = firestore.collection('whereFieldDeleteValue');

      expect(
        () => collection.where('foo', WhereFilter.equal, FieldValue.delete),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects custom classes as value', () {
      final collection = firestore.collection('whereObject');

      expect(
        () => collection.where('foo', WhereFilter.equal, Object()),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('supports isNull', () async {
      final collection = firestore.collection('whereNull');

      final doc = collection.doc('doc');
      await doc.set({'a': null});
      await collection.doc('doc2').set({'a': 42});

      final snapshot = await collection
          .where('a', WhereFilter.equal, null)
          .get();

      expect(snapshot.docs.single.ref, doc);
    });

    test('supports isNotNull', () async {
      final collection = firestore.collection('whereNull');

      final doc = collection.doc('doc');
      await doc.set({'a': 42});
      await collection.doc('doc2').set({'a': null});

      final snapshot = await collection
          .where('a', WhereFilter.notEqual, null)
          .get();

      expect(snapshot.docs.single.ref, doc);
    });

    test('rejects invalid null/nan filters', () {
      final collection = firestore.collection('whereNull');

      expect(
        () => collection.where('foo', WhereFilter.greaterThan, null),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => collection.where('foo', WhereFilter.greaterThan, double.nan),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('orderBy', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test('accepts asc', () async {
      final collection = firestore.collection('orderByAsc');

      await collection.doc('a').set({'foo': 1});
      await collection.doc('b').set({'foo': 2});

      final snapshot = await collection.orderBy('foo').get();
      expect(snapshot.docs.map((doc) => doc.id), ['a', 'b']);

      final snapshot2 = await collection.orderBy('foo', descending: true).get();
      expect(snapshot2.docs.map((doc) => doc.id), ['b', 'a']);
    });

    test('rejecs call after cursor', () {
      final collection = firestore.collection('orderByAfterCursor');

      expect(
        () => collection.orderBy('foo').startAt(['foo']).orderBy('bar'),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => collection
            .where('foo', WhereFilter.equal, 0)
            .startAt(['foo'])
            .where('bar', WhereFilter.equal, 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('concatenantes orders', () async {
      final collection = firestore.collection('orderByConcat');

      await collection.doc('d').set({'foo': 1, 'bar': 1});
      await collection.doc('c').set({'foo': 1, 'bar': 2});
      await collection.doc('b').set({'foo': 2, 'bar': 1});
      await collection.doc('a').set({'foo': 2, 'bar': 2});

      final snapshot = await collection.orderBy('foo').orderBy('bar').get();
      expect(snapshot.docs.map((doc) => doc.id), ['d', 'c', 'b', 'a']);
    });
  });

  group('limit()', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test('uses latest limit', () async {
      final collection = firestore.collection('limitLatest');

      await collection.doc('a').set({'foo': 1});
      await collection.doc('b').set({'foo': 2});
      await collection.doc('c').set({'foo': 3});

      final snapshot = await collection.limit(1).limit(2).get();
      expect(snapshot.docs.map((doc) => doc.id), ['a', 'b']);
    });
  });

  group('limitToLatest()', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test('uses latest limit', () async {
      final collection = firestore.collection('limitLatest');

      await collection.doc('a').set({'foo': 1});
      await collection.doc('b').set({'foo': 2});
      await collection.doc('c').set({'foo': 3});

      final snapshot = await collection
          .orderBy('foo')
          .limitToLast(1)
          .limitToLast(2)
          .get();
      expect(snapshot.docs.map((doc) => doc.id), ['c', 'b']);
    });
  });
}
