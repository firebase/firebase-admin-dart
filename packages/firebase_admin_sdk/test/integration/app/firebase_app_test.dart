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
import 'dart:io';

import 'package:firebase_admin_sdk/auth.dart';
import 'package:firebase_admin_sdk/src/app.dart';
import 'package:firebase_admin_sdk/src/auth.dart';
import 'package:test/test.dart';

import '../../fixtures/helpers.dart';
import '../../fixtures/mock_service_account.dart';

void main() {
  group('FirebaseApp Integration', () {
    group('client creation', () {
      tearDown(() {
        FirebaseApp.apps.forEach(FirebaseApp.deleteApp);
      });

      test(
        'creates an authenticated client via Application Default Credentials',
        () async {
          final app = FirebaseApp.initializeApp(
            name: 'adc-client-${DateTime.now().microsecondsSinceEpoch}',
            options: AppOptions(
              credential: Credential.fromApplicationDefaultCredentials(),
              projectId: mockProjectId,
            ),
          );

          final client = await app.client;
          expect(client, isNotNull);

          await app.close();
        },
      );
    }, tags: 'prod');

    group(
      'Firestore emulator lifecycle',
      () {
        late FirebaseApp app;

        setUp(() {
          app = FirebaseApp.initializeApp(
            name: 'fs-lifecycle-${DateTime.now().millisecondsSinceEpoch}',
            options: const AppOptions(projectId: projectId),
          );
        });

        tearDown(() async {
          if (!app.isDeleted) await app.close();
        });

        test(
          'initialises Firestore, performs a round-trip, then closes cleanly',
          () async {
            final firestore = app.firestore();
            final docRef = firestore
                .collection('_app_integration')
                .doc('lifecycle-ping');

            await docRef.set({'status': 'alive'});

            final snap = await docRef.get();
            expect(snap.exists, isTrue);
            expect(snap.data()?['status'], 'alive');

            await docRef.delete();

            await app.close();

            expect(app.isDeleted, isTrue);
            expect(() => app.firestore(), throwsA(isA<FirebaseAppException>()));
          },
          timeout: const Timeout(Duration(seconds: 30)),
        );

        test('closes multiple services concurrently without error', () async {
          app.firestore();
          app.messaging();
          app.securityRules();

          await expectLater(app.close(), completes);

          expect(app.isDeleted, isTrue);
        }, timeout: const Timeout(Duration(seconds: 30)));
      },
      skip: Environment.isFirestoreEmulatorEnabled()
          ? false
          : 'Skipping Firestore emulator lifecycle tests. '
                'Set FIRESTORE_EMULATOR_HOST to run these tests.',
    );

    group(
      'Auth emulator lifecycle',
      () {
        // Remove production credentials from the zone so the Auth service
        // uses the emulator rather than hitting production.
        late Map<String, String> emulatorEnv;

        setUpAll(() {
          emulatorEnv = Map<String, String>.from(Platform.environment);
          emulatorEnv.remove(Environment.googleApplicationCredentials);
        });

        test('initialises Auth, creates a user, then closes cleanly', () async {
          await runZoned(zoneValues: {envSymbol: emulatorEnv}, () async {
            final app = FirebaseApp.initializeApp(
              name: 'auth-lifecycle-${DateTime.now().millisecondsSinceEpoch}',
              options: const AppOptions(projectId: projectId),
            );

            final auth = Auth.internal(app);

            final user = await auth.createUser(
              CreateRequest(email: 'lifecycle-test@example.com'),
            );
            expect(user.email, 'lifecycle-test@example.com');

            await auth.deleteUser(user.uid);

            await app.close();
            expect(app.isDeleted, isTrue);
          });
        }, timeout: const Timeout(Duration(seconds: 30)));
      },
      skip: Environment.isAuthEmulatorEnabled()
          ? false
          : 'Skipping Auth emulator lifecycle tests. '
                'Set FIREBASE_AUTH_EMULATOR_HOST to run these tests.',
    );
  });
}
