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

part of '../auth.dart';

_FirebaseTokenGenerator _createFirebaseTokenGenerator(
  FirebaseApp app, {
  String? tenantId,
}) {
  try {
    return _FirebaseTokenGenerator(app, tenantId: tenantId);
  } on googleapis_auth.ServerRequestFailedException catch (err, stackTrace) {
    Error.throwWithStackTrace(
      FirebaseAuthAdminException(
        AuthClientErrorCode.invalidCredential,
        err.message,
      ),
      stackTrace,
    );
  }
}

abstract class _BaseAuth {
  _BaseAuth({
    required this.app,
    required _AbstractAuthRequestHandler authRequestHandler,
    _FirebaseTokenGenerator? tokenGenerator,
    FirebaseTokenVerifier? idTokenVerifier,
    FirebaseTokenVerifier? sessionCookieVerifier,
  }) : _authRequestHandler = authRequestHandler,
       _tokenGenerator = tokenGenerator ?? _createFirebaseTokenGenerator(app),
       _sessionCookieVerifier =
           sessionCookieVerifier ?? _createSessionCookieVerifier(app),
       _idTokenVerifier = idTokenVerifier ?? _createIdTokenVerifier(app);

  final FirebaseApp app;
  final _AbstractAuthRequestHandler _authRequestHandler;
  final FirebaseTokenVerifier _sessionCookieVerifier;
  final _FirebaseTokenGenerator _tokenGenerator;
  final FirebaseTokenVerifier _idTokenVerifier;

  /// Generates the out of band email action link to reset a user's password.
  /// The link is generated for the user with the specified email address. The
  /// optional [ActionCodeSettings] object
  /// defines whether the link is to be handled by a mobile app or browser and the
  /// additional state information to be passed in the deep link, etc.
  ///

  /// - [email] - The email address of the user whose password is to be
  ///   reset.
  /// - [actionCodeSettings] - The action
  ///     code settings. If specified, the state/continue URL is set as the
  ///     "continueUrl" parameter in the password reset link. The default password
  ///     reset landing page will use this to display a link to go back to the app
  ///     if it is installed.
  ///     If the actionCodeSettings is not specified, no URL is appended to the
  ///     action URL.
  ///     The state URL provided must belong to a domain that is allowed by the
  ///     developer in the console. Otherwise an error is thrown.
  ///     Mobile app redirects are only applicable if the developer configures
  ///     and accepts the Firebase Dynamic Links terms of service.
  ///     The Android package name and iOS bundle ID are respected only if they
  ///     are configured in the same Firebase Auth project.
  Future<String> generatePasswordResetLink(
    String email, {
    ActionCodeSettings? actionCodeSettings,
  }) {
    // TODO(demolaf): see if 'PASSWORD_RESET' needs to be replaced with
    //  _emailActionRequestTypes
    return _authRequestHandler.getEmailActionLink(
      'PASSWORD_RESET',
      email,
      actionCodeSettings,
    );
  }

  /// Generates the out of band email action link to verify the user's ownership
  /// of the specified email. The [ActionCodeSettings] object provided
  /// as an argument to this method defines whether the link is to be handled by a
  /// mobile app or browser along with additional state information to be passed in
  /// the deep link, etc.
  ///
  /// - [email] - The email account to verify.
  /// - [actionCodeSettings] - The action
  ///     code settings. If specified, the state/continue URL is set as the
  ///     "continueUrl" parameter in the email verification link. The default email
  ///     verification landing page will use this to display a link to go back to
  ///     the app if it is installed.
  ///     If the actionCodeSettings is not specified, no URL is appended to the
  ///     action URL.
  ///     The state URL provided must belong to a domain that is allowed by the
  ///     developer in the console. Otherwise an error is thrown.
  ///     Mobile app redirects are only applicable if the developer configures
  ///     and accepts the Firebase Dynamic Links terms of service.
  ///     The Android package name and iOS bundle ID are respected only if they
  ///     are configured in the same Firebase Auth project.
  Future<String> generateEmailVerificationLink(
    String email, {
    ActionCodeSettings? actionCodeSettings,
  }) {
    return _authRequestHandler.getEmailActionLink(
      'VERIFY_EMAIL',
      email,
      actionCodeSettings,
    );
  }

