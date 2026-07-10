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

/// Environment variable names used by the Firebase Admin SDK.
///
/// These constants provide type-safe access to environment variables
/// that configure SDK behavior, credentials, and emulator connections.
@internal
abstract class Environment {
  /// Path to Google Application Credentials JSON file.
  ///
  /// Used by Application Default Credentials to load service account credentials.
  /// Example: `/path/to/serviceAccountKey.json`
  static const googleApplicationCredentials = 'GOOGLE_APPLICATION_CREDENTIALS';

  /// Google Cloud project ID.
  ///
  /// Used to explicitly specify the project ID when not available from credentials.
  static const googleCloudProject = 'GOOGLE_CLOUD_PROJECT';

  /// Legacy Google Cloud project ID (gcloud CLI).
  ///
  /// Alternative to [googleCloudProject], used by gcloud CLI.
  static const gcloudProject = 'GCLOUD_PROJECT';

  /// Firebase Auth Emulator host address.
  ///
  /// When set, Auth service automatically connects to the emulator instead of production.
  /// Format: `host:port` (e.g., `localhost:9099`)
  static const firebaseAuthEmulatorHost = 'FIREBASE_AUTH_EMULATOR_HOST';

  /// Firestore Emulator host address.
  ///
  /// When set, Firestore service automatically connects to the emulator instead of production.
  /// Format: `host:port` (e.g., `localhost:8080`)
  static const firestoreEmulatorHost = 'FIRESTORE_EMULATOR_HOST';

  /// Cloud Tasks Emulator host address.
  ///
  /// When set, Functions (Cloud Tasks) service automatically connects to the emulator instead of production.
  /// Format: `host:port` (e.g., `127.0.0.1:9499`)
  static const cloudTasksEmulatorHost = 'CLOUD_TASKS_EMULATOR_HOST';

  /// Firebase Storage Emulator host address.
  ///
  /// When set, Storage service automatically connects to the emulator instead of production.
  /// Format: `host:port` (e.g., `localhost:9199`)
  static const firebaseStorageEmulatorHost = 'FIREBASE_STORAGE_EMULATOR_HOST';

  /// Checks if the Firestore emulator is enabled via environment variable.
  ///
  /// Returns `true` if [firestoreEmulatorHost] is set in the environment.
  ///
  /// Example:
  /// ```dart
  /// if (Environment.isFirestoreEmulatorEnabled()) {
  ///   print('Using Firestore emulator');
  /// }
  /// ```
  static bool isFirestoreEmulatorEnabled() {
    final env =
        Zone.current[envSymbol] as Map<String, String>? ?? Platform.environment;
    return env[firestoreEmulatorHost] != null;
  }

  /// Checks if the Auth emulator is enabled via environment variable.
  ///
  /// Returns `true` if [firebaseAuthEmulatorHost] is set in the environment.
  ///
  /// Example:
  /// ```dart
  /// if (Environment.isAuthEmulatorEnabled()) {
  ///   print('Using Auth emulator');
  /// }
  /// ```
  static bool isAuthEmulatorEnabled() {
    final env =
        Zone.current[envSymbol] as Map<String, String>? ?? Platform.environment;
    return env[firebaseAuthEmulatorHost] != null;
  }

  /// Checks if the Cloud Tasks emulator is enabled via environment variable.
  ///
  /// Returns `true` if [cloudTasksEmulatorHost] is set in the environment.
  ///
  /// Example:
  /// ```dart
  /// if (Environment.isCloudTasksEmulatorEnabled()) {
  ///   print('Using Cloud Tasks emulator');
  /// }
  /// ```
  static bool isCloudTasksEmulatorEnabled() {
    final env =
        Zone.current[envSymbol] as Map<String, String>? ?? Platform.environment;
    return env[cloudTasksEmulatorHost] != null;
  }

  /// Checks if the Storage emulator is enabled via environment variable.
  ///
  /// Returns `true` if [firebaseStorageEmulatorHost] is set in the environment.
  ///
  /// Example:
  /// ```dart
  /// if (Environment.isStorageEmulatorEnabled()) {
  ///   print('Using Storage emulator');
  /// }
  /// ```
  static bool isStorageEmulatorEnabled() {
    final env =
        Zone.current[envSymbol] as Map<String, String>? ?? Platform.environment;
    return env[firebaseStorageEmulatorHost] != null;
  }

  /// Gets the Storage emulator host from environment variables.
  ///
  /// Returns the host:port string if set, otherwise null.
  ///
  /// Example:
  /// ```dart
  /// final host = Environment.getStorageEmulatorHost();
  /// if (host != null) {
  ///   print('Storage emulator at $host');
  /// }
  /// ```
  static String? getStorageEmulatorHost() {
    final env =
        Zone.current[envSymbol] as Map<String, String>? ?? Platform.environment;
    return env[firebaseStorageEmulatorHost];
  }

  /// Gets the Auth emulator host from environment variables.
  ///
  /// Returns the host:port string if set, otherwise null.
  ///
  /// Example:
  /// ```dart
  /// final host = Environment.getAuthEmulatorHost();
  /// if (host != null) {
  ///   print('Auth emulator at $host');
  /// }
  /// ```
  static String? getAuthEmulatorHost() {
    final env =
        Zone.current[envSymbol] as Map<String, String>? ?? Platform.environment;
    return env[firebaseAuthEmulatorHost];
  }

  /// Gets the Cloud Tasks emulator host from environment variables.
  ///
  /// Returns the host:port string if set, otherwise null.
  ///
  /// Example:
  /// ```dart
  /// final host = Environment.getCloudTasksEmulatorHost();
  /// if (host != null) {
  ///   print('Tasks emulator at $host');
  /// }
  /// ```
  static String? getCloudTasksEmulatorHost() {
    final env =
        Zone.current[envSymbol] as Map<String, String>? ?? Platform.environment;
    return env[cloudTasksEmulatorHost];
  }

  /// Gets the Kit Instance ID if running within a kit.
  static String? getKitInstanceId() {
    final env =
        Zone.current[envSymbol] as Map<String, String>? ?? Platform.environment;
    return env['FIREBASE_KIT_INSTANCE_ID'];
  }
}
