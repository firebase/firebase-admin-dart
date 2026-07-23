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
import 'dart:convert';
import 'dart:io';

import 'package:google_cloud/constants.dart' as google_cloud;
import 'package:google_cloud/google_cloud.dart' as google_cloud;
import 'package:google_cloud_firestore_v1/firestore.dart' as firestore_v1;
import 'package:googleapis_auth/auth_io.dart' as googleapis_auth;
import 'package:http/http.dart';
import 'package:http2/transport.dart' hide Settings;
import 'package:meta/meta.dart';
import 'package:pool/pool.dart';

import '../google_cloud_firestore.dart';
import 'environment.dart';
import 'firestore_exception.dart';

/// Internal HTTP request implementation that wraps a stream.
///
/// This is used by [EmulatorClient] to create modified requests with
/// updated headers while preserving the request body stream.
class _RequestImpl extends BaseRequest {
  _RequestImpl(super.method, super.url, [Stream<List<int>>? stream])
    : _stream = stream ?? const Stream.empty();

  final Stream<List<int>> _stream;

  @override
  ByteStream finalize() {
    super.finalize();
    return ByteStream(_stream);
  }
}

/// HTTP client wrapper that adds Firebase emulator authentication.
///
/// This client wraps another HTTP client and automatically adds the
/// `Authorization: Bearer owner` header to all requests, which is required
/// when communicating with Firebase emulators (Auth, Firestore, etc.).
///
/// Firebase emulators expect this specific bearer token to grant full
/// admin privileges for local development and testing.
@internal
class EmulatorClient extends BaseClient implements googleapis_auth.AuthClient {
  EmulatorClient(this.client);

  final Client client;

  @override
  googleapis_auth.AccessCredentials get credentials =>
      throw UnimplementedError();

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final modifiedRequest = _RequestImpl(
      request.method,
      request.url,
      request.finalize(),
    );
    modifiedRequest.headers.addAll(request.headers);
    modifiedRequest.headers['Authorization'] = 'Bearer owner';

    return client.send(modifiedRequest);
  }

  @override
  void close() => client.close();
}

/// Sends [request] as a single HTTP/2 stream on [transport], translating
/// between `BaseRequest`/`StreamedResponse` and http2's frames.
Future<StreamedResponse> _sendOverHttp2(
  ClientTransportConnection transport,
  BaseRequest request,
) async {
  final bodyBytes = await request.finalize().toBytes();
  final path = request.url.hasQuery
      ? '${request.url.path}?${request.url.query}'
      : request.url.path;

  final stream = transport.makeRequest([
    Header.ascii(':method', request.method),
    Header.ascii(':scheme', 'https'),
    Header.ascii(':authority', request.url.host),
    Header.ascii(':path', path),
    for (final entry in request.headers.entries)
      Header.ascii(entry.key.toLowerCase(), entry.value),
  ], endStream: bodyBytes.isEmpty);

  if (bodyBytes.isNotEmpty) stream.sendData(bodyBytes, endStream: true);

  final statusCompleter = Completer<int>();
  late final StreamSubscription<StreamMessage> subscription;
  final bodyController = StreamController<List<int>>(
    onCancel: () => subscription.cancel(),
  );
  final responseHeaders = <String, String>{};

  subscription = stream.incomingMessages.listen(
    (message) {
      if (message is HeadersStreamMessage) {
        for (final header in message.headers) {
          final name = ascii.decode(header.name);
          final value = ascii.decode(header.value);
          if (name == ':status') {
            if (!statusCompleter.isCompleted) {
              statusCompleter.complete(int.parse(value));
            }
          } else {
            responseHeaders[name] = value;
          }
        }
      } else if (message is DataStreamMessage) {
        bodyController.add(message.bytes);
      }
    },
    onDone: () {
      if (!statusCompleter.isCompleted) {
        statusCompleter.completeError(
          StateError('Stream closed before a response status was received'),
        );
      }
      if (!bodyController.isClosed) bodyController.close();
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!statusCompleter.isCompleted) {
        statusCompleter.completeError(error, stackTrace);
      }
      bodyController.addError(error, stackTrace);
      if (!bodyController.isClosed) bodyController.close();
    },
    cancelOnError: true,
  );

  final statusCode = await statusCompleter.future;
  return StreamedResponse(
    bodyController.stream,
    statusCode,
    headers: responseHeaders,
    request: request,
  );
}

class _PooledResource<T> {
  _PooledResource(this.future);
  final Future<T> future;
  int inFlight = 0;
  bool failed = false;
}

/// A pool of resources of type [T], mirroring nodejs-firestore's
/// `ClientPool` (dev/src/pool.ts): packs load onto the most-full resource
/// under [maxConcurrentOperations] instead of spreading evenly, opens a
/// new resource once existing ones are full, retires a resource once
/// [run] reports it failed, and garbage collects idle resources past
/// [maxIdleResources].
@internal
class ClientPool<T> {
  ClientPool(
    Future<T> Function() create, {
    required this.maxConcurrentOperations,
    required Future<void> Function(T resource) destroy,
    this.maxIdleResources = 1,
  }) : _create = create,
       _destroy = destroy;