  /// Generates an out-of-band email action link to verify the user's ownership
  /// of the specified email. The [ActionCodeSettings] object provided
  /// as an argument to this method defines whether the link is to be handled by a
  /// mobile app or browser along with additional state information to be passed in
  /// the deep link, etc.
  ///
  /// - [email] - The current email account.
  /// - [newEmail] - The email address the account is being updated to.
  /// - [actionCodeSettings] - The action
  ///     code settings. If specified, the state/continue URL is set as the
  ///     "continueUrl" parameter in the email verification link. The default email
  ///     verification landing page will use this to display a link to go back to
  ///     the app if it is installed.
  ///     If the actionCodeSettings is not specified, no URL is appended to the
  ///     action URL.
  ///     The state URL provided must belong to a domain that is authorized
  ///     in the console, or an error will be thrown.
  ///     Mobile app redirects are only applicable if the developer configures
  ///     and accepts the Firebase Dynamic Links terms of service.
  ///     The Android package name and iOS bundle ID are respected only if they
  ///     are configured in the same Firebase Auth project.
  Future<String> generateVerifyAndChangeEmailLink(
    String email,
    String newEmail, {
    ActionCodeSettings? actionCodeSettings,
  }) {
    return _authRequestHandler.getEmailActionLink(
      'VERIFY_AND_CHANGE_EMAIL',
      email,
      actionCodeSettings,
      newEmail,
    );
  }

  /// Generates the out of band email action link to verify the user's ownership
  /// of the specified email. The [ActionCodeSettings] object provided
  /// as an argument to this method defines whether the link is to be handled by a
  /// mobile app or browser along with additional state information to be passed in
  /// the deep link, etc.
  ///
  /// - [email] - The email account to verify.
  /// - [actionCodeSettings] - The action
  ///     code settings. If specified, the state/continue URL is set as the
  ///     "continueUrl" parameter in the email verification link. The default email
  ///     verification landing page will use this to display a link to go back to
  ///     the app if it is installed.
  ///     If the actionCodeSettings is not specified, no URL is appended to the
  ///     action URL.
  ///     The state URL provided must belong to a domain that is allowed by the
  ///     developer in the console. Otherwise an error is thrown.
  ///     Mobile app redirects are only applicable if the developer configures
  ///     and accepts the Firebase Dynamic Links terms of service.
  ///     The Android package name and iOS bundle ID are respected only if they
  ///     are configured in the same Firebase Auth project.
  Future<String> generateSignInWithEmailLink(
    String email,
    ActionCodeSettings actionCodeSettings,
  ) {
    return _authRequestHandler.getEmailActionLink(
      'EMAIL_SIGNIN',
      email,
      actionCodeSettings,
    );
  }

  /// Returns the list of existing provider configurations matching the filter
  /// provided. At most, 100 provider configs can be listed at a time.
  ///
  /// SAML and OIDC provider support requires Google Cloud's Identity Platform
  /// (GCIP). To learn more about GCIP, including pricing and features,
  /// see the https://cloud.google.com/identity-platform.
  Future<ListProviderConfigResults> listProviderConfigs(
    AuthProviderConfigFilter options,
  ) async {
    if (options._type == _AuthProviderConfigFilterType.oidc) {
      final response = await _authRequestHandler.listOAuthIdpConfigs(
        maxResults: options.maxResults,
        pageToken: options.pageToken,
      );
      return ListProviderConfigResults(
        providerConfigs: [
          // Convert each provider config response to a OIDCConfig.
          ...?response.oauthIdpConfigs?.map(
            OIDCAuthProviderConfig.fromResponse,
          ),
        ],
        pageToken: response.nextPageToken,
      );
    } else if (options._type == _AuthProviderConfigFilterType.saml) {
      final response = await _authRequestHandler.listInboundSamlConfigs(
        maxResults: options.maxResults,
        pageToken: options.pageToken,
      );
      return ListProviderConfigResults(
        providerConfigs: [
          // Convert each provider config response to a SAMLConfig.
          ...?response.inboundSamlConfigs?.map(
            SAMLAuthProviderConfig.fromResponse,
          ),
        ],
        pageToken: response.nextPageToken,
      );
    }

    throw FirebaseAuthAdminException(
      AuthClientErrorCode.invalidArgument,
      '"AuthProviderConfigFilter.type" must be either "saml" or "oidc"',
    );
  }

