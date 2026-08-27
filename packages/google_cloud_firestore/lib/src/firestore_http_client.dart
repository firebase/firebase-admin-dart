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

import 'package:google_cloud/constants.dart' as google_cloud;
import 'package:google_cloud/google_cloud.dart' as google_cloud;
import 'package:google_cloud_firestore_v1/firestore.dart' as firestore_v1;
import 'package:googleapis_auth/auth_io.dart' as googleapis_auth;
import 'package:http/http.dart';
import 'package:meta/meta.dart';

import '../google_cloud_firestore.dart';
import 'environment.dart';
import 'firestore_exception.dart';

/// Internal HTTP request implementation that wraps a stream.
///
/// This is used by [EmulatorClient] to create modified requests with
/// updated headers while preserving the request body stream.
class _RequestImpl extends BaseRequest {
  _RequestImpl(super.method, super.url, [Stream<List<int>>? stream])
    : _stream = stream ?? const Stream.empty();

  final Stream<List<int>> _stream;

  @override
  ByteStream finalize() {
    super.finalize();
    return ByteStream(_stream);
  }
}

/// HTTP client wrapper that adds custom headers to every outgoing Firestore
/// request.
///
/// Used to attach [Settings.headers] (e.g. usage-tracking headers set by a
/// caller like the Firebase Admin SDK) without altering how the underlying
/// client authenticates requests.
///
/// Values are appended (space-joined) onto any existing header of the same
/// name rather than replacing it, since the transport layer
/// (`package:google_cloud_rpc`) already sets its own `X-Goog-Api-Client`
/// value identifying this library — matching the multi-token convention
/// that header uses (e.g. `gl-dart/3.9 gax/1.0 gccl/0.5 fire-admin/0.5`).
@internal
class FirestoreRequestClient extends BaseClient
    implements googleapis_auth.AuthClient {
  FirestoreRequestClient(this._client, this._headers);

  final googleapis_auth.AuthClient _client;
  final Map<String, String> _headers;

  @override
  googleapis_auth.AccessCredentials get credentials => _client.credentials;

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    for (final entry in _headers.entries) {
      final existing = request.headers[entry.key];
      request.headers[entry.key] = existing == null
          ? entry.value
          : '$existing ${entry.value}';
    }
    return _client.send(request);
  }

  @override
  void close() => _client.close();
}

/// HTTP client wrapper that adds Firebase emulator authentication.
///
/// This client wraps another HTTP client and automatically adds the
/// `Authorization: Bearer owner` header to all requests, which is required
/// when communicating with Firebase emulators (Auth, Firestore, etc.).
///
/// Firebase emulators expect this specific bearer token to grant full
/// admin privileges for local development and testing.
@internal
class EmulatorClient extends BaseClient implements googleapis_auth.AuthClient {
  EmulatorClient(this.client);

  final Client client;

  @override
  googleapis_auth.AccessCredentials get credentials =>
      throw UnimplementedError();

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final modifiedRequest = _RequestImpl(
      request.method,
      request.url,
      request.finalize(),
    );
    modifiedRequest.headers.addAll(request.headers);
    modifiedRequest.headers['Authorization'] = 'Bearer owner';

    return client.send(modifiedRequest);
  }

  @override
  void close() => client.close();
}

/// HTTP client wrapper for Firestore API operations.
///
/// Provides authenticated API access with automatic project ID discovery.
class FirestoreHttpClient {
  FirestoreHttpClient({required this.credential, required Settings settings})
    : _settings = settings;

  final Credential credential;
  final Settings _settings;

  String? _cachedProjectId;

  String? get cachedProjectId => _cachedProjectId;

