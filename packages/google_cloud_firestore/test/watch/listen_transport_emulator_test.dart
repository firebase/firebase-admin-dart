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

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:google_cloud_firestore/src/watch/listen_transport.dart';
import 'package:google_cloud_firestore_v1/firestore.dart' as firestore_v1;
import 'package:test/test.dart';

import '../fixtures/helpers.dart';

const _database = 'projects/$projectId/databases/(default)';
const _timeout = Duration(seconds: 10);

void main() {
  setUpAll(ensureEmulatorConfigured);

  test('listens to a document over gRPC', () async {
    final firestore = await createFirestore();
    final transport = GrpcListenTransport.fromSettings(
      settings: const Settings(projectId: projectId),
      credential: Credential.fromApplicationDefaultCredentials(),
      database: _database,
    );
    addTearDown(transport.close);

    final doc = firestore.collection('listen-transport').doc();
    final name = '$_database/documents/${doc.path}';

    final stream = transport.open();
    final responses = StreamIterator(stream.responses);
    Future<firestore_v1.ListenResponse> next() async {
      expect(await responses.moveNext().timeout(_timeout), isTrue);
      return responses.current;
    }

    stream.send(
      firestore_v1.ListenRequest(
        database: _database,
        addTarget: firestore_v1.Target(
          documents: firestore_v1.Target_DocumentsTarget(documents: [name]),
          targetId: 1,
        ),
      ),
    );

    final changeTypes = <firestore_v1.TargetChange_TargetChangeType>[];
    while (!changeTypes.contains(
      firestore_v1.TargetChange_TargetChangeType.current,
    )) {
      final response = await next();
      if (response.targetChange case final change?) {
        expect(change.cause, isNull);
        changeTypes.add(change.targetChangeType);
      }
    }
    expect(changeTypes.first, firestore_v1.TargetChange_TargetChangeType.add);

    await doc.set({'greeting': 'hello'});

    firestore_v1.DocumentChange? documentChange;
    while (documentChange == null) {
      documentChange = (await next()).documentChange;
    }
    expect(documentChange.targetIds, [1]);
    expect(documentChange.document!.name, name);
    expect(documentChange.document!.fields['greeting']!.stringValue, 'hello');

    await stream.close();
    // Responses already received are still delivered before the end.
    while (await responses.moveNext().timeout(_timeout)) {}
  });
}
