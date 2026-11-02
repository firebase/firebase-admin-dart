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

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:google_cloud_firestore/src/generated/google/firestore/v1/firestore.pbgrpc.dart'
    as pb;
import 'package:google_cloud_firestore/src/watch/listen_transport.dart';
import 'package:google_cloud_firestore_v1/firestore.dart' as firestore_v1;
import 'package:googleapis_auth/auth_io.dart' as googleapis_auth;
import 'package:grpc/grpc.dart' as grpc;
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const _database = 'projects/test-project/databases/(default)';

/// An in-process Firestore service whose `Listen` is scripted per test.
class _FakeFirestore extends pb.FirestoreServiceBase {
  Stream<pb.ListenResponse> Function(
    grpc.ServiceCall call,
    Stream<pb.ListenRequest> requests,
  )
  onListen = (_, _) => const Stream.empty();

  @override
  Stream<pb.ListenResponse> listen(
    grpc.ServiceCall call,
    Stream<pb.ListenRequest> request,
  ) => onListen(call, request);

  // Every other RPC is unused.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Attaches `token()` to each request, as a googleapis_auth client does, and
/// sends it on through the base client it was created with.
class _FakeAuthClient extends http.BaseClient
    implements googleapis_auth.AuthClient {
  _FakeAuthClient(this._base, this._token, {this.quotaProject});

  final http.Client _base;
  final String? Function() _token;
  final String? quotaProject;

  @override
  googleapis_auth.AccessCredentials get credentials =>
      throw UnimplementedError();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (_token() case final token?) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (quotaProject case final project?) {
      request.headers['X-Goog-User-Project'] = project;
    }
    request.headers['User-Agent'] = 'not-forwarded';
    return _base.send(request);
  }
}

