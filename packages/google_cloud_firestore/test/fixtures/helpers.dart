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
