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

import 'package:google_cloud_firestore/google_cloud_firestore.dart'
    hide greaterThan, lessThan;
import 'package:test/test.dart' hide throwsArgumentError;

const _readTime = '2024-01-01T00:00:00.000Z';
final _transactionId = base64Encode(utf8.encode('tx'));

void _writeJson(HttpRequest request, int statusCode, Object body) {
  request.response
    ..statusCode = statusCode
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  request.response.close();
}

void _writeAborted(HttpRequest request) => _writeJson(request, 409, {
  'error': {
    'code': 409,
    'status': 'ABORTED',
    'message': 'Aborted due to cross-transaction contention.',
  },
});

void _writeDocument(HttpRequest request, String name) =>
    _writeJson(request, 200, [
      {
        'found': {
          'name': name,
          'fields': {
            'count': {'integerValue': '1'},
          },
          'createTime': _readTime,
          'updateTime': _readTime,
        },
        'transaction': _transactionId,
        'readTime': _readTime,
      },
    ]);

void main() {
  group('Streaming RPC errors', () {
    late HttpServer server;
    late Firestore firestore;
    late List<String> calls;
    late void Function(HttpRequest request, String method, int attempt) handler;
    late Map<Object, Object?> zoneValues;

    setUp(() async {
      calls = [];
      handler = (request, _, _) => _writeJson(request, 200, {});

      server = await HttpServer.bind('localhost', 0);
      server.listen((request) async {
        await request.drain<void>();
        final method = request.uri.path.split(':').last;
        calls.add(method);
        handler(request, method, calls.where((m) => m == method).length);
      });

      zoneValues = {
        envSymbol: <String, String>{
          'FIRESTORE_EMULATOR_HOST': 'localhost:${server.port}',
        },
      };

      firestore = Firestore(
        settings: const Settings(projectId: 'test-project'),
      );
    });

    tearDown(() async {
      await firestore.terminate();
      await server.close(force: true);
    });

    test('surface as FirestoreException', () async {
      handler = (request, _, _) => _writeAborted(request);

      await expectLater(
        runZoned(() => firestore.doc('test/doc').get(), zoneValues: zoneValues),
        throwsA(
          isA<FirestoreException>().having(
            (e) => e.errorCode,
            'errorCode',
            FirestoreClientErrorCode.aborted,
          ),
        ),
      );
    });

    test('ABORTED on a transactional read retries the transaction', () async {
      final ref = firestore.doc('test/doc');
      handler = (request, method, attempt) {
        if (method == 'batchGet' && attempt == 1) return _writeAborted(request);
        if (method == 'batchGet') {
          return _writeDocument(
            request,
            'projects/test-project/databases/(default)/documents/test/doc',
          );
        }
        if (method == 'commit') {
          return _writeJson(request, 200, {
            'commitTime': _readTime,
            'writeResults': [
              {'updateTime': _readTime},
            ],
          });
        }
        _writeJson(request, 200, {});
      };

      await runZoned(
        () => firestore.runTransaction((tx) async {
          final snapshot = await tx.get(ref);
          tx.update(ref, {'count': (snapshot.data()!['count']! as int) + 1});
        }),
        zoneValues: zoneValues,
      );

      expect(calls.where((m) => m == 'batchGet'), hasLength(2));
      expect(calls.where((m) => m == 'commit'), hasLength(1));
    });
  });
}
