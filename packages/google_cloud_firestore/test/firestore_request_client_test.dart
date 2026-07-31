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

import 'package:google_cloud_firestore/src/firestore_http_client.dart';
import 'package:googleapis_auth/auth_io.dart' as googleapis_auth;
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Wraps a plain [Client] (such as [MockClient]) so it satisfies the
/// [googleapis_auth.AuthClient] interface [FirestoreRequestClient] requires.
class _FakeAuthClient extends BaseClient implements googleapis_auth.AuthClient {
  _FakeAuthClient(this._inner);

  final Client _inner;
  bool closed = false;

  @override
  googleapis_auth.AccessCredentials get credentials =>
      throw UnimplementedError();

  @override
  Future<StreamedResponse> send(BaseRequest request) => _inner.send(request);

  @override
  void close() {
    closed = true;
    _inner.close();
  }
}

void main() {
  group('FirestoreRequestClient', () {
    test('sets a header that has no existing value', () async {
      late Request captured;
      final mock = MockClient((request) async {
        captured = request;
        return Response('{}', 200);
      });

      final client = FirestoreRequestClient(_FakeAuthClient(mock), {
        'X-Firebase-Client': 'fire-admin-dart/1.0.0',
      });

      await client.get(Uri.parse('https://firestore.googleapis.com/'));

      expect(captured.headers['X-Firebase-Client'], 'fire-admin-dart/1.0.0');
    });

    test(
      'appends to (rather than overwrites) an existing header value',
      () async {
        late Request captured;
        final mock = MockClient((request) async {
          captured = request;
          return Response('{}', 200);
        });

        final client = FirestoreRequestClient(_FakeAuthClient(mock), {
          'X-Goog-Api-Client': 'fire-admin/1.0.0',
        });

        final request = Request(
          'GET',
          Uri.parse('https://firestore.googleapis.com/'),
        );
        // Simulates the value package:google_cloud_rpc already sets.
        request.headers['X-Goog-Api-Client'] =
            'gl-dart/3.9 gax/1.0 rest/1.0 gapic/1.0';

        await client.send(request);

        expect(
          captured.headers['X-Goog-Api-Client'],
          'gl-dart/3.9 gax/1.0 rest/1.0 gapic/1.0 fire-admin/1.0.0',
        );
      },
    );

    test('applies multiple headers independently', () async {
      late Request captured;
      final mock = MockClient((request) async {
        captured = request;
        return Response('{}', 200);
      });

      final client = FirestoreRequestClient(_FakeAuthClient(mock), {
        'X-Firebase-Client': 'fire-admin-dart/1.0.0',
        'X-Goog-Api-Client': 'fire-admin/1.0.0',
      });

      await client.get(Uri.parse('https://firestore.googleapis.com/'));

      expect(captured.headers['X-Firebase-Client'], 'fire-admin-dart/1.0.0');
      expect(captured.headers['X-Goog-Api-Client'], 'fire-admin/1.0.0');
    });

    test('delegates close() to the inner client', () {
      final mock = MockClient((request) async => Response('{}', 200));
      final inner = _FakeAuthClient(mock);
      final client = FirestoreRequestClient(inner, const {});

      client.close();

      expect(inner.closed, isTrue);
    });

    test('delegates credentials to the inner client', () {
      final mock = MockClient((request) async => Response('{}', 200));
      final inner = _FakeAuthClient(mock);
      final client = FirestoreRequestClient(inner, const {});

      expect(() => client.credentials, throwsUnimplementedError);
    });
  });
}
