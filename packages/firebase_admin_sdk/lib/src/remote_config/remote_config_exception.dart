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

/// Mapping from Google API status codes to [RemoteConfigErrorCode] values.
@internal
const remoteConfigErrorCodeMapping = <String, RemoteConfigErrorCode>{
  'ABORTED': RemoteConfigErrorCode.aborted,
  'ALREADY_EXISTS': RemoteConfigErrorCode.alreadyExists,
  'INVALID_ARGUMENT': RemoteConfigErrorCode.invalidArgument,
  'INTERNAL': RemoteConfigErrorCode.internalError,
  'FAILED_PRECONDITION': RemoteConfigErrorCode.failedPrecondition,
  'NOT_FOUND': RemoteConfigErrorCode.notFound,
  'OUT_OF_RANGE': RemoteConfigErrorCode.outOfRange,
  'PERMISSION_DENIED': RemoteConfigErrorCode.permissionDenied,
  'RESOURCE_EXHAUSTED': RemoteConfigErrorCode.resourceExhausted,
  'UNAUTHENTICATED': RemoteConfigErrorCode.unauthenticated,
  'UNKNOWN': RemoteConfigErrorCode.unknownError,
};

/// Remote Config error code values.
enum RemoteConfigErrorCode {
  aborted('aborted'),
  alreadyExists('already-exists'),
  invalidArgument('invalid-argument'),
  internalError('internal-error'),
  failedPrecondition('failed-precondition'),
  notFound('not-found'),
  outOfRange('out-of-range'),
  permissionDenied('permission-denied'),
  resourceExhausted('resource-exhausted'),
  unauthenticated('unauthenticated'),
  unknownError('unknown-error');

  const RemoteConfigErrorCode(this.code);

  /// The string identifier for this error code.
  final String code;
}

/// Firebase Remote Config exception.
class FirebaseRemoteConfigException extends FirebaseAdminException
    implements Exception {
  FirebaseRemoteConfigException(this.errorCode, [String? message])
    : super(FirebaseServiceType.remoteConfig.name, errorCode.code, message);

  /// Builds an exception from a server error response.
  ///
  /// Inspects the JSON body for a structured error code and message; falls back
  /// to the HTTP status when the body is not parseable.
  @internal
  factory FirebaseRemoteConfigException.fromServerError({
    required int? statusCode,
    required String body,
    required bool isJson,
  }) {
    if (isJson) {
      try {
        final json = jsonDecode(body);
        final errorCode = _serverErrorCode(json);
        final message = _serverErrorMessage(json) ?? 'Server error.';
        final mapped = errorCode != null
            ? remoteConfigErrorCodeMapping[errorCode]
            : null;
        if (mapped != null) {
          return FirebaseRemoteConfigException(mapped, message);
        }
      } on FormatException {
        // fall through
      }
    }

    final byStatus = switch (statusCode) {
      400 => RemoteConfigErrorCode.invalidArgument,
      401 || 403 => RemoteConfigErrorCode.unauthenticated,
      404 => RemoteConfigErrorCode.notFound,
      409 => RemoteConfigErrorCode.alreadyExists,
      412 => RemoteConfigErrorCode.failedPrecondition,
      429 => RemoteConfigErrorCode.resourceExhausted,
      500 => RemoteConfigErrorCode.internalError,
      _ => RemoteConfigErrorCode.unknownError,
    };
    return FirebaseRemoteConfigException(
      byStatus,
      'Unexpected response with status: $statusCode and body: $body',
    );
  }

  /// The structured error code associated with this exception.
  final RemoteConfigErrorCode errorCode;

  @override
  String toString() => 'FirebaseRemoteConfigException: $code: $message';
}

String? _serverErrorCode(Object? response) {
  if (response is! Map || !response.containsKey('error')) return null;
  final error = response['error'];
  if (error is String) return error;
  if (error is Map) {
    if (error['status'] is String) return error['status'] as String;
    if (error['code'] is String) return error['code'] as String;
  }
  return null;
}

String? _serverErrorMessage(Object? response) {
  if (response is Map) {
    final error = response['error'];
    if (error is Map && error['message'] is String) {
      return error['message'] as String;
    }
  }
  return null;
}

/// Wraps the body of an async function so any thrown exception is rethrown as
/// a [FirebaseRemoteConfigException] when applicable.
Future<T> _rcGuard<T>(FutureOr<T> Function() fn) async {
  try {
    final value = fn();
    if (value is T) return value;
    return await value;
  } on FirebaseRemoteConfigException {
    rethrow;
  } catch (error, stackTrace) {
    Error.throwWithStackTrace(
      FirebaseRemoteConfigException(
        RemoteConfigErrorCode.unknownError,
        'Unexpected error: $error',
      ),
      stackTrace,
    );
  }
}
