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

import 'package:google_cloud_firestore_v1/firestore.dart' as firestore_v1;
import 'package:googleapis_auth/auth_io.dart' as googleapis_auth;
import 'package:grpc/grpc.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../credential.dart';
import '../environment.dart';
import '../firestore.dart';
import '../firestore_exception.dart';
import '../generated/google/firestore/v1/document.pb.dart' as pb;
import '../generated/google/firestore/v1/firestore.pb.dart' as pb;
import '../generated/google/firestore/v1/firestore.pbgrpc.dart' as pbgrpc;

/// The access token the Firestore emulator accepts as an admin credential.
@internal
const emulatorAccessToken = 'owner';

/// One bidirectional `google.firestore.v1.Firestore/Listen` call.
///
/// Responses are passed through as the server sends them. In particular, a
/// target the caller may not read arrives as a `TargetChange` of type
/// `REMOVE` with a `cause`, on a stream that stays open: interpreting that is
/// up to the caller.
@internal
abstract interface class ListenStream {
  /// The responses of this call, in order.
  ///
  /// Emits a [FirestoreException] if the call fails, and closes when the call
  /// ends.
  Stream<firestore_v1.ListenResponse> get responses;

  /// Sends [request] on this call.
  void send(firestore_v1.ListenRequest request);

  /// Cancels this call.
  ///
  /// [responses] still delivers the responses and any error already
  /// received, then closes; the cancellation itself adds no error. Calling
  /// [send] afterwards throws a [StateError].
  Future<void> close();
}

/// Opens `Listen` calls against one Firestore database.
@internal
abstract interface class ListenTransport {
  /// Opens a new `Listen` call.
  ///
  /// Failing to connect or authenticate surfaces as an error on
  /// [ListenStream.responses], not as a synchronous throw.
  ListenStream open();

  /// Cancels the open calls and releases the connection.
  ///
  /// Calling [open] afterwards throws a [StateError].
  Future<void> close();
}

/// Where `Listen` calls are sent, resolved the same way as REST requests.
@internal
@immutable
final class ListenEndpoint {
  const ListenEndpoint({
    required this.host,
    required this.port,
    required this.secure,
    required this.isEmulator,
  });

  /// Resolves the endpoint for [settings].
  ///
  /// `FIRESTORE_EMULATOR_HOST` takes precedence over [Settings.host] and is
  /// always reached over plaintext. Otherwise [Settings.ssl] decides whether
  /// the connection uses TLS.
  factory ListenEndpoint.fromSettings(Settings settings) {
    final emulatorHost = Environment.getFirestoreEmulatorHost(
      settings.environmentOverride,
    );
    if (emulatorHost != null) {
      return ListenEndpoint._parse(
        emulatorHost,
        secure: false,
        isEmulator: true,
      );
    }
    return ListenEndpoint._parse(
      settings.host ?? 'firestore.googleapis.com',
      secure: settings.ssl,
      isEmulator: false,
    );
  }

  factory ListenEndpoint._parse(
    String authority, {
    required bool secure,
    required bool isEmulator,
  }) {
    // Parsing as an authority handles `host`, `host:port` and `[::1]:port`.
    final uri = Uri.parse('//$authority');
    return ListenEndpoint(
      host: uri.host,
      port: uri.hasPort ? uri.port : (secure ? 443 : 80),
      secure: secure,
      isEmulator: isEmulator,
    );
  }

  final String host;
  final int port;

  /// Whether the connection uses TLS.
  final bool secure;

  /// Whether this is the Firestore emulator, which takes
  /// [emulatorAccessToken] instead of a real access token.
  final bool isEmulator;

  @override
  bool operator ==(Object other) =>
      other is ListenEndpoint &&
      other.host == host &&
      other.port == port &&
      other.secure == secure &&
      other.isEmulator == isEmulator;

  @override
  int get hashCode => Object.hash(host, port, secure, isEmulator);

