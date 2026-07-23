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
      Header.ascii(entry.key, entry.value),
  ], endStream: bodyBytes.isEmpty);

  if (bodyBytes.isNotEmpty) stream.sendData(bodyBytes, endStream: true);

  final statusCompleter = Completer<int>();
  final bodyController = StreamController<List<int>>();
  final responseHeaders = <String, String>{};

  stream.incomingMessages.listen(
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
      if (!bodyController.isClosed) bodyController.close();
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!statusCompleter.isCompleted) {
        statusCompleter.completeError(error, stackTrace);
      }
      bodyController.addError(error, stackTrace);
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

class _PooledConnection {
  _PooledConnection(this.transportFuture);
  final Future<ClientTransportConnection> transportFuture;
  int inFlight = 0;

  /// Set once a send() on this connection throws - matches Node
  /// ClientPool's RST_STREAM handling: stop routing NEW work here, but let
  /// requests already in flight finish. Actually removing/closing failed
  /// connections is deferred (see [Http2ClientPool] doc comment) - this
  /// pass only stops reusing them.
  bool failed = false;
}

/// Sends every request as a stream on a pool of shared HTTP/2 connections
/// to [host], mirroring nodejs-firestore's `ClientPool`
/// (dev/src/pool.ts): packs load onto the most-full connection under
/// [maxStreamsPerConnection] (to keep others idle) rather than spreading
/// evenly, opens a new connection once all existing ones are full, and
/// stops routing new work to a connection once it's shown a
/// connection-level failure.
///
/// Known gaps vs. Node's ClientPool, deferred to a follow-up:
/// - No idle-capacity garbage collection - connections opened during a
///   burst are never closed once traffic quiets down.
/// - No graceful terminate() draining - close() does not wait for
///   in-flight requests before finishing connections.
///
/// Pure transport: no auth. Wrapped with googleapis_auth's client helpers
/// below (see [FirestoreHttpClient._createClient]) for a refreshing
/// AuthClient.
class Http2ClientPool extends BaseClient {
  Http2ClientPool(this.host, {this.maxStreamsPerConnection = 100})
    : _handshakeGate = Pool(_maxConcurrentHandshakes);

  final String host;
  final int maxStreamsPerConnection;

  // Caps concurrent in-flight TCP+TLS handshakes, independent of how many
  // total connections the pool ends up needing - protects against a huge,
  // unpredictable production burst opening hundreds of handshakes at once.
  static const _maxConcurrentHandshakes = 50;
  final Pool _handshakeGate;

  final List<_PooledConnection> _connections = [];

  Future<ClientTransportConnection> _openConnection() {
    return _handshakeGate.withResource(() async {
      final socket = await SecureSocket.connect(
        host,
        443,
        supportedProtocols: ['h2'],
      );
      if (socket.selectedProtocol != 'h2') {
        throw StateError(
          'Server did not negotiate HTTP/2 (got ${socket.selectedProtocol})',
        );
      }
      return ClientTransportConnection.viaSocket(socket);
    });
  }

  /// Picks the most-full connection under capacity, or reserves a new one.
  ///
  /// Deliberately synchronous (no `await`), so it runs atomically with
  /// respect to other concurrent calls without needing a lock - otherwise
  /// many callers arriving before the first connection finishes dialing
  /// would all see an empty pool and each open their own (a thundering
  /// herd), instead of piling onto the one already being established.
  ///
  /// "Most-full" (not least-loaded) selection matches Node ClientPool's
  /// intent: pack load onto fewer connections so others stay idle and
  /// become eligible for future cleanup, rather than spreading evenly.
  _PooledConnection _acquireConnection() {
    _PooledConnection? selected;
    for (final conn in _connections) {
      if (conn.failed) continue;
      if (conn.inFlight < maxStreamsPerConnection &&
          (selected == null || conn.inFlight > selected.inFlight)) {
        selected = conn;
      }
    }
    if (selected != null) return selected;

    final pooled = _PooledConnection(_openConnection());
    _connections.add(pooled);
    return pooled;
  }

  /// The number of connections currently in the pool (including any that
  /// have been marked [_PooledConnection.failed] but not yet cleaned up).
  int get connectionCount => _connections.length;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final conn = _acquireConnection();
    conn.inFlight++;
    try {
      final transport = await conn.transportFuture;
      return await _sendOverHttp2(transport, request);
    } catch (e) {
      // Broader than Node's RST_STREAM-specific regex match - our own
      // testing surfaced multiple distinct http2-level error shapes
      // (REFUSED_STREAM, "forcefully terminated"/CONNECT_ERROR), so any
      // thrown error here is treated as a signal this connection is no
      // longer trustworthy for new work.
      conn.failed = true;
      rethrow;
    } finally {
      conn.inFlight--;
    }
  }

  @override
  void close() {
    for (final conn in _connections) {
      conn.transportFuture.then((t) => t.finish());
    }
  }
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

  /// Creates the appropriate HTTP client based on emulator configuration.
  Future<googleapis_auth.AuthClient> _createClient() async {
    if (_isUsingEmulator) {
      // Emulator: Create unauthenticated client. The emulator has no TLS
      // and doesn't negotiate HTTP/2, so this stays on plain HTTP/1.1.
      return EmulatorClient(Client());
    }

    // Production: every request multiplexes over a pool of shared HTTP/2
    // connections instead of dart:io's default one-connection-per-request
    // HTTP/1.1 behavior. googleapis_auth wraps this transport with its
    // token-refresh logic - the pool itself has no auth concept.
    final transport = Http2ClientPool(_settings.host ?? 'firestore.googleapis.com');

    final serviceAccountCreds = credential.serviceAccountCredentials;
    if (serviceAccountCreds != null) {
      return googleapis_auth.clientViaServiceAccount(
        serviceAccountCreds,
        ['https://www.googleapis.com/auth/cloud-platform'],
        baseClient: transport,
      );
    }

    // Fall back to Application Default Credentials
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
  }
}
