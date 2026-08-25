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

part of '../app.dart';

/// HTTP client wrapper that adds Firebase and Google API client headers for usage tracking.
///
/// Wraps another HTTP client and injects:
/// - `X-Firebase-Client: fire-admin-dart/{version}`
/// - `X-Goog-Api-Client: gl-dart/{dartVersion} fire-admin/{version}`
/// into every outgoing request so Firebase backend services can identify the SDK.
@internal
class FirebaseUserAgentClient extends BaseClient
    implements googleapis_auth.AuthClient {
  FirebaseUserAgentClient(this._client);

  final googleapis_auth.AuthClient _client;

  @override
  googleapis_auth.AccessCredentials get credentials => _client.credentials;

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    for (final entry in firebaseUserAgentHeaders.entries) {
      final existing = request.headers[entry.key];
      if (existing == null) {
        request.headers[entry.key] = entry.value;
      } else if (entry.key.toLowerCase() == 'x-goog-api-client') {
        final tokens = existing.split(RegExp(r'\s+'));
        if (!tokens.contains(fireAdminApiClientTag)) {
          request.headers[entry.key] = '$existing $fireAdminApiClientTag';
        }
      } else {
        request.headers[entry.key] = entry.value;
      }
    }
    return _client.send(request);
  }

  @override
  void close() => _client.close();
}
