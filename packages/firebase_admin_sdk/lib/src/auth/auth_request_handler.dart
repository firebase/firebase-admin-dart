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

/// Maximum allowed number of provider configurations to batch download at one time.
const _maxListProviderConfigurationPageSize = 100;

/// Maximum allowed number of users to batch get at one time.
const _maxGetAccountsBatchSize = 100;

/// Maximum allowed number of users to batch download at one time.
const _maxDownloadAccountPageSize = 1000;

/// Maximum allowed number of users to batch delete at one time.
const _maxDeleteAccountsBatchSize = 1000;

/// Maximum allowed number of users to batch upload at one time.
const _maxUploadAccountBatchSize = 1000;

/// Minimum allowed session cookie duration in seconds (5 minutes).
const _minSessionCookieDurationSecs = 5 * 60;

/// Maximum allowed session cookie duration in seconds (2 weeks).
const _maxSessionCookieDurationSecs = 14 * 24 * 60 * 60;

// TODO(demolaf): this could be an enum instead.
/// List of supported email action request types.
const _emailActionRequestTypes = {
  'PASSWORD_RESET',
  'VERIFY_EMAIL',
  'EMAIL_SIGNIN',
  'VERIFY_AND_CHANGE_EMAIL',
};

abstract class _AbstractAuthRequestHandler {
  _AbstractAuthRequestHandler(this.app, {@internal AuthHttpClient? httpClient})
    : _httpClient = httpClient ?? AuthHttpClient(app);

  final FirebaseApp app;
  final AuthHttpClient _httpClient;

  AuthHttpClient get httpClient => _httpClient;

