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

/// Represents a Firebase app instance.
///
/// Each app is associated with a Firebase project and has its own
/// configuration options and services.
class FirebaseApp {
  FirebaseApp({
    required this.options,
    required this.name,
    required this.wasInitializedFromEnv,
  });

  static final _defaultAppRegistry = AppRegistry.getDefault();

  /// Initializes a Firebase app.
  ///
  /// Creates a new app instance or returns an existing one if already
  /// initialized with the same configuration.
  ///
  /// If [options] is not provided, the app will be auto-initialized from
  /// the FIREBASE_CONFIG environment variable.
  ///
  /// [name] defaults to an internal string if not specified.
  static FirebaseApp initializeApp({AppOptions? options, String? name}) {
    return _defaultAppRegistry.initializeApp(options: options, name: name);
  }

  /// Returns the default Firebase app instance.
  ///
  /// This is a convenience getter equivalent to `getApp()`.
  ///
  /// Throws `FirebaseAppException` if the default app has not been initialized.
  static FirebaseApp get instance => getApp();

  /// Gets an existing Firebase app by name.
  ///
  /// Returns the app with the given [name], or the default app if [name]
  /// is not provided.
  ///
  /// Throws `FirebaseAppException` if no app exists with the given name.
  static FirebaseApp getApp([String? name]) {
    return _defaultAppRegistry.getApp(name);
  }

  /// Returns a list of all initialized Firebase apps.
  static List<FirebaseApp> get apps {
    return _defaultAppRegistry.apps;
  }

  /// Deletes the specified Firebase app and cleans up its resources.
  ///
  /// Throws `FirebaseAppException` if the app does not exist.
  static Future<void> deleteApp(FirebaseApp app) {
    return _defaultAppRegistry.deleteApp(app);
  }

  /// The name of this app.
  ///
  /// The default app's name is `[DEFAULT]`.
  final String name;

  /// The configuration options for this app.
  final AppOptions options;

  /// Whether this app was initialized from environment variables.
  ///
  /// When true, indicates the app was created via `initializeApp()` without
  /// explicit options, loading config from environment instead.
  final bool wasInitializedFromEnv;

  /// Whether this app has been deleted.
  bool _isDeleted = false;

  /// Returns true if this app has been deleted.
  bool get isDeleted => _isDeleted;

  @override
  String toString() =>
      'FirebaseApp('
      'name: $name, '
      'projectId: $projectId, '
      'wasInitializedFromEnv: $wasInitializedFromEnv, '
      'isDeleted: $_isDeleted)';

  /// Map of service name to service instance for caching.
  final Map<String, FirebaseService> _services = {};

  /// The HTTP client for this app.
  ///
  /// Uses the client from options if provided, otherwise creates a default one.
  /// Nullable to avoid triggering lazy initialization during cleanup.
  Future<googleapis_auth.AuthClient>? _httpClient;

  Future<googleapis_auth.AuthClient> _createDefaultClient() async {
    final scopes = [
      auth3.IdentityToolkitApi.cloudPlatformScope,
      auth3.IdentityToolkitApi.firebaseScope,
      ...options.additionalScopes,
    ];
    final credential =
        options.credential ?? Credential.fromApplicationDefaultCredentials();
    return FirebaseUserAgentClient(await credential.createClient(scopes));
  }

  /// The authenticated HTTP client for this app.
  ///
  /// Lazily initialized on first access. Returns the client provided via
  /// [AppOptions.httpClient] if one was supplied, otherwise creates a default
  /// client using the app's [AppOptions.credential] and the SDK's required
  /// scopes plus any [AppOptions.additionalScopes].
  ///
  /// Use this when you need to call Google APIs not directly supported by this
  /// SDK — for example, passing the client to a `googleapis` package API for
  /// advanced Cloud Storage operations (resumable uploads, byte-range fetches,
  /// etc.).
  ///
  /// **Lifecycle:** The client is closed automatically when [close] is called,
  /// unless it was provided via [AppOptions.httpClient] — in that case you own
  /// its lifecycle and must close it yourself.
  ///
  /// **Scopes:** The default client is granted `cloud-platform` and `firebase`
  /// scopes, which cover most Google APIs. If you need additional scopes,
  /// set [AppOptions.additionalScopes] — or provide a fully configured client
  /// via [AppOptions.httpClient].
  ///
  /// Example:
  /// ```dart
  /// final storageApi = StorageApi(await app.client);
  /// final object = await storageApi.objects.get(bucket, objectName);
  /// ```
  Future<googleapis_auth.AuthClient> get client {
    return _httpClient ??= options.httpClient != null
        ? Future.value(options.httpClient!)
        : _createDefaultClient();
  }

