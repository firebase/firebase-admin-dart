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

import 'dart:io';

import 'package:google_cloud_firestore/src/firestore_http_client.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

/// Records the requests it is given and answers them without any network I/O,
/// standing in for whichever half of the transport a request was routed to.
class _RecordingClient extends BaseClient {
  final List<Uri> requests = <Uri>[];
  bool closed = false;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    requests.add(request.url);
    return StreamedResponse(const Stream.empty(), 200, request: request);
  }

  @override
  void close() => closed = true;
}

void main() {
  group('Http2WithHttp1FallbackClient', () {
    test('routes plain http requests away from the HTTP/2 transport', () async {
      // ADC on GCE and Cloud Run fetches tokens over plain http.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        request.response
          ..statusCode = 200
          ..write('ok');
        request.response.close();
      });

      final client = Http2WithHttp1FallbackClient();
      addTearDown(client.close);

      final response = await client.get(
        Uri.http('${server.address.host}:${server.port}', '/token'),
      );

      expect(response.statusCode, 200);
      expect(response.body, 'ok');
    });

    test('sends https requests over the HTTP/2 transport', () async {
      final http1 = _RecordingClient();
      final client = Http2WithHttp1FallbackClient(http1: http1);
      addTearDown(client.close);

      // Nothing is listening, so failing to dial proves it took the HTTP/2 leg.
      await expectLater(
        client.get(Uri.https('localhost:1', '/')),
        throwsA(isA<ClientException>()),
      );
      expect(http1.requests, isEmpty);
    });

    test('close() closes both transports', () async {
      final http1 = _RecordingClient();
      final client = Http2WithHttp1FallbackClient(http1: http1);

      // Force the lazily created fallback into existence before closing.
      await client.get(Uri.http('localhost:1', '/'));
      client.close();

      expect(http1.closed, isTrue);
      await expectLater(
        client.get(Uri.https('localhost:1', '/')),
        throwsA(
          isA<ClientException>().having(
            (e) => e.message,
            'message',
            contains('already closed'),
          ),
        ),
      );
    });
  });
}