  /// Generates the out of band email action link for the email specified using the action code settings provided.
  /// Returns a [Future] that completes with the generated link.
  Future<String> getEmailActionLink(
    String requestType,
    String email,
    ActionCodeSettings? actionCodeSettings, [
    String? newEmail,
  ]) async {
    assertIsEmail(email);

    if (requestType == 'VERIFY_AND_CHANGE_EMAIL') {
      if (newEmail == null || newEmail.isEmpty) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.invalidArgument,
          "`newEmail` is required when `requestType` === 'VERIFY_AND_CHANGE_EMAIL'",
        );
      }
      assertIsEmail(newEmail);
    }

    final request = auth1.GoogleCloudIdentitytoolkitV1GetOobCodeRequest(
      requestType: requestType,
      email: email,
      returnOobLink: true,
      newEmail: newEmail,
    );

    // ActionCodeSettings required for email link sign-in to determine the url where the sign-in will
    // be completed.
    // TODO(demolaf): find and replace anywhere _emailActionRequestTypes
    //  are hardcoded like the one below i.e. requestType == 'EMAIL_SIGNIN'
    if (actionCodeSettings == null && requestType == 'EMAIL_SIGNIN') {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.invalidArgument,
        "`actionCodeSettings` is required when `requestType` === 'EMAIL_SIGNIN'",
      );
    }

    if (actionCodeSettings != null || requestType == 'EMAIL_SIGNIN') {
      final builder = _ActionCodeSettingsBuilder(actionCodeSettings!);
      builder.buildRequest(request);
    }

    final response = await _httpClient.getOobCode(request);
    return response.oobLink!;
  }

  /// Lists the OIDC configurations (single batch only) with a size of maxResults and starting from
  /// the offset as specified by pageToken.
  Future<auth2.GoogleCloudIdentitytoolkitAdminV2ListOAuthIdpConfigsResponse>
  listOAuthIdpConfigs({int? maxResults, String? pageToken}) async {
    final response = await _httpClient.listOAuthIdpConfigs(
      pageSize: maxResults ?? _maxListProviderConfigurationPageSize,
      pageToken: pageToken,
    );
    if (response.oauthIdpConfigs == null) {
      response.oauthIdpConfigs = [];
      response.nextPageToken = null;
    }
    return response;
  }

  /// Lists the SAML configurations (single batch only) with a size of maxResults and starting from
  /// the offset as specified by pageToken.
  Future<auth2.GoogleCloudIdentitytoolkitAdminV2ListInboundSamlConfigsResponse>
  listInboundSamlConfigs({int? maxResults, String? pageToken}) async {
    final response = await _httpClient.listInboundSamlConfigs(
      pageSize: maxResults ?? _maxListProviderConfigurationPageSize,
      pageToken: pageToken,
    );
    if (response.inboundSamlConfigs == null) {
      response.inboundSamlConfigs = [];
      response.nextPageToken = null;
    }
    return response;
  }

  /// Creates a new OIDC provider configuration with the properties provided.
  Future<auth2.GoogleCloudIdentitytoolkitAdminV2OAuthIdpConfig>
  createOAuthIdpConfig(OIDCAuthProviderConfig options) async {
    final request =
        OIDCAuthProviderConfig._buildServerRequest(options) ??
        auth2.GoogleCloudIdentitytoolkitAdminV2OAuthIdpConfig();

    final response = await _httpClient.createOAuthIdpConfig(
      request,
      options.providerId,
    );

    final name = response.name;
    if (name == null ||
        OIDCAuthProviderConfig.getProviderIdFromResourceName(name) == null) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.internalError,
        'INTERNAL ASSERT FAILED: Unable to create OIDC configuration',
      );
    }

    return response;
  }

  /// Creates a new SAML provider configuration with the properties provided.
  Future<auth2.GoogleCloudIdentitytoolkitAdminV2InboundSamlConfig>
  createInboundSamlConfig(SAMLAuthProviderConfig options) async {
    final request =
        SAMLAuthProviderConfig._buildServerRequest(options) ??
        auth2.GoogleCloudIdentitytoolkitAdminV2InboundSamlConfig();

    final response = await _httpClient.createInboundSamlConfig(
      request,
      options.providerId,
    );

    final name = response.name;
    if (name == null ||
        SAMLAuthProviderConfig.getProviderIdFromResourceName(name) == null) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.internalError,
        'INTERNAL ASSERT FAILED: Unable to create SAML configuration',
      );
    }

    return response;
  }

  /// Sets additional developer claims on an existing user identified by provided UID.
  Future<String> setCustomUserClaims(
    String uid,
    Map<String, Object?>? customUserClaims,
  ) async {
    if (!isUid(uid)) {
      throw FirebaseAuthAdminException(AuthClientErrorCode.invalidUid);
    }

    final claims = customUserClaims ?? <String, Object?>{};

    final request = auth1.GoogleCloudIdentitytoolkitV1SetAccountInfoRequest(
      localId: uid,
      customAttributes: jsonEncode(claims),
    );

    final response = await _httpClient.setAccountInfo(request);
    return response.localId!;
  }

  /// Revokes all refresh tokens for the specified user identified by the uid provided.
  /// In addition to revoking all refresh tokens for a user, all ID tokens issued
  /// before revocation will also be revoked on the Auth backend. Any request with an
  /// ID token generated before revocation will be rejected with a token expired error.
  /// Note that due to the fact that the timestamp is stored in seconds, any tokens minted in
  /// the same second as the revocation will still be valid. If there is a chance that a token
  /// was minted in the last second, delay for 1 second before revoking.
  Future<String> revokeRefreshTokens(String uid) async {
    // Validate user UID.
    if (!isUid(uid)) {
      throw FirebaseAuthAdminException(AuthClientErrorCode.invalidUid);
    }

    final request = auth1.GoogleCloudIdentitytoolkitV1SetAccountInfoRequest(
      localId: uid,
      // validSince is in UTC seconds.
      validSince: (DateTime.now().millisecondsSinceEpoch / 1000)
          .floor()
          .toString(),
    );

    final response = await _httpClient.setAccountInfo(request);
    return response.localId!;
  }

  /// Updates an existing OIDC provider configuration with the properties provided.
  Future<auth2.GoogleCloudIdentitytoolkitAdminV2OAuthIdpConfig>
  updateOAuthIdpConfig(
    String providerId,
    OIDCUpdateAuthProviderRequest options,
  ) async {
    if (!OIDCAuthProviderConfig.isProviderId(providerId)) {
      throw FirebaseAuthAdminException(AuthClientErrorCode.invalidProviderId);
    }

    final request = OIDCAuthProviderConfig._buildServerRequest(
      options,
      ignoreMissingFields: true,
    );
    final updateMask = generateUpdateMask(request?.toJson());

    final response = await _httpClient.updateOAuthIdpConfig(
      request ?? auth2.GoogleCloudIdentitytoolkitAdminV2OAuthIdpConfig(),
      providerId,
      updateMask: updateMask.join(','),
    );

    final name = response.name;
    if (name == null ||
        OIDCAuthProviderConfig.getProviderIdFromResourceName(name) == null) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.internalError,
        'INTERNAL ASSERT FAILED: Unable to update OIDC configuration',
      );
    }

    return response;
  }

  /// Updates an existing SAML provider configuration with the properties provided.
  Future<auth2.GoogleCloudIdentitytoolkitAdminV2InboundSamlConfig>
  updateInboundSamlConfig(
    String providerId,
    SAMLUpdateAuthProviderRequest options,
  ) async {
    if (!SAMLAuthProviderConfig.isProviderId(providerId)) {
      throw FirebaseAuthAdminException(AuthClientErrorCode.invalidProviderId);
    }

    final request = SAMLAuthProviderConfig._buildServerRequest(
      options,
      ignoreMissingFields: true,
    );
    final updateMask = generateUpdateMask(request?.toJson());
    final response = await _httpClient.updateInboundSamlConfig(
      request ?? auth2.GoogleCloudIdentitytoolkitAdminV2InboundSamlConfig(),
      providerId,
      updateMask: updateMask.join(','),
    );

    final name = response.name;
    if (name == null ||
        SAMLAuthProviderConfig.getProviderIdFromResourceName(name) == null) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.internalError,
        'INTERNAL ASSERT FAILED: Unable to update SAML provider configuration',
      );
    }
    return response;
  }

  /// Looks up an OIDC provider configuration by provider ID.
  Future<auth2.GoogleCloudIdentitytoolkitAdminV2OAuthIdpConfig>
  getOAuthIdpConfig(String providerId) {
    if (!OIDCAuthProviderConfig.isProviderId(providerId)) {
      throw FirebaseAuthAdminException(AuthClientErrorCode.invalidProviderId);
    }

    return _httpClient.getOauthIdpConfig(providerId);
  }

  Future<auth2.GoogleCloudIdentitytoolkitAdminV2InboundSamlConfig>
  getInboundSamlConfig(String providerId) {
    if (!SAMLAuthProviderConfig.isProviderId(providerId)) {
      throw FirebaseAuthAdminException(AuthClientErrorCode.invalidProviderId);
    }

    return _httpClient.getInboundSamlConfig(providerId);
  }

  /// Deletes an OIDC configuration identified by a providerId.
  Future<void> deleteOAuthIdpConfig(String providerId) {
    if (!OIDCAuthProviderConfig.isProviderId(providerId)) {
      throw FirebaseAuthAdminException(AuthClientErrorCode.invalidProviderId);
    }

    return _httpClient.deleteOauthIdpConfig(providerId);
  }

  /// Deletes a SAML configuration identified by a providerId.
  Future<void> deleteInboundSamlConfig(String providerId) {
    if (!SAMLAuthProviderConfig.isProviderId(providerId)) {
      throw FirebaseAuthAdminException(AuthClientErrorCode.invalidProviderId);
    }

    return _httpClient.deleteInboundSamlConfig(providerId);
  }

  /// Creates a new Firebase session cookie with the specified duration that can be used for
  /// session management (set as a server side session cookie with custom cookie policy).
  /// The session cookie JWT will have the same payload claims as the provided ID token.
  Future<String> createSessionCookie(String idToken, {required int expiresIn}) {
    if (idToken.isEmpty) {
      throw FirebaseAuthAdminException(AuthClientErrorCode.invalidIdToken);
    }

    // Convert to seconds (use integer division to avoid decimal).
    final validDuration = expiresIn ~/ 1000;

    if (validDuration < _minSessionCookieDurationSecs ||
        validDuration > _maxSessionCookieDurationSecs) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.invalidSessionCookieDuration,
      );
    }

    final request =
        auth1.GoogleCloudIdentitytoolkitV1CreateSessionCookieRequest(
          idToken: idToken,
          validDuration: validDuration.toString(),
        );

    return _httpClient.v1((api, projectId) async {
      final response = await api.projects.createSessionCookie(
        request,
        projectId,
      );

      final sessionCookie = response.sessionCookie;
      if (sessionCookie == null || sessionCookie.isEmpty) {
        throw FirebaseAuthAdminException(AuthClientErrorCode.internalError);
      }

      return response.sessionCookie!;
    });
  }

  /// Imports the list of users provided to Firebase Auth. This is useful when
  /// migrating from an external authentication system without having to use the Firebase CLI SDK.
  /// At most, 1000 users are allowed to be imported one at a time.
  /// When importing a list of password users, UserImportOptions are required to be specified.
  ///
  /// - users - The list of user records to import to Firebase Auth.
  /// - options - The user import options, required when the users provided
  ///     include password credentials.
  ///
  /// Returns a Future that resolves when the operation completes
  /// with the result of the import. This includes the number of successful imports, the number
  /// of failed uploads and their corresponding errors.
  Future<UserImportResult> uploadAccount(
    List<UserImportRecord> users,
    UserImportOptions? options,
  ) async {
    // This will throw if any error is detected in the hash options.
    // For errors in the list of users, this will not throw and will report the errors and the
    // corresponding user index in the user import generated response below.
    // No need to validate raw request or raw response as this is done in UserImportBuilder.
    final userImportBuilder = _UserImportBuilder(
      users: users,
      options: options,
      userRequestValidator: (userRequest) {
        // Pass true to validate the uploadAccount specific fields.
        // TODO validateCreateEditRequest
      },
    );

    final request = userImportBuilder.buildRequest();
    final requestUsers = request.users;
    // Fail quickly if more users than allowed are to be imported.
    if (requestUsers != null &&
        requestUsers.length > _maxUploadAccountBatchSize) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.maximumUserCountExceeded,
        'A maximum of $_maxUploadAccountBatchSize users can be imported at once.',
      );
    }
    // If no remaining user in request after client side processing, there is no need
    // to send the request to the server.
    if (requestUsers == null || requestUsers.isEmpty) {
      return userImportBuilder.buildResponse([]);
    }

    return _httpClient.v1((api, projectId) async {
      final response = await api.projects.accounts_1.batchCreate(
        request,
        projectId,
      );
      // No error object is returned if no error encountered.
      // Rewrite response as UserImportResult and re-insert client previously detected errors.
      return userImportBuilder.buildResponse(response.error ?? const []);
    });
  }

  /// Exports the users (single batch only) with a size of maxResults and starting from
  /// the offset as specified by pageToken.
  ///
  /// maxResults - The page size, 1000 if not specified. This is also the maximum
  /// allowed limit.
  ///
  /// pageToken - The next page token. If not specified, returns users starting
  /// without any offset. Users are returned in the order they were created from oldest to
  /// newest, relative to the page token offset.
  ///
  /// Returns a Future that resolves with the current batch of downloaded
  /// users and the next page token if available. For the last page, an empty list of users
  /// and no page token are returned.
  Future<auth1.GoogleCloudIdentitytoolkitV1DownloadAccountResponse>
  downloadAccount({required int? maxResults, required String? pageToken}) {
    maxResults ??= _maxDownloadAccountPageSize;
    if (pageToken != null && pageToken.isEmpty) {
      throw FirebaseAuthAdminException(AuthClientErrorCode.invalidPageToken);
    }
    if (maxResults <= 0 || maxResults > _maxDownloadAccountPageSize) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.invalidArgument,
        'Required "maxResults" must be a positive integer that does not exceed '
        '$_maxDownloadAccountPageSize.',
      );
    }

    return _httpClient.v1((api, projectId) async {
      return api.projects.accounts_1.batchGet(
        projectId,
        maxResults: maxResults,
        nextPageToken: pageToken,
      );
    });
  }

  /// Deletes an account identified by a uid.
  Future<auth1.GoogleCloudIdentitytoolkitV1DeleteAccountResponse> deleteAccount(
    String uid,
  ) async {
    assertIsUid(uid);

    return _httpClient.v1((api, projectId) async {
      return api.projects.accounts_1.delete(
        auth1.GoogleCloudIdentitytoolkitV1DeleteAccountRequest(localId: uid),
        projectId,
      );
    });
  }

  Future<auth1.GoogleCloudIdentitytoolkitV1BatchDeleteAccountsResponse>
  deleteAccounts(List<String> uids, {required bool force}) async {
    if (uids.isEmpty) {
      return auth1.GoogleCloudIdentitytoolkitV1BatchDeleteAccountsResponse();
    } else if (uids.length > _maxDeleteAccountsBatchSize) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.maximumUserCountExceeded,
        '`uids` parameter must have <= $_maxDeleteAccountsBatchSize entries.',
      );
    }

    return _httpClient.v1((api, projectId) async {
      return api.projects.accounts_1.batchDelete(
        auth1.GoogleCloudIdentitytoolkitV1BatchDeleteAccountsRequest(
          localIds: uids,
          force: force,
        ),
        projectId,
      );
    });
  }

  /// Create a new user with the properties supplied.
  ///
  /// A [Future] that resolves when the operation completes
  /// with the user id that was created.
  Future<String> createNewAccount(CreateRequest properties) async {
    return _httpClient.v1((api, projectId) async {
      var mfaInfo = properties.multiFactor?.enrolledFactors
          .map((info) => info.toGoogleCloudIdentitytoolkitV1MfaFactor())
          .toList();
      if (mfaInfo != null && mfaInfo.isEmpty) mfaInfo = null;

      final response = await api.projects.accounts(
        auth1.GoogleCloudIdentitytoolkitV1SignUpRequest(
          disabled: properties.disabled,
          displayName: properties.displayName?.value,
          email: properties.email,
          emailVerified: properties.emailVerified,
          localId: properties.uid,
          mfaInfo: mfaInfo,
          password: properties.password,
          phoneNumber: properties.phoneNumber?.value,
          photoUrl: properties.photoURL?.value,
        ),
        projectId,
      );

      final localId = response.localId;
      if (localId == null) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.internalError,
          'INTERNAL ASSERT FAILED: Unable to create new user',
        );
      }

      return localId;
    });
  }

  Future<auth1.GoogleCloudIdentitytoolkitV1GetAccountInfoResponse>
  _accountsLookup(
    auth1.GoogleCloudIdentitytoolkitV1GetAccountInfoRequest request,
  ) async {
    return _httpClient.v1((api, projectId) async {
      final response = await api.accounts.lookup(request);
      final users = response.users;
      if (users == null || users.isEmpty) {
        throw FirebaseAuthAdminException(AuthClientErrorCode.userNotFound);
      }
      return response;
    });
  }

  /// Looks up a user by uid.
  ///
  /// Returns a Future that resolves with the user information.
  Future<auth1.GoogleCloudIdentitytoolkitV1UserInfo> getAccountInfoByUid(
    String uid,
  ) async {
    if (!isUid(uid)) {
      throw FirebaseAuthAdminException(AuthClientErrorCode.invalidUid);
    }

    final response = await _accountsLookup(
      auth1.GoogleCloudIdentitytoolkitV1GetAccountInfoRequest(localId: [uid]),
    );

    return response.users!.single;
  }

  /// Looks up a user by email.
  Future<auth1.GoogleCloudIdentitytoolkitV1UserInfo> getAccountInfoByEmail(
    String email,
  ) async {
    assertIsEmail(email);

    final response = await _accountsLookup(
      auth1.GoogleCloudIdentitytoolkitV1GetAccountInfoRequest(email: [email]),
    );

    return response.users!.single;
  }

  /// Looks up a user by phone number.
  Future<auth1.GoogleCloudIdentitytoolkitV1UserInfo>
  getAccountInfoByPhoneNumber(String phoneNumber) async {
    assertIsPhoneNumber(phoneNumber);

    final response = await _accountsLookup(
      auth1.GoogleCloudIdentitytoolkitV1GetAccountInfoRequest(
        phoneNumber: [phoneNumber],
      ),
    );

    return response.users!.single;
  }

  Future<auth1.GoogleCloudIdentitytoolkitV1UserInfo>
  getAccountInfoByFederatedUid({
    required String providerId,
    required String rawId,
  }) async {
    if (providerId.isEmpty) {
      throw FirebaseAuthAdminException(AuthClientErrorCode.invalidProviderId);
    }
    if (rawId.isEmpty) {
      throw FirebaseAuthAdminException(AuthClientErrorCode.invalidUid);
    }

    final response = await _accountsLookup(
      auth1.GoogleCloudIdentitytoolkitV1GetAccountInfoRequest(
        federatedUserId: [
          auth1.GoogleCloudIdentitytoolkitV1FederatedUserIdentifier(
            providerId: providerId,
            rawId: rawId,
          ),
        ],
      ),
    );

    return response.users!.single;
  }

  /// Looks up multiple users by their identifiers (uid, email, etc).
  Future<auth1.GoogleCloudIdentitytoolkitV1GetAccountInfoResponse>
  getAccountInfoByIdentifiers(List<UserIdentifier> identifiers) async {
    if (identifiers.isEmpty) {
      return auth1.GoogleCloudIdentitytoolkitV1GetAccountInfoResponse(
        users: [],
      );
    } else if (identifiers.length > _maxGetAccountsBatchSize) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.maximumUserCountExceeded,
        '`identifiers` parameter must have <= $_maxGetAccountsBatchSize entries.',
      );
    }

    final request = auth1.GoogleCloudIdentitytoolkitV1GetAccountInfoRequest();

    for (final id in identifiers) {
      switch (id) {
        case UidIdentifier():
          if (request.localId != null) {
            request.localId!.add(id.uid);
          } else {
            request.localId = [id.uid];
          }
        case EmailIdentifier():
          if (request.email != null) {
            request.email!.add(id.email);
          } else {
            request.email = [id.email];
          }
        case PhoneIdentifier():
          if (request.phoneNumber != null) {
            request.phoneNumber!.add(id.phoneNumber);
          } else {
            request.phoneNumber = [id.phoneNumber];
          }
        case ProviderIdentifier():
          if (request.federatedUserId != null) {
            request.federatedUserId!.add(
              auth1.GoogleCloudIdentitytoolkitV1FederatedUserIdentifier(
                providerId: id.providerId,
                rawId: id.providerUid,
              ),
            );
          } else {
            request.federatedUserId = [
              auth1.GoogleCloudIdentitytoolkitV1FederatedUserIdentifier(
                providerId: id.providerId,
                rawId: id.providerUid,
              ),
            ];
          }
      }
    }

    return _httpClient.v1((api, projectId) => api.accounts.lookup(request));
  }

  /// Edits an existing user.
  ///
  /// - uid - The user to edit.
  /// - properties - The properties to set on the user.
  ///
  /// Returns a [Future] that resolves when the operation completes
  /// with the user id that was edited.
  Future<String> updateExistingAccount(
    String uid,
    UpdateRequest properties,
  ) async {
    assertIsUid(uid);

    final providerToLink = properties.providerToLink;
    if (providerToLink != null) {
      if (providerToLink.providerId?.isNotEmpty ?? false) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.invalidArgument,
          'providerToLink.providerId of properties argument must be a non-empty string.',
        );
      }
      if (providerToLink.uid?.isNotEmpty ?? false) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.invalidArgument,
          'providerToLink.uid of properties argument must be a non-empty string.',
        );
      }
    }
    final providersToUnlink = properties.providersToUnlink;
    if (providersToUnlink != null) {
      for (final provider in providersToUnlink) {
        if (provider.isEmpty) {
          throw FirebaseAuthAdminException(
            AuthClientErrorCode.invalidArgument,
            'providersToUnlink of properties argument must be a non-empty string.',
          );
        }
      }
    }

    // For deleting some attributes, these values must be passed as Box(null).
    final isPhotoDeleted =
        properties.photoURL != null && properties.photoURL?.value == null;
    final isDisplayNameDeleted =
        properties.displayName != null && properties.displayName?.value == null;
    final isPhoneNumberDeleted =
        properties.phoneNumber != null && properties.phoneNumber?.value == null;

    // They will be removed from the backend request and an additional parameter
    // deleteAttribute: ['PHOTO_URL', 'DISPLAY_NAME']
    // with an array of the parameter names to delete will be passed.
    final deleteAttribute = [
      if (isPhotoDeleted) 'PHOTO_URL',
      if (isDisplayNameDeleted) 'DISPLAY_NAME',
    ];

    // Phone will be removed from the backend request and an additional parameter
    // deleteProvider: ['phone'] with an array of providerIds (phone in this case),
    // will be passed.
    List<String>? deleteProvider;
    if (isPhoneNumberDeleted) deleteProvider = ['phone'];

    final linkProviderUserInfo = properties.providerToLink
        ?._toProviderUserInfo();

    final providerToUnlink = properties.providersToUnlink;
    if (providerToUnlink != null) {
      deleteProvider ??= [];
      deleteProvider.addAll(providerToUnlink);
    }

    final mfa = properties.multiFactor?.toMfaInfo();

    final request = auth1.GoogleCloudIdentitytoolkitV1SetAccountInfoRequest(
      deleteAttribute: deleteAttribute.isEmpty ? null : deleteAttribute,
      deleteProvider: deleteProvider,
      disableUser: properties.disabled,
      // Will be null if deleted or set to null. "deleteAttribute" will take over
      displayName: properties.displayName?.value,
      email: properties.email,
      emailVerified: properties.emailVerified,
      linkProviderUserInfo: linkProviderUserInfo,
      mfa: mfa,
      password: properties.password,
      // Will be null if deleted or set to null. "deleteProvider" will take over
      phoneNumber: properties.phoneNumber?.value,
      // Will be null if deleted or set to null. "deleteAttribute" will take over
      photoUrl: properties.photoURL?.value,
      // The UID of the user to be updated.
      localId: uid,
    );

    final response = await _httpClient.setAccountInfo(request);
    return response.localId!;
  }
}