  @internal
  Future<String> getProjectId({
    String? projectIdOverride,
    Map<String, String>? environment,
  }) async {
    final env = environment ?? Zone.current[envSymbol] as Map<String, String>?;
    if (env != null) {
      for (final envKey in google_cloud.projectIdEnvironmentVariableOptions) {
        final value = env[envKey];
        if (value != null) return value;
      }
    }

    final explicitProjectId = projectIdOverride ?? options.projectId;
    if (explicitProjectId != null) return explicitProjectId;

    return google_cloud.computeProjectId();
  }

  /// Returns the explicitly configured project ID, if available.
  ///
  /// This is a simple synchronous getter that returns the project ID from
  /// [AppOptions.projectId] if it was explicitly set. Returns null if not set.
  ///
  /// Services that need project ID should use their own discovery mechanism
  /// via `ProjectIdProvider.discoverProjectId()` which handles async metadata
  /// service lookup when explicit projectId is not available.
  String? get projectId => options.projectId;

  /// Gets or initializes a service for this app.
  ///
  /// Services are cached per app instance. The first call with a given [name]
  /// will invoke [init] to create the service. Subsequent calls return the
  /// cached instance.
  @internal
  T getOrInitService<T extends FirebaseService>(
    String name,
    T Function(FirebaseApp) init,
  ) {
    _checkDestroyed();
    if (!_services.containsKey(name)) {
      _services[name] = init(this);
    }
    return _services[name]! as T;
  }

  /// Gets the App Check service instance for this app.
  ///
  /// Returns a cached instance if one exists, otherwise creates a new one.
  AppCheck appCheck() => AppCheck.internal(this);

  /// Gets the Auth service instance for this app.
  ///
  /// Returns a cached instance if one exists, otherwise creates a new one.
  Auth auth() => Auth.internal(this);

  /// Gets the Firestore service instance for this app.
  ///
  /// Returns a cached instance if one exists, otherwise creates a new one.
  /// Optional [settings] are only applied when creating a new instance.
  ///
  /// For multi-database support, use [databaseId] to specify a named database.
  /// Default is '(default)'.
  google_cloud_firestore.Firestore firestore({
    google_cloud_firestore.Settings? settings,
    String databaseId = kDefaultDatabaseId,
  }) {
    final service = Firestore.internal(this);

    if (settings != null) {
      return service.initializeDatabase(databaseId, settings);
    }
    return service.getDatabase(databaseId);
  }

  /// Gets the Messaging service instance for this app.
  ///
  /// Returns a cached instance if one exists, otherwise creates a new one.
  Messaging messaging() => Messaging.internal(this);

  /// Gets the Remote Config service instance for this app.
  ///
  /// Returns a cached instance if one exists, otherwise creates a new one.
  RemoteConfig remoteConfig() => RemoteConfig.internal(this);

  /// Gets the Security Rules service instance for this app.
  ///
  /// Returns a cached instance if one exists, otherwise creates a new one.
  SecurityRules securityRules() => SecurityRules.internal(this);

  /// Gets the Functions service instance for this app.
  ///
  /// Returns a cached instance if one exists, otherwise creates a new one.
  Functions functions() => Functions.internal(this);

  /// Gets the Storage service instance for this app.
  ///
  /// Returns a cached instance if one exists, otherwise creates a new one.
  Storage storage() => Storage.internal(this);

  /// Closes this app and cleans up all associated resources.
  ///
  /// This method:
  /// 1. Removes the app from the global registry
  /// 2. Calls [FirebaseService.delete] on all registered services
  /// 3. Closes the HTTP client (if it was created by the SDK)
  /// 4. Marks the app as deleted
  ///
  /// After calling this method, the app instance can no longer be used.
  /// Any subsequent calls to the app or its services will throw a
  /// `FirebaseAppException` with code 'app-deleted'.
  ///
  /// Note: If you provided a custom [AppOptions.httpClient], it will NOT
  /// be closed automatically. You are responsible for closing it.
  ///
  /// Example:
  /// ```dart
  /// final app = FirebaseApp.initializeApp(options: options);
  /// // Use app...
  /// await app.close();
  /// // App can no longer be used
  /// ```
  Future<void> close() async {
    _checkDestroyed();

    // Remove from registry
    _defaultAppRegistry.removeApp(name);

    // Delete all services
    await Future.wait(
      _services.values.map((service) {
        return service.delete();
      }),
    );

    _services.clear();

    // Only close client if it was initialized AND we created it (not user-provided)
    if (_httpClient != null && options.httpClient == null) {
      (await _httpClient!).close();
    }

    _isDeleted = true;
  }

  /// Checks if this app has been deleted and throws if so.
  void _checkDestroyed() {
    if (_isDeleted) {
      throw FirebaseAppException(
        AppErrorCode.appDeleted,
        'Firebase app "$name" has already been deleted.',
      );
    }
  }
}
