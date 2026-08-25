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

import 'package:firebase_admin_sdk/src/app.dart';
import 'package:firebase_admin_sdk/src/utils/utils.dart';
import 'package:firebase_admin_sdk/src/version.g.dart';
import 'package:googleapis_auth/auth_io.dart' as googleapis_auth;
import 'package:http/http.dart';
import 'package:test/test.dart';

void main() {
  group('FirebaseUserAgentClient', () {
    test('adds X-Firebase-Client header to every request', () async {
      final captured = <BaseRequest>[];
      final client = FirebaseUserAgentClient(_CapturingAuthClient(captured));

      await client.send(Request('GET', Uri.parse('https://example.com/')));

      expect(captured.length, 1);
      expect(
        captured.first.headers['X-Firebase-Client'],
        'fire-admin-dart/$packageVersion',
      );
    });

    test('header value is fire-admin-dart/<version>', () async {
      final captured = <BaseRequest>[];
      final client = FirebaseUserAgentClient(_CapturingAuthClient(captured));

      await client.send(Request('GET', Uri.parse('https://example.com/')));

      final value = captured.first.headers['X-Firebase-Client']!;
      expect(value, startsWith('fire-admin-dart/'));
      expect(value.split('/').last, packageVersion);
    });

    test('adds X-Goog-Api-Client header to every request', () async {
      final captured = <BaseRequest>[];
      final client = FirebaseUserAgentClient(_CapturingAuthClient(captured));

      await client.send(Request('GET', Uri.parse('https://example.com/')));

      expect(captured.length, 1);
      expect(
        captured.first.headers['X-Goog-Api-Client'],
        'gl-dart/$dartVersion fire-admin/$packageVersion',
      );
    });

    test(
      'X-Goog-Api-Client has correct format gl-dart/<version> fire-admin/<version>',
      () async {
        final captured = <BaseRequest>[];
        final client = FirebaseUserAgentClient(_CapturingAuthClient(captured));

        await client.send(Request('GET', Uri.parse('https://example.com/')));

        final value = captured.first.headers['X-Goog-Api-Client']!;
        final parts = value.split(' ');
        expect(parts.length, 2);
        expect(parts[0], startsWith('gl-dart/'));
        expect(parts[1], startsWith('fire-admin/'));
        expect(parts[1].split('/').last, packageVersion);
      },
    );

    test('preserves other headers on the request', () async {
      final captured = <BaseRequest>[];
      final client = FirebaseUserAgentClient(_CapturingAuthClient(captured));

      final request = Request('POST', Uri.parse('https://example.com/'));
      request.headers['content-type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer tok';
      await client.send(request);

      expect(captured.first.headers['content-type'], 'application/json');
      expect(captured.first.headers['Authorization'], 'Bearer tok');
    });

    test('overwrites any pre-existing X-Firebase-Client header', () async {
      // The legacy messaging client used to set fire-admin-node/<version>;
      // FirebaseUserAgentClient should replace it with the correct value.
      final captured = <BaseRequest>[];
      final client = FirebaseUserAgentClient(_CapturingAuthClient(captured));

      final request = Request('POST', Uri.parse('https://example.com/'));
      request.headers['X-Firebase-Client'] = 'fire-admin-node/12.0.0';
      await client.send(request);

      expect(
        captured.first.headers['X-Firebase-Client'],
        'fire-admin-dart/$packageVersion',
      );
    });

    test('appends to any pre-existing X-Goog-Api-Client header', () async {
      final captured = <BaseRequest>[];
      final client = FirebaseUserAgentClient(_CapturingAuthClient(captured));

      final request = Request('POST', Uri.parse('https://example.com/'));
      request.headers['X-Goog-Api-Client'] = 'gl-dart/3.9.0 gdcl/17.0.0';
      await client.send(request);

      expect(
        captured.first.headers['X-Goog-Api-Client'],
        'gl-dart/3.9.0 gdcl/17.0.0 fire-admin/$packageVersion',
      );
    });

    test(
      'does not duplicate fire-admin tag if already present in X-Goog-Api-Client',
      () async {
        final captured = <BaseRequest>[];
        final client = FirebaseUserAgentClient(_CapturingAuthClient(captured));

        final request = Request('POST', Uri.parse('https://example.com/'));
        request.headers['X-Goog-Api-Client'] =
            'gl-dart/3.9.0 fire-admin/$packageVersion';
        await client.send(request);

        expect(
          captured.first.headers['X-Goog-Api-Client'],
          'gl-dart/3.9.0 fire-admin/$packageVersion',
        );
      },
    );

    test('injects both headers on every individual request', () async {
      final captured = <BaseRequest>[];
      final client = FirebaseUserAgentClient(_CapturingAuthClient(captured));

      await client.send(Request('GET', Uri.parse('https://example.com/1')));
      await client.send(Request('POST', Uri.parse('https://example.com/2')));
      await client.send(Request('PUT', Uri.parse('https://example.com/3')));

      expect(captured.length, 3);
      for (final req in captured) {
        expect(
          req.headers['X-Firebase-Client'],
          'fire-admin-dart/$packageVersion',
        );
        expect(
          req.headers['X-Goog-Api-Client'],
          'gl-dart/$dartVersion fire-admin/$packageVersion',
        );
      }
    });

    test('delegates close() to the inner client', () async {
      var closed = false;
      final client = FirebaseUserAgentClient(
        _CapturingAuthClient([], onClose: () => closed = true),
      );

      client.close();

      expect(closed, isTrue);
    });

    test('delegates credentials getter to the inner client', () {
      final inner = _CapturingAuthClient([]);
      final client = FirebaseUserAgentClient(inner);

      // credentials throws UnimplementedError on our stub — same as EmulatorClient.
      expect(() => client.credentials, throwsUnimplementedError);
    });
  });
}

/// Minimal [googleapis_auth.AuthClient] that records every [BaseRequest]
/// passed to [send] without making real network calls.
class _CapturingAuthClient extends BaseClient
    implements googleapis_auth.AuthClient {
  _CapturingAuthClient(this._captured, {void Function()? onClose})
    : _onClose = onClose;

  final List<BaseRequest> _captured;
  final void Function()? _onClose;

  @override
  googleapis_auth.AccessCredentials get credentials =>
      throw UnimplementedError();

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    _captured.add(request);
    return StreamedResponse(const Stream.empty(), 200);
  }

  @override
  void close() => _onClose?.call();
}
