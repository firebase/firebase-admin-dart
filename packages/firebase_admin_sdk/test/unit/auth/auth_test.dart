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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_admin_sdk/src/app.dart';
import 'package:firebase_admin_sdk/src/auth.dart';
import 'package:googleapis/identitytoolkit/v1.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import '../../fixtures/helpers.dart';
import '../../fixtures/mock.dart';
import '../../fixtures/mock_service_account.dart';

void main() {
  late Auth auth;

  setUp(() {
    final sdk = createApp(
      credential: Credential.fromServiceAccountParams(
        privateKey: mockPrivateKey,
        email: mockClientEmail,
        projectId: projectId,
      ),
    );
    auth = Auth.internal(sdk);
  });

  setUpAll(registerFallbacks);

  group('FirebaseAuth', () {
    group('verifyIdToken', () {
      test('verifies ID token from Firebase Auth production', () {
        // Remove emulator env var from the zone environment
        final prodEnv = Map<String, String>.from(Platform.environment);
        prodEnv.remove(Environment.firebaseAuthEmulatorHost);

        return runZoned(() async {
          final appName = 'prod-test-${DateTime.now().microsecondsSinceEpoch}';
          final app = FirebaseApp.initializeApp(name: appName);
          final authProd = Auth.internal(app);

          try {
            // Helper function to exchange custom token for ID token
            Future<String> getIdTokenFromCustomToken(String customToken) async {
              final client = await authProd.app.client;
              final api = IdentityToolkitApi(client);

              final request =
                  GoogleCloudIdentitytoolkitV1SignInWithCustomTokenRequest(
                    token: customToken,
                    returnSecureToken: true,
                  );

              final response = await api.accounts.signInWithCustomToken(
                request,
              );

              if (response.idToken == null || response.idToken!.isEmpty) {
                throw Exception(
                  'Failed to exchange custom token for ID token: No idToken in response',
                );
              }

              return response.idToken!;
            }

            // Create a user and get ID token
            const email = 'foo@google.com';
            const password =
                'TestPassword123!'; // Meets all password requirements
            UserRecord? user;
            try {
              user = await authProd.createUser(
                CreateRequest(email: email, password: password),
              );

              final customToken = await authProd.createCustomToken(user.uid);
              final token = await getIdTokenFromCustomToken(customToken);
              final decodedToken = await authProd.verifyIdToken(token);

              expect(decodedToken.aud, 'dart-firebase-admin');
              expect(decodedToken.uid, user.uid);
              expect(decodedToken.sub, user.uid);
              expect(decodedToken.email, email);
              expect(decodedToken.emailVerified, false);
              expect(decodedToken.phoneNumber, isNull);
              expect(decodedToken.firebase.identities, {
                'email': [email],
              });
              // When signing in with custom token, signInProvider is 'custom'
              expect(decodedToken.firebase.signInProvider, 'custom');
            } finally {
              if (user != null) {
                await authProd.deleteUser(user.uid);
              }
            }
          } finally {
            await app.close();
          }
        }, zoneValues: {envSymbol: prodEnv});
      }, tags: 'prod');
    });

    group('Email Action Links', () {
      group('generatePasswordResetLink', () {
        test('generates link without ActionCodeSettings', () async {
          final clientMock = MockAuthClient();
          when(() => clientMock.send(any())).thenAnswer(
            (_) => Future.value(
              StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'oobLink': 'https://example.com/reset?oobCode=ABC123',
                    }),
                  ),
                ),
                200,
                headers: {'content-type': 'application/json'},
              ),
            ),
          );

          final app = createApp(client: clientMock, name: 'test-reset-link');
          final testAuth = Auth.internal(app);

          final link = await testAuth.generatePasswordResetLink(
            'test@example.com',
          );

          expect(link, equals('https://example.com/reset?oobCode=ABC123'));
        });

        test('validates email is required', () async {
          expect(
            () => auth.generatePasswordResetLink(''),
            throwsA(isA<FirebaseAuthAdminException>()),
          );
        });

        test('generates link with ActionCodeSettings', () async {
          final clientMock = MockAuthClient();
          when(() => clientMock.send(any())).thenAnswer(
            (_) => Future.value(
              StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'oobLink': 'https://example.com/reset?oobCode=ABC123',
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
            name: 'test-reset-link-settings',
          );
          final testAuth = Auth.internal(app);

          final actionCodeSettings = ActionCodeSettings(
            url: 'https://myapp.example.com/finishReset',
          );

          final link = await testAuth.generatePasswordResetLink(
            'test@example.com',
            actionCodeSettings: actionCodeSettings,
          );

          expect(link, equals('https://example.com/reset?oobCode=ABC123'));
          verify(() => clientMock.send(any())).called(1);
        });

        test('validates ActionCodeSettings.url is a valid URI', () async {
          final actionCodeSettings = ActionCodeSettings(url: 'not a valid url');

          expect(
            () => auth.generatePasswordResetLink(
              'test@example.com',
              actionCodeSettings: actionCodeSettings,
            ),
            throwsA(
              isA<FirebaseAuthAdminException>().having(
                (e) => e.errorCode,
                'errorCode',
                AuthClientErrorCode.invalidContinueUri,
              ),
            ),
          );
        });

        test('validates ActionCodeSettings.linkDomain is not empty', () async {
          final actionCodeSettings = ActionCodeSettings(
            url: 'https://example.com',
            linkDomain: '', // Empty string should fail
          );

          expect(
            () => auth.generatePasswordResetLink(
              'test@example.com',
              actionCodeSettings: actionCodeSettings,
            ),
            throwsA(
              isA<FirebaseAuthAdminException>().having(
                (e) => e.errorCode,
                'errorCode',
                AuthClientErrorCode.invalidHostingLinkDomain,
              ),
            ),
          );
        });

        test('generates link with linkDomain (new property)', () async {
          final clientMock = MockAuthClient();

          when(() => clientMock.send(any())).thenAnswer((_) {
            return Future.value(
              StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'oobLink': 'https://example.com/reset?oobCode=ABC123',
                    }),
                  ),
                ),
                200,
                headers: {'content-type': 'application/json'},
              ),
            );
          });

          final app = createApp(
            client: clientMock,
            name: 'test-reset-link-with-linkdomain',
          );
          final testAuth = Auth.internal(app);

          final actionCodeSettings = ActionCodeSettings(
            url: 'https://myapp.example.com/finishReset',
            linkDomain: 'myapp.page.link', // Using new linkDomain property
          );

          final link = await testAuth.generatePasswordResetLink(
            'test@example.com',
            actionCodeSettings: actionCodeSettings,
          );

          expect(link, equals('https://example.com/reset?oobCode=ABC123'));

          // Verify that send was called (meaning ActionCodeSettings was processed)
          verify(() => clientMock.send(any())).called(1);
        });
      });

      group('generateEmailVerificationLink', () {
        test('generates link without ActionCodeSettings', () async {
          final clientMock = MockAuthClient();
          when(() => clientMock.send(any())).thenAnswer(
            (_) => Future.value(
              StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'oobLink': 'https://example.com/verify?oobCode=XYZ789',
                    }),
                  ),
                ),
                200,
                headers: {'content-type': 'application/json'},
              ),
            ),
          );

          final app = createApp(client: clientMock, name: 'test-verify-link');
          final testAuth = Auth.internal(app);

          final link = await testAuth.generateEmailVerificationLink(
            'test@example.com',
          );

          expect(link, equals('https://example.com/verify?oobCode=XYZ789'));
          verify(() => clientMock.send(any())).called(1);
        });

        test('generates link with ActionCodeSettings', () async {
          final clientMock = MockAuthClient();
          when(() => clientMock.send(any())).thenAnswer(
            (_) => Future.value(
              StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'oobLink': 'https://example.com/verify?oobCode=XYZ789',
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
            name: 'test-verify-link-settings',
          );
          final testAuth = Auth.internal(app);

          final actionCodeSettings = ActionCodeSettings(
            url: 'https://myapp.example.com/finishVerification',
          );

          final link = await testAuth.generateEmailVerificationLink(
            'test@example.com',
            actionCodeSettings: actionCodeSettings,
          );

          expect(link, equals('https://example.com/verify?oobCode=XYZ789'));
          verify(() => clientMock.send(any())).called(1);
        });

        test('generates link with linkDomain (new property)', () async {
          final clientMock = MockAuthClient();

          when(() => clientMock.send(any())).thenAnswer((_) {
            return Future.value(
              StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'oobLink': 'https://example.com/verify?oobCode=XYZ789',
                    }),
                  ),
                ),
                200,
                headers: {'content-type': 'application/json'},
              ),
            );
          });

          final app = createApp(
            client: clientMock,
            name: 'test-verify-link-with-linkdomain',
          );
          final testAuth = Auth.internal(app);

          final actionCodeSettings = ActionCodeSettings(
            url: 'https://myapp.example.com/finishVerification',
            linkDomain: 'myapp.page.link',
          );

          final link = await testAuth.generateEmailVerificationLink(
            'test@example.com',
            actionCodeSettings: actionCodeSettings,
          );

          expect(link, equals('https://example.com/verify?oobCode=XYZ789'));
          verify(() => clientMock.send(any())).called(1);
        });

        test('validates email is required', () async {
          expect(
            () => auth.generateEmailVerificationLink(''),
            throwsA(isA<FirebaseAuthAdminException>()),
          );
        });

        test('validates ActionCodeSettings.url is a valid URI', () async {
          final actionCodeSettings = ActionCodeSettings(url: 'not a valid url');

          expect(
            () => auth.generateEmailVerificationLink(
              'test@example.com',
              actionCodeSettings: actionCodeSettings,
            ),
            throwsA(
              isA<FirebaseAuthAdminException>().having(
                (e) => e.errorCode,
                'errorCode',
                AuthClientErrorCode.invalidContinueUri,
              ),
            ),
          );
        });

        test('validates ActionCodeSettings.linkDomain is not empty', () async {
          final actionCodeSettings = ActionCodeSettings(
            url: 'https://example.com',
            linkDomain: '',
          );

          expect(
            () => auth.generateEmailVerificationLink(
              'test@example.com',
              actionCodeSettings: actionCodeSettings,
            ),
            throwsA(
              isA<FirebaseAuthAdminException>().having(
                (e) => e.errorCode,
                'errorCode',
                AuthClientErrorCode.invalidHostingLinkDomain,
              ),
            ),
          );
        });
      });

      group('generateSignInWithEmailLink', () {
        test('generates link without ActionCodeSettings', () async {
          final clientMock = MockAuthClient();

          when(() => clientMock.send(any())).thenAnswer((_) {
            return Future.value(
              StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'oobLink': 'https://example.com/signin?oobCode=DEF456',
                    }),
                  ),
                ),
                200,
                headers: {'content-type': 'application/json'},
              ),
            );
          });

          final app = createApp(client: clientMock, name: 'test-signin-link');
          final testAuth = Auth.internal(app);

          final actionCodeSettings = ActionCodeSettings(
            url: 'https://myapp.example.com/finishSignIn',
            handleCodeInApp: true,
          );

          final link = await testAuth.generateSignInWithEmailLink(
            'test@example.com',
            actionCodeSettings,
          );

          expect(link, equals('https://example.com/signin?oobCode=DEF456'));
          verify(() => clientMock.send(any())).called(1);
        });

        test('generates link with linkDomain (new property)', () async {
          final clientMock = MockAuthClient();

          when(() => clientMock.send(any())).thenAnswer((_) {
            return Future.value(
              StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'oobLink': 'https://example.com/signin?oobCode=DEF456',
                    }),
                  ),
                ),
                200,
                headers: {'content-type': 'application/json'},
              ),
            );
          });

          final app = createApp(
            client: clientMock,
            name: 'test-signin-link-with-linkdomain',
          );
          final testAuth = Auth.internal(app);

          final actionCodeSettings = ActionCodeSettings(
            url: 'https://myapp.example.com/finishSignIn',
            handleCodeInApp: true,
            linkDomain: 'myapp.page.link',
          );

          final link = await testAuth.generateSignInWithEmailLink(
            'test@example.com',
            actionCodeSettings,
          );

          expect(link, equals('https://example.com/signin?oobCode=DEF456'));
          verify(() => clientMock.send(any())).called(1);
        });

        test('generates link with ActionCodeSettings', () async {
          final clientMock = MockAuthClient();
          when(() => clientMock.send(any())).thenAnswer(
            (_) => Future.value(
              StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'oobLink': 'https://example.com/signin?oobCode=DEF456',
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
            name: 'test-signin-link-settings',
          );
          final testAuth = Auth.internal(app);

          final actionCodeSettings = ActionCodeSettings(
            url: 'https://myapp.example.com/finishSignIn',
            handleCodeInApp: true,
          );

          final link = await testAuth.generateSignInWithEmailLink(
            'test@example.com',
            actionCodeSettings,
          );

          expect(link, equals('https://example.com/signin?oobCode=DEF456'));
          verify(() => clientMock.send(any())).called(1);
        });

        test('validates email is required', () async {
          final actionCodeSettings = ActionCodeSettings(
            url: 'https://example.com',
            handleCodeInApp: true,
          );

          expect(
            () => auth.generateSignInWithEmailLink('', actionCodeSettings),
            throwsA(isA<FirebaseAuthAdminException>()),
          );
        });

        test('validates ActionCodeSettings.linkDomain is not empty', () {
          final actionCodeSettings = ActionCodeSettings(
            url: 'https://example.com',
            handleCodeInApp: true,
            linkDomain: '',
          );

          expect(
            () => auth.generateSignInWithEmailLink(
              'test@example.com',
              actionCodeSettings,
            ),
            throwsA(
              isA<FirebaseAuthAdminException>().having(
                (e) => e.errorCode,
                'errorCode',
                AuthClientErrorCode.invalidHostingLinkDomain,
              ),
            ),
          );
        });
      });

      group('generateVerifyAndChangeEmailLink', () {
        test('generates link without ActionCodeSettings', () async {
          final clientMock = MockAuthClient();
          when(() => clientMock.send(any())).thenAnswer(
            (_) => Future.value(
              StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'oobLink':
                          'https://example.com/changeEmail?oobCode=GHI789',
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
            name: 'test-change-email-link-basic',
          );
          final testAuth = Auth.internal(app);

          final link = await testAuth.generateVerifyAndChangeEmailLink(
            'old@example.com',
            'new@example.com',
          );

          expect(
            link,
            equals('https://example.com/changeEmail?oobCode=GHI789'),
          );
          verify(() => clientMock.send(any())).called(1);
        });

        test('generates link with ActionCodeSettings', () async {
          final clientMock = MockAuthClient();

          when(() => clientMock.send(any())).thenAnswer((_) {
            return Future.value(
              StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'oobLink':
                          'https://example.com/changeEmail?oobCode=GHI789',
                    }),
                  ),
                ),
                200,
                headers: {'content-type': 'application/json'},
              ),
            );
          });

          final app = createApp(
            client: clientMock,
            name: 'test-change-email-link',
          );
          final testAuth = Auth.internal(app);

          final actionCodeSettings = ActionCodeSettings(
            url: 'https://myapp.example.com/finishChangeEmail',
          );

          final link = await testAuth.generateVerifyAndChangeEmailLink(
            'old@example.com',
            'new@example.com',
            actionCodeSettings: actionCodeSettings,
          );

          expect(
            link,
            equals('https://example.com/changeEmail?oobCode=GHI789'),
          );
          verify(() => clientMock.send(any())).called(1);
        });

        test('generates link with linkDomain (new property)', () async {
          final clientMock = MockAuthClient();

          when(() => clientMock.send(any())).thenAnswer((_) {
            return Future.value(
              StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'oobLink':
                          'https://example.com/changeEmail?oobCode=GHI789',
                    }),
                  ),
                ),
                200,
                headers: {'content-type': 'application/json'},
              ),
            );
          });

          final app = createApp(
            client: clientMock,
            name: 'test-change-email-link-with-linkdomain',
          );
          final testAuth = Auth.internal(app);

          final actionCodeSettings = ActionCodeSettings(
            url: 'https://myapp.example.com/finishChangeEmail',
            linkDomain: 'myapp.page.link',
          );

          final link = await testAuth.generateVerifyAndChangeEmailLink(
            'old@example.com',
            'new@example.com',
            actionCodeSettings: actionCodeSettings,
          );

          expect(
            link,
            equals('https://example.com/changeEmail?oobCode=GHI789'),
          );
          verify(() => clientMock.send(any())).called(1);
        });

        test('validates email is required', () async {
          final actionCodeSettings = ActionCodeSettings(
            url: 'https://example.com',
          );

          expect(
            () => auth.generateVerifyAndChangeEmailLink(
              '',
              'new@example.com',
              actionCodeSettings: actionCodeSettings,
            ),
            throwsA(isA<FirebaseAuthAdminException>()),
          );
        });

        test('validates newEmail is required', () async {
          final actionCodeSettings = ActionCodeSettings(
            url: 'https://example.com',
          );

          expect(
            () => auth.generateVerifyAndChangeEmailLink(
              'old@example.com',
              '',
              actionCodeSettings: actionCodeSettings,
            ),
            throwsA(isA<FirebaseAuthAdminException>()),
          );
        });

        test('validates ActionCodeSettings.linkDomain is not empty', () {
          final actionCodeSettings = ActionCodeSettings(
            url: 'https://example.com',
            linkDomain: '',
          );

          expect(
            () => auth.generateVerifyAndChangeEmailLink(
              'old@example.com',
              'new@example.com',
              actionCodeSettings: actionCodeSettings,
            ),
            throwsA(
              isA<FirebaseAuthAdminException>().having(
                (e) => e.errorCode,
                'errorCode',
                AuthClientErrorCode.invalidHostingLinkDomain,
              ),
            ),
          );
        });
      });
    });

    group('createCustomToken', () {
      test('creates a valid JWT token', () async {
        final token = await auth.createCustomToken('test-uid');

        expect(token, isNotEmpty);
        expect(token, isA<String>());
        // Token should be in JWT format (3 parts separated by dots)
        expect(token.split('.').length, equals(3));
      });

      test('creates token with developer claims', () async {
        final token = await auth.createCustomToken(
          'test-uid',
          developerClaims: {'admin': true, 'level': 5},
        );

        expect(token, isNotEmpty);
        expect(token, isA<String>());
      });

      test('throws when uid is empty', () async {
        expect(
          () => auth.createCustomToken(''),
          throwsA(isA<FirebaseAuthAdminException>()),
        );
      });
    });

    group('setCustomUserClaims', () {
      test('sets custom claims for user', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({'localId': 'test-uid'}))),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-set-claims');
        final testAuth = Auth.internal(app);

        await testAuth.setCustomUserClaims(
          'test-uid',
          customUserClaims: {'admin': true, 'role': 'editor'},
        );

        verify(() => clientMock.send(any())).called(1);
      });

      test('throws when uid is empty', () async {
        await expectLater(
          () => auth.setCustomUserClaims('', customUserClaims: {'admin': true}),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/invalid-uid',
            ),
          ),
        );
      });

      test('throws when uid is invalid (too long)', () async {
        final invalidUid = 'a' * 129; // UID must be <= 128 characters
        await expectLater(
          () => auth.setCustomUserClaims(
            invalidUid,
            customUserClaims: {'admin': true},
          ),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/invalid-uid',
            ),
          ),
        );
      });

      test('clears claims when null is passed', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({'localId': 'test-uid'}))),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-clear-claims');
        final testAuth = Auth.internal(app);

        await testAuth.setCustomUserClaims('test-uid');

        verify(() => clientMock.send(any())).called(1);
      });

      test('throws error when backend returns error', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {'code': 404, 'message': 'USER_NOT_FOUND'},
                  }),
                ),
              ),
              404,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-set-claims-error',
        );
        final testAuth = Auth.internal(app);

        await expectLater(
          testAuth.setCustomUserClaims(
            'test-uid',
            customUserClaims: {'admin': true},
          ),
          throwsA(isA<FirebaseAuthAdminException>()),
        );

        verify(() => clientMock.send(any())).called(1);
      });
    });

    group('revokeRefreshTokens', () {
      test('revokes refresh tokens successfully', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'localId': 'test-uid',
                    'validSince':
                        '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
                  }),
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-revoke-tokens');
        final testAuth = Auth.internal(app);

        await testAuth.revokeRefreshTokens('test-uid');

        verify(() => clientMock.send(any())).called(1);
      });

      test('throws when uid is empty', () async {
        await expectLater(
          () => auth.revokeRefreshTokens(''),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/invalid-uid',
            ),
          ),
        );
      });

      test('throws when uid is invalid (too long)', () async {
        final invalidUid = 'a' * 129; // UID must be <= 128 characters
        await expectLater(
          () => auth.revokeRefreshTokens(invalidUid),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/invalid-uid',
            ),
          ),
        );
      });

      test('throws error when backend returns error', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {'code': 404, 'message': 'USER_NOT_FOUND'},
                  }),
                ),
              ),
              404,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-revoke-tokens-error',
        );
        final testAuth = Auth.internal(app);

        await expectLater(
          testAuth.revokeRefreshTokens('test-uid'),
          throwsA(isA<FirebaseAuthAdminException>()),
        );

        verify(() => clientMock.send(any())).called(1);
      });
    });

    group('deleteUser', () {
      test('deletes user successfully', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({'kind': 'identitytoolkit#DeleteAccountResponse'}),
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-delete-user');
        final testAuth = Auth.internal(app);

        await testAuth.deleteUser('test-uid');

        verify(() => clientMock.send(any())).called(1);
      });

      test('throws when uid is empty', () async {
        expect(
          () => auth.deleteUser(''),
          throwsA(isA<FirebaseAuthAdminException>()),
        );
      });

      test('throws when uid is invalid (too long)', () async {
        // UID must be 128 characters or less
        final invalidUid = 'a' * 129;
        await expectLater(
          () => auth.deleteUser(invalidUid),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/invalid-uid',
            ),
          ),
        );
      });

      test('throws error when backend returns error', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {'code': 404, 'message': 'USER_NOT_FOUND'},
                  }),
                ),
              ),
              404,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-delete-user-error',
        );
        final testAuth = Auth.internal(app);

        await expectLater(
          testAuth.deleteUser('non-existent-uid'),
          throwsA(isA<FirebaseAuthAdminException>()),
        );

        verify(() => clientMock.send(any())).called(1);
      });
    });

    group('deleteUsers', () {
      test('deletes multiple users successfully', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({'errors': <dynamic>[]}))),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-delete-users');
        final testAuth = Auth.internal(app);

        final result = await testAuth.deleteUsers(['uid1', 'uid2', 'uid3']);

        expect(result.successCount, equals(3));
        expect(result.failureCount, equals(0));
        expect(result.errors, isEmpty);
        verify(() => clientMock.send(any())).called(1);
      });

      test('handles errors for some users', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'errors': [
                      {'index': 1, 'message': 'USER_NOT_FOUND'},
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
          name: 'test-delete-users-errors',
        );
        final testAuth = Auth.internal(app);

        final result = await testAuth.deleteUsers(['uid1', 'uid2', 'uid3']);

        expect(result.successCount, equals(2));
        expect(result.failureCount, equals(1));
        expect(result.errors, hasLength(1));
        verify(() => clientMock.send(any())).called(1);
      });

      test('handles empty array', () async {
        final result = await auth.deleteUsers([]);

        expect(result.successCount, equals(0));
        expect(result.failureCount, equals(0));
        expect(result.errors, isEmpty);
      });

      test('throws when uids list exceeds maximum limit', () async {
        // Maximum is 1000 uids
        final tooManyUids = List.generate(1001, (i) => 'uid$i');

        await expectLater(
          () => auth.deleteUsers(tooManyUids),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/maximum-user-count-exceeded',
            ),
          ),
        );
      });

      test('handles multiple errors with correct indexing', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'errors': [
                      {'index': 0, 'message': 'USER_NOT_FOUND'},
                      {'index': 2, 'message': 'INTERNAL_ERROR'},
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
          name: 'test-delete-users-multiple-errors',
        );
        final testAuth = Auth.internal(app);

        final result = await testAuth.deleteUsers([
          'uid1',
          'uid2',
          'uid3',
          'uid4',
        ]);

        expect(result.successCount, equals(2));
        expect(result.failureCount, equals(2));
        expect(result.errors, hasLength(2));
        expect(result.errors[0].index, equals(0));
        expect(result.errors[1].index, equals(2));
        verify(() => clientMock.send(any())).called(1);
      });
    });

    group('listUsers', () {
      test('lists users successfully', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'users': [
                      {
                        'localId': 'uid1',
                        'email': 'user1@example.com',
                        'emailVerified': false,
                        'disabled': false,
                        'createdAt': '1234567890000',
                      },
                      {
                        'localId': 'uid2',
                        'email': 'user2@example.com',
                        'emailVerified': true,
                        'disabled': false,
                        'createdAt': '1234567890000',
                      },
                    ],
                    'nextPageToken': 'next-page-token',
                  }),
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-list-users');
        final testAuth = Auth.internal(app);

        final result = await testAuth.listUsers();

        expect(result.users, hasLength(2));
        expect(result.users[0].uid, equals('uid1'));
        expect(result.users[1].uid, equals('uid2'));
        expect(result.pageToken, equals('next-page-token'));
        verify(() => clientMock.send(any())).called(1);
      });

      test('supports pagination parameters', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({'users': <dynamic>[]}))),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-list-users-pagination',
        );
        final testAuth = Auth.internal(app);

        await testAuth.listUsers(maxResults: 10, pageToken: 'page-token');

        verify(() => clientMock.send(any())).called(1);
      });

      test('lists users with default options', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'users': [
                      {
                        'localId': 'uid1',
                        'email': 'user1@example.com',
                        'emailVerified': false,
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
          name: 'test-list-users-default',
        );
        final testAuth = Auth.internal(app);

        final result = await testAuth.listUsers();

        expect(result.users, hasLength(1));
        expect(result.users[0].uid, equals('uid1'));
        verify(() => clientMock.send(any())).called(1);
      });

      test('returns empty list when no users exist', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({'users': <dynamic>[]}))),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-list-users-empty',
        );
        final testAuth = Auth.internal(app);

        final result = await testAuth.listUsers(maxResults: 500);

        expect(result.users, isEmpty);
        expect(result.pageToken, isNull);
        verify(() => clientMock.send(any())).called(1);
      });

      test('throws error when backend returns error', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {'code': 500, 'message': 'INTERNAL_ERROR'},
                  }),
                ),
              ),
              500,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-list-users-error',
        );
        final testAuth = Auth.internal(app);

        await expectLater(
          testAuth.listUsers(maxResults: 500),
          throwsA(isA<FirebaseAuthAdminException>()),
        );

        verify(() => clientMock.send(any())).called(1);
      });
    });

    group('getUsers', () {
      test('gets multiple users by identifiers', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'users': [
                      {
                        'localId': 'uid1',
                        'email': 'user1@example.com',
                        'emailVerified': false,
                        'disabled': false,
                        'createdAt': '1234567890000',
                      },
                      {
                        'localId': 'uid2',
                        'phoneNumber': '+1234567890',
                        'emailVerified': false,
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

        final app = createApp(client: clientMock, name: 'test-get-users');
        final testAuth = Auth.internal(app);

        final result = await testAuth.getUsers([
          UidIdentifier(uid: 'uid1'),
          EmailIdentifier(email: 'user1@example.com'),
          UidIdentifier(uid: 'uid2'),
        ]);

        expect(result.users, hasLength(2));
        expect(result.users[0].uid, equals('uid1'));
        expect(result.users[1].uid, equals('uid2'));
        verify(() => clientMock.send(any())).called(1);
      });

      test('handles empty identifiers array', () async {
        final result = await auth.getUsers([]);

        expect(result.users, isEmpty);
        expect(result.notFound, isEmpty);
      });

      test(
        'returns no users when given identifiers that do not exist',
        () async {
          final clientMock = MockAuthClient();
          when(() => clientMock.send(any())).thenAnswer(
            (_) => Future.value(
              StreamedResponse(
                Stream.value(utf8.encode(jsonEncode({}))),
                200,
                headers: {'content-type': 'application/json'},
              ),
            ),
          );

          final app = createApp(
            client: clientMock,
            name: 'test-get-users-not-found',
          );
          final testAuth = Auth.internal(app);

          final notFoundIds = [UidIdentifier(uid: 'id-that-doesnt-exist')];
          final result = await testAuth.getUsers(notFoundIds);

          expect(result.users, isEmpty);
          expect(result.notFound, equals(notFoundIds));
          verify(() => clientMock.send(any())).called(1);
        },
      );

      test('throws when identifiers list exceeds maximum limit', () {
        // Maximum is 100 identifiers
        final tooManyIdentifiers = List.generate(
          101,
          (i) => UidIdentifier(uid: 'uid$i'),
        );

        expect(
          () => auth.getUsers(tooManyIdentifiers),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/maximum-user-count-exceeded',
            ),
          ),
        );
      });

      test(
        'returns users by various identifier types including provider',
        () async {
          final clientMock = MockAuthClient();
          when(() => clientMock.send(any())).thenAnswer(
            (_) => Future.value(
              StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'users': [
                        {
                          'localId': 'uid1',
                          'email': 'user1@example.com',
                          'phoneNumber': '+15555550001',
                          'emailVerified': false,
                          'disabled': false,
                          'createdAt': '1234567890000',
                        },
                        {
                          'localId': 'uid2',
                          'email': 'user2@example.com',
                          'phoneNumber': '+15555550002',
                          'emailVerified': false,
                          'disabled': false,
                          'createdAt': '1234567890000',
                        },
                        {
                          'localId': 'uid3',
                          'email': 'user3@example.com',
                          'phoneNumber': '+15555550003',
                          'emailVerified': false,
                          'disabled': false,
                          'createdAt': '1234567890000',
                        },
                        {
                          'localId': 'uid4',
                          'email': 'user4@example.com',
                          'phoneNumber': '+15555550004',
                          'emailVerified': false,
                          'disabled': false,
                          'createdAt': '1234567890000',
                          'providerUserInfo': [
                            {
                              'providerId': 'google.com',
                              'rawId': 'google_uid4',
                            },
                          ],
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
            name: 'test-get-users-various-types',
          );
          final testAuth = Auth.internal(app);

          final identifiers = [
            UidIdentifier(uid: 'uid1'),
            EmailIdentifier(email: 'user2@example.com'),
            PhoneIdentifier(phoneNumber: '+15555550003'),
            ProviderIdentifier(
              providerId: 'google.com',
              providerUid: 'google_uid4',
            ),
            UidIdentifier(uid: 'this-user-doesnt-exist'),
          ];

          final result = await testAuth.getUsers(identifiers);

          expect(result.users, hasLength(4));
          // Check that the non-existent uid is in notFound
          expect(result.notFound, isNotEmpty);
          final notFoundUid = result.notFound
              .whereType<UidIdentifier>()
              .where((id) => id.uid == 'this-user-doesnt-exist')
              .firstOrNull;
          expect(notFoundUid, isNotNull);
          expect(notFoundUid!.uid, equals('this-user-doesnt-exist'));
          verify(() => clientMock.send(any())).called(1);
        },
      );
    });

    group('getUser', () {
      test('gets user successfully', () async {
        const testUid = 'test-uid-123';
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'users': [
                      {
                        'localId': testUid,
                        'email': 'test@example.com',
                        'displayName': 'Test User',
                        'emailVerified': false,
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

        final app = createApp(client: clientMock, name: 'test-get-user');
        final testAuth = Auth.internal(app);

        final user = await testAuth.getUser(testUid);

        expect(user.uid, equals(testUid));
        expect(user.email, equals('test@example.com'));
        expect(user.displayName, equals('Test User'));
        expect(user.emailVerified, isFalse);
        expect(user.disabled, isFalse);
        verify(() => clientMock.send(any())).called(1);
      });

      test('throws when uid is empty', () async {
        await expectLater(
          () => auth.getUser(''),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/invalid-uid',
            ),
          ),
        );
      });

      test('throws when uid is invalid (too long)', () async {
        final invalidUid = 'a' * 129; // UID must be <= 128 characters
        await expectLater(
          () => auth.getUser(invalidUid),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/invalid-uid',
            ),
          ),
        );
      });

      test('throws error when backend returns error', () async {
        const testUid = 'test-uid-123';
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {'code': 404, 'message': 'USER_NOT_FOUND'},
                  }),
                ),
              ),
              404,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-get-user-error');
        final testAuth = Auth.internal(app);

        await expectLater(
          testAuth.getUser(testUid),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/user-not-found',
            ),
          ),
        );

        verify(() => clientMock.send(any())).called(1);
      });
    });

    group('getUserByEmail', () {
      test('gets user by email successfully', () async {
        const testEmail = 'user@example.com';
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
                        'email': testEmail,
                        'displayName': 'Test User',
                        'emailVerified': false,
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
          name: 'test-get-user-by-email',
        );
        final testAuth = Auth.internal(app);

        final user = await testAuth.getUserByEmail(testEmail);

        expect(user.uid, equals('test-uid-123'));
        expect(user.email, equals(testEmail));
        expect(user.displayName, equals('Test User'));
        expect(user.emailVerified, isFalse);
        expect(user.disabled, isFalse);
        verify(() => clientMock.send(any())).called(1);
      });

      test('throws when email is empty', () async {
        await expectLater(
          () => auth.getUserByEmail(''),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/invalid-email',
            ),
          ),
        );
      });

      test('throws when email is invalid', () async {
        const invalidEmail = 'name-example-com';
        await expectLater(
          () => auth.getUserByEmail(invalidEmail),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/invalid-email',
            ),
          ),
        );
      });

      test('throws error when backend returns error', () async {
        const testEmail = 'user@example.com';
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {'code': 404, 'message': 'USER_NOT_FOUND'},
                  }),
                ),
              ),
              404,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-get-user-by-email-error',
        );
        final testAuth = Auth.internal(app);

        await expectLater(
          testAuth.getUserByEmail(testEmail),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/user-not-found',
            ),
          ),
        );

        verify(() => clientMock.send(any())).called(1);
      });
    });

    group('getUserByPhoneNumber', () {
      test('gets user by phone number successfully', () async {
        const testPhoneNumber = '+11234567890';
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
                        'phoneNumber': testPhoneNumber,
                        'emailVerified': false,
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
          name: 'test-get-user-by-phone',
        );
        final testAuth = Auth.internal(app);

        final user = await testAuth.getUserByPhoneNumber(testPhoneNumber);

        expect(user.uid, equals('test-uid-123'));
        expect(user.phoneNumber, equals(testPhoneNumber));
        expect(user.emailVerified, isFalse);
        expect(user.disabled, isFalse);
        verify(() => clientMock.send(any())).called(1);
      });

      test('throws when phone number is empty', () async {
        await expectLater(
          () => auth.getUserByPhoneNumber(''),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/invalid-phone-number',
            ),
          ),
        );
      });

      test('throws when phone number is invalid', () async {
        const invalidPhoneNumber = 'invalid';
        await expectLater(
          () => auth.getUserByPhoneNumber(invalidPhoneNumber),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/invalid-phone-number',
            ),
          ),
        );
      });

      test('throws error when backend returns error', () async {
        const testPhoneNumber = '+11234567890';
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {'code': 404, 'message': 'USER_NOT_FOUND'},
                  }),
                ),
              ),
              404,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-get-user-by-phone-error',
        );
        final testAuth = Auth.internal(app);

        await expectLater(
          testAuth.getUserByPhoneNumber(testPhoneNumber),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/user-not-found',
            ),
          ),
        );

        verify(() => clientMock.send(any())).called(1);
      });
    });

    group('getUserByProviderUid', () {
      test('gets user by provider uid successfully', () async {
        const providerId = 'google.com';
        const providerUid = 'google_uid';
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
                        'email': 'user@example.com',
                        'emailVerified': false,
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
          name: 'test-get-user-by-provider-uid',
        );
        final testAuth = Auth.internal(app);

        final user = await testAuth.getUserByProviderUid(
          providerId: providerId,
          uid: providerUid,
        );

        expect(user.uid, equals('test-uid-123'));
        expect(user.email, equals('user@example.com'));
        verify(() => clientMock.send(any())).called(1);
      });

      test('throws when provider ID is empty', () {
        expect(
          () => auth.getUserByProviderUid(providerId: '', uid: 'uid'),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/invalid-provider-id',
            ),
          ),
        );
      });

      test('throws invalid-uid when uid is empty', () {
        expect(
          () => auth.getUserByProviderUid(providerId: 'google.com', uid: ''),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/invalid-uid',
            ),
          ),
        );
      });

      test(
        'redirects to getUserByPhoneNumber when providerId is phone',
        () async {
          const phoneNumber = '+11234567890';
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
                          'phoneNumber': phoneNumber,
                          'emailVerified': false,
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
            name: 'test-get-user-by-phone-provider',
          );
          final testAuth = Auth.internal(app);

          final user = await testAuth.getUserByProviderUid(
            providerId: 'phone',
            uid: phoneNumber,
          );

          expect(user.uid, equals('test-uid-123'));
          expect(user.phoneNumber, equals(phoneNumber));
          verify(() => clientMock.send(any())).called(1);
        },
      );

      test('redirects to getUserByEmail when providerId is email', () async {
        const email = 'user@example.com';
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
                        'email': email,
                        'emailVerified': false,
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
          name: 'test-get-user-by-email-provider',
        );
        final testAuth = Auth.internal(app);

        final user = await testAuth.getUserByProviderUid(
          providerId: 'email',
          uid: email,
        );

        expect(user.uid, equals('test-uid-123'));
        expect(user.email, equals(email));
        verify(() => clientMock.send(any())).called(1);
      });

      test('throws error when backend returns error', () async {
        const providerId = 'google.com';
        const providerUid = 'google_uid';
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {'code': 404, 'message': 'USER_NOT_FOUND'},
                  }),
                ),
              ),
              404,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-get-user-by-provider-uid-error',
        );
        final testAuth = Auth.internal(app);

        await expectLater(
          testAuth.getUserByProviderUid(
            providerId: providerId,
            uid: providerUid,
          ),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/user-not-found',
            ),
          ),
        );

        verify(() => clientMock.send(any())).called(1);
      });
    });

    group('importUsers', () {
      test('imports users successfully', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({'error': <dynamic>[]}))),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-import-users');
        final testAuth = Auth.internal(app);

        final users = [
          UserImportRecord(uid: 'uid1', email: 'user1@example.com'),
          UserImportRecord(uid: 'uid2', email: 'user2@example.com'),
        ];

        final result = await testAuth.importUsers(users);

        expect(result.successCount, equals(2));
        expect(result.failureCount, equals(0));
        expect(result.errors, isEmpty);
        verify(() => clientMock.send(any())).called(1);
      });

      test('handles partial failures', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': [
                      {'index': 1, 'message': 'INVALID_PHONE_NUMBER'},
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
          name: 'test-import-users-partial',
        );
        final testAuth = Auth.internal(app);

        final users = [
          UserImportRecord(uid: 'uid1', email: 'user1@example.com'),
          UserImportRecord(uid: 'uid2', phoneNumber: 'invalid'),
        ];

        final result = await testAuth.importUsers(users);

        expect(result.successCount, equals(1));
        expect(result.failureCount, equals(1));
        expect(result.errors, hasLength(1));
        expect(result.errors[0].index, equals(1));
        verify(() => clientMock.send(any())).called(1);
      });

      test('throws error when backend returns error', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {'code': 500, 'message': 'INTERNAL_ERROR'},
                  }),
                ),
              ),
              500,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-import-users-error',
        );
        final testAuth = Auth.internal(app);

        final users = [
          UserImportRecord(uid: 'uid1', email: 'user1@example.com'),
        ];

        await expectLater(
          testAuth.importUsers(users),
          throwsA(isA<FirebaseAuthAdminException>()),
        );

        verify(() => clientMock.send(any())).called(1);
      });
    });

    group('listProviderConfigs', () {
      test('lists OIDC provider configs successfully', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'oauthIdpConfigs': [
                      {
                        'name':
                            'projects/project_id/oauthIdpConfigs/oidc.provider1',
                        'displayName': 'OIDC Provider 1',
                        'enabled': true,
                        'clientId': 'CLIENT_ID_1',
                        'issuer': 'https://oidc1.com/issuer',
                      },
                      {
                        'name':
                            'projects/project_id/oauthIdpConfigs/oidc.provider2',
                        'displayName': 'OIDC Provider 2',
                        'enabled': true,
                        'clientId': 'CLIENT_ID_2',
                        'issuer': 'https://oidc2.com/issuer',
                      },
                    ],
                    'nextPageToken': 'NEXT_PAGE_TOKEN',
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
          name: 'test-list-oidc-configs',
        );
        final testAuth = Auth.internal(app);

        final result = await testAuth.listProviderConfigs(
          AuthProviderConfigFilter.oidc(
            maxResults: 50,
            pageToken: 'PAGE_TOKEN',
          ),
        );

        expect(result.providerConfigs, hasLength(2));
        expect(result.providerConfigs[0], isA<OIDCAuthProviderConfig>());
        expect(result.providerConfigs[0].providerId, equals('oidc.provider1'));
        expect(result.providerConfigs[1].providerId, equals('oidc.provider2'));
        expect(result.pageToken, equals('NEXT_PAGE_TOKEN'));
        verify(() => clientMock.send(any())).called(1);
      });

      test('lists SAML provider configs successfully', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'inboundSamlConfigs': [
                      {
                        'name':
                            'projects/project_id/inboundSamlConfigs/saml.provider1',
                        'idpConfig': {
                          'idpEntityId': 'IDP_ENTITY_ID_1',
                          'ssoUrl': 'https://saml1.com/login',
                          'idpCertificates': [
                            {'x509Certificate': 'CERT1'},
                          ],
                        },
                        'spConfig': {
                          'spEntityId': 'RP_ENTITY_ID_1',
                          'callbackUri':
                              'https://project-id.firebaseapp.com/__/auth/handler',
                        },
                        'displayName': 'SAML Provider 1',
                        'enabled': true,
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
          name: 'test-list-saml-configs',
        );
        final testAuth = Auth.internal(app);

        final result = await testAuth.listProviderConfigs(
          AuthProviderConfigFilter.saml(),
        );

        expect(result.providerConfigs, hasLength(1));
        expect(result.providerConfigs[0], isA<SAMLAuthProviderConfig>());
        expect(result.providerConfigs[0].providerId, equals('saml.provider1'));
        verify(() => clientMock.send(any())).called(1);
      });

      test('returns empty list when no configs exist', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(jsonEncode({'oauthIdpConfigs': <dynamic>[]})),
              ),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-list-configs-empty',
        );
        final testAuth = Auth.internal(app);

        final result = await testAuth.listProviderConfigs(
          AuthProviderConfigFilter.oidc(),
        );

        expect(result.providerConfigs, isEmpty);
        expect(result.pageToken, isNull);
        verify(() => clientMock.send(any())).called(1);
      });

      test('throws error when backend returns error', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {'code': 500, 'message': 'INTERNAL_ERROR'},
                  }),
                ),
              ),
              500,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-list-configs-error',
        );
        final testAuth = Auth.internal(app);

        await expectLater(
          testAuth.listProviderConfigs(AuthProviderConfigFilter.oidc()),
          throwsA(isA<FirebaseAuthAdminException>()),
        );

        verify(() => clientMock.send(any())).called(1);
      });
    });

    group('updateProviderConfig', () {
      test('throws when provider ID is invalid', () async {
        const invalidProviderIds = [
          '',
          'unsupported',
          'oidc.',
          'oidc.provider.',
          'oidc.provider\n',
          'oidc.provider/1',
          r'oidc.provider\1',
          'oidc.provider?k=v',
          'oidc.provider#frag',
          'oidc.provider%2f1',
          'saml.',
          'saml.provider.',
          'saml.provider\n',
          'saml.provider/1',
          r'saml.provider\1',
          'saml.provider?k=v',
          'saml.provider#frag',
          'saml.provider%2f1',
        ];
        for (final providerId in invalidProviderIds) {
          await expectLater(
            () => auth.updateProviderConfig(
              providerId,
              OIDCUpdateAuthProviderRequest(displayName: 'Test'),
            ),
            throwsA(
              isA<FirebaseAuthAdminException>().having(
                (e) => e.code,
                'code',
                'auth/invalid-provider-id',
              ),
            ),
            reason: providerId,
          );
        }
      });

      test('updates OIDC provider config successfully', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'name': 'projects/project_id/oauthIdpConfigs/oidc.provider',
                    'displayName': 'Updated OIDC Display Name',
                    'enabled': true,
                    'clientId': 'UPDATED_CLIENT_ID',
                    'issuer': 'https://updated-oidc.com/issuer',
                    'clientSecret': 'CLIENT_SECRET',
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
          name: 'test-update-oidc-config',
        );
        final testAuth = Auth.internal(app);

        final config = await testAuth.updateProviderConfig(
          'oidc.provider',
          OIDCUpdateAuthProviderRequest(
            displayName: 'Updated OIDC Display Name',
            clientId: 'UPDATED_CLIENT_ID',
            issuer: 'https://updated-oidc.com/issuer',
          ),
        );

        expect(config, isA<OIDCAuthProviderConfig>());
        expect(config.providerId, equals('oidc.provider'));
        expect(config.displayName, equals('Updated OIDC Display Name'));
        verify(() => clientMock.send(any())).called(1);
      });

      test('updates SAML provider config successfully', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'name':
                        'projects/project_id/inboundSamlConfigs/saml.provider',
                    'idpConfig': {
                      'idpEntityId': 'UPDATED_IDP_ENTITY_ID',
                      'ssoUrl': 'https://updated-saml.com/login',
                      'idpCertificates': [
                        {'x509Certificate': 'UPDATED_CERT'},
                      ],
                    },
                    'spConfig': {
                      'spEntityId': 'UPDATED_RP_ENTITY_ID',
                      'callbackUri':
                          'https://project-id.firebaseapp.com/__/auth/handler',
                    },
                    'displayName': 'Updated SAML Display Name',
                    'enabled': true,
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
          name: 'test-update-saml-config',
        );
        final testAuth = Auth.internal(app);

        final config = await testAuth.updateProviderConfig(
          'saml.provider',
          SAMLUpdateAuthProviderRequest(
            displayName: 'Updated SAML Display Name',
            idpEntityId: 'UPDATED_IDP_ENTITY_ID',
            ssoURL: 'https://updated-saml.com/login',
          ),
        );

        expect(config, isA<SAMLAuthProviderConfig>());
        expect(config.providerId, equals('saml.provider'));
        expect(config.displayName, equals('Updated SAML Display Name'));
        verify(() => clientMock.send(any())).called(1);
      });

      test('throws error when backend returns error for OIDC', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {
                      'code': 404,
                      'message': 'CONFIGURATION_NOT_FOUND',
                    },
                  }),
                ),
              ),
              404,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-update-oidc-error',
        );
        final testAuth = Auth.internal(app);

        await expectLater(
          testAuth.updateProviderConfig(
            'oidc.provider',
            OIDCUpdateAuthProviderRequest(displayName: 'Test'),
          ),
          throwsA(isA<FirebaseAuthAdminException>()),
        );

        verify(() => clientMock.send(any())).called(1);
      });

      test('throws error when backend returns error for SAML', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {
                      'code': 404,
                      'message': 'CONFIGURATION_NOT_FOUND',
                    },
                  }),
                ),
              ),
              404,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-update-saml-error',
        );
        final testAuth = Auth.internal(app);

        await expectLater(
          testAuth.updateProviderConfig(
            'saml.provider',
            SAMLUpdateAuthProviderRequest(displayName: 'Test'),
          ),
          throwsA(isA<FirebaseAuthAdminException>()),
        );

        verify(() => clientMock.send(any())).called(1);
      });
    });

    group('updateUser', () {
      test('updates user successfully', () async {
        const testUid = 'test-uid-123';
        final clientMock = MockAuthClient();
        var callCount = 0;
        when(() => clientMock.send(any())).thenAnswer((_) {
          callCount++;
          // First call: setAccountInfo (updateExistingAccount) - returns localId
          if (callCount == 1) {
            return Future.value(
              StreamedResponse(
                Stream.value(utf8.encode(jsonEncode({'localId': testUid}))),
                200,
                headers: {'content-type': 'application/json'},
              ),
            );
          }
          // Second call: lookup (getAccountInfoByUid) - returns updated user info
          return Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'users': [
                      {
                        'localId': testUid,
                        'email': 'updated@example.com',
                        'displayName': 'Updated Name',
                        'emailVerified': true,
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
          );
        });

        final app = createApp(client: clientMock, name: 'test-update-user');
        final testAuth = Auth.internal(app);

        final user = await testAuth.updateUser(
          testUid,
          UpdateRequest(
            email: 'updated@example.com',
            displayName: 'Updated Name',
            emailVerified: true,
          ),
        );

        expect(user.uid, equals(testUid));
        expect(user.email, equals('updated@example.com'));
        expect(user.displayName, equals('Updated Name'));
        expect(user.emailVerified, isTrue);
        verify(() => clientMock.send(any())).called(2);
      });

      test('throws when uid is empty', () async {
        await expectLater(
          () => auth.updateUser('', UpdateRequest(email: 'test@example.com')),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/invalid-uid',
            ),
          ),
        );
      });

      test('throws when uid is invalid (too long)', () async {
        final invalidUid = 'a' * 129; // UID must be <= 128 characters
        await expectLater(
          () => auth.updateUser(
            invalidUid,
            UpdateRequest(email: 'test@example.com'),
          ),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/invalid-uid',
            ),
          ),
        );
      });

      test('throws error when backend returns error', () async {
        const testUid = 'test-uid-123';
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {'code': 404, 'message': 'USER_NOT_FOUND'},
                  }),
                ),
              ),
              404,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-update-user-error',
        );
        final testAuth = Auth.internal(app);

        await expectLater(
          testAuth.updateUser(
            testUid,
            UpdateRequest(email: 'test@example.com'),
          ),
          throwsA(isA<FirebaseAuthAdminException>()),
        );

        verify(() => clientMock.send(any())).called(1);
      });
    });

    group('verifyIdToken', () {
      test('verifies ID token successfully', () async {
        final mockTokenVerifier = MockFirebaseTokenVerifier();
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
          },
        });

        when(
          () => mockTokenVerifier.verifyJWT(
            any(),
            isEmulator: any(named: 'isEmulator'),
          ),
        ).thenAnswer((_) async => decodedToken);

        // Always mock HTTP client for getUser calls (needed when emulator is enabled or checkRevoked is true)
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

        final app = createApp(name: 'test-verify-id-token', client: clientMock);
        final testAuth = Auth.internal(app, idTokenVerifier: mockTokenVerifier);

        final result = await testAuth.verifyIdToken('mock-token');

        expect(result.uid, equals('test-uid-123'));
        expect(result.sub, equals('test-uid-123'));
        verify(
          () => mockTokenVerifier.verifyJWT(
            'mock-token',
            isEmulator: any(named: 'isEmulator'),
          ),
        ).called(1);
      });

      test('throws when idToken is empty', () async {
        final mockTokenVerifier = MockFirebaseTokenVerifier();
        when(
          () => mockTokenVerifier.verifyJWT(
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
        final testAuth = Auth.internal(app, idTokenVerifier: mockTokenVerifier);

        await expectLater(
          () => testAuth.verifyIdToken(''),
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
        final mockTokenVerifier = MockFirebaseTokenVerifier();
        when(
          () => mockTokenVerifier.verifyJWT(
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
        final testAuth = Auth.internal(app, idTokenVerifier: mockTokenVerifier);

        await expectLater(
          () => testAuth.verifyIdToken('invalid-token'),
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
        final mockTokenVerifier = MockFirebaseTokenVerifier();
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
          },
        });

        when(
          () => mockTokenVerifier.verifyJWT(
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
        final testAuth = Auth.internal(app, idTokenVerifier: mockTokenVerifier);

        await expectLater(
          () => testAuth.verifyIdToken('mock-token', checkRevoked: true),
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
        final mockTokenVerifier = MockFirebaseTokenVerifier();
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
          },
        });

        when(
          () => mockTokenVerifier.verifyJWT(
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
        final testAuth = Auth.internal(app, idTokenVerifier: mockTokenVerifier);

        await expectLater(
          () => testAuth.verifyIdToken('mock-token', checkRevoked: true),
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
          final mockTokenVerifier = MockFirebaseTokenVerifier();
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
            },
          });

          when(
            () => mockTokenVerifier.verifyJWT(
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
          final testAuth = Auth.internal(
            app,
            idTokenVerifier: mockTokenVerifier,
          );

          final result = await testAuth.verifyIdToken(
            'mock-token',
            checkRevoked: true,
          );

          expect(result.uid, equals('test-uid-123'));
          verify(
            () => mockTokenVerifier.verifyJWT(
              'mock-token',
              isEmulator: any(named: 'isEmulator'),
            ),
          ).called(1);
        },
      );
    });

    group('createSessionCookie', () {
      test('creates session cookie successfully', () async {
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

        final app = createApp(client: clientMock, name: 'test-session-cookie');
        final testAuth = Auth.internal(app);

        final sessionCookie = await testAuth.createSessionCookie(
          'id-token',
          const SessionCookieOptions(
            expiresIn: 3600000,
          ), // 1 hour in milliseconds
        );

        expect(sessionCookie, equals('session-cookie-string'));
        verify(() => clientMock.send(any())).called(1);
      });

      test('throws when idToken is empty', () async {
        expect(
          () => auth.createSessionCookie(
            '',
            const SessionCookieOptions(expiresIn: 3600000),
          ),
          throwsA(isA<FirebaseAuthAdminException>()),
        );
      });

      test('validates expiresIn duration - too short', () async {
        // expiresIn must be between 5 minutes (300000 ms) and 2 weeks (1209600000 ms)
        expect(
          () => auth.createSessionCookie(
            'id-token',
            const SessionCookieOptions(
              expiresIn: 60000,
            ), // 1 minute - too short
          ),
          throwsA(isA<FirebaseAuthAdminException>()),
        );
      });

      test('validates expiresIn duration - too long', () async {
        // expiresIn must not exceed 2 weeks (1209600000 ms)
        expect(
          () => auth.createSessionCookie(
            'id-token',
            const SessionCookieOptions(
              expiresIn: 15 * 24 * 60 * 60 * 1000, // 15 days - too long
            ),
          ),
          throwsA(isA<FirebaseAuthAdminException>()),
        );
      });

      test('validates expiresIn duration - minimum allowed', () async {
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

        final app = createApp(client: clientMock, name: 'test-min-duration');
        final testAuth = Auth.internal(app);

        // 5 minutes (300000 ms) is the minimum allowed
        final sessionCookie = await testAuth.createSessionCookie(
          'id-token',
          const SessionCookieOptions(expiresIn: 5 * 60 * 1000), // 5 minutes
        );

        expect(sessionCookie, equals('session-cookie-string'));
      });

      test('validates expiresIn duration - maximum allowed', () async {
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

        final app = createApp(client: clientMock, name: 'test-max-duration');
        final testAuth = Auth.internal(app);

        // 2 weeks (1209600000 ms) is the maximum allowed
        final sessionCookie = await testAuth.createSessionCookie(
          'id-token',
          const SessionCookieOptions(
            expiresIn: 14 * 24 * 60 * 60 * 1000, // 2 weeks
          ),
        );

        expect(sessionCookie, equals('session-cookie-string'));
      });

      test('handles backend error', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {'code': 400, 'message': 'INVALID_ID_TOKEN'},
                  }),
                ),
              ),
              400,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-backend-error');
        final testAuth = Auth.internal(app);

        await expectLater(
          () => testAuth.createSessionCookie(
            'invalid-id-token',
            const SessionCookieOptions(expiresIn: 3600000),
          ),
          throwsA(isA<FirebaseAuthAdminException>()),
        );
      });
    });

    group('createUser', () {
      test('creates user successfully', () async {
        const testUid = 'test-uid-123';
        final clientMock = MockAuthClient();
        var callCount = 0;
        when(() => clientMock.send(any())).thenAnswer((_) {
          callCount++;
          // First call: signUp (createNewAccount) - returns localId
          if (callCount == 1) {
            return Future.value(
              StreamedResponse(
                Stream.value(utf8.encode(jsonEncode({'localId': testUid}))),
                200,
                headers: {'content-type': 'application/json'},
              ),
            );
          }
          // Second call: lookup (getAccountInfoByUid) - returns user info
          return Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'users': [
                      {
                        'localId': testUid,
                        'email': 'test@example.com',
                        'displayName': 'Test User',
                        'emailVerified': false,
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
          );
        });

        final app = createApp(client: clientMock, name: 'test-create-user');
        final testAuth = Auth.internal(app);

        final user = await testAuth.createUser(
          CreateRequest(email: 'test@example.com', displayName: 'Test User'),
        );

        expect(user.uid, equals(testUid));
        expect(user.email, equals('test@example.com'));
        expect(user.displayName, equals('Test User'));
        expect(user.emailVerified, isFalse);
        expect(user.disabled, isFalse);
        verify(() => clientMock.send(any())).called(2);
      });

      test('throws error when createNewAccount fails', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {'code': 400, 'message': 'EMAIL_ALREADY_EXISTS'},
                  }),
                ),
              ),
              400,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-create-user-error',
        );
        final testAuth = Auth.internal(app);

        await expectLater(
          testAuth.createUser(CreateRequest(email: 'existing@example.com')),
          throwsA(isA<FirebaseAuthAdminException>()),
        );

        verify(() => clientMock.send(any())).called(1);
      });

      test('throws internal error when getUser returns user not found', () async {
        const testUid = 'test-uid-123';
        final clientMock = MockAuthClient();
        var callCount = 0;
        when(() => clientMock.send(any())).thenAnswer((_) {
          callCount++;
          // First call: signUp (createNewAccount) - returns localId
          if (callCount == 1) {
            return Future.value(
              StreamedResponse(
                Stream.value(utf8.encode(jsonEncode({'localId': testUid}))),
                200,
                headers: {'content-type': 'application/json'},
              ),
            );
          }
          // Second call: lookup (getAccountInfoByUid) - returns empty users (user not found)
          return Future.value(
            StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({'users': <dynamic>[]}))),
              200,
              headers: {'content-type': 'application/json'},
            ),
          );
        });

        final app = createApp(
          client: clientMock,
          name: 'test-create-user-not-found',
        );
        final testAuth = Auth.internal(app);

        await expectLater(
          testAuth.createUser(CreateRequest(email: 'test@example.com')),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/internal-error',
            ),
          ),
        );

        verify(() => clientMock.send(any())).called(2);
      });

      test(
        'propagates error when getUser fails with non-user-not-found error',
        () async {
          const testUid = 'test-uid-123';
          final clientMock = MockAuthClient();
          var callCount = 0;
          when(() => clientMock.send(any())).thenAnswer((_) {
            callCount++;
            // First call: signUp (createNewAccount) - returns localId
            if (callCount == 1) {
              return Future.value(
                StreamedResponse(
                  Stream.value(utf8.encode(jsonEncode({'localId': testUid}))),
                  200,
                  headers: {'content-type': 'application/json'},
                ),
              );
            }
            // Second call: lookup (getAccountInfoByUid) - returns error
            return Future.value(
              StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'error': {'code': 500, 'message': 'INTERNAL_ERROR'},
                    }),
                  ),
                ),
                500,
                headers: {'content-type': 'application/json'},
              ),
            );
          });

          final app = createApp(
            client: clientMock,
            name: 'test-create-user-get-error',
          );
          final testAuth = Auth.internal(app);

          await expectLater(
            testAuth.createUser(CreateRequest(email: 'test@example.com')),
            throwsA(isA<FirebaseAuthAdminException>()),
          );

          verify(() => clientMock.send(any())).called(2);
        },
      );
    });

    group('deleteProviderConfig', () {
      test('throws when provider ID is invalid', () async {
        const invalidProviderIds = [
          '',
          'unsupported',
          'oidc.',
          'oidc.provider.',
          'oidc.provider\n',
          'oidc.provider/1',
          r'oidc.provider\1',
          'oidc.provider?k=v',
          'oidc.provider#frag',
          'oidc.provider%2f1',
          'saml.',
          'saml.provider.',
          'saml.provider\n',
          'saml.provider/1',
          r'saml.provider\1',
          'saml.provider?k=v',
          'saml.provider#frag',
          'saml.provider%2f1',
        ];
        for (final providerId in invalidProviderIds) {
          await expectLater(
            () => auth.deleteProviderConfig(providerId),
            throwsA(
              isA<FirebaseAuthAdminException>().having(
                (e) => e.code,
                'code',
                'auth/invalid-provider-id',
              ),
            ),
            reason: providerId,
          );
        }
      });

      test('deletes OIDC provider config successfully', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({}))),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-delete-oidc');
        final testAuth = Auth.internal(app);

        await testAuth.deleteProviderConfig('oidc.provider');

        verify(() => clientMock.send(any())).called(1);
      });

      test('deletes SAML provider config successfully', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({}))),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-delete-saml');
        final testAuth = Auth.internal(app);

        await testAuth.deleteProviderConfig('saml.provider');

        verify(() => clientMock.send(any())).called(1);
      });

      test('throws error when backend returns error for OIDC', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {
                      'code': 404,
                      'message': 'CONFIGURATION_NOT_FOUND',
                    },
                  }),
                ),
              ),
              404,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-delete-oidc-error',
        );
        final testAuth = Auth.internal(app);

        await expectLater(
          testAuth.deleteProviderConfig('oidc.provider'),
          throwsA(isA<FirebaseAuthAdminException>()),
        );

        verify(() => clientMock.send(any())).called(1);
      });

      test('throws error when backend returns error for SAML', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {
                      'code': 404,
                      'message': 'CONFIGURATION_NOT_FOUND',
                    },
                  }),
                ),
              ),
              404,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(
          client: clientMock,
          name: 'test-delete-saml-error',
        );
        final testAuth = Auth.internal(app);

        await expectLater(
          testAuth.deleteProviderConfig('saml.provider'),
          throwsA(isA<FirebaseAuthAdminException>()),
        );

        verify(() => clientMock.send(any())).called(1);
      });
    });

    group('getProviderConfig', () {
      test('throws when provider ID is invalid', () async {
        const invalidProviderIds = [
          '',
          'unsupported',
          'oidc.',
          'oidc.provider.',
          'oidc.provider\n',
          'oidc.provider/1',
          r'oidc.provider\1',
          'oidc.provider?k=v',
          'oidc.provider#frag',
          'oidc.provider%2f1',
          'saml.',
          'saml.provider.',
          'saml.provider\n',
          'saml.provider/1',
          r'saml.provider\1',
          'saml.provider?k=v',
          'saml.provider#frag',
          'saml.provider%2f1',
        ];
        for (final providerId in invalidProviderIds) {
          await expectLater(
            () => auth.getProviderConfig(providerId),
            throwsA(
              isA<FirebaseAuthAdminException>().having(
                (e) => e.code,
                'code',
                'auth/invalid-provider-id',
              ),
            ),
            reason: providerId,
          );
        }
      });

      test('gets OIDC provider config successfully', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'name': 'projects/project_id/oauthIdpConfigs/oidc.provider',
                    'displayName': 'OIDC_DISPLAY_NAME',
                    'enabled': true,
                    'clientId': 'CLIENT_ID',
                    'issuer': 'https://oidc.com/issuer',
                    'clientSecret': 'CLIENT_SECRET',
                  }),
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-get-oidc');
        final testAuth = Auth.internal(app);

        final config = await testAuth.getProviderConfig('oidc.provider');

        expect(config, isA<OIDCAuthProviderConfig>());
        expect(config.providerId, equals('oidc.provider'));
        expect(config.displayName, equals('OIDC_DISPLAY_NAME'));
        expect(config.enabled, isTrue);
        verify(() => clientMock.send(any())).called(1);
      });

      test('gets SAML provider config successfully', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'name':
                        'projects/project_id/inboundSamlConfigs/saml.provider',
                    'idpConfig': {
                      'idpEntityId': 'IDP_ENTITY_ID',
                      'ssoUrl': 'https://example.com/login',
                      'idpCertificates': [
                        {'x509Certificate': 'CERT1'},
                        {'x509Certificate': 'CERT2'},
                      ],
                    },
                    'spConfig': {
                      'spEntityId': 'RP_ENTITY_ID',
                      'callbackUri':
                          'https://project-id.firebaseapp.com/__/auth/handler',
                    },
                    'displayName': 'SAML_DISPLAY_NAME',
                    'enabled': true,
                  }),
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-get-saml');
        final testAuth = Auth.internal(app);

        final config = await testAuth.getProviderConfig('saml.provider');

        expect(config, isA<SAMLAuthProviderConfig>());
        expect(config.providerId, equals('saml.provider'));
        expect(config.displayName, equals('SAML_DISPLAY_NAME'));
        expect(config.enabled, isTrue);
        verify(() => clientMock.send(any())).called(1);
      });

      test('throws error when backend returns error for OIDC', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {
                      'code': 404,
                      'message': 'CONFIGURATION_NOT_FOUND',
                    },
                  }),
                ),
              ),
              404,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-get-oidc-error');
        final testAuth = Auth.internal(app);

        await expectLater(
          testAuth.getProviderConfig('oidc.provider'),
          throwsA(isA<FirebaseAuthAdminException>()),
        );

        verify(() => clientMock.send(any())).called(1);
      });

      test('throws error when backend returns error for SAML', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {
                      'code': 404,
                      'message': 'CONFIGURATION_NOT_FOUND',
                    },
                  }),
                ),
              ),
              404,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-get-saml-error');
        final testAuth = Auth.internal(app);

        await expectLater(
          testAuth.getProviderConfig('saml.provider'),
          throwsA(isA<FirebaseAuthAdminException>()),
        );

        verify(() => clientMock.send(any())).called(1);
      });
    });

    group('createProviderConfig', () {
      test('throws when provider ID is invalid', () async {
        final requestHandler = AuthRequestHandler(auth.app);
        const invalidOidcProviderIds = [
          '',
          'unsupported',
          'oidc.',
          'oidc.provider.',
          'oidc.provider\n',
          'oidc.provider/1',
          r'oidc.provider\1',
          'oidc.provider?k=v',
          'oidc.provider#frag',
          'oidc.provider%2f1',
        ];
        expect(OIDCAuthProviderConfig.isProviderId('oidc.provider'), isTrue);
        for (final providerId in invalidOidcProviderIds) {
          expect(
            OIDCAuthProviderConfig.isProviderId(providerId),
            isFalse,
            reason: providerId,
          );
          final invalidConfig = OIDCAuthProviderConfig(
            providerId: providerId,
            displayName: 'OIDC provider',
            enabled: true,
            clientId: 'CLIENT_ID',
            issuer: 'https://oidc.com/issuer',
          );

          await expectLater(
            auth.createProviderConfig(invalidConfig),
            throwsA(
              isA<FirebaseAuthAdminException>().having(
                (e) => e.code,
                'code',
                'auth/invalid-provider-id',
              ),
            ),
            reason: providerId,
          );
          await expectLater(
            requestHandler.createOAuthIdpConfig(invalidConfig),
            throwsA(
              isA<FirebaseAuthAdminException>().having(
                (e) => e.code,
                'code',
                'auth/invalid-provider-id',
              ),
            ),
            reason: providerId,
          );
        }

        const invalidSamlProviderIds = [
          '',
          'unsupported',
          'saml.',
          'saml.provider.',
          'saml.provider\n',
          'saml.provider/1',
          r'saml.provider\1',
          'saml.provider?k=v',
          'saml.provider#frag',
          'saml.provider%2f1',
        ];
        expect(SAMLAuthProviderConfig.isProviderId('saml.provider'), isTrue);
        for (final providerId in invalidSamlProviderIds) {
          expect(
            SAMLAuthProviderConfig.isProviderId(providerId),
            isFalse,
            reason: providerId,
          );
          final invalidConfig = SAMLAuthProviderConfig(
            providerId: providerId,
            displayName: 'SAML provider',
            enabled: true,
            idpEntityId: 'IDP_ENTITY_ID',
            ssoURL: 'https://example.com/login',
            x509Certificates: ['CERT1'],
            rpEntityId: 'RP_ENTITY_ID',
            callbackURL: 'https://project-id.firebaseapp.com/__/auth/handler',
          );

          await expectLater(
            auth.createProviderConfig(invalidConfig),
            throwsA(
              isA<FirebaseAuthAdminException>().having(
                (e) => e.code,
                'code',
                'auth/invalid-provider-id',
              ),
            ),
            reason: providerId,
          );
          await expectLater(
            requestHandler.createInboundSamlConfig(invalidConfig),
            throwsA(
              isA<FirebaseAuthAdminException>().having(
                (e) => e.code,
                'code',
                'auth/invalid-provider-id',
              ),
            ),
            reason: providerId,
          );
        }
      });

      test('creates OIDC provider config successfully', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'name': 'projects/project_id/oauthIdpConfigs/oidc.provider',
                    'displayName': 'OIDC_DISPLAY_NAME',
                    'enabled': true,
                    'clientId': 'CLIENT_ID',
                    'issuer': 'https://oidc.com/issuer',
                    'clientSecret': 'CLIENT_SECRET',
                  }),
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-create-oidc');
        final testAuth = Auth.internal(app);

        final config = await testAuth.createProviderConfig(
          OIDCAuthProviderConfig(
            providerId: 'oidc.provider',
            displayName: 'OIDC_DISPLAY_NAME',
            enabled: true,
            clientId: 'CLIENT_ID',
            issuer: 'https://oidc.com/issuer',
            clientSecret: 'CLIENT_SECRET',
          ),
        );

        expect(config, isA<OIDCAuthProviderConfig>());
        expect(config.providerId, equals('oidc.provider'));
        expect(config.displayName, equals('OIDC_DISPLAY_NAME'));
        expect(config.enabled, isTrue);
        verify(() => clientMock.send(any())).called(1);
      });

      test('creates SAML provider config successfully', () async {
        final clientMock = MockAuthClient();
        when(() => clientMock.send(any())).thenAnswer(
          (_) => Future.value(
            StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'name':
                        'projects/project_id/inboundSamlConfigs/saml.provider',
                    'idpConfig': {
                      'idpEntityId': 'IDP_ENTITY_ID',
                      'ssoUrl': 'https://example.com/login',
                      'idpCertificates': [
                        {'x509Certificate': 'CERT1'},
                        {'x509Certificate': 'CERT2'},
                      ],
                    },
                    'spConfig': {
                      'spEntityId': 'RP_ENTITY_ID',
                      'callbackUri':
                          'https://project-id.firebaseapp.com/__/auth/handler',
                    },
                    'displayName': 'SAML_DISPLAY_NAME',
                    'enabled': true,
                  }),
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final app = createApp(client: clientMock, name: 'test-create-saml');
        final testAuth = Auth.internal(app);

        final config = await testAuth.createProviderConfig(
          SAMLAuthProviderConfig(
            providerId: 'saml.provider',
            displayName: 'SAML_DISPLAY_NAME',
            enabled: true,
            idpEntityId: 'IDP_ENTITY_ID',
            ssoURL: 'https://example.com/login',
            x509Certificates: ['CERT1', 'CERT2'],
            rpEntityId: 'RP_ENTITY_ID',
            callbackURL: 'https://project-id.firebaseapp.com/__/auth/handler',
          ),
        );

        expect(config, isA<SAMLAuthProviderConfig>());
        expect(config.providerId, equals('saml.provider'));
        expect(config.displayName, equals('SAML_DISPLAY_NAME'));
        expect(config.enabled, isTrue);
        verify(() => clientMock.send(any())).called(1);
      });
    });

    group('verifySessionCookie', () {
      test('verifies session cookie successfully', () async {
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
          },
        });

        when(
          () => mockSessionCookieVerifier.verifyJWT(
            any(),
            isEmulator: any(named: 'isEmulator'),
          ),
        ).thenAnswer((_) async => decodedToken);

        // Always mock HTTP client for getUser calls (needed when emulator is enabled or checkRevoked is true)
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
          name: 'test-verify-session-cookie',
          client: clientMock,
        );
        final testAuth = Auth.internal(
          app,
          sessionCookieVerifier: mockSessionCookieVerifier,
        );

        final result = await testAuth.verifySessionCookie(
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
      });

      test('throws when sessionCookie is empty', () async {
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

        final app = createApp(name: 'test-verify-session-cookie-empty');
        final testAuth = Auth.internal(
          app,
          sessionCookieVerifier: mockSessionCookieVerifier,
        );

        await expectLater(
          () => testAuth.verifySessionCookie(''),
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

        final app = createApp(name: 'test-verify-session-cookie-invalid');
        final testAuth = Auth.internal(
          app,
          sessionCookieVerifier: mockSessionCookieVerifier,
        );

        await expectLater(
          () => testAuth.verifySessionCookie('invalid-cookie'),
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

        final app = createApp(
          client: clientMock,
          name: 'test-verify-session-cookie-disabled',
        );
        final testAuth = Auth.internal(
          app,
          sessionCookieVerifier: mockSessionCookieVerifier,
        );

        await expectLater(
          () => testAuth.verifySessionCookie('mock-cookie', checkRevoked: true),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/user-disabled',
            ),
          ),
        );
      });

      test('throws when checkRevoked is true and cookie is revoked', () async {
        final mockSessionCookieVerifier = MockFirebaseTokenVerifier();
        // Cookie with auth_time before validSince
        final authTime = DateTime.now().subtract(const Duration(hours: 2));
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
          },
        });

        when(
          () => mockSessionCookieVerifier.verifyJWT(
            any(),
            isEmulator: any(named: 'isEmulator'),
          ),
        ).thenAnswer((_) async => decodedToken);

        final clientMock = MockAuthClient();
        // validSince is after auth_time, so cookie is revoked
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
          name: 'test-verify-session-cookie-revoked',
        );
        final testAuth = Auth.internal(
          app,
          sessionCookieVerifier: mockSessionCookieVerifier,
        );

        await expectLater(
          () => testAuth.verifySessionCookie('mock-cookie', checkRevoked: true),
          throwsA(
            isA<FirebaseAuthAdminException>().having(
              (e) => e.code,
              'code',
              'auth/session-cookie-revoked',
            ),
          ),
        );
      });

      test(
        'succeeds when checkRevoked is true and cookie is not revoked',
        () async {
          final mockSessionCookieVerifier = MockFirebaseTokenVerifier();
          // Cookie with auth_time after validSince
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
            name: 'test-verify-session-cookie-not-revoked',
          );
          final testAuth = Auth.internal(
            app,
            sessionCookieVerifier: mockSessionCookieVerifier,
          );

          final result = await testAuth.verifySessionCookie(
            'mock-cookie',
            checkRevoked: true,
          );

          expect(result.uid, equals('test-uid-123'));
          verify(
            () => mockSessionCookieVerifier.verifyJWT(
              'mock-cookie',
              isEmulator: any(named: 'isEmulator'),
            ),
          ).called(1);
        },
      );
    });
  });
}
