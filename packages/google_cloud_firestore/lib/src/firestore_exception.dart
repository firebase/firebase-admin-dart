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

import 'package:google_cloud_rpc/exceptions.dart';
import 'package:meta/meta.dart';

import 'status_code.dart';

/// Extracts error code from error response.
String? _getErrorCode(Object? response) {
  if (response is! Map || !response.containsKey('error')) return null;

  final error = response['error'];
  if (error is String) return error;

  error as Map;

  if (error.containsKey('status')) {
    return error['status'] as String?;
  }

  return error['message'] as String?;
}

/// Extracts error message from the given response object.
String? _getErrorMessage(Object? response) {
  switch (response) {
    case <Object?, Object?>{'error': {'message': final String? message}}:
      return message;
  }

  return null;
}

/// Creates a new FirestoreError by extracting the error code, message and other relevant
/// details from an HTTP error response.
FirestoreException _createFirestoreError({
  required String body,
  required int? statusCode,
  required bool isJson,
}) {
  if (isJson) {
    // For JSON responses, map the server response to a client-side error.
    final json = jsonDecode(body);
    final errorCode = _getErrorCode(json)!;
    final errorMessage = _getErrorMessage(json);

    return FirestoreException.fromServerError(
      serverErrorCode: errorCode,
      message: errorMessage,
      rawServerResponse: json,
    );
  }

  // Non-JSON response
  FirestoreClientErrorCode error;
  switch (statusCode) {
    case 400:
      error = FirestoreClientErrorCode.invalidArgument;
    case 401:
    case 403:
      error = FirestoreClientErrorCode.unauthenticated;
    case 500:
      error = FirestoreClientErrorCode.internal;
    case 503:
      error = FirestoreClientErrorCode.unavailable;
    case 409: // HTTP Mapping: 409 Conflict
      error = FirestoreClientErrorCode.aborted;
    default:
      // Treat non-JSON responses with unexpected status codes as unknown errors.
      error = FirestoreClientErrorCode.unknown;
  }

  return FirestoreException(
    error,
    '${error.message} Raw server response: "$body". Status code: '
    '$statusCode.',
  );
}

/// A generic guard wrapper for API calls to handle exceptions.
@internal
R firestoreGuard<R>(R Function() cb) {
  try {
    final value = cb();

    if (value is Future) {
      return value.catchError(handleFirestoreException) as R;
    }

    return value;
  } catch (error, stackTrace) {
    handleFirestoreException(error, stackTrace);
  }
}

/// Converts an Exception to a FirestoreError.
@internal
Never handleFirestoreException(Object exception, StackTrace stackTrace) {
  if (exception is ServiceException) {
    Error.throwWithStackTrace(
      _createFirestoreError(
        statusCode: exception.statusCode,
        body: exception.responseBody ?? '',
        isJson: exception.status != null,
      ),
      stackTrace,
    );
  }

  Error.throwWithStackTrace(exception, stackTrace);
}

/// Exception thrown by Firestore operations.
class FirestoreException implements Exception {
  FirestoreException(this.errorCode, [String? message])
    : message = message ?? errorCode.message;

  @internal
  factory FirestoreException.fromServerError({
    required String serverErrorCode,
    String? message,
    Object? rawServerResponse,
  }) {
    // If not found, default to unknown error.
    final error =
        firestoreServerToClientCode[serverErrorCode] ??
        FirestoreClientErrorCode.unknown;
    var effectiveMessage = message ?? error.message;

    if (error == FirestoreClientErrorCode.unknown &&
        rawServerResponse != null) {
      try {
        effectiveMessage +=
            ' Raw server response: "${jsonEncode(rawServerResponse)}"';
      } catch (e) {
        // Ignore JSON parsing error.
      }
    }

    return FirestoreException(error, effectiveMessage);
  }

  final FirestoreClientErrorCode errorCode;
  final String message;

  String get code => errorCode.code;

  @override
  String toString() => 'FirestoreError: $code: $message';
}

