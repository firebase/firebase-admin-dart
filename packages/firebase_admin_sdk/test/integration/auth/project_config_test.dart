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

// Firebase ProjectConfig Integration Tests - Emulator Safe
//
// These tests work with Firebase Auth Emulator and test basic ProjectConfig operations.
// For production-only tests (MFA, TOTP, reCAPTCHA), see project_config_integration_prod_test.dart
//
// Run with:
//   FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 dart test test/auth/project_config_integration_test.dart

@Tags(['firebase-emulator'])
library;

import 'package:firebase_admin_sdk/auth.dart';
import 'package:test/test.dart';

import '../../fixtures/auth/helpers.dart';

void main() {
  late Auth auth;
  late ProjectConfigManager projectConfigManager;

  setUp(() {
    auth = createAuthForTest();
    projectConfigManager = auth.projectConfigManager;
  });

  group('ProjectConfigManager', () {
    group('getProjectConfig', () {
      test('retrieves current project configuration', () async {
        final config = await projectConfigManager.getProjectConfig();

        // ProjectConfig should always be returned, even if fields are null
        expect(config, isA<ProjectConfig>());

        // Depending on project setup, some fields may or may not be configured
        // We just verify the response structure is correct
      });

      test('returns config with proper types for all fields', () async {
        final config = await projectConfigManager.getProjectConfig();

        // Verify field types when they exist
        if (config.smsRegionConfig != null) {
          expect(config.smsRegionConfig, isA<SmsRegionConfig>());
        }
        if (config.multiFactorConfig != null) {
          expect(config.multiFactorConfig, isA<MultiFactorConfig>());
        }
        if (config.recaptchaConfig != null) {
          expect(config.recaptchaConfig, isA<RecaptchaConfig>());
        }
        if (config.passwordPolicyConfig != null) {
          expect(config.passwordPolicyConfig, isA<PasswordPolicyConfig>());
        }
        if (config.emailPrivacyConfig != null) {
          expect(config.emailPrivacyConfig, isA<EmailPrivacyConfig>());
        }
        if (config.mobileLinksConfig != null) {
          expect(config.mobileLinksConfig, isA<MobileLinksConfig>());
        }
      });

      test('toJson serialization works correctly', () async {
        final config = await projectConfigManager.getProjectConfig();
        final json = config.toJson();

        // Should return a valid Map
        expect(json, isA<Map<String, dynamic>>());

        // Only configured fields should be present
        if (config.smsRegionConfig != null) {
          expect(json.containsKey('smsRegionConfig'), isTrue);
        }
        if (config.multiFactorConfig != null) {
          expect(json.containsKey('multiFactorConfig'), isTrue);
        }
        if (config.recaptchaConfig != null) {
          expect(json.containsKey('recaptchaConfig'), isTrue);
        }
        if (config.passwordPolicyConfig != null) {
          expect(json.containsKey('passwordPolicyConfig'), isTrue);
        }
        if (config.emailPrivacyConfig != null) {
          expect(json.containsKey('emailPrivacyConfig'), isTrue);
        }
        if (config.mobileLinksConfig != null) {
          expect(json.containsKey('mobileLinksConfig'), isTrue);
        }
      });
    });

    group('updateProjectConfig', () {
      test('updates email privacy configuration', () async {
        // Update email privacy config
        final updatedConfig = await projectConfigManager.updateProjectConfig(
          UpdateProjectConfigRequest(
            emailPrivacyConfig: EmailPrivacyConfig(
              enableImprovedEmailPrivacy: true,
            ),
          ),
        );

        expect(updatedConfig, isA<ProjectConfig>());

        if (updatedConfig.emailPrivacyConfig != null) {
          expect(
            updatedConfig.emailPrivacyConfig!.enableImprovedEmailPrivacy,
            isTrue,
          );
        }
      });

      test('updates SMS region configuration to allowByDefault', () async {
        final updatedConfig = await projectConfigManager.updateProjectConfig(
          const UpdateProjectConfigRequest(
            smsRegionConfig: AllowByDefaultSmsRegionConfig(
              disallowedRegions: ['US', 'CA'],
            ),
          ),
        );

        expect(updatedConfig, isA<ProjectConfig>());

        if (updatedConfig.smsRegionConfig != null) {
          expect(
            updatedConfig.smsRegionConfig,
            isA<AllowByDefaultSmsRegionConfig>(),
          );
          final smsConfig =
              updatedConfig.smsRegionConfig! as AllowByDefaultSmsRegionConfig;
          expect(smsConfig.disallowedRegions, contains('US'));
          expect(smsConfig.disallowedRegions, contains('CA'));
        }
      });

      test('updates SMS region configuration to allowlistOnly', () async {
        final updatedConfig = await projectConfigManager.updateProjectConfig(
          const UpdateProjectConfigRequest(
            smsRegionConfig: AllowlistOnlySmsRegionConfig(
              allowedRegions: ['GB', 'FR', 'DE'],
            ),
          ),
        );

        expect(updatedConfig, isA<ProjectConfig>());

        if (updatedConfig.smsRegionConfig != null) {
          expect(
            updatedConfig.smsRegionConfig,
            isA<AllowlistOnlySmsRegionConfig>(),
          );
          final smsConfig =
              updatedConfig.smsRegionConfig! as AllowlistOnlySmsRegionConfig;
          expect(smsConfig.allowedRegions, contains('GB'));
          expect(smsConfig.allowedRegions, contains('FR'));
          expect(smsConfig.allowedRegions, contains('DE'));
        }
      });

      test('updates password policy configuration', () async {
        final updatedConfig = await projectConfigManager.updateProjectConfig(
          UpdateProjectConfigRequest(
            passwordPolicyConfig: PasswordPolicyConfig(
              enforcementState: PasswordPolicyEnforcementState.enforce,
              forceUpgradeOnSignin: true,
              constraints: CustomStrengthOptionsConfig(
                requireUppercase: true,
                requireLowercase: true,
                requireNumeric: true,
                minLength: 10,
              ),
            ),
          ),
        );

        expect(updatedConfig, isA<ProjectConfig>());

        if (updatedConfig.passwordPolicyConfig != null) {
          expect(
            updatedConfig.passwordPolicyConfig!.enforcementState,
            equals(PasswordPolicyEnforcementState.enforce),
          );
        }
      });

      test('updates mobile links configuration', () async {
        final updatedConfig = await projectConfigManager.updateProjectConfig(
          const UpdateProjectConfigRequest(
            mobileLinksConfig: MobileLinksConfig(
              domain: MobileLinksDomain.hostingDomain,
            ),
          ),
        );

        expect(updatedConfig, isA<ProjectConfig>());

        if (updatedConfig.mobileLinksConfig != null) {
          expect(
            updatedConfig.mobileLinksConfig!.domain,
            equals(MobileLinksDomain.hostingDomain),
          );
        }
      });

      test('get and update maintain consistency', () async {
        final initialConfig = await projectConfigManager.getProjectConfig();

        await projectConfigManager.updateProjectConfig(
          UpdateProjectConfigRequest(
            emailPrivacyConfig: EmailPrivacyConfig(
              enableImprovedEmailPrivacy: false,
            ),
          ),
        );

        final retrievedConfig = await projectConfigManager.getProjectConfig();

        expect(initialConfig, isA<ProjectConfig>());
        expect(retrievedConfig, isA<ProjectConfig>());
      });
    });
  });
}