class AuthRequestHandler extends _AbstractAuthRequestHandler {
  AuthRequestHandler(super.app, {@internal super.httpClient});

  /// Gets the current project's config.
  Future<Map<String, dynamic>> getProjectConfig() async {
    final response = await _httpClient.getConfig();
    return _projectConfigResponseToJson(response);
  }

  /// Updates the current project's config.
  Future<Map<String, dynamic>> updateProjectConfig(
    UpdateProjectConfigRequest options,
  ) async {
    final requestMap = options.buildServerRequest();
    final request = auth2.GoogleCloudIdentitytoolkitAdminV2Config.fromJson(
      requestMap,
    );

    // Generate update mask from request keys
    final updateMask = requestMap.keys.join(',');

    final response = await _httpClient.updateConfig(request, updateMask);
    return _projectConfigResponseToJson(response);
  }

  /// Looks up a tenant by tenant ID.
  Future<Map<String, dynamic>> getTenant(String tenantId) async {
    if (tenantId.isEmpty) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.invalidTenantId,
        'Tenant ID must be a non-empty string.',
      );
    }

    final response = await _httpClient.getTenant(tenantId);
    return _tenantResponseToJson(response);
  }

  /// Lists tenants (single batch only) with a size of maxResults and starting from
  /// the offset as specified by pageToken.
  Future<Map<String, dynamic>> listTenants({
    int maxResults = 1000,
    String? pageToken,
  }) async {
    if (maxResults > 1000) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.invalidArgument,
        'maxResults must not exceed 1000.',
      );
    }

    final response = await _httpClient.listTenants(
      maxResults: maxResults,
      pageToken: pageToken,
    );

    final tenants = <Map<String, dynamic>>[];
    if (response.tenants != null) {
      for (final tenant in response.tenants!) {
        tenants.add(_tenantResponseToJson(tenant));
      }
    }

    return {
      'tenants': tenants,
      if (response.nextPageToken != null)
        'nextPageToken': response.nextPageToken,
    };
  }

  /// Deletes a tenant identified by a tenantId.
  Future<void> deleteTenant(String tenantId) async {
    if (tenantId.isEmpty) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.invalidTenantId,
        'Tenant ID must be a non-empty string.',
      );
    }

    await _httpClient.deleteTenant(tenantId);
  }

  /// Creates a new tenant with the properties provided.
  Future<Map<String, dynamic>> createTenant(
    CreateTenantRequest tenantOptions,
  ) async {
    final requestMap = Tenant._buildServerRequest(tenantOptions, true);
    final request = auth2.GoogleCloudIdentitytoolkitAdminV2Tenant.fromJson(
      requestMap,
    );
    final response = await _httpClient.createTenant(request);
    return _tenantResponseToJson(response);
  }

  /// Updates an existing tenant with the properties provided.
  Future<Map<String, dynamic>> updateTenant(
    String tenantId,
    UpdateTenantRequest tenantOptions,
  ) async {
    if (tenantId.isEmpty) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.invalidTenantId,
        'Tenant ID must be a non-empty string.',
      );
    }

    final requestMap = Tenant._buildServerRequest(tenantOptions, false);
    final request = auth2.GoogleCloudIdentitytoolkitAdminV2Tenant.fromJson(
      requestMap,
    );
    final response = await _httpClient.updateTenant(tenantId, request);
    return _tenantResponseToJson(response);
  }

  /// Helper method to convert tenant response to JSON format.
  Map<String, dynamic> _tenantResponseToJson(
    auth2.GoogleCloudIdentitytoolkitAdminV2Tenant response,
  ) {
    return {
      'name': response.name,
      if (response.displayName != null) 'displayName': response.displayName,
      if (response.allowPasswordSignup != null)
        'allowPasswordSignup': response.allowPasswordSignup,
      if (response.enableEmailLinkSignin != null)
        'enableEmailLinkSignin': response.enableEmailLinkSignin,
      if (response.enableAnonymousUser != null)
        'enableAnonymousUser': response.enableAnonymousUser,
      if (response.mfaConfig != null)
        'mfaConfig': _mfaConfigToJson(response.mfaConfig!),
      if (response.testPhoneNumbers != null)
        'testPhoneNumbers': response.testPhoneNumbers,
      if (response.smsRegionConfig != null)
        'smsRegionConfig': _smsRegionConfigToJson(response.smsRegionConfig!),
      if (response.recaptchaConfig != null)
        'recaptchaConfig': _recaptchaConfigToJson(response.recaptchaConfig!),
      if (response.passwordPolicyConfig != null)
        'passwordPolicyConfig': _passwordPolicyConfigToJson(
          response.passwordPolicyConfig!,
        ),
      if (response.emailPrivacyConfig != null)
        'emailPrivacyConfig': _emailPrivacyConfigToJson(
          response.emailPrivacyConfig!,
        ),
    };
  }

  Map<String, dynamic> _mfaConfigToJson(
    auth2.GoogleCloudIdentitytoolkitAdminV2MultiFactorAuthConfig config,
  ) {
    // Convert providerConfigs from Google API objects to JSON maps
    List<Map<String, dynamic>>? providerConfigsJson;
    if (config.providerConfigs != null) {
      providerConfigsJson = <Map<String, dynamic>>[];
      for (final providerConfig in config.providerConfigs!) {
        final configMap = <String, dynamic>{};

        // Extract state
        if (providerConfig.state != null) {
          configMap['state'] = providerConfig.state;
        }

        // Extract totpProviderConfig
        if (providerConfig.totpProviderConfig != null) {
          final totpConfig = <String, dynamic>{};
          if (providerConfig.totpProviderConfig!.adjacentIntervals != null) {
            totpConfig['adjacentIntervals'] =
                providerConfig.totpProviderConfig!.adjacentIntervals;
          }
          configMap['totpProviderConfig'] = totpConfig;
        }

        providerConfigsJson.add(configMap);
      }
    }

    return {
      if (config.state != null) 'state': config.state,
      if (config.enabledProviders != null)
        'enabledProviders': config.enabledProviders,
      'providerConfigs': ?providerConfigsJson,
    };
  }

  Map<String, dynamic> _smsRegionConfigToJson(
    auth2.GoogleCloudIdentitytoolkitAdminV2SmsRegionConfig config,
  ) {
    return {
      if (config.allowByDefault != null)
        'allowByDefault': {
          'disallowedRegions': config.allowByDefault!.disallowedRegions ?? [],
        },
      if (config.allowlistOnly != null)
        'allowlistOnly': {
          'allowedRegions': config.allowlistOnly!.allowedRegions ?? [],
        },
    };
  }

  Map<String, dynamic> _recaptchaConfigToJson(
    auth2.GoogleCloudIdentitytoolkitAdminV2RecaptchaConfig config,
  ) {
    final result = <String, dynamic>{
      if (config.emailPasswordEnforcementState != null)
        'emailPasswordEnforcementState': config.emailPasswordEnforcementState,
    };

    // phoneEnforcementState may not be in the Google API types yet, check if it exists
    try {
      final phoneState = (config as dynamic).phoneEnforcementState;
      if (phoneState != null) {
        result['phoneEnforcementState'] = phoneState;
      }
    } catch (_) {
      // Field doesn't exist in API types yet
    }

    if (config.useAccountDefender != null) {
      result['useAccountDefender'] = config.useAccountDefender;
    }

    // Add managedRules if present
    if (config.managedRules != null) {
      result['managedRules'] = config.managedRules!.map((rule) {
        return {
          'endScore': rule.endScore,
          if (rule.action != null) 'action': rule.action,
        };
      }).toList();
    }

    // Add recaptchaKeys if present
    if (config.recaptchaKeys != null) {
      result['recaptchaKeys'] = config.recaptchaKeys!.map((key) {
        return {'key': key.key, if (key.type != null) 'type': key.type};
      }).toList();
    }

    // useSmsBotScore may not be in the Google API types yet, check if it exists
    try {
      final useSmsBotScore = (config as dynamic).useSmsBotScore;
      if (useSmsBotScore != null) {
        result['useSmsBotScore'] = useSmsBotScore;
      }
    } catch (_) {
      // Field doesn't exist in API types yet
    }

    // useSmsTollFraudProtection may not be in the Google API types yet, check if it exists
    try {
      final useSmsTollFraudProtection =
          (config as dynamic).useSmsTollFraudProtection;
      if (useSmsTollFraudProtection != null) {
        result['useSmsTollFraudProtection'] = useSmsTollFraudProtection;
      }
    } catch (_) {
      // Field doesn't exist in API types yet
    }

    // tollFraudManagedRules may not be in the Google API types yet, check if it exists
    try {
      final tollFraudManagedRules = (config as dynamic).tollFraudManagedRules;
      if (tollFraudManagedRules != null) {
        result['tollFraudManagedRules'] =
            (tollFraudManagedRules as List<dynamic>).map((rule) {
              final ruleMap = rule as Map<String, dynamic>;
              return {
                'startScore': ruleMap['startScore'] is int
                    ? (ruleMap['startScore'] as int).toDouble()
                    : ruleMap['startScore'] as double,
                if (ruleMap['action'] != null) 'action': ruleMap['action'],
              };
            }).toList();
      }
    } catch (_) {
      // Field doesn't exist in API types yet
    }

    return result;
  }

  Map<String, dynamic> _passwordPolicyConfigToJson(
    auth2.GoogleCloudIdentitytoolkitAdminV2PasswordPolicyConfig config,
  ) {
    return {
      if (config.passwordPolicyEnforcementState != null)
        'passwordPolicyEnforcementState': config.passwordPolicyEnforcementState,
      if (config.forceUpgradeOnSignin != null)
        'forceUpgradeOnSignin': config.forceUpgradeOnSignin,
      if (config.passwordPolicyVersions != null)
        'passwordPolicyVersions': config.passwordPolicyVersions!.map((version) {
          return {
            if (version.customStrengthOptions != null)
              'customStrengthOptions': {
                if (version.customStrengthOptions!.containsLowercaseCharacter !=
                    null)
                  'containsLowercaseCharacter':
                      version.customStrengthOptions!.containsLowercaseCharacter,
                if (version.customStrengthOptions!.containsUppercaseCharacter !=
                    null)
                  'containsUppercaseCharacter':
                      version.customStrengthOptions!.containsUppercaseCharacter,
                if (version.customStrengthOptions!.containsNumericCharacter !=
                    null)
                  'containsNumericCharacter':
                      version.customStrengthOptions!.containsNumericCharacter,
                if (version
                        .customStrengthOptions!
                        .containsNonAlphanumericCharacter !=
                    null)
                  'containsNonAlphanumericCharacter': version
                      .customStrengthOptions!
                      .containsNonAlphanumericCharacter,
                if (version.customStrengthOptions!.minPasswordLength != null)
                  'minPasswordLength':
                      version.customStrengthOptions!.minPasswordLength,
                if (version.customStrengthOptions!.maxPasswordLength != null)
                  'maxPasswordLength':
                      version.customStrengthOptions!.maxPasswordLength,
              },
          };
        }).toList(),
    };
  }

  Map<String, dynamic> _emailPrivacyConfigToJson(
    auth2.GoogleCloudIdentitytoolkitAdminV2EmailPrivacyConfig config,
  ) {
    return {
      if (config.enableImprovedEmailPrivacy != null)
        'enableImprovedEmailPrivacy': config.enableImprovedEmailPrivacy,
    };
  }

  Map<String, dynamic> _mobileLinksConfigToJson(
    auth2.GoogleCloudIdentitytoolkitAdminV2MobileLinksConfig config,
  ) {
    return {if (config.domain != null) 'domain': config.domain};
  }

  /// Helper method to convert project config response to JSON format.
  Map<String, dynamic> _projectConfigResponseToJson(
    auth2.GoogleCloudIdentitytoolkitAdminV2Config response,
  ) {
    return {
      if (response.smsRegionConfig != null)
        'smsRegionConfig': _smsRegionConfigToJson(response.smsRegionConfig!),
      // Backend API returns "mfa" for project config
      if (response.mfa != null) 'mfa': _mfaConfigToJson(response.mfa!),
      if (response.recaptchaConfig != null)
        'recaptchaConfig': _recaptchaConfigToJson(response.recaptchaConfig!),
      if (response.passwordPolicyConfig != null)
        'passwordPolicyConfig': _passwordPolicyConfigToJson(
          response.passwordPolicyConfig!,
        ),
      if (response.emailPrivacyConfig != null)
        'emailPrivacyConfig': _emailPrivacyConfigToJson(
          response.emailPrivacyConfig!,
        ),
      if (response.mobileLinksConfig != null)
        'mobileLinksConfig': _mobileLinksConfigToJson(
          response.mobileLinksConfig!,
        ),
    };
  }
}

/// Tenant-aware request handler extending the abstract auth request handler.
class _TenantAwareAuthRequestHandler extends _AbstractAuthRequestHandler {
  _TenantAwareAuthRequestHandler(super.app, this.tenantId)
    : _tenantHttpClient = _TenantAwareAuthHttpClient(app, tenantId);

  final String tenantId;
  final _TenantAwareAuthHttpClient _tenantHttpClient;

  @override
  _TenantAwareAuthHttpClient get _httpClient => _tenantHttpClient;
}
