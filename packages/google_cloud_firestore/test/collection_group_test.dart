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
  group('collectionGroup', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test('throws if collectionId contains "/"', () {
      expect(
        () => firestore.collectionGroup('my-group/docA'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'Invalid collectionId "my-group/docA". '
                'Collection IDs must not contain "/".',
          ),
        ),
      );
    });

    test('supports withConverter', () async {
      await Future.wait([
        firestore.doc('with-converter-group/docA').set({'value': 42}),
        firestore.doc('abc/def/with-converter-group/docB').set({'value': 13}),
        firestore.doc('abc/def/with-converter-group/docC').set({'value': 10}),
      ]);

      final group = firestore
          .collectionGroup('with-converter-group')
          .withConverter(
            fromFirestore: (firestore) => firestore.data()['value']! as num,
            toFirestore: (value) => {'value': value},
          );

      final query = group.where('value', WhereFilter.greaterThan, 12);
      final snapshot = await query.get();

      expect(snapshot.docs, hasLength(2));
      expect(snapshot.docs[0].data(), 13);
      expect(snapshot.docs[1].data(), 42);
    });

    test('defaults to JSON decoding', () async {
      await Future.wait([
        firestore.doc('group/docA').set({'value': 42}),
        firestore.doc('abc/def/group/docB').set({'value': 13}),
        firestore.doc('abc/def/group/docC').set({'value': 10}),
      ]);

      final group = firestore.collectionGroup('group');

      final query = group.where('value', WhereFilter.greaterThan, 12);
      final snapshot = await query.get();

      expect(snapshot.docs, hasLength(2));
      expect(snapshot.docs[0].data(), {'value': 13});
      expect(snapshot.docs[1].data(), {'value': 42});
    });
  });
}
