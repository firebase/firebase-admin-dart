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

@Tags(['prod'])
library;

import 'package:firebase_admin_sdk/security_rules.dart';
import 'package:test/test.dart';

import '../../fixtures/helpers.dart';
import '../../fixtures/mock.dart';

void main() {
  late SecurityRules securityRules;
  final createdRulesets = <String>[];

  setUpAll(registerFallbacks);

  setUp(() async {
    final sdk = createApp();
    securityRules = SecurityRules.internal(sdk);
    createdRulesets.clear();
  });

  tearDown(() async {
    // Clean up any rulesets created during tests
    for (final rulesetName in createdRulesets) {
      try {
        await securityRules.deleteRuleset(rulesetName);
      } catch (_) {
        // Ignore errors during cleanup
      }
    }
  });

  const simpleFirestoreContent =
      'service cloud.firestore { match /databases/{database}/documents { match /{document=**} { allow read, write: if false; } } }';

  const simpleStorageContent =
      'service firebase.storage { match /b/{bucket}/o { match /{allPaths=**} { allow read, write: if request.auth != null; } } }';

  group('SecurityRules', () {
    test('ruleset e2e', () async {
      final ruleset = await securityRules.createRuleset(
        RulesFile(name: 'firestore.rules', content: simpleFirestoreContent),
      );
      createdRulesets.add(ruleset.name);

      final ruleset2 = await securityRules.getRuleset(ruleset.name);
      expect(ruleset2.name, ruleset.name);
      expect(ruleset2.createTime, isNotEmpty);
      expect(ruleset2.source.single.name, 'firestore.rules');
      expect(ruleset2.source.single.content, simpleFirestoreContent);

      await securityRules.deleteRuleset(ruleset.name);

      expect(
        securityRules.getRuleset(ruleset.name),
        throwsA(
          isA<FirebaseSecurityRulesException>().having(
            (e) => e.code,
            'code',
            'security-rules/not-found',
          ),
        ),
      );
    });

    test('listRulesetMetadata', () async {
      final ruleset = await securityRules.createRuleset(
        RulesFile(name: 'firestore.rules', content: simpleFirestoreContent),
      );
      createdRulesets.add(ruleset.name);

      final ruleset2 = await securityRules.createRuleset(
        RulesFile(
          name: 'firestore.rules',
          content: '/* hello */ $simpleFirestoreContent',
        ),
      );
      createdRulesets.add(ruleset2.name);

      final metadata = await securityRules.listRulesetMetadata(pageSize: 1);

      expect(metadata.rulesets.length, 1);
      expect(metadata.nextPageToken, isNotNull);
      expect(metadata.rulesets.single.name, ruleset2.name);

      final metadata2 = await securityRules.listRulesetMetadata(
        pageSize: 1,
        nextPageToken: metadata.nextPageToken,
      );

      expect(metadata2.rulesets.length, 1);
      expect(metadata2.rulesets.single.name, isNot(ruleset2.name));
      expect(metadata2.rulesets.single.name, ruleset.name);
    });

    test('firestore release flow', () async {
      final ruleset = await securityRules.createRuleset(
        RulesFile(name: 'firestore.rules', content: simpleFirestoreContent),
      );
      createdRulesets.add(ruleset.name);

      final before = await securityRules.getFirestoreRuleset();

      expect(before.name, isNot(ruleset.name));

      await securityRules.releaseFirestoreRuleset(ruleset.name);

      final after = await securityRules.getFirestoreRuleset();
      expect(after.name, ruleset.name);
    });

    test('storage release flow', () async {
      const bucket = 'dart-firebase-admin.appspot.com';

      // Create and release a new ruleset from source
      final newRuleset = await securityRules.releaseStorageRulesetFromSource(
        simpleStorageContent,
        bucket,
      );
      createdRulesets.add(newRuleset.name);

      expect(newRuleset.name, isNotEmpty);
      expect(newRuleset.source.length, 1);
      expect(newRuleset.source.single.name, 'storage.rules');
      expect(newRuleset.source.single.content, simpleStorageContent);

      // Verify it was applied by getting the current ruleset
      final after = await securityRules.getStorageRuleset(bucket);
      expect(after.name, newRuleset.name);
      expect(after.source.length, 1);
      expect(after.source.single.content, simpleStorageContent);
    }, skip: 'Requires Storage bucket to be configured in Firebase project');

    group('Error Handling', () {
      test(
        'getRuleset rejects with not-found for non-existing ruleset',
        () async {
          const nonExistingName = '00000000-1111-2222-3333-444444444444';
          await expectLater(
            securityRules.getRuleset(nonExistingName),
            throwsA(
              isA<FirebaseSecurityRulesException>().having(
                (e) => e.code,
                'code',
                'security-rules/not-found',
              ),
            ),
          );
        },
      );

      test(
        'getRuleset rejects with invalid-argument for invalid name',
        () async {
          await expectLater(
            securityRules.getRuleset('invalid uuid'),
            throwsA(
              isA<FirebaseSecurityRulesException>().having(
                (e) => e.code,
                'code',
                'security-rules/invalid-argument',
              ),
            ),
          );
        },
      );

      test(
        'createRuleset rejects with invalid-argument for invalid syntax',
        () async {
          final invalidRulesFile = RulesFile(
            name: 'firestore.rules',
            content: 'invalid syntax',
          );

          await expectLater(
            securityRules.createRuleset(invalidRulesFile),
            throwsA(
              isA<FirebaseSecurityRulesException>().having(
                (e) => e.code,
                'code',
                'security-rules/invalid-argument',
              ),
            ),
          );
        },
      );

      test(
        'deleteRuleset rejects with not-found for non-existing ruleset',
        () async {
          const nonExistingName = '00000000-1111-2222-3333-444444444444';
          await expectLater(
            securityRules.deleteRuleset(nonExistingName),
            throwsA(
              isA<FirebaseSecurityRulesException>().having(
                (e) => e.code,
                'code',
                'security-rules/not-found',
              ),
            ),
          );
        },
      );

      test(
        'deleteRuleset rejects with invalid-argument for invalid name',
        () async {
          await expectLater(
            securityRules.deleteRuleset('invalid uuid'),
            throwsA(
              isA<FirebaseSecurityRulesException>().having(
                (e) => e.code,
                'code',
                'security-rules/invalid-argument',
              ),
            ),
          );
        },
      );
    });
  });
}