  /// Returns a [Future] that completes with the newly created [AuthProviderConfig]
  /// when the new provider configuration is created.
  ///
  /// SAML and OIDC provider support requires Google Cloud's Identity Platform
  /// (GCIP). To learn more about GCIP, including pricing and features,
  /// see the https://cloud.google.com/identity-platform.
  Future<AuthProviderConfig> createProviderConfig(
    AuthProviderConfig config,
  ) async {
    if (OIDCAuthProviderConfig.isProviderId(config.providerId)) {
      final response = await _authRequestHandler.createOAuthIdpConfig(
        config as OIDCAuthProviderConfig,
      );
      return OIDCAuthProviderConfig.fromResponse(response);
    } else if (SAMLAuthProviderConfig.isProviderId(config.providerId)) {
      final response = await _authRequestHandler.createInboundSamlConfig(
        config as SAMLAuthProviderConfig,
      );
      return SAMLAuthProviderConfig.fromResponse(response);
    }

    throw FirebaseAuthAdminException(AuthClientErrorCode.invalidProviderId);
  }

  /// Returns a [Future] that completes with the updated [AuthProviderConfig]
  /// corresponding to the provider ID specified.
  /// If the specified ID does not exist, an `auth/configuration-not-found` error
  /// is thrown.
  ///
  /// SAML and OIDC provider support requires Google Cloud's Identity Platform
  /// (GCIP). To learn more about GCIP, including pricing and features,
  /// see the https://cloud.google.com/identity-platform.
  Future<AuthProviderConfig> updateProviderConfig(
    String providerId,
    UpdateAuthProviderRequest updatedConfig,
  ) async {
    if (OIDCAuthProviderConfig.isProviderId(providerId)) {
      final response = await _authRequestHandler.updateOAuthIdpConfig(
        providerId,
        updatedConfig as OIDCUpdateAuthProviderRequest,
      );
      return OIDCAuthProviderConfig.fromResponse(response);
    } else if (SAMLAuthProviderConfig.isProviderId(providerId)) {
      final response = await _authRequestHandler.updateInboundSamlConfig(
        providerId,
        updatedConfig as SAMLUpdateAuthProviderRequest,
      );
      return SAMLAuthProviderConfig.fromResponse(response);
    }

    throw FirebaseAuthAdminException(AuthClientErrorCode.invalidProviderId);
  }

  /// Looks up an Auth provider configuration by the provided ID.
  /// Returns a [Future] that completes with the provider configuration
  /// corresponding to the provider ID specified. If the specified ID does not
  /// exist, an `auth/configuration-not-found` error is thrown.
  ///
  /// SAML and OIDC provider support requires Google Cloud's Identity Platform
  /// (GCIP). To learn more about GCIP, including pricing and features,
  /// see the https://cloud.google.com/identity-platform.
  ///
  /// - [providerId] - The provider ID corresponding to the provider
  ///     config to return.
  Future<AuthProviderConfig> getProviderConfig(String providerId) async {
    if (OIDCAuthProviderConfig.isProviderId(providerId)) {
      final response = await _authRequestHandler.getOAuthIdpConfig(providerId);
      return OIDCAuthProviderConfig.fromResponse(response);
    } else if (SAMLAuthProviderConfig.isProviderId(providerId)) {
      final response = await _authRequestHandler.getInboundSamlConfig(
        providerId,
      );
      return SAMLAuthProviderConfig.fromResponse(response);
    } else {
      throw FirebaseAuthAdminException(AuthClientErrorCode.invalidProviderId);
    }
  }

  /// Deletes the provider configuration corresponding to the provider ID passed.
  /// If the specified ID does not exist, an `auth/configuration-not-found` error
  /// is thrown.
  ///
  /// SAML and OIDC provider support requires Google Cloud's Identity Platform
  /// (GCIP). To learn more about GCIP, including pricing and features,
  /// see the https://cloud.google.com/identity-platform.
  Future<void> deleteProviderConfig(String providerId) {
    if (OIDCAuthProviderConfig.isProviderId(providerId)) {
      return _authRequestHandler.deleteOAuthIdpConfig(providerId);
    } else if (SAMLAuthProviderConfig.isProviderId(providerId)) {
      return _authRequestHandler.deleteInboundSamlConfig(providerId);
    }
    throw FirebaseAuthAdminException(AuthClientErrorCode.invalidProviderId);
  }

