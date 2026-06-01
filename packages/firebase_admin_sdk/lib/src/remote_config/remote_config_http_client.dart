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

part of 'remote_config.dart';

const _rcApiHost = 'firebaseremoteconfig.googleapis.com';

/// Required so the server returns the `ETag` response header.
///
/// See https://firebase.google.com/docs/remote-config/use-config-rest#etag_usage_and_forced_updates
const _rcDefaultHeaders = <String, String>{'Accept-Encoding': 'gzip'};

/// Result of a Remote Config HTTP call: parsed JSON body plus the response
/// `ETag` header (when present).
@internal
typedef RemoteConfigHttpResult = ({Map<String, Object?> body, String? etag});

/// Low-level HTTP client for the Remote Config REST API.
///
/// Wraps the authenticated client returned by [FirebaseApp] with REST-specific
/// path building, header injection, and error mapping. Higher-level
/// orchestration (validation, data-class conversion) lives in the request
/// handler.
class RemoteConfigHttpClient {
  RemoteConfigHttpClient(this.app);

  /// The owning Firebase app.
  final FirebaseApp app;

  String _basePath(String projectId) => '/v1/projects/$projectId';

  Future<R> _run<R>(
    Future<R> Function(googleapis_auth.AuthClient client, String projectId) fn,
  ) async {
    final client = await app.client;
    final projectId = await app.getProjectId();
    return _rcGuard(() => fn(client, projectId));
  }

  /// `GET /v1/projects/{projectId}/remoteConfig[?versionNumber=N]`
  Future<RemoteConfigHttpResult> getTemplate({String? versionNumber}) {
    return _run((client, projectId) async {
      final query = <String, String>{'versionNumber': ?versionNumber};
      final uri = Uri.https(
        _rcApiHost,
        '${_basePath(projectId)}/remoteConfig',
        query.isEmpty ? null : query,
      );
      return _send(client, 'GET', uri);
    });
  }

  /// `PUT /v1/projects/{projectId}/remoteConfig[?validate_only=true]`
  ///
  /// [etag] is sent as the `If-Match` header (or `*` to force).
  Future<RemoteConfigHttpResult> publishTemplate({
    required Map<String, Object?> body,
    required String etag,
    bool validateOnly = false,
  }) {
    return _run((client, projectId) async {
      final uri = Uri.https(
        _rcApiHost,
        '${_basePath(projectId)}/remoteConfig',
        validateOnly ? const {'validate_only': 'true'} : null,
      );
      return _send(
        client,
        'PUT',
        uri,
        body: body,
        extraHeaders: <String, String>{'If-Match': etag},
      );
    });
  }

  /// `POST /v1/projects/{projectId}/remoteConfig:rollback`
  Future<RemoteConfigHttpResult> rollback(String versionNumber) {
    return _run((client, projectId) async {
      final uri = Uri.https(
        _rcApiHost,
        '${_basePath(projectId)}/remoteConfig:rollback',
      );
      return _send(
        client,
        'POST',
        uri,
        body: <String, Object?>{'versionNumber': versionNumber},
      );
    });
  }

  /// `GET /v1/projects/{projectId}/remoteConfig:listVersions?...`
  Future<Map<String, Object?>> listVersions({
    int? pageSize,
    String? pageToken,
    String? endVersionNumber,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return _run((client, projectId) async {
      final query = <String, String>{
        'pageSize': ?pageSize?.toString(),
        'pageToken': ?pageToken,
        'endVersionNumber': ?endVersionNumber,
        'startTime': ?startTime?.toUtc().toIso8601String(),
        'endTime': ?endTime?.toUtc().toIso8601String(),
      };
      final uri = Uri.https(
        _rcApiHost,
        '${_basePath(projectId)}/remoteConfig:listVersions',
        query.isEmpty ? null : query,
      );
      final result = await _send(client, 'GET', uri);
      return result.body;
    });
  }

  /// `GET /v1/projects/{projectId}/namespaces/firebase-server/serverRemoteConfig`
  Future<RemoteConfigHttpResult> getServerTemplate() {
    return _run((client, projectId) async {
      final uri = Uri.https(
        _rcApiHost,
        '${_basePath(projectId)}/namespaces/firebase-server/serverRemoteConfig',
      );
      return _send(client, 'GET', uri);
    });
  }

  Future<RemoteConfigHttpResult> _send(
    googleapis_auth.AuthClient client,
    String method,
    Uri uri, {
    Map<String, Object?>? body,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = <String, String>{
      ..._rcDefaultHeaders,
      if (body != null) 'Content-Type': 'application/json',
      ...?extraHeaders,
    };
    final encodedBody = body == null ? null : jsonEncode(body);

    final Response response;
    switch (method) {
      case 'GET':
        response = await client.get(uri, headers: headers);
      case 'POST':
        response = await client.post(uri, headers: headers, body: encodedBody);
      case 'PUT':
        response = await client.put(uri, headers: headers, body: encodedBody);
      default:
        throw StateError('Unsupported HTTP method: $method');
    }

    final etag = response.headers['etag'];
    final status = response.statusCode;

    if (status < 200 || status >= 300) {
      final isJson = (response.headers['content-type'] ?? '').contains(
        'application/json',
      );
      throw FirebaseRemoteConfigException.fromServerError(
        statusCode: status,
        body: response.body,
        isJson: isJson,
      );
    }

    if (response.body.isEmpty) {
      return (body: const <String, Object?>{}, etag: etag);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.unknownError,
        'Expected JSON object in response body, got ${decoded.runtimeType}.',
      );
    }
    return (body: decoded, etag: etag);
  }
}