  @override
  String toString() =>
      'ListenEndpoint($host:$port, secure: $secure, isEmulator: $isEmulator)';
}

/// The gRPC metadata sent with a `Listen` call on [database]
/// (`projects/{project}/databases/{database}`).
///
/// [headers] (from [Settings.headers]) are added with lower-cased names, as
/// HTTP/2 requires, but never replace the routing or auth entries. Without an
/// [accessToken] there is no `authorization` entry: the transport adds it per
/// call from an [AuthMetadataSource].
@internal
Map<String, String> listenMetadata({
  required String database,
  String? accessToken,
  Map<String, String>? headers,
}) => {
  for (final MapEntry(:key, :value) in (headers ?? const {}).entries)
    if (key.toLowerCase() != 'authorization') key.toLowerCase(): value,
  if (accessToken != null) 'authorization': 'Bearer $accessToken',
  'google-cloud-resource-prefix': database,
  'x-goog-request-params': 'database=$database',
};

/// Converts a failed gRPC call into a [FirestoreException], keeping the
/// exact status code.
///
/// Like [FirestoreException.fromServerError] for REST errors, an unrecognised
/// code yields `unknown` with the raw status (details and trailers included)
/// appended to the message.
@internal
FirestoreException firestoreExceptionFromGrpcError(GrpcError error) {
  final errorCode = FirestoreClientErrorCode.fromStatusCode(error.code);
  final message = error.message;
  return FirestoreException.fromServerError(
    // An unrecognised code has no entry, so it maps to unknown.
    serverErrorCode: errorCode == FirestoreClientErrorCode.unknown
        ? 'UNKNOWN'
        : errorCode.statusCode.name.toUpperCaseSnake(),
    message: message != null && message.isNotEmpty ? message : null,
    rawServerResponse: {
      'error': {
        'code': error.code,
        'message': ?message,
        if (error.details case final details? when details.isNotEmpty)
          'details': [for (final detail in details) detail.toString()],
        if (error.trailers case final trailers? when trailers.isNotEmpty)
          'trailers': trailers,
      },
    },
  );
}

extension on String {
  /// `permissionDenied` to `PERMISSION_DENIED`.
  String toUpperCaseSnake() => replaceAllMapped(
    RegExp('[A-Z]'),
    (match) => '_${match[0]}',
  ).toUpperCase();
}

/// Converts a `google_cloud_firestore_v1` request into its protobuf form via
/// its proto3 JSON representation.
@internal
pb.ListenRequest listenRequestToProto(firestore_v1.ListenRequest request) =>
    pb.ListenRequest()
      ..mergeFromProto3Json(_nullValuesByName(request.toJson()));

/// Spells every `"nullValue": null` in [json] as `"nullValue": "NULL_VALUE"`.
///
/// Both are valid proto3 JSON for a `NullValue` field, but
/// `mergeFromProto3Json` reads `null` as "unset", which would turn a null
/// `Value` (e.g. in a cursor) into an empty one.
Object? _nullValuesByName(Object? json) => switch (json) {
  Map<Object?, Object?>() => {
    for (final MapEntry(:key, :value) in json.entries)
      key: key == 'nullValue' && value == null
          ? 'NULL_VALUE'
          : _nullValuesByName(value),
  },
  List<Object?>() => [for (final value in json) _nullValuesByName(value)],
  _ => json,
};

/// Converts a protobuf response into its `google_cloud_firestore_v1` form via
/// its proto3 JSON representation.
///
/// The `details` of a `TargetChange.cause` are dropped: rendering an `Any` as
/// JSON needs its type generated and registered, which Firestore's error
/// detail types are not. Watch only reads the cause's code and message.
@internal
firestore_v1.ListenResponse listenResponseFromProto(
  pb.ListenResponse response,
) {
  if (response.targetChange.cause.details.isNotEmpty) {
    response = response.deepCopy()..targetChange.cause.details.clear();
  }
  final json = _jsonObject(response.toProto3Json())! as Map<String, Object?>;
  if (json case {
    'documentChange': {
      'document': {'fields': final Map<String, Object?> fields},
    },
  }) {
    _restoreValues(response.documentChange.document.fields, fields);
  }
  return firestore_v1.ListenResponse.fromJson(json);
}

