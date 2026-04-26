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

import 'package:firebase_admin_sdk/src/remote_config/remote_config.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../fixtures/helpers.dart';

class _MockHttpClient extends Mock implements RemoteConfigHttpClient {}

const _sampleTemplateBody = <String, Object?>{
  'conditions': <Object?>[],
  'parameters': <String, Object?>{
    'flag': <String, Object?>{
      'defaultValue': <String, Object?>{'value': 'on'},
    },
  },
  'parameterGroups': <String, Object?>{},
};

const _sampleServerTemplateBody = <String, Object?>{
  'conditions': <Object?>[],
  'parameters': <String, Object?>{
    'flag': <String, Object?>{
      'defaultValue': <String, Object?>{'value': 'on'},
    },
  },
};

const _sampleListVersionsBody = <String, Object?>{
  'versions': <Object?>[
    <String, Object?>{
      'versionNumber': '7',
      'updateOrigin': 'CONSOLE',
      'updateType': 'INCREMENTAL_UPDATE',
      'description': 'tweak',
    },
    <String, Object?>{'versionNumber': '6'},
  ],
  'nextPageToken': 'tok-2',
};

void main() {
  late _MockHttpClient httpClient;
  late RemoteConfig rc;

  setUp(() {
    httpClient = _MockHttpClient();
    final app = createApp(
      name: 'rc-svc-${DateTime.now().microsecondsSinceEpoch}',
    );
    rc = RemoteConfig.internal(
      app,
      requestHandler: RemoteConfigRequestHandler(app, httpClient: httpClient),
    );
  });

  group('getTemplate', () {
    test('returns parsed template with etag from response header', () async {
      when(
        () => httpClient.getTemplate(),
      ).thenAnswer((_) async => (body: _sampleTemplateBody, etag: 'etag-1'));

      final template = await rc.getTemplate();
      expect(template.etag, 'etag-1');
      expect(template.parameters['flag'], isA<RemoteConfigParameter>());
      expect(
        (template.parameters['flag']!.defaultValue! as ExplicitParameterValue)
            .value,
        'on',
      );
    });

    test('throws when response is missing the ETag header', () async {
      when(
        () => httpClient.getTemplate(),
      ).thenAnswer((_) async => (body: _sampleTemplateBody, etag: null));

      await expectLater(
        rc.getTemplate(),
        throwsA(
          isA<FirebaseRemoteConfigException>().having(
            (e) => e.errorCode,
            'errorCode',
            RemoteConfigErrorCode.invalidArgument,
          ),
        ),
      );
    });
  });

  group('getTemplate(versionNumber)', () {
    test('passes versionNumber through to the HTTP client', () async {
      when(
        () => httpClient.getTemplate(versionNumber: '42'),
      ).thenAnswer((_) async => (body: _sampleTemplateBody, etag: 'etag-v'));

      final template = await rc.getTemplate('42');
      expect(template.etag, 'etag-v');
      verify(() => httpClient.getTemplate(versionNumber: '42')).called(1);
    });

    test('throws on non-integer versionNumber', () async {
      await expectLater(
        rc.getTemplate('abc'),
        throwsA(
          isA<FirebaseRemoteConfigException>().having(
            (e) => e.errorCode,
            'errorCode',
            RemoteConfigErrorCode.invalidArgument,
          ),
        ),
      );
    });
  });

  group('publishTemplate', () {
    test('sends If-Match: <etag> by default', () async {
      when(
        () => httpClient.publishTemplate(
          body: any(named: 'body'),
          etag: any(named: 'etag'),
          validateOnly: any(named: 'validateOnly'),
        ),
      ).thenAnswer((_) async => (body: _sampleTemplateBody, etag: 'etag-2'));

      final input = rc.createTemplateFromJson(
        '{"etag":"etag-1","conditions":[],"parameters":{},"parameterGroups":{}}',
      );
      final published = await rc.publishTemplate(input);
      expect(published.etag, 'etag-2');

      final captured = verify(
        () => httpClient.publishTemplate(
          body: captureAny(named: 'body'),
          etag: captureAny(named: 'etag'),
          validateOnly: captureAny(named: 'validateOnly'),
        ),
      ).captured;
      expect(captured[1], 'etag-1');
      expect(captured[2], false);
      expect(
        (captured[0] as Map<String, Object?>).containsKey('etag'),
        isFalse,
      );
    });

    test('sends If-Match: * when force is true', () async {
      when(
        () => httpClient.publishTemplate(
          body: any(named: 'body'),
          etag: any(named: 'etag'),
          validateOnly: any(named: 'validateOnly'),
        ),
      ).thenAnswer((_) async => (body: _sampleTemplateBody, etag: 'etag-3'));

      final input = rc.createTemplateFromJson(
        '{"etag":"old","conditions":[],"parameters":{},"parameterGroups":{}}',
      );
      await rc.publishTemplate(input, force: true);

      final captured = verify(
        () => httpClient.publishTemplate(
          body: any(named: 'body'),
          etag: captureAny(named: 'etag'),
          validateOnly: any(named: 'validateOnly'),
        ),
      ).captured;
      expect(captured.single, '*');
    });

    test(
      'strips output-only Version fields and keeps only description',
      () async {
        when(
          () => httpClient.publishTemplate(
            body: any(named: 'body'),
            etag: any(named: 'etag'),
            validateOnly: any(named: 'validateOnly'),
          ),
        ).thenAnswer((_) async => (body: _sampleTemplateBody, etag: 'etag-4'));

        const json = '''{
        "etag": "old",
        "conditions": [],
        "parameters": {},
        "parameterGroups": {},
        "version": {
          "versionNumber": "5",
          "updateOrigin": "CONSOLE",
          "updateType": "FORCED_UPDATE",
          "description": "Manual edit"
        }
      }''';
        await rc.publishTemplate(rc.createTemplateFromJson(json));

        final captured =
            verify(
                  () => httpClient.publishTemplate(
                    body: captureAny(named: 'body'),
                    etag: any(named: 'etag'),
                    validateOnly: any(named: 'validateOnly'),
                  ),
                ).captured.single
                as Map<String, Object?>;
        // Only the user-input description survives; output-only fields are gone.
        expect(captured['version'], <String, Object?>{
          'description': 'Manual edit',
        });
      },
    );
  });

  group('validateTemplate', () {
    test(
      'restores the original etag instead of the "-0"-suffixed response',
      () async {
        // The Remote Config backend returns the input etag with a "-0" suffix on
        // a successful validation.  The handler must overwrite that with the
        // request etag so callers can keep using the template.
        when(
          () => httpClient.publishTemplate(
            body: any(named: 'body'),
            etag: 'etag-1',
            validateOnly: true,
          ),
        ).thenAnswer(
          (_) async => (body: _sampleTemplateBody, etag: 'etag-1-0'),
        );

        final input = rc.createTemplateFromJson(
          '{"etag":"etag-1","conditions":[],"parameters":{},"parameterGroups":{}}',
        );
        final validated = await rc.validateTemplate(input);
        expect(validated.etag, 'etag-1');
      },
    );

    test('passes validateOnly: true', () async {
      when(
        () => httpClient.publishTemplate(
          body: any(named: 'body'),
          etag: any(named: 'etag'),
          validateOnly: true,
        ),
      ).thenAnswer((_) async => (body: _sampleTemplateBody, etag: 'etag-1-0'));

      final input = rc.createTemplateFromJson(
        '{"etag":"etag-1","conditions":[],"parameters":{},"parameterGroups":{}}',
      );
      await rc.validateTemplate(input);

      verify(
        () => httpClient.publishTemplate(
          body: any(named: 'body'),
          etag: 'etag-1',
          validateOnly: true,
        ),
      ).called(1);
    });
  });

  group('rollback', () {
    test('forwards versionNumber to the HTTP client', () async {
      when(
        () => httpClient.rollback('5'),
      ).thenAnswer((_) async => (body: _sampleTemplateBody, etag: 'etag-r'));

      final result = await rc.rollback('5');
      expect(result.etag, 'etag-r');
      verify(() => httpClient.rollback('5')).called(1);
    });

    test('throws on non-integer versionNumber', () async {
      await expectLater(
        rc.rollback('abc'),
        throwsA(
          isA<FirebaseRemoteConfigException>().having(
            (e) => e.errorCode,
            'errorCode',
            RemoteConfigErrorCode.invalidArgument,
          ),
        ),
      );
    });
  });

  group('listVersions', () {
    test('parses the response into a ListVersionsResult', () async {
      when(
        () => httpClient.listVersions(
          pageSize: any(named: 'pageSize'),
          pageToken: any(named: 'pageToken'),
          endVersionNumber: any(named: 'endVersionNumber'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer((_) async => _sampleListVersionsBody);

      final result = await rc.listVersions();
      expect(result.versions, hasLength(2));
      expect(result.versions[0].versionNumber, '7');
      expect(result.versions[0].updateOrigin, 'CONSOLE');
      expect(result.versions[0].description, 'tweak');
      expect(result.versions[1].versionNumber, '6');
      expect(result.nextPageToken, 'tok-2');
    });

    test('passes options through verbatim', () async {
      when(
        () => httpClient.listVersions(
          pageSize: 10,
          pageToken: 'tok-1',
          endVersionNumber: '20',
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer(
        (_) async => const <String, Object?>{'versions': <Object?>[]},
      );

      await rc.listVersions(
        ListVersionsOptions(
          pageSize: 10,
          pageToken: 'tok-1',
          endVersionNumber: '20',
        ),
      );

      verify(
        () => httpClient.listVersions(
          pageSize: 10,
          pageToken: 'tok-1',
          endVersionNumber: '20',
          startTime: null,
          endTime: null,
        ),
      ).called(1);
    });
  });

  group('getServerTemplate', () {
    test('loads, parses, and stamps the etag from the response', () async {
      when(() => httpClient.getServerTemplate()).thenAnswer(
        (_) async => (body: _sampleServerTemplateBody, etag: 'srv-1'),
      );

      final template = await rc.getServerTemplate();
      // Re-evaluate against an empty context — confirms the template made it
      // into the cache and the parameter resolved via its default value.
      final config = template.evaluate();
      expect(config.getString('flag'), 'on');
    });

    test('initServerTemplate without a template throws on evaluate', () {
      final template = rc.initServerTemplate();
      expect(
        template.evaluate,
        throwsA(
          isA<FirebaseRemoteConfigException>().having(
            (e) => e.errorCode,
            'errorCode',
            RemoteConfigErrorCode.failedPrecondition,
          ),
        ),
      );
    });
  });
}
