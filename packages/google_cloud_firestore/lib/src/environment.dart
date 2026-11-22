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
import 'dart:io';

import '../google_cloud_firestore.dart';

/// Environment variable names used by Google Cloud Firestore.
///
/// These constants provide type-safe access to environment variables
/// that configure Firestore behavior and emulator connections.
abstract class Environment {
  /// Firestore Emulator host address.
  ///
  /// When set, Firestore automatically connects to the emulator instead of production.
  /// Format: `host:port` (e.g., `localhost:8080`)
  ///
  /// Example:
  /// ```bash
  /// export FIRESTORE_EMULATOR_HOST=localhost:8080
  /// ```
  static const firestoreEmulatorHost = 'FIRESTORE_EMULATOR_HOST';

  /// Gets the Firestore emulator host from environment variables.
  ///
  /// Returns the host:port string if [firestoreEmulatorHost] is set, otherwise null.
  ///
  /// Priority order:
  /// 1. Zone.current[envSymbol] (for package tests using runZoned)
  /// 2. [environmentOverride] parameter (for cross-package tests)
  /// 3. Platform.environment (actual system environment)
  ///
  /// Example:
  /// ```dart
  /// final emulatorHost = Environment.getFirestoreEmulatorHost();
  /// if (emulatorHost != null) {
  ///   print('Using Firestore emulator at $emulatorHost');
  /// }
  /// ```
  static String? getFirestoreEmulatorHost([
    Map<String, String>? environmentOverride,
  ]) {
    // First check Zone (for package tests)
    final zoneEnv = Zone.current[envSymbol] as Map<String, String>?;
    if (zoneEnv != null) {
      return zoneEnv[firestoreEmulatorHost];
    }

    // Then check environmentOverride (for cross-package tests)
    if (environmentOverride != null) {
      return environmentOverride[firestoreEmulatorHost];
    }

    // Finally fall back to actual environment variables
    return Platform.environment[firestoreEmulatorHost];
  }

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
  static bool isFirestoreEmulatorEnabled([
    Map<String, String>? environmentOverride,
  ]) {
    return getFirestoreEmulatorHost(environmentOverride) != null;
  }
}
