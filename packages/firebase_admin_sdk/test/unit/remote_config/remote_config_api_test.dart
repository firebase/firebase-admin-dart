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

import 'package:firebase_admin_sdk/remote_config.dart';
import 'package:test/test.dart';

import '../../fixtures/helpers.dart';

void main() {
  late RemoteConfig rc;

  setUp(() {
    final app = createApp(
      name: 'rc-api-test-${DateTime.now().microsecondsSinceEpoch}',
    );
    rc = app.remoteConfig();
  });

  group('RemoteConfig data classes', () {
    test('createTemplateFromJson parses a representative template', () {
      const json = '''{
        "etag": "etag-1",
        "conditions": [
          {"name": "ios", "expression": "device.os == 'iOS'", "tagColor": "BLUE"}
        ],
        "parameters": {
          "welcome_message": {
            "defaultValue": {"value": "Hello"},
            "conditionalValues": {
              "ios": {"value": "Hi from iOS"}
            },
            "description": "Greeting",
            "valueType": "STRING"
          },
          "feature_flag": {
            "defaultValue": {"useInAppDefault": true},
            "valueType": "BOOLEAN"
          }
        },
        "parameterGroups": {
          "ui": {
            "description": "UI parameters",
            "parameters": {
              "color": {"defaultValue": {"value": "blue"}}
            }
          }
        },
        "version": {
          "versionNumber": "42",
          "updateTime": "2026-04-25T10:00:00Z",
          "updateOrigin": "REST_API",
          "updateType": "INCREMENTAL_UPDATE",
          "description": "Initial publish"
        }
      }''';

      final template = rc.createTemplateFromJson(json);

      expect(template.etag, 'etag-1');
      expect(template.conditions, hasLength(1));
      expect(template.conditions[0].name, 'ios');
      expect(template.conditions[0].expression, "device.os == 'iOS'");
      expect(template.conditions[0].tagColor, TagColor.blue);

      expect(template.parameters, hasLength(2));
      final welcome = template.parameters['welcome_message']!;
      expect(welcome.defaultValue, isA<ExplicitParameterValue>());
      expect((welcome.defaultValue! as ExplicitParameterValue).value, 'Hello');
      expect(welcome.conditionalValues, hasLength(1));
      expect(welcome.description, 'Greeting');
      expect(welcome.valueType, ParameterValueType.string);

      final flag = template.parameters['feature_flag']!;
      expect(flag.defaultValue, isA<InAppDefaultValue>());
      expect((flag.defaultValue! as InAppDefaultValue).useInAppDefault, true);
      expect(flag.valueType, ParameterValueType.boolean);

      expect(template.parameterGroups, hasLength(1));
      expect(
        template.parameterGroups['ui']!.parameters['color']!.defaultValue,
        isA<ExplicitParameterValue>(),
      );

      expect(template.version, isNotNull);
      expect(template.version!.versionNumber, '42');
      expect(template.version!.updateOrigin, 'REST_API');
      expect(template.version!.description, 'Initial publish');
    });

    test('createTemplateFromJson throws on missing etag', () {
      const json =
          '{"conditions": [], "parameters": {}, "parameterGroups": {}}';
      expect(
        () => rc.createTemplateFromJson(json),
        throwsA(
          isA<FirebaseRemoteConfigException>().having(
            (e) => e.errorCode,
            'errorCode',
            RemoteConfigErrorCode.invalidArgument,
          ),
        ),
      );
    });

    test('createTemplateFromJson throws on malformed JSON', () {
      expect(
        () => rc.createTemplateFromJson('not-json'),
        throwsA(
          isA<FirebaseRemoteConfigException>().having(
            (e) => e.errorCode,
            'errorCode',
            RemoteConfigErrorCode.invalidArgument,
          ),
        ),
      );
    });

    test('createTemplateFromJson throws on empty input', () {
      expect(
        () => rc.createTemplateFromJson(''),
        throwsA(
          isA<FirebaseRemoteConfigException>().having(
            (e) => e.errorCode,
            'errorCode',
            RemoteConfigErrorCode.invalidArgument,
          ),
        ),
      );
    });

    test('createTemplateFromJson throws when JSON decodes to non-object', () {
      expect(
        () => rc.createTemplateFromJson('[1, 2, 3]'),
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

  group('Constructor validation', () {
    test('PercentCondition rejects out-of-range microPercent', () {
      expect(
        () => PercentCondition(microPercent: -1),
        throwsA(
          isA<FirebaseRemoteConfigException>().having(
            (e) => e.errorCode,
            'errorCode',
            RemoteConfigErrorCode.invalidArgument,
          ),
        ),
      );
      expect(
        () => PercentCondition(microPercent: 100000001),
        throwsA(
          isA<FirebaseRemoteConfigException>().having(
            (e) => e.errorCode,
            'errorCode',
            RemoteConfigErrorCode.invalidArgument,
          ),
        ),
      );
      // Boundaries OK.
      expect(PercentCondition(microPercent: 0).microPercent, 0);
      expect(PercentCondition(microPercent: 100000000).microPercent, 100000000);
    });

    test('PercentCondition rejects seed longer than 32 characters', () {
      expect(
        () => PercentCondition(seed: 'x' * 33),
        throwsA(
          isA<FirebaseRemoteConfigException>().having(
            (e) => e.errorCode,
            'errorCode',
            RemoteConfigErrorCode.invalidArgument,
          ),
        ),
      );
      expect(PercentCondition(seed: 'x' * 32).seed, 'x' * 32);
    });

    test('CustomSignalCondition rejects empty / oversized target arrays', () {
      expect(
        () => CustomSignalCondition(targetCustomSignalValues: const []),
        throwsA(
          isA<FirebaseRemoteConfigException>().having(
            (e) => e.errorCode,
            'errorCode',
            RemoteConfigErrorCode.invalidArgument,
          ),
        ),
      );
      expect(
        () => CustomSignalCondition(
          targetCustomSignalValues: List.filled(101, 'x'),
        ),
        throwsA(
          isA<FirebaseRemoteConfigException>().having(
            (e) => e.errorCode,
            'errorCode',
            RemoteConfigErrorCode.invalidArgument,
          ),
        ),
      );
    });

    test('ListVersionsOptions rejects pageSize out of [1, 300]', () {
      expect(
        () => ListVersionsOptions(pageSize: 0),
        throwsA(isA<FirebaseRemoteConfigException>()),
      );
      expect(
        () => ListVersionsOptions(pageSize: 301),
        throwsA(isA<FirebaseRemoteConfigException>()),
      );
      expect(ListVersionsOptions(pageSize: 1).pageSize, 1);
      expect(ListVersionsOptions(pageSize: 300).pageSize, 300);
    });
  });

  group('Value source-dependent getters', () {
    test('static source always returns defaults', () {
      final v = Value.internal(ValueSource.valueStatic);
      expect(v.asBoolean(), false);
      expect(v.asInt(), 0);
      expect(v.asDouble(), 0.0);
      expect(v.asString(), '');
    });

    test('truthy strings (case-insensitive) → true', () {
      for (final s in const [
        '1',
        'true',
        't',
        'yes',
        'y',
        'on',
        'TRUE',
        'On',
        'YES',
      ]) {
        expect(
          Value.internal(ValueSource.valueRemote, s).asBoolean(),
          isTrue,
          reason: '"$s" should be truthy',
        );
      }
    });

    test('non-truthy strings → false', () {
      for (final s in const ['0', 'false', 'no', '', 'foo', 'off']) {
        expect(
          Value.internal(ValueSource.valueRemote, s).asBoolean(),
          isFalse,
          reason: '"$s" should be falsy',
        );
      }
    });

    test('asInt parses integer strings; non-integers return 0', () {
      expect(Value.internal(ValueSource.valueRemote, '42').asInt(), 42);
      expect(Value.internal(ValueSource.valueRemote, '-5').asInt(), -5);
      // Float strings don't parse as int — caller should use asDouble.
      expect(Value.internal(ValueSource.valueRemote, '3.14').asInt(), 0);
      // Unparsable → 0.
      expect(Value.internal(ValueSource.valueRemote, 'not-a-num').asInt(), 0);
    });

    test('asDouble parses int and float strings; unparsable returns 0.0', () {
      expect(Value.internal(ValueSource.valueRemote, '42').asDouble(), 42.0);
      expect(Value.internal(ValueSource.valueRemote, '3.14').asDouble(), 3.14);
      expect(Value.internal(ValueSource.valueRemote, '-5').asDouble(), -5.0);
      expect(
        Value.internal(ValueSource.valueRemote, 'not-a-num').asDouble(),
        0.0,
      );
    });

    test('default-source values behave like remote', () {
      final v = Value.internal(ValueSource.valueDefault, 'true');
      expect(v.asBoolean(), true);
      expect(v.getSource(), ValueSource.valueDefault);
    });
  });

  group('ServerConfig', () {
    test('getValue returns static default for unknown keys', () {
      final config = ServerConfig.internal(<String, Value>{});
      final v = config.getValue('missing');
      expect(v.getSource(), ValueSource.valueStatic);
      expect(v.asBoolean(), false);
      expect(v.asInt(), 0);
      expect(v.asDouble(), 0.0);
      expect(v.asString(), '');
    });

    test('getAll returns a copy', () {
      final config = ServerConfig.internal(<String, Value>{
        'k': Value.internal(ValueSource.valueRemote, 'v'),
      });
      final all = config.getAll();
      expect(all.keys, ['k']);
      // Mutating the returned map must not affect the underlying config.
      all['x'] = Value.internal(ValueSource.valueRemote, 'leaked');
      expect(config.getAll().containsKey('x'), isFalse);
    });
  });

  group('ServerTemplate.evaluate', () {
    test('respects condition order, defaults, and in-app fallback', () {
      const json = '''{
        "etag": "tmpl-1",
        "conditions": [
          {"name": "always-true", "condition": {"true": {}}},
          {"name": "always-false", "condition": {"false": {}}}
        ],
        "parameters": {
          "by_condition": {
            "defaultValue": {"value": "default"},
            "conditionalValues": {
              "always-true": {"value": "matched"}
            }
          },
          "fallback": {
            "defaultValue": {"value": "fallback-default"}
          },
          "skip_via_in_app": {
            "defaultValue": {"useInAppDefault": true}
          }
        }
      }''';

      final template = rc.initServerTemplate(
        defaultConfig: const {
          'skip_via_in_app': 'in-app-value',
          'unrelated': 'kept',
        },
        template: json,
      );
      final config = template.evaluate();

      expect(config.getString('by_condition'), 'matched');
      expect(
        config.getValue('by_condition').getSource(),
        ValueSource.valueRemote,
      );

      expect(config.getString('fallback'), 'fallback-default');
      expect(config.getValue('fallback').getSource(), ValueSource.valueRemote);

      // skip_via_in_app should fall through to the in-app default config.
      expect(config.getString('skip_via_in_app'), 'in-app-value');
      expect(
        config.getValue('skip_via_in_app').getSource(),
        ValueSource.valueDefault,
      );

      // Keys present only in defaultConfig pass through.
      expect(config.getString('unrelated'), 'kept');

      // Unknown keys → static default.
      expect(
        config.getValue('does-not-exist').getSource(),
        ValueSource.valueStatic,
      );
    });

    test('throws failed-precondition when no template loaded', () {
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

    test('set() rejects malformed JSON', () {
      final template = rc.initServerTemplate();
      expect(
        () => template.set('not-json'),
        throwsA(
          isA<FirebaseRemoteConfigException>().having(
            (e) => e.errorCode,
            'errorCode',
            RemoteConfigErrorCode.invalidArgument,
          ),
        ),
      );
    });

    test('set() rejects unsupported types', () {
      final template = rc.initServerTemplate();
      expect(
        () => template.set(42),
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
}
