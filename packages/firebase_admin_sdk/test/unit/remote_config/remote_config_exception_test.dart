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

import 'package:firebase_admin_sdk/src/remote_config/remote_config.dart';
import 'package:test/test.dart';

void main() {
  group('FirebaseRemoteConfigException', () {
    test('exposes the structured code with the service prefix', () {
      final exception = FirebaseRemoteConfigException(
        RemoteConfigErrorCode.invalidArgument,
        'bad input',
      );
      expect(exception.errorCode, RemoteConfigErrorCode.invalidArgument);
      // Parent class composes code as "service/code", and the
      // FirebaseServiceType name for Remote Config is "remote-config".
      expect(exception.code, 'remote-config/invalid-argument');
      expect(exception.message, 'bad input');
      expect(exception.toString(), contains('remote-config/invalid-argument'));
    });

    test('maps known server status codes via remoteConfigErrorCodeMapping', () {
      const expected = <String, RemoteConfigErrorCode>{
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
      expect(remoteConfigErrorCodeMapping, expected);
    });

    test('fromServerError parses a structured JSON error', () {
      const body = '''{
        "error": {
          "code": 400,
          "message": "Invalid template version.",
          "status": "INVALID_ARGUMENT"
        }
      }''';
      final ex = FirebaseRemoteConfigException.fromServerError(
        statusCode: 400,
        body: body,
        isJson: true,
      );
      expect(ex.errorCode, RemoteConfigErrorCode.invalidArgument);
      expect(ex.message, 'Invalid template version.');
    });

    test(
      'fromServerError falls back to status when body lacks structured code',
      () {
        final byStatus = <int, RemoteConfigErrorCode>{
          400: RemoteConfigErrorCode.invalidArgument,
          401: RemoteConfigErrorCode.unauthenticated,
          403: RemoteConfigErrorCode.unauthenticated,
          404: RemoteConfigErrorCode.notFound,
          409: RemoteConfigErrorCode.alreadyExists,
          412: RemoteConfigErrorCode.failedPrecondition,
          429: RemoteConfigErrorCode.resourceExhausted,
          500: RemoteConfigErrorCode.internalError,
          599: RemoteConfigErrorCode.unknownError,
        };
        for (final entry in byStatus.entries) {
          final ex = FirebaseRemoteConfigException.fromServerError(
            statusCode: entry.key,
            body: 'not-json',
            isJson: false,
          );
          expect(
            ex.errorCode,
            entry.value,
            reason: 'status ${entry.key} should map to ${entry.value}',
          );
        }
      },
    );

    test('fromServerError handles JSON without an "error" key', () {
      final ex = FirebaseRemoteConfigException.fromServerError(
        statusCode: 400,
        body: '{}',
        isJson: true,
      );
      expect(ex.errorCode, RemoteConfigErrorCode.invalidArgument);
    });

    test('fromServerError handles malformed JSON marked as JSON', () {
      final ex = FirebaseRemoteConfigException.fromServerError(
        statusCode: 500,
        body: '{not valid json',
        isJson: true,
      );
      expect(ex.errorCode, RemoteConfigErrorCode.internalError);
    });
  });
}
