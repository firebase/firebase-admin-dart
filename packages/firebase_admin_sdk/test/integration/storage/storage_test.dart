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

import 'dart:typed_data';

import 'package:firebase_admin_sdk/src/app.dart';
import 'package:google_cloud_storage/google_cloud_storage.dart' as gcs;
import 'package:test/test.dart';

import '../../fixtures/helpers.dart';

/// Integration tests for Storage wrapper.
///
/// These tests require the Firebase Storage emulator to be running.
/// Start it with: firebase emulators:start --only storage
///
/// Or run tests with: firebase emulators:exec "dart test test/storage/storage_integration_test.dart"
void main() {
  group(
    'Storage Integration Tests',
    () {
      late FirebaseApp app;
      late FirebaseApp appWithBucket;
      const testBucketName = 'dart-firebase-admin.firebasestorage.app';
      ({String bucketName, String objectName})? currentObject;

      setUpAll(() {
        // Create app without default bucket
        app = FirebaseApp.initializeApp(
          name: 'storage-integration-test',
          options: const AppOptions(projectId: projectId),
        );

        // Create app with default bucket configured
        appWithBucket = FirebaseApp.initializeApp(
          name: 'storage-integration-test-with-bucket',
          options: const AppOptions(
            projectId: projectId,
            storageBucket: testBucketName,
          ),
        );
      });

      tearDownAll(() async {
        await app.close();
        await appWithBucket.close();
      });

      tearDown(() async {
        // Clean up any test objects created during tests
        if (currentObject != null) {
          final obj = currentObject!;
          currentObject = null;
          try {
            final storage = app.storage();
            await storage
                .bucket(obj.bucketName)
                .storage
                .deleteObject(obj.bucketName, obj.objectName);
          } catch (e) {
            // Ignore errors if object doesn't exist
          }
        }
      });

      group('Storage initialization', () {
        test('should initialize properly in emulator mode', () {
          final storage = app.storage();
          expect(storage, isNotNull);
          expect(storage.app, same(app));
        });

        test('should work with app that has default bucket configured', () {
          final storage = appWithBucket.storage();
          expect(storage, isNotNull);
          expect(storage.app, same(appWithBucket));
        });
      });

      group('bucket()', () {
        test(
          'should return a handle to the default bucket and it works',
          () async {
            final storage = appWithBucket.storage();
            final bucket = storage.bucket();

            expect(bucket, isA<gcs.Bucket>());
            expect(bucket.name, testBucketName);

            // Verify bucket works by uploading, downloading, and deleting a file
            await verifyBucket(bucket, 'storage().bucket()');
          },
        );

        test(
          'should return a handle to a specified bucket and it works',
          () async {
            final storage = app.storage();
            final bucket = storage.bucket(testBucketName);

            expect(bucket, isA<gcs.Bucket>());
            expect(bucket.name, testBucketName);

            // Verify bucket works by uploading, downloading, and deleting a file
            await verifyBucket(bucket, 'storage().bucket(string)');
          },
        );

        test('should handle multiple buckets', () async {
          final storage = app.storage();
          final bucket1 = storage.bucket(testBucketName);
          final bucket2 = storage.bucket('$testBucketName-2');

          expect(bucket1.name, testBucketName);
          expect(bucket2.name, '$testBucketName-2');
        });
      });

      // TODO: Re-enable once google_cloud_storage exposes an exists() API or
      // equivalent. bucket.metadata() could be used but there is no explicit
      // exists() method in the new package.
      // group('bucket existence', () {
      //   test(
      //     'should return a handle for non-existing bucket which can be queried',
      //     () async {
      //       final storage = app.storage();
      //       final bucket = storage.bucket('non-existing-bucket-test');
      //
      //       expect(bucket, isA<gcs.Bucket>());
      //       expect(bucket.name, 'non-existing-bucket-test');
      //
      //       final exists = await bucket.exists();
      //       expect(exists, isFalse);
      //     },
      //   );
      // });

      group('object operations', () {
        test('should upload and download an object successfully', () async {
          final storage = app.storage();
          final bucket = storage.bucket(testBucketName);
          final objectName =
              'test-upload-${DateTime.now().millisecondsSinceEpoch}.txt';
          currentObject = (bucketName: testBucketName, objectName: objectName);

          const testContent = 'Hello from Dart Firebase Admin!';
          final contentBytes = Uint8List.fromList(testContent.codeUnits);

          // Upload object
          await bucket.storage.uploadObject(
            bucket.name,
            objectName,
            contentBytes,
            metadata: gcs.ObjectMetadata(contentType: 'text/plain'),
          );

          // TODO: Re-enable once google_cloud_storage exposes an exists() API.
          // final exists = await file.exists();
          // expect(exists, isTrue);

          // Download and verify content
          final downloaded = await bucket.storage.downloadObject(
            bucket.name,
            objectName,
          );
          final downloadedContent = String.fromCharCodes(downloaded);
          expect(downloadedContent, testContent);
        });

        test('should handle object metadata', () async {
          final storage = app.storage();
          final bucket = storage.bucket(testBucketName);
          final objectName =
              'test-metadata-${DateTime.now().millisecondsSinceEpoch}.txt';
          currentObject = (bucketName: testBucketName, objectName: objectName);

          const testContent = 'Test content for metadata';
          final contentBytes = Uint8List.fromList(testContent.codeUnits);

          // Upload with custom metadata
          await bucket.storage.uploadObject(
            bucket.name,
            objectName,
            contentBytes,
            metadata: gcs.ObjectMetadata(
              contentType: 'text/plain',
              metadata: {'customKey': 'customValue'},
            ),
          );

          // Get metadata
          final metadata = await bucket.storage.objectMetadata(
            bucket.name,
            objectName,
          );
          expect(metadata.contentType, 'text/plain');
          expect(metadata.metadata?['customKey'], 'customValue');
          expect(metadata.name, objectName);
          expect(metadata.bucket, testBucketName);
        });

        test('should delete an object successfully', () async {
          final storage = app.storage();
          final bucket = storage.bucket(testBucketName);
          final objectName =
              'test-delete-${DateTime.now().millisecondsSinceEpoch}.txt';

          const testContent = 'To be deleted';
          final contentBytes = Uint8List.fromList(testContent.codeUnits);

          // Upload object
          await bucket.storage.uploadObject(
            bucket.name,
            objectName,
            contentBytes,
            metadata: gcs.ObjectMetadata(contentType: 'text/plain'),
          );

          // TODO: Re-enable once google_cloud_storage exposes an exists() API.
          // var exists = await file.exists();
          // expect(exists, isTrue);

          // Delete object
          await bucket.storage.deleteObject(bucket.name, objectName);

          // TODO: Re-enable once google_cloud_storage exposes an exists() API.
          // exists = await file.exists();
          // expect(exists, isFalse);
        });
      });

      group('emulator mode verification', () {
        test('should be using emulator host', () {
          expect(Environment.isStorageEmulatorEnabled(), isTrue);
          expect(Environment.getStorageEmulatorHost(), isNotNull);
        });

        test('Storage should work correctly in emulator mode', () async {
          final storage = app.storage();
          final bucket = storage.bucket(testBucketName);

          // Simple round-trip test
          final objectName =
              'emulator-test-${DateTime.now().millisecondsSinceEpoch}.txt';
          currentObject = (bucketName: testBucketName, objectName: objectName);

          const content = 'Emulator test';
          await bucket.storage.uploadObject(
            bucket.name,
            objectName,
            Uint8List.fromList(content.codeUnits),
            metadata: gcs.ObjectMetadata(contentType: 'text/plain'),
          );

          final downloaded = await bucket.storage.downloadObject(
            bucket.name,
            objectName,
          );
          expect(String.fromCharCodes(downloaded), content);
        });
      });
    },
    skip: Environment.isStorageEmulatorEnabled()
        ? false
        : 'Skipping Storage integration tests. Set FIREBASE_STORAGE_EMULATOR_HOST'
              ' environment variable to run these tests.',
  );
}

/// Helper function to verify a bucket works by performing
/// upload/download/delete operations.
Future<void> verifyBucket(gcs.Bucket bucket, String testName) async {
  final expected = 'Hello World: $testName';
  final objectName = 'data_${DateTime.now().millisecondsSinceEpoch}.txt';

  // Upload
  await bucket.storage.uploadObject(
    bucket.name,
    objectName,
    Uint8List.fromList(expected.codeUnits),
    metadata: gcs.ObjectMetadata(contentType: 'text/plain'),
  );

  // Download and verify
  final downloaded = await bucket.storage.downloadObject(
    bucket.name,
    objectName,
  );
  final content = String.fromCharCodes(downloaded);
  expect(content, expected, reason: 'Downloaded content should match uploaded');

  // Delete
  await bucket.storage.deleteObject(bucket.name, objectName);

  // TODO: Re-enable once google_cloud_storage exposes an exists() API.
  // final exists = await file.exists();
  // expect(exists, isFalse, reason: 'Object should not exist after deletion');
}
