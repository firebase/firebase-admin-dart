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

import 'dart:convert';

import 'package:google_cloud_storage/google_cloud_storage.dart' as gcs;
import 'package:googleapis_auth/googleapis_auth.dart' as googleapis_auth;
import 'package:meta/meta.dart';
import '../app.dart';
import '../utils/native_environment.dart';

part 'storage_exception.dart';

class Storage implements FirebaseService {
  Storage._(this.app) {
    final isEmulator = Environment.isStorageEmulatorEnabled();

    if (isEmulator) {
      final emulatorHost = Environment.getStorageEmulatorHost()!;

      if (RegExp('https?://').hasMatch(emulatorHost)) {
        throw FirebaseAppException(
          AppErrorCode.failedPrecondition,
          'FIREBASE_STORAGE_EMULATOR_HOST should not contain a protocol (http or https).',
        );
      }
      setNativeEnvironmentVariable('STORAGE_EMULATOR_HOST', emulatorHost);
    } else {
      // Ensure no emulator host leaks into production GCS client from a
      // previous emulator-mode Storage instance in the same process.
      unsetNativeEnvironmentVariable('STORAGE_EMULATOR_HOST');
    }
    _isEmulator = isEmulator;
  }

  @internal
  factory Storage.internal(FirebaseApp app) {
    return app.getOrInitService(FirebaseServiceType.storage.name, Storage._);
  }

  @override
  final FirebaseApp app;

  late final bool _isEmulator;

  gcs.Storage? _delegateOrNull;

  /// The underlying `google_cloud_storage` client.
  ///
  /// Created on first use rather than in the constructor: `gcs.Storage` starts
  /// resolving credentials as soon as it is constructed, so building it eagerly
  /// would make `app.storage()` alone perform an auth handshake.
  gcs.Storage get _delegate => _delegateOrNull ??= gcs.Storage(
    // Resolved here rather than left to `google_cloud_storage`: its own
    // discovery parks an un-awaited future that can fail as an unhandled async
    // error, and `projectId` takes a `String?`, so it cannot be guarded the
    // way [_appClient] is.
    projectId: app.resolveProjectIdSync(),
    // `google_cloud_storage` only falls back to an unauthenticated client
    // when `client` is null, which is what the emulator needs.
    client: _isEmulator ? null : _appClient(),
  );

  /// The app's authenticated client, with its errors marked as observed.
  ///
  /// `gcs.Storage` stores this future in a field without awaiting it, so an
  /// auth failure would otherwise be reported as an unhandled async error even
  /// when no storage operation is ever performed. Listeners added later — by
  /// the delegate, when it actually makes a request — still receive the error.
  Future<googleapis_auth.AuthClient> _appClient() {
    final client = app.client;
    client.ignore();
    return client;
  }

  gcs.Bucket bucket([String? name]) {
    final bucketName = name ?? app.options.storageBucket;
    if (bucketName == null || bucketName.isEmpty) {
      throw FirebaseAppException(
        AppErrorCode.failedPrecondition,
        'Bucket name not specified or invalid. Specify a valid bucket name via the '
        'storageBucket option when initializing the app, or specify the bucket name '
        'explicitly when calling the bucket() method.',
      );
    }

    return _delegate.bucket(bucketName);
  }

  /// Returns a long-lived download URL for the given object.
  ///
  /// The URL is signed with a download token from the Firebase Storage REST
  /// API, making it suitable for sharing with end-users. The token must exist
  /// on the object — if none is present, create one in the Firebase Console or
  /// via the Firebase Storage REST API first.
  ///
  /// Example:
  /// ```dart
  /// final storage = app.storage();
  /// final bucket = storage.bucket('my-bucket.appspot.com');
  /// final url = await storage.getDownloadURL(bucket, 'images/photo.jpg');
  /// ```
  Future<String> getDownloadURL(gcs.Bucket bucket, String objectName) async {
    final emulatorHost = Environment.getStorageEmulatorHost();
    final endpoint = emulatorHost != null
        ? 'http://$emulatorHost/v0'
        : 'https://firebasestorage.googleapis.com/v0';

    final encodedName = Uri.encodeComponent(objectName);
    final uri = Uri.parse('$endpoint/b/${bucket.name}/o/$encodedName');

    final client = await app.client;
    final response = await client.get(uri);

    if (response.statusCode != 200) {
      throw FirebaseStorageAdminException(
        StorageClientErrorCode.internalError,
        'Failed to retrieve object metadata. Status: ${response.statusCode}.',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final downloadTokens = json['downloadTokens'] as String?;

    if (downloadTokens == null || downloadTokens.isEmpty) {
      throw FirebaseStorageAdminException(
        StorageClientErrorCode.noDownloadToken,
      );
    }

    final token = downloadTokens.split(',').first;
    return '$endpoint/b/${bucket.name}/o/$encodedName?alt=media&token=$token';
  }

  bool _isDeleted = false;

  @override
  Future<void> delete() async {
    if (_isDeleted) return;
    _isDeleted = true;
    _delegateOrNull?.close();
  }
}
