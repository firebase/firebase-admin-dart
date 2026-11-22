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

/// Messaging server to client enum error codes.
@internal
const messagingServerToClientCode = {
  /* GENERIC ERRORS */
  // Generic invalid message parameter provided.
  'InvalidParameters': MessagingClientErrorCode.invalidArgument,
  // Mismatched sender ID.
  'MismatchSenderId': MessagingClientErrorCode.mismatchedCredential,
  // FCM server unavailable.
  'Unavailable': MessagingClientErrorCode.serverUnavailable,
  // FCM server internal error.
  'InternalServerError': MessagingClientErrorCode.internalError,

  /* SEND ERRORS */
  // Invalid registration token format.
  'InvalidRegistration': MessagingClientErrorCode.invalidRegistrationToken,
  // Registration token is not registered.
  'NotRegistered': MessagingClientErrorCode.registrationTokenNotRegistered,
  // Registration token does not match restricted package name.
  'InvalidPackageName': MessagingClientErrorCode.invalidPackageName,
  // Message payload size limit exceeded.
  'MessageTooBig': MessagingClientErrorCode.payloadSizeLimitExceeded,
  // Invalid key in the data message payload.
  'InvalidDataKey': MessagingClientErrorCode.invalidDataPayloadKey,
  // Invalid time to live option.
  'InvalidTtl': MessagingClientErrorCode.invalidOptions,
  // Device message rate exceeded.
  'DeviceMessageRateExceeded':
      MessagingClientErrorCode.deviceMessageRateExceeded,
  // Topics message rate exceeded.
  'TopicsMessageRateExceeded':
      MessagingClientErrorCode.topicsMessageRateExceeded,
  // Invalid APNs credentials.
  'InvalidApnsCredential': MessagingClientErrorCode.thirdPartyAuthError,

  /* FCM v1 canonical error codes */
  'NOT_FOUND': MessagingClientErrorCode.registrationTokenNotRegistered,
  'PERMISSION_DENIED': MessagingClientErrorCode.mismatchedCredential,
  'RESOURCE_EXHAUSTED': MessagingClientErrorCode.messageRateExceeded,
  'UNAUTHENTICATED': MessagingClientErrorCode.thirdPartyAuthError,

  /* FCM v1 new error codes */
  'APNS_AUTH_ERROR': MessagingClientErrorCode.thirdPartyAuthError,
  'INTERNAL': MessagingClientErrorCode.internalError,
  'INVALID_ARGUMENT': MessagingClientErrorCode.invalidArgument,
  'QUOTA_EXCEEDED': MessagingClientErrorCode.messageRateExceeded,
  'SENDER_ID_MISMATCH': MessagingClientErrorCode.mismatchedCredential,
  'THIRD_PARTY_AUTH_ERROR': MessagingClientErrorCode.thirdPartyAuthError,
  'UNAVAILABLE': MessagingClientErrorCode.serverUnavailable,
  'UNREGISTERED': MessagingClientErrorCode.registrationTokenNotRegistered,
  'UNSPECIFIED_ERROR': MessagingClientErrorCode.unknownError,
};

class FirebaseMessagingAdminException extends FirebaseAdminException
    implements Exception {
  FirebaseMessagingAdminException(this.errorCode, [String? message])
    : super(
        FirebaseServiceType.messaging.name,
        errorCode.code,
        message ?? errorCode.message,
      );

  @internal
  factory FirebaseMessagingAdminException.fromServerError({
    required String serverErrorCode,
    String? message,
    Object? rawServerResponse,
  }) {
    // If not found, default to unknown error.
    final error =
        messagingServerToClientCode[serverErrorCode] ??
        MessagingClientErrorCode.unknownError;
    var effectiveMessage = message ?? error.message;

    if (error == MessagingClientErrorCode.unknownError &&
        rawServerResponse != null) {
      try {
        effectiveMessage +=
            ' Raw server response: "${jsonEncode(rawServerResponse)}"';
      } catch (e) {
        // Ignore JSON parsing error.
      }
    }

    return FirebaseMessagingAdminException(error, effectiveMessage);
  }

  final MessagingClientErrorCode errorCode;

  @override
  String toString() => 'FirebaseMessagingAdminException: $code: $message';
}

