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
import 'dart:io' show gzip;

import 'package:firebase_admin_sdk/src/remote_config/remote_config.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../../fixtures/helpers.dart';

class _StubAuthClient extends MockClient implements AuthClient {
  _StubAuthClient(super.fn);

  @override
  AccessCredentials get credentials => throw UnimplementedError();
}

void main() {
  group('RemoteConfigHttpClient response body', () {
    const template = {
      'parameters': {
        'greeting': {
          'defaultValue': {'value': 'salut, lume ✓'},
        },
      },
    };
    final plainBytes = utf8.encode(jsonEncode(template));
    const jsonType = {'content-type': 'application/json; charset=UTF-8'};

    RemoteConfigHttpClient clientReturning(Response response) {
      final app = createApp(
        name: 'rc-http-${DateTime.now().microsecondsSinceEpoch}',
        client: _StubAuthClient((_) async => response),
      );
      return RemoteConfigHttpClient(app);
    }

    test('sends Accept-Encoding: gzip', () async {
      late Request sent;
      final app = createApp(
        name: 'rc-http-${DateTime.now().microsecondsSinceEpoch}',
        client: _StubAuthClient((request) async {
          sent = request;
          return Response.bytes(plainBytes, 200);
        }),
      );

      await RemoteConfigHttpClient(app).getTemplate();

      expect(sent.headers['Accept-Encoding'], 'gzip');
    });

    test('inflates a gzip body', () async {
      final client = clientReturning(
        Response.bytes(
          gzip.encode(plainBytes),
          200,
          headers: {...jsonType, 'content-encoding': 'gzip', 'etag': 'etag-1'},
        ),
      );

      final result = await client.getTemplate();

      expect(result.body, template);
      expect(result.etag, 'etag-1');
    });

    test('reads a plain body that still carries the gzip header', () async {
      // What a client backed by dart:io's HttpClient returns: the body is
      // already inflated, the header is left in place.
      final client = clientReturning(
        Response.bytes(
          plainBytes,
          200,
          headers: {...jsonType, 'content-encoding': 'gzip', 'etag': 'etag-1'},
        ),
      );

      final result = await client.getTemplate();

      expect(result.body, template);
      expect(result.etag, 'etag-1');
    });

    test('reads a plain body with no content-encoding header', () async {
      final client = clientReturning(
        Response.bytes(plainBytes, 200, headers: jsonType),
      );

      expect((await client.getTemplate()).body, template);
    });

    test(
      'returns an empty map for an empty body with the gzip header',
      () async {
        final client = clientReturning(
          Response.bytes(const [], 200, headers: {'content-encoding': 'gzip'}),
        );

        expect((await client.getTemplate()).body, isEmpty);
      },
    );

    test('maps a gzip error body to its server error code', () async {
      final error = jsonEncode({
        'error': {'status': 'INVALID_ARGUMENT', 'message': 'bad template'},
      });
      final client = clientReturning(
        Response.bytes(
          gzip.encode(utf8.encode(error)),
          400,
          headers: {
            'content-encoding': 'gzip',
            'content-type': 'application/json',
          },
        ),
      );

      await expectLater(
        client.getTemplate(),
        throwsA(
          isA<FirebaseRemoteConfigException>()
              .having(
                (e) => e.errorCode,
                'errorCode',
                RemoteConfigErrorCode.invalidArgument,
              )
              .having((e) => e.message, 'message', contains('bad template')),
        ),
      );
    });
  });
}
