// Copyright 2024 Google LLC
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

/// Interface representing the object returned from a
/// [TenantManager.listTenants] operation.
/// Contains the list of tenants for the current batch and the next page token if available.
class ListTenantsResult {
  ListTenantsResult({required this.tenants, this.pageToken});

  /// The list of [Tenant] objects for the downloaded batch.
  final List<Tenant> tenants;

  /// The next page token if available. This is needed for the next batch download.
  final String? pageToken;
}

/// Tenant-aware `Auth` interface used for managing users, configuring SAML/OIDC providers,
/// generating email links for password reset, email verification, etc for specific tenants.
///
/// Multi-tenancy support requires Google Cloud's Identity Platform
/// (GCIP). To learn more about GCIP, including pricing and features,
/// see the [GCIP documentation](https://cloud.google.com/identity-platform).
///
/// Each tenant contains its own identity providers, settings and sets of users.
/// Using `TenantAwareAuth`, users for a specific tenant and corresponding OIDC/SAML
/// configurations can also be managed, ID tokens for users signed in to a specific tenant
/// can be verified, and email action links can also be generated for users belonging to the
/// tenant.
///
/// `TenantAwareAuth` instances for a specific `tenantId` can be instantiated by calling
/// [TenantManager.authForTenant].
class TenantAwareAuth extends _BaseAuth {
  /// The TenantAwareAuth class constructor.
  ///
  /// [app] - The app that created this tenant.
  /// [tenantId] - The corresponding tenant ID.
  TenantAwareAuth._(FirebaseApp app, this.tenantId)
    : super(
        app: app,
        authRequestHandler: _TenantAwareAuthRequestHandler(app, tenantId),
        tokenGenerator: _createFirebaseTokenGenerator(app, tenantId: tenantId),
      );

  /// Internal constructor for testing.
  ///
  /// [app] - The app that created this tenant.
  /// [tenantId] - The corresponding tenant ID.
  /// [idTokenVerifier] - Optional ID token verifier for testing.
  /// [sessionCookieVerifier] - Optional session cookie verifier for testing.
  @internal
  TenantAwareAuth.internal(
    FirebaseApp app,
    this.tenantId, {
    super.idTokenVerifier,
    super.sessionCookieVerifier,
  }) : super(
         app: app,
         authRequestHandler: _TenantAwareAuthRequestHandler(app, tenantId),
         tokenGenerator: _createFirebaseTokenGenerator(app, tenantId: tenantId),
       );

  /// The tenant identifier corresponding to this `TenantAwareAuth` instance.
  /// All calls to the user management APIs, OIDC/SAML provider management APIs, email link
  /// generation APIs, etc will only be applied within the scope of this tenant.
  final String tenantId;

  /// Verifies a Firebase ID token (JWT). If the token is valid and its `tenant_id` claim
  /// matches this tenant's ID, the returned [Future] is completed with the token's decoded claims;
  /// otherwise, the [Future] is rejected with an error.
  ///
  /// [idToken] - The ID token to verify.
  /// [checkRevoked] - Whether to check if the ID token was revoked. If true, verifies against
  ///   the Auth backend to check if the token has been revoked.
  ///
  /// Returns a [Future] that resolves with the token's decoded claims if the ID token is valid
  /// and belongs to this tenant; otherwise, a rejected [Future].
  @override
  Future<DecodedIdToken> verifyIdToken(
    String idToken, {
    bool checkRevoked = false,
  }) async {
    final decodedClaims = await super.verifyIdToken(
      idToken,
      checkRevoked: checkRevoked,
    );

    // Validate tenant ID.
    if (decodedClaims.firebase.tenant != tenantId) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.mismatchingTenantId,
        'The provided token does not match the tenant ID.',
      );
    }

    return decodedClaims;
  }

  /// Creates a new Firebase session cookie with the specified options that can be used for
  /// session management (set as a server side session cookie with custom cookie policy).
  /// The session cookie JWT will have the same payload claims as the provided ID token.
  ///
  /// [idToken] - The Firebase ID token to exchange for a session cookie.
  /// [sessionCookieOptions] - The session cookie options which includes custom expiration
  ///   in milliseconds. The minimum allowed is 5 minutes and the maxium allowed is 2 weeks.
  ///
  /// Returns a [Future] that resolves with the created session cookie.
  @override
  Future<String> createSessionCookie(
    String idToken,
    SessionCookieOptions sessionCookieOptions,
  ) async {
    // Validate idToken is not empty before verification.
    if (idToken.isEmpty) {
      throw FirebaseAuthAdminException(AuthClientErrorCode.invalidIdToken);
    }

    // Verify the ID token and check tenant ID before creating session cookie.
    await verifyIdToken(idToken);

    return super.createSessionCookie(idToken, sessionCookieOptions);
  }

  /// Verifies a Firebase session cookie. Returns a [Future] with the session cookie's decoded claims
  /// if the session cookie is valid and its `tenant_id` claim matches this tenant's ID;
  /// otherwise, a rejected [Future].
  ///
  /// [sessionCookie] - The session cookie to verify.
  /// [checkRevoked] - Whether to check if the session cookie was revoked. If true, verifies
  ///   against the Auth backend to check if the session has been revoked.
  ///
  /// Returns a [Future] that resolves with the session cookie's decoded claims if valid and
  /// belongs to this tenant; otherwise, a rejected [Future].
  @override
  Future<DecodedIdToken> verifySessionCookie(
    String sessionCookie, {
    bool checkRevoked = false,
  }) async {
    final decodedClaims = await super.verifySessionCookie(
      sessionCookie,
      checkRevoked: checkRevoked,
    );

    // Validate tenant ID.
    if (decodedClaims.firebase.tenant != tenantId) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.mismatchingTenantId,
        'The provided session cookie does not match the tenant ID.',
      );
    }

    return decodedClaims;
  }
}

