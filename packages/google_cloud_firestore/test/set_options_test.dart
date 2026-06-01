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
import 'package:test/test.dart';

import 'fixtures/helpers.dart';

void main() {
  late Firestore firestore;
  late CollectionReference<Map<String, Object?>> testCollection;

  setUp(() async {
    firestore = await createFirestore();
    testCollection = firestore.collection('set-options-test');
  });

  group('SetOptions.merge()', () {
    test('DocumentReference should merge fields', () async {
      final docRef = testCollection.doc();
      await docRef.set({'foo': 'bar'});
      await docRef.set({'baz': 'qux'}, options: const SetOptions.merge());

      final data = (await docRef.get()).data()!;
      expect(data['foo'], 'bar');
      expect(data['baz'], 'qux');
    });

    test('WriteBatch should merge fields', () async {
      final docRef = testCollection.doc();
      await docRef.set({'foo': 'bar'});

      final batch = firestore.batch();
      batch.set(docRef, {'baz': 'qux'}, options: const SetOptions.merge());
      await batch.commit();

      final data = (await docRef.get()).data()!;
      expect(data['foo'], 'bar');
      expect(data['baz'], 'qux');
    });

    test('Transaction should merge fields', () async {
      final docRef = testCollection.doc();
      await docRef.set({'foo': 'bar'});

      await firestore.runTransaction((transaction) async {
        transaction.set(docRef, {
          'baz': 'qux',
        }, options: const SetOptions.merge());
      });

      final data = (await docRef.get()).data()!;
      expect(data['foo'], 'bar');
      expect(data['baz'], 'qux');
    });

    test('BulkWriter should merge fields', () async {
      final docRef = testCollection.doc();
      await docRef.set({'foo': 'bar'});

      final bulkWriter = firestore.bulkWriter();
      await bulkWriter.set(docRef, {
        'baz': 'qux',
      }, options: const SetOptions.merge());
      await bulkWriter.close();

      final data = (await docRef.get()).data()!;
      expect(data['foo'], 'bar');
      expect(data['baz'], 'qux');
    }, skip: 'BulkWriter.close() times out - known issue');
  });

  group('SetOptions.mergeFields()', () {
    test('should only merge specified fields', () async {
      final docRef = testCollection.doc();
      await docRef.set({'foo': 'bar', 'baz': 'qux', 'num': 1});

      await docRef.set(
        {'baz': 'updated', 'foo': 'ignored', 'num': 999},
        options: SetOptions.mergeFields([
          FieldPath(const ['baz']),
        ]),
      );

      final data = (await docRef.get()).data()!;
      expect(data['baz'], 'updated');
      expect(data['foo'], 'bar');
      expect(data['num'], 1);
    });
  });
}