  /// Creates a new Firebase custom token (JWT) that can be sent back to a client
  /// device to use to sign in with the client SDKs' `signInWithCustomToken()`
  /// methods. (Tenant-aware instances will also embed the tenant ID in the
  /// token.)
  ///
  /// See https://firebase.google.com/docs/auth/admin/create-custom-tokens
  /// for code samples and detailed documentation.
  Future<String> createCustomToken(
    String uid, {
    Map<String, Object?>? developerClaims,
  }) {
    return _tokenGenerator.createCustomToken(
      uid,
      developerClaims: developerClaims,
    );
  }

  /// Sets additional developer claims on an existing user identified by the
  /// provided `uid`, typically used to define user roles and levels of
  /// access. These claims should propagate to all devices where the user is
  /// already signed in (after token expiration or when token refresh is forced)
  /// and the next time the user signs in. If a reserved OIDC claim name
  /// is used (sub, iat, iss, etc), an error is thrown. They are set on the
  /// authenticated user's ID token JWT.
  ///
  /// See https://firebase.google.com/docs/auth/admin/custom-claims
  /// for code samples and detailed documentation.
  ///
  /// - [uid] - The `uid` of the user to edit.
  /// - [customUserClaims] - The developer claims to set. If null is
  ///   passed, existing custom claims are deleted. Passing a custom claims payload
  ///   larger than 1000 bytes will throw an error. Custom claims are added to the
  ///   user's ID token which is transmitted on every authenticated request.
  ///   For profile non-access related user attributes, use database or other
  ///   separate storage systems.
  Future<void> setCustomUserClaims(
    String uid, {
    Map<String, Object?>? customUserClaims,
  }) async {
    await _authRequestHandler.setCustomUserClaims(uid, customUserClaims);
  }

  /// Verifies a Firebase ID token (JWT). If the token is valid, the returned
  /// [Future] completes with the token's decoded claims; otherwise, it
  /// throws.
  ///
  /// If `checkRevoked` is set to true, first verifies whether the corresponding
  /// user is disabled. If yes, an `auth/user-disabled` error is thrown. If no,
  /// verifies if the session corresponding to the ID token was revoked. If the
  /// corresponding user's session was invalidated, an `auth/id-token-revoked`
  /// error is thrown. If not specified the check is not applied.
  ///
  /// See https://firebase.google.com/docs/auth/admin/verify-id-tokens
  /// for code samples and detailed documentation.
  ///
  /// - [checkRevoked] - Whether to check if the ID token was revoked.
  ///   This requires an extra request to the Firebase Auth backend to check
  ///   the `tokensValidAfterTime` time for the corresponding user.
  ///   When not specified, this additional check is not applied.
  Future<DecodedIdToken> verifyIdToken(
    String idToken, {
    bool checkRevoked = false,
  }) async {
    final isEmulator = Environment.isAuthEmulatorEnabled();
    final decodedIdToken = await _idTokenVerifier.verifyJWT(
      idToken,
      isEmulator: isEmulator,
    );
    // Whether to check if the token was revoked.
    if (checkRevoked || isEmulator) {
      return _verifyDecodedJWTNotRevokedOrDisabled(
        decodedIdToken,
        AuthClientErrorCode.idTokenRevoked,
      );
    }
    return decodedIdToken;
  }

  /// Revokes all refresh tokens for an existing user.
  ///
  /// This API will update the user's [UserRecord.tokensValidAfterTime] to
  /// the current UTC. It is important that the server on which this is called has
  /// its clock set correctly and synchronized.
  ///
  /// While this will revoke all sessions for a specified user and disable any
  /// new ID tokens for existing sessions from getting minted, existing ID tokens
  /// may remain active until their natural expiration (one hour). To verify that
  /// ID tokens are revoked, use [_BaseAuth.verifyIdToken]
  /// where `checkRevoked` is set to true.
  Future<void> revokeRefreshTokens(String uid) async {
    await _authRequestHandler.revokeRefreshTokens(uid);
  }

