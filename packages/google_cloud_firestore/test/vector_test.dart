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
import 'package:test/test.dart';

import 'fixtures/helpers.dart';

void main() {
  // Shared Firestore instance for unit tests (no emulator needed)
  late Firestore firestore;

  setUpAll(() {
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

  group('VectorValue', () {
    test('constructor creates VectorValue from list', () {
      final vector = VectorValue(const [1.0, 2.0, 3.0]);
      expect(vector.toArray(), [1.0, 2.0, 3.0]);
    });

    test('constructor creates immutable copy of list', () {
      final originalList = [1.0, 2.0, 3.0];
      final vector = VectorValue(originalList);

      // Modifying original list shouldn't affect VectorValue
      originalList[0] = 100.0;
      expect(vector.toArray(), [1.0, 2.0, 3.0]);
    });

    test('toArray returns a copy', () {
      final vector = VectorValue(const [1.0, 2.0, 3.0]);
      final array1 = vector.toArray();
      final array2 = vector.toArray();

      // Arrays should be equal but not identical
      expect(array1, array2);
      expect(identical(array1, array2), false);

      // Modifying returned array shouldn't affect VectorValue
      array1[0] = 100.0;
      expect(vector.toArray(), [1.0, 2.0, 3.0]);
    });

    test('isEqual returns true for equal vectors', () {
      final vector1 = VectorValue(const [1.0, 2.0, 3.0]);
      final vector2 = VectorValue(const [1.0, 2.0, 3.0]);

      expect(vector1.isEqual(vector2), true);
    });

    test('isEqual returns false for different vectors', () {
      final vector1 = VectorValue(const [1.0, 2.0, 3.0]);
      final vector2 = VectorValue(const [1.0, 2.0, 4.0]);

      expect(vector1.isEqual(vector2), false);
    });

    test('isEqual returns false for vectors of different lengths', () {
      final vector1 = VectorValue(const [1.0, 2.0, 3.0]);
      final vector2 = VectorValue(const [1.0, 2.0]);

      expect(vector1.isEqual(vector2), false);
    });

    test('operator == works correctly', () {
      final vector1 = VectorValue(const [1.0, 2.0, 3.0]);
      final vector2 = VectorValue(const [1.0, 2.0, 3.0]);
      final vector3 = VectorValue(const [1.0, 2.0, 4.0]);

      expect(vector1 == vector2, true);
      expect(vector1 == vector3, false);
    });

    test('hashCode is consistent for equal vectors', () {
      final vector1 = VectorValue(const [1.0, 2.0, 3.0]);
      final vector2 = VectorValue(const [1.0, 2.0, 3.0]);

      expect(vector1.hashCode, vector2.hashCode);
    });

    test('empty vector is allowed', () {
      final vector = VectorValue(const []);
      expect(vector.toArray(), isEmpty);
    });
  });

  group('FieldValue.vector', () {
    test('creates VectorValue', () {
      final vector = FieldValue.vector([1.0, 2.0, 3.0]);

      expect(vector, isA<VectorValue>());
      expect(vector.toArray(), [1.0, 2.0, 3.0]);
    });
  });

  group('DistanceMeasure', () {
    test('has correct string values', () {
      expect(DistanceMeasure.euclidean.value, 'EUCLIDEAN');
      expect(DistanceMeasure.cosine.value, 'COSINE');
      expect(DistanceMeasure.dotProduct.value, 'DOT_PRODUCT');
    });
  });

  group('VectorQueryOptions', () {
    test('constructor with required parameters', () {
      const options = VectorQueryOptions(
        vectorField: 'embedding',
        queryVector: [1.0, 2.0, 3.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.cosine,
      );

      expect(options.vectorField, 'embedding');
      expect(options.queryVector, [1.0, 2.0, 3.0]);
      expect(options.limit, 10);
      expect(options.distanceMeasure, DistanceMeasure.cosine);
      expect(options.distanceResultField, isNull);
      expect(options.distanceThreshold, isNull);
    });

    test('constructor with all parameters', () {
      final options = VectorQueryOptions(
        vectorField: 'embedding',
        queryVector: FieldValue.vector([1.0, 2.0, 3.0]),
        limit: 10,
        distanceMeasure: DistanceMeasure.euclidean,
        distanceResultField: 'distance',
        distanceThreshold: 0.5,
      );

      expect(options.vectorField, 'embedding');
      expect(options.queryVector, isA<VectorValue>());
      expect(options.limit, 10);
      expect(options.distanceMeasure, DistanceMeasure.euclidean);
      expect(options.distanceResultField, 'distance');
      expect(options.distanceThreshold, 0.5);
    });

    test('equality', () {
      const options1 = VectorQueryOptions(
        vectorField: 'embedding',
        queryVector: [1.0, 2.0, 3.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.cosine,
      );

      const options2 = VectorQueryOptions(
        vectorField: 'embedding',
        queryVector: [1.0, 2.0, 3.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.cosine,
      );

      const options3 = VectorQueryOptions(
        vectorField: 'embedding',
        queryVector: [1.0, 2.0, 3.0],
        limit: 5, // different limit
        distanceMeasure: DistanceMeasure.cosine,
      );

      expect(options1 == options2, true);
      expect(options1 == options3, false);
    });
  });

  group('Query.findNearest', () {
    test('validates empty queryVector throws error', () {
      final query = firestore.collection('collectionId');

      expect(
        () => query.findNearest(
          vectorField: 'embedding',
          queryVector: <double>[],
          limit: 10,
          distanceMeasure: DistanceMeasure.euclidean,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates limit must be positive', () {
      final query = firestore.collection('collectionId');

      expect(
        () => query.findNearest(
          vectorField: 'embedding',
          queryVector: [10.0, 1000.0],
          limit: 0,
          distanceMeasure: DistanceMeasure.euclidean,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => query.findNearest(
          vectorField: 'embedding',
          queryVector: [10.0, 1000.0],
          limit: -1,
          distanceMeasure: DistanceMeasure.euclidean,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates limit must be at most 1000', () {
      final query = firestore.collection('collectionId');

      expect(
        () => query.findNearest(
          vectorField: 'embedding',
          queryVector: [10.0, 1000.0],
          limit: 1001,
          distanceMeasure: DistanceMeasure.euclidean,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts VectorValue as queryVector', () {
      final query = firestore.collection('collectionId');
      final vectorQuery = query.findNearest(
        vectorField: 'embedding',
        queryVector: FieldValue.vector([1.0, 2.0, 3.0]),
        limit: 10,
        distanceMeasure: DistanceMeasure.cosine,
      );

      expect(vectorQuery, isA<VectorQuery<DocumentData>>());
    });

    test('accepts List<double> as queryVector', () {
      final query = firestore.collection('collectionId');
      final vectorQuery = query.findNearest(
        vectorField: 'embedding',
        queryVector: [1.0, 2.0, 3.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.cosine,
      );

      expect(vectorQuery, isA<VectorQuery<DocumentData>>());
    });

    test('accepts FieldPath as vectorField', () {
      final query = firestore.collection('collectionId');
      final vectorQuery = query.findNearest(
        vectorField: FieldPath(const ['nested', 'embedding']),
        queryVector: [1.0, 2.0, 3.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.cosine,
      );

      expect(vectorQuery, isA<VectorQuery<DocumentData>>());
    });
  });

  group('VectorQuery.isEqual', () {
    test('returns true for equal vector queries', () {
      final queryA = firestore
          .collection('collectionId')
          .where('foo', WhereFilter.equal, 42);
      final queryB = firestore
          .collection('collectionId')
          .where('foo', WhereFilter.equal, 42);

      final vectorQueryA = queryA.findNearest(
        vectorField: 'embedding',
        queryVector: [40.0, 41.0, 42.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.cosine,
      );

      final vectorQueryB = queryB.findNearest(
        vectorField: 'embedding',
        queryVector: [40.0, 41.0, 42.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.cosine,
      );

      expect(vectorQueryA.isEqual(vectorQueryB), true);
      expect(vectorQueryA == vectorQueryB, true);
    });

    test('returns false for different base queries', () {
      final queryA = firestore
          .collection('collectionId')
          .where('foo', WhereFilter.equal, 42);
      final queryB = firestore.collection('collectionId'); // No where clause

      final vectorQueryA = queryA.findNearest(
        vectorField: 'embedding',
        queryVector: [40.0, 41.0, 42.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.cosine,
      );

      final vectorQueryB = queryB.findNearest(
        vectorField: 'embedding',
        queryVector: [40.0, 41.0, 42.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.cosine,
      );

      expect(vectorQueryA.isEqual(vectorQueryB), false);
    });

    test('returns false for different queryVector', () {
      final queryA = firestore.collection('collectionId');
      final queryB = firestore.collection('collectionId');

      final vectorQueryA = queryA.findNearest(
        vectorField: 'embedding',
        queryVector: [40.0, 41.0, 42.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.cosine,
      );

      final vectorQueryB = queryB.findNearest(
        vectorField: 'embedding',
        queryVector: [40.0, 42.0], // Different vector
        limit: 10,
        distanceMeasure: DistanceMeasure.cosine,
      );

      expect(vectorQueryA.isEqual(vectorQueryB), false);
    });

    test('returns false for different limit', () {
      final queryA = firestore.collection('collectionId');
      final queryB = firestore.collection('collectionId');

      final vectorQueryA = queryA.findNearest(
        vectorField: 'embedding',
        queryVector: [40.0, 41.0, 42.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.cosine,
      );

      final vectorQueryB = queryB.findNearest(
        vectorField: 'embedding',
        queryVector: [40.0, 41.0, 42.0],
        limit: 1000, // Different limit
        distanceMeasure: DistanceMeasure.cosine,
      );

      expect(vectorQueryA.isEqual(vectorQueryB), false);
    });

    test('returns false for different distanceMeasure', () {
      final queryA = firestore.collection('collectionId');
      final queryB = firestore.collection('collectionId');

      final vectorQueryA = queryA.findNearest(
        vectorField: 'embedding',
        queryVector: [40.0, 41.0, 42.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.cosine,
      );

      final vectorQueryB = queryB.findNearest(
        vectorField: 'embedding',
        queryVector: [40.0, 41.0, 42.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.euclidean, // Different measure
      );

      expect(vectorQueryA.isEqual(vectorQueryB), false);
    });

    test('returns false for different distanceThreshold', () {
      final queryA = firestore.collection('collectionId');
      final queryB = firestore.collection('collectionId');

      final vectorQueryA = queryA.findNearest(
        vectorField: 'embedding',
        queryVector: [40.0, 41.0, 42.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.euclidean,
        distanceThreshold: 1.125,
      );

      final vectorQueryB = queryB.findNearest(
        vectorField: 'embedding',
        queryVector: [40.0, 41.0, 42.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.euclidean,
        distanceThreshold: 0.125, // Different threshold
      );

      expect(vectorQueryA.isEqual(vectorQueryB), false);
    });

    test('returns false when one has distanceThreshold and other does not', () {
      final queryA = firestore.collection('collectionId');
      final queryB = firestore.collection('collectionId');

      final vectorQueryA = queryA.findNearest(
        vectorField: 'embedding',
        queryVector: [40.0, 41.0, 42.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.euclidean,
        distanceThreshold: 1,
      );

      final vectorQueryB = queryB.findNearest(
        vectorField: 'embedding',
        queryVector: [40.0, 41.0, 42.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.euclidean,
        // No distanceThreshold
      );

      expect(vectorQueryA.isEqual(vectorQueryB), false);
    });

    test('returns false for different distanceResultField', () {
      final queryA = firestore.collection('collectionId');
      final queryB = firestore.collection('collectionId');

      final vectorQueryA = queryA.findNearest(
        vectorField: 'embedding',
        queryVector: [40.0, 41.0, 42.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.euclidean,
        distanceResultField: 'distance',
      );

      final vectorQueryB = queryB.findNearest(
        vectorField: 'embedding',
        queryVector: [40.0, 41.0, 42.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.euclidean,
        distanceResultField: 'result', // Different field
      );

      expect(vectorQueryA.isEqual(vectorQueryB), false);
    });

    test('returns true with distanceResultField as String vs FieldPath', () {
      final queryA = firestore.collection('collectionId');
      final queryB = firestore.collection('collectionId');

      final vectorQueryA = queryA.findNearest(
        vectorField: 'embedding',
        queryVector: [40.0, 41.0, 42.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.euclidean,
        distanceResultField: 'distance',
      );

      final vectorQueryB = queryB.findNearest(
        vectorField: 'embedding',
        queryVector: [40.0, 41.0, 42.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.euclidean,
        distanceResultField: FieldPath(const ['distance']),
      );

      expect(vectorQueryA.isEqual(vectorQueryB), true);
    });

    test('returns true for all distance measures', () {
      for (final measure in DistanceMeasure.values) {
        final queryA = firestore.collection('collectionId');
        final queryB = firestore.collection('collectionId');

        final vectorQueryA = queryA.findNearest(
          vectorField: 'embedding',
          queryVector: [1.0],
          limit: 2,
          distanceMeasure: measure,
        );

        final vectorQueryB = queryB.findNearest(
          vectorField: 'embedding',
          queryVector: [1.0],
          limit: 2,
          distanceMeasure: measure,
        );

        expect(
          vectorQueryA.isEqual(vectorQueryB),
          true,
          reason: 'Failed for $measure',
        );
      }
    });
  });

  group('VectorQuery.query', () {
    test('returns the underlying query', () {
      final baseQuery = firestore
          .collection('collectionId')
          .where('foo', WhereFilter.equal, 42);

      final vectorQuery = baseQuery.findNearest(
        vectorField: 'embedding',
        queryVector: [1.0, 2.0, 3.0],
        limit: 10,
        distanceMeasure: DistanceMeasure.cosine,
      );

      expect(vectorQuery.query, baseQuery);
    });
  });

  group('Vector Integration Tests', () {
    late Firestore firestoreEmulator;

    setUp(() async {
      firestoreEmulator = await createFirestore();
    });

    group('write and read vector embeddings', () {
      test('can create document with vector field', () async {
        final ref = firestoreEmulator.collection('vector-test').doc();
        await ref.create({
          'vector0': FieldValue.vector([0.0]),
          'vector1': FieldValue.vector([1.0, 2.0, 3.99]),
        });

        final snap = await ref.get();
        expect(snap.exists, true);
        expect(snap.get('vector0')?.value, isA<VectorValue>());
        expect((snap.get('vector0')!.value! as VectorValue).toArray(), [0.0]);
        expect((snap.get('vector1')!.value! as VectorValue).toArray(), [
          1.0,
          2.0,
          3.99,
        ]);
      });

      test('can set document with vector field', () async {
        final ref = firestoreEmulator.collection('vector-test').doc();
        await ref.set({
          'vector0': FieldValue.vector([0.0]),
          'vector1': FieldValue.vector([1.0, 2.0, 3.99]),
          'vector2': FieldValue.vector([0.0, 0.0, 0.0]),
        });

        final snap = await ref.get();
        expect(snap.exists, true);
        expect((snap.get('vector0')!.value! as VectorValue).toArray(), [0.0]);
        expect((snap.get('vector1')!.value! as VectorValue).toArray(), [
          1.0,
          2.0,
          3.99,
        ]);
        expect((snap.get('vector2')!.value! as VectorValue).toArray(), [
          0.0,
          0.0,
          0.0,
        ]);
      });

      test('can update document with vector field', () async {
        final ref = firestoreEmulator.collection('vector-test').doc();
        await ref.set({'name': 'test'});
        await ref.update({
          'vector3': FieldValue.vector([-1.0, -200.0, -999.0]),
        });

        final snap = await ref.get();
        expect((snap.get('vector3')!.value! as VectorValue).toArray(), [
          -1.0,
          -200.0,
          -999.0,
        ]);
      });

      test('VectorValue.isEqual works with retrieved vectors', () async {
        final ref = firestoreEmulator.collection('vector-test').doc();
        await ref.set({
          'embedding': FieldValue.vector([1.0, 2.0, 3.0]),
        });

        final snap = await ref.get();
        final retrievedVector = snap.get('embedding')!.value! as VectorValue;
        final expectedVector = FieldValue.vector([1.0, 2.0, 3.0]);

        expect(retrievedVector.isEqual(expectedVector), true);
      });
    });

    group('vector search (findNearest)', () {
      late CollectionReference<DocumentData> collection;

      setUp(() async {
        // Create test collection with vector embeddings
        collection = firestoreEmulator.collection(
          'vector-search-test-${DateTime.now().millisecondsSinceEpoch}',
        );

        // Create test documents with embeddings
        await Future.wait([
          collection.doc('doc1').set({
            'foo': 'bar',
            // No embedding
          }),
          collection.doc('doc2').set({
            'foo': 'xxx',
            'embedding': FieldValue.vector([10.0, 10.0]),
          }),
          collection.doc('doc3').set({
            'foo': 'bar',
            'embedding': FieldValue.vector([1.0, 1.0]),
          }),
          collection.doc('doc4').set({
            'foo': 'bar',
            'embedding': FieldValue.vector([10.0, 0.0]),
          }),
          collection.doc('doc5').set({
            'foo': 'bar',
            'embedding': FieldValue.vector([20.0, 0.0]),
          }),
          collection.doc('doc6').set({
            'foo': 'bar',
            'embedding': FieldValue.vector([100.0, 100.0]),
          }),
        ]);
      });

      test('supports findNearest by EUCLIDEAN distance', () async {
        final vectorQuery = collection
            .where('foo', WhereFilter.equal, 'bar')
            .findNearest(
              vectorField: 'embedding',
              queryVector: [10.0, 10.0],
              limit: 3,
              distanceMeasure: DistanceMeasure.euclidean,
            );

        final res = await vectorQuery.get();
        expect(res.size, 3);
        expect(res.empty, false);
        expect(res.docs.length, 3);

        // Results should be ordered by distance
        // [10, 0] is closest to [10, 10] with distance 10
        // [1, 1] has distance ~12.7
        // [20, 0] has distance ~14.1
        expect(
          (res.docs[0].get('embedding')!.value! as VectorValue).toArray(),
          [10.0, 0.0],
        );
        expect(
          (res.docs[1].get('embedding')!.value! as VectorValue).toArray(),
          [1.0, 1.0],
        );
        expect(
          (res.docs[2].get('embedding')!.value! as VectorValue).toArray(),
          [20.0, 0.0],
        );
      });

      test('supports findNearest by COSINE distance', () async {
        final vectorQuery = collection
            .where('foo', WhereFilter.equal, 'bar')
            .findNearest(
              vectorField: 'embedding',
              queryVector: [10.0, 10.0],
              limit: 3,
              distanceMeasure: DistanceMeasure.cosine,
            );

        final res = await vectorQuery.get();
        expect(res.size, 3);

        // For cosine distance, [1,1] and [100,100] have same angle as [10,10]
        // so they should be closest (cosine distance = 0)
        final vectors = res.docs
            .map((d) => (d.get('embedding')!.value! as VectorValue).toArray())
            .toList();

        // All results should have the embedding field
        expect(vectors.length, 3);
      });

      test('supports findNearest by DOT_PRODUCT distance', () async {
        final vectorQuery = collection
            .where('foo', WhereFilter.equal, 'bar')
            .findNearest(
              vectorField: 'embedding',
              queryVector: [1.0, 1.0],
              limit: 3,
              distanceMeasure: DistanceMeasure.dotProduct,
            );

        final res = await vectorQuery.get();
        expect(res.size, 3);
      });

      test('supports findNearest with distanceResultField', () async {
        final vectorQuery = collection
            .where('foo', WhereFilter.equal, 'bar')
            .findNearest(
              vectorField: 'embedding',
              queryVector: [10.0, 10.0],
              limit: 3,
              distanceMeasure: DistanceMeasure.euclidean,
              distanceResultField: 'distance',
            );

        final res = await vectorQuery.get();
        expect(res.size, 3);

        // Each document should have a 'distance' field with the computed distance
        for (final doc in res.docs) {
          final distance = doc.get('distance')!.value;
          expect(distance, isA<double>());
          expect(distance! as double, greaterThanOrEqualTo(0));
        }
      });

      test('supports findNearest with distanceThreshold', () async {
        final vectorQuery = collection
            .where('foo', WhereFilter.equal, 'bar')
            .findNearest(
              vectorField: 'embedding',
              queryVector: [10.0, 10.0],
              limit: 10,
              distanceMeasure: DistanceMeasure.euclidean,
              distanceThreshold: 15, // Only return docs within distance 15
            );

        final res = await vectorQuery.get();
        // Should filter out [100, 100] which has distance ~127
        expect(res.size, lessThanOrEqualTo(4));
      });

      test('VectorQuerySnapshot has correct properties', () async {
        final vectorQuery = collection.findNearest(
          vectorField: 'embedding',
          queryVector: [1.0, 1.0],
          limit: 2,
          distanceMeasure: DistanceMeasure.euclidean,
        );

        final res = await vectorQuery.get();

        expect(res.query, vectorQuery);
        expect(res.readTime, isA<Timestamp>());
        expect(res.docs, isA<List<QueryDocumentSnapshot<DocumentData>>>());
        expect(res.size, res.docs.length);
        expect(res.empty, res.docs.isEmpty);
      });

      test('VectorQuerySnapshot.docChanges returns all as added', () async {
        final vectorQuery = collection.findNearest(
          vectorField: 'embedding',
          queryVector: [1.0, 1.0],
          limit: 3,
          distanceMeasure: DistanceMeasure.euclidean,
        );

        final res = await vectorQuery.get();
        final changes = res.docChanges;

        expect(changes.length, res.size);
        for (final change in changes) {
          expect(change.type, DocumentChangeType.added);
          expect(change.oldIndex, -1);
        }
      });

      test('VectorQuerySnapshot.forEach iterates over docs', () async {
        final vectorQuery = collection.findNearest(
          vectorField: 'embedding',
          queryVector: [1.0, 1.0],
          limit: 3,
          distanceMeasure: DistanceMeasure.euclidean,
        );

        final res = await vectorQuery.get();
        var count = 0;
        res.forEach((doc) {
          expect(doc, isA<QueryDocumentSnapshot<DocumentData>>());
          count++;
        });

        expect(count, res.size);
      });

      test('findNearest works with converters', () async {
        final testCollection = firestoreEmulator.collection(
          'converter-test-${DateTime.now().millisecondsSinceEpoch}',
        );

        await testCollection.add({
          'foo': 'bar',
          'embedding': FieldValue.vector([5.0, 5.0]),
        });

        final vectorQuery = testCollection
            .withConverter<Map<String, Object?>>(
              fromFirestore: (snapshot) => snapshot.data(),
              toFirestore: (data) => data,
            )
            .where('foo', WhereFilter.equal, 'bar')
            .findNearest(
              vectorField: 'embedding',
              queryVector: [10.0, 10.0],
              limit: 3,
              distanceMeasure: DistanceMeasure.euclidean,
            );

        final res = await vectorQuery.get();
        expect(res.size, 1);
        expect(res.docs[0].data()['foo'], 'bar');
        final embedding = res.docs[0].data()['embedding']! as VectorValue;
        expect(embedding.toArray(), [5.0, 5.0]);
      });

      test('supports findNearest skipping fields of wrong types', () async {
        final testCollection = firestoreEmulator.collection(
          'wrong-types-test-${DateTime.now().millisecondsSinceEpoch}',
        );

        await Future.wait([
          testCollection.add({'foo': 'bar'}),
          // These documents are skipped - not actual vector values
          testCollection.add({
            'foo': 'bar',
            'embedding': [10, 10],
          }),
          testCollection.add({'foo': 'bar', 'embedding': 'not a vector'}),
          testCollection.add({'foo': 'bar', 'embedding': null}),
          // Actual vector values
          testCollection.add({
            'foo': 'bar',
            'embedding': FieldValue.vector([9.0, 9.0]),
          }),
          testCollection.add({
            'foo': 'bar',
            'embedding': FieldValue.vector([50.0, 50.0]),
          }),
          testCollection.add({
            'foo': 'bar',
            'embedding': FieldValue.vector([100.0, 100.0]),
          }),
        ]);

        final vectorQuery = testCollection
            .where('foo', WhereFilter.equal, 'bar')
            .findNearest(
              vectorField: 'embedding',
              queryVector: [10.0, 10.0],
              limit: 100,
              distanceMeasure: DistanceMeasure.euclidean,
            );

        final res = await vectorQuery.get();
        expect(res.size, 3);
        expect(
          (res.docs[0].get('embedding')!.value! as VectorValue).isEqual(
            FieldValue.vector([9.0, 9.0]),
          ),
          true,
        );
        expect(
          (res.docs[1].get('embedding')!.value! as VectorValue).isEqual(
            FieldValue.vector([50.0, 50.0]),
          ),
          true,
        );
        expect(
          (res.docs[2].get('embedding')!.value! as VectorValue).isEqual(
            FieldValue.vector([100.0, 100.0]),
          ),
          true,
        );
      });

      test('findNearest ignores mismatching dimensions', () async {
        final testCollection = firestoreEmulator.collection(
          'dimension-test-${DateTime.now().millisecondsSinceEpoch}',
        );

        await Future.wait([
          testCollection.add({'foo': 'bar'}),
          // Vector with dimension mismatch (1D instead of 2D)
          testCollection.add({
            'foo': 'bar',
            'embedding': FieldValue.vector([10.0]),
          }),
          // Vectors with dimension match (2D)
          testCollection.add({
            'foo': 'bar',
            'embedding': FieldValue.vector([9.0, 9.0]),
          }),
          testCollection.add({
            'foo': 'bar',
            'embedding': FieldValue.vector([50.0, 50.0]),
          }),
        ]);

        final vectorQuery = testCollection
            .where('foo', WhereFilter.equal, 'bar')
            .findNearest(
              vectorField: 'embedding',
              queryVector: [10.0, 10.0],
              limit: 3,
              distanceMeasure: DistanceMeasure.euclidean,
            );

        final res = await vectorQuery.get();
        expect(res.size, 2);
        expect(
          (res.docs[0].get('embedding')!.value! as VectorValue).isEqual(
            FieldValue.vector([9.0, 9.0]),
          ),
          true,
        );
        expect(
          (res.docs[1].get('embedding')!.value! as VectorValue).isEqual(
            FieldValue.vector([50.0, 50.0]),
          ),
          true,
        );
      });

      test('supports findNearest on non-existent field', () async {
        final testCollection = firestoreEmulator.collection(
          'nonexistent-test-${DateTime.now().millisecondsSinceEpoch}',
        );

        await Future.wait([
          testCollection.add({'foo': 'bar'}),
          testCollection.add({
            'foo': 'bar',
            'otherField': [10, 10],
          }),
          testCollection.add({'foo': 'bar', 'otherField': 'not a vector'}),
          testCollection.add({'foo': 'bar', 'otherField': null}),
        ]);

        final vectorQuery = testCollection
            .where('foo', WhereFilter.equal, 'bar')
            .findNearest(
              vectorField: 'embedding',
              queryVector: [10.0, 10.0],
              limit: 3,
              distanceMeasure: DistanceMeasure.euclidean,
            );

        final res = await vectorQuery.get();
        expect(res.size, 0);
      });

      test('supports findNearest with select to exclude vector data', () async {
        final testCollection = firestoreEmulator.collection(
          'select-test-${DateTime.now().millisecondsSinceEpoch}',
        );

        await Future.wait([
          testCollection.add({'foo': 1}),
          testCollection.add({
            'foo': 2,
            'embedding': FieldValue.vector([10.0, 10.0]),
          }),
          testCollection.add({
            'foo': 3,
            'embedding': FieldValue.vector([1.0, 1.0]),
          }),
          testCollection.add({
            'foo': 4,
            'embedding': FieldValue.vector([10.0, 0.0]),
          }),
          testCollection.add({
            'foo': 5,
            'embedding': FieldValue.vector([20.0, 0.0]),
          }),
          testCollection.add({
            'foo': 6,
            'embedding': FieldValue.vector([100.0, 100.0]),
          }),
        ]);

        final vectorQuery = testCollection
            .where('foo', WhereFilter.isIn, [1, 2, 3, 4, 5, 6])
            .select([
              FieldPath(const ['foo']),
            ])
            .findNearest(
              vectorField: 'embedding',
              queryVector: [10.0, 10.0],
              limit: 10,
              distanceMeasure: DistanceMeasure.euclidean,
            );

        final res = await vectorQuery.get();
        expect(res.size, 5);
        expect(res.docs[0].get('foo')?.value, 2);
        expect(res.docs[1].get('foo')?.value, 4);
        expect(res.docs[2].get('foo')?.value, 3);
        expect(res.docs[3].get('foo')?.value, 5);
        expect(res.docs[4].get('foo')?.value, 6);

        // Verify embedding field is not returned
        for (final doc in res.docs) {
          expect(doc.get('embedding'), isNull);
        }
      });

      test('supports findNearest with large dimension vectors', () async {
        final testCollection = firestoreEmulator.collection(
          'large-dim-test-${DateTime.now().millisecondsSinceEpoch}',
        );

        // Create 2048-dimension vectors
        final embeddingVector = <double>[];
        final queryVector = <double>[];
        for (var i = 0; i < 2048; i++) {
          embeddingVector.add((i + 1).toDouble());
          queryVector.add((i - 1).toDouble());
        }

        await testCollection.add({
          'embedding': FieldValue.vector(embeddingVector),
        });

        final vectorQuery = testCollection.findNearest(
          vectorField: 'embedding',
          queryVector: queryVector,
          limit: 1000,
          distanceMeasure: DistanceMeasure.euclidean,
        );

        final res = await vectorQuery.get();
        expect(res.size, 1);
        expect(
          (res.docs[0].get('embedding')!.value! as VectorValue).toArray(),
          embeddingVector,
        );
      });

      test('SDK orders vector field same way as backend', () async {
        final testCollection = firestoreEmulator.collection(
          'ordering-test-${DateTime.now().millisecondsSinceEpoch}',
        );

        // Test data with VectorValues in the order we expect the backend to sort
        final docsInOrder = [
          {
            'embedding': FieldValue.vector([-100.0]),
          },
          {
            'embedding': FieldValue.vector([0.0]),
          },
          {
            'embedding': FieldValue.vector([100.0]),
          },
          {
            'embedding': FieldValue.vector([1.0, 2.0]),
          },
          {
            'embedding': FieldValue.vector([2.0, 2.0]),
          },
          {
            'embedding': FieldValue.vector([1.0, 2.0, 3.0]),
          },
          {
            'embedding': FieldValue.vector([1.0, 2.0, 3.0, 4.0]),
          },
          {
            'embedding': FieldValue.vector([1.0, 2.0, 3.0, 4.0, 5.0]),
          },
          {
            'embedding': FieldValue.vector([1.0, 2.0, 100.0, 4.0, 4.0]),
          },
          {
            'embedding': FieldValue.vector([100.0, 2.0, 3.0, 4.0, 5.0]),
          },
        ];

        final docRefs = <DocumentReference<DocumentData>>[];
        for (final data in docsInOrder) {
          final docRef = await testCollection.add(data);
          docRefs.add(docRef);
        }

        // Query by ordering on embedding field
        final query = testCollection.orderBy('embedding');
        final snapshot = await query.get();

        // Verify the order matches what we inserted
        expect(snapshot.docs.length, docsInOrder.length);
        for (var i = 0; i < snapshot.docs.length; i++) {
          expect(snapshot.docs[i].ref.path, docRefs[i].path);
        }
      });
    });
  }, tags: 'firebase-emulator');

  group('Vector Production Tests', () {
    late Firestore firestoreProd;

    setUp(() async {
      firestoreProd = Firestore(
        settings: const Settings(projectId: 'dart-firebase-admin'),
      );
    });

    group('vector search with nested fields', () {
      test('supports findNearest on vector nested in a map', () async {
        await runZoned(() async {
          // Use fixed collection name for production (requires pre-configured index)
          final collection = firestoreProd.collection(
            'nested-vector-test-prod',
          );
          final testId = 'test-${DateTime.now().millisecondsSinceEpoch}';

          try {
            await Future.wait([
              collection.add({
                'testId': testId,
                'nested': {
                  'embedding': FieldValue.vector([1.0, 1.0]),
                },
              }),
              collection.add({
                'testId': testId,
                'nested': {
                  'embedding': FieldValue.vector([10.0, 10.0]),
                },
              }),
            ]);

            // Query with testId filter for test isolation
            final vectorQuery = collection
                .where('testId', WhereFilter.equal, testId)
                .findNearest(
                  vectorField: 'nested.embedding',
                  queryVector: [1.0, 1.0],
                  limit: 2,
                  distanceMeasure: DistanceMeasure.euclidean,
                );

            final res = await vectorQuery.get();
            expect(res.size, 2);
          } finally {
            // Clean up: delete test documents
            final docs = await firestoreProd
                .collection('nested-vector-test-prod')
                .where('testId', WhereFilter.equal, testId)
                .get();
            for (final doc in docs.docs) {
              await doc.ref.delete();
            }
          }
        }, zoneValues: {envSymbol: <String, String>{}});
      });
    });
  }, tags: 'prod');
}