/// Messaging client error codes and their default messages.
enum MessagingClientErrorCode {
  invalidArgument(
    code: 'invalid-argument',
    message: 'Invalid argument provided.',
  ),
  invalidRecipient(
    code: 'invalid-recipient',
    message: 'Invalid message recipient provided.',
  ),
  invalidPayload(
    code: 'invalid-payload',
    message: 'Invalid message payload provided.',
  ),
  invalidDataPayloadKey(
    code: 'invalid-data-payload-key',
    message:
        'The data message payload contains an invalid key. See the reference documentation '
        'for the DataMessagePayload type for restricted keys.',
  ),
  payloadSizeLimitExceeded(
    code: 'payload-size-limit-exceeded',
    message:
        'The provided message payload exceeds the FCM size limits. See the error documentation '
        'for more details.',
  ),
  invalidOptions(
    code: 'invalid-options',
    message: 'Invalid message options provided.',
  ),
  invalidRegistrationToken(
    code: 'invalid-registration-token',
    message:
        'Invalid registration token provided. Make sure it matches the registration token '
        'the client app receives from registering with FCM.',
  ),
  registrationTokenNotRegistered(
    code: 'registration-token-not-registered',
    message:
        'The provided registration token is not registered. A previously valid registration '
        'token can be unregistered for a variety of reasons. See the error documentation for more '
        'details. Remove this registration token and stop using it to send messages.',
  ),
  mismatchedCredential(
    code: 'mismatched-credential',
    message:
        'The credential used to authenticate this SDK does not have permission to send '
        'messages to the device corresponding to the provided registration token. Make sure the '
        'credential and registration token both belong to the same Firebase project.',
  ),
  invalidPackageName(
    code: 'invalid-package-name',
    message:
        'The message was addressed to a registration token whose package name does not match '
        'the provided "restrictedPackageName" option.',
  ),
  deviceMessageRateExceeded(
    code: 'device-message-rate-exceeded',
    message:
        'The rate of messages to a particular device is too high. Reduce the number of '
        'messages sent to this device and do not immediately retry sending to this device.',
  ),
  topicsMessageRateExceeded(
    code: 'topics-message-rate-exceeded',
    message:
        'The rate of messages to subscribers to a particular topic is too high. Reduce the '
        'number of messages sent for this topic, and do not immediately retry sending to this topic.',
  ),
  messageRateExceeded(
    code: 'message-rate-exceeded',
    message: 'Sending limit exceeded for the message target.',
  ),
  thirdPartyAuthError(
    code: 'third-party-auth-error',
    message:
        'A message targeted to an iOS device could not be sent because the required APNs '
        'SSL certificate was not uploaded or has expired. Check the validity of your development '
        'and production certificates.',
  ),
  tooManyTopics(
    code: 'too-many-topics',
    message:
        'The maximum number of topics the provided registration token can be subscribed to '
        'has been exceeded.',
  ),
  authenticationError(
    code: 'authentication-error',
    message:
        'An error occurred when trying to authenticate to the FCM servers. Make sure the '
        'credential used to authenticate this SDK has the proper permissions. See '
        'https://firebase.google.com/docs/admin/setup for setup instructions.',
  ),
  serverUnavailable(
    code: 'server-unavailable',
    message:
        'The FCM server could not process the request in time. See the error documentation '
        'for more details.',
  ),
  internalError(
    code: 'internal-error',
    message: 'An internal error has occurred. Please retry the request.',
  ),
  unknownError(
    code: 'unknown-error',
    message: 'An unknown server error was returned.',
  );

  const MessagingClientErrorCode({required this.code, required this.message});

  /// The error code.
  final String code;

  /// The default error message.
  final String message;
}

/// Extracts error code from the given response object.
String? _getErrorCode(Object? response) {
  if (response is! Map || !response.containsKey('error')) return null;

  final error = response['error'];
  if (error is String) return error;

  error as Map;

  final details = error['details'];
  if (details is List) {
    const fcmErrorType = 'type.googleapis.com/google.firebase.fcm.v1.FcmError';
    for (final element in details) {
      if (element is Map && element['@type'] == fcmErrorType) {
        return element['errorCode'] as String?;
      }
    }
  }

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

/// Creates a new FirebaseMessagingError by extracting the error code, message and other relevant
/// details from an HTTP error response.
FirebaseMessagingAdminException _createFirebaseError({
  required String body,
  required int? statusCode,
  required bool isJson,
}) {
  if (isJson) {
    // For JSON responses, map the server response to a client-side error.

    final json = jsonDecode(body);
    final errorCode = _getErrorCode(json)!;
    final errorMessage = _getErrorMessage(json);

    return FirebaseMessagingAdminException.fromServerError(
      serverErrorCode: errorCode,
      message: errorMessage,
      rawServerResponse: json,
    );
  }

  // Non-JSON response
  MessagingClientErrorCode error;
  switch (statusCode) {
    case 400:
      error = MessagingClientErrorCode.invalidArgument;
    case 401:
    case 403:
      error = MessagingClientErrorCode.authenticationError;
    case 500:
      error = MessagingClientErrorCode.internalError;
    case 503:
      error = MessagingClientErrorCode.serverUnavailable;
    default:
      // Treat non-JSON responses with unexpected status codes as unknown errors.
      error = MessagingClientErrorCode.unknownError;
  }

  return FirebaseMessagingAdminException(
    error,
    '${error.message} Raw server response: "$body". Status code: '
    '$statusCode.',
  );
}

Future<T> _fmcGuard<T>(FutureOr<T> Function() fn) async {
  try {
    final value = fn();

    if (value is T) return value;

    return await value.catchError(_handleException);
  } catch (error, stackTrace) {
    _handleException(error, stackTrace);
  }
}

/// Converts a Exception to a FirebaseAdminException.
Never _handleException(Object exception, StackTrace stackTrace) {
  if (exception is fmc1.DetailedApiRequestError) {
    Error.throwWithStackTrace(
      _createFirebaseError(
        statusCode: exception.status,
        body: switch (exception.jsonResponse) {
          null => '',
          final json => jsonEncode(json),
        },
        isJson: exception.jsonResponse != null,
      ),
      stackTrace,
    );
  }

  Error.throwWithStackTrace(exception, stackTrace);
}