  /// Creates a new Firebase session cookie with the specified options. The created
  /// JWT string can be set as a server-side session cookie with a custom cookie
  /// policy, and be used for session management. The session cookie JWT will have
  /// the same payload claims as the provided ID token.
  ///
  /// See https://firebase.google.com/docs/auth/admin/manage-cookies
  /// for code samples and detailed documentation.
  ///
  Future<String> createSessionCookie(
    String idToken,
    SessionCookieOptions sessionCookieOptions,
  ) async {
    return _authRequestHandler.createSessionCookie(
      idToken,
      expiresIn: sessionCookieOptions.expiresIn,
    );
  }

  Future<DecodedIdToken> verifySessionCookie(
    String sessionCookie, {
    bool checkRevoked = false,
  }) async {
    final isEmulator = Environment.isAuthEmulatorEnabled();
    final decodedIdToken = await _sessionCookieVerifier.verifyJWT(
      sessionCookie,
      isEmulator: isEmulator,
    );

    if (checkRevoked || isEmulator) {
      return _verifyDecodedJWTNotRevokedOrDisabled(
        decodedIdToken,
        AuthClientErrorCode.sessionCookieRevoked,
      );
    }

    return decodedIdToken;
  }

  Future<DecodedIdToken> _verifyDecodedJWTNotRevokedOrDisabled(
    DecodedIdToken decodedIdToken,
    AuthClientErrorCode revocationErrorInfo,
  ) async {
    final user = await getUser(decodedIdToken.sub);
    if (user.disabled) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.userDisabled,
        'The user record is disabled.',
      );
    }

    if (user.tokensValidAfterTime case final tokensValidAfterTime?) {
      // Check if authentication time is older than valid since time.
      if (decodedIdToken.authTime.isBefore(tokensValidAfterTime)) {
        throw FirebaseAuthAdminException(revocationErrorInfo);
      }
    }
    // All checks above passed. Return the decoded token.
    return decodedIdToken;
  }

  /// Imports the provided list of users into Firebase Auth.
  /// A maximum of 1000 users are allowed to be imported one at a time.
  /// When importing users with passwords,
  /// [UserImportOptions] are required to be
  /// specified.
  /// This operation is optimized for bulk imports and will ignore checks on `uid`,
  /// `email` and other identifier uniqueness which could result in duplications.
  ///
  /// - users - The list of user records to import to Firebase Auth.
  /// - options - The user import options, required when the users provided include
  ///   password credentials.
  ///
  /// Returns a Future that resolves when
  /// the operation completes with the result of the import. This includes the
  /// number of successful imports, the number of failed imports and their
  /// corresponding errors.
  Future<UserImportResult> importUsers(
    List<UserImportRecord> users, [
    UserImportOptions? options,
  ]) async {
    return _authRequestHandler.uploadAccount(users, options);
  }

  /// Retrieves a list of users (single batch only) with a size of `maxResults`
  /// starting from the offset as specified by `pageToken`. This is used to
  /// retrieve all the users of a specified project in batches.
  ///
  /// See https://firebase.google.com/docs/auth/admin/manage-users#list_all_users
  /// for code samples and detailed documentation.
  ///
  /// - maxResults - The page size, 1000 if not specified. This is also
  ///   the maximum allowed limit.
  /// - pageToken - The next page token. If not specified, returns
  ///   users starting without any offset.
  ///
  /// Returns a [Future] that completes with
  /// the current batch of downloaded users and the next page token.
  Future<ListUsersResult> listUsers({
    int? maxResults,
    String? pageToken,
  }) async {
    final response = await _authRequestHandler.downloadAccount(
      maxResults: maxResults,
      pageToken: pageToken,
    );

    final users =
        response.users?.map(UserRecord.fromResponse).toList() ?? <UserRecord>[];

    return ListUsersResult._(users: users, pageToken: response.nextPageToken);
  }

  /// Deletes an existing user.
  ///
  /// See https://firebase.google.com/docs/auth/admin/manage-users#delete_a_user
  /// for code samples and detailed documentation.
  ///
  /// Returns a [Future] that completes once the user has been
  /// deleted.
  Future<void> deleteUser(String uid) async {
    await _authRequestHandler.deleteAccount(uid);
  }

  /// Deletes the users specified by the given uids.
  ///
  /// Deleting a non-existing user won't generate an error (i.e. this method
  /// is idempotent.) Non-existing users are considered to be successfully
  /// deleted, and are therefore counted in the
  /// `DeleteUsersResult.successCount` value.
  ///
  /// Only a maximum of 1000 identifiers may be supplied. If more than 1000
  /// identifiers are supplied, this method throws a FirebaseAuthError.
  ///
  /// This API is currently rate limited at the server to 1 QPS. If you exceed
  /// this, you may get a quota exceeded error. Therefore, if you want to
  /// delete more than 1000 users, you may need to add a delay to ensure you
  /// don't go over this limit.
  ///
  /// Returns a Futrue that resolves to the total number of successful/failed
  /// deletions, as well as the array of errors that corresponds to the
  /// failed deletions.
  Future<DeleteUsersResult> deleteUsers(List<String> uids) async {
    uids.forEach(assertIsUid);

    final response = await _authRequestHandler.deleteAccounts(
      uids,
      force: true,
    );
    final errors =
        response.errors ??
        <auth1.GoogleCloudIdentitytoolkitV1BatchDeleteErrorInfo>[];

    return DeleteUsersResult._(
      successCount: uids.length - errors.length,
      failureCount: errors.length,
      errors: errors.map((batchDeleteErrorInfo) {
        final index = batchDeleteErrorInfo.index;
        if (index == null) {
          throw FirebaseAuthAdminException(
            AuthClientErrorCode.internalError,
            'Corrupt BatchDeleteAccountsResponse detected',
          );
        }

        FirebaseAuthAdminException errMsgToError(String? msg) {
          // We unconditionally set force=true, so the 'NOT_DISABLED' error
          // should not be possible.
          final code = msg != null && msg.startsWith('NOT_DISABLED')
              ? AuthClientErrorCode.userNotDisabled
              : AuthClientErrorCode.internalError;

          return FirebaseAuthAdminException(code, batchDeleteErrorInfo.message);
        }

        return FirebaseArrayIndexError(
          index: index,
          error: errMsgToError(batchDeleteErrorInfo.message),
        );
      }).toList(),
    );
  }

  /// Gets the user data for the user corresponding to a given `uid`.
  ///
  /// See https://firebase.google.com/docs/auth/admin/manage-users#retrieve_user_data
  /// for code samples and detailed documentation.
  ///
  /// Returns a Future fulfilled with the use data corresponding to the provided `uid`.
  Future<UserRecord> getUser(String uid) async {
    final response = await _authRequestHandler.getAccountInfoByUid(uid);
    // Returns the user record populated with server response.
    return UserRecord.fromResponse(response);
  }

  /// Gets the user data for the user corresponding to a given phone number. The
  /// phone number has to conform to the E.164 specification.
  ///
  /// See https://firebase.google.com/docs/auth/admin/manage-users#retrieve_user_data
  /// for code samples and detailed documentation.
  ///
  /// Takes the phone number corresponding to the user whose
  /// data to fetch.
  ///
  /// Returns a Future fulfilled with the user
  /// data corresponding to the provided phone number.
  Future<UserRecord> getUserByPhoneNumber(String phoneNumber) async {
    final response = await _authRequestHandler.getAccountInfoByPhoneNumber(
      phoneNumber,
    );
    // Returns the user record populated with server response.
    return UserRecord.fromResponse(response);
  }

  /// Gets the user data for the user corresponding to a given email.
  ///
  /// See https://firebase.google.com/docs/auth/admin/manage-users#retrieve_user_data
  /// for code samples and detailed documentation.
  ///
  /// Receives the email corresponding to the user whose data to fetch.
  ///
  /// Returns a [Future] that completes with the user
  /// data corresponding to the provided email.
  Future<UserRecord> getUserByEmail(String email) async {
    final response = await _authRequestHandler.getAccountInfoByEmail(email);
    // Returns the user record populated with server response.
    return UserRecord.fromResponse(response);
  }

  /// Gets the user data for the user corresponding to a given provider id.
  ///
  /// See https://firebase.google.com/docs/auth/admin/manage-users#retrieve_user_data
  /// for code samples and detailed documentation.
  ///
  /// - `providerId`: The provider ID, for example, "google.com" for the
  ///   Google provider.
  /// - `uid`: The user identifier for the given provider.
  ///
  /// Returns a Future fulfilled with the user data corresponding to the
  /// given provider id.
  Future<UserRecord> getUserByProviderUid({
    required String providerId,
    required String uid,
  }) async {
    // Although we don't really advertise it, we want to also handle
    // non-federated idps with this call. So if we detect one of them, we'll
    // reroute this request appropriately.
    if (providerId == 'phone') {
      return getUserByPhoneNumber(uid);
    } else if (providerId == 'email') {
      return getUserByEmail(uid);
    }

    final response = await _authRequestHandler.getAccountInfoByFederatedUid(
      providerId: providerId,
      rawId: uid,
    );

    // Returns the user record populated with server response.
    return UserRecord.fromResponse(response);
  }

  /// Gets the user data corresponding to the specified identifiers.
  ///
  /// There are no ordering guarantees; in particular, the nth entry in the result list is not
  /// guaranteed to correspond to the nth entry in the input parameters list.
  ///
  /// Only a maximum of 100 identifiers may be supplied. If more than 100 identifiers are supplied,
  /// this method throws a FirebaseAuthError.
  ///
  /// Takes a list of [UserIdentifier] used to indicate which user records should be returned.
  /// Must not have more than 100 entries.
  ///
  /// Returns a Future that resolves to the corresponding user records.
  /// Throws [FirebaseAdminException] if any of the identifiers are invalid or if more than 100
  ///  identifiers are specified.
  Future<GetUsersResult> getUsers(List<UserIdentifier> identifiers) async {
    final response = await _authRequestHandler.getAccountInfoByIdentifiers(
      identifiers,
    );

    final userRecords =
        response.users?.map(UserRecord.fromResponse).toList() ??
        const <UserRecord>[];

    // Checks if the specified identifier is within the list of UserRecords.
    bool isUserFound(UserIdentifier id) {
      return userRecords.any((userRecord) {
        switch (id) {
          case UidIdentifier():
            return id.uid == userRecord.uid;
          case EmailIdentifier():
            return id.email == userRecord.email;
          case PhoneIdentifier():
            return id.phoneNumber == userRecord.phoneNumber;
          case ProviderIdentifier():
            final matchingUserInfo = userRecord.providerData.firstWhereOrNull(
              (userInfo) => userInfo.phoneNumber != null,
            );
            return matchingUserInfo != null &&
                id.providerUid == matchingUserInfo.uid;
        }
      });
    }

    final notFound = identifiers.where((id) => !isUserFound(id)).toList();

    return GetUsersResult._(users: userRecords, notFound: notFound);
  }

  /// Creates a new user.
  ///
  /// See https://firebase.google.com/docs/auth/admin/manage-users#create_a_user
  /// for code samples and detailed documentation.
  ///
  /// Returns A Future fulfilled with the user
  /// data corresponding to the newly created user.
  Future<UserRecord> createUser(CreateRequest properties) async {
    return _authRequestHandler
        .createNewAccount(properties)
        // Return the corresponding user record.
        .then(getUser)
        .onError<FirebaseAuthAdminException>((error, _) {
          if (error.errorCode == AuthClientErrorCode.userNotFound) {
            // Something must have happened after creating the user and then retrieving it.
            throw FirebaseAuthAdminException(
              AuthClientErrorCode.internalError,
              'Unable to create the user record provided.',
            );
          }
          throw error;
        });
  }

  /// Updates an existing user.
  ///
  /// See https://firebase.google.com/docs/auth/admin/manage-users#update_a_user
  /// for code samples and detailed documentation.
  ///
  /// - uid - The `uid` corresponding to the user to update.
  /// - properties - The properties to update on the provided user.
  ///
  /// Returns a [Future] fulfilled with the updated user data.
  Future<UserRecord> updateUser(String uid, UpdateRequest properties) async {
    // Although we don't really advertise it, we want to also handle linking of
    // non-federated idps with this call. So if we detect one of them, we'll
    // adjust the properties parameter appropriately. This *does* imply that a
    // conflict could arise, e.g. if the user provides a phoneNumber property,
    // but also provides a providerToLink with a 'phone' provider id. In that
    // case, we'll throw an error.
    // A provider without a uid is left for updateExistingAccount to reject:
    // moving it would send phoneNumber: null, which deletes the phone number.
    var request = properties;
    final providerToLink = properties.providerToLink;
    switch (providerToLink) {
      case UserProvider(providerId: 'email', :final uid?) when uid.isNotEmpty:
        if (properties.email != null) {
          throw FirebaseAuthAdminException(
            AuthClientErrorCode.invalidArgument,
            "Both UpdateRequest.email and UpdateRequest.providerToLink.providerId='email' were set. To "
            'link to the email/password provider, only specify the UpdateRequest.email field.',
          );
        }
        request = properties._copyWith(email: uid, keepProviderToLink: false);
      case UserProvider(providerId: 'phone', :final uid?) when uid.isNotEmpty:
        if (properties.phoneNumber != null) {
          throw FirebaseAuthAdminException(
            AuthClientErrorCode.invalidArgument,
            "Both UpdateRequest.phoneNumber and UpdateRequest.providerToLink.providerId='phone' were set. To "
            'link to a phone provider, only specify the UpdateRequest.phoneNumber field.',
          );
        }
        request = properties._copyWith(
          phoneNumber: uid,
          keepProviderToLink: false,
        );
    }
    final providersToUnlink = properties.providersToUnlink;
    if (providersToUnlink != null && providersToUnlink.contains('phone')) {
      // If we've been told to unlink the phone provider both via setting
      // phoneNumber to null *and* by setting providersToUnlink to include
      // 'phone', then we'll reject that. Though it might also be reasonable
      // to relax this restriction and just unlink it.
      if (properties.phoneNumber case _Box(value: null)) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.invalidArgument,
          "Both UpdateRequest.phoneNumber and UpdateRequest.providersToUnlink=['phone'] were set. To "
          'unlink the phone provider, only specify the UpdateRequest.providersToUnlink field.',
        );
      }
    }

    final existingUid = await _authRequestHandler.updateExistingAccount(
      uid,
      request,
    );
    return getUser(existingUid);
  }
}