  final Future<T> Function() _create;
  final Future<void> Function(T resource) _destroy;
  final int maxConcurrentOperations;
  final int maxIdleResources;

  final _resources = <_PooledResource<T>>[];
  var _terminated = false;
  Completer<void>? _drained;

  @visibleForTesting
  int get size => _resources.length;

  @visibleForTesting
  int get opCount =>
      _resources.fold(0, (total, resource) => total + resource.inFlight);

  /// Runs [operation] on an available (or newly created) resource.
  Future<R> run<R>(Future<R> Function(T resource) operation) async {
    if (_terminated) {
      throw StateError('This pool has already been terminated.');
    }

    final pooled = _acquire();
    pooled.inFlight++;
    try {
      return await operation(await pooled.future);
    } catch (_) {
      pooled.failed = true;
      rethrow;
    } finally {
      pooled.inFlight--;
      if (_terminated) {
        _maybeCompleteDrain();
      } else {
        await _collectIfIdle(pooled);
      }
    }
  }

  // Synchronous (no `await`), so concurrent calls can't race each other
  // into both creating a resource before either sees the other's.
  _PooledResource<T> _acquire() {
    _PooledResource<T>? selected;
    for (final resource in _resources) {
      if (resource.failed) continue;
      if (resource.inFlight < maxConcurrentOperations &&
          (selected == null || resource.inFlight > selected.inFlight)) {
        selected = resource;
      }
    }
    if (selected != null) return selected;

    final resource = _PooledResource<T>(_create());
    _resources.add(resource);
    return resource;
  }

  Future<void> _collectIfIdle(_PooledResource<T> resource) async {
    if (resource.inFlight > 0) return;
    if (!resource.failed && !_hasExcessIdleCapacity) return;

    _resources.remove(resource);
    try {
      await _destroy(await resource.future);
    } catch (_) {
      // Best-effort: a failure here must not shadow the caller's own
      // request error, since this runs inside run()'s finally block.
    }
  }

  bool get _hasExcessIdleCapacity {
    final idleCapacity = _resources.fold(
      0,
      (total, resource) => total + (maxConcurrentOperations - resource.inFlight),
    );
    return idleCapacity > maxIdleResources * maxConcurrentOperations;
  }

  void _maybeCompleteDrain() {
    final drained = _drained;
    if (drained != null && !drained.isCompleted && opCount == 0) {
      drained.complete();
    }
  }

  /// Waits for in-flight operations to finish, then destroys every
  /// resource in the pool. No further operations can run afterward.
  Future<void> terminate() async {
    _terminated = true;

    if (opCount > 0) {
      _drained = Completer<void>();
      await _drained!.future;
    }

    for (final resource in _resources) {
      try {
        await _destroy(await resource.future);
      } catch (_) {
        // Best-effort: one resource failing to close shouldn't stop the
        // rest from being destroyed.
      }
    }
    _resources.clear();
  }
}

/// Sends every request as a stream on a pool of shared HTTP/2 connections,
/// dialed per-host - see [ClientPool]. Multi-host so it's safe to use for
/// every request an [googleapis_auth.AuthClient] might send, not just the
/// actual Firestore calls: credential negotiation (OAuth2 token endpoint,
/// WIF/OIDC token exchange) targets different hosts entirely, and each
/// gets its own pool dialed to the right place instead of reusing a
/// connection meant for somewhere else.
///
/// Pure transport, no auth: wrapped with googleapis_auth's client helpers
/// in [FirestoreHttpClient._createClient] for a refreshing
/// [googleapis_auth.AuthClient].
class Http2Client extends BaseClient {
  Http2Client({this.maxStreamsPerConnection = 100});

  final int maxStreamsPerConnection;
  final _pools = <String, ClientPool<ClientTransportConnection>>{};

  // Caps concurrent in-flight TCP+TLS handshakes across all hosts,
  // independent of how many total connections any one pool needs.
  static final _handshakeGate = Pool(50);

  // Synchronous (no `await`), so concurrent requests to a new host can't
  // race each other into creating two pools for the same host.
  ClientPool<ClientTransportConnection> _poolFor(String host) {
    return _pools.putIfAbsent(
      host,
      () => ClientPool<ClientTransportConnection>(
        () => _handshakeGate.withResource(() => _dial(host)),
        maxConcurrentOperations: maxStreamsPerConnection,
        destroy: (transport) => transport.finish(),
      ),
    );
  }

  static Future<ClientTransportConnection> _dial(String host) async {
    final socket = await SecureSocket.connect(
      host,
      443,
      supportedProtocols: ['h2'],
    );
    if (socket.selectedProtocol != 'h2') {
      socket.destroy();
      throw StateError(
        'Server did not negotiate HTTP/2 (got ${socket.selectedProtocol})',
      );
    }
    return ClientTransportConnection.viaSocket(socket);
  }

  /// The number of connections currently pooled, across all hosts.
  int get connectionCount =>
      _pools.values.fold(0, (total, pool) => total + pool.size);