/// Firestore server to client enum error codes.
/// https://cloud.google.com/firestore/docs/use-rest-api#error_codes
@internal
const firestoreServerToClientCode = {
  'ABORTED': FirestoreClientErrorCode.aborted,
  'ALREADY_EXISTS': FirestoreClientErrorCode.alreadyExists,
  'CANCELLED': FirestoreClientErrorCode.cancelled,
  'DATA_LOSS': FirestoreClientErrorCode.dataLoss,
  'DEADLINE_EXCEEDED': FirestoreClientErrorCode.deadlineExceeded,
  'FAILED_PRECONDITION': FirestoreClientErrorCode.failedPrecondition,
  'INTERNAL': FirestoreClientErrorCode.internal,
  'INVALID_ARGUMENT': FirestoreClientErrorCode.invalidArgument,
  'NOT_FOUND': FirestoreClientErrorCode.notFound,
  'OK': FirestoreClientErrorCode.ok,
  'OUT_OF_RANGE': FirestoreClientErrorCode.outOfRange,
  'PERMISSION_DENIED': FirestoreClientErrorCode.permissionDenied,
  'RESOURCE_EXHAUSTED': FirestoreClientErrorCode.resourceExhausted,
  'UNAUTHENTICATED': FirestoreClientErrorCode.unauthenticated,
  'UNAVAILABLE': FirestoreClientErrorCode.unavailable,
  'UNIMPLEMENTED': FirestoreClientErrorCode.unimplemented,
  'UNKNOWN': FirestoreClientErrorCode.unknown,
};

/// Firestore client error codes and their default messages.
enum FirestoreClientErrorCode {
  aborted(
    statusCode: StatusCode.aborted,
    code: 'aborted',
    message:
        'The operation was aborted, typically due to a concurrency issue like transaction aborts, etc.',
  ),
  alreadyExists(
    statusCode: StatusCode.alreadyExists,
    code: 'already-exists',
    message: 'Some document that we attempted to create already exists.',
  ),
  cancelled(
    statusCode: StatusCode.cancelled,
    code: 'cancelled',
    message: 'The operation was cancelled (typically by the caller).',
  ),
  dataLoss(
    statusCode: StatusCode.dataLoss,
    code: 'data-loss',
    message: 'Unrecoverable data loss or corruption.',
  ),
  deadlineExceeded(
    statusCode: StatusCode.deadlineExceeded,
    code: 'deadline_exceeded',
    message: 'Deadline expired before operation could complete.',
  ),
  failedPrecondition(
    statusCode: StatusCode.failedPrecondition,
    code: 'failed_precondition',
    message:
        "Operation was rejected because the system is not in a state required for the operation's execution.",
  ),
  internal(
    statusCode: StatusCode.internal,
    code: 'internal',
    message: 'Internal errors.',
  ),
  invalidArgument(
    statusCode: StatusCode.invalidArgument,
    code: 'invalid_argument',
    message: 'Client specified an invalid argument.',
  ),
  notFound(
    statusCode: StatusCode.notFound,
    code: 'not_found',
    message: 'Some requested document was not found.',
  ),
  ok(
    statusCode: StatusCode.ok,
    code: 'ok',
    message: 'The operation completed successfully.',
  ),
  outOfRange(
    statusCode: StatusCode.outOfRange,
    code: 'out_of_range',
    message: 'Operation was attempted past the valid range.',
  ),
  permissionDenied(
    statusCode: StatusCode.permissionDenied,
    code: 'permission_denied',
    message:
        'The caller does not have permission to execute the specified operation.',
  ),
  resourceExhausted(
    statusCode: StatusCode.resourceExhausted,
    code: 'resource_exhausted',
    message:
        'Some resource has been exhausted, perhaps a per-user quota, or perhaps the entire file system is out of space.',
  ),
  unauthenticated(
    statusCode: StatusCode.unauthenticated,
    code: 'unauthenticated',
    message:
        'The request does not have valid authentication credentials for the operation.',
  ),
  unavailable(
    statusCode: StatusCode.unavailable,
    code: 'unavailable',
    message: 'The service is currently unavailable.',
  ),
  unimplemented(
    statusCode: StatusCode.unimplemented,
    code: 'unimplemented',
    message: 'Operation is not implemented or not supported/enabled.',
  ),
  unknown(
    statusCode: StatusCode.unknown,
    code: 'unknown',
    message: 'Unknown error or an error from a different error domain.',
  );

  const FirestoreClientErrorCode({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final StatusCode statusCode;
  final String code;
  final String message;

  /// Maps a gRPC status code to the corresponding FirestoreClientErrorCode.
  static FirestoreClientErrorCode fromStatusCode(int code) {
    return values.firstWhere(
      (errorCode) => errorCode.statusCode.value == code,
      orElse: () => FirestoreClientErrorCode.unknown,
    );
  }
}
