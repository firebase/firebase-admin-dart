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
import 'dart:convert';

import 'package:firebase_admin_sdk/src/app.dart';
import 'package:firebase_admin_sdk/src/storage/storage.dart';
import 'package:google_cloud_storage/google_cloud_storage.dart' as gcs;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../fixtures/helpers.dart';

class MockAuthClient extends Mock implements auth.AuthClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
  });

  group('Storage', () {
    late FirebaseApp app;
    late FirebaseApp appWithBucket;
    late MockAuthClient mockClient;

    setUp(() {
      mockClient = MockAuthClient();

      // Create app without storage bucket
      app = FirebaseApp.initializeApp(
        name: 'test-app-${DateTime.now().millisecondsSinceEpoch}',
        options: AppOptions(projectId: projectId, httpClient: mockClient),
      );

      // Create app with storage bucket configured
      appWithBucket = FirebaseApp.initializeApp(
        name: 'test-app-bucket-${DateTime.now().millisecondsSinceEpoch}',
        options: AppOptions(
          projectId: projectId,
          storageBucket: 'bucketName.appspot.com',
          httpClient: mockClient,
        ),
      );
    });

    tearDown(() async {
      await app.close();
      await appWithBucket.close();
    });

    group('Constructor', () {
      test('should not throw given a valid app', () {
        expect(() => Storage.internal(app), returnsNormally);
      });

      test('should create storage instance successfully', () {
        final storage = Storage.internal(app);
        expect(storage, isA<Storage>());
      });

      test('should be singleton per app', () {
        final storage1 = Storage.internal(app);
        final storage2 = Storage.internal(app);
        expect(storage1, same(storage2));
      });
    });

    group('app', () {
      test('returns the app from the constructor', () {
        final storage = Storage.internal(app);
        // We expect referential equality here
        expect(storage.app, same(app));
      });

      test('is read-only', () {
        final storage = Storage.internal(app);
        // In Dart, final properties are inherently read-only
        expect(storage.app, isA<FirebaseApp>());
      });
    });

    group('bucket()', () {
      test('should return a bucket object when called with no arguments', () {
        final storage = Storage.internal(appWithBucket);
        final bucket = storage.bucket();
        expect(bucket, isA<gcs.Bucket>());
        expect(bucket.name, 'bucketName.appspot.com');
      });

      test('should return a bucket object when called with valid name', () {
        final storage = Storage.internal(app);
        final bucket = storage.bucket('foo');
        expect(bucket, isA<gcs.Bucket>());
        expect(bucket.name, 'foo');
      });

      test(
        'should throw when no bucket name provided and no default configured',
        () {
          final storage = Storage.internal(app);

          expect(
            storage.bucket,
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
                    contains('Bucket name not specified or invalid'),
                  )
                  .having(
                    (e) => e.message,
                    'message',
                    contains(
                      'Specify a valid bucket name via the storageBucket option',
                    ),
                  )
                  .having(
                    (e) => e.message,
                    'message',
                    contains('calling the bucket() method'),
                  ),
            ),
          );
        },
      );

      test('should throw when empty string is provided', () {
        final storage = Storage.internal(app);

        expect(
          () => storage.bucket(''),
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
                  contains('Bucket name not specified or invalid'),
                ),
          ),
        );
      });

      test('should create multiple buckets with different names', () {
        final storage = Storage.internal(app);
        final bucket1 = storage.bucket('bucket-1');
        final bucket2 = storage.bucket('bucket-2');

        expect(bucket1.name, 'bucket-1');
        expect(bucket2.name, 'bucket-2');
      });

      test('should prioritize explicit name over default bucket', () {
        final storage = Storage.internal(appWithBucket);
        final bucket = storage.bucket('custom-bucket');

        expect(bucket.name, 'custom-bucket');
        expect(bucket.name, isNot('bucketName.appspot.com'));
      });
    });

    group('Emulator mode', () {
      const validEmulatorHost = 'localhost:9199';
      const invalidEmulatorHost = 'https://localhost:9199';

      test(
        'sets up correctly when FIREBASE_STORAGE_EMULATOR_HOST is set',
        () async {
          final testEnv = <String, String>{
            Environment.firebaseStorageEmulatorHost: validEmulatorHost,
          };

          await runZoned(zoneValues: {envSymbol: testEnv}, () async {
            final testApp = FirebaseApp.initializeApp(
              name: 'emulator-test-${DateTime.now().millisecondsSinceEpoch}',
              options: AppOptions(projectId: projectId, httpClient: mockClient),
            );
            addTearDown(() async {
              await testApp.close();
            });

            // Should create storage without errors
            final storage = Storage.internal(testApp);
            expect(storage, isA<Storage>());

            // Verify that storage works in emulator mode
            expect(() => storage.bucket('test-bucket'), returnsNormally);
          });
        },
      );

      test('throws if FIREBASE_STORAGE_EMULATOR_HOST has a protocol', () async {
        final testEnv = <String, String>{
          Environment.firebaseStorageEmulatorHost: invalidEmulatorHost,
        };

        await runZoned(zoneValues: {envSymbol: testEnv}, () async {
          final testApp = FirebaseApp.initializeApp(
            name:
                'emulator-protocol-test-${DateTime.now().millisecondsSinceEpoch}',
            options: AppOptions(projectId: projectId, httpClient: mockClient),
          );
          addTearDown(() async {
            await testApp.close();
          });

          expect(
            () => Storage.internal(testApp),
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
                    contains(
                      'FIREBASE_STORAGE_EMULATOR_HOST should not contain a protocol',
                    ),
                  ),
            ),
          );
        });
      });

      test('throws if protocol is http://', () async {
        final testEnv = <String, String>{
          Environment.firebaseStorageEmulatorHost: 'http://localhost:9199',
        };

        await runZoned(zoneValues: {envSymbol: testEnv}, () async {
          final testApp = FirebaseApp.initializeApp(
            name: 'emulator-http-test-${DateTime.now().millisecondsSinceEpoch}',
            options: AppOptions(projectId: projectId, httpClient: mockClient),
          );
          addTearDown(() async {
            await testApp.close();
          });

          expect(
            () => Storage.internal(testApp),
            throwsA(
              isA<FirebaseAppException>().having(
                (e) => e.message,
                'message',
                contains(
                  'FIREBASE_STORAGE_EMULATOR_HOST should not contain a protocol',
                ),
              ),
            ),
          );
        });
      });

      test('works correctly without emulator configuration', () async {
        // Empty environment - no emulator
        final testEnv = <String, String>{};

        await runZoned(zoneValues: {envSymbol: testEnv}, () async {
          final testApp = FirebaseApp.initializeApp(
            name: 'no-emulator-test-${DateTime.now().millisecondsSinceEpoch}',
            options: AppOptions(projectId: projectId, httpClient: mockClient),
          );
          addTearDown(() async {
            await testApp.close();
          });

          final storage = Storage.internal(testApp);
          expect(storage, isA<Storage>());
          expect(() => storage.bucket('test-bucket'), returnsNormally);
        });
      });
    });

    group('FirebaseApp.storage()', () {
      late FirebaseApp testApp;

      setUp(() {
        testApp = FirebaseApp.initializeApp(
          name: 'storage-api-test-${DateTime.now().millisecondsSinceEpoch}',
          options: AppOptions(
            projectId: projectId,
            storageBucket: 'test-bucket.appspot.com',
            httpClient: mockClient,
          ),
        );
      });

      tearDown(() async {
        await testApp.close();
      });

      test('should return Storage instance and cache it', () {
        final storage1 = testApp.storage();
        final storage2 = testApp.storage();

        expect(storage1, isA<Storage>());
        expect(storage1, same(storage2)); // Cached
      });

      test('should provide access to bucket() method', () {
        final storage = testApp.storage();
        final bucket = storage.bucket(); // Use default bucket

        expect(bucket, isA<gcs.Bucket>());
        expect(bucket.name, 'test-bucket.appspot.com');
      });
    });

    group('lifecycle', () {
      test('should handle delete() gracefully', () async {
        final testApp = FirebaseApp.initializeApp(
          name: 'delete-test-${DateTime.now().millisecondsSinceEpoch}',
          options: AppOptions(projectId: projectId, httpClient: mockClient),
        );

        final storage = Storage.internal(testApp);
        expect(storage, isNotNull);

        // Delete should not throw
        await storage.delete();

        // Clean up the app
        await testApp.close();
      });

      test('should handle delete() called multiple times gracefully', () async {
        final testApp = FirebaseApp.initializeApp(
          name: 'multi-delete-test-${DateTime.now().millisecondsSinceEpoch}',
          options: AppOptions(projectId: projectId, httpClient: mockClient),
        );

        final storage = Storage.internal(testApp);
        expect(storage, isNotNull);

        await storage.delete();
        await storage.delete();
        await testApp.close();
      });

      test('should throw when accessing storage after app.close()', () async {
        final testApp = FirebaseApp.initializeApp(
          name: 'close-test-${DateTime.now().millisecondsSinceEpoch}',
          options: AppOptions(projectId: projectId, httpClient: mockClient),
        );

        // Get storage instance before closing
        final storage = testApp.storage();
        expect(storage, isNotNull);

        // Close the app
        await testApp.close();

        // Trying to get storage after close should throw
        expect(
          testApp.storage,
          throwsA(
            isA<FirebaseAppException>().having(
              (e) => e.errorCode,
              'errorCode',
              equals(AppErrorCode.appDeleted),
            ),
          ),
        );
      });
    });

    group('Integration with underlying Storage library', () {
      test('should pass through to google_cloud_storage correctly', () {
        final storage = Storage.internal(appWithBucket);
        final bucket = storage.bucket('integration-test-bucket');

        expect(bucket, isA<gcs.Bucket>());
        expect(bucket.name, 'integration-test-bucket');

        // The bucket should be a valid google_cloud_storage.Bucket instance
        expect(bucket.storage, isNotNull);
      });

      test('should handle bucket operations without errors', () {
        final storage = Storage.internal(app);

        // Create multiple buckets
        final bucket1 = storage.bucket('test-bucket-1');
        final bucket2 = storage.bucket('test-bucket-2');
        final bucket3 = storage.bucket('test-bucket-3');

        expect(bucket1.name, 'test-bucket-1');
        expect(bucket2.name, 'test-bucket-2');
        expect(bucket3.name, 'test-bucket-3');
      });
    });

    group('getDownloadURL()', () {
      const bucketName = 'test-bucket.appspot.com';
      const objectName = 'path/to/file.jpg';
      const downloadToken = 'abc-token';
      const productionEndpoint = 'https://firebasestorage.googleapis.com/v0';

      test('returns correct download URL for production endpoint', () async {
        // Clear emulator env var so we hit the production endpoint.
        await runZoned(zoneValues: {envSymbol: <String, String>{}}, () async {
          final storage = Storage.internal(app);
          final bucket = storage.bucket(bucketName);

          when(() => mockClient.get(any())).thenAnswer(
            (_) async => http.Response(
              jsonEncode({'downloadTokens': downloadToken}),
              200,
            ),
          );

          final url = await storage.getDownloadURL(bucket, objectName);

          expect(
            url,
            '$productionEndpoint/b/$bucketName/o/${Uri.encodeComponent(objectName)}?alt=media&token=$downloadToken',
          );
        });
      });

      test(
        'uses only the first token when multiple tokens are present',
        () async {
          final storage = Storage.internal(app);
          final bucket = storage.bucket(bucketName);

          when(() => mockClient.get(any())).thenAnswer(
            (_) async => http.Response(
              jsonEncode({
                'downloadTokens': 'first-token,second-token,third-token',
              }),
              200,
            ),
          );

          final url = await storage.getDownloadURL(bucket, 'file.txt');
          expect(url, contains('token=first-token'));
          expect(url, isNot(contains('second-token')));
        },
      );

      test(
        'throws noDownloadToken when metadata has no downloadTokens',
        () async {
          final storage = Storage.internal(app);
          final bucket = storage.bucket(bucketName);

          when(() => mockClient.get(any())).thenAnswer(
            (_) async => http.Response(jsonEncode(<String, dynamic>{}), 200),
          );

          await expectLater(
            storage.getDownloadURL(bucket, objectName),
            throwsA(
              isA<FirebaseStorageAdminException>()
                  .having(
                    (e) => e.errorCode,
                    'errorCode',
                    StorageClientErrorCode.noDownloadToken,
                  )
                  .having(
                    (e) => e.message,
                    'message',
                    contains('No download token available'),
                  ),
            ),
          );
        },
      );

      test(
        'throws noDownloadToken when downloadTokens is an empty string',
        () async {
          final storage = Storage.internal(app);
          final bucket = storage.bucket(bucketName);

          when(() => mockClient.get(any())).thenAnswer(
            (_) async => http.Response(jsonEncode({'downloadTokens': ''}), 200),
          );

          await expectLater(
            storage.getDownloadURL(bucket, objectName),
            throwsA(
              isA<FirebaseStorageAdminException>().having(
                (e) => e.errorCode,
                'errorCode',
                StorageClientErrorCode.noDownloadToken,
              ),
            ),
          );
        },
      );

      test('throws internalError on a non-200 HTTP response', () async {
        final storage = Storage.internal(app);
        final bucket = storage.bucket(bucketName);

        when(
          () => mockClient.get(any()),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        await expectLater(
          storage.getDownloadURL(bucket, objectName),
          throwsA(
            isA<FirebaseStorageAdminException>()
                .having(
                  (e) => e.errorCode,
                  'errorCode',
                  StorageClientErrorCode.internalError,
                )
                .having((e) => e.message, 'message', contains('500')),
          ),
        );
      });

      test('URL-encodes object names with special characters', () async {
        final storage = Storage.internal(app);
        final bucket = storage.bucket(bucketName);

        when(() => mockClient.get(any())).thenAnswer(
          (_) async =>
              http.Response(jsonEncode({'downloadTokens': downloadToken}), 200),
        );

        const specialName = 'my folder/my file (1).jpg';
        final url = await storage.getDownloadURL(bucket, specialName);
        expect(url, contains(Uri.encodeComponent(specialName)));
      });

      test(
        'uses the emulator endpoint when FIREBASE_STORAGE_EMULATOR_HOST is set',
        () async {
          const emulatorHost = 'localhost:9199';
          final testEnv = <String, String>{
            Environment.firebaseStorageEmulatorHost: emulatorHost,
          };

          await runZoned(zoneValues: {envSymbol: testEnv}, () async {
            final testApp = FirebaseApp.initializeApp(
              name: 'dl-url-emulator-${DateTime.now().millisecondsSinceEpoch}',
              options: AppOptions(projectId: projectId, httpClient: mockClient),
            );
            addTearDown(() async => testApp.close());

            when(() => mockClient.get(any())).thenAnswer(
              (_) async => http.Response(
                jsonEncode({'downloadTokens': downloadToken}),
                200,
              ),
            );

            final storage = Storage.internal(testApp);
            final bucket = storage.bucket(bucketName);
            final url = await storage.getDownloadURL(bucket, 'file.txt');

            expect(url, startsWith('http://$emulatorHost/v0'));
            expect(url, contains('token=$downloadToken'));
          });
        },
      );

      test('hits the correct Firebase Storage REST endpoint', () async {
        // Clear emulator env var so we hit the production endpoint.
        await runZoned(zoneValues: {envSymbol: <String, String>{}}, () async {
          final storage = Storage.internal(app);
          final bucket = storage.bucket(bucketName);
          Uri? capturedUri;

          when(() => mockClient.get(any())).thenAnswer((invocation) async {
            capturedUri = invocation.positionalArguments[0] as Uri;
            return http.Response(
              jsonEncode({'downloadTokens': downloadToken}),
              200,
            );
          });

          await storage.getDownloadURL(bucket, objectName);

          expect(
            capturedUri.toString(),
            '$productionEndpoint/b/$bucketName/o/${Uri.encodeComponent(objectName)}',
          );
        });
      });
    });
  });
}
