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

import 'package:firebase_admin_sdk/src/auth.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../fixtures/helpers.dart';
import '../../fixtures/mock.dart';

const _uid = 'test-uid';

/// Calls [Auth.updateUser] against a mocked backend and returns the JSON body
/// of the `accounts:update` request it sent.
Future<Map<String, Object?>> _sentUpdate(UpdateRequest request) async {
  final clientMock = MockAuthClient();
  Map<String, Object?>? updateBody;
  when(() => clientMock.send(any())).thenAnswer((invocation) async {
    final httpRequest = invocation.positionalArguments.single as BaseRequest;
    final body = await httpRequest.finalize().bytesToString();
    final Object response;
    if (httpRequest.url.path.endsWith('accounts:update')) {
      updateBody = jsonDecode(body) as Map<String, Object?>;
      response = {'localId': _uid};
    } else {
      response = {
        'users': [
          {'localId': _uid, 'createdAt': '0'},
        ],
      };
    }
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(response))),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  final app = createApp(client: clientMock);
  await Auth.internal(app).updateUser(_uid, request);

  expect(updateBody, isNotNull, reason: 'accounts:update was not called');
  return updateBody!;
}

/// An [Auth] whose backend fails the test if it is called.
Auth _authWithoutBackend() {
  final clientMock = MockAuthClient();
  when(() => clientMock.send(any())).thenAnswer(
    (_) => fail('updateUser should fail before calling the backend'),
  );
  return Auth.internal(createApp(client: clientMock));
}

Matcher _invalidArgument(String message) => isA<FirebaseAuthAdminException>()
    .having((e) => e.code, 'code', 'auth/argument-error')
    .having((e) => e.message, 'message', contains(message));

void main() {
  setUpAll(registerFallbacks);

  group('updateUser', () {
    group('omitted fields are left unchanged', () {
      test('UpdateRequest(disabled: true) deletes nothing', () async {
        final body = await _sentUpdate(UpdateRequest(disabled: true));

        expect(body, {'localId': _uid, 'disableUser': true});
      });

      test('setting displayName does not delete photoURL or phone', () async {
        final body = await _sentUpdate(UpdateRequest(displayName: 'Jane Doe'));

        expect(body, {'localId': _uid, 'displayName': 'Jane Doe'});
      });

      test('setting phoneNumber and photoURL sends them', () async {
        final body = await _sentUpdate(
          UpdateRequest(
            phoneNumber: '+15555550100',
            photoURL: 'https://example.com/a.png',
          ),
        );

        expect(body, {
          'localId': _uid,
          'phoneNumber': '+15555550100',
          'photoUrl': 'https://example.com/a.png',
        });
      });
    });

    group('fields set to null are deleted', () {
      test('displayName and photoURL', () async {
        final body = await _sentUpdate(
          UpdateRequest(displayName: null, photoURL: null),
        );

        expect(body, {
          'localId': _uid,
          'deleteAttribute': unorderedEquals(['DISPLAY_NAME', 'PHOTO_URL']),
        });
      });

      test('phoneNumber', () async {
        final body = await _sentUpdate(UpdateRequest(phoneNumber: null));

        expect(body, {
          'localId': _uid,
          'deleteProvider': ['phone'],
        });
      });
    });

    group('providersToUnlink', () {
      test("unlinks the phone provider with ['phone']", () async {
        final body = await _sentUpdate(
          UpdateRequest(providersToUnlink: ['phone']),
        );

        expect(body, {
          'localId': _uid,
          'deleteProvider': ['phone'],
        });
      });

      test("rejects phoneNumber: null together with ['phone']", () async {
        final auth = _authWithoutBackend();

        await expectLater(
          auth.updateUser(
            _uid,
            UpdateRequest(phoneNumber: null, providersToUnlink: ['phone']),
          ),
          throwsA(_invalidArgument("providersToUnlink=['phone']")),
        );
      });
    });
  });
}