  @override
  Future<StreamedResponse> send(BaseRequest request) => _poolFor(
    request.url.host,
  ).run((transport) => _sendOverHttp2(transport, request));

  /// Waits for in-flight requests to finish, then closes every connection.
  ///
  /// Unlike [close] (constrained by `http.Client`'s synchronous signature),
  /// this can be awaited by callers who hold a concrete [Http2Client].
  Future<void> terminate() async {
    for (final pool in _pools.values) {
      await pool.terminate();
    }
  }

  @override
  void close() => unawaited(terminate());
}

/// HTTP client wrapper for Firestore API operations.
///
/// Provides authenticated API access with automatic project ID discovery.
class FirestoreHttpClient {
  FirestoreHttpClient({required this.credential, required Settings settings})
    : _settings = settings;

  final Credential credential;
  final Settings _settings;

  String? _cachedProjectId;

  String? get cachedProjectId => _cachedProjectId;

  /// Synchronously resolves the project ID from environment variables or the
  /// credentials file, without any network I/O.
  ///
  /// Checks (in order): [cachedProjectId], Zone env ([envSymbol]),
  /// [Settings.environmentOverride], real environment variables, then the
  /// credentials file at `GOOGLE_APPLICATION_CREDENTIALS`.
  ///
  /// Returns `null` when only async strategies (gcloud CLI, metadata server)
  /// could succeed; those are handled by [_run] and cached in [cachedProjectId].
  String? getProjectId() {
    if (_cachedProjectId != null) return _cachedProjectId;

    final zoneEnv = Zone.current[envSymbol] as Map<String, String>?;
    String? discovered;

    if (zoneEnv != null) {
      for (final envKey in google_cloud.projectIdEnvironmentVariableOptions) {
        final value = zoneEnv[envKey];
        if (value != null) {
          discovered = value;
          break;
        }
      }
    } else {
      final envOverride = _settings.environmentOverride;
      if (envOverride != null) {
        for (final envKey in google_cloud.projectIdEnvironmentVariableOptions) {
          final value = envOverride[envKey];
          if (value != null) {
            discovered = value;
            break;
          }
        }
      } else {
        discovered =
            google_cloud.projectIdFromEnvironmentVariables() ??
            google_cloud.projectIdFromCredentialsFile();
      }
    }

    return discovered != null ? (_cachedProjectId = discovered) : null;
  }

  /// Gets the Firestore API host URL based on emulator configuration.
  Uri get _firestoreApiHost {
    final emulatorHost = Environment.getFirestoreEmulatorHost(
      _settings.environmentOverride,
    );

    if (emulatorHost != null) {
      return Uri.http(emulatorHost, '/');
    }

    return Uri.https(_settings.host ?? 'firestore.googleapis.com', '/');
  }

  /// Checks if the Firestore emulator is enabled via environment variable.
  bool get _isUsingEmulator =>
      Environment.isFirestoreEmulatorEnabled(_settings.environmentOverride);

  /// Lazy-initialized HTTP client that's cached for reuse.
  late final Future<googleapis_auth.AuthClient> _client = _createClient();

  // googleapis_auth never closes a caller-supplied baseClient, so
  // close() must reach this transport itself.
  Http2Client? _transport;

  /// Creates the appropriate HTTP client based on emulator configuration.
  Future<googleapis_auth.AuthClient> _createClient() async {
    if (_isUsingEmulator) {
      // Emulator: plain HTTP/1.1, matching nodejs-firestore's REST-mode
      // behavior (its gRPC mode uses HTTP/2, but this SDK is REST-only).
      return EmulatorClient(Client());
    }

    final transport = Http2Client();
    _transport = transport;

    final serviceAccountCreds = credential.serviceAccountCredentials;
    if (serviceAccountCreds != null) {
      return googleapis_auth.clientViaServiceAccount(
        serviceAccountCreds,
        ['https://www.googleapis.com/auth/cloud-platform'],
        baseClient: transport,
      );
    }

    return googleapis_auth.clientViaApplicationDefaultCredentials(
      scopes: ['https://www.googleapis.com/auth/cloud-platform'],
      baseClient: transport,
    );
  }

  Future<R> _run<R>(
    Future<R> Function(googleapis_auth.AuthClient client, String projectId) fn,
  ) async {
    final client = await _client;

    final projectId =
        getProjectId() ??
        _settings.projectId ??
        await google_cloud.computeProjectId();

    _cachedProjectId = projectId;

    return firestoreGuard(() => fn(client, projectId));
  }

  /// Executes a Firestore v1 API operation with automatic projectId injection.
  Future<R> v1<R>(
    Future<R> Function(firestore_v1.Firestore api, String projectId) fn,
  ) => _run(
    (client, projectId) => fn(
      firestore_v1.Firestore(client: client, endPoint: _firestoreApiHost),
      projectId,
    ),
  );

  /// Closes the HTTP client and releases resources.
  Future<void> close() async {
    final client = await _client;
    client.close();
    await _transport?.terminate();
  }
}
