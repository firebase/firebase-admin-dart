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

import 'dart:async';
import 'dart:io';

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import '../fixtures/helpers.dart';

const _timeout = Duration(seconds: 10);

void main() {
  setUpAll(ensureEmulatorConfigured);

  test('DocumentReference.snapshots() follows a document', () async {
    final firestore = await createFirestore();
    final doc = firestore.collection('snapshots').doc();

    final snapshots = StreamIterator(doc.snapshots());
    addTearDown(snapshots.cancel);
    Future<DocumentSnapshot<DocumentData>> next() async {
      expect(await snapshots.moveNext().timeout(_timeout), isTrue);
      return snapshots.current;
    }

    expect((await next()).exists, isFalse);

    await doc.set({'n': 1});
    expect((await next()).data(), {'n': 1});

    await doc.update({'n': 2});
    expect((await next()).data(), {'n': 2});

    await doc.delete();
    expect((await next()).exists, isFalse);
  });

  test('Query.snapshots() follows the results of a query', () async {
    final firestore = await createFirestore();
    final collection = firestore
        .collection('snapshots')
        .doc()
        .collection('results');
    final query = collection.orderBy('n');

    final snapshots = StreamIterator(query.snapshots());
    addTearDown(snapshots.cancel);
    Future<List<(DocumentChangeType, String, int, int)>> nextChanges() async {
      expect(await snapshots.moveNext().timeout(_timeout), isTrue);
      return [
        for (final change in snapshots.current.docChanges)
          (change.type, change.doc.id, change.oldIndex, change.newIndex),
      ];
    }

    expect(await nextChanges(), isEmpty);

    await collection.doc('a').set({'n': 1});
    expect(await nextChanges(), [(DocumentChangeType.added, 'a', -1, 0)]);

    await collection.doc('b').set({'n': 2});
    expect(await nextChanges(), [(DocumentChangeType.added, 'b', -1, 1)]);

    await collection.doc('a').update({'n': 3});
    expect(await nextChanges(), [(DocumentChangeType.modified, 'a', 0, 1)]);

    await collection.doc('b').delete();
    expect(await nextChanges(), [(DocumentChangeType.removed, 'b', 0, -1)]);
  });

  test('Query.snapshots() delivers the fields a select() keeps', () async {
    final firestore = await createFirestore();
    final collection = firestore
        .collection('snapshots')
        .doc()
        .collection('select');
    await collection.doc('a').set({'kept': 1, 'dropped': 2});

    final snapshots = StreamIterator(
      collection.select([
        FieldPath(const ['kept']),
      ]).snapshots(),
    );
    addTearDown(snapshots.cancel);

    expect(await snapshots.moveNext().timeout(_timeout), isTrue);
    expect(snapshots.current.docs.map((doc) => doc.data()), [
      {'kept': 1},
    ]);

    await collection.doc('b').set({'kept': 3, 'dropped': 4});
    expect(await snapshots.moveNext().timeout(_timeout), isTrue);
    expect(
      {for (final doc in snapshots.current.docs) doc.id: doc.data()},
      {
        'a': {'kept': 1},
        'b': {'kept': 3},
      },
    );
  });

  test('Firestore.terminate() closes an open listener', () async {
    // A Firestore of its own, so terminating it leaves the others open.
    final firestore = Firestore(
      settings: Settings(
        projectId: projectId,
        host: Platform.environment['FIRESTORE_EMULATOR_HOST'],
        ssl: false,
      ),
    );
    // Terminating is memoized, so this is safe after the test terminates it.
    addTearDown(firestore.terminate);
    final doc = firestore.collection('snapshots').doc();

    final snapshots = StreamIterator(doc.snapshots());
    expect(await snapshots.moveNext().timeout(_timeout), isTrue);
    expect(snapshots.current.exists, isFalse);

    await firestore.terminate().timeout(_timeout);

    expect(await snapshots.moveNext().timeout(_timeout), isFalse);
    await expectLater(
      doc.snapshots().first,
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('terminated'),
        ),
      ),
    );
  });
}