/// Puts back what `toProto3Json` loses from the [values] rendered in [json]:
/// a set but empty `bytesValue` (omitted, leaving a `Value` of no kind) and
/// the sign of a `-0.0` `doubleValue`.
void _restoreValues(Map<String, pb.Value> values, Map<String, Object?> json) {
  for (final MapEntry(:key, :value) in values.entries) {
    if (json[key] case final Map<String, Object?> valueJson) {
      _restoreValue(value, valueJson);
    }
  }
}

void _restoreValue(pb.Value value, Map<String, Object?> json) {
  switch (value.whichValueType()) {
    case pb.Value_ValueType.bytesValue when value.bytesValue.isEmpty:
      json['bytesValue'] = '';
    case pb.Value_ValueType.doubleValue
        when value.doubleValue == 0 && value.doubleValue.isNegative:
      json['doubleValue'] = -0.0;
    case pb.Value_ValueType.mapValue:
      if (json case {
        'mapValue': {'fields': final Map<String, Object?> fields},
      }) {
        _restoreValues(value.mapValue.fields, fields);
      }
    case pb.Value_ValueType.arrayValue:
      if (json case {'arrayValue': {'values': final List<Object?> values}}) {
        for (final (index, element) in value.arrayValue.values.indexed) {
          if (values[index] case final Map<String, Object?> elementJson) {
            _restoreValue(element, elementJson);
          }
        }
      }
    default:
  }
}

/// Retypes the maps in proto3 JSON as `Map<String, Object?>`.
///
/// `toProto3Json` builds map fields (such as `Document.fields`) as
/// `Map<dynamic, dynamic>`, which the `google_cloud_firestore_v1` decoders
/// reject.
Object? _jsonObject(Object? json) => switch (json) {
  Map<Object?, Object?>() => <String, Object?>{
    for (final MapEntry(:key, :value) in json.entries)
      key! as String: _jsonObject(value),
  },
  List<Object?>() => [for (final value in json) _jsonObject(value)],
  _ => json,
};

const _scopes = ['https://www.googleapis.com/auth/cloud-platform'];

/// The channel credentials for [endpoint]: TLS unless it is plaintext.
@internal
ChannelCredentials channelCredentialsFor(ListenEndpoint endpoint) =>
    endpoint.secure
    ? const ChannelCredentials.secure()
    : const ChannelCredentials.insecure();

/// Supplies the auth metadata for a `Listen` call: `authorization`, plus
/// `x-goog-user-project` when the credential names a quota project.
typedef AuthMetadataSource = Future<Map<String, String>> Function();

/// Access tokens from the googleapis_auth client the REST path builds for a
/// [Credential]: a service account client for service account credentials,
/// otherwise Application Default Credentials (any kind googleapis_auth
/// supports, including external accounts).
///
/// The client is created on the first [call], not on construction, and is
/// recreated by the next call if creating it fails. Each call reads the
/// auth headers the client would attach to a request, so googleapis_auth's
/// own expiry tracking decides when to refresh the token; no network I/O
/// happens while it is still valid.
@internal
final class CredentialAccessTokens {
  CredentialAccessTokens(Credential credential)
    : this.withClientFactory(
        (baseClient) => _createAuthClient(credential, baseClient),
      );

  /// Creates the googleapis_auth client with `createClient`, which must use
  /// the given `baseClient` for its requests.
  @visibleForTesting
  CredentialAccessTokens.withClientFactory(this._createClient);

  final Future<googleapis_auth.AuthClient> Function(http.Client baseClient)
  _createClient;
  final _baseClient = _TokenCaptureClient();
  Future<googleapis_auth.AuthClient>? _client;

