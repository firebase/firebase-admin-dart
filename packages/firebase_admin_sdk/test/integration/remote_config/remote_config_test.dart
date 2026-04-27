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

// Firebase Remote Config integration tests.
//
// SAFETY: Remote Config has no emulator, so these tests hit the real API.
// They run a publish/rollback cycle against the project identified by the
// `RC_TEST_PROJECT_ID` env var. The rollback at the end of the suite
// restores the project's prior template version, so the net change to the
// project is zero on a successful run.
//
// Local: `gcloud beta auth application-default login`,
//        `export RC_TEST_PROJECT_ID=<your-project>`, and
//        `RUN_PROD_TESTS=true dart test test/integration/remote_config/`.
// CI:    runs in the `test-wif` GitHub Actions job, which authenticates
//        via Workload Identity Federation; the bound service account must
//        have `roles/firebaseremoteconfig.admin` on the project, and the
//        project ID must be supplied via the `RC_TEST_PROJECT_ID` env var
//        (e.g. via a workflow-level `env:` block backed by a secret).

import 'dart:io';

import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:firebase_admin_sdk/remote_config.dart';
import 'package:test/test.dart';

import '../../fixtures/helpers.dart';

final _rcProjectId = Platform.environment['RC_TEST_PROJECT_ID'];

const _validConditions = [
  RemoteConfigCondition(
    name: 'ios',
    expression: "device.os == 'ios'",
    tagColor: TagColor.indigo,
  ),
  RemoteConfigCondition(
    name: 'android',
    expression: "device.os == 'android'",
    tagColor: TagColor.green,
  ),
];

// `RemoteConfigParameter` isn't const (it wraps `conditionalValues` in
// `Map.unmodifiable` internally), so this is `final` rather than `const`.
final _validParameter = RemoteConfigParameter(
  defaultValue: const ExplicitParameterValue(value: 'hello'),
  description: 'dart_admin_sdk e2e test parameter',
  valueType: ParameterValueType.string,
);

