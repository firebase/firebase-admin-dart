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

import 'package:firebase_admin_sdk/src/app.dart';
import 'package:google_cloud_firestore/google_cloud_firestore.dart' as gfs;
import 'package:test/test.dart';

import '../../fixtures/helpers.dart';

/// Integration tests for Firestore wrapper.
///
/// These tests require the Firestore emulator to be running.
/// Start it with: firebase emulators:start --only firestore
///
/// Or run tests with: firebase emulators:exec "dart test test/firestore/firestore_integration_test.dart"
void main() {
  group(
    'Firestore Integration Tests',
    () {
      late FirebaseApp app;
      late gfs.Firestore firestore;

      setUp(() {
        app = FirebaseApp.initializeApp(
          name: 'integration-test-${DateTime.now().millisecondsSinceEpoch}',
          options: const AppOptions(projectId: projectId),
        );

        firestore = app.firestore();
      });

      tearDown(() async {
        // Clean up the test document if it exists
        await app.close();
      });

      group('Basic Operations', () {
        test('supports basic CRUD operations', () async {
          final docRef = firestore.collection('cities').doc('mountain-view');
          final mountainView = {'name': 'Mountain View', 'population': 77846};

          // Create
          await docRef.set(mountainView);

          // Read
          final snapshot = await docRef.get();
          expect(snapshot.exists, isTrue);
          expect(snapshot.data(), equals(mountainView));

          // Update
          await docRef.update({'population': 80000});
          final updatedSnapshot = await docRef.get();
          expect(updatedSnapshot.data()?['population'], equals(80000));

          // Delete
          await docRef.delete();
          final deletedSnapshot = await docRef.get();
          expect(deletedSnapshot.exists, isFalse);
        });

        test('supports batch writes', () async {
          final batch = firestore.batch();
          final doc1 = firestore.collection('cities').doc('city-1');
          final doc2 = firestore.collection('cities').doc('city-2');

          batch.set(doc1, {'name': 'City 1', 'population': 1000});
          batch.set(doc2, {'name': 'City 2', 'population': 2000});

          await batch.commit();

          final snapshot1 = await doc1.get();
          final snapshot2 = await doc2.get();

          expect(snapshot1.exists, isTrue);
          expect(snapshot2.exists, isTrue);
          expect(snapshot1.data()?['name'], equals('City 1'));
          expect(snapshot2.data()?['name'], equals('City 2'));

          // Cleanup
          await doc1.delete();
          await doc2.delete();
        });

        test('supports transactions', () async {
          final docRef = firestore.collection('counters').doc('test-counter');
          await docRef.set({'count': 0});

          await firestore.runTransaction((transaction) async {
            final snapshot = await transaction.get(docRef);
            final currentCount = (snapshot.data()?['count'] as int?) ?? 0;
            transaction.update(docRef, {'count': currentCount + 1});
          });

          final snapshot = await docRef.get();
          expect(snapshot.data()?['count'], equals(1));

          // Cleanup
          await docRef.delete();
        });

        test('supports queries', () async {
          final collection = firestore.collection('test-cities');

          // Add test data
          await collection.doc('city1').set({
            'name': 'City 1',
            'population': 1000,
          });
          await collection.doc('city2').set({
            'name': 'City 2',
            'population': 2000,
          });
          await collection.doc('city3').set({
            'name': 'City 3',
            'population': 3000,
          });

          // Query
          final query = collection.where(
            'population',
            gfs.WhereFilter.greaterThan,
            1500,
          );
          final querySnapshot = await query.get();

          expect(querySnapshot.docs.length, equals(2));

          // Cleanup
          for (final doc in querySnapshot.docs) {
            await doc.ref.delete();
          }
          await collection.doc('city1').delete();
        });
      });

      group('Field Values', () {
        test(
          'FieldValue.serverTimestamp provides server-side timestamp',
          () async {
            final docRef = firestore
                .collection('cities')
                .doc('timestamped-city');
            final cityData = {
              'name': 'Mountain View',
              'population': 77846,
              'createdAt': gfs.FieldValue.serverTimestamp,
            };

            await docRef.set(cityData);

            final snapshot = await docRef.get();
            expect(snapshot.exists, isTrue);
            expect(snapshot.data()?['name'], equals('Mountain View'));
            expect(snapshot.data()?['createdAt'], isA<gfs.Timestamp>());

            // Cleanup
            await docRef.delete();
          },
        );

        test('FieldValue.increment works correctly', () async {
          final docRef = firestore.collection('counters').doc('increment-test');
          await docRef.set({'count': 5});

          await docRef.update({'count': const gfs.FieldValue.increment(3)});

          final snapshot = await docRef.get();
          expect(snapshot.data()?['count'], equals(8));

          // Cleanup
          await docRef.delete();
        });

        test('FieldValue.arrayUnion adds elements to array', () async {
          final docRef = firestore.collection('lists').doc('array-test');
          await docRef.set({
            'items': ['a', 'b'],
          });

          await docRef.update({
            'items': const gfs.FieldValue.arrayUnion(['c', 'd']),
          });

          final snapshot = await docRef.get();
          final items = snapshot.data()?['items'] as List?;
          expect(items, containsAll(['a', 'b', 'c', 'd']));

          // Cleanup
          await docRef.delete();
        });

        test('FieldValue.arrayRemove removes elements from array', () async {
          final docRef = firestore.collection('lists').doc('array-remove-test');
          await docRef.set({
            'items': ['a', 'b', 'c', 'd'],
          });

          await docRef.update({
            'items': const gfs.FieldValue.arrayRemove(['b', 'c']),
          });

          final snapshot = await docRef.get();
          final items = snapshot.data()?['items'] as List?;
          expect(items, equals(['a', 'd']));

          // Cleanup
          await docRef.delete();
        });

        test('FieldValue.delete removes a field', () async {
          final docRef = firestore
              .collection('cities')
              .doc('delete-field-test');
          await docRef.set({
            'name': 'Test City',
            'population': 1000,
            'country': 'USA',
          });

          await docRef.update({'country': gfs.FieldValue.delete});

          final snapshot = await docRef.get();
          final data = snapshot.data();
          expect(data?['name'], equals('Test City'));
          expect(data?['population'], equals(1000));
          expect(data?.containsKey('country'), isFalse);

          // Cleanup
          await docRef.delete();
        });
      });

      group('Document References', () {
        test('supports saving references in documents', () async {
          final sourceDoc = firestore.collection('cities').doc('source-city');
          final targetDoc = firestore.collection('cities').doc('target-city');

          await sourceDoc.set({'name': 'Mountain View', 'population': 77846});

          await targetDoc.set({'name': 'Palo Alto', 'sisterCity': sourceDoc});

          final snapshot = await targetDoc.get();
          expect(snapshot.exists, isTrue);
          expect(snapshot.data()?['name'], equals('Palo Alto'));

          final sisterCityRef =
              snapshot.data()?['sisterCity'] as gfs.DocumentReference?;
          expect(sisterCityRef, isNotNull);
          expect(sisterCityRef!.path, equals(sourceDoc.path));

          // Verify we can fetch the referenced document
          final sisterSnapshot = await sisterCityRef.get();
          expect(sisterSnapshot.exists, isTrue);
          expect(
            (sisterSnapshot.data() as Map<String, dynamic>?)?['name'],
            equals('Mountain View'),
          );

          // Cleanup
          await sourceDoc.delete();
          await targetDoc.delete();
        });
      });

      group('Multi-database Support', () {
        test('supports multiple named databases', () async {
          final defaultDb = app.firestore();
          final namedDb = app.firestore(databaseId: 'test-database');

          expect(defaultDb, isA<gfs.Firestore>());
          expect(namedDb, isA<gfs.Firestore>());
          expect(defaultDb, isNot(same(namedDb)));

          // Verify they are actually different databases
          final docInDefault = defaultDb.collection('test').doc('doc1');
          final docInNamed = namedDb.collection('test').doc('doc1');

          await docInDefault.set({'db': 'default'});
          await docInNamed.set({'db': 'named'});

          final defaultSnapshot = await docInDefault.get();
          final namedSnapshot = await docInNamed.get();

          expect(defaultSnapshot.data()?['db'], equals('default'));
          expect(namedSnapshot.data()?['db'], equals('named'));

          // Cleanup
          await docInDefault.delete();
          await docInNamed.delete();
        });
      });

      group('Collection Operations', () {
        test('listDocuments returns document references', () async {
          final collection = firestore.collection('list-test');

          // Create test documents
          await collection.doc('doc1').set({'value': 1});
          await collection.doc('doc2').set({'value': 2});
          await collection.doc('doc3').set({'value': 3});

          final docs = await collection.listDocuments();
          expect(docs.length, greaterThanOrEqualTo(3));

          // Cleanup
          for (final doc in docs) {
            await doc.delete();
          }
        });
      });

      group('GeoPoint', () {
        test('supports storing and retrieving GeoPoints', () async {
          final docRef = firestore.collection('locations').doc('office');
          final location = gfs.GeoPoint(
            latitude: 37.422,
            longitude: -122.084,
          ); // Googleplex

          await docRef.set({'name': 'Google HQ', 'location': location});

          final snapshot = await docRef.get();
          expect(snapshot.exists, isTrue);

          final retrievedLocation =
              snapshot.data()?['location'] as gfs.GeoPoint?;
          expect(retrievedLocation, isNotNull);
          expect(retrievedLocation!.latitude, equals(37.422));
          expect(retrievedLocation.longitude, equals(-122.084));

          // Cleanup
          await docRef.delete();
        });
      });

      group('Error Handling', () {
        test('throws error when document does not exist for update', () async {
          final docRef = firestore.collection('cities').doc('non-existent');

          expect(
            () => docRef.update({'name': 'Test'}),
            throwsA(isA<gfs.FirestoreException>()),
          );
        });

        test('handles invalid field paths', () async {
          final docRef = firestore.collection('cities').doc('invalid-field');
          await docRef.set({'name': 'Test City'});

          // Empty field path should throw
          expect(() => docRef.update({'': 'value'}), throwsA(anything));

          // Cleanup
          await docRef.delete();
        });
      });
    },
    skip: Environment.isFirestoreEmulatorEnabled()
        ? false
        : 'Skipping Firestore integration tests. Set FIRESTORE_EMULATOR_HOST'
              ' environment variable to run these tests.',
  );
}
