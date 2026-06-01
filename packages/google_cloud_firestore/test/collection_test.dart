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

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart' hide throwsArgumentError;

import 'fixtures/helpers.dart';

void main() {
  group('Collection interface', () {
    late Firestore firestore;

    setUpAll(ensureEmulatorConfigured);

    setUp(() async => firestore = await createFirestore());

    test('supports + in collection name', () async {
      final a = firestore.collection(
        '/collection+a/lF1kvtRAYMqmdInT7iJK/subcollection',
      );

      expect(a.path, 'collection+a/lF1kvtRAYMqmdInT7iJK/subcollection');

      await a.add({'foo': 'bar'});

      final results = await a.get();

      expect(results.docs.length, 1);
      expect(results.docs.first.data(), {'foo': 'bar'});
    });

    test('has doc() method', () {
      final collection = firestore.collection('colId');

      expect(collection.id, 'colId');
      expect(collection.path, 'colId');

      final documentRef = collection.doc('docId');

      expect(documentRef, isA<DocumentReference<DocumentData>>());
      expect(documentRef.id, 'docId');
      expect(documentRef.path, 'colId/docId');

      expect(
        () => collection.doc(''),
        throwsArgumentError(message: 'Must be a non-empty string'),
      );
      expect(
        () => collection.doc('doc/coll'),
        throwsArgumentError(
          message:
              'Value for argument "documentPath" must point to a document, '
              'but was "doc/coll". '
              'Your path does not contain an even number of components.',
        ),
      );

      expect(
        collection.doc('docId/colId/docId'),
        isA<DocumentReference<DocumentData>>(),
      );
    });

    test('has parent getter', () {
      final collection = firestore.collection('col1/doc/col2');
      expect(collection.path, 'col1/doc/col2');

      final document = collection.parent;
      expect(document!.path, 'col1/doc');
    });

    test('parent returns null for root', () {
      final collection = firestore.collection('col1');

      expect(collection.parent, isNull);
    });

    test('supports auto-generated ids', () {
      final collection = firestore.collection('col1');

      final document = collection.doc();
      expect(document.id, hasLength(20));
    });

    test('has add() method', () async {
      final collection = firestore.collection('addCollection');

      final documentRef = await collection.add({'foo': 'bar'});

      expect(documentRef, isA<DocumentReference<DocumentData>>());
      expect(documentRef.id, hasLength(20));
      expect(documentRef.path, 'addCollection/${documentRef.id}');

      final documentSnapshot = await documentRef.get();

      expect(documentSnapshot.exists, isTrue);
      expect(documentSnapshot.data(), {'foo': 'bar'});
    });

    test('has list() method', () async {
      final collection = firestore.collection('listCollection');

      final a = collection.doc('a');
      await a.set({'foo': 'bar'});

      final b = collection.doc('b');
      await b.set({'baz': 'quaz'});

      final documents = await collection.listDocuments();

      expect(documents, unorderedEquals([a, b]));
    });

    test('override equal', () async {
      final coll1 = firestore.collection('coll1');
      final coll1Equals = firestore.collection('coll1');
      final coll2 = firestore.collection('coll2');

      expect(coll1, coll1Equals);
      expect(coll1, isNot(coll2));
    });

    test('override hashCode', () async {
      final coll1 = firestore.collection('coll1');
      final coll1Equals = firestore.collection('coll1');
      final coll2 = firestore.collection('coll2');

      expect(coll1.hashCode, coll1Equals.hashCode);
      expect(coll1.hashCode, isNot(coll2.hashCode));
    });

    test('for CollectionReference.withConverter().doc()', () async {
      final collection = firestore.collection('withConverterColDoc');

      final rawDoc = collection.doc('doc');

      final docRef = collection
          .withConverter<int>(
            fromFirestore: (snapshot) => snapshot.data()['value']! as int,
            toFirestore: (value) => {'value': value},
          )
          .doc('doc');

      expect(docRef, isA<DocumentReference<int>>());
      expect(docRef.id, 'doc');
      expect(docRef.path, 'withConverterColDoc/doc');

      await docRef.set(42);

      final rawDocSnapshot = await rawDoc.get();
      expect(rawDocSnapshot.data(), {'value': 42});

      final docSnapshot = await docRef.get();
      expect(docSnapshot.data(), 42);
    });

    test('for CollectionReference.withConverter().add()', () async {
      final collection = firestore
          .collection('withConverterColAdd')
          .withConverter<int>(
            fromFirestore: (snapshot) => snapshot.data()['value']! as int,
            toFirestore: (value) => {'value': value},
          );

      expect(collection, isA<CollectionReference<int>>());

      final docRef = await collection.add(42);

      expect(docRef, isA<DocumentReference<int>>());
      expect(docRef.id, hasLength(20));
      expect(docRef.path, 'withConverterColAdd/${docRef.id}');

      final docSnapshot = await docRef.get();
      expect(docSnapshot.data(), 42);
    });

    test(
      'drops the converter when calling CollectionReference<T>.parent()',
      () {
        final collection = firestore
            .collection('withConverterColParent/doc/child')
            .withConverter(
              fromFirestore: (snapshot) => snapshot.data()['value']! as int,
              toFirestore: (value) => {'value': value},
            );

        expect(collection, isA<CollectionReference<int>>());

        final parent = collection.parent;

        expect(parent!.path, 'withConverterColParent/doc');
      },
    );

    test('resets converter to untyped with null parameters', () async {
      // Create a typed collection reference
      final typedCollection = firestore
          .collection('withConverterNullTest')
          .withConverter<int>(
            fromFirestore: (snapshot) => snapshot.data()['value']! as int,
            toFirestore: (value) => {'value': value},
          );

      expect(typedCollection, isA<CollectionReference<int>>());

      // Reset to untyped by passing null
      final untypedCollection = typedCollection.withConverter<DocumentData>();

      expect(untypedCollection, isA<CollectionReference<DocumentData>>());

      // Verify we can work with raw DocumentData
      final docRef = await untypedCollection.add({'foo': 'bar', 'num': 123});
      final snapshot = await docRef.get();

      expect(snapshot.data(), {'foo': 'bar', 'num': 123});
    });

    test('DocumentReference.withConverter() resets with null', () async {
      final collection = firestore.collection('docConverterNullTest');

      // Create typed document reference
      final typedDocRef = collection
          .doc('testDoc')
          .withConverter<int>(
            fromFirestore: (snapshot) => snapshot.data()['value']! as int,
            toFirestore: (value) => {'value': value},
          );

      expect(typedDocRef, isA<DocumentReference<int>>());

      // Set data using typed reference
      await typedDocRef.set(42);

      // Reset to untyped
      final untypedDocRef = typedDocRef.withConverter<DocumentData>();

      expect(untypedDocRef, isA<DocumentReference<DocumentData>>());

      // Verify we can read raw data
      final snapshot = await untypedDocRef.get();
      expect(snapshot.data(), {'value': 42});

      // Verify we can write raw data
      await untypedDocRef.set({'value': 100, 'extra': 'field'});
      final updatedSnapshot = await untypedDocRef.get();
      expect(updatedSnapshot.data(), {'value': 100, 'extra': 'field'});
    });

    test('Query.withConverter() resets with null', () async {
      final collection = firestore.collection('queryConverterNullTest');

      // Add test data
      await collection.doc('doc1').set({'value': 10});
      await collection.doc('doc2').set({'value': 20});

      // Create typed query
      final typedQuery = collection
          .where('value', WhereFilter.greaterThan, 5)
          .withConverter<int>(
            fromFirestore: (snapshot) => snapshot.data()['value']! as int,
            toFirestore: (value) => {'value': value},
          );

      expect(typedQuery, isA<Query<int>>());

      // Reset to untyped
      final untypedQuery = typedQuery.withConverter<DocumentData>();

      expect(untypedQuery, isA<Query<DocumentData>>());

      // Verify we get raw data
      final snapshot = await untypedQuery.get();
      expect(snapshot.docs.length, 2);
      expect(snapshot.docs.first.data(), {'value': 10});
      expect(snapshot.docs.last.data(), {'value': 20});
    });

    test('CollectionGroup.withConverter() resets with null', () async {
      // Create test data in multiple collections
      await firestore.collection('parent1/doc/groupNullTest').doc('doc1').set({
        'value': 1,
      });
      await firestore.collection('parent2/doc/groupNullTest').doc('doc2').set({
        'value': 2,
      });

      // Create typed collection group
      final typedGroup = firestore
          .collectionGroup('groupNullTest')
          .withConverter<int>(
            fromFirestore: (snapshot) => snapshot.data()['value']! as int,
            toFirestore: (value) => {'value': value},
          );

      expect(typedGroup, isA<CollectionGroup<int>>());

      // Reset to untyped
      final untypedGroup = typedGroup.withConverter<DocumentData>();

      expect(untypedGroup, isA<CollectionGroup<DocumentData>>());

      // Verify we get raw data
      final snapshot = await untypedGroup.get();
      expect(snapshot.docs.length, greaterThanOrEqualTo(2));
      expect(snapshot.docs.first.data()['value'], isA<int>());
    });

    test('withConverter() with only fromFirestore null uses default', () async {
      final collection = firestore.collection('partialNullTest');

      final typedCollection = collection.withConverter<int>(
        fromFirestore: (snapshot) => snapshot.data()['value']! as int,
        toFirestore: (value) => {'value': value},
      );

      // Passing null for just one parameter should reset to default
      final resetCollection = typedCollection.withConverter<DocumentData>(
        toFirestore: (value) => value,
      );

      expect(resetCollection, isA<CollectionReference<DocumentData>>());

      final docRef = await resetCollection.add({'test': 'data'});
      final snapshot = await docRef.get();
      expect(snapshot.data(), {'test': 'data'});
    });

    test('withConverter() with only toFirestore null uses default', () async {
      final collection = firestore.collection('partialNullTest2');

      final typedCollection = collection.withConverter<int>(
        fromFirestore: (snapshot) => snapshot.data()['value']! as int,
        toFirestore: (value) => {'value': value},
      );

      // Passing null for just one parameter should reset to default
      final resetCollection = typedCollection.withConverter<DocumentData>(
        fromFirestore: (snapshot) => snapshot.data(),
      );

      expect(resetCollection, isA<CollectionReference<DocumentData>>());

      final docRef = await resetCollection.add({'test': 'data'});
      final snapshot = await docRef.get();
      expect(snapshot.data(), {'test': 'data'});
    });
  });
}