void main() {
  // Three conditions must hold for the suite to run:
  //   - RC_TEST_PROJECT_ID is set (target project for the round-trip).
  //   - Credentials are available (CI WIF sets GOOGLE_APPLICATION_CREDENTIALS;
  //     local opt-in via RUN_PROD_TESTS=true).
  final projectId = _rcProjectId;
  final shouldRun = projectId != null && (hasWifEnv || hasProdEnv);
  final skipReason = shouldRun
      ? null
      : 'Requires RC_TEST_PROJECT_ID plus GOOGLE_APPLICATION_CREDENTIALS or RUN_PROD_TESTS=true';

  group('RemoteConfig (production)', () {
    late FirebaseApp app;
    late RemoteConfig rc;
    late RemoteConfigTemplate baseline;

    setUpAll(() async {
      app = FirebaseApp.initializeApp(
        name: 'rc-e2e-${DateTime.now().microsecondsSinceEpoch}',
        options: AppOptions(projectId: projectId),
      );
      rc = app.remoteConfig();
      baseline = await rc.getTemplate();
    });

    tearDownAll(() async {
      await app.close();
    });

    test('getTemplate returns a template with a non-empty etag', () {
      expect(baseline.etag, isNotEmpty);
    });

    test('validateTemplate succeeds with a valid template', () async {
      final candidate = RemoteConfigTemplate(
        etag: baseline.etag,
        conditions: _validConditions,
        parameters: <String, RemoteConfigParameter>{
          ...baseline.parameters,
          'dart_admin_sdk_e2e_marker': _validParameter,
        },
        parameterGroups: baseline.parameterGroups,
        version: const Version(description: 'dart_admin_sdk e2e validate'),
      );

      final validated = await rc.validateTemplate(candidate);
      // Validate-only restores the original etag in our request handler.
      expect(validated.etag, baseline.etag);
    });

    test(
      'validateTemplate propagates invalid-argument when conditions reference unknown names',
      () async {
        final invalid = RemoteConfigTemplate(
          etag: baseline.etag,
          // No conditions defined, but the parameter below references
          // a non-existent condition name.
          conditions: const <RemoteConfigCondition>[],
          parameters: <String, RemoteConfigParameter>{
            ...baseline.parameters,
            'dart_admin_sdk_e2e_marker': RemoteConfigParameter(
              defaultValue: const ExplicitParameterValue(value: 'x'),
              conditionalValues: const <String, RemoteConfigParameterValue>{
                'never_declared_condition': ExplicitParameterValue(value: 'y'),
              },
            ),
          },
          parameterGroups: baseline.parameterGroups,
        );

        await expectLater(
          rc.validateTemplate(invalid),
          throwsA(
            isA<FirebaseRemoteConfigException>().having(
              (e) => e.errorCode,
              'errorCode',
              RemoteConfigErrorCode.invalidArgument,
            ),
          ),
        );
      },
    );

    test(
      'publishTemplate -> getTemplate -> rollback round-trip',
      () async {
        // 1. Publish a marker parameter on top of the current baseline.
        final stamp = DateTime.now().toUtc().toIso8601String();
        final candidate = RemoteConfigTemplate(
          etag: baseline.etag,
          conditions: _validConditions,
          parameters: <String, RemoteConfigParameter>{
            ...baseline.parameters,
            'dart_admin_sdk_e2e_marker': RemoteConfigParameter(
              defaultValue: ExplicitParameterValue(value: stamp),
              description: 'e2e $stamp',
              valueType: ParameterValueType.string,
            ),
          },
          parameterGroups: baseline.parameterGroups,
          version: Version(description: 'dart_admin_sdk e2e $stamp'),
        );

        final published = await rc.publishTemplate(candidate);
        expect(published.etag, isNot(equals(baseline.etag)));
        expect(
          published.parameters.containsKey('dart_admin_sdk_e2e_marker'),
          isTrue,
        );

        // 2. Fetch and verify the marker is visible.
        final fetched = await rc.getTemplate();
        final marker = fetched.parameters['dart_admin_sdk_e2e_marker'];
        expect(marker, isNotNull);
        expect((marker!.defaultValue! as ExplicitParameterValue).value, stamp);

        // 3. Roll back to the prior version; project state should match
        //    the baseline we captured in setUpAll. The bound service
        //    account needs `roles/firebaseanalytics.viewer` on the
        //    linked GA property in addition to
        //    `roles/firebaseremoteconfig.admin`, since RC's rollback
        //    endpoint validates against Google Analytics data.
        final priorVersion = baseline.version?.versionNumber;
        if (priorVersion != null) {
          final rolledBack = await rc.rollback(priorVersion);
          expect(
            rolledBack.parameters.containsKey('dart_admin_sdk_e2e_marker'),
            isFalse,
            reason: 'rollback should remove the e2e marker parameter',
          );
        }
      },
      // Round-trip can take a bit; allow generous time.
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'listVersions returns at least the version we just published',
      () async {
        final result = await rc.listVersions(ListVersionsOptions(pageSize: 5));
        expect(result.versions, isNotEmpty);
        // Newest first per the REST API.
        expect(result.versions.first.versionNumber, isNotNull);
      },
    );

    test(
      'getTemplate(versionNumber) returns a specific historical version',
      () async {
        // Pick the latest known version from listVersions and re-fetch it
        // explicitly. The returned template must echo that version number
        // back in `version.versionNumber`.
        final list = await rc.listVersions(ListVersionsOptions(pageSize: 1));
        expect(list.versions, isNotEmpty);
        final versionNumber = list.versions.first.versionNumber;
        expect(versionNumber, isNotNull);

        final atVersion = await rc.getTemplate(versionNumber);
        expect(atVersion.etag, isNotEmpty);
        expect(atVersion.version, isNotNull);
        expect(atVersion.version!.versionNumber, versionNumber);
      },
    );

    test(
      'publishTemplate(force: true) bypasses ETag validation',
      () async {
        // 1. Build a candidate from the current active template, but stamp
        //    a deliberately stale ETag to force the version-mismatch path.
        final current = await rc.getTemplate();
        final stamp = DateTime.now().toUtc().toIso8601String();
        final cleanCurrent = Map<String, RemoteConfigParameter>.from(
          current.parameters,
        )..remove('dart_admin_sdk_e2e_marker');
        final staleCandidate = RemoteConfigTemplate(
          // Stale: not the server's actual current ETag.
          etag: 'etag-deliberately-stale',
          conditions: current.conditions,
          parameters: <String, RemoteConfigParameter>{
            ...cleanCurrent,
            'dart_admin_sdk_e2e_marker': RemoteConfigParameter(
              defaultValue: ExplicitParameterValue(value: 'force-$stamp'),
              description: 'e2e force-publish $stamp',
              valueType: ParameterValueType.string,
            ),
          },
          parameterGroups: current.parameterGroups,
          version: const Version(description: 'dart_admin_sdk e2e force'),
        );

        // 2. Without force, the server rejects the stale ETag.
        await expectLater(
          rc.publishTemplate(staleCandidate),
          throwsA(isA<FirebaseRemoteConfigException>()),
        );

        // 3. With force=true, the SDK sends `If-Match: *` and the publish
        //    succeeds despite the stale ETag in the candidate.
        final published = await rc.publishTemplate(staleCandidate, force: true);
        expect(
          published.parameters.containsKey('dart_admin_sdk_e2e_marker'),
          isTrue,
        );

        // 4. Cleanup: roll back to baseline so subsequent tests see the
        //    original state.
        final priorVersion = baseline.version?.versionNumber;
        if (priorVersion != null) {
          await rc.rollback(priorVersion);
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test('getServerTemplate + evaluate produces a ServerConfig', () async {
      // Server-side templates are a separate resource and can only be
      // authored via the Firebase Console (the public REST API exposes
      // GET on this namespace but no write path). If the target project
      // has no server template configured, the API returns NOT_FOUND;
      // we fall back to initServerTemplate with an empty cached template
      // so the evaluator still smoke-tests cleanly.
      ServerTemplate serverTemplate;
      try {
        serverTemplate = await rc.getServerTemplate(
          defaultConfig: const <String, Object>{
            'dart_admin_sdk_e2e_in_app_only': 'fallback',
          },
        );
      } on FirebaseRemoteConfigException catch (e) {
        if (e.errorCode != RemoteConfigErrorCode.notFound) rethrow;
        serverTemplate = rc.initServerTemplate(
          defaultConfig: const <String, Object>{
            'dart_admin_sdk_e2e_in_app_only': 'fallback',
          },
          template: '{"etag":"e2e-empty","conditions":[],"parameters":{}}',
        );
      }

      final config = serverTemplate.evaluate(
        const EvaluationContext(randomizationId: 'dart_admin_sdk_e2e_user'),
      );

      // A key that exists ONLY in the in-app defaultConfig (never published
      // to the server template) must resolve from `valueDefault`.
      expect(
        config.getValue('dart_admin_sdk_e2e_in_app_only').getSource(),
        ValueSource.valueDefault,
      );
      expect(config.getString('dart_admin_sdk_e2e_in_app_only'), 'fallback');
      // Unknown keys fall through to static defaults.
      expect(
        config.getValue('definitely_not_a_real_key').getSource(),
        ValueSource.valueStatic,
      );
    });
  }, skip: skipReason);
}