/// Interface representing the object returned from a
/// [_BaseAuth.listUsers] operation. Contains the list
/// of users for the current batch and the next page token if available.
class ListUsersResult {
  ListUsersResult._({required this.users, required this.pageToken});

  /// The list of [UserRecord] objects for the
  /// current downloaded batch.
  final List<UserRecord> users;

  /// The next page token if available. This is needed for the next batch download.
  final String? pageToken;
}

/// Represents the result of the [_BaseAuth.getUsers] API.
class GetUsersResult {
  GetUsersResult._({required this.users, required this.notFound});

  /// Set of user records, corresponding to the set of users that were
  /// requested. Only users that were found are listed here. The result set is
  /// unordered.
  final List<UserRecord> users;

  /// Set of identifiers that were requested, but not found.
  final List<UserIdentifier> notFound;
}

/// Represents the result of the [_BaseAuth.deleteUsers].
/// API.
class DeleteUsersResult {
  DeleteUsersResult._({
    required this.failureCount,
    required this.successCount,
    required this.errors,
  });

  /// The number of user records that failed to be deleted (possibly zero).
  final int failureCount;

  /// The number of users that were deleted successfully (possibly zero).
  /// Users that did not exist prior to calling `deleteUsers()` are
  /// considered to be successfully deleted.
  final int successCount;