  static Future<googleapis_auth.AuthClient> _createAuthClient(
    Credential credential,
    http.Client baseClient,
  ) {
    final serviceAccount = credential.serviceAccountCredentials;
    if (serviceAccount != null) {
      return googleapis_auth.clientViaServiceAccount(
        serviceAccount,
        _scopes,
        baseClient: baseClient,
      );
    }
    return googleapis_auth.clientViaApplicationDefaultCredentials(
      scopes: _scopes,
      baseClient: baseClient,
    );
  }

  /// Returns the auth metadata for a call, with a current access token.
  Future<Map<String, String>> call() async {
    final clientFuture = _client ??= _createClient(_baseClient);
    final googleapis_auth.AuthClient client;
    try {
      client = await clientFuture;
    } catch (_) {
      if (identical(_client, clientFuture)) _client = null;
      rethrow;
    }
    final response = await client.get(_TokenCaptureClient.captureUri);
    final metadata = {
      for (final name in _TokenCaptureClient.capturedHeaders)
        name: ?response.headers['${_TokenCaptureClient.capturePrefix}$name'],
    };
    if (!(metadata['authorization'] ?? '').startsWith('Bearer ')) {
      throw StateError('The credential did not supply a bearer token.');
    }
    return metadata;
  }

  /// Closes the googleapis_auth client, if one was created.
  Future<void> close() async {
    final client = _client;
    _client = null;
    try {
      if (client != null) (await client).close();
    } catch (_) {
      // Creating the client failed, so there is nothing to close.
    } finally {
      _baseClient.close();
    }
  }
}

/// The base client handed to googleapis_auth: token requests go to the
/// network, while requests to [captureUri] are answered locally with the
/// [capturedHeaders] googleapis_auth attached echoed back, each name
/// prefixed with [capturePrefix].
final class _TokenCaptureClient extends http.BaseClient {
  static final captureUri = Uri.https('listen-token.invalid', '/');
  static const capturePrefix = 'x-captured-';

  /// The headers googleapis_auth attaches that the call needs. Others it
  /// may set, such as `user-agent`, are left to `package:grpc`.
  static const capturedHeaders = ['authorization', 'x-goog-user-project'];

  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url != captureUri) return _inner.send(request);
    return http.StreamedResponse(
      const Stream.empty(),
      200,
      headers: {
        for (final MapEntry(:key, :value) in request.headers.entries)
          if (capturedHeaders.contains(key.toLowerCase()))
            '$capturePrefix${key.toLowerCase()}': value,
      },
      request: request,
    );
  }

  @override
  void close() => _inner.close();
}

/// A [ListenTransport] over a `package:grpc` [ClientChannel].
///
/// Owns its channel: [close] shuts it down.
@internal
final class GrpcListenTransport implements ListenTransport {
  /// Connects to [endpoint].
  ///
  /// The emulator is sent [emulatorAccessToken]. Otherwise each call is
  /// authorised with the metadata from [authMetadata], when given. [onClose] runs
  /// once the channel is shut down.
  GrpcListenTransport({
    required ListenEndpoint endpoint,
    required String database,
    AuthMetadataSource? authMetadata,
    Map<String, String>? headers,
    Future<void> Function()? onClose,
  }) : _channel = ClientChannel(
         endpoint.host,
         port: endpoint.port,
         options: ChannelOptions(credentials: channelCredentialsFor(endpoint)),
       ),
       _authMetadata = endpoint.isEmulator ? null : authMetadata,
       _onClose = onClose,
       _metadata = listenMetadata(
         database: database,
         accessToken: endpoint.isEmulator ? emulatorAccessToken : null,
         headers: headers,
       ) {
    _client = pbgrpc.FirestoreClient(_channel);
  }

