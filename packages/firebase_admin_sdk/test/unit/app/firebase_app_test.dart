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

import 'package:firebase_admin_sdk/functions.dart';
import 'package:firebase_admin_sdk/messaging.dart';
import 'package:firebase_admin_sdk/security_rules.dart';
import 'package:firebase_admin_sdk/src/app.dart';
import 'package:firebase_admin_sdk/src/app_check/app_check.dart';
import 'package:firebase_admin_sdk/src/auth.dart';
import 'package:firebase_admin_sdk/storage.dart';
import 'package:google_cloud/google_cloud.dart' as google_cloud;
import 'package:google_cloud_firestore/google_cloud_firestore.dart'
    as google_cloud_firestore;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../fixtures/helpers.dart';
import '../../fixtures/mock.dart';
import '../../fixtures/mock_service_account.dart';

void main() {
  group('FirebaseApp', () {
    group('initializeApp', () {
      tearDown(() {
        // Clean up all apps after each test
        FirebaseApp.apps.forEach(FirebaseApp.deleteApp);
      });

      test('creates a default app without options', () {
        final app = FirebaseApp.initializeApp();

        expect(app.name, '[DEFAULT]');
        expect(app.wasInitializedFromEnv, isTrue);
        expect(app.isDeleted, isFalse);
      });

      test('creates default app with options', () {
        const options = AppOptions(projectId: mockProjectId);
        final app = FirebaseApp.initializeApp(options: options);

        expect(app.name, '[DEFAULT]');
        expect(app.options.projectId, mockProjectId);
        expect(app.wasInitializedFromEnv, isFalse);
        expect(app.isDeleted, isFalse);
      });

      test('creates named app with options', () {
        const options = AppOptions(projectId: mockProjectId);
        final app = FirebaseApp.initializeApp(
          options: options,
          name: 'custom-app',
        );

        expect(app.name, 'custom-app');
        expect(app.options.projectId, mockProjectId);
        expect(app.wasInitializedFromEnv, isFalse);
      });

      test('returns same instance for duplicate initialization', () {
        const options = AppOptions(projectId: mockProjectId);
        final app1 = FirebaseApp.initializeApp(options: options);
        final app2 = FirebaseApp.initializeApp(options: options);

        expect(identical(app1, app2), isTrue);
      });

      test('allows multiple named apps', () {
        const options1 = AppOptions(projectId: 'project1');
        const options2 = AppOptions(projectId: 'project2');

        final app1 = FirebaseApp.initializeApp(options: options1, name: 'app1');
        final app2 = FirebaseApp.initializeApp(options: options2, name: 'app2');

        expect(app1.name, 'app1');
        expect(app2.name, 'app2');
        expect(app1.options.projectId, 'project1');
        expect(app2.options.projectId, 'project2');
      });
    });

    group('instance', () {
      tearDown(() {
        FirebaseApp.apps.forEach(FirebaseApp.deleteApp);
      });

      test('returns default app', () {
        final app = FirebaseApp.initializeApp();
        final instance = FirebaseApp.initializeApp();

        expect(identical(app, instance), isTrue);
      });

      test('throws if default app not initialized', () {
        expect(
          () => FirebaseApp.instance,
          throwsA(
            isA<FirebaseAppException>().having(
              (e) => e.code,
              'code',
              'app/no-app',
            ),
          ),
        );
      });
    });

    group('getApp', () {
      tearDown(() {
        FirebaseApp.apps.forEach(FirebaseApp.deleteApp);
      });

      test('returns default app when no name provided', () {
        final app = FirebaseApp.initializeApp(
          options: const AppOptions(projectId: mockProjectId),
        );
        final retrieved = FirebaseApp.getApp();

        expect(identical(app, retrieved), isTrue);
      });

      test('returns named app', () {
        final app = FirebaseApp.initializeApp(
          options: const AppOptions(projectId: mockProjectId),
          name: 'test-app',
        );
        final retrieved = FirebaseApp.getApp('test-app');

        expect(identical(app, retrieved), isTrue);
      });

      test('throws if app does not exist', () {
        expect(
          () => FirebaseApp.getApp('nonexistent'),
          throwsA(
            isA<FirebaseAppException>().having(
              (e) => e.code,
              'code',
              'app/no-app',
            ),
          ),
        );
      });
    });

    group('apps', () {
      tearDown(() {
        FirebaseApp.apps.forEach(FirebaseApp.deleteApp);
      });

      test('returns empty list when no apps initialized', () {
        expect(FirebaseApp.apps, isEmpty);
      });

      test('returns all initialized apps', () {
        final app1 = FirebaseApp.initializeApp(
          options: const AppOptions(projectId: 'project1'),
          name: 'app1',
        );
        final app2 = FirebaseApp.initializeApp(
          options: const AppOptions(projectId: 'project2'),
          name: 'app2',
        );

        final apps = FirebaseApp.apps;
        expect(apps.length, 2);
        expect(apps.contains(app1), isTrue);
        expect(apps.contains(app2), isTrue);
      });
    });

    group('deleteApp', () {
      test('removes app from registry', () async {
        final app = FirebaseApp.initializeApp(
          options: const AppOptions(projectId: mockProjectId),
        );

        await FirebaseApp.deleteApp(app);

        expect(FirebaseApp.apps, isEmpty);
      });

      test('marks app as deleted', () async {
        final app = FirebaseApp.initializeApp(
          options: const AppOptions(projectId: mockProjectId),
        );

        await FirebaseApp.deleteApp(app);

        expect(app.isDeleted, isTrue);
      });

      test('throws if app does not exist in registry', () async {
        final app = FirebaseApp(
          name: 'fake-app',
          options: const AppOptions(projectId: mockProjectId),
          wasInitializedFromEnv: false,
        );

        expect(
          () => FirebaseApp.deleteApp(app),
          throwsA(
            isA<FirebaseAppException>().having(
              (e) => e.code,
              'code',
              'app/no-app',
            ),
          ),
        );
      });
    });

    group('properties', () {
      tearDown(() async {
        FirebaseApp.apps.forEach(FirebaseApp.deleteApp);
      });

      test('projectId returns null when not configured', () {
        final appWithoutProject = FirebaseApp.initializeApp(
          options: const AppOptions(),
          name: 'test-app',
        );

        expect(appWithoutProject.projectId, isNull);

        FirebaseApp.deleteApp(appWithoutProject);
      });

      test('projectId returns the configured value', () {
        final app = FirebaseApp.initializeApp(
          options: const AppOptions(projectId: mockProjectId),
          name: 'configured-project-app',
        );

        expect(app.projectId, mockProjectId);
      });

      test('isDeleted returns false for active app', () {
        final app = FirebaseApp.initializeApp(
          options: const AppOptions(projectId: mockProjectId),
          name: 'test-app',
        );

        expect(app.isDeleted, isFalse);
      });
    });

    group('getProjectId', () {
      late FirebaseApp app;

      setUp(() {
        app = FirebaseApp.initializeApp(
          name: 'get-project-id-${DateTime.now().microsecondsSinceEpoch}',
          options: const AppOptions(),
        );
      });

      tearDown(() async {
        if (!app.isDeleted) await app.close();
      });

      test(
        'returns project ID from explicit environment map – GOOGLE_CLOUD_PROJECT',
        () async {
          final resolved = await app.getProjectId(
            environment: {'GOOGLE_CLOUD_PROJECT': 'from-google-cloud-project'},
          );
          expect(resolved, 'from-google-cloud-project');
        },
      );

      test(
        'returns project ID from explicit environment map – GCLOUD_PROJECT',
        () async {
          final resolved = await app.getProjectId(
            environment: {'GCLOUD_PROJECT': 'from-gcloud-project'},
          );
          expect(resolved, 'from-gcloud-project');
        },
      );

      test(
        'returns project ID from explicit environment map – GCP_PROJECT',
        () async {
          final resolved = await app.getProjectId(
            environment: {'GCP_PROJECT': 'from-gcp-project'},
          );
          expect(resolved, 'from-gcp-project');
        },
      );

      test(
        'returns project ID from explicit environment map – CLOUDSDK_CORE_PROJECT',
        () async {
          final resolved = await app.getProjectId(
            environment: {
              'CLOUDSDK_CORE_PROJECT': 'from-cloudsdk-core-project',
            },
          );
          expect(resolved, 'from-cloudsdk-core-project');
        },
      );

      test('returns project ID from zone-injected environment', () async {
        await runZoned(
          zoneValues: {
            envSymbol: {'GOOGLE_CLOUD_PROJECT': 'zone-project'},
          },
          () async {
            final resolved = await app.getProjectId();
            expect(resolved, 'zone-project');
          },
        );
      });

      test(
        'explicit environment map takes precedence over projectIdOverride',
        () async {
          final resolved = await app.getProjectId(
            projectIdOverride: 'override-project',
            environment: {'GOOGLE_CLOUD_PROJECT': 'env-wins'},
          );
          expect(resolved, 'env-wins');
        },
      );

      test(
        'zone environment takes precedence over projectIdOverride',
        () async {
          await runZoned(
            zoneValues: {
              envSymbol: {'GOOGLE_CLOUD_PROJECT': 'zone-wins'},
            },
            () async {
              final resolved = await app.getProjectId(
                projectIdOverride: 'override-loses',
              );
              expect(resolved, 'zone-wins');
            },
          );
        },
      );

      test(
        'explicit environment map takes precedence over options.projectId',
        () async {
          final appWithProject = FirebaseApp.initializeApp(
            name: 'env-over-options-${DateTime.now().microsecondsSinceEpoch}',
            options: const AppOptions(projectId: 'options-project'),
          );
          addTearDown(() async {
            if (!appWithProject.isDeleted) await appWithProject.close();
          });

          final resolved = await appWithProject.getProjectId(
            environment: {'GOOGLE_CLOUD_PROJECT': 'env-wins-over-options'},
          );
          expect(resolved, 'env-wins-over-options');
        },
      );

      test(
        'projectIdOverride takes precedence over options.projectId',
        () async {
          final appWithProject = FirebaseApp.initializeApp(
            name:
                'override-over-options-${DateTime.now().microsecondsSinceEpoch}',
            options: const AppOptions(projectId: 'options-project'),
          );
          addTearDown(() async {
            if (!appWithProject.isDeleted) await appWithProject.close();
          });

          final resolved = await appWithProject.getProjectId(
            projectIdOverride: 'override-wins',
            environment: <String, String>{},
          );
          expect(resolved, 'override-wins');
        },
      );

      test(
        'returns projectIdOverride when no environment variables are set',
        () async {
          final resolved = await app.getProjectId(
            projectIdOverride: 'only-override',
            environment: <String, String>{},
          );
          expect(resolved, 'only-override');
        },
      );

      test(
        'returns options.projectId when no env vars and no override',
        () async {
          final appWithProject = FirebaseApp.initializeApp(
            name: 'options-fallback-${DateTime.now().microsecondsSinceEpoch}',
            options: const AppOptions(projectId: 'configured-project'),
          );
          addTearDown(() async {
            if (!appWithProject.isDeleted) await appWithProject.close();
          });

          final resolved = await appWithProject.getProjectId(
            environment: <String, String>{},
          );
          expect(resolved, 'configured-project');
        },
      );

      test('ignores empty environment values', () async {
        final appWithProject = FirebaseApp.initializeApp(
          name: 'empty-env-${DateTime.now().microsecondsSinceEpoch}',
          options: const AppOptions(projectId: 'configured-project'),
        );
        addTearDown(() async {
          if (!appWithProject.isDeleted) await appWithProject.close();
        });

        final resolved = await appWithProject.getProjectId(
          environment: {'GOOGLE_CLOUD_PROJECT': ''},
        );
        expect(resolved, 'configured-project');
      });

      test('falls back to the service account credential', () async {
        final appWithCredential = FirebaseApp.initializeApp(
          name: 'credential-project-${DateTime.now().microsecondsSinceEpoch}',
          options: AppOptions(
            credential: Credential.fromServiceAccountParams(
              clientId: 'client-id',
              privateKey: mockPrivateKey,
              email: mockClientEmail,
              projectId: 'from-credential',
            ),
          ),
        );
        addTearDown(() async {
          if (!appWithCredential.isDeleted) await appWithCredential.close();
        });

        final resolved = await appWithCredential.getProjectId(
          environment: <String, String>{},
        );
        expect(resolved, 'from-credential');
      });

      test('prefers options.projectId over the credential', () async {
        final appWithBoth = FirebaseApp.initializeApp(
          name:
              'options-over-credential-${DateTime.now().microsecondsSinceEpoch}',
          options: AppOptions(
            projectId: 'options-project',
            credential: Credential.fromServiceAccountParams(
              clientId: 'client-id',
              privateKey: mockPrivateKey,
              email: mockClientEmail,
              projectId: 'from-credential',
            ),
          ),
        );
        addTearDown(() async {
          if (!appWithBoth.isDeleted) await appWithBoth.close();
        });

        final resolved = await appWithBoth.getProjectId(
          environment: <String, String>{},
        );
        expect(resolved, 'options-project');
      });
    });

    group('resolveProjectIdSync', () {
      test('resolves without any asynchronous work', () {
        final appWithProject = FirebaseApp.initializeApp(
          name: 'sync-options-${DateTime.now().microsecondsSinceEpoch}',
          options: const AppOptions(projectId: 'sync-project'),
        );
        addTearDown(() async {
          if (!appWithProject.isDeleted) await appWithProject.close();
        });

        expect(
          appWithProject.resolveProjectIdSync(environment: <String, String>{}),
          'sync-project',
        );
      });

      test('returns null when only async discovery could resolve it', () {
        final bareApp = FirebaseApp.initializeApp(
          name: 'sync-unresolvable-${DateTime.now().microsecondsSinceEpoch}',
          options: const AppOptions(),
        );
        addTearDown(() async {
          if (!bareApp.isDeleted) await bareApp.close();
        });

        final resolved = bareApp.resolveProjectIdSync(
          environment: <String, String>{},
        );
        expect(
          resolved,
          anyOf(isNull, equals(google_cloud.projectIdFromCredentialsFile())),
        );
      });
    });

    group('client', () {
      test('returns custom client when provided', () async {
        final mockClient = MockAuthClient();
        final app = FirebaseApp.initializeApp(
          options: AppOptions(projectId: mockProjectId, httpClient: mockClient),
        );

        final client = await app.client;
        expect(identical(client, mockClient), isTrue);

        await FirebaseApp.deleteApp(app);
      });

      test('reuses same client on subsequent calls', () {
        runZoned(() async {
          final mockClient = MockAuthClient();
          final app = FirebaseApp.initializeApp(
            options: AppOptions(
              projectId: mockProjectId,
              httpClient: mockClient,
            ),
          );
          final client1 = await app.client;
          final client2 = await app.client;

          expect(identical(client1, client2), isTrue);

          await FirebaseApp.deleteApp(app);
        }, zoneValues: {envSymbol: <String, String>{}});
      });
    });

    group('service accessors', () {
      late FirebaseApp app;

      setUp(() {
        runZoned(() {
          final mockClient = MockAuthClient();
          app = FirebaseApp.initializeApp(
            options: AppOptions(
              projectId: mockProjectId,
              httpClient: mockClient,
            ),
          );
        }, zoneValues: {});
      });

      tearDown(() async {
        if (!app.isDeleted) {
          await FirebaseApp.deleteApp(app);
        }
      });

      test('appCheck returns AppCheck instance', () {
        final appCheck = app.appCheck();
        expect(appCheck, isA<AppCheck>());
        expect(identical(appCheck.app, app), isTrue);
      });

      test('appCheck returns cached instance', () {
        final appCheck1 = app.appCheck();
        final appCheck2 = app.appCheck();
        expect(identical(appCheck1, appCheck2), isTrue);
        expect(identical(appCheck2, AppCheck.internal(app)), isTrue);
      });

      test('auth returns Auth instance', () {
        final auth = app.auth();
        expect(auth, isA<Auth>());
        expect(identical(auth.app, app), isTrue);
      });

      test('auth returns cached instance', () {
        final auth1 = app.auth();
        final auth2 = app.auth();
        expect(identical(auth1, auth2), isTrue);
        expect(identical(auth2, Auth.internal(app)), isTrue);
      });

      test('firestore returns Firestore instance', () {
        final firestore = app.firestore(settings: mockFirestoreSettings);
        expect(firestore, isA<google_cloud_firestore.Firestore>());
        // Verify we can use Firestore methods
        expect(firestore.collection('test'), isNotNull);
      });

      test('firestore returns cached instance', () {
        final firestore1 = app.firestore(settings: mockFirestoreSettings);
        final firestore2 = app.firestore(settings: mockFirestoreSettings);
        expect(identical(firestore1, firestore2), isTrue);
      });

      test(
        'firestore with different databaseId returns different instances',
        () {
          final firestore1 = app.firestore(
            settings: mockFirestoreSettingsWithDb('db1'),
            databaseId: 'db1',
          );
          final firestore2 = app.firestore(
            settings: mockFirestoreSettingsWithDb('db2'),
            databaseId: 'db2',
          );
          expect(identical(firestore1, firestore2), isFalse);
        },
      );

      test('firestore throws when reinitializing with different settings', () {
        // Initialize with first settings
        app.firestore(
          settings: const google_cloud_firestore.Settings(
            host: 'localhost:8080',
            environmentOverride: {'FIRESTORE_EMULATOR_HOST': 'localhost:8080'},
          ),
        );

        // Try to initialize again with different settings - should throw
        expect(
          () => app.firestore(
            settings: const google_cloud_firestore.Settings(
              host: 'different:9090',
              environmentOverride: {
                'FIRESTORE_EMULATOR_HOST': 'localhost:8080',
              },
            ),
          ),
          throwsA(isA<FirebaseAppException>()),
        );
      });

      test('messaging returns Messaging instance', () {
        final messaging = app.messaging();
        expect(messaging, isA<Messaging>());
        expect(identical(messaging.app, app), isTrue);
      });

      test('messaging returns cached instance', () {
        final messaging1 = app.messaging();
        final messaging2 = app.messaging();
        expect(identical(messaging1, messaging2), isTrue);
        expect(identical(messaging1, Messaging.internal(app)), isTrue);
      });

      test('securityRules returns SecurityRules instance', () {
        final securityRules = app.securityRules();
        expect(securityRules, isA<SecurityRules>());
        expect(identical(securityRules.app, app), isTrue);
      });

      test('securityRules returns cached instance', () {
        final securityRules1 = app.securityRules();
        final securityRules2 = app.securityRules();
        expect(identical(securityRules1, securityRules2), isTrue);
      });

      test('functions returns Functions instance', () {
        final functions = app.functions();
        expect(functions, isA<Functions>());
        expect(identical(functions.app, app), isTrue);
      });

      test('functions returns cached instance', () {
        final functions1 = app.functions();
        final functions2 = app.functions();
        expect(identical(functions1, functions2), isTrue);
        expect(identical(functions1, Functions.internal(app)), isTrue);
      });

      test('storage returns Storage instance', () {
        final storage = app.storage();
        expect(storage, isA<Storage>());
        expect(identical(storage.app, app), isTrue);
      });

      test('storage returns cached instance', () {
        final storage1 = app.storage();
        final storage2 = app.storage();
        expect(identical(storage1, storage2), isTrue);
        expect(identical(storage1, Storage.internal(app)), isTrue);
      });

      test('throws when accessing services after deletion', () async {
        await app.close();

        expect(
          () => app.auth(),
          throwsA(
            isA<FirebaseAppException>().having(
              (e) => e.code,
              'code',
              'app/app-deleted',
            ),
          ),
        );
        expect(
          () => app.firestore(settings: mockFirestoreSettings),
          throwsA(
            isA<FirebaseAppException>().having(
              (e) => e.code,
              'code',
              'app/app-deleted',
            ),
          ),
        );
      });

      test('appCheck throws when accessing after deletion', () async {
        await app.close();

        expect(
          () => app.appCheck(),
          throwsA(
            isA<FirebaseAppException>().having(
              (e) => e.code,
              'code',
              'app/app-deleted',
            ),
          ),
        );
      });

      test('messaging throws when accessing after deletion', () async {
        await app.close();

        expect(
          () => app.messaging(),
          throwsA(
            isA<FirebaseAppException>().having(
              (e) => e.code,
              'code',
              'app/app-deleted',
            ),
          ),
        );
      });

      test('securityRules throws when accessing after deletion', () async {
        await app.close();

        expect(
          () => app.securityRules(),
          throwsA(
            isA<FirebaseAppException>().having(
              (e) => e.code,
              'code',
              'app/app-deleted',
            ),
          ),
        );
      });

      test('functions throws when accessing after deletion', () async {
        await app.close();

        expect(
          () => app.functions(),
          throwsA(
            isA<FirebaseAppException>().having(
              (e) => e.code,
              'code',
              'app/app-deleted',
            ),
          ),
        );
      });

      test('storage throws when accessing after deletion', () async {
        await app.close();

        expect(
          () => app.storage(),
          throwsA(
            isA<FirebaseAppException>().having(
              (e) => e.code,
              'code',
              'app/app-deleted',
            ),
          ),
        );
      });
    });

    group('close', () {
      test('marks app as deleted', () async {
        final app = FirebaseApp.initializeApp(
          options: const AppOptions(projectId: mockProjectId),
        );

        await app.close();

        expect(app.isDeleted, isTrue);
      });

      test('removes app from registry', () async {
        final app = FirebaseApp.initializeApp(
          options: const AppOptions(projectId: mockProjectId),
        );

        await app.close();

        expect(FirebaseApp.apps, isEmpty);
      });

      test('cleans up services', () async {
        final app = FirebaseApp.initializeApp(
          options: const AppOptions(projectId: mockProjectId),
        );

        // Initialize a service
        app.auth();

        await app.close();

        expect(app.isDeleted, isTrue);
      });

      test('closes HTTP client when created by SDK', () {
        runZoned(() async {
          final mockClient = MockAuthClient();
          final app = FirebaseApp.initializeApp(
            options: AppOptions(
              projectId: mockProjectId,
              httpClient: mockClient,
            ),
          );

          await app.client;

          await app.close();

          expect(app.isDeleted, isTrue);
        }, zoneValues: {});
      });

      test('does not close custom HTTP client', () async {
        final mockClient = MockAuthClient();
        final app = FirebaseApp.initializeApp(
          options: AppOptions(projectId: mockProjectId, httpClient: mockClient),
        );

        // Trigger client access
        await app.client;

        await app.close();

        // Verify close was not NOT called on custom client
        verifyNever(mockClient.close);
      });

      test('throws when called twice', () async {
        final app = FirebaseApp.initializeApp(
          options: const AppOptions(projectId: mockProjectId),
        );

        await app.close();

        expect(
          app.close,
          throwsA(
            isA<FirebaseAppException>().having(
              (e) => e.code,
              'code',
              'app/app-deleted',
            ),
          ),
        );
      });

      test(
        'calls delete() on auth service and closes HTTP client when emulator is enabled',
        () async {
          const firebaseAuthEmulatorHost = '127.0.0.1:9099';
          final testEnv = <String, String>{
            Environment.firebaseAuthEmulatorHost: firebaseAuthEmulatorHost,
          };

          await runZoned(zoneValues: {envSymbol: testEnv}, () async {
            // Create mocks
            final mockHttpClient = AuthHttpClientMock();
            final mockClient = MockAuthClient();

            final app = FirebaseApp.initializeApp(
              options: const AppOptions(projectId: mockProjectId),
            );

            // Setup the mock: httpClient returns our mock client
            when(
              () => mockHttpClient.client,
            ).thenAnswer((_) async => mockClient);

            // Create a real request handler with mocked http client
            final requestHandler = AuthRequestHandler(
              app,
              httpClient: mockHttpClient,
            );

            // Initialize auth service with our request handler
            Auth.internal(app, requestHandler: requestHandler);

            // Verify emulator is enabled
            expect(Environment.isAuthEmulatorEnabled(), isTrue);

            // Close the app - this should call delete() on auth service
            // which should close the HTTP client
            await app.close();

            // Verify app is marked as deleted
            expect(app.isDeleted, isTrue);

            // Verify client.close() was called
            verify(mockClient.close).called(1);
          });
        },
      );

      test(
        'closes firestore service and HTTP client when emulator is enabled',
        () async {
          const firestoreEmulatorHost = 'localhost:8080';
          final testEnv = <String, String>{
            Environment.firestoreEmulatorHost: firestoreEmulatorHost,
          };

          await runZoned(zoneValues: {envSymbol: testEnv}, () async {
            final app = FirebaseApp.initializeApp(
              options: const AppOptions(projectId: mockProjectId),
            );

            // Initialize firestore service
            app.firestore();

            // Verify emulator is enabled
            expect(Environment.isFirestoreEmulatorEnabled(), isTrue);

            // Close the app - this should call delete() on firestore service
            await app.close();

            // Verify app is marked as deleted
            expect(app.isDeleted, isTrue);

            // Verify accessing service after close throws
            expect(
              app.firestore,
              throwsA(
                isA<FirebaseAppException>().having(
                  (e) => e.code,
                  'code',
                  'app/app-deleted',
                ),
              ),
            );
          });
        },
      );
    });
  });
}
