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

import 'package:firebase_admin_sdk/auth.dart';
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../fixtures/helpers.dart';
import '../../fixtures/mock.dart';
import '../../fixtures/mock_service_account.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(CreateTenantRequest());
    registerFallbackValue(UpdateTenantRequest());
  });

  group('TenantManager', () {
    group('authForTenant', () {
      test('returns TenantAwareAuth instance for valid tenant ID', () {
        final app = _createMockApp();
        final auth = Auth.internal(app);
        final tenantManager = auth.tenantManager;

        final tenantAuth = tenantManager.authForTenant('test-tenant-id');

        expect(tenantAuth, isA<TenantAwareAuth>());
        expect(tenantAuth.tenantId, equals('test-tenant-id'));
      });

      test('returns cached instance for same tenant ID', () {
        final app = _createMockApp();
        final auth = Auth.internal(app);
        final tenantManager = auth.tenantManager;

        final tenantAuth1 = tenantManager.authForTenant('test-tenant-id');
        final tenantAuth2 = tenantManager.authForTenant('test-tenant-id');

        expect(identical(tenantAuth1, tenantAuth2), isTrue);
      });

      test('returns different instances for different tenant IDs', () {
        final app = _createMockApp();
        final auth = Auth.internal(app);
        final tenantManager = auth.tenantManager;

        final tenantAuth1 = tenantManager.authForTenant('tenant-1');
        final tenantAuth2 = tenantManager.authForTenant('tenant-2');

        expect(identical(tenantAuth1, tenantAuth2), isFalse);
        expect(tenantAuth1.tenantId, equals('tenant-1'));
        expect(tenantAuth2.tenantId, equals('tenant-2'));
      });

      test('throws on invalid tenant ID', () {
        final app = _createMockApp();
        final auth = Auth.internal(app);
        final tenantManager = auth.tenantManager;

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
            () => tenantManager.authForTenant(tenantId),
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

    test('tenantManager getter returns same instance', () {
      final app = _createMockApp();
      final auth = Auth.internal(app);

      final tenantManager1 = auth.tenantManager;
      final tenantManager2 = auth.tenantManager;

      expect(identical(tenantManager1, tenantManager2), isTrue);
    });

    group('getTenant', () {
      test('throws when tenantId is invalid', () async {
        final app = _createMockApp();
        final tenantManager = TenantManager.internal(app);

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
          await expectLater(
            () => tenantManager.getTenant(tenantId),
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

      test('returns tenant successfully', () async {
        final app = _createMockApp();
        final mockRequestHandler = AuthRequestHandlerMock();
        final tenantManager = TenantManager.internal(
          app,
          authRequestHandler: mockRequestHandler,
        );

        final tenantResponse = <String, dynamic>{
          'name': 'projects/test-project/tenants/test-tenant-id',
          'displayName': 'Test Tenant',
          'allowPasswordSignup': true,
          'enableEmailLinkSignin': false,
          'enableAnonymousUser': true,
        };

        when(
          () => mockRequestHandler.getTenant(any()),
        ).thenAnswer((_) async => tenantResponse);

        final tenant = await tenantManager.getTenant('test-tenant-id');

        expect(tenant.tenantId, equals('test-tenant-id'));
        expect(tenant.displayName, equals('Test Tenant'));
        expect(tenant.anonymousSignInEnabled, isTrue);
        verify(() => mockRequestHandler.getTenant('test-tenant-id')).called(1);
      });

      test('throws when backend returns error', () async {
        final app = _createMockApp();
        final mockRequestHandler = AuthRequestHandlerMock();
        final tenantManager = TenantManager.internal(
          app,
          authRequestHandler: mockRequestHandler,
        );

        final error = FirebaseAuthAdminException(
          AuthClientErrorCode.tenantNotFound,
          'TENANT_NOT_FOUND',
        );

        when(() => mockRequestHandler.getTenant(any())).thenThrow(error);

        await expectLater(
          () => tenantManager.getTenant('test-tenant-id'),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/tenant-not-found',
            ),
          ),
        );
      });
    });

    group('listTenants', () {
      test('throws when maxResults is too large', () async {
        final app = _createMockApp();
        final tenantManager = TenantManager.internal(app);

        await expectLater(
          () => tenantManager.listTenants(maxResults: 1001),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/argument-error',
            ),
          ),
        );
      });

      test('returns tenants successfully', () async {
        final app = _createMockApp();
        final mockRequestHandler = AuthRequestHandlerMock();
        final tenantManager = TenantManager.internal(
          app,
          authRequestHandler: mockRequestHandler,
        );

        final listResponse = <String, dynamic>{
          'tenants': [
            {
              'name': 'projects/test-project/tenants/tenant-1',
              'displayName': 'Tenant 1',
            },
            {
              'name': 'projects/test-project/tenants/tenant-2',
              'displayName': 'Tenant 2',
            },
          ],
          'nextPageToken': 'next-page-token',
        };

        when(
          () => mockRequestHandler.listTenants(
            maxResults: any(named: 'maxResults'),
            pageToken: any(named: 'pageToken'),
          ),
        ).thenAnswer((_) async => listResponse);

        final result = await tenantManager.listTenants(
          maxResults: 10,
          pageToken: 'page-token',
        );

        expect(result.tenants.length, equals(2));
        expect(result.tenants[0].tenantId, equals('tenant-1'));
        expect(result.tenants[1].tenantId, equals('tenant-2'));
        expect(result.pageToken, equals('next-page-token'));
        verify(
          () => mockRequestHandler.listTenants(
            maxResults: 10,
            pageToken: 'page-token',
          ),
        ).called(1);
      });

      test('returns empty list when no tenants', () async {
        final app = _createMockApp();
        final mockRequestHandler = AuthRequestHandlerMock();
        final tenantManager = TenantManager.internal(
          app,
          authRequestHandler: mockRequestHandler,
        );

        final listResponse = <String, dynamic>{
          'tenants': <Map<String, dynamic>>[],
        };

        when(
          () => mockRequestHandler.listTenants(
            maxResults: any(named: 'maxResults'),
            pageToken: any(named: 'pageToken'),
          ),
        ).thenAnswer((_) async => listResponse);

        final result = await tenantManager.listTenants();

        expect(result.tenants, isEmpty);
        expect(result.pageToken, isNull);
      });
    });

    group('createTenant', () {
      test('creates tenant successfully', () async {
        final app = _createMockApp();
        final mockRequestHandler = AuthRequestHandlerMock();
        final tenantManager = TenantManager.internal(
          app,
          authRequestHandler: mockRequestHandler,
        );

        final tenantResponse = <String, dynamic>{
          'name': 'projects/test-project/tenants/new-tenant-id',
          'displayName': 'New Tenant',
          'allowPasswordSignup': true,
          'enableEmailLinkSignin': false,
          'enableAnonymousUser': false,
        };

        when(
          () => mockRequestHandler.createTenant(any()),
        ).thenAnswer((_) async => tenantResponse);

        final tenant = await tenantManager.createTenant(
          CreateTenantRequest(displayName: 'New Tenant'),
        );

        expect(tenant.tenantId, equals('new-tenant-id'));
        expect(tenant.displayName, equals('New Tenant'));
        verify(() => mockRequestHandler.createTenant(any())).called(1);
      });

      test('throws when backend returns error', () async {
        final app = _createMockApp();
        final mockRequestHandler = AuthRequestHandlerMock();
        final tenantManager = TenantManager.internal(
          app,
          authRequestHandler: mockRequestHandler,
        );

        final error = FirebaseAuthAdminException(
          AuthClientErrorCode.internalError,
          'INTERNAL_ERROR',
        );

        when(() => mockRequestHandler.createTenant(any())).thenThrow(error);

        await expectLater(
          () => tenantManager.createTenant(
            CreateTenantRequest(displayName: 'New Tenant'),
          ),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/internal-error',
            ),
          ),
        );
      });
    });

    group('updateTenant', () {
      test('throws when tenantId is invalid', () async {
        final app = _createMockApp();
        final tenantManager = TenantManager.internal(app);

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
          await expectLater(
            () => tenantManager.updateTenant(
              tenantId,
              UpdateTenantRequest(displayName: 'Updated Name'),
            ),
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

      test('updates tenant successfully', () async {
        final app = _createMockApp();
        final mockRequestHandler = AuthRequestHandlerMock();
        final tenantManager = TenantManager.internal(
          app,
          authRequestHandler: mockRequestHandler,
        );

        final tenantResponse = <String, dynamic>{
          'name': 'projects/test-project/tenants/test-tenant-id',
          'displayName': 'Updated Tenant',
          'allowPasswordSignup': true,
          'enableEmailLinkSignin': false,
          'enableAnonymousUser': true,
        };

        when(
          () => mockRequestHandler.updateTenant(any(), any()),
        ).thenAnswer((_) async => tenantResponse);

        final tenant = await tenantManager.updateTenant(
          'test-tenant-id',
          UpdateTenantRequest(displayName: 'Updated Tenant'),
        );

        expect(tenant.tenantId, equals('test-tenant-id'));
        expect(tenant.displayName, equals('Updated Tenant'));
        verify(
          () => mockRequestHandler.updateTenant('test-tenant-id', any()),
        ).called(1);
      });

      test('throws when backend returns error', () async {
        final app = _createMockApp();
        final mockRequestHandler = AuthRequestHandlerMock();
        final tenantManager = TenantManager.internal(
          app,
          authRequestHandler: mockRequestHandler,
        );

        final error = FirebaseAuthAdminException(
          AuthClientErrorCode.tenantNotFound,
          'TENANT_NOT_FOUND',
        );

        when(
          () => mockRequestHandler.updateTenant(any(), any()),
        ).thenThrow(error);

        await expectLater(
          () => tenantManager.updateTenant(
            'test-tenant-id',
            UpdateTenantRequest(displayName: 'Updated Name'),
          ),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/tenant-not-found',
            ),
          ),
        );
      });
    });

    group('deleteTenant', () {
      test('throws when tenantId is invalid', () async {
        final app = _createMockApp();
        final tenantManager = TenantManager.internal(app);

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
          await expectLater(
            () => tenantManager.deleteTenant(tenantId),
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

      test('deletes tenant successfully', () async {
        final app = _createMockApp();
        final mockRequestHandler = AuthRequestHandlerMock();
        final tenantManager = TenantManager.internal(
          app,
          authRequestHandler: mockRequestHandler,
        );

        when(
          () => mockRequestHandler.deleteTenant(any()),
        ).thenAnswer((_) async => Future<void>.value());

        await tenantManager.deleteTenant('test-tenant-id');

        verify(
          () => mockRequestHandler.deleteTenant('test-tenant-id'),
        ).called(1);
      });

      test('throws when backend returns error', () async {
        final app = _createMockApp();
        final mockRequestHandler = AuthRequestHandlerMock();
        final tenantManager = TenantManager.internal(
          app,
          authRequestHandler: mockRequestHandler,
        );

        final error = FirebaseAuthAdminException(
          AuthClientErrorCode.tenantNotFound,
          'TENANT_NOT_FOUND',
        );

        when(() => mockRequestHandler.deleteTenant(any())).thenThrow(error);

        await expectLater(
          () => tenantManager.deleteTenant('test-tenant-id'),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/tenant-not-found',
            ),
          ),
        );
      });
    });
  });

  group('ListTenantsResult', () {
    test('creates result with page token', () {
      final tenants = <Tenant>[];
      const pageToken = 'next-page-token';

      final result = ListTenantsResult(tenants: tenants, pageToken: pageToken);

      expect(result.tenants, equals(tenants));
      expect(result.pageToken, equals(pageToken));
    });

    test('creates result without page token', () {
      final tenants = <Tenant>[];

      final result = ListTenantsResult(tenants: tenants);

      expect(result.tenants, equals(tenants));
      expect(result.pageToken, isNull);
    });

    test('creates result with empty tenants list', () {
      final result = ListTenantsResult(tenants: []);

      expect(result.tenants, isEmpty);
      expect(result.pageToken, isNull);
    });
  });

  group('TenantAwareAuth', () {
    setUpAll(registerFallbacks);

    test('has correct tenant ID', () {
      final app = _createMockApp();
      final auth = Auth.internal(app);
      final tenantManager = auth.tenantManager;

      final tenantAuth = tenantManager.authForTenant('test-tenant-id');

      expect(tenantAuth.tenantId, equals('test-tenant-id'));
    });

    test('TenantAwareAuth.internal throws on invalid tenant ID', () {
      final app = _createMockApp();
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
          () => TenantAwareAuth.internal(app, tenantId),
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

    test('is instance of BaseAuth', () {
      final app = _createMockApp();
      final auth = Auth.internal(app);
      final tenantManager = auth.tenantManager;

      final tenantAuth = tenantManager.authForTenant('test-tenant-id');

      // TenantAwareAuth extends _BaseAuth which provides all auth methods
      expect(tenantAuth, isA<TenantAwareAuth>());
    });

    group('verifyIdToken', () {
      test('verifies ID token successfully with matching tenant ID', () async {
        const tenantId = 'test-tenant-id';
        final mockIdTokenVerifier = MockFirebaseTokenVerifier();
        final decodedToken = DecodedIdToken.fromMap({
          'sub': 'test-uid-123',
          'uid': 'test-uid-123',
          'aud': 'test-project',
          'iss': 'https://securetoken.google.com/test-project',
          'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'exp':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'auth_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'firebase': <String, dynamic>{
            'identities': <String, dynamic>{},
            'sign_in_provider': 'custom',
            'tenant': tenantId,
          },
        });

        when(
          () => mockIdTokenVerifier.verifyJWT(
            any(),
            isEmulator: any(named: 'isEmulator'),
          ),
        ).thenAnswer((_) async => decodedToken);

        // Always mock HTTP client for getUser calls
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'users': [
                      {
                        'localId': 'test-uid-123',
                        'email': 'test@example.com',
                        'disabled': false,
                        'createdAt': '1234567890000',
                      },
                    ],
                  }),
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-verify-id-token');
        final tenantAuth = TenantAwareAuth.internal(
          app,
          tenantId,
          idTokenVerifier: mockIdTokenVerifier,
        );

        final result = await tenantAuth.verifyIdToken('mock-token');

        expect(result.uid, equals('test-uid-123'));
        expect(result.sub, equals('test-uid-123'));
        expect(result.firebase.tenant, equals(tenantId));
        verify(
          () => mockIdTokenVerifier.verifyJWT(
            'mock-token',
            isEmulator: any(named: 'isEmulator'),
          ),
        ).called(1);
      });

      test('throws when idToken has mismatching tenant ID', () async {
        const tenantId = 'test-tenant-id';
        const wrongTenantId = 'wrong-tenant-id';
        final mockIdTokenVerifier = MockFirebaseTokenVerifier();
        final decodedToken = DecodedIdToken.fromMap({
          'sub': 'test-uid-123',
          'uid': 'test-uid-123',
          'aud': 'test-project',
          'iss': 'https://securetoken.google.com/test-project',
          'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'exp':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'auth_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'firebase': <String, dynamic>{
            'identities': <String, dynamic>{},
            'sign_in_provider': 'custom',
            'tenant': wrongTenantId,
          },
        });

        when(
          () => mockIdTokenVerifier.verifyJWT(
            any(),
            isEmulator: any(named: 'isEmulator'),
          ),
        ).thenAnswer((_) async => decodedToken);

        // Mock HTTP client for getUser calls (needed when emulator is enabled or checkRevoked is true)
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'users': [
                      {
                        'localId': 'test-uid-123',
                        'email': 'test@example.com',
                        'disabled': false,
                        'createdAt': '1234567890000',
                      },
                    ],
                  }),
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-mismatching-tenant-id',
        );
        final tenantAuth = TenantAwareAuth.internal(
          app,
          tenantId,
          idTokenVerifier: mockIdTokenVerifier,
        );

        await expectLater(
          () => tenantAuth.verifyIdToken('mock-token'),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/mismatching-tenant-id',
            ),
          ),
        );
      });

      test('throws when idToken is empty', () async {
        const tenantId = 'test-tenant-id';
        final mockIdTokenVerifier = MockFirebaseTokenVerifier();
        when(
          () => mockIdTokenVerifier.verifyJWT(
            any(),
            isEmulator: any(named: 'isEmulator'),
          ),
        ).thenThrow(
          FirebaseAuthAdminException(
            AuthClientErrorCode.invalidArgument,
            'Firebase ID token has invalid format.',
          ),
        );

        final app = createApp(name: 'test-verify-id-token-empty');
        final tenantAuth = TenantAwareAuth.internal(
          app,
          tenantId,
          idTokenVerifier: mockIdTokenVerifier,
        );

        await expectLater(
          () => tenantAuth.verifyIdToken(''),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/argument-error',
            ),
          ),
        );
      });

      test('throws when idToken is invalid', () async {
        const tenantId = 'test-tenant-id';
        final mockIdTokenVerifier = MockFirebaseTokenVerifier();
        when(
          () => mockIdTokenVerifier.verifyJWT(
            any(),
            isEmulator: any(named: 'isEmulator'),
          ),
        ).thenThrow(
          FirebaseAuthAdminException(
            AuthClientErrorCode.invalidArgument,
            'Decoding Firebase ID token failed.',
          ),
        );

        final app = createApp(name: 'test-verify-id-token-invalid');
        final tenantAuth = TenantAwareAuth.internal(
          app,
          tenantId,
          idTokenVerifier: mockIdTokenVerifier,
        );

        await expectLater(
          () => tenantAuth.verifyIdToken('invalid-token'),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/argument-error',
            ),
          ),
        );
      });

      test('throws when checkRevoked is true and user is disabled', () async {
        const tenantId = 'test-tenant-id';
        final mockIdTokenVerifier = MockFirebaseTokenVerifier();
        final decodedToken = DecodedIdToken.fromMap({
          'sub': 'test-uid-123',
          'uid': 'test-uid-123',
          'aud': 'test-project',
          'iss': 'https://securetoken.google.com/test-project',
          'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'exp':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'auth_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'firebase': <String, dynamic>{
            'identities': <String, dynamic>{},
            'sign_in_provider': 'custom',
            'tenant': tenantId,
          },
        });

        when(
          () => mockIdTokenVerifier.verifyJWT(
            any(),
            isEmulator: any(named: 'isEmulator'),
          ),
        ).thenAnswer((_) async => decodedToken);

        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'users': [
                      {
                        'localId': 'test-uid-123',
                        'email': 'test@example.com',
                        'disabled': true,
                        'createdAt': '1234567890000',
                      },
                    ],
                  }),
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-verify-id-token-disabled',
        );
        final tenantAuth = TenantAwareAuth.internal(
          app,
          tenantId,
          idTokenVerifier: mockIdTokenVerifier,
        );

        await expectLater(
          () => tenantAuth.verifyIdToken('mock-token', checkRevoked: true),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/user-disabled',
            ),
          ),
        );
      });

      test('throws when checkRevoked is true and token is revoked', () async {
        const tenantId = 'test-tenant-id';
        final mockIdTokenVerifier = MockFirebaseTokenVerifier();
        // Token with auth_time before validSince
        final authTime = DateTime.now().subtract(const Duration(hours: 2));
        final decodedToken = DecodedIdToken.fromMap({
          'sub': 'test-uid-123',
          'uid': 'test-uid-123',
          'aud': 'test-project',
          'iss': 'https://securetoken.google.com/test-project',
          'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'exp':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'auth_time': authTime.millisecondsSinceEpoch ~/ 1000,
          'firebase': <String, dynamic>{
            'identities': <String, dynamic>{},
            'sign_in_provider': 'custom',
            'tenant': tenantId,
          },
        });

        when(
          () => mockIdTokenVerifier.verifyJWT(
            any(),
            isEmulator: any(named: 'isEmulator'),
          ),
        ).thenAnswer((_) async => decodedToken);

        final clientMock = MockAuthClient();
        // validSince is after auth_time, so token is revoked
        final validSince = DateTime.now().subtract(const Duration(hours: 1));
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'users': [
                      {
                        'localId': 'test-uid-123',
                        'email': 'test@example.com',
                        'disabled': false,
                        'validSince':
                            (validSince.millisecondsSinceEpoch ~/ 1000)
                                .toString(),
                        'createdAt': '1234567890000',
                      },
                    ],
                  }),
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-verify-id-token-revoked',
        );
        final tenantAuth = TenantAwareAuth.internal(
          app,
          tenantId,
          idTokenVerifier: mockIdTokenVerifier,
        );

        await expectLater(
          () => tenantAuth.verifyIdToken('mock-token', checkRevoked: true),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/id-token-revoked',
            ),
          ),
        );
      });

      test(
        'succeeds when checkRevoked is true and token is not revoked',
        () async {
          const tenantId = 'test-tenant-id';
          final mockIdTokenVerifier = MockFirebaseTokenVerifier();
          // Token with auth_time after validSince
          final authTime = DateTime.now().subtract(const Duration(minutes: 30));
          final decodedToken = DecodedIdToken.fromMap({
            'sub': 'test-uid-123',
            'uid': 'test-uid-123',
            'aud': 'test-project',
            'iss': 'https://securetoken.google.com/test-project',
            'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'exp':
                DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000,
            'auth_time': authTime.millisecondsSinceEpoch ~/ 1000,
            'firebase': <String, dynamic>{
              'identities': <String, dynamic>{},
              'sign_in_provider': 'custom',
              'tenant': tenantId,
            },
          });

          when(
            () => mockIdTokenVerifier.verifyJWT(
              any(),
              isEmulator: any(named: 'isEmulator'),
            ),
          ).thenAnswer((_) async => decodedToken);

          final clientMock = MockAuthClient();
          // validSince is before auth_time, so token is not revoked
          final validSince = DateTime.now().subtract(const Duration(hours: 1));
          when(() => clientMock.send(any())).thenAnswer(
            (_) => Future.value(
              StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'users': [
                        {
                          'localId': 'test-uid-123',
                          'email': 'test@example.com',
                          'disabled': false,
                          'validSince':
                              (validSince.millisecondsSinceEpoch ~/ 1000)
                                  .toString(),
                          'createdAt': '1234567890000',
                        },
                      ],
                    }),
                  ),
                ),
                200,
                headers: {'content-type': 'application/json'},
              ),
            ),
          );

          final app = createApp(
            client: clientMock,
            name: 'test-verify-id-token-not-revoked',
          );
          final tenantAuth = TenantAwareAuth.internal(
            app,
            tenantId,
            idTokenVerifier: mockIdTokenVerifier,
          );

          final result = await tenantAuth.verifyIdToken(
            'mock-token',
            checkRevoked: true,
          );

          expect(result.uid, equals('test-uid-123'));
          expect(result.firebase.tenant, equals(tenantId));
        },
      );
    });

    group('createSessionCookie', () {
      test('throws when idToken is empty', () async {
        const tenantId = 'test-tenant-id';
        final app = _createMockApp();
        final auth = Auth.internal(app);
        final tenantManager = auth.tenantManager;
        final tenantAuth = tenantManager.authForTenant(tenantId);

        expect(
          () => tenantAuth.createSessionCookie(
            '',
            const SessionCookieOptions(expiresIn: 3600000),
          ),
          throwsA(isA<FirebaseAuthAdminException>()),
        );
      });

      test('validates expiresIn duration - too short', () async {
        const tenantId = 'test-tenant-id';
        final mockIdTokenVerifier = MockFirebaseTokenVerifier();
        final decodedIdToken = DecodedIdToken.fromMap({
          'sub': 'test-uid-123',
          'uid': 'test-uid-123',
          'aud': 'test-project',
          'iss': 'https://securetoken.google.com/test-project',
          'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'exp':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'auth_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'firebase': <String, dynamic>{
            'identities': <String, dynamic>{},
            'sign_in_provider': 'custom',
            'tenant': tenantId,
          },
        });

        when(
          () => mockIdTokenVerifier.verifyJWT(
            any(),
            isEmulator: any(named: 'isEmulator'),
          ),
        ).thenAnswer((_) async => decodedIdToken);

        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({'sessionCookie': 'session-cookie-string'}),
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = _createMockApp();
        final tenantAuth = TenantAwareAuth.internal(
          app,
          tenantId,
          idTokenVerifier: mockIdTokenVerifier,
        );

        expect(
          () => tenantAuth.createSessionCookie(
            'id-token',
            const SessionCookieOptions(
              expiresIn: 60000,
            ), // 1 minute - too short
          ),
          throwsA(isA<FirebaseAuthAdminException>()),
        );
      });

      test('validates expiresIn duration - too long', () async {
        const tenantId = 'test-tenant-id';
        final mockIdTokenVerifier = MockFirebaseTokenVerifier();
        final decodedIdToken = DecodedIdToken.fromMap({
          'sub': 'test-uid-123',
          'uid': 'test-uid-123',
          'aud': 'test-project',
          'iss': 'https://securetoken.google.com/test-project',
          'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'exp':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'auth_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'firebase': <String, dynamic>{
            'identities': <String, dynamic>{},
            'sign_in_provider': 'custom',
            'tenant': tenantId,
          },
        });

        when(
          () => mockIdTokenVerifier.verifyJWT(
            any(),
            isEmulator: any(named: 'isEmulator'),
          ),
        ).thenAnswer((_) async => decodedIdToken);

        final app = _createMockApp();
        final tenantAuth = TenantAwareAuth.internal(
          app,
          tenantId,
          idTokenVerifier: mockIdTokenVerifier,
        );

        expect(
          () => tenantAuth.createSessionCookie(
            'id-token',
            const SessionCookieOptions(
              expiresIn: 15 * 24 * 60 * 60 * 1000, // 15 days - too long
            ),
          ),
          throwsA(isA<FirebaseAuthAdminException>()),
        );
      });
    });

    group('verifySessionCookie', () {
      test(
        'verifies session cookie successfully with matching tenant ID',
        () async {
          const tenantId = 'test-tenant-id';
          final mockSessionCookieVerifier = MockFirebaseTokenVerifier();
          final decodedToken = DecodedIdToken.fromMap({
            'sub': 'test-uid-123',
            'uid': 'test-uid-123',
            'aud': 'test-project',
            'iss': 'https://session.firebase.google.com/test-project',
            'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'exp':
                DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000,
            'auth_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'firebase': <String, dynamic>{
              'identities': <String, dynamic>{},
              'sign_in_provider': 'custom',
              'tenant': tenantId,
            },
          });

          when(
            () => mockSessionCookieVerifier.verifyJWT(
              any(),
              isEmulator: any(named: 'isEmulator'),
            ),
          ).thenAnswer((_) async => decodedToken);

          // Always mock HTTP client for getUser calls
          final clientMock = MockAuthClient();
          when(() => clientMock.send(any())).thenAnswer(
            (_) => Future.value(
              StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'users': [
                        {
                          'localId': 'test-uid-123',
                          'email': 'test@example.com',
                          'disabled': false,
                          'createdAt': '1234567890000',
                        },
                      ],
                    }),
                  ),
                ),
                200,
                headers: {'content-type': 'application/json'},
              ),
            ),
          );

          final app = createApp(
            client: clientMock,
            name: 'test-verify-session-cookie',
          );
          final tenantAuth = TenantAwareAuth.internal(
            app,
            tenantId,
            sessionCookieVerifier: mockSessionCookieVerifier,
          );

          final result = await tenantAuth.verifySessionCookie(
            'mock-session-cookie',
          );

          expect(result.uid, equals('test-uid-123'));
          expect(result.sub, equals('test-uid-123'));
          verify(
            () => mockSessionCookieVerifier.verifyJWT(
              'mock-session-cookie',
              isEmulator: any(named: 'isEmulator'),
            ),
          ).called(1);
        },
      );

      test('throws when session cookie has mismatching tenant ID', () async {
        const tenantId = 'test-tenant-id';
        const wrongTenantId = 'wrong-tenant-id';
        final mockSessionCookieVerifier = MockFirebaseTokenVerifier();
        final decodedToken = DecodedIdToken.fromMap({
          'sub': 'test-uid-123',
          'uid': 'test-uid-123',
          'aud': 'test-project',
          'iss': 'https://session.firebase.google.com/test-project',
          'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'exp':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'auth_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'firebase': <String, dynamic>{
            'identities': <String, dynamic>{},
            'sign_in_provider': 'custom',
            'tenant': wrongTenantId,
          },
        });

        when(
          () => mockSessionCookieVerifier.verifyJWT(
            any(),
            isEmulator: any(named: 'isEmulator'),
          ),
        ).thenAnswer((_) async => decodedToken);

        // Mock HTTP client for getUser calls (needed when emulator is enabled or checkRevoked is true)
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'users': [
                      {
                        'localId': 'test-uid-123',
                        'email': 'test@example.com',
                        'disabled': false,
                        'createdAt': '1234567890000',
                      },
                    ],
                  }),
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-mismatching-tenant',
        );
        final tenantAuth = TenantAwareAuth.internal(
          app,
          tenantId,
          sessionCookieVerifier: mockSessionCookieVerifier,
        );

        await expectLater(
          () => tenantAuth.verifySessionCookie('mock-session-cookie'),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/mismatching-tenant-id',
            ),
          ),
        );
      });

      test('throws when sessionCookie is empty', () async {
        const tenantId = 'test-tenant-id';
        final mockSessionCookieVerifier = MockFirebaseTokenVerifier();
        when(
          () => mockSessionCookieVerifier.verifyJWT(
            any(),
            isEmulator: any(named: 'isEmulator'),
          ),
        ).thenThrow(
          FirebaseAuthAdminException(
            AuthClientErrorCode.invalidArgument,
            'Firebase session cookie has invalid format.',
          ),
        );

        final app = createApp(name: 'test-empty-session-cookie');
        final tenantAuth = TenantAwareAuth.internal(
          app,
          tenantId,
          sessionCookieVerifier: mockSessionCookieVerifier,
        );

        await expectLater(
          () => tenantAuth.verifySessionCookie(''),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/argument-error',
            ),
          ),
        );
      });

      test('throws when sessionCookie is invalid', () async {
        const tenantId = 'test-tenant-id';
        final mockSessionCookieVerifier = MockFirebaseTokenVerifier();
        when(
          () => mockSessionCookieVerifier.verifyJWT(
            any(),
            isEmulator: any(named: 'isEmulator'),
          ),
        ).thenThrow(
          FirebaseAuthAdminException(
            AuthClientErrorCode.invalidArgument,
            'Decoding Firebase session cookie failed.',
          ),
        );

        final app = createApp(name: 'test-invalid-session-cookie');
        final tenantAuth = TenantAwareAuth.internal(
          app,
          tenantId,
          sessionCookieVerifier: mockSessionCookieVerifier,
        );

        await expectLater(
          () => tenantAuth.verifySessionCookie('invalid-cookie'),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/argument-error',
            ),
          ),
        );
      });

      test('throws when checkRevoked is true and user is disabled', () async {
        const tenantId = 'test-tenant-id';
        final mockSessionCookieVerifier = MockFirebaseTokenVerifier();
        final decodedToken = DecodedIdToken.fromMap({
          'sub': 'test-uid-123',
          'uid': 'test-uid-123',
          'aud': 'test-project',
          'iss': 'https://session.firebase.google.com/test-project',
          'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'exp':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'auth_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'firebase': <String, dynamic>{
            'identities': <String, dynamic>{},
            'sign_in_provider': 'custom',
            'tenant': tenantId,
          },
        });

        when(
          () => mockSessionCookieVerifier.verifyJWT(
            any(),
            isEmulator: any(named: 'isEmulator'),
          ),
        ).thenAnswer((_) async => decodedToken);

        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'users': [
                      {
                        'localId': 'test-uid-123',
                        'email': 'test@example.com',
                        'disabled': true,
                        'createdAt': '1234567890000',
                      },
                    ],
                  }),
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-user-disabled');
        final tenantAuth = TenantAwareAuth.internal(
          app,
          tenantId,
          sessionCookieVerifier: mockSessionCookieVerifier,
        );

        await expectLater(
          () =>
              tenantAuth.verifySessionCookie('mock-cookie', checkRevoked: true),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/user-disabled',
            ),
          ),
        );
      });

      test(
        'succeeds when checkRevoked is true and cookie is not revoked',
        () async {
          const tenantId = 'test-tenant-id';
          final mockSessionCookieVerifier = MockFirebaseTokenVerifier();
          final authTime = DateTime.now().subtract(const Duration(minutes: 30));
          final decodedToken = DecodedIdToken.fromMap({
            'sub': 'test-uid-123',
            'uid': 'test-uid-123',
            'aud': 'test-project',
            'iss': 'https://session.firebase.google.com/test-project',
            'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'exp':
                DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000,
            'auth_time': authTime.millisecondsSinceEpoch ~/ 1000,
            'firebase': <String, dynamic>{
              'identities': <String, dynamic>{},
              'sign_in_provider': 'custom',
              'tenant': tenantId,
            },
          });

          when(
            () => mockSessionCookieVerifier.verifyJWT(
              any(),
              isEmulator: any(named: 'isEmulator'),
            ),
          ).thenAnswer((_) async => decodedToken);

          final clientMock = MockAuthClient();
          // validSince is before auth_time, so cookie is not revoked
          final validSince = DateTime.now().subtract(const Duration(hours: 2));
          when(() => clientMock.send(any())).thenAnswer(
            (_) => Future.value(
              StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'users': [
                        {
                          'localId': 'test-uid-123',
                          'email': 'test@example.com',
                          'disabled': false,
                          'validSince':
                              (validSince.millisecondsSinceEpoch ~/ 1000)
                                  .toString(),
                          'createdAt': '1234567890000',
                        },
                      ],
                    }),
                  ),
                ),
                200,
                headers: {'content-type': 'application/json'},
              ),
            ),
          );

          final app = createApp(
            client: clientMock,
            name: 'test-cookie-not-revoked',
          );
          final tenantAuth = TenantAwareAuth.internal(
            app,
            tenantId,
            sessionCookieVerifier: mockSessionCookieVerifier,
          );

          final result = await tenantAuth.verifySessionCookie(
            'mock-cookie',
            checkRevoked: true,
          );

          expect(result.uid, equals('test-uid-123'));
        },
      );
    });
  });

  group('UpdateTenantRequest', () {
    test('creates request with all fields', () {
      final request = UpdateTenantRequest(
        displayName: 'Test Tenant',
        emailSignInConfig: EmailSignInProviderConfig(
          enabled: true,
          passwordRequired: false,
        ),
        anonymousSignInEnabled: true,
        multiFactorConfig: MultiFactorConfig(
          state: MultiFactorConfigState.enabled,
          factorIds: ['phone'],
        ),
        testPhoneNumbers: {'+1234567890': '123456'},
        smsRegionConfig: const AllowByDefaultSmsRegionConfig(
          disallowedRegions: ['US'],
        ),
        recaptchaConfig: RecaptchaConfig(
          emailPasswordEnforcementState:
              RecaptchaProviderEnforcementState.enforce,
        ),
        passwordPolicyConfig: PasswordPolicyConfig(
          enforcementState: PasswordPolicyEnforcementState.enforce,
        ),
        emailPrivacyConfig: EmailPrivacyConfig(
          enableImprovedEmailPrivacy: true,
        ),
      );

      expect(request.displayName, equals('Test Tenant'));
      expect(request.emailSignInConfig, isNotNull);
      expect(request.anonymousSignInEnabled, isTrue);
      expect(request.multiFactorConfig, isNotNull);
      expect(request.testPhoneNumbers, isNotNull);
      expect(request.smsRegionConfig, isNotNull);
      expect(request.recaptchaConfig, isNotNull);
      expect(request.passwordPolicyConfig, isNotNull);
      expect(request.emailPrivacyConfig, isNotNull);
    });

    test('creates request with no fields', () {
      final request = UpdateTenantRequest();

      expect(request.displayName, isNull);
      expect(request.emailSignInConfig, isNull);
      expect(request.anonymousSignInEnabled, isNull);
      expect(request.multiFactorConfig, isNull);
      expect(request.testPhoneNumbers, isNull);
      expect(request.smsRegionConfig, isNull);
      expect(request.recaptchaConfig, isNull);
      expect(request.passwordPolicyConfig, isNull);
      expect(request.emailPrivacyConfig, isNull);
    });
  });

  group('CreateTenantRequest', () {
    test('is an alias for UpdateTenantRequest', () {
      final request = CreateTenantRequest(displayName: 'New Tenant');

      expect(request, isA<UpdateTenantRequest>());
      expect(request.displayName, equals('New Tenant'));
    });
  });

  group('Tenant.toJson', () {
    test('toJson serialization with minimal fields', () async {
      final app = _createMockApp();
      final mockRequestHandler = AuthRequestHandlerMock();
      final tenantManager = TenantManager.internal(
        app,
        authRequestHandler: mockRequestHandler,
      );

      final tenantResponse = <String, dynamic>{
        'name': 'projects/test-project/tenants/minimal-tenant',
        'allowPasswordSignup': false,
        'enableEmailLinkSignin': false,
        'enableAnonymousUser': false,
      };

      when(
        () => mockRequestHandler.getTenant(any()),
      ).thenAnswer((_) async => tenantResponse);

      final tenant = await tenantManager.getTenant('minimal-tenant');
      final json = tenant.toJson();

      expect(json['tenantId'], equals('minimal-tenant'));
      expect(json['anonymousSignInEnabled'], equals(false));
      expect(json.containsKey('displayName'), isFalse);
      expect(json.containsKey('emailSignInConfig'), isTrue);
      expect(json.containsKey('multiFactorConfig'), isFalse);
      expect(json.containsKey('testPhoneNumbers'), isFalse);
      expect(json.containsKey('smsRegionConfig'), isFalse);
      expect(json.containsKey('recaptchaConfig'), isFalse);
      expect(json.containsKey('passwordPolicyConfig'), isFalse);
      expect(json.containsKey('emailPrivacyConfig'), isFalse);
    });

    test('toJson serialization with all fields', () async {
      final app = _createMockApp();
      final mockRequestHandler = AuthRequestHandlerMock();
      final tenantManager = TenantManager.internal(
        app,
        authRequestHandler: mockRequestHandler,
      );

      final tenantResponse = <String, dynamic>{
        'name': 'projects/test-project/tenants/full-tenant',
        'displayName': 'Full Config Tenant',
        'allowPasswordSignup': true,
        'enableEmailLinkSignin': true,
        'enableAnonymousUser': true,
        'testPhoneNumbers': {
          '+11234567890': '123456',
          '+19876543210': '654321',
        },
        'smsRegionConfig': {
          'allowByDefault': {
            'disallowedRegions': ['US', 'CA'],
          },
        },
        'mfaConfig': {
          'state': 'ENABLED',
          'enabledProviders': [
            {'state': 'ENABLED', 'totpProviderConfig': <String, dynamic>{}},
          ],
        },
        'recaptchaConfig': {
          'emailPasswordEnforcementState': 'ENFORCE',
          'phoneEnforcementState': 'AUDIT',
        },
        'passwordPolicyConfig': {'passwordPolicyEnforcementState': 'ENFORCE'},
        'emailPrivacyConfig': {'enableImprovedEmailPrivacy': true},
      };

      when(
        () => mockRequestHandler.getTenant(any()),
      ).thenAnswer((_) async => tenantResponse);

      final tenant = await tenantManager.getTenant('full-tenant');
      final json = tenant.toJson();

      expect(json['tenantId'], equals('full-tenant'));
      expect(json['displayName'], equals('Full Config Tenant'));
      expect(json['anonymousSignInEnabled'], equals(true));
      expect(json.containsKey('testPhoneNumbers'), isTrue);
      expect(json['testPhoneNumbers'], isA<Map<Object?, Object?>>());
      expect(json.containsKey('emailSignInConfig'), isTrue);
      expect(json.containsKey('multiFactorConfig'), isTrue);
      expect(json.containsKey('smsRegionConfig'), isTrue);
      expect(json.containsKey('recaptchaConfig'), isTrue);
      expect(json.containsKey('passwordPolicyConfig'), isTrue);
      expect(json.containsKey('emailPrivacyConfig'), isTrue);
    });

    test('toJson excludes null optional properties', () async {
      final app = _createMockApp();
      final mockRequestHandler = AuthRequestHandlerMock();
      final tenantManager = TenantManager.internal(
        app,
        authRequestHandler: mockRequestHandler,
      );

      final tenantResponse = <String, dynamic>{
        'name': 'projects/test-project/tenants/partial-tenant',
        'displayName': 'Partial Tenant',
        'allowPasswordSignup': true,
        'enableEmailLinkSignin': false,
        'enableAnonymousUser': false,
        'smsRegionConfig': {
          'allowByDefault': {
            'disallowedRegions': ['US'],
          },
        },
      };

      when(
        () => mockRequestHandler.getTenant(any()),
      ).thenAnswer((_) async => tenantResponse);

      final tenant = await tenantManager.getTenant('partial-tenant');
      final json = tenant.toJson();

      expect(json['tenantId'], equals('partial-tenant'));
      expect(json['displayName'], equals('Partial Tenant'));
      expect(json['anonymousSignInEnabled'], equals(false));
      expect(json.containsKey('testPhoneNumbers'), isFalse);
      expect(json.containsKey('emailSignInConfig'), isTrue);
      expect(json.containsKey('multiFactorConfig'), isFalse);
      expect(json.containsKey('smsRegionConfig'), isTrue);
      expect(json.containsKey('recaptchaConfig'), isFalse);
      expect(json.containsKey('passwordPolicyConfig'), isFalse);
      expect(json.containsKey('emailPrivacyConfig'), isFalse);
    });

    test('toJson handles allowlistOnly SMS region config', () async {
      final app = _createMockApp();
      final mockRequestHandler = AuthRequestHandlerMock();
      final tenantManager = TenantManager.internal(
        app,
        authRequestHandler: mockRequestHandler,
      );

      final tenantResponse = <String, dynamic>{
        'name': 'projects/test-project/tenants/allowlist-tenant',
        'allowPasswordSignup': false,
        'enableEmailLinkSignin': false,
        'enableAnonymousUser': false,
        'smsRegionConfig': {
          'allowlistOnly': {
            'allowedRegions': ['GB', 'FR', 'DE'],
          },
        },
      };

      when(
        () => mockRequestHandler.getTenant(any()),
      ).thenAnswer((_) async => tenantResponse);

      final tenant = await tenantManager.getTenant('allowlist-tenant');
      final json = tenant.toJson();

      expect(json['tenantId'], equals('allowlist-tenant'));
      expect(json.containsKey('smsRegionConfig'), isTrue);
      final smsConfig = json['smsRegionConfig'] as Map<String, dynamic>;
      expect(smsConfig.containsKey('allowlistOnly'), isTrue);
    });
  });
}

// Mock app for testing
FirebaseApp _createMockApp() {
  return FirebaseApp.initializeApp(
    options: AppOptions(
      projectId: 'test-project',
      credential: Credential.fromServiceAccountParams(
        clientId: 'test-client-id',
        privateKey: mockPrivateKey,
        email: mockClientEmail,
        projectId: 'test-project',
      ),
    ),
  );
}
