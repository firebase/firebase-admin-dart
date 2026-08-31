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

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:google_cloud_firestore/src/environment.dart';
import 'package:google_cloud_firestore/src/firestore_http_client.dart';
import 'package:test/test.dart';

/// Builds a client for host resolution only; no request is ever sent.
///
/// [Settings.environmentOverride] is always supplied so the ambient
/// `FIRESTORE_EMULATOR_HOST` cannot leak into these expectations.
FirestoreHttpClient _clientFor({
  String? host,
  bool ssl = true,
  Map<String, String> environment = const {},
}) {
  return FirestoreHttpClient(
    credential: Credential.fromApplicationDefaultCredentials(),
    settings: Settings(
      projectId: 'test-project',
      host: host,
      ssl: ssl,
      environmentOverride: environment,
    ),
  );
}

void main() {
  group('firestoreApiHost', () {
    test('defaults to the production endpoint over HTTPS', () {
      final uri = _clientFor().firestoreApiHost;

      expect(uri.scheme, 'https');
      expect(uri.host, 'firestore.googleapis.com');
    });

    test('uses HTTPS for a custom host when ssl is true', () {
      final uri = _clientFor(host: 'example.test:8080').firestoreApiHost;

      expect(uri.scheme, 'https');
      expect(uri.host, 'example.test');
      expect(uri.port, 8080);
    });

    test('uses HTTP for a custom host when ssl is false', () {
      final uri = _clientFor(
        host: '127.0.0.1:8080',
        ssl: false,
      ).firestoreApiHost;

      expect(uri.scheme, 'http');
      expect(uri.host, '127.0.0.1');
      expect(uri.port, 8080);
    });

    test('uses HTTP against the default host when ssl is false', () {
      final uri = _clientFor(ssl: false).firestoreApiHost;

      expect(uri.scheme, 'http');
      expect(uri.host, 'firestore.googleapis.com');
    });

    test('FIRESTORE_EMULATOR_HOST wins over host and ssl', () {
      final uri = _clientFor(
        host: 'example.test:9090',
        environment: const {
          Environment.firestoreEmulatorHost: '127.0.0.1:8080',
        },
      ).firestoreApiHost;

      expect(uri.scheme, 'http');
      expect(uri.host, '127.0.0.1');
      expect(uri.port, 8080);
    });
  });
}
