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

    test('should validate empty tokens list', () {
      expect(
        () => messaging.sendEachForMulticast(MulticastMessage(tokens: [])),
        throwsA(
          isA<FirebaseMessagingAdminException>().having(
            (e) => e.message,
            'message',
            'messages must be a non-empty array',
          ),
        ),
      );
    });

    test('should validate tokens list does not exceed 500', () {
      expect(
        () => messaging.sendEachForMulticast(
          MulticastMessage(
            tokens: List.generate(501, (index) => 'token$index'),
          ),
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
          () => httpClient.invokeRequestHandler(
            host: any(named: 'host'),
            path: any(named: 'path'),
            requestData: any(named: 'requestData'),
          ),
        ).thenAnswer((_) async => <String, dynamic>{});

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
          '/topics/', // empty after /topics/
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

      test('should normalize topic by prepending /topics/', () async {
        when(
          () => httpClient.invokeRequestHandler(
            host: any(named: 'host'),
            path: any(named: 'path'),
            requestData: any(named: 'requestData'),
          ),
        ).thenAnswer(
          (_) async => <String, dynamic>{
            'results': [<String, dynamic>{}],
          },
        );

        await messaging.subscribeToTopic(['token1'], 'test-topic');

        final capture = verify(
          () => httpClient.invokeRequestHandler(
            host: captureAny(named: 'host'),
            path: captureAny(named: 'path'),
            requestData: captureAny(named: 'requestData'),
          ),
        )..called(1);

        final requestData = capture.captured.last as Map<String, Object?>;
        expect(requestData['to'], '/topics/test-topic');
      });

      test('should not modify topic already starting with /topics/', () async {
        when(
          () => httpClient.invokeRequestHandler(
            host: any(named: 'host'),
            path: any(named: 'path'),
            requestData: any(named: 'requestData'),
          ),
        ).thenAnswer(
          (_) async => <String, dynamic>{
            'results': [<String, dynamic>{}],
          },
        );

        await messaging.subscribeToTopic(['token1'], '/topics/test-topic');

        final capture = verify(
          () => httpClient.invokeRequestHandler(
            host: captureAny(named: 'host'),
            path: captureAny(named: 'path'),
            requestData: captureAny(named: 'requestData'),
          ),
        )..called(1);

        final requestData = capture.captured.last as Map<String, Object?>;
        expect(requestData['to'], '/topics/test-topic');
      });

      test('should make request to IID API with correct parameters', () async {
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

        await messaging.subscribeToTopic(['token1', 'token2'], 'test-topic');

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
      });

      test('should return success response with all successes', () async {
        when(
          () => httpClient.invokeRequestHandler(
            host: any(named: 'host'),
            path: any(named: 'path'),
            requestData: any(named: 'requestData'),
          ),
        ).thenAnswer(
          (_) async => <String, dynamic>{
            'results': [
              <String, dynamic>{},
              <String, dynamic>{},
              <String, dynamic>{},
            ],
          },
        );

        final response = await messaging.subscribeToTopic([
          'token1',
          'token2',
          'token3',
        ], 'test-topic');

        expect(response.successCount, 3);
        expect(response.failureCount, 0);
        expect(response.errors, isEmpty);
      });

      test('should return response with partial failures', () async {
        when(
          () => httpClient.invokeRequestHandler(
            host: any(named: 'host'),
            path: any(named: 'path'),
            requestData: any(named: 'requestData'),
          ),
        ).thenAnswer(
          (_) async => <String, dynamic>{
            'results': [
              <String, dynamic>{},
              <String, dynamic>{'error': 'INVALID_ARGUMENT'},
              <String, dynamic>{},
              <String, dynamic>{'error': 'NOT_FOUND'},
            ],
          },
        );

        final response = await messaging.subscribeToTopic([
          'token1',
          'token2',
          'token3',
          'token4',
        ], 'test-topic');

        expect(response.successCount, 2);
        expect(response.failureCount, 2);
        expect(response.errors.length, 2);
        expect(response.errors[0].index, 1);
        expect(
          response.errors[0].error,
          isA<FirebaseMessagingAdminException>().having(
            (e) => e.message,
            'message',
            'INVALID_ARGUMENT',
          ),
        );
        expect(response.errors[1].index, 3);
        expect(
          response.errors[1].error,
          isA<FirebaseMessagingAdminException>().having(
            (e) => e.message,
            'message',
            'NOT_FOUND',
          ),
        );
      });
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

      test('should make request to IID API with correct parameters', () async {
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

        await messaging.unsubscribeFromTopic([
          'token1',
          'token2',
        ], 'test-topic');

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
      });

      test('should return success response', () async {
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

        final response = await messaging.unsubscribeFromTopic([
          'token1',
          'token2',
        ], 'test-topic');

        expect(response.successCount, 2);
        expect(response.failureCount, 0);
        expect(response.errors, isEmpty);
      });
    });
  });
}