  /// Connects to the endpoint [settings] resolve to, authenticating with
  /// [credential] as REST requests do.
  factory GrpcListenTransport.fromSettings({
    required Settings settings,
    required Credential credential,
    required String database,
  }) {
    final endpoint = ListenEndpoint.fromSettings(settings);
    final tokens = endpoint.isEmulator
        ? null
        : CredentialAccessTokens(credential);
    return GrpcListenTransport(
      endpoint: endpoint,
      database: database,
      authMetadata: tokens?.call,
      headers: settings.headers,
      onClose: tokens?.close,
    );
  }

  final ClientChannel _channel;
  late final pbgrpc.FirestoreClient _client;
  final AuthMetadataSource? _authMetadata;
  final Future<void> Function()? _onClose;
  final Map<String, String> _metadata;
  final _streams = <_GrpcListenStream>{};
  Future<void>? _closeFuture;

  @override
  ListenStream open() {
    if (_closeFuture != null) {
      throw StateError('GrpcListenTransport has already been closed.');
    }
    final requests = StreamController<pb.ListenRequest>();
    final stream = _GrpcListenStream(requests, onEnd: _streams.remove);
    final authMetadata = _authMetadata;
    stream._start(
      _client.listen(
        requests.stream,
        options: CallOptions(
          metadata: _metadata,
          providers: [
            if (authMetadata != null)
              (metadata, uri) async {
                try {
                  metadata.addAll(await authMetadata());
                } catch (error) {
                  // grpc reports this as a retryable UNAVAILABLE.
                  stream._authError = error;
                  rethrow;
                }
              },
          ],
        ),
      ),
    );
    _streams.add(stream);
    return stream;
  }

  @override
  Future<void> close() => _closeFuture ??= () async {
    await Future.wait([
      for (final stream in [..._streams]) stream.close(),
    ]);
    await _channel.shutdown();
    await _onClose?.call();
  }();
}

final class _GrpcListenStream implements ListenStream {
  _GrpcListenStream(this._requests, {required this.onEnd});

  final StreamController<pb.ListenRequest> _requests;

  /// Called once, when the call ends for any reason.
  final void Function(_GrpcListenStream stream) onEnd;

  late final ResponseStream<pb.ListenResponse> _call;
  // Pausing is not passed on to the call: cancelling a paused
  // `package:grpc` call stalls the connection it shares with other calls.
  // Responses are buffered here instead.
  late final _responses = StreamController<firestore_v1.ListenResponse>(
    onCancel: close,
  );

  /// Why the access token for this call could not be obtained, if it failed.
  Object? _authError;

  /// Whether [close] was called.
  var _closing = false;

  /// Whether the call has ended.
  var _ended = false;

  void _start(ResponseStream<pb.ListenResponse> call) {
    _call = call;
    call.listen(_onData, onError: _onError, onDone: _end);
  }

  @override
  Stream<firestore_v1.ListenResponse> get responses => _responses.stream;

  void _onData(pb.ListenResponse response) {
    final firestore_v1.ListenResponse converted;
    try {
      converted = listenResponseFromProto(response);
    } catch (error, stackTrace) {
      _responses.addError(
        FirestoreException(
          FirestoreClientErrorCode.internal,
          'Could not decode a Listen response: $error',
        ),
        stackTrace,
      );
      unawaited(close());
      return;
    }
    _responses.add(converted);
  }

  void _onError(Object error, StackTrace stackTrace) {
    if (_closing) return;
    final authError = _authError;
    _responses.addError(switch (error) {
      _ when authError != null => FirestoreException(
        FirestoreClientErrorCode.unauthenticated,
        'Could not obtain an access token: $authError',
      ),
      GrpcError() => firestoreExceptionFromGrpcError(error),
      _ => error,
    }, stackTrace);
  }

  void _end() {
    if (_ended) return;
    _ended = true;
    onEnd(this);
    unawaited(_requests.close());
    unawaited(_responses.close());
  }

  @override
  void send(firestore_v1.ListenRequest request) {
    if (_closing || _ended) {
      throw StateError('ListenStream has already ended.');
    }
    _requests.add(listenRequestToProto(request));
  }

  @override
  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    if (!_ended) await _call.cancel();
    _end();
  }
}