/// Defines the tenant manager used to help manage tenant related operations.
/// This includes:
/// - The ability to create, update, list, get and delete tenants for the underlying
///   project.
/// - Getting a `TenantAwareAuth` instance for running Auth related operations
///   (user management, provider configuration management, token verification,
///   email link generation, etc) in the context of a specified tenant.
class TenantManager {
  /// Initializes a TenantManager instance for a specified FirebaseApp.
  ///
  /// The app parameter is the app for this TenantManager instance.
  TenantManager._(this._app)
    : _authRequestHandler = AuthRequestHandler(_app),
      _tenantsMap = {};

  /// Internal constructor for testing.
  ///
  /// [FirebaseApp] - The app for this TenantManager instance.
  /// [authRequestHandler] - Optional request handler for testing.
  @internal
  TenantManager.internal(this._app, {AuthRequestHandler? authRequestHandler})
    : _authRequestHandler = authRequestHandler ?? AuthRequestHandler(_app),
      _tenantsMap = {};

  final FirebaseApp _app;
  final AuthRequestHandler _authRequestHandler;
  final Map<String, TenantAwareAuth> _tenantsMap;

  /// Returns a `TenantAwareAuth` instance bound to the given tenant ID.
  ///
  /// [tenantId] - The tenant ID whose `TenantAwareAuth` instance is to be returned.
  ///
  /// Returns the `TenantAwareAuth` instance corresponding to this tenant identifier.
  TenantAwareAuth authForTenant(String tenantId) {
    assertIsTenantId(tenantId);

    return _tenantsMap.putIfAbsent(
      tenantId,
      () => TenantAwareAuth._(_app, tenantId),
    );
  }

  /// Gets the tenant configuration for the tenant corresponding to a given [tenantId].
  ///
  /// [tenantId] - The tenant identifier corresponding to the tenant whose data to fetch.
  ///
  /// Returns a [Future] fulfilled with the tenant configuration for the provided [tenantId].
  Future<Tenant> getTenant(String tenantId) async {
    final response = await _authRequestHandler.getTenant(tenantId);
    return Tenant._fromResponse(response);
  }

  /// Retrieves a list of tenants (single batch only) with a size of [maxResults]
  /// starting from the offset as specified by [pageToken]. This is used to
  /// retrieve all the tenants of a specified project in batches.
  ///
  /// [maxResults] - The page size, 1000 if not specified. This is also
  ///   the maximum allowed limit.
  /// [pageToken] - The next page token. If not specified, returns
  ///   tenants starting without any offset.
  ///
  /// Returns a [Future] that resolves with a batch of downloaded tenants and the next page token.
  Future<ListTenantsResult> listTenants({
    int maxResults = 1000,
    String? pageToken,
  }) async {
    final response = await _authRequestHandler.listTenants(
      maxResults: maxResults,
      pageToken: pageToken,
    );

    final tenants = <Tenant>[];
    final tenantsList = response['tenants'] as List<dynamic>?;
    if (tenantsList != null) {
      for (final tenantResponse in tenantsList) {
        tenants.add(
          Tenant._fromResponse(tenantResponse as Map<String, dynamic>),
        );
      }
    }

    return ListTenantsResult(
      tenants: tenants,
      pageToken: response['nextPageToken'] as String?,
    );
  }

  /// Deletes an existing tenant.
  ///
  /// [tenantId] - The `tenantId` corresponding to the tenant to delete.
  ///
  /// Returns a [Future] that completes once the tenant has been deleted.
  Future<void> deleteTenant(String tenantId) async {
    await _authRequestHandler.deleteTenant(tenantId);
  }

  /// Creates a new tenant.
  /// When creating new tenants, tenants that use separate billing and quota will require their
  /// own project and must be defined as `full_service`.
  ///
  /// [tenantOptions] - The properties to set on the new tenant configuration to be created.
  ///
  /// Returns a [Future] fulfilled with the tenant configuration corresponding to the newly
  /// created tenant.
  Future<Tenant> createTenant(CreateTenantRequest tenantOptions) async {
    final response = await _authRequestHandler.createTenant(tenantOptions);
    return Tenant._fromResponse(response);
  }

  /// Updates an existing tenant configuration.
  ///
  /// [tenantId] - The `tenantId` corresponding to the tenant to update.
  /// [tenantOptions] - The properties to update on the provided tenant.
  ///
  /// Returns a [Future] fulfilled with the updated tenant data.
  Future<Tenant> updateTenant(
    String tenantId,
    UpdateTenantRequest tenantOptions,
  ) async {
    final response = await _authRequestHandler.updateTenant(
      tenantId,
      tenantOptions,
    );
    return Tenant._fromResponse(response);
  }
}
