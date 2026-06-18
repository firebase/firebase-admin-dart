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

@Tags(['firebase-emulator'])
library;

import 'dart:typed_data';

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart' hide throwsArgumentError;

import 'fixtures/helpers.dart';

void main() {
  group('DocumentReference', () {
    late Firestore firestore;
    late DocumentReference<Map<String, Object?>> documentRef;

    setUp(() async {
      firestore = await createFirestore();
      documentRef = firestore.doc('collectionId/documentId');
    });

    test('listCollections', () async {
      final doc1 = firestore.doc('collectionId/a');
      final doc2 = firestore.doc('collectionId/b');

      final doc1col1 = doc1.collection('a');
      final doc1col2 = doc1.collection('b');

      final doc2col1 = doc2.collection('c');
      final doc2col2 = doc2.collection('d');

      await doc1col1.add({});
      await doc1col2.add({});
      await doc2col1.add({});
      await doc2col2.add({});

      final doc1Collections = await doc1.listCollections();
      final doc2Collections = await doc2.listCollections();

      expect(doc1Collections, unorderedEquals([doc1col1, doc1col2]));
      expect(doc2Collections, unorderedEquals([doc2col1, doc2col2]));
    });

    test('has collection() method', () {
      final collection = documentRef.collection('col');
      expect(collection.id, 'col');

      expect(
        () => documentRef.collection('col/doc'),
        throwsArgumentError(
          message:
              'Value for argument "collectionPath" must point to a collection, but was "col/doc". '
              'Your path does not contain an odd number of components.',
        ),
      );

      expect(documentRef.collection('col/doc/col').id, 'col');
    });

    test('has path property', () {
      expect(documentRef.path, 'collectionId/documentId');
    });

    test('has parent property', () {
      expect(documentRef.parent.path, 'collectionId');
    });

    test('overrides equal operator', () {
      final doc1 = firestore.doc('coll/doc1');
      final doc1Equals = firestore.doc('coll/doc1');
      final doc2 = firestore.doc('coll/doc1/coll/doc1');
      expect(doc1, doc1Equals);
      expect(doc1, isNot(doc2));
    });

    test('overrides hash operator', () {
      final doc1 = firestore.doc('coll/doc1');
      final doc1Equals = firestore.doc('coll/doc1');
      final doc2 = firestore.doc('coll/doc1/coll/doc1');
      expect(doc1.hashCode, doc1Equals.hashCode);
      expect(doc1.hashCode, isNot(doc2.hashCode));
    });
  });

  group('serialize document', () {
    // Tests that all Firestore data types can be stored and
    // retrieved successfully.
    //
    // See https://firebase.google.com/docs/firestore/manage-data/data-types
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test("doesn't serialize unsupported types", () {
      expect(
        firestore.doc('unknownType/documentId').set({
          'foo': FieldPath.documentId,
        }),
        throwsArgumentError(
          message:
              'Cannot use object of type "FieldPath" '
              'as a Firestore value (found in field foo).',
        ),
      );

      expect(
        firestore.doc('unknownType/object').set({'foo': Object()}),
        throwsArgumentError(
          message: 'Unsupported value type: Object (found in field foo).',
        ),
      );
    });

    group('array', () {
      test('empty', () async {
        final doc = firestore.doc('collectionId/array');
        addTearDown(doc.delete);

        await doc.set({'array': []});
        final data = await doc.get().then((snapshot) => snapshot.data());

        expect(data, {'array': isEmpty});
      });

      test('non-empty', () async {
        final doc = firestore.doc('collectionId/array');
        addTearDown(doc.delete);

        await doc.set({
          'array': [1, 'two', true],
        });
        final data = await doc.get().then((snapshot) => snapshot.data());

        expect(data, {
          'array': [1, 'two', true],
        });
      });
    });

    group('boolean', () {
      test('true', () async {
        final doc = firestore.doc('collectionId/bool');
        addTearDown(doc.delete);

        await doc.set({'bool': true});
        final data = await doc.get().then((snapshot) => snapshot.data());

        expect(data, {'bool': true});
      });

      test('false', () async {
        final doc = firestore.doc('collectionId/bool');
        addTearDown(doc.delete);

        await doc.set({'bool': false});
        final data = await doc.get().then((snapshot) => snapshot.data());

        expect(data, {'bool': false});
      });
    });

    group('bytes', () {
      test('empty', () async {
        final doc = firestore.doc('collectionId/bytes');
        addTearDown(doc.delete);

        await doc.set({'bytes': Uint8List(0)});
        final data = await doc.get().then((snapshot) => snapshot.data());

        expect(data, {'bytes': Uint8List(0)});
      });

      test('non-empty', () async {
        final doc = firestore.doc('collectionId/bytes');
        addTearDown(doc.delete);

        await doc.set({
          'bytes': Uint8List.fromList([0, 1, 127, 128, 255]),
        });
        final data = await doc.get().then((snapshot) => snapshot.data());

        expect(data, {
          'bytes': Uint8List.fromList([0, 1, 127, 128, 255]),
        });
      });
    });

    group('date and time', () {
      test('serializes date before 1970', () async {
        await firestore.doc('collectionId/before1970').set({
          'moonLanding': DateTime(1960, 7, 20, 20, 18),
        });

        final data = await firestore
            .doc('collectionId/before1970')
            .get()
            .then((snapshot) => snapshot.data()!['moonLanding']);

        expect(data, Timestamp.fromDate(DateTime(1960, 7, 20, 20, 18)));
      });
    });

    group('floating-point number', () {
      test('Supports NaN and Infinity', () async {
        //
        await firestore.doc('collectionId/nan').set({
          'nan': double.nan,
          'infinity': double.infinity,
          'negativeInfinity': double.negativeInfinity,
        });

        final data = await firestore
            .doc('collectionId/nan')
            .get()
            .then((snapshot) => snapshot.data());

        expect(data, {
          'nan': double.nan,
          'infinity': double.infinity,
          'negativeInfinity': double.negativeInfinity,
        });
      });
    });

    group('geographical point', () {
      test('with invalid geopoint', () {
        expect(
          () => GeoPoint(latitude: double.nan, longitude: 0),
          throwsArgumentError(
            message: 'Value for argument "latitude" is not a valid number',
          ),
        );

        expect(
          () => GeoPoint(latitude: 0, longitude: double.nan),
          throwsArgumentError(
            message: 'Value for argument "longitude" is not a valid number',
          ),
        );

        expect(
          () => GeoPoint(latitude: double.infinity, longitude: 0),
          throwsArgumentError(
            message: 'Latitude must be in the range of [-90, 90]',
          ),
        );
        expect(
          () => GeoPoint(latitude: 91, longitude: 0),
          throwsArgumentError(
            message: 'Latitude must be in the range of [-90, 90]',
          ),
        );

        expect(
          () => GeoPoint(latitude: 90, longitude: 181),
          throwsArgumentError(
            message: 'Longitude must be in the range of [-180, 180]',
          ),
        );
      });
    });

    group('integer', () {
      test('Supports BigInt', () async {
        final firestore = await createFirestore(
          settings: const Settings(useBigInt: true),
        );

        await firestore.doc('collectionId/bigInt').set({
          'foo': BigInt.from(9223372036854775807),
        });

        final data = await firestore
            .doc('collectionId/bigInt')
            .get()
            .then((snapshot) => snapshot.data()!['foo']);

        expect(data, BigInt.from(9223372036854775807));
      });
    });

    group('map', () {
      test('resolves infinite nesting', () {
        final obj = <String, Object?>{};
        obj['foo'] = obj;

        expect(
          () => firestore.doc('collectionId/nesting').set(obj),
          throwsArgumentError(
            message:
                'Firestore objects may not contain more than 20 levels of nesting '
                'or contain a cycle',
          ),
        );
      });
    });

    group('null', () {
      test('value', () async {
        final doc = firestore.doc('collectionId/null');
        addTearDown(doc.delete);

        await doc.set({'null': null});
        final data = await doc.get().then((snapshot) => snapshot.data());

        expect(data, {'null': null});
      });
    });

    group('reference', () {
      test('document reference', () async {
        final doc = firestore.doc('collectionId/reference');
        addTearDown(doc.delete);

        final otherDoc = firestore.doc('otherCollection/otherDoc');
        await doc.set({'reference': otherDoc});
        final data = await doc.get().then((snapshot) => snapshot.data());

        expect(data, {'reference': otherDoc});
      });
    });

    group('text string', () {
      test('serializes unicode keys', () async {
        await firestore.doc('collectionId/unicode').set({'😀': '😜'});

        final data = await firestore
            .doc('collectionId/unicode')
            .get()
            .then((snapshot) => snapshot.data());

        expect(data, {'😀': '😜'});
      });
    });

    group('vector', () {
      test('empty', () async {
        final doc = firestore.doc('collectionId/vector');
        addTearDown(doc.delete);

        await expectLater(
          doc.set({'vector': FieldValue.vector([])}),
          // Zero-dimensional vectors are not supported by Firestore.
          throwsA(
            isA<FirestoreException>().having(
              (e) => e.code,
              'code',
              'invalid_argument',
            ),
          ),
        );
      });

      test('single-dimension', () async {
        final doc = firestore.doc('collectionId/vector');
        addTearDown(doc.delete);

        await doc.set({
          'vector': FieldValue.vector([0.0]),
        });
        final data = await doc.get().then((snapshot) => snapshot.data());

        expect(data, {
          'vector': FieldValue.vector([0.0]),
        });
      });

      test('multi-dimension', () async {
        final doc = firestore.doc('collectionId/vector');
        addTearDown(doc.delete);

        await doc.set({
          'vector': FieldValue.vector([1.0, 2.0, 3.0]),
        });
        final data = await doc.get().then((snapshot) => snapshot.data());

        expect(data, {
          'vector': FieldValue.vector([1.0, 2.0, 3.0]),
        });
      });
    });
  });

  group('get document', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test('returns document', () async {
      firestore = await createFirestore();
      await firestore.doc('collectionId/getdocument').set({
        'foo': {'bar': 'foobar'},
        'null': null,
      });

      final snapshot = await firestore.doc('collectionId/getdocument').get();

      expect(snapshot.data(), {
        'foo': {'bar': 'foobar'},
        'null': null,
      });

      expect(snapshot.get('foo')?.value, {'bar': 'foobar'});
      expect(snapshot.get('unknown'), null);
      expect(snapshot.get('null'), isNotNull);
      expect(snapshot.get('null')!.value, null);
      expect(snapshot.get('foo.bar')?.value, 'foobar');

      expect(snapshot.get(FieldPath(const ['foo']))?.value, {'bar': 'foobar'});
      expect(snapshot.get(FieldPath(const ['foo', 'bar']))?.value, 'foobar');

      expect(snapshot.ref.id, 'getdocument');
    });

    test('returns read, update and create times', () async {
      final time = DateTime.now().toUtc().millisecondsSinceEpoch - 5000;

      await firestore.doc('collectionId/times').delete();
      await firestore.doc('collectionId/times').set({});

      final snapshot = await firestore.doc('collectionId/times').get();

      expect(snapshot.createTime!.seconds * 1000, greaterThan(time));
      expect(snapshot.updateTime!.seconds * 1000, greaterThan(time));
      expect(snapshot.readTime!.seconds * 1000, greaterThan(time));
    });

    test('returns not found', () async {
      await firestore.doc('collectionId/found').set({});

      final found = await firestore.doc('collectionId/found').get();
      final notFound = await firestore.doc('collectionId/not_found').get();

      expect(found.exists, isTrue);
      expect(found.data(), isNotNull);
      expect(found.createTime, isNotNull);
      expect(found.updateTime, isNotNull);
      expect(found.readTime, isNotNull);

      expect(notFound.exists, isFalse);
      expect(notFound.data(), isNull);
      expect(notFound.createTime, isNull);
      expect(notFound.updateTime, isNull);
      expect(notFound.readTime, isNotNull);
    });
  });

  // TODO add tests dependent on invalid reads. This needs API overrides to have GRPC return invalid data

  group('delete document', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test('works', () async {
      await firestore.doc('collectionId/deletedoc').set({});

      expect(
        await firestore
            .doc('collectionId/deletedoc')
            .get()
            .then((s) => s.exists),
        isTrue,
      );

      await firestore.doc('collectionId/deletedoc').delete();

      expect(
        await firestore
            .doc('collectionId/deletedoc')
            .get()
            .then((s) => s.exists),
        isFalse,
      );
    });

    test('Supports preconditions', () async {
      final result = await firestore.doc('collectionId/precondition').set({});

      await firestore
          .doc('collectionId/precondition')
          .delete(Precondition.timestamp(result.writeTime));

      expect(
        await firestore
            .doc('collectionId/precondition')
            .get()
            .then((s) => s.exists),
        isFalse,
      );

      await firestore.doc('collectionId/precondition').set({});

      expect(
        () => firestore
            .doc('collectionId/precondition')
            .delete(Precondition.timestamp(result.writeTime)),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('set documents', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test(
      'sends empty non-merge write even with just field transform',
      () async {
        final now = DateTime.now().toUtc().millisecondsSinceEpoch - 5000;
        await firestore.doc('collectionId/setdoctransform').set({
          'a': FieldValue.serverTimestamp,
          'b': {'c': FieldValue.serverTimestamp},
        });

        final writes = await firestore
            .doc('collectionId/setdoctransform')
            .get()
            .then((s) => s.data()!);

        expect((writes['a']! as Timestamp).seconds * 1000, greaterThan(now));
        expect(
          ((writes['b']! as Map)['c']! as Timestamp).seconds * 1000,
          greaterThan(now),
        );
      },
    );

    test("doesn't split on dots", () async {
      await firestore.doc('collectionId/setdots').set({'a.b': 'c'});

      final writes = await firestore
          .doc('collectionId/setdots')
          .get()
          .then((s) => s.data()!);

      expect(writes, {'a.b': 'c'});
    });

    test("doesn't support non-merge deletes", () {
      expect(
        () => firestore.doc('collectionId/nonMergeDelete').set({
          'foo': FieldValue.delete,
        }),
        throwsArgumentError(
          message:
              'must appear at the top-level and can only be used in update() '
              '(found in field foo).',
        ),
      );
    });
  });

  group('create document', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test('creates document', () async {
      await firestore.doc('collectionId/createdoc').delete();
      await firestore.doc('collectionId/createdoc').create({'foo': 'bar'});

      final snapshot = await firestore.doc('collectionId/createdoc').get();

      expect(snapshot.data(), {'foo': 'bar'});
    });

    test('returns update time', () async {
      final time = DateTime.now().toUtc().millisecondsSinceEpoch - 5000;

      await firestore.doc('collectionId/createdoctime').delete();
      final result = await firestore
          .doc('collectionId/createdoctime')
          .create({});

      expect(result.writeTime.seconds * 1000, greaterThan(time));
    });

    test('supports field transforms', () async {
      final time = DateTime.now().toUtc().millisecondsSinceEpoch - 5000;

      await firestore.doc('collectionId/createdoctransform').delete();
      await firestore.doc('collectionId/createdoctransform').create({
        'a': FieldValue.serverTimestamp,
      });

      final writes = await firestore
          .doc('collectionId/createdoctransform')
          .get()
          .then((s) => s.data()!);

      expect((writes['a']! as Timestamp).seconds * 1000, greaterThan(time));
    });
  });

  group('update document', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test('works', () async {
      await firestore.doc('collectionId/updatedoc').set({'foo': 'bar'});
      await firestore.doc('collectionId/updatedoc').update({'bar': 'baz'});

      final snapshot = await firestore.doc('collectionId/updatedoc').get();

      expect(snapshot.data(), {'foo': 'bar', 'bar': 'baz'});
    });

    test('supports nested field transform', () async {
      final time = DateTime.now().toUtc().millisecondsSinceEpoch - 5000;

      await firestore.doc('collectionId/updatedocnestedtransform').set({});
      await firestore.doc('collectionId/updatedocnestedtransform').update({
        'foo': {},
        'a': {'b': FieldValue.serverTimestamp},
        'c.d': FieldValue.serverTimestamp,
      });

      final writes = await firestore
          .doc('collectionId/updatedocnestedtransform')
          .get()
          .then((s) => s.data()!);

      final a = writes['a']! as Map;
      final c = writes['c']! as Map;

      expect((a['b']! as Timestamp).seconds * 1000, greaterThan(time));
      expect((c['d']! as Timestamp).seconds * 1000, greaterThan(time));
    });

    test('supports nested empty map', () async {
      await firestore.doc('collectionId/updatedocemptymap').set({});
      await firestore.doc('collectionId/updatedocemptymap').update({'foo': {}});

      final writes = await firestore
          .doc('collectionId/updatedocemptymap')
          .get()
          .then((s) => s.data()!);

      expect(writes, {'foo': <String, Object?>{}});
    });

    test('supports nested delete using chained paths', () async {
      await firestore.doc('collectionId/updatenesteddelete').set({
        'foo': {'bar': 'foobar'},
      });
      await firestore.doc('collectionId/updatenesteddelete').update({
        'foo.bar': FieldValue.delete,
      });

      final writes = await firestore
          .doc('collectionId/updatenesteddelete')
          .get()
          .then((s) => s.data()!);

      expect(writes, {'foo': <String, Object?>{}});
    });

    test('supports nested delete if not at root level', () async {
      expect(
        firestore.doc('collectionId/updatenesteddeleteinvalid').update({
          'foo': {'bar': FieldValue.delete},
        }),
        throwsArgumentError(
          message:
              'must appear at the top-level and can only be used in update() '
              '(found in field foo.bar).',
        ),
      );
    });

    test('returns update time', () async {
      final time = DateTime.now().toUtc().millisecondsSinceEpoch - 5000;

      await firestore.doc('collectionId/updatedoctime').set({});
      final result = await firestore.doc('collectionId/updatedoctime').update({
        'foo': 42,
      });

      expect(result.writeTime.seconds * 1000, greaterThan(time));
    });

    test('with invalid last update time precondition', () async {
      final soon = DateTime.now().toUtc().millisecondsSinceEpoch + 5000;

      await expectLater(
        firestore.doc('collectionId/invalidlastupdatetimeprecondition').update({
          'foo': 'bar',
        }, Precondition.timestamp(Timestamp.fromMillis(soon))),
        throwsA(isA<FirestoreException>()),
      );
    });

    test('with valid last update time precondition', () async {
      final result = await firestore
          .doc('collectionId/lastupdatetimeprecondition')
          .set({});

      // does not throw
      await firestore.doc('collectionId/lastupdatetimeprecondition').update({
        'foo': 'bar',
      }, Precondition.timestamp(result.writeTime));
    });

    test('requires at least one field', () {
      expect(
        firestore.doc('collectionId/emptyupdate').update({}),
        throwsArgumentError(message: 'At least one field must be updated.'),
      );
    });

    test('with two nested fields', () async {
      await firestore.doc('collectionId/twonestedfields').set({});

      await firestore.doc('collectionId/twonestedfields').update({
        'foo.foo': 'one',
        'foo.bar': 'two',
        'foo.deep.foo': 'one',
        'foo.deep.bar': 'two',
      });

      final writes = await firestore
          .doc('collectionId/twonestedfields')
          .get()
          .then((s) => s.data()!);

      expect(writes, {
        'foo': {
          'foo': 'one',
          'bar': 'two',
          'deep': {'foo': 'one', 'bar': 'two'},
        },
      });
    });

    test('with field with dot', () async {
      await firestore.doc('collectionId/fieldwithdot').set({});

      await firestore.doc('collectionId/fieldwithdot').update({
        FieldPath(const ['foo.bar']): 'one',
      });

      final writes = await firestore
          .doc('collectionId/fieldwithdot')
          .get()
          .then((s) => s.data()!);

      expect(writes, {'foo.bar': 'one'});
    });

    test('with conflicting update', () async {
      expect(
        () => firestore.doc('collectionId/conflictingupdate').update({
          'foo': 'bar',
          'foo.bar': 'baz',
        }),
        throwsArgumentError(
          message: 'Field "foo" was specified multiple times.',
        ),
      );

      expect(
        () => firestore.doc('collectionId/conflictingupdate').update({
          'foo': 'bar',
          'foo.bar.foobar': 'baz',
        }),
        throwsArgumentError(
          message: 'Field "foo" was specified multiple times.',
        ),
      );

      expect(
        () => firestore.doc('collectionId/conflictingupdate').update({
          'foo.bar': 'baz',
          'foo': 'bar',
        }),
        throwsArgumentError(
          message: 'Field "foo" was specified multiple times.',
        ),
      );

      expect(
        () => firestore.doc('collectionId/conflictingupdate').update({
          'foo.bar': 'foobar',
          'foo.bar.baz': 'foobar',
        }),
        throwsArgumentError(
          message: 'Field "foo.bar" was specified multiple times.',
        ),
      );
    });
  });

  // TODO add tests starting at "with valid field paths"
}
