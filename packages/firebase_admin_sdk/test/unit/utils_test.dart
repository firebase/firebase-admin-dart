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

import 'package:firebase_admin_sdk/src/auth.dart';
import 'package:firebase_admin_sdk/src/utils/utils.dart';
import 'package:firebase_admin_sdk/src/utils/validator.dart';
import 'package:test/test.dart';

void main() {
  group('isSafeUrlSegment', () {
    test('returns true for valid URL path segments', () {
      const validSegments = [
        'tenant1',
        'tenant-1',
        'tenant_1',
        'tenant.1',
        'tenant~1',
        'TENANT123',
        'oidc.provider',
        'saml.provider-1',
      ];
      for (final segment in validSegments) {
        expect(isSafeUrlSegment(segment), isTrue, reason: segment);
      }
    });

    test('returns false for invalid URL path segments', () {
      const invalidSegments = <String?>[
        null,
        '',
        '.',
        '..',
        '...',
        'tenant.',
        'tenant\n',
        'tenant\r',
        'tenant\uFEFF',
        'tenant/1',
        r'tenant\1',
        'tenant?k=v',
        'tenant#frag',
        'tenant%2f1',
      ];
      for (final segment in invalidSegments) {
        expect(isSafeUrlSegment(segment), isFalse, reason: '$segment');
      }
    });
  });

  group('isTenantId', () {
    test('returns true for valid tenant IDs', () {
      expect(isTenantId('tenant-1'), isTrue);
      expect(isTenantId('tenant_1.test~2'), isTrue);
    });

    test('returns false for invalid tenant IDs', () {
      const invalidTenantIds = [
        '',
        '.',
        '..',
        '...',
        'tenant.',
        'tenant\n',
        'tenant\uFEFF',
        'tenant/1',
        r'tenant\1',
        'tenant?k=v',
        'tenant#frag',
        'tenant%2f1',
      ];
      for (final tenantId in invalidTenantIds) {
        expect(isTenantId(tenantId), isFalse, reason: tenantId);
      }
    });
  });

  group('assertIsTenantId', () {
    test('does not throw for valid tenant IDs', () {
      expect(() => assertIsTenantId('tenant-1'), returnsNormally);
    });

    test('throws invalid-tenant-id for invalid tenant IDs', () {
      const invalidTenantIds = [
        '',
        '.',
        '..',
        '...',
        'tenant.',
        'tenant\n',
        'tenant\uFEFF',
        'tenant/1',
        r'tenant\1',
        'tenant?k=v',
        'tenant#frag',
        'tenant%2f1',
      ];
      for (final tenantId in invalidTenantIds) {
        expect(
          () => assertIsTenantId(tenantId),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/invalid-tenant-id',
            ),
          ),
          reason: tenantId,
        );
      }
    });
  });

  group('generateUpdateMask', () {
    test('non-map objects', () {
      expect(generateUpdateMask(null), isEmpty);
      expect(generateUpdateMask(1), isEmpty);
      expect(generateUpdateMask('string'), isEmpty);
      expect(generateUpdateMask([]), isEmpty);
    });

    test('empty map', () {
      final obj = <String, dynamic>{};
      expect(generateUpdateMask(obj), isEmpty);
    });

    test('flat map', () {
      final obj = {'a': 1, 'b': 'string', 'c': null};
      expect(generateUpdateMask(obj), containsAll(['a', 'b', 'c']));
    });

    test('nested maps', () {
      final obj = {
        'a': 1,
        'b': {'c': 2, 'd': null},
      };
      expect(generateUpdateMask(obj), containsAll(['a', 'b.c', 'b.d']));
    });

    test('deeply nested maps', () {
      final obj = {
        'a': {
          'b': {'c': null},
        },
      };
      expect(generateUpdateMask(obj), containsAll(['a.b.c']));
    });

    test('empty maps as leaf nodes', () {
      final obj = {
        'a': <String, dynamic>{},
        'b': {'c': <String, dynamic>{}},
      };
      expect(generateUpdateMask(obj), containsAll(['a', 'b.c']));
    });
  });
}
