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

import 'dart:io';

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:http/http.dart' show ClientException;
import 'package:test/test.dart';

const projectId = 'dart-firebase-admin';

/// Project ID used by unit tests that mock the Firestore HTTP client and
/// never make a real network call (as opposed to [projectId], which points
/// at the real project used by emulator/production integration tests).
const mockProjectId = 'test-project';

const mockPrivateKey = '''
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA6xkrY7pxvazMDAesPtRqsnQN+7Nv1boCQeFP+crgJLZN9gnD
vqiDCIqPOv0p/n687npEp1eGDJcL/ZxK/wXQqvonwUeTwZnglKSRL6W76zXyYiFa
ibVLdHgg/KIUrlokS8/pWbFkI7kideTgQp+1vh3jUcdpq46tatPvINzZEj5xrV/2
NSzyBSMNPrXsMEk9cEh8e3GkgGuitHVfLp5M4K/d31ezoBt1dZjtxKS7JI+OHya5
C9Z208BllZNklUERK8lSw0EG1y1VahMl4mBpKpfswq1Dysv9JPv3hMEWt/S4864l
dxN4VE5M6MB8hWFPq+f4UY7MhNkeYcNfyqgMxQIDAQABAoIBADmp1kEjSWOe/vtS
ZHaSrkrv+UALznnrIkObanzXvGt0xaF72qWoel89cQ0kbEjuOBP8LFupNYlgAQJm
8+QiPoC5U8ft8PlS70k2JiA8M9/ovvc/vA+7xnKeRmUAsjbjiDSKHe+weWHjtmaZ
SUI+HxsvBIMZ+LqqB7IEoon6cUmuS+TBGeBtPUZkwtjhzAXeyy9xNKjEJ94NcPRo
fIBIPGXMroc2fafbVsr+Wq931oficPEpjRd+JLkojHqcq/aY1sIWpYwNxu6jF9sm
KsUUtrwsQL6s3vxwkuKd3X0XhEgJSQBxkY40BLFMLFR0gmoVzw3+OtfEagMiXzyb
SAYbFk8CgYEA94lcWzOGGUijpQQKBwcNBo/kvcQ6h9NGlJ7ZUeuAyIIq4aRxGFBV
yWnpKOFC7ywsNeoatLXXTiTe6Xq0JBkup3WZktsNe1BI2R1kX6PHHYBVMKXA02tX
uGANaqg/A+ZYA2VMPdcRTNhgXgsJnj7mcDCKHdPYQHvLGqU5WRA185cCgYEA8yLw
bb6oZ3YtMbBYYay0u3iqlN74GWqLwLH2ZovQIWnVYbYUNmJNTVhkHlShXWK3qKOY
p26K67LBIRYRaseIH4e9hPROy1vsl4dkmd8FJfhsx8WXpa3/3pHw9hmbhmhhjVLo
ABtQKxjLDa430mi3jFgcN7yn6B4qklpO6lmpngMCgYB8BAOTZbLvg+cIy4dCkhPC
j+Dn+iHg3sbjutniIvz4d86IEdzfc5AnQrqf0ou4TAcyU8FhfCEMc4iCrQkHdN5c
45w3aSvN9iEpNYKOL/2YGC2WG9UJlyPxqZ3PK8+2YncB7IRQDyoJt/Y/54PAFn9Z
AdiQrQwQ8nSFOvYKWwbMrQKBgAhem4grmAB3wPaE64XxPAd4D+cwBbpaQJVRivnc
tj1wNzg13FxC5gZTlJ62qxdb3pafixG4bG/Qp3VMHS1f0P/E3HFHN68oauyMbJof
Yz37X0NBOgcqBjTTMUhHeWMXFMSYpgPa7NeO8u51oNZNZIQgRFhm1iDXaP/AvBa1
H3GhAoGBAKGcU+cw5dx9jf4Dj3Xechknrl5aDdK5FNrIC4IJ20A4N3S+WQ1cQuRO
QjJNH9ASKTmmuslFJZZcBX5ybnr9Eg3MUeCyaru1CSWubrKraMo71mgzTexZOtV5
nlc5+GKKhkC/Vp5ZNE04kdT+35eMZUTbv1/d3Y5TzUIGd6QwtPtM
-----END RSA PRIVATE KEY-----
''';

/// Whether the Firestore emulator is enabled.
bool isFirestoreEmulatorEnabled() {
  return Platform.environment['FIRESTORE_EMULATOR_HOST'] != null;
}

/// Validates that required emulator environment variables are set.
///
/// Call this in setUpAll() of test files to fail fast if emulators aren't
/// configured, preventing accidental writes to production.
///
/// Example:
/// ```dart
/// setUpAll(() {
///   ensureEmulatorConfigured();
/// });
/// ```
void ensureEmulatorConfigured() {
  if (!isFirestoreEmulatorEnabled()) {
    throw StateError(
      'Missing emulator configuration: FIRESTORE_EMULATOR_HOST\n\n'
      'Tests must run against Firebase emulators to prevent writing to production.\n'
      'Set the following environment variable:\n'
      '  FIRESTORE_EMULATOR_HOST=localhost:8080\n\n'
      'Or run tests with: firebase emulators:exec "dart test"',
    );
  }
}

Future<void> _recursivelyDeleteAllDocuments(Firestore firestore) async {
  Future<void> handleCollection(CollectionReference<void> collection) async {
    final docs = await collection.listDocuments();

    for (final doc in docs) {
      await doc.delete();

      final subcollections = await doc.listCollections();
      for (final subcollection in subcollections) {
        await handleCollection(subcollection);
      }
    }
  }

  final collections = await firestore.listCollections();
  for (final collection in collections) {
    await handleCollection(collection);
  }
}

/// Creates a Firestore instance for testing.
///
/// Automatically cleans up all documents after each test.
///
/// Note: Tests should be run with FIRESTORE_EMULATOR_HOST=localhost:8080
/// environment variable set. The emulator will be auto-detected.
Future<Firestore> createFirestore({Settings? settings}) async {
  // CRITICAL: Ensure emulator is running to prevent hitting production
  if (!isFirestoreEmulatorEnabled()) {
    throw StateError(
      'FIRESTORE_EMULATOR_HOST environment variable must be set to run tests. '
      'This prevents accidentally writing test data to production. '
      'Set it to "localhost:8080" or your emulator host.',
    );
  }

  final emulatorHost = Platform.environment['FIRESTORE_EMULATOR_HOST']!;

  // Create Firestore with emulator settings
  final firestore = Firestore(
    settings: (settings ?? const Settings()).copyWith(
      projectId: projectId,
      host: emulatorHost,
      ssl: false,
    ),
  );

  addTearDown(() async {
    try {
      await _recursivelyDeleteAllDocuments(firestore);
    } on ClientException catch (e) {
      // Ignore if HTTP client was already closed
      if (!e.message.contains('Client is already closed')) rethrow;
    }
    await firestore.terminate();
  });

  return firestore;
}

Matcher isArgumentError({String? message}) {
  var matcher = isA<ArgumentError>();
  if (message != null) {
    matcher = matcher.having((e) => e.message, 'message', message);
  }

  return matcher;
}

Matcher throwsArgumentError({String? message}) {
  return throwsA(isArgumentError(message: message));
}
