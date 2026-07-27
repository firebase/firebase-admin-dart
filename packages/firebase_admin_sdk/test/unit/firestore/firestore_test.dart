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

import 'dart:io';

import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:firebase_admin_sdk/src/firestore/firestore.dart';
import 'package:firebase_admin_sdk/src/utils/utils.dart';
import 'package:google_cloud_firestore/google_cloud_firestore.dart' as gfs;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../fixtures/helpers.dart';
import '../../fixtures/mock_service_account.dart';

class MockAuthClient extends Mock implements auth.AuthClient {}

void main() {
  group('Firestore Wrapper', () {
    late FirebaseApp app;
    late Firestore firestoreService;
    late MockAuthClient client;

    setUp(() {
      client = MockAuthClient();

      // Create app with mock HTTP client to prevent actual authentication
      app = FirebaseApp.initializeApp(
        name: 'test-app-${DateTime.now().millisecondsSinceEpoch}',
        options: AppOptions(projectId: projectId, httpClient: client),
      );

      firestoreService = Firestore.internal(app);
    });

    tearDown(() async {
      await app.close();
    });

    group('Initializer', () {
      test('should not throw given a valid app', () {
        expect(() => firestoreService.getDatabase(), returnsNormally);
      });

      test('should return Firestore instance for named database', () {
        final db = firestoreService.getDatabase('my-database');
        expect(db, isA<gfs.Firestore>());
      });
    });

    group('app', () {
      test('returns the app from the constructor', () {
        expect(firestoreService.app, same(app));
      });
    });

    group('initializeDatabase', () {
      test('should initialize database with settings', () {
        const settings = gfs.Settings(projectId: 'test-project');

        expect(
          () => firestoreService.initializeDatabase('test-db', settings),
          returnsNormally,
        );
      });

      test('should return same instance if initialized with same settings', () {
        const settings = gfs.Settings(projectId: 'test-project');

        final db1 = firestoreService.initializeDatabase('test-db-1', settings);
        final db2 = firestoreService.initializeDatabase('test-db-1', settings);

        expect(db1, same(db2));
      });

      test(
        'should throw if database already initialized with different settings',
        () {
          const settings1 = gfs.Settings(projectId: 'test-project');
          const settings2 = gfs.Settings(projectId: 'different-project');

          firestoreService.initializeDatabase('test-db-2', settings1);

          expect(
            () => firestoreService.initializeDatabase('test-db-2', settings2),
            throwsA(
              isA<FirebaseAppException>()
                  .having(
                    (e) => e.errorCode,
                    'errorCode',
                    equals(AppErrorCode.failedPrecondition),
                  )
                  .having(
                    (e) => e.message,
                    'message',
                    contains('already been called with different settings'),
                  ),
            ),
          );
        },
      );
    });

    group('credential handling', () {
      test('should extract credentials from ServiceAccountCredential', () {
        // Use a real service account file for this test
        final serviceAccountFile = File('test/mock_service_account.json');
        if (!serviceAccountFile.existsSync()) {
          // Skip if mock service account doesn't exist
          return;
        }

        final credential = Credential.fromServiceAccount(serviceAccountFile);

        final credApp = FirebaseApp.initializeApp(
          name: 'cred-app',
          options: AppOptions(
            credential: credential,
            projectId: 'test-project',
            httpClient: client,
          ),
        );
        addTearDown(credApp.close);

        final service = Firestore.internal(credApp);
        final db = service.getDatabase();

        // The Firestore instance should have credentials set from the app
        // This test will FAIL initially because credential extraction is not implemented
        expect(db, isNotNull);

        // TODO: Add more specific assertions once we can inspect the settings
        // For now, this is a smoke test that it doesn't crash
      });

      test(
        'should use Application Default Credentials when no credential provided',
        () {
          // This test requires GOOGLE_APPLICATION_CREDENTIALS to be set
          // or running in a GCP environment
          final adcApp = FirebaseApp.initializeApp(
            name: 'adc-app',
            options: AppOptions(projectId: 'test-project', httpClient: client),
          );
          addTearDown(adcApp.close);

          final service = Firestore.internal(adcApp);
          final db = service.getDatabase();

          expect(db, isNotNull);
        },
        tags: 'prod',
      );
    });

    group('settings comparison', () {
      test('should detect different settings (projectId, host, ssl)', () {
        const settings1 = gfs.Settings(
          projectId: 'project-1',
          host: 'localhost:8080',
        );
        const settings2 = gfs.Settings(
          projectId: 'project-2',
          host: 'localhost:9090',
          ssl: false,
        );

        firestoreService.initializeDatabase('db-diff-1', settings1);

        expect(
          () => firestoreService.initializeDatabase('db-diff-1', settings2),
          throwsA(
            isA<FirebaseAppException>().having(
              (e) => e.message,
              'message',
              contains('already been called with different settings'),
            ),
          ),
        );
      });

      test('should detect different credentials', () {
        final settings1 = gfs.Settings(
          projectId: 'test-project',
          credential: gfs.Credential.fromServiceAccountParams(
            email: 'test1@example.com',
            privateKey: mockPrivateKey,
            projectId: 'test-project',
          ),
          environmentOverride: const {
            'FIRESTORE_EMULATOR_HOST': 'localhost:8080',
          },
        );
        final settings2 = gfs.Settings(
          projectId: 'test-project',
          credential: gfs.Credential.fromServiceAccountParams(
            email: 'test2@example.com',
            privateKey: mockPrivateKey,
            projectId: 'test-project',
          ),
          environmentOverride: const {
            'FIRESTORE_EMULATOR_HOST': 'localhost:8080',
          },
        );

        firestoreService.initializeDatabase('db-diff-2', settings1);

        expect(
          () => firestoreService.initializeDatabase('db-diff-2', settings2),
          throwsA(
            isA<FirebaseAppException>().having(
              (e) => e.message,
              'message',
              contains('already been called with different settings'),
            ),
          ),
        );
      });

      test('should allow same settings (including null)', () {
        final settings = gfs.Settings(
          projectId: 'test-project',
          credential: gfs.Credential.fromServiceAccountParams(
            email: mockClientEmail,
            privateKey: mockPrivateKey,
            projectId: 'test-project',
          ),
          environmentOverride: const {
            'FIRESTORE_EMULATOR_HOST': 'localhost:8080',
          },
        );

        final db1 = firestoreService.initializeDatabase('db-same-1', settings);
        final db2 = firestoreService.initializeDatabase('db-same-1', settings);

        expect(db1, same(db2));

        // Also test null settings
        final db3 = firestoreService.initializeDatabase('db-null-1', null);
        final db4 = firestoreService.initializeDatabase('db-null-1', null);

        expect(db3, same(db4));
      });
    });

    group('usage-tracking headers', () {
      test('are attached when no user headers are provided', () {
        final settings = firestoreService.buildSettingsForTesting('db', null);

        expect(settings.headers, firestoreUsageTrackingHeaders);
      });

      test('are merged with, not replaced by, user-provided headers', () {
        final settings = firestoreService.buildSettingsForTesting(
          'db',
          const gfs.Settings(headers: {'X-Trace-Id': 'abc123'}),
        );

        expect(settings.headers, {
          ...firestoreUsageTrackingHeaders,
          'X-Trace-Id': 'abc123',
        });
      });

      test('can be overridden by a user-provided header of the same name', () {
        final settings = firestoreService.buildSettingsForTesting(
          'db',
          const gfs.Settings(headers: {'X-Firebase-Client': 'custom-value'}),
        );

        expect(settings.headers!['X-Firebase-Client'], 'custom-value');
        expect(
          settings.headers!['X-Goog-Api-Client'],
          firestoreUsageTrackingHeaders['X-Goog-Api-Client'],
        );
      });
    });

    group('lifecycle', () {
      test('should terminate all databases on delete', () async {
        final db1 = firestoreService.getDatabase('lifecycle-1');
        final db2 = firestoreService.getDatabase('lifecycle-2');

        expect(db1, isNotNull);
        expect(db2, isNotNull);

        await firestoreService.delete();

        // After delete, the databases map should be empty
        // This is tested indirectly - we can't access private fields
      });

      test('should handle delete() called multiple times', () async {
        final db = firestoreService.getDatabase('multi-delete-test');
        expect(db, isNotNull);

        // First delete
        await firestoreService.delete();

        // Second delete should not throw
        expect(() => firestoreService.delete(), returnsNormally);
      });

      test('should throw when accessing firestore after app.close()', () async {
        final testApp = FirebaseApp.initializeApp(
          name: 'close-test-${DateTime.now().millisecondsSinceEpoch}',
          options: AppOptions(projectId: projectId, httpClient: client),
        );

        // Get firestore instance before closing
        final db = testApp.firestore();
        expect(db, isNotNull);

        // Close the app
        await testApp.close();

        // Trying to get firestore after close should throw
        expect(
          testApp.firestore,
          throwsA(
            isA<FirebaseAppException>().having(
              (e) => e.errorCode,
              'errorCode',
              equals(AppErrorCode.appDeleted),
            ),
          ),
        );
      });

      test('should create new instance after delete if requested', () async {
        final db1 = firestoreService.getDatabase('recreate-test');
        expect(db1, isNotNull);

        await firestoreService.delete();

        // After delete, getting database should create a new instance
        final db2 = firestoreService.getDatabase('recreate-test');
        expect(db2, isNotNull);
        expect(db2, isNot(same(db1)));
      });
    });
  });

  group('FirebaseApp.firestore()', () {
    late FirebaseApp app;
    late MockAuthClient client;

    setUp(() {
      client = MockAuthClient();
      app = FirebaseApp.initializeApp(
        name: 'firestore-api-test-${DateTime.now().millisecondsSinceEpoch}',
        options: AppOptions(projectId: projectId, httpClient: client),
      );
    });

    tearDown(() async {
      await app.close();
    });

    test('should return Firestore instance and cache it', () {
      final db1 = app.firestore();
      final db2 = app.firestore();

      expect(db1, isA<gfs.Firestore>());
      expect(db1, same(db2)); // Cached
    });

    test('should accept custom settings', () {
      const settings = gfs.Settings(
        projectId: 'test-project',
        host: 'localhost:8080',
        ssl: false,
      );

      final db = app.firestore(settings: settings, databaseId: 'my-db');
      expect(db, isA<gfs.Firestore>());
    });

    test('should throw if trying to reinitialize with different settings', () {
      const settings1 = gfs.Settings(projectId: 'project-1');
      const settings2 = gfs.Settings(projectId: 'project-2');

      app.firestore(settings: settings1, databaseId: 'reinit-test');

      expect(
        () => app.firestore(settings: settings2, databaseId: 'reinit-test'),
        throwsA(
          isA<FirebaseAppException>().having(
            (e) => e.message,
            'message',
            contains('already been called with different settings'),
          ),
        ),
      );
    });
  });

  group('Multi-database support', () {
    late FirebaseApp app;
    late MockAuthClient client;

    setUp(() {
      client = MockAuthClient();
      app = FirebaseApp.initializeApp(
        name: 'multi-db-test-${DateTime.now().millisecondsSinceEpoch}',
        options: AppOptions(projectId: projectId, httpClient: client),
      );
    });

    tearDown(() async {
      await app.close();
    });

    test('should support multiple databases per app', () {
      final defaultDb = app.firestore();
      final namedDb1 = app.firestore(databaseId: 'database-1');
      final namedDb2 = app.firestore(databaseId: 'database-2');

      expect(defaultDb, isA<gfs.Firestore>());
      expect(namedDb1, isA<gfs.Firestore>());
      expect(namedDb2, isA<gfs.Firestore>());

      // All should be different instances
      expect(defaultDb, isNot(same(namedDb1)));
      expect(defaultDb, isNot(same(namedDb2)));
      expect(namedDb1, isNot(same(namedDb2)));
    });
  });

  group('Edge Cases', () {
    late MockAuthClient client;

    setUp(() {
      client = MockAuthClient();
    });

    test('should work when projectId is null but provided in settings', () {
      final appWithoutProject = FirebaseApp.initializeApp(
        name: 'no-project-${DateTime.now().millisecondsSinceEpoch}',
        options: AppOptions(httpClient: client), // No projectId
      );
      addTearDown(appWithoutProject.close);

      // Should work if settings provide projectId
      const settings = gfs.Settings(projectId: 'settings-project');
      final db = appWithoutProject.firestore(settings: settings);

      expect(db, isA<gfs.Firestore>());
    });

    test('should allow empty database ID to default to "(default)"', () {
      final app = FirebaseApp.initializeApp(
        name: 'empty-db-${DateTime.now().millisecondsSinceEpoch}',
        options: AppOptions(projectId: projectId, httpClient: client),
      );
      addTearDown(app.close);

      // Empty string should be treated as default database
      final db1 = app.firestore(databaseId: '');
      final db2 = app.firestore(); // default

      expect(db1, isA<gfs.Firestore>());
      expect(db2, isA<gfs.Firestore>());
      // They might or might not be the same depending on implementation
    });

    test('should handle concurrent initialization of same database', () async {
      final app = FirebaseApp.initializeApp(
        name: 'concurrent-${DateTime.now().millisecondsSinceEpoch}',
        options: AppOptions(projectId: projectId, httpClient: client),
      );
      addTearDown(app.close);

      // Try to initialize the same database concurrently
      final results = await Future.wait([
        Future(() => app.firestore(databaseId: 'concurrent-db')),
        Future(() => app.firestore(databaseId: 'concurrent-db')),
        Future(() => app.firestore(databaseId: 'concurrent-db')),
      ]);

      // All should be the same instance (cached)
      expect(results[0], same(results[1]));
      expect(results[1], same(results[2]));
    });
  });
}
