// Copyright 2020, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';
import '../fixtures/helpers.dart' as helpers;

void main() {
  group('Firestore.getAll() Integration Tests', () {
    late Firestore firestore;

    setUp(() async {
      firestore = await helpers.createFirestore();
    });

    Future<DocumentReference<Map<String, dynamic>>> initializeTest(
      String path,
    ) async {
      final prefixedPath = 'flutter-tests/$path';
      await firestore.doc(prefixedPath).delete();
      addTearDown(() => firestore.doc(prefixedPath).delete());

      return firestore.doc(prefixedPath);
    }

    test('retrieves multiple documents', () async {
      final docRef1 = await initializeTest('getAll1');
      final docRef2 = await initializeTest('getAll2');
      final docRef3 = await initializeTest('getAll3');

      await docRef1.set({'value': 42});
      await docRef2.set({'value': 44});
      await docRef3.set({'value': 'foo'});

      final snapshots = await firestore.getAll([docRef1, docRef2, docRef3]);

      expect(snapshots.length, 3);
      expect(snapshots[0].data()!['value'], 42);
      expect(snapshots[1].data()!['value'], 44);
      expect(snapshots[2].data()!['value'], 'foo');
    });

    test('retrieves single document', () async {
      final docRef = await initializeTest('getAll-single');

      await docRef.set({'name': 'Alice', 'age': 30});

      final snapshots = await firestore.getAll([docRef]);

      expect(snapshots.length, 1);
      expect(snapshots[0].data()!['name'], 'Alice');
      expect(snapshots[0].data()!['age'], 30);
    });

    test('handles missing documents', () async {
      final docRef1 = await initializeTest('getAll-exists');
      final docRef2 = await initializeTest('getAll-missing');

      await docRef1.set({'exists': true});
      // docRef2 is not created, so it will be missing

      final snapshots = await firestore.getAll([docRef1, docRef2]);

      expect(snapshots.length, 2);
      expect(snapshots[0].exists, isTrue);
      expect(snapshots[0].data()!['exists'], true);
      expect(snapshots[1].exists, isFalse);
      expect(snapshots[1].data(), isNull);
    });

    test('handles all missing documents', () async {
      final docRef1 = await initializeTest('getAll-missing1');
      final docRef2 = await initializeTest('getAll-missing2');

      // Neither document is created

      final snapshots = await firestore.getAll([docRef1, docRef2]);

      expect(snapshots.length, 2);
      expect(snapshots[0].exists, isFalse);
      expect(snapshots[1].exists, isFalse);
    });

    test('applies field mask', () async {
      final docRef1 = await initializeTest('getAll-mask1');
      final docRef2 = await initializeTest('getAll-mask2');

      await docRef1.set({'name': 'Alice', 'age': 30, 'city': 'NYC'});
      await docRef2.set({'name': 'Bob', 'age': 25, 'city': 'LA'});

      final snapshots = await firestore.getAll(
        [docRef1, docRef2],
        ReadOptions(
          fieldMask: [
            FieldMask.fieldPath(FieldPath(const ['name'])),
            FieldMask.fieldPath(FieldPath(const ['age'])),
          ],
        ),
      );

      expect(snapshots.length, 2);
      expect(snapshots[0].data(), {'name': 'Alice', 'age': 30});
      expect(snapshots[0].data()!.containsKey('city'), isFalse);
      expect(snapshots[1].data(), {'name': 'Bob', 'age': 25});
      expect(snapshots[1].data()!.containsKey('city'), isFalse);
    });

    test('applies field mask with string paths', () async {
      final docRef = await initializeTest('getAll-mask-string');

      await docRef.set({
        'user': {'name': 'Alice', 'email': 'alice@example.com', 'age': 30},
        'settings': {'theme': 'dark', 'notifications': true},
      });

      final snapshots = await firestore.getAll(
        [docRef],
        ReadOptions(
          fieldMask: [
            FieldMask.fieldPath(FieldPath(const ['user', 'name'])),
            FieldMask.fieldPath(FieldPath(const ['settings', 'theme'])),
          ],
        ),
      );

      expect(snapshots.length, 1);
      final data = snapshots[0].data()!;
      final user = data['user'] as Map<String, dynamic>;
      final settings = data['settings'] as Map<String, dynamic>;
      expect(user['name'], 'Alice');
      expect(user.containsKey('email'), isFalse);
      expect(user.containsKey('age'), isFalse);
      expect(settings['theme'], 'dark');
      expect(settings.containsKey('notifications'), isFalse);
    });

    test('preserves document order', () async {
      final docRef1 = await initializeTest('getAll-order1');
      final docRef2 = await initializeTest('getAll-order2');
      final docRef3 = await initializeTest('getAll-order3');

      await docRef1.set({'index': 1});
      await docRef2.set({'index': 2});
      await docRef3.set({'index': 3});

      // Request in specific order
      final snapshots = await firestore.getAll([
        docRef3,
        docRef1,
        docRef2,
        docRef3,
      ]);

      expect(snapshots.length, 4);
      expect(snapshots[0].data()!['index'], 3);
      expect(snapshots[1].data()!['index'], 1);
      expect(snapshots[2].data()!['index'], 2);
      expect(snapshots[3].data()!['index'], 3);
    });

    test('handles duplicate document references', () async {
      final docRef = await initializeTest('getAll-duplicate');

      await docRef.set({'count': 100});

      final snapshots = await firestore.getAll([docRef, docRef, docRef]);

      expect(snapshots.length, 3);
      expect(snapshots[0].data()!['count'], 100);
      expect(snapshots[1].data()!['count'], 100);
      expect(snapshots[2].data()!['count'], 100);
      // Verify all snapshots refer to the same document
      expect(snapshots[0].ref.path, docRef.path);
      expect(snapshots[1].ref.path, docRef.path);
      expect(snapshots[2].ref.path, docRef.path);
    });

    test('includes read time on all snapshots', () async {
      final docRef1 = await initializeTest('getAll-readtime1');
      final docRef2 = await initializeTest('getAll-readtime2');

      await docRef1.set({'value': 1});
      await docRef2.set({'value': 2});

      final snapshots = await firestore.getAll([docRef1, docRef2]);

      expect(snapshots.length, 2);
      expect(snapshots[0].readTime, isNotNull);
      expect(snapshots[1].readTime, isNotNull);
      // Read times should be very close (same batch read)
      expect(snapshots[0].readTime, snapshots[1].readTime);
    });

    test('includes create and update times', () async {
      final docRef = await initializeTest('getAll-timestamps');

      await docRef.set({'initial': true});
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await docRef.update({'updated': true});

      final snapshots = await firestore.getAll([docRef]);

      expect(snapshots.length, 1);
      final snapshot = snapshots[0];
      expect(snapshot.createTime, isNotNull);
      expect(snapshot.updateTime, isNotNull);
      expect(
        snapshot.updateTime!.toDate().isAfter(snapshot.createTime!.toDate()),
        isTrue,
      );
    });

    test('works with documents from different paths', () async {
      final docRef1 = await initializeTest('getAll-path1');
      final docRef2 = await initializeTest('getAll-path2');
      final docRef3 = await initializeTest('getAll-path3');

      await docRef1.set({'path': 1});
      await docRef2.set({'path': 2});
      await docRef3.set({'path': 3});

      final snapshots = await firestore.getAll([docRef1, docRef2, docRef3]);

      expect(snapshots.length, 3);
      expect(snapshots[0].data()!['path'], 1);
      expect(snapshots[1].data()!['path'], 2);
      expect(snapshots[2].data()!['path'], 3);
    });

    test('throws on empty document array', () async {
      expect(() => firestore.getAll([]), throwsA(isA<ArgumentError>()));
    });
  });
}