void main() {
  group('channelCredentialsFor', () {
    test('uses TLS for a secure endpoint', () {
      const endpoint = ListenEndpoint(
        host: 'firestore.googleapis.com',
        port: 443,
        secure: true,
        isEmulator: false,
      );

      expect(channelCredentialsFor(endpoint).isSecure, isTrue);
    });

    test('uses plaintext for the emulator', () {
      const endpoint = ListenEndpoint(
        host: 'localhost',
        port: 8080,
        secure: false,
        isEmulator: true,
      );

      expect(channelCredentialsFor(endpoint).isSecure, isFalse);
    });
  });

  group('CredentialAccessTokens', () {
    test('creates the client lazily and reads the token it attaches', () async {
      var created = 0;
      final tokens = CredentialAccessTokens.withClientFactory((base) async {
        created++;
        return _FakeAuthClient(base, () => 'token-1');
      });
      addTearDown(tokens.close);

      expect(created, 0);
      expect(await tokens(), {'authorization': 'Bearer token-1'});
      expect(await tokens(), {'authorization': 'Bearer token-1'});
      expect(created, 1);
    });

    test('returns the token after the client refreshes it', () async {
      var token = 'old';
      final tokens = CredentialAccessTokens.withClientFactory(
        (base) async => _FakeAuthClient(base, () => token),
      );
      addTearDown(tokens.close);

      expect(await tokens(), {'authorization': 'Bearer old'});
      token = 'new';
      expect(await tokens(), {'authorization': 'Bearer new'});
    });

    test('retries creating the client after a failure', () async {
      var attempts = 0;
      final tokens = CredentialAccessTokens.withClientFactory((base) async {
        if (++attempts == 1) throw const FormatException('bad credentials');
        return _FakeAuthClient(base, () => 'token');
      });
      addTearDown(tokens.close);

      await expectLater(tokens(), throwsFormatException);
      expect(await tokens(), {'authorization': 'Bearer token'});
      expect(attempts, 2);
    });

    test('includes the quota project googleapis_auth attaches', () async {
      final tokens = CredentialAccessTokens.withClientFactory(
        (base) async =>
            _FakeAuthClient(base, () => 'token', quotaProject: 'billing'),
      );
      addTearDown(tokens.close);

      expect(await tokens(), {
        'authorization': 'Bearer token',
        'x-goog-user-project': 'billing',
      });
    });

    test('fails when the client attaches no bearer token', () async {
      final tokens = CredentialAccessTokens.withClientFactory(
        (base) async => _FakeAuthClient(base, () => null),
      );
      addTearDown(tokens.close);

      await expectLater(tokens(), throwsStateError);
    });
  });

  group('GrpcListenTransport', () {
    late grpc.Server server;
    late _FakeFirestore service;
    late GrpcListenTransport transport;

    setUp(() async {
      service = _FakeFirestore();
      server = grpc.Server.create(services: [service]);
      await server.serve(address: InternetAddress.loopbackIPv4, port: 0);
      transport = GrpcListenTransport(
        endpoint: ListenEndpoint(
          host: InternetAddress.loopbackIPv4.address,
          port: server.port!,
          secure: false,
          isEmulator: true,
        ),
        database: _database,
        headers: {'X-Goog-Api-Client': 'fire-admin/1.0'},
      );
      addTearDown(() async {
        await transport.close();
        await server.shutdown();
      });
    });

    test('sends requests and metadata, and bridges responses', () async {
      final received = Completer<(Map<String, String>, pb.ListenRequest)>();
      service.onListen = (call, requests) async* {
        final request = await requests.first;
        received.complete((call.clientMetadata!, request));
        yield pb.ListenResponse(
          targetChange: pb.TargetChange(
            targetChangeType: pb.TargetChange_TargetChangeType.ADD,
            targetIds: [request.addTarget.targetId],
          ),
        );
      };

      final stream = transport.open();
      stream.send(
        firestore_v1.ListenRequest(
          database: _database,
          addTarget: firestore_v1.Target(
            documents: firestore_v1.Target_DocumentsTarget(
              documents: ['$_database/documents/col/doc'],
            ),
            targetId: 3,
          ),
        ),
      );

      final response = await stream.responses.first;
      final (metadata, request) = await received.future;

      expect(metadata['authorization'], 'Bearer owner');
      expect(metadata['google-cloud-resource-prefix'], _database);
      expect(metadata['x-goog-request-params'], 'database=$_database');
      expect(metadata['x-goog-api-client'], 'fire-admin/1.0');
      expect(request.database, _database);
      expect(request.addTarget.documents.documents, [
        '$_database/documents/col/doc',
      ]);
      expect(
        response.targetChange!.targetChangeType,
        firestore_v1.TargetChange_TargetChangeType.add,
      );
      expect(response.targetChange!.targetIds, [3]);
    });

    GrpcListenTransport productionTransport(AuthMetadataSource authMetadata) {
      final transport = GrpcListenTransport(
        endpoint: ListenEndpoint(
          host: InternetAddress.loopbackIPv4.address,
          port: server.port!,
          secure: false,
          isEmulator: false,
        ),
        database: _database,
        authMetadata: authMetadata,
      );
      addTearDown(transport.close);
      return transport;
    }

    test('authorises production calls with the auth metadata', () async {
      final received = Completer<Map<String, String>>();
      service.onListen = (call, requests) {
        received.complete(call.clientMetadata!);
        return const Stream.empty();
      };
      final transport = productionTransport(
        () async => {
          'authorization': 'Bearer token-1',
          'x-goog-user-project': 'billing',
        },
      );

      await transport.open().responses.drain<void>();

      final metadata = await received.future;
      expect(metadata['authorization'], 'Bearer token-1');
      expect(metadata['x-goog-user-project'], 'billing');
      expect(metadata['google-cloud-resource-prefix'], _database);
    });

    test('reports an auth metadata failure as unauthenticated', () async {
      final transport = productionTransport(
        () => Future.error(StateError('no credentials')),
      );

      await expectLater(
        transport.open().responses,
        emitsError(
          isA<FirestoreException>()
              .having(
                (e) => e.errorCode,
                'errorCode',
                FirestoreClientErrorCode.unauthenticated,
              )
              .having((e) => e.message, 'message', contains('no credentials')),
        ),
      );
    });

    test('rejects send once the server ends the call', () async {
      service.onListen = (call, requests) =>
          Stream.value(pb.ListenResponse(targetChange: pb.TargetChange()));

      final stream = transport.open();
      expect(await stream.responses.toList(), hasLength(1));

      expect(
        () => stream.send(firestore_v1.ListenRequest(database: _database)),
        throwsStateError,
      );
    });

    test('cancelling the responses cancels the call', () async {
      final serverCancelled = Completer<void>();
      service.onListen = (call, requests) {
        final controller = StreamController<pb.ListenResponse>();
        requests.listen(
          (_) => controller.add(
            pb.ListenResponse(targetChange: pb.TargetChange()),
          ),
          onError: (Object error) => serverCancelled.complete(),
        );
        return controller.stream;
      };

      final stream = transport.open();
      stream.send(firestore_v1.ListenRequest(database: _database));
      await stream.responses.first;

      await serverCancelled.future.timeout(const Duration(seconds: 5));
      expect(
        () => stream.send(firestore_v1.ListenRequest(database: _database)),
        throwsStateError,
      );
    });

    test('closing a paused stream leaves the channel usable', () async {
      service.onListen = (call, requests) async* {
        await for (final _ in requests) {
          for (var i = 0; i < 2000; i++) {
            yield pb.ListenResponse(targetChange: pb.TargetChange());
          }
        }
      };

      // Pausing used to pause the gRPC call itself; cancelling a paused call
      // stalls package:grpc's shared connection, starving later calls.
      for (var round = 0; round < 10; round++) {
        final paused = transport.open();
        final first = Completer<void>();
        final subscription = paused.responses.listen((_) {
          if (!first.isCompleted) first.complete();
        });
        paused.send(firestore_v1.ListenRequest(database: _database));
        await first.future;
        subscription.pause();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await paused.close();
        subscription.resume();

        final next = transport.open();
        next.send(firestore_v1.ListenRequest(database: _database));
        await expectLater(
          next.responses.first.timeout(const Duration(seconds: 5)),
          completes,
        );
        await next.close();
      }
    });

    test('reports a failed call as a FirestoreException', () async {
      service.onListen = (call, requests) =>
          Stream.error(const grpc.GrpcError.permissionDenied('no access'));

      final stream = transport.open();

      await expectLater(
        stream.responses,
        emitsError(
          isA<FirestoreException>()
              .having((e) => e.errorCode.statusCode.value, 'code', 7)
              .having((e) => e.message, 'message', 'no access'),
        ),
      );
    });

    test('close ends the responses without an error', () async {
      final serverCancelled = Completer<void>();
      service.onListen = (call, requests) {
        final controller = StreamController<pb.ListenResponse>();
        requests.listen(
          (_) => controller.add(
            pb.ListenResponse(targetChange: pb.TargetChange()),
          ),
          // The server sees the client's cancellation as CANCELLED.
          onError: (Object error) => serverCancelled.complete(),
        );
        return controller.stream;
      };

      final stream = transport.open();
      final responses = StreamIterator(stream.responses);
      stream.send(firestore_v1.ListenRequest(database: _database));
      expect(await responses.moveNext(), isTrue);

      await stream.close();

      expect(await responses.moveNext(), isFalse);
      await serverCancelled.future.timeout(const Duration(seconds: 5));
      expect(
        () => stream.send(firestore_v1.ListenRequest(database: _database)),
        throwsStateError,
      );
    });

    test('close cancels open calls and rejects new ones', () async {
      service.onListen = (call, requests) {
        // Keeps the call open until the client cancels it.
        final controller = StreamController<pb.ListenResponse>();
        requests.listen(
          null,
          onError: (Object error) => controller.close(),
          onDone: controller.close,
        );
        return controller.stream;
      };

      final stream = transport.open();
      final done = stream.responses.toList();

      await transport.close();

      expect(await done.timeout(const Duration(seconds: 5)), isEmpty);
      expect(transport.open, throwsStateError);
    });
  });
}
