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

part of 'messaging.dart';

/// HTTP client for Firebase Cloud Messaging API operations.
///
/// Handles HTTP client management, googleapis API client creation,
/// path builders, and simple API operations.
/// Does not handle emulator routing as FCM has no emulator support.
class FirebaseMessagingHttpClient {
  FirebaseMessagingHttpClient(this.app);

  final FirebaseApp app;

  /// Gets the IID (Instance ID) API host for legacy topic management.
  String get iidApiHost => 'iid.googleapis.com';

  /// Gets the FCM API host for topic management.
  String get fcmHost => 'fcm.googleapis.com';

  /// Builds the parent resource path for FCM operations.
  String buildParent(String projectId) {
    return 'projects/$projectId';
  }

  Future<R> _run<R>(
    Future<R> Function(googleapis_auth.AuthClient client, String projectId) fn,
  ) async {
    final client = await app.client;
    final projectId = await app.getProjectId();
    return _fmcGuard(() => fn(client, projectId));
  }

  /// Executes an operation directly with the AuthClient and projectId.
  Future<R> withClient<R>(
    Future<R> Function(googleapis_auth.AuthClient client, String projectId) fn,
  ) => _run(fn);

  /// Executes a Messaging v1 API operation with automatic projectId injection.
  Future<R> v1<R>(
    Future<R> Function(fmc1.FirebaseCloudMessagingApi api, String projectId) fn,
  ) => _run(
    (client, projectId) =>
        fn(fmc1.FirebaseCloudMessagingApi(client), projectId),
  );

  /// Invokes the legacy FCM API with the provided request data.
  ///
  /// This is used for legacy FCM API operations that don't use googleapis.
  Future<Object?> invokeRequestHandler({
    required String host,
    required String path,
    Object? requestData,
  }) async {
    try {
      final client = await app.client;
      final response = await client.post(
        Uri.https(host, path),
        body: jsonEncode(requestData),
        headers: {
          'access_token_auth': 'true',
          'content-type': 'application/json',
        },
      );

      // Send non-JSON responses to the catch() below where they will be treated as errors.
      if (!response.isJson) {
        throw _HttpException(response);
      }

      final json = jsonDecode(response.body);

      // Check for backend errors in the response.
      final errorCode = _getErrorCode(json);
      if (errorCode != null) {
        throw _HttpException(response);
      }

      return json;
    } on _HttpException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        _createFirebaseError(
          body: error.response.body,
          statusCode: error.response.statusCode,
          isJson: error.response.isJson,
        ),
        stackTrace,
      );
    }
  }
}

extension on Response {
  bool get isJson =>
      headers['content-type']?.contains('application/json') ?? false;
}

class _HttpException implements Exception {
  _HttpException(this.response);

  final Response response;
}