  /// Synchronously resolves the project ID from environment variables or the
  /// credentials file, without any network I/O.
  ///
  /// Checks (in order): [cachedProjectId], Zone env ([envSymbol]),
  /// [Settings.environmentOverride], real environment variables, then the
  /// credentials file at `GOOGLE_APPLICATION_CREDENTIALS`.
  ///
  /// Returns `null` when only async strategies (gcloud CLI, metadata server)
  /// could succeed; those are handled by [_run] and cached in [cachedProjectId].
  String? getProjectId() {
    if (_cachedProjectId != null) return _cachedProjectId;

    final zoneEnv = Zone.current[envSymbol] as Map<String, String>?;
    String? discovered;

    if (zoneEnv != null) {
      for (final envKey in google_cloud.projectIdEnvironmentVariableOptions) {
        final value = zoneEnv[envKey];
        if (value != null) {
          discovered = value;
          break;
        }
      }
    } else {
      final envOverride = _settings.environmentOverride;
      if (envOverride != null) {
        for (final envKey in google_cloud.projectIdEnvironmentVariableOptions) {
          final value = envOverride[envKey];
          if (value != null) {
            discovered = value;
            break;
          }
        }
      } else {
        discovered =
            google_cloud.projectIdFromEnvironmentVariables() ??
            google_cloud.projectIdFromCredentialsFile();
      }
    }

    return discovered != null ? (_cachedProjectId = discovered) : null;
  }

  /// Gets the Firestore API host URL.
  ///
  /// `FIRESTORE_EMULATOR_HOST` takes precedence over [Settings.host], since it
  /// is the documented way to redirect the SDK at an emulator. Otherwise the
  /// scheme follows [Settings.ssl], which lets a custom [Settings.host] be
  /// reached over plain HTTP.
  @internal
  @visibleForTesting
  Uri get firestoreApiHost {
    final emulatorHost = Environment.getFirestoreEmulatorHost(
      _settings.environmentOverride,
    );

    if (emulatorHost != null) {
      return Uri.http(emulatorHost, '/');
    }

    final host = _settings.host ?? 'firestore.googleapis.com';
    return _settings.ssl ? Uri.https(host, '/') : Uri.http(host, '/');
  }

  /// Checks if the Firestore emulator is enabled via environment variable.
  bool get _isUsingEmulator =>
      Environment.isFirestoreEmulatorEnabled(_settings.environmentOverride);

  /// Lazy-initialized HTTP client that's cached for reuse.
  late final Future<googleapis_auth.AuthClient> _client = _createClient();

  /// Creates the appropriate HTTP client based on emulator configuration.
  Future<googleapis_auth.AuthClient> _createClient() async {
    final client = await _createBaseClient();

    final headers = _settings.headers;
    if (headers == null || headers.isEmpty) return client;

    return FirestoreRequestClient(client, Map.unmodifiable(headers));
  }

  Future<googleapis_auth.AuthClient> _createBaseClient() async {
    if (_isUsingEmulator) {
      // Emulator: Create unauthenticated client.
      return EmulatorClient(Client());
    }

    // Production: Create authenticated client.
    final serviceAccountCreds = credential.serviceAccountCredentials;
    if (serviceAccountCreds != null) {
      return googleapis_auth.clientViaServiceAccount(serviceAccountCreds, [
        'https://www.googleapis.com/auth/cloud-platform',
      ]);
    }

    // Fall back to Application Default Credentials
    return googleapis_auth.clientViaApplicationDefaultCredentials(
      scopes: ['https://www.googleapis.com/auth/cloud-platform'],
    );
  }

  Future<R> _run<R>(
    Future<R> Function(googleapis_auth.AuthClient client, String projectId) fn,
  ) async {
    final client = await _client;

    final projectId =
        getProjectId() ??
        _settings.projectId ??
        await google_cloud.computeProjectId();

    _cachedProjectId = projectId;

    return firestoreGuard(() => fn(client, projectId));
  }

  /// Executes a Firestore v1 API operation with automatic projectId injection.
  Future<R> v1<R>(
    Future<R> Function(firestore_v1.Firestore api, String projectId) fn,
  ) => _run(
    (client, projectId) => fn(
      firestore_v1.Firestore(client: client, endPoint: firestoreApiHost),
      projectId,
    ),
  );

  /// Closes the HTTP client and releases resources.
  Future<void> close() async {
    final client = await _client;
    client.close();
  }
}
