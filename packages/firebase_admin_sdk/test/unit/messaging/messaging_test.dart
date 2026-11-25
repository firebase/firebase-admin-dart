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

// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:firebase_admin_sdk/src/messaging/messaging.dart';
import 'package:googleapis/fcm/v1.dart' as fmc1;
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../fixtures/helpers.dart';
import '../../fixtures/mock.dart';

class ProjectsMessagesResourceMock extends Mock
    implements fmc1.ProjectsMessagesResource {}

class FirebaseMessagingHttpMockAuthClient extends Mock
    implements FirebaseMessagingHttpClient {}

class FirebaseCloudMessagingApiMock extends Mock
    implements fmc1.FirebaseCloudMessagingApi {}

class ProjectsResourceMock extends Mock implements fmc1.ProjectsResource {}

class _LengthOnlyTokens extends ListBase<String> {
  @override
  int get length => 501;

  @override
  set length(int value) => throw UnsupportedError('Cannot change length');

  @override
  String operator [](int index) => throw StateError('Tokens were read');

  @override
  void operator []=(int index, String value) =>
      throw UnsupportedError('Cannot change tokens');
}

extension on Object? {
  T cast<T>() => this as T;
}

void main() {
  late Messaging messaging;
  late FirebaseMessagingRequestHandler requestHandler;

  final httpClient = FirebaseMessagingHttpMockAuthClient();
  final messages = ProjectsMessagesResourceMock();
  final projectResourceMock = ProjectsResourceMock();
  final messagingApiMock = FirebaseCloudMessagingApiMock();

  setUpAll(registerFallbacks);

  void mockV1<T>() {
    when(() => httpClient.v1<T>(any())).thenAnswer((invocation) async {
      final callback = invocation.positionalArguments.first as Function;

      // Pass both the API client and projectId to match the v1() signature
      final result = await Function.apply(callback, [
        messagingApiMock,
        projectId,
      ]);
      return result as T;
    });
  }

  setUp(() {
    when(() => projectResourceMock.messages).thenReturn(messages);
    when(() => messagingApiMock.projects).thenReturn(projectResourceMock);

    // Mock buildParent to return the expected parent resource path
    when(() => httpClient.buildParent(any())).thenAnswer(
      (invocation) => 'projects/${invocation.positionalArguments[0]}',
    );

    // Mock iidApiHost for topic management
    when(() => httpClient.iidApiHost).thenReturn('iid.googleapis.com');
    // Mock fcmHost for topic management
    when(() => httpClient.fcmHost).thenReturn('fcm.googleapis.com');

    // Use unique app name for each test to avoid interference
    final appName = 'messaging-test-${DateTime.now().microsecondsSinceEpoch}';
    final app = createApp(name: appName);
    requestHandler = FirebaseMessagingRequestHandler(
      app,
      httpClient: httpClient,
    );
    messaging = Messaging.internal(app, requestHandler: requestHandler);
  });

  tearDown(() {
    reset(httpClient);
    reset(messages);
    reset(projectResourceMock);
    reset(messagingApiMock);
  });

  group('Error handling', () {
    for (final (:code, :error) in [
      (code: 400, error: MessagingClientErrorCode.invalidArgument),
      (code: 401, error: MessagingClientErrorCode.authenticationError),
      (code: 403, error: MessagingClientErrorCode.authenticationError),
      (code: 500, error: MessagingClientErrorCode.internalError),
      (code: 503, error: MessagingClientErrorCode.serverUnavailable),
      (code: 505, error: MessagingClientErrorCode.unknownError),
    ]) {
      test('converts $code codes into errors', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(Stream.value(utf8.encode('')), code),
          ),
        );

        final app = createApp(client: clientMock);
        final handler = Messaging.internal(app);

        await expectLater(
          () => handler.send(TokenMessage(token: '123')),
          throwsA(
            isA<FirebaseMessagingAdminException>().having(
              (e) => e.errorCode,
              'errorCode',
              error,
            ),
          ),
        );
      });
    }

    for (final MapEntry(key: messagingError, value: code)
        in messagingServerToClientCode.entries) {
      test('converts $messagingError error codes', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {'message': messagingError},
                  }),
                ),
              ),
              400,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock);
        final handler = Messaging.internal(app);

        await expectLater(
          () => handler.send(TokenMessage(token: '123')),
          throwsA(
            isA<FirebaseMessagingAdminException>()
                .having((e) => e.errorCode, 'errorCode', code)
                .having((e) => e.code, 'code', 'messaging/${code.code}'),
          ),
        );
      });
    }
  });

  group('Messaging.send', () {
    setUp(() => mockV1<String>());

    test('should send a message', () async {
      when(
        () => messages.send(any(), any()),
      ).thenAnswer((_) => Future.value(fmc1.Message(name: 'test')));

      final result = await messaging.send(TopicMessage(topic: 'test'));

      expect(result, 'test');

      final capture = verify(() => messages.send(captureAny(), captureAny()))
        ..called(1);
      verifyNoMoreInteractions(messages);

      final request = capture.captured.first as fmc1.SendMessageRequest;
      final parent = capture.captured.last as String;

      expect(request.message?.topic, 'test');
      expect(parent, 'projects/$projectId');
    });

    test('throws internal error if response has no name', () {
      when(
        () => messages.send(any(), any()),
      ).thenAnswer((_) => Future.value(fmc1.Message()));

      expect(
        () => messaging.send(TopicMessage(topic: 'test')),
        throwsA(
          isA<FirebaseMessagingAdminException>()
              .having(
                (e) => e.errorCode,
                'errorCode',
                MessagingClientErrorCode.internalError,
              )
              .having((e) => e.message, 'message', 'No name in response'),
        ),
      );
    });

    test('sends a TokenMessage with token set on the request', () async {
      when(
        () => messages.send(any(), any()),
      ).thenAnswer((_) => Future.value(fmc1.Message(name: 'test')));

      const token = 'my-device-token';
      final result = await messaging.send(TokenMessage(token: token));

      expect(result, 'test');

      final capture = verify(() => messages.send(captureAny(), captureAny()))
        ..called(1);

      final request = capture.captured.first as fmc1.SendMessageRequest;
      expect(request.message?.token, token);
      expect(request.message?.topic, isNull);
      expect(request.message?.condition, isNull);
    });

    test('sends a FidMessage using the generated FID field', () async {
      when(
        () => messages.send(any(), any()),
      ).thenAnswer((_) async => fmc1.Message(name: 'test'));

      expect(await messaging.send(FidMessage(fid: 'installation-id')), 'test');

      final request =
          verify(() => messages.send(captureAny(), any())).captured.single
              as fmc1.SendMessageRequest;
      expect(request.message.runtimeType, fmc1.Message);
      expect(request.message?.fid, 'installation-id');
      expect(request.message?.token, isNull);
      expect(request.message?.topic, isNull);
      expect(request.message?.condition, isNull);
    });

    test('sends a FidMessage in the HTTP v1 request body', () async {
      final client = MockAuthClient();
      late String body;
      when(() => client.send(any())).thenAnswer((invocation) async {
        final request = invocation.positionalArguments.single as BaseRequest;
        body = await request.finalize().bytesToString();
        return StreamedResponse(
          Stream.value(utf8.encode('{"name":"messages/test"}')),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final app = createApp(client: client);
      final handler = Messaging.internal(app);

      final result = await handler.send(
        FidMessage(
          fid: 'installation-id',
          data: {'key': 'value'},
          notification: Notification(title: 'Hello'),
        ),
        dryRun: true,
      );

      expect(result, 'messages/test');
      final request =
          verify(() => client.send(captureAny())).captured.single
              as BaseRequest;
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://fcm.googleapis.com/v1/projects/$projectId/messages:send?alt=json',
      );
      expect(jsonDecode(body), {
        'message': {
          'fid': 'installation-id',
          'data': {'key': 'value'},
          'notification': {'title': 'Hello'},
        },
        'validateOnly': true,
      });
    });

    test(
      'sends a ConditionMessage with condition set on the request',
      () async {
        when(
          () => messages.send(any(), any()),
        ).thenAnswer((_) => Future.value(fmc1.Message(name: 'test')));

        const condition = "'foo-bar' in topics || 'baz' in topics";
        final result = await messaging.send(
          ConditionMessage(condition: condition),
        );

        expect(result, 'test');

        final capture = verify(() => messages.send(captureAny(), captureAny()))
          ..called(1);

        final request = capture.captured.first as fmc1.SendMessageRequest;
        expect(request.message?.condition, condition);
        expect(request.message?.topic, isNull);
        expect(request.message?.token, isNull);
      },
    );

    test('dryRun', () async {
      when(
        () => messages.send(any(), any()),
      ).thenAnswer((_) => Future.value(fmc1.Message(name: 'test')));

      await messaging.send(TopicMessage(topic: 'test'), dryRun: true);

      final capture = verify(() => messages.send(captureAny(), captureAny()))
        ..called(1);

      final request = capture.captured.first as fmc1.SendMessageRequest;

      expect(request.validateOnly, true);
    });

    test('supports booleans', () async {
      when(
        () => messages.send(any(), any()),
      ).thenAnswer((_) => Future.value(fmc1.Message(name: 'test')));

      await messaging.send(
        TopicMessage(
          topic: 'test',
          apns: ApnsConfig(
            payload: ApnsPayload(
              aps: Aps(
                contentAvailable: true,
                mutableContent: true,
                sound: const CriticalSound(critical: true, name: 'default'),
              ),
            ),
          ),
          webpush: WebpushConfig(
            notification: WebpushNotification(renotify: true),
          ),
        ),
      );

      final capture = verify(() => messages.send(captureAny(), captureAny()))
        ..called(1);
      final request = capture.captured.first as fmc1.SendMessageRequest;

      expect(
        request.message!.apns!.payload!['aps']!
            .cast<Map<Object?, Object?>>()['content-available'],
        1,
      );
      expect(
        request.message!.apns!.payload!['aps']!
            .cast<Map<Object?, Object?>>()['mutable-content'],
        1,
      );
      expect(
        request.message!.apns!.payload!['aps']!
            .cast<Map<Object?, Object?>>()['sound']
            .cast<Map<Object?, Object?>>()['critical'],
        1,
      );

      expect(request.message!.webpush!.notification!['renotify'], 1);
    });

    test('ApsSoundName serialises as a plain string', () async {
      when(
        () => messages.send(any(), any()),
      ).thenAnswer((_) => Future.value(fmc1.Message(name: 'test')));

      await messaging.send(
        TopicMessage(
          topic: 'test',
          apns: ApnsConfig(
            payload: ApnsPayload(
              aps: Aps(sound: const ApsSoundName('default')),
            ),
          ),
        ),
      );

      final capture = verify(() => messages.send(captureAny(), captureAny()))
        ..called(1);
      final request = capture.captured.first as fmc1.SendMessageRequest;

      expect(
        request.message!.apns!.payload!['aps']
            .cast<Map<Object?, Object?>>()['sound'],
        'default',
      );
    });

    test(
      'ApsInterruptionLevel serialises with correct APNs key values',
      () async {
        for (final (level, expected) in [
          (ApsInterruptionLevel.active, 'active'),
          (ApsInterruptionLevel.critical, 'critical'),
          (ApsInterruptionLevel.passive, 'passive'),
          (ApsInterruptionLevel.timeSensitive, 'time-sensitive'),
        ]) {
          when(
            () => messages.send(any(), any()),
          ).thenAnswer((_) => Future.value(fmc1.Message(name: 'test')));

          await messaging.send(
            TopicMessage(
              topic: 'test',
              apns: ApnsConfig(
                payload: ApnsPayload(aps: Aps(interruptionLevel: level)),
              ),
            ),
          );

          final capture = verify(
            () => messages.send(captureAny(), captureAny()),
          )..called(1);
          final request = capture.captured.first as fmc1.SendMessageRequest;

          expect(
            request.message!.apns!.payload!['aps']
                .cast<Map<Object?, Object?>>()['interruption-level'],
            expected,
            reason: 'Expected $level to serialise as "$expected"',
          );

          reset(messages);
        }
      },
    );

    test('supports null alert/sound', () async {
      when(
        () => messages.send(any(), any()),
      ).thenAnswer((_) => Future.value(fmc1.Message(name: 'test')));

      await messaging.send(
        TopicMessage(
          topic: 'test',
          apns: ApnsConfig(payload: ApnsPayload(aps: Aps())),
          webpush: WebpushConfig(
            notification: WebpushNotification(renotify: true),
          ),
        ),
      );

      final capture = verify(() => messages.send(captureAny(), captureAny()))
        ..called(1);
      final request = capture.captured.first as fmc1.SendMessageRequest;

      expect(request.message!.apns!.payload!['aps'], <String, Object?>{});
    });
  });

  group('sendEach', () {
    setUp(() => mockV1<BatchResponse>());

    test('sends FidMessage targets', () async {
      when(
        () => messages.send(any(), any()),
      ).thenAnswer((_) async => fmc1.Message(name: 'test'));

      final response = await messaging.sendEach([
        FidMessage(fid: 'installation-id'),
      ]);

      expect(response.successCount, 1);
      final request =
          verify(() => messages.send(captureAny(), any())).captured.single
              as fmc1.SendMessageRequest;
      expect(jsonDecode(jsonEncode(request)), {
        'message': {'fid': 'installation-id'},
      });
    });

    test('asserts list length >=1 <500', () {
      expect(
        () => messaging.sendEach([]),
        throwsA(
          isA<FirebaseMessagingAdminException>().having(
            (e) => e.message,
            'message',
            'messages must be a non-empty array',
          ),
        ),
      );

      expect(
        () => messaging.sendEach(
          List.generate(501, (index) => TopicMessage(topic: '$index')),
        ),
        throwsA(
          isA<FirebaseMessagingAdminException>().having(
            (e) => e.message,
            'message',
            'messages list must not contain more than 500 items',
          ),
        ),
      );
    });

    test('works', () async {
      when(() => messages.send(any(), any())).thenAnswer((i) {
        final request = i.positionalArguments.first as fmc1.SendMessageRequest;
        switch (request.message?.topic) {
          case 'test':
            // Voluntary cause "test" to resolve after "test2"
            return Future(() => Future.value(fmc1.Message(name: 'test')));
          case _:
            return Future.error('error');
        }
      });

      final result = await messaging.sendEach([
        TopicMessage(topic: 'test'),
        TopicMessage(topic: 'test2'),
      ]);

      expect(result.successCount, 1);
      expect(result.failureCount, 1);

      expect(result.responses, [
        isA<SendResponse>()
            .having((r) => r.success, 'success', true)
            .having((r) => r.messageId, 'messageId', 'test')
            .having((r) => r.error, 'error', null),
        isA<SendResponse>()
            .having((r) => r.success, 'success', false)
            .having((r) => r.messageId, 'messageId', null)
            .having(
              (r) => r.error,
              'error',
              isA<FirebaseMessagingAdminException>().having(
                (e) => e.message,
                'message',
                'error',
              ),
            ),
      ]);

      final capture = verify(() => messages.send(captureAny(), any()))
        ..called(2);
      verifyNoMoreInteractions(messages);

      var request = capture.captured.first as fmc1.SendMessageRequest;

      expect(request.validateOnly, null);

      request = capture.captured[1] as fmc1.SendMessageRequest;

      expect(request.validateOnly, null);
    });

    test('dry run', () async {
      when(
        () => messages.send(any(), any()),
      ).thenAnswer((i) => Future.value(fmc1.Message(name: 'test')));

      await messaging.sendEach(dryRun: true, [
        TopicMessage(topic: 'test'),
        TopicMessage(topic: 'test2'),
      ]);

      final capture = verify(() => messages.send(captureAny(), any()))
        ..called(2);
      verifyNoMoreInteractions(messages);

      var request = capture.captured.first as fmc1.SendMessageRequest;

      expect(request.validateOnly, true);

      request = capture.captured[1] as fmc1.SendMessageRequest;

      expect(request.validateOnly, true);
    });
  });

  group('sendEachForMulticast', () {
    setUp(() => mockV1<BatchResponse>());

    test('dispatches individual FID payloads over HTTP', () async {
      final client = MockAuthClient();
      final bodies = <Object?>[];
      when(() => client.send(any())).thenAnswer((invocation) async {
        final request = invocation.positionalArguments.single as BaseRequest;
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send?alt=json',
        );
        bodies.add(jsonDecode(await request.finalize().bytesToString()));
        return StreamedResponse(
          Stream.value(utf8.encode('{"name":"messages/test"}')),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final app = createApp(client: client);
      final handler = Messaging.internal(app);

      final result = await handler.sendEachForMulticast(
        FidMulticastMessage(fids: ['fid1', 'fid2'], data: {'key': 'value'}),
      );

      expect(result.successCount, 2);
      expect(
        bodies,
        unorderedEquals([
          {
            'message': {
              'fid': 'fid1',
              'data': {'key': 'value'},
            },
          },
          {
            'message': {
              'fid': 'fid2',
              'data': {'key': 'value'},
            },
          },
        ]),
      );
      verify(() => client.send(any())).called(2);
    });

    test('sends FIDs with all payload fields and dry run', () async {
      when(() => messages.send(any(), any())).thenAnswer((invocation) async {
        final request =
            invocation.positionalArguments.first as fmc1.SendMessageRequest;
        return fmc1.Message(name: 'message-${request.message?.fid}');
      });

      final result = await messaging.sendEachForMulticast(
        FidMulticastMessage(
          fids: ['fid1', 'fid2'],
          data: {'key': 'value'},
          notification: Notification(title: 'Title', body: 'Body'),
          android: AndroidConfig(collapseKey: 'collapse'),
          apns: ApnsConfig(headers: {'apns-priority': '10'}),
          webpush: WebpushConfig(headers: {'TTL': '300'}),
          fcmOptions: FcmOptions(analyticsLabel: 'label'),
        ),
        dryRun: true,
      );

      expect(result.successCount, 2);
      expect(result.failureCount, 0);
      expect(result.responses.map((response) => response.messageId), [
        'message-fid1',
        'message-fid2',
      ]);
      final capture = verify(() => messages.send(captureAny(), captureAny()))
        ..called(2);
      for (var i = 0; i < 2; i++) {
        final request = capture.captured[i * 2] as fmc1.SendMessageRequest;
        expect(capture.captured[i * 2 + 1], 'projects/$projectId');
        expect(request.validateOnly, isTrue);
        expect(request.message?.fid, 'fid${i + 1}');
        expect(request.message?.token, isNull);
        expect(request.message?.topic, isNull);
        expect(request.message?.condition, isNull);
        expect(request.message?.data, {'key': 'value'});
        expect(request.message?.notification?.title, 'Title');
        expect(request.message?.notification?.body, 'Body');
        expect(request.message?.android?.collapseKey, 'collapse');
        expect(request.message?.apns?.headers, {'apns-priority': '10'});
        expect(request.message?.webpush?.headers, {'TTL': '300'});
        expect(request.message?.fcmOptions?.analyticsLabel, 'label');
      }
    });

    test(
      'preserves mixed target and response order with partial failures',
      () async {
        when(() => messages.send(any(), any())).thenAnswer((invocation) async {
          final request =
              invocation.positionalArguments.first as fmc1.SendMessageRequest;
          final target = request.message?.token ?? request.message?.fid;
          if (target == 'fid1') {
            throw fmc1.DetailedApiRequestError(
              404,
              'Not found',
              jsonResponse: {
                'error': {'message': 'UNREGISTERED'},
              },
            );
          }
          if (target == 'token1') {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          return fmc1.Message(name: 'message-$target');
        });

        final result = await messaging.sendEachForMulticast(
          MulticastMessage(
            tokens: ['token1', 'token2'],
            fids: ['fid1', 'fid2'],
            data: {'key': 'value'},
          ),
        );

        expect(result.successCount, 3);
        expect(result.failureCount, 1);
        expect(result.responses.map((response) => response.messageId), [
          'message-token1',
          'message-token2',
          null,
          'message-fid2',
        ]);
        expect(
          result.responses[2].error,
          isA<FirebaseMessagingAdminException>().having(
            (error) => error.errorCode,
            'errorCode',
            MessagingClientErrorCode.registrationTokenNotRegistered,
          ),
        );
        final capture = verify(() => messages.send(captureAny(), any()))
          ..called(4);
        final requests = capture.captured.cast<fmc1.SendMessageRequest>();
        expect(requests.map((request) => request.message?.token), [
          'token1',
          'token2',
          null,
          null,
        ]);
        expect(requests.map((request) => request.message?.fid), [
          null,
          null,
          'fid1',
          'fid2',
        ]);
        for (final request in requests) {
          expect(request.message?.data, {'key': 'value'});
          expect(request.validateOnly, isNull);
        }
      },
    );

    test(
      'reports empty FIDs per target without blocking valid targets',
      () async {
        when(() => messages.send(any(), any())).thenAnswer((invocation) async {
          final request =
              invocation.positionalArguments.first as fmc1.SendMessageRequest;
          return fmc1.Message(
            name: request.message?.fid ?? request.message?.token,
          );
        });

        final result = await messaging.sendEachForMulticast(
          MulticastMessage(tokens: ['token'], fids: ['', 'valid', '']),
          dryRun: true,
        );
        expect(result.successCount, 2);
        expect(result.failureCount, 2);
        expect(result.responses.map((response) => response.messageId), [
          'token',
          null,
          'valid',
          null,
        ]);
        for (final index in [1, 3]) {
          expect(result.responses[index].success, isFalse);
          expect(
            result.responses[index].error,
            isA<FirebaseMessagingAdminException>()
                .having(
                  (error) => error.code,
                  'code',
                  'messaging/invalid-payload',
                )
                .having(
                  (error) => error.message,
                  'message',
                  'Exactly one of fid, topic, token or condition is required',
                ),
          );
        }
        final requests = (verify(
          () => messages.send(captureAny(), any()),
        )..called(2)).captured.cast<fmc1.SendMessageRequest>();
        expect(requests.map((request) => request.message?.fid), [
          null,
          'valid',
        ]);
        expect(requests.map((request) => request.validateOnly), [true, true]);
      },
    );

    test('reports all-empty FIDs as individual failures', () async {
      final result = await messaging.sendEachForMulticast(
        FidMulticastMessage(fids: ['', '']),
      );

      expect(result.successCount, 0);
      expect(result.failureCount, 2);
      for (final response in result.responses) {
        expect(response.success, isFalse);
        expect(response.error?.code, 'messaging/invalid-payload');
      }
      verifyNever(() => httpClient.v1<BatchResponse>(any()));
      verifyNever(() => messages.send(any(), any()));
    });

    test('combines invalid FIDs with server failures in order', () async {
      when(() => messages.send(any(), any())).thenAnswer((invocation) async {
        final request =
            invocation.positionalArguments.first as fmc1.SendMessageRequest;
        if (request.message?.fid == 'rejected') {
          throw fmc1.DetailedApiRequestError(
            404,
            'Not found',
            jsonResponse: {
              'error': {'message': 'UNREGISTERED'},
            },
          );
        }
        return fmc1.Message(name: request.message?.fid);
      });

      final result = await messaging.sendEachForMulticast(
        FidMulticastMessage(fids: ['', 'rejected', 'valid']),
      );
      expect(result.successCount, 1);
      expect(result.failureCount, 2);
      expect(result.responses[0].error?.code, 'messaging/invalid-payload');
      expect(
        result.responses[1].error?.code,
        'messaging/registration-token-not-registered',
      );
      expect(result.responses[2].messageId, 'valid');
      verify(() => messages.send(any(), any())).called(2);
    });

    test('preserves response order if caller mutates target lists', () async {
      final response = Completer<fmc1.Message>();
      when(
        () => messages.send(any(), any()),
      ).thenAnswer((_) => response.future);
      final tokens = <String>['token'];
      final fids = <String>['', 'valid'];

      final pending = messaging.sendEachForMulticast(
        MulticastMessage(tokens: tokens, fids: fids),
      );
      await Future<void>.delayed(Duration.zero);
      tokens.clear();
      fids.clear();
      response.complete(fmc1.Message(name: 'sent'));

      final result = await pending;
      expect(result.successCount, 2);
      expect(result.failureCount, 1);
      expect(result.responses.map((item) => item.success), [true, false, true]);
      expect(result.responses[1].error?.code, 'messaging/invalid-payload');
      verify(() => messages.send(any(), any())).called(2);
    });

    test('validates empty and oversized FID and mixed batches', () async {
      for (final payload in <MulticastMessagePayload>[
        FidMulticastMessage(fids: []),
        MulticastMessage(tokens: [], fids: []),
      ]) {
        await expectLater(
          () => messaging.sendEachForMulticast(payload),
          throwsA(
            isA<FirebaseMessagingAdminException>()
                .having(
                  (error) => error.errorCode,
                  'errorCode',
                  MessagingClientErrorCode.invalidArgument,
                )
                .having(
                  (error) => error.message,
                  'message',
                  'Either tokens or fids must be a non-empty array',
                ),
          ),
        );
      }

      for (final payload in <MulticastMessagePayload>[
        FidMulticastMessage(fids: List.filled(501, 'fid')),
        MulticastMessage(
          tokens: List.filled(250, 'token'),
          fids: List.filled(251, 'fid'),
        ),
      ]) {
        await expectLater(
          () => messaging.sendEachForMulticast(payload),
          throwsA(
            isA<FirebaseMessagingAdminException>()
                .having(
                  (error) => error.errorCode,
                  'errorCode',
                  MessagingClientErrorCode.invalidArgument,
                )
                .having(
                  (error) => error.message,
                  'message',
                  'The total number of tokens and fids must not exceed 500.',
                ),
          ),
        );
      }
      verifyNever(() => messages.send(any(), any()));
    });

    test('accepts 500 FID-only or combined targets', () async {
      when(
        () => messages.send(any(), any()),
      ).thenAnswer((_) async => fmc1.Message(name: 'success'));

      final payloads = <MulticastMessagePayload>[
        FidMulticastMessage(fids: List.filled(500, 'fid')),
        MulticastMessage(
          tokens: List.filled(250, 'token'),
          fids: List.filled(250, 'fid'),
        ),
      ];
      for (final payload in payloads) {
        final result = await messaging.sendEachForMulticast(payload);
        expect(result.successCount, 500);
        expect(result.failureCount, 0);
        verify(() => messages.send(any(), any())).called(500);
      }
    });

    test('accepts a legacy multicast with only FIDs', () async {
      when(
        () => messages.send(any(), any()),
      ).thenAnswer((_) async => fmc1.Message(name: 'success'));

      final result = await messaging.sendEachForMulticast(
        MulticastMessage(tokens: [], fids: ['fid']),
      );
      expect(result.successCount, 1);
      final request =
          verify(() => messages.send(captureAny(), any())).captured.single
              as fmc1.SendMessageRequest;
      expect(request.message?.fid, 'fid');
      expect(request.message?.token, isNull);
    });

    test('should convert multicast message to token messages', () async {
      when(() => messages.send(any(), any())).thenAnswer((i) {
        final request = i.positionalArguments.first as fmc1.SendMessageRequest;
        return Future.value(
          fmc1.Message(name: 'message-${request.message?.token}'),
        );
      });

      final result = await messaging.sendEachForMulticast(
        MulticastMessage(
          tokens: ['token1', 'token2', 'token3'],
          notification: Notification(title: 'Test', body: 'Body'),
          data: {'key': 'value'},
        ),
      );

      expect(result.successCount, 3);
      expect(result.failureCount, 0);
      expect(result.responses.length, 3);

      // Verify that send was called 3 times with the correct token messages
      final capture = verify(() => messages.send(captureAny(), any()))
        ..called(3);

      for (var i = 0; i < 3; i++) {
        final request = capture.captured[i] as fmc1.SendMessageRequest;
        expect(request.message?.token, 'token${i + 1}');
        expect(request.message?.notification?.title, 'Test');
        expect(request.message?.notification?.body, 'Body');
        expect(request.message?.data, {'key': 'value'});
      }
    });

    test('empty token list returns a failed Future', () async {
      final future = messaging.sendEachForMulticast(
        MulticastMessage(tokens: []),
      );
      await future.then<void>(
        (_) => fail('Expected validation failure'),
        onError: (Object error) {
          expect(
            error,
            isA<FirebaseMessagingAdminException>().having(
              (e) => e.message,
              'message',
              'Either tokens or fids must be a non-empty array',
            ),
          );
        },
      );
      verifyNever(() => httpClient.v1<BatchResponse>(any()));
    });

    test('multicast validation errors reach catchError', () async {
      var caught = false;
      final future = messaging
          .sendEachForMulticast(FidMulticastMessage(fids: []))
          .catchError((Object error, StackTrace stackTrace) {
            caught = true;
            expect(error, isA<FirebaseMessagingAdminException>());
            Error.throwWithStackTrace(error, stackTrace);
          });
      await expectLater(
        future,
        throwsA(isA<FirebaseMessagingAdminException>()),
      );
      expect(caught, isTrue);
      verifyNever(() => httpClient.v1<BatchResponse>(any()));
    });

    test(
      'oversized token list returns a failed Future without reading tokens',
      () async {
        final future = messaging.sendEachForMulticast(
          MulticastMessage(tokens: _LengthOnlyTokens()),
        );
        await expectLater(
          future,
          throwsA(
            isA<FirebaseMessagingAdminException>().having(
              (e) => e.message,
              'message',
              'The total number of tokens and fids must not exceed 500.',
            ),
          ),
        );
        verifyNever(() => httpClient.v1<BatchResponse>(any()));
      },
    );

    test('should support dryRun mode', () async {
      when(() => messages.send(any(), any())).thenAnswer((i) {
        return Future.value(fmc1.Message(name: 'test'));
      });

      await messaging.sendEachForMulticast(
        MulticastMessage(tokens: ['token1', 'token2']),
        dryRun: true,
      );

      final capture = verify(() => messages.send(captureAny(), any()))
        ..called(2);

      for (var i = 0; i < 2; i++) {
        final request = capture.captured[i] as fmc1.SendMessageRequest;
        expect(request.validateOnly, true);
      }
    });

    test('should propagate all BaseMessage fields', () async {
      when(() => messages.send(any(), any())).thenAnswer((i) {
        return Future.value(fmc1.Message(name: 'test'));
      });

      await messaging.sendEachForMulticast(
        MulticastMessage(
          tokens: ['token1'],
          data: {'key': 'value'},
          notification: Notification(title: 'Title', body: 'Body'),
          android: AndroidConfig(
            collapseKey: 'collapse',
            priority: AndroidConfigPriority.high,
          ),
          apns: ApnsConfig(headers: {'apns-priority': '10'}),
          webpush: WebpushConfig(headers: {'TTL': '300'}),
          fcmOptions: FcmOptions(analyticsLabel: 'label'),
        ),
      );

      final capture = verify(() => messages.send(captureAny(), any()))
        ..called(1);

      final request = capture.captured.first as fmc1.SendMessageRequest;
      expect(request.message?.token, 'token1');
      expect(request.message?.data, {'key': 'value'});
      expect(request.message?.notification?.title, 'Title');
      expect(request.message?.notification?.body, 'Body');
      expect(request.message?.android?.collapseKey, 'collapse');
      expect(request.message?.android?.priority, 'high');
      expect(request.message?.apns?.headers, {'apns-priority': '10'});
      expect(request.message?.webpush?.headers, {'TTL': '300'});
      expect(request.message?.fcmOptions?.analyticsLabel, 'label');
    });

    test('should handle mixed success and failure responses', () async {
      when(() => messages.send(any(), any())).thenAnswer((i) {
        final request = i.positionalArguments.first as fmc1.SendMessageRequest;
        if (request.message?.token == 'token2') {
          return Future.error('error');
        }
        return Future.value(fmc1.Message(name: 'success'));
      });

      final result = await messaging.sendEachForMulticast(
        MulticastMessage(tokens: ['token1', 'token2', 'token3']),
      );

      expect(result.successCount, 2);
      expect(result.failureCount, 1);
      expect(result.responses.length, 3);

      expect(result.responses[0].success, true);
      expect(result.responses[0].messageId, 'success');
      expect(result.responses[1].success, false);
      expect(result.responses[1].error, isA<FirebaseMessagingAdminException>());
      expect(result.responses[2].success, true);
      expect(result.responses[2].messageId, 'success');
    });
  });

  group('Topic Management', () {
    late MockAuthClient mockAuthClient;

    void mockWithClient<T>() {
      when(() => httpClient.withClient<T>(any())).thenAnswer((
        invocation,
      ) async {
        final callback = invocation.positionalArguments.first as Function;
        final result = await Function.apply(callback, [
          mockAuthClient,
          projectId,
        ]);
        return result as T;
      });
    }

    setUp(() {
      mockAuthClient = MockAuthClient();
      mockWithClient<MessagingTopicManagementResponse>();
    });

    group('subscribeToTopic', () {
      test('should validate empty registration tokens list', () async {
        expect(
          () => messaging.subscribeToTopic([], 'test-topic'),
          throwsA(
            isA<FirebaseMessagingAdminException>()
                .having(
                  (e) => e.errorCode,
                  'errorCode',
                  MessagingClientErrorCode.invalidArgument,
                )
                .having(
                  (e) => e.message,
                  'message',
                  contains('must be a non-empty list'),
                ),
          ),
        );
      });

      test('should validate empty token strings', () async {
        expect(
          () => messaging.subscribeToTopic([
            'token1',
            '',
            'token3',
          ], 'test-topic'),
          throwsA(
            isA<FirebaseMessagingAdminException>()
                .having(
                  (e) => e.errorCode,
                  'errorCode',
                  MessagingClientErrorCode.invalidArgument,
                )
                .having(
                  (e) => e.message,
                  'message',
                  contains('must all be non-empty strings'),
                ),
          ),
        );
      });

      test('should validate > 1000 registration tokens', () async {
        final tokens = List.generate(1001, (i) => 'token$i');
        expect(
          () => messaging.subscribeToTopic(tokens, 'test-topic'),
          throwsA(
            isA<FirebaseMessagingAdminException>()
                .having(
                  (e) => e.errorCode,
                  'errorCode',
                  MessagingClientErrorCode.invalidArgument,
                )
                .having(
                  (e) => e.message,
                  'message',
                  contains('must not contain more than 1000 tokens'),
                ),
          ),
        );
      });

      test('should validate empty topic', () async {
        expect(
          () => messaging.subscribeToTopic(['token1'], ''),
          throwsA(
            isA<FirebaseMessagingAdminException>()
                .having(
                  (e) => e.errorCode,
                  'errorCode',
                  MessagingClientErrorCode.invalidArgument,
                )
                .having(
                  (e) => e.message,
                  'message',
                  contains('must be a non-empty string'),
                ),
          ),
        );
      });

      test('should validate topic format', () async {
        when(
          () => mockAuthClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => Response('{}', 200));

        // Valid topics should not throw
        for (final topic in [
          'test-topic',
          '/topics/test-topic',
          'test_topic',
          'test.topic',
          'test~topic',
          'test%20topic',
        ]) {
          await messaging.subscribeToTopic(['token1'], topic);
        }

        // Invalid topics should throw
        for (final topic in [
          'test topic', // space not allowed
          'test@topic', // @ not allowed
          'test#topic', // # not allowed
          'private/test-topic', // nested path / private not allowed
          'test/topic', // slashes not allowed
        ]) {
          expect(
            () => messaging.subscribeToTopic(['token1'], topic),
            throwsA(
              isA<FirebaseMessagingAdminException>()
                  .having(
                    (e) => e.errorCode,
                    'errorCode',
                    MessagingClientErrorCode.invalidArgument,
                  )
                  .having(
                    (e) => e.message,
                    'message',
                    contains('must be a string which matches the format'),
                  ),
            ),
          );
        }
      });

      test(
        'should make request to FCM v1 REST API with correct parameters',
        () async {
          when(
            () => mockAuthClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => Response('{}', 200));

          final response = await messaging.subscribeToTopic([
            'token1',
            'token2',
          ], 'test-topic');

          expect(response.successCount, 2);
          expect(response.failureCount, 0);
          expect(response.errors, isEmpty);

          final captured = verify(
            () => mockAuthClient.post(
              captureAny(),
              headers: captureAny(named: 'headers'),
              body: captureAny(named: 'body'),
            ),
          )..called(2);

          final uri1 = captured.captured[0] as Uri;
          expect(
            uri1.toString(),
            'https://fcm.googleapis.com/v1/projects/$projectId/registrations/token1/topicSubscriptions?topic_name=test-topic',
          );
          final headers1 = captured.captured[1] as Map<String, String>;
          expect(headers1['x-goog-api-format-version'], '2');
          expect(headers1['content-type'], 'application/json; charset=UTF-8');
          final body1 = captured.captured[2] as String;
          expect(body1, '{}');
        },
      );

      test(
        'should normalize topic by stripping /topics/ prefix in URL',
        () async {
          when(
            () => mockAuthClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => Response('{}', 200));

          await messaging.subscribeToTopic(['token1'], '/topics/test-topic');

          final captured = verify(
            () => mockAuthClient.post(
              captureAny(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          )..called(1);

          final uri = captured.captured.first as Uri;
          expect(
            uri.toString(),
            'https://fcm.googleapis.com/v1/projects/$projectId/registrations/token1/topicSubscriptions?topic_name=test-topic',
          );
        },
      );

      test('should treat 409 Conflict / ALREADY_EXISTS as success', () async {
        when(
          () => mockAuthClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => Response(
            jsonEncode({
              'error': {
                'status': 'ALREADY_EXISTS',
                'message': 'Already subscribed.',
              },
            }),
            409,
            headers: {'content-type': 'application/json'},
          ),
        );

        final response = await messaging.subscribeToTopic([
          'token1',
        ], 'test-topic');

        expect(response.successCount, 1);
        expect(response.failureCount, 0);
        expect(response.errors, isEmpty);
      });

      test(
        'should return response with partial failures and FcmError details',
        () async {
          when(
            () => mockAuthClient.post(
              any(that: predicate<Uri>((u) => u.toString().contains('token1'))),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => Response('{}', 200));

          when(
            () => mockAuthClient.post(
              any(that: predicate<Uri>((u) => u.toString().contains('token2'))),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer(
            (_) async => Response(
              jsonEncode({
                'error': {
                  'status': 'NOT_FOUND',
                  'message': 'Requested entity was not found.',
                  'details': [
                    {
                      '@type':
                          'type.googleapis.com/google.firebase.fcm.v1.FcmError',
                      'errorCode': 'UNREGISTERED',
                    },
                  ],
                },
              }),
              404,
              headers: {'content-type': 'application/json'},
            ),
          );

          final response = await messaging.subscribeToTopic([
            'token1',
            'token2',
          ], 'test-topic');

          expect(response.successCount, 1);
          expect(response.failureCount, 1);
          expect(response.errors.length, 1);
          expect(response.errors[0].index, 1);
          expect(
            response.errors[0].error,
            isA<FirebaseMessagingAdminException>().having(
              (e) => e.errorCode,
              'errorCode',
              MessagingClientErrorCode.registrationTokenNotRegistered,
            ),
          );
        },
      );
    });

    group('unsubscribeFromTopic', () {
      test('should validate empty registration tokens list', () async {
        expect(
          () => messaging.unsubscribeFromTopic([], 'test-topic'),
          throwsA(
            isA<FirebaseMessagingAdminException>()
                .having(
                  (e) => e.errorCode,
                  'errorCode',
                  MessagingClientErrorCode.invalidArgument,
                )
                .having(
                  (e) => e.message,
                  'message',
                  contains('must be a non-empty list'),
                ),
          ),
        );
      });

      test(
        'should make DELETE request to FCM v1 REST API with correct parameters',
        () async {
          when(
            () => mockAuthClient.delete(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => Response('{}', 200));

          final response = await messaging.unsubscribeFromTopic([
            'token1',
            'token2',
          ], 'test-topic');

          expect(response.successCount, 2);
          expect(response.failureCount, 0);
          expect(response.errors, isEmpty);

          final captured = verify(
            () => mockAuthClient.delete(
              captureAny(),
              headers: captureAny(named: 'headers'),
            ),
          )..called(2);

          final uri1 = captured.captured[0] as Uri;
          expect(
            uri1.toString(),
            'https://fcm.googleapis.com/v1/projects/$projectId/registrations/token1/topicSubscriptions/test-topic?allow_missing=true',
          );
          final headers1 = captured.captured[1] as Map<String, String>;
          expect(headers1['x-goog-api-format-version'], '2');
        },
      );

      test('should handle 404 Not Found as error on unsubscribe', () async {
        when(
          () => mockAuthClient.delete(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => Response(
            jsonEncode({
              'error': {'status': 'NOT_FOUND', 'message': 'Not found.'},
            }),
            404,
            headers: {'content-type': 'application/json'},
          ),
        );

        final response = await messaging.unsubscribeFromTopic([
          'token1',
        ], 'test-topic');

        expect(response.successCount, 0);
        expect(response.failureCount, 1);
        expect(response.errors.length, 1);
        expect(response.errors[0].index, 0);
        expect(
          response.errors[0].error,
          isA<FirebaseMessagingAdminException>().having(
            (e) => e.errorCode,
            'errorCode',
            MessagingClientErrorCode.registrationTokenNotRegistered,
          ),
        );
      });
    });

    group('Legacy topic management', () {
      test(
        'subscribeToTopicLegacy should make request to IID API with correct parameters',
        () async {
          when(
            () => httpClient.invokeRequestHandler(
              host: any(named: 'host'),
              path: any(named: 'path'),
              requestData: any(named: 'requestData'),
            ),
          ).thenAnswer(
            (_) async => <String, dynamic>{
              'results': [<String, dynamic>{}, <String, dynamic>{}],
            },
          );

          final response = await messaging.subscribeToTopicLegacy([
            'token1',
            'token2',
          ], 'test-topic');

          expect(response.successCount, 2);
          expect(response.failureCount, 0);
          expect(response.errors, isEmpty);

          final capture = verify(
            () => httpClient.invokeRequestHandler(
              host: captureAny(named: 'host'),
              path: captureAny(named: 'path'),
              requestData: captureAny(named: 'requestData'),
            ),
          )..called(1);

          expect(capture.captured[0], 'iid.googleapis.com');
          expect(capture.captured[1], '/iid/v1:batchAdd');
          final requestData = capture.captured[2] as Map<String, Object?>;
          expect(requestData['to'], '/topics/test-topic');
          expect(requestData['registration_tokens'], ['token1', 'token2']);
        },
      );

      test(
        'unsubscribeFromTopicLegacy should make request to IID API with correct parameters',
        () async {
          when(
            () => httpClient.invokeRequestHandler(
              host: any(named: 'host'),
              path: any(named: 'path'),
              requestData: any(named: 'requestData'),
            ),
          ).thenAnswer(
            (_) async => <String, dynamic>{
              'results': [<String, dynamic>{}, <String, dynamic>{}],
            },
          );

          final response = await messaging.unsubscribeFromTopicLegacy([
            'token1',
            'token2',
          ], 'test-topic');

          expect(response.successCount, 2);
          expect(response.failureCount, 0);
          expect(response.errors, isEmpty);

          final capture = verify(
            () => httpClient.invokeRequestHandler(
              host: captureAny(named: 'host'),
              path: captureAny(named: 'path'),
              requestData: captureAny(named: 'requestData'),
            ),
          )..called(1);

          expect(capture.captured[0], 'iid.googleapis.com');
          expect(capture.captured[1], '/iid/v1:batchRemove');
          final requestData = capture.captured[2] as Map<String, Object?>;
          expect(requestData['to'], '/topics/test-topic');
          expect(requestData['registration_tokens'], ['token1', 'token2']);
        },
      );
    });
  });
}
