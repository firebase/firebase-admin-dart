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
enum FirebaseServiceType {
  appCheck(name: 'app-check'),
  auth(name: 'auth'),
  firestore(name: 'firestore'),
  messaging(name: 'messaging'),
  remoteConfig(name: 'remote-config'),
  securityRules(name: 'security-rules'),
  functions(name: 'functions'),
  storage(name: 'storage');

  const FirebaseServiceType({required this.name});

  final String name;
}

/// Base class for all Firebase services.
///
/// All Firebase services (Auth, Messaging, Firestore, etc.) implement this
/// interface to enable proper lifecycle management.
///
/// Services are automatically registered with the [FirebaseApp] when first
/// accessed via factory constructors. When the app is closed via
/// [FirebaseApp.close], all registered services have their [delete] method
/// called to clean up resources.
///
/// Example implementation:
/// ```dart
/// class MyService implements FirebaseService {
///   factory MyService(FirebaseApp app) {
///     return app.getOrInitService(
///       'my-service',
///       (app) => MyService._(app),
///     ) as MyService;
///   }
///
///   MyService._(this.app);
///
///   @override
///   final FirebaseApp app;
///
///   @override
///   Future<void> delete() async {
///     // Cleanup logic here
///   }
/// }
/// ```
@internal
abstract class FirebaseService {
  FirebaseService(this.app);

  /// The Firebase app this service is associated with.
  final FirebaseApp app;

  /// Cleans up resources used by this service.
  ///
  /// This method is called automatically when [FirebaseApp.close] is called
  /// on the parent app. Services should override this to release any held
  /// resources such as:
  /// - Network connections
  /// - File handles
  /// - Cached data
  /// - Subscriptions or listeners
  Future<void> delete();
}
