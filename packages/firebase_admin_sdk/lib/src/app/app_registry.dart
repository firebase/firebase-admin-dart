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

part of '../app.dart';

@internal
class AppRegistry {
  AppRegistry._();

  /// Returns the shared default instance, creating it on first access.
  factory AppRegistry.getDefault() {
    return _instance ??= AppRegistry._();
  }

  static AppRegistry? _instance;

  /// The current instance, if one exists.
  static AppRegistry? get instance => _instance;

  /// Replaces the singleton instance. Use for testing.
  @visibleForTesting
  static set instance(AppRegistry? registry) {
    _instance = registry;
  }

  static const _defaultAppName = '[DEFAULT]';

  final Map<String, FirebaseApp> _apps = {};

  /// Initializes a new Firebase app or returns an existing one.
  ///
  /// Creates a new app with the given [options] and [name], or returns an
  /// existing app if one with the same name already exists with matching
  /// configuration.
  ///
  /// If [options] is null, the app will be initialized from the
  /// FIREBASE_CONFIG environment variable.
  ///
  /// [name] defaults to `[DEFAULT]` if not provided.
  ///
  /// Throws `FirebaseAppException` if:
  /// - An app with the same name exists but with different configuration
  /// - An app with the same name exists but was initialized differently
  ///   (one from env, one explicitly)
  FirebaseApp initializeApp({AppOptions? options, String? name}) {
    name ??= _defaultAppName;
    _validateAppName(name);

    final (effectiveOptions, wasInitializedFromEnv) = switch (options) {
      null => (fetchOptionsFromEnvironment(), true),
      AppOptions(credential: null) => (
        options.copyWith(
          credential: _credentialFromEnv(
            Zone.current[envSymbol] as Map<String, String>? ??
                Platform.environment,
          ),
        ),
        false,
      ),
      _ => (options, false),
    };

    // App doesn't exist - create it
    if (!_apps.containsKey(name)) {
      final app = FirebaseApp(
        options: effectiveOptions,
        name: name,
        wasInitializedFromEnv: wasInitializedFromEnv,
      );
      _apps[name] = app;
      return app;
    }

    // App exists
    final existingApp = _apps[name]!;

    // Check initialization mode matches
    if (existingApp.wasInitializedFromEnv != wasInitializedFromEnv) {
      throw FirebaseAppException(
        AppErrorCode.invalidAppOptions,
        'Firebase app named "$name" already exists with different configuration.',
      );
    }

    // Both from env: return existing app (skip comparison)
    if (wasInitializedFromEnv) {
      return existingApp;
    }

    // Check if options match existing app (using Equatable)
    if (options != existingApp.options) {
      throw FirebaseAppException(
        AppErrorCode.duplicateApp,
        'Firebase app named "$name" already exists with different configuration.',
      );
    }

    return existingApp;
  }

  /// Loads app options from the FIREBASE_CONFIG environment variable.
  ///
  /// If the variable contains a string starting with '{', it's parsed as JSON.
  /// Otherwise, it's treated as a file path to read.
  ///
  /// Returns empty AppOptions if FIREBASE_CONFIG is not set.
  AppOptions fetchOptionsFromEnvironment() {
    final env =
        Zone.current[envSymbol] as Map<String, String>? ?? Platform.environment;

    final config = env['FIREBASE_CONFIG'];
    if (config == null || config.isEmpty) {
      return AppOptions(credential: _credentialFromEnv(env));
    }

    try {
      final String contents;
      if (config.startsWith('{')) {
        // Parse as JSON directly
        contents = config;
      } else {
        // Treat as file path
        contents = File(config).readAsStringSync();
      }

      final json = jsonDecode(contents) as Map<String, dynamic>;

      return AppOptions(
        credential: _credentialFromEnv(env),
        projectId: json['projectId'] as String?,
        databaseURL: json['databaseURL'] as String?,
        storageBucket: json['storageBucket'] as String?,
        serviceAccountId: json['serviceAccountId'] as String?,
      );
    } catch (error) {
      throw FirebaseAppException(
        AppErrorCode.invalidArgument,
        'Failed to parse FIREBASE_CONFIG: $error',
      );
    }
  }

  /// Gets an existing app by name.
  ///
  /// Returns the app with the given [name], or the default app if [name]
  /// is null or not provided.
  ///
  /// Throws [FirebaseAppException] if no app exists with the given name.
  FirebaseApp getApp([String? name]) {
    name ??= _defaultAppName;
    _validateAppName(name);

    if (!_apps.containsKey(name)) {
      final errorMessage = name == _defaultAppName
          ? 'The default Firebase app does not exist. '
          : 'Firebase app named "$name" does not exist. ';
      throw FirebaseAppException(
        AppErrorCode.noApp,
        '${errorMessage}Make sure you call initializeApp() before using any of the Firebase services.',
      );
    }

    return _apps[name]!;
  }

  /// Returns a list of all initialized apps.
  List<FirebaseApp> get apps {
    return List.unmodifiable(_apps.values);
  }

  /// Deletes the specified app and cleans up its resources.
  ///
  /// This calls [FirebaseApp.close] on the app, which will also remove it
  /// from the registry.
  Future<void> deleteApp(FirebaseApp app) async {
    final existingApp = getApp(app.name);
    await existingApp.close();
  }

  /// Removes an app from the registry.
  ///
  /// This is called internally by [FirebaseApp.close] to remove the app
  /// from the registry after cleanup.
  void removeApp(String name) {
    _apps.remove(name);
  }

  /// Validates that an app name is a non-empty string.
  void _validateAppName(String name) {
    if (name.isEmpty) {
      throw FirebaseAppException(
        AppErrorCode.invalidAppName,
        'Invalid Firebase app name "$name" provided. App name must be a non-empty string.',
      );
    }
  }

  Credential _credentialFromEnv(Map<String, String> env) {
    final googleCredPath = env['GOOGLE_APPLICATION_CREDENTIALS'];
    if (googleCredPath != null) {
      try {
        return Credential.fromServiceAccount(File(googleCredPath));
      } catch (_) {
        // File missing, not a service account JSON, or missing project_id –
        // fall through to ADC.
      }
    }
    return Credential.fromApplicationDefaultCredentials();
  }
}