  /// A list of `FirebaseArrayIndexError` instances describing the errors that
  /// were encountered during the deletion. Length of this list is equal to
  /// the return value of [DeleteUsersResult.failureCount].
  final List<FirebaseArrayIndexError> errors;
}

/// Interface representing the response from the
/// [_BaseAuth.importUsers] method for batch
/// importing users to Firebase Auth.
class UserImportResult {
  @internal
  UserImportResult({
    required this.failureCount,
    required this.successCount,
    required this.errors,
  });

  /// The number of user records that failed to import to Firebase Auth.
  final int failureCount;

  /// The number of user records that successfully imported to Firebase Auth.
  final int successCount;

  /// An array of errors corresponding to the provided users to import. The
  /// length of this array is equal to [failureCount].
  final List<FirebaseArrayIndexError> errors;
}

/// Interface representing the session cookie options needed for the
/// [_BaseAuth.createSessionCookie] method.
class SessionCookieOptions {
  /// Creates a new [SessionCookieOptions] with the specified expiration time.
  ///
  /// The [expiresIn] is the session cookie custom expiration in milliseconds.
  /// The minimum allowed is 5 minutes (300000 ms) and the maximum allowed is 2 weeks (1209600000 ms).
  const SessionCookieOptions({required this.expiresIn});

  /// The session cookie custom expiration in milliseconds.
  ///
  /// The minimum allowed is 5 minutes (300000 ms) and the maximum allowed is 2 weeks (1209600000 ms).
  final int expiresIn;
}
