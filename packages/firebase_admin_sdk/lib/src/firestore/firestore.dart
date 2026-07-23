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

import 'package:google_cloud_firestore/google_cloud_firestore.dart'
    as google_cloud_firestore;
import 'package:meta/meta.dart';

import '../app.dart';
import '../utils/utils.dart';
import '../version.g.dart';

/// Default database ID used by Firestore
const String kDefaultDatabaseId = '(default)';

/// Firestore service for Firebase Admin SDK.
class Firestore implements FirebaseService {
  /// Internal constructor
  Firestore._(this.app);

  /// Factory constructor that ensures singleton per app.
  @internal
  factory Firestore.internal(FirebaseApp app) {
    return app.getOrInitService(
      FirebaseServiceType.firestore.name,
      Firestore._,
    );
  }

  @override
  final FirebaseApp app;

  // Maps database IDs to Firestore delegate instances
  final Map<String, google_cloud_firestore.Firestore> _databases = {};

  // Maps database IDs to their settings
  final Map<String, google_cloud_firestore.Settings?> _settings = {};

  /// Gets the settings used to initialize a specific database.
  /// Returns null if the database hasn't been initialized yet.
  ///
  /// This is exposed for testing purposes to verify credential extraction.
  @visibleForTesting
  google_cloud_firestore.Settings? getSettingsForDatabase(String databaseId) {
    return _settings[databaseId];
  }

  /// Gets the actual settings that would be built for a database.
  /// This calls _buildSettings without initializing the database.
  ///
  /// This is exposed for testing purposes to verify settings construction.
  @visibleForTesting
  google_cloud_firestore.Settings buildSettingsForTesting(
    String databaseId,
    google_cloud_firestore.Settings? userSettings,
  ) {
    return _buildSettings(databaseId, userSettings);
  }

  /// Gets or creates a Firestore instance for the specified database.
  @internal
  google_cloud_firestore.Firestore getDatabase([
    String databaseId = kDefaultDatabaseId,
  ]) {
    var database = _databases[databaseId];
    if (database == null) {
      database = _initFirestore(databaseId, null);
      _databases[databaseId] = database;
      _settings[databaseId] = null;
    }
    return database;
  }

  /// Initializes a Firestore instance with specific settings.
  /// Throws if the database was already initialized with different settings.
  @internal
  google_cloud_firestore.Firestore initializeDatabase(
    String databaseId,
    google_cloud_firestore.Settings? settings,
  ) {
    final existingInstance = _databases[databaseId];
    if (existingInstance != null) {
      final initialSettings = _settings[databaseId];
      if (_areSettingsEqual(settings, initialSettings)) {
        return existingInstance;
      }
      throw FirebaseAppException(
        AppErrorCode.failedPrecondition,
        'app.firestore() has already been called with different settings for database "$databaseId". '
        'To avoid this error, call app.firestore() with the same settings '
        'as when it was originally called, or call app.firestore() to return the '
        'already initialized instance.',
      );
    }

    final newInstance = _initFirestore(databaseId, settings);
    _databases[databaseId] = newInstance;
    // Store user-provided settings (not built settings) for comparison
    // This allows us to detect if the user tries to reinitialize with
    // different settings
    _settings[databaseId] = settings;
    return newInstance;
  }

  /// Creates Firestore settings from the Firebase app configuration
  google_cloud_firestore.Settings _buildSettings(
    String databaseId,
    google_cloud_firestore.Settings? userSettings,
  ) {
    final projectId = app.projectId;
    final appCredential = app.options.credential;

    var settings = userSettings ?? const google_cloud_firestore.Settings();

    if (settings.credential == null) {
      if (appCredential is ServiceAccountCredential) {
        settings = settings.copyWith(
          credential:
              google_cloud_firestore.Credential.fromServiceAccountParams(
                email: appCredential.clientEmail,
                privateKey: appCredential.privateKey,
                projectId: appCredential.projectId,
              ),
        );
      } else if (appCredential is ApplicationDefaultCredential) {
        settings = settings.copyWith(
          credential: google_cloud_firestore
              .Credential.fromApplicationDefaultCredentials(),
        );
      } else if (appCredential != null) {
        throw FirebaseAppException(
          AppErrorCode.invalidCredential,
          'Firestore requires ServiceAccountCredential or '
          'ApplicationDefaultCredential. Got: ${appCredential.runtimeType}',
        );
      }
    }

    settings = settings.copyWith(databaseId: databaseId);

    if (projectId != null && settings.projectId == null) {
      settings = settings.copyWith(projectId: projectId);
    }

    if (settings.headers == null) {
      settings = settings.copyWith(
        headers: {
          'X-Firebase-Client': 'fire-admin-dart/$packageVersion',
          'X-Goog-Api-Client': 'gl-dart/$dartVersion fire-admin/$packageVersion',
        },
      );
    }

    return settings;
  }

  google_cloud_firestore.Firestore _initFirestore(
    String databaseId,
    google_cloud_firestore.Settings? settings,
  ) {
    final firestoreSettings = _buildSettings(databaseId, settings);
    return google_cloud_firestore.Firestore(settings: firestoreSettings);
  }

  bool _areSettingsEqual(
    google_cloud_firestore.Settings? a,
    google_cloud_firestore.Settings? b,
  ) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;

    if (a.projectId != b.projectId ||
        a.databaseId != b.databaseId ||
        a.host != b.host ||
        a.ssl != b.ssl) {
      return false;
    }

    return a.credential == b.credential;
  }

  @override
  Future<void> delete() async {
    // Terminate all Firestore instances
    await Future.wait(_databases.values.map((db) => db.terminate()));
    _databases.clear();
    _settings.clear();
  }
}
