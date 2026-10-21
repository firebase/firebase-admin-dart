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

class AuthHttpClient {
  AuthHttpClient(this.app);

  final FirebaseApp app;

  /// Gets the Auth API host URL based on emulator configuration.
  ///
  /// When [Environment.firebaseAuthEmulatorHost] is set, routes requests to
  /// the local Auth emulator. Otherwise, uses production Auth API.
  Uri get _authApiHost {
    final emulatorHost = Environment.getAuthEmulatorHost();

    if (emulatorHost != null) {
      return Uri.http(emulatorHost, 'identitytoolkit.googleapis.com/');
    }

    return Uri.https('identitytoolkit.googleapis.com', '/');
  }

  /// Lazy-initialized HTTP client that's cached for reuse.
  /// Uses unauthenticated client for emulator, authenticated for production.
  late final Future<googleapis_auth.AuthClient> _client = _createClient();

  Future<googleapis_auth.AuthClient> get client => _client;

  /// Creates the appropriate HTTP client based on emulator configuration.
  Future<googleapis_auth.AuthClient> _createClient() async {
    // If app has custom httpClient (e.g., mock for testing), always use it
    if (app.options.httpClient != null) {
      return app.client;
    }

    if (Environment.isAuthEmulatorEnabled()) {
      // Emulator: Create unauthenticated client to avoid loading ADC credentials
      // which would cause emulator warnings. Wrap with EmulatorClient to add
      // "Authorization: Bearer owner" header that the emulator requires.
      return EmulatorClient(http.Client());
    }
    // Production: Use authenticated client from app
    return app.client;
  }

  /// Builds the parent resource path for project-level operations.
  String buildParent(String projectId) {
    return 'projects/$projectId';
  }

  String buildProjectConfigParent(String projectId) {
    return '${buildParent(projectId)}/config';
  }

  /// Builds the parent path for OAuth IDP config operations.
  String buildOAuthIdpParent(String projectId, String parentId) {
    return 'projects/$projectId/oauthIdpConfigs/$parentId';
  }

  /// Builds the parent path for SAML config operations.
  String buildSamlParent(String projectId, String parentId) {
    return 'projects/$projectId/inboundSamlConfigs/$parentId';
  }

  /// Builds the resource path for a specific tenant.
  String buildTenantParent(String projectId, String tenantId) {
    return 'projects/$projectId/tenants/$tenantId';
  }

  Future<auth1.GoogleCloudIdentitytoolkitV1GetOobCodeResponse> getOobCode(
    auth1.GoogleCloudIdentitytoolkitV1GetOobCodeRequest request,
  ) {
    return v1((api, projectId) async {
      final email = request.email;
      if (email == null || !isEmail(email)) {
        throw FirebaseAuthAdminException(AuthClientErrorCode.invalidEmail);
      }

      final newEmail = request.newEmail;
      if (newEmail != null && !isEmail(newEmail)) {
        throw FirebaseAuthAdminException(AuthClientErrorCode.invalidEmail);
      }

      if (!_emailActionRequestTypes.contains(request.requestType)) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.invalidArgument,
          '"${request.requestType}" is not a supported email action request type.',
        );
      }

      final response = await api.accounts.sendOobCode(request);

      if (response.oobLink == null) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.internalError,
          'INTERNAL ASSERT FAILED: Unable to generate email action link',
        );
      }

      return response;
    });
  }

  Future<auth2.GoogleCloudIdentitytoolkitAdminV2ListInboundSamlConfigsResponse>
  listInboundSamlConfigs({required int pageSize, String? pageToken}) {
    return v2((api, projectId) async {
      if (pageToken != null && pageToken.isEmpty) {
        throw FirebaseAuthAdminException(AuthClientErrorCode.invalidPageToken);
      }

      if (pageSize <= 0 || pageSize > _maxListProviderConfigurationPageSize) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.invalidArgument,
          'Required "maxResults" must be a positive integer that does not exceed '
          '$_maxListProviderConfigurationPageSize.',
        );
      }

      return api.projects.inboundSamlConfigs.list(
        buildParent(projectId),
        pageSize: pageSize,
        pageToken: pageToken,
      );
    });
  }

  Future<auth2.GoogleCloudIdentitytoolkitAdminV2ListOAuthIdpConfigsResponse>
  listOAuthIdpConfigs({required int pageSize, String? pageToken}) {
    return v2((api, projectId) async {
      if (pageToken != null && pageToken.isEmpty) {
        throw FirebaseAuthAdminException(AuthClientErrorCode.invalidPageToken);
      }

      if (pageSize <= 0 || pageSize > _maxListProviderConfigurationPageSize) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.invalidArgument,
          'Required "maxResults" must be a positive integer that does not exceed '
          '$_maxListProviderConfigurationPageSize.',
        );
      }

      return api.projects.oauthIdpConfigs.list(
        buildParent(projectId),
        pageSize: pageSize,
        pageToken: pageToken,
      );
    });
  }

  Future<auth2.GoogleCloudIdentitytoolkitAdminV2OAuthIdpConfig>
  createOAuthIdpConfig(
    auth2.GoogleCloudIdentitytoolkitAdminV2OAuthIdpConfig request,
    String providerId,
  ) {
    return v2((api, projectId) async {
      final response = await api.projects.oauthIdpConfigs.create(
        request,
        buildParent(projectId),
        oauthIdpConfigId: providerId,
      );

      final name = response.name;
      if (name == null || name.isEmpty) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.internalError,
          'INTERNAL ASSERT FAILED: Unable to create OIDC configuration',
        );
      }

      return response;
    });
  }

  Future<auth2.GoogleCloudIdentitytoolkitAdminV2InboundSamlConfig>
  createInboundSamlConfig(
    auth2.GoogleCloudIdentitytoolkitAdminV2InboundSamlConfig request,
    String providerId,
  ) {
    return v2((api, projectId) async {
      final response = await api.projects.inboundSamlConfigs.create(
        request,
        buildParent(projectId),
        inboundSamlConfigId: providerId,
      );

      final name = response.name;
      if (name == null || name.isEmpty) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.internalError,
          'INTERNAL ASSERT FAILED: Unable to create SAML configuration',
        );
      }

      return response;
    });
  }

  Future<void> deleteOauthIdpConfig(String providerId) {
    return v2((api, projectId) async {
      await api.projects.oauthIdpConfigs.delete(
        buildOAuthIdpParent(projectId, providerId),
      );
    });
  }

  Future<void> deleteInboundSamlConfig(String providerId) {
    return v2((api, projectId) async {
      await api.projects.inboundSamlConfigs.delete(
        buildSamlParent(projectId, providerId),
      );
    });
  }

  Future<auth2.GoogleCloudIdentitytoolkitAdminV2InboundSamlConfig>
  updateInboundSamlConfig(
    auth2.GoogleCloudIdentitytoolkitAdminV2InboundSamlConfig request,
    String providerId, {
    required String? updateMask,
  }) {
    return v2((api, projectId) async {
      final response = await api.projects.inboundSamlConfigs.patch(
        request,
        buildSamlParent(projectId, providerId),
        updateMask: updateMask,
      );

      if (response.name == null || response.name!.isEmpty) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.internalError,
          'INTERNAL ASSERT FAILED: Unable to update SAML configuration',
        );
      }

      return response;
    });
  }

  Future<auth2.GoogleCloudIdentitytoolkitAdminV2OAuthIdpConfig>
  updateOAuthIdpConfig(
    auth2.GoogleCloudIdentitytoolkitAdminV2OAuthIdpConfig request,
    String providerId, {
    required String? updateMask,
  }) {
    return v2((api, projectId) async {
      final response = await api.projects.oauthIdpConfigs.patch(
        request,
        buildOAuthIdpParent(projectId, providerId),
        updateMask: updateMask,
      );

      if (response.name == null || response.name!.isEmpty) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.internalError,
          'INTERNAL ASSERT FAILED: Unable to update OIDC configuration',
        );
      }

      return response;
    });
  }

  Future<auth1.GoogleCloudIdentitytoolkitV1SetAccountInfoResponse>
  setAccountInfo(
    auth1.GoogleCloudIdentitytoolkitV1SetAccountInfoRequest request,
  ) {
    return v1((api, projectId) async {
      // TODO should this use account/project/update or account/update?
      // Or maybe both?
      // ^ Depending on it, use tenantId... Or do we? The request seems to reject tenantID args
      final response = await api.accounts.update(request);

      final localId = response.localId;
      if (localId == null) {
        throw FirebaseAuthAdminException(AuthClientErrorCode.userNotFound);
      }
      return response;
    });
  }

  Future<auth2.GoogleCloudIdentitytoolkitAdminV2OAuthIdpConfig>
  getOauthIdpConfig(String providerId) {
    return v2((api, projectId) async {
      final response = await api.projects.oauthIdpConfigs.get(
        buildOAuthIdpParent(projectId, providerId),
      );

      final name = response.name;
      if (name == null || name.isEmpty) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.internalError,
          'INTERNAL ASSERT FAILED: Unable to get OIDC configuration',
        );
      }

      return response;
    });
  }

  Future<auth2.GoogleCloudIdentitytoolkitAdminV2InboundSamlConfig>
  getInboundSamlConfig(String providerId) {
    return v2((api, projectId) async {
      final response = await api.projects.inboundSamlConfigs.get(
        buildSamlParent(projectId, providerId),
      );

      final name = response.name;
      if (name == null || name.isEmpty) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.internalError,
          'INTERNAL ASSERT FAILED: Unable to get SAML configuration',
        );
      }

      return response;
    });
  }

  // Tenant management methods
  Future<auth2.GoogleCloudIdentitytoolkitAdminV2Tenant> getTenant(
    String tenantId,
  ) {
    return v2((api, projectId) async {
      assertIsTenantId(tenantId);

      final response = await api.projects.tenants.get(
        buildTenantParent(projectId, tenantId),
      );

      if (response.name == null || response.name!.isEmpty) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.internalError,
          'INTERNAL ASSERT FAILED: Unable to get tenant',
        );
      }

      return response;
    });
  }

  Future<auth2.GoogleCloudIdentitytoolkitAdminV2ListTenantsResponse>
  listTenants({required int maxResults, String? pageToken}) {
    // TODO(demalaf): rename client below to identityApi or api
    return v2((api, projectId) async {
      final response = await api.projects.tenants.list(
        buildParent(projectId),
        pageSize: maxResults,
        pageToken: pageToken,
      );

      return response;
    });
  }

  Future<auth2.GoogleProtobufEmpty> deleteTenant(String tenantId) {
    return v2((api, projectId) async {
      assertIsTenantId(tenantId);

      return api.projects.tenants.delete(
        buildTenantParent(projectId, tenantId),
      );
    });
  }

  Future<auth2.GoogleCloudIdentitytoolkitAdminV2Tenant> createTenant(
    auth2.GoogleCloudIdentitytoolkitAdminV2Tenant request,
  ) {
    return v2((api, projectId) async {
      final response = await api.projects.tenants.create(
        request,
        buildParent(projectId),
      );

      if (response.name == null || response.name!.isEmpty) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.internalError,
          'INTERNAL ASSERT FAILED: Unable to create new tenant',
        );
      }

      return response;
    });
  }

  Future<auth2.GoogleCloudIdentitytoolkitAdminV2Tenant> updateTenant(
    String tenantId,
    auth2.GoogleCloudIdentitytoolkitAdminV2Tenant request,
  ) {
    return v2((api, projectId) async {
      assertIsTenantId(tenantId);

      final name = buildTenantParent(projectId, tenantId);
      final updateMask = request.toJson().keys.join(',');

      final response = await api.projects.tenants.patch(
        request,
        name,
        updateMask: updateMask,
      );

      if (response.name == null || response.name!.isEmpty) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.internalError,
          'INTERNAL ASSERT FAILED: Unable to update tenant',
        );
      }

      return response;
    });
  }

  // Project Config management methods
  Future<auth2.GoogleCloudIdentitytoolkitAdminV2Config> getConfig() {
    return v2((api, projectId) async {
      final name = buildProjectConfigParent(projectId);
      final response = await api.projects.getConfig(name);
      return response;
    });
  }

  Future<auth2.GoogleCloudIdentitytoolkitAdminV2Config> updateConfig(
    auth2.GoogleCloudIdentitytoolkitAdminV2Config request,
    String updateMask,
  ) {
    return v2((api, projectId) async {
      final name = buildProjectConfigParent(projectId);
      final response = await api.projects.updateConfig(
        request,
        name,
        updateMask: updateMask,
      );
      return response;
    });
  }

  Future<R> _run<R>(
    Future<R> Function(googleapis_auth.AuthClient client, String projectId) fn,
  ) {
    return _authGuard(() async {
      // Use the cached client (created once based on emulator configuration)
      final client = await _client;
      final projectId = await app.getProjectId();
      return fn(client, projectId);
    });
  }

  Future<R> v1<R>(
    Future<R> Function(auth1.IdentityToolkitApi api, String projectId) fn,
  ) => _run(
    (client, projectId) => fn(
      auth1.IdentityToolkitApi(client, rootUrl: _authApiHost.toString()),
      projectId,
    ),
  );

  Future<R> v2<R>(
    Future<R> Function(auth2.IdentityToolkitApi api, String projectId) fn,
  ) => _run(
    (client, projectId) => fn(
      auth2.IdentityToolkitApi(client, rootUrl: _authApiHost.toString()),
      projectId,
    ),
  );

  Future<R> v3<R>(
    Future<R> Function(auth3.IdentityToolkitApi api, String projectId) fn,
  ) => _run(
    (client, projectId) => fn(
      auth3.IdentityToolkitApi(client, rootUrl: _authApiHost.toString()),
      projectId,
    ),
  );
}

/// Tenant-aware HTTP client that builds tenant-specific resource paths.
class _TenantAwareAuthHttpClient extends AuthHttpClient {
  _TenantAwareAuthHttpClient(super.app, this.tenantId) {
    assertIsTenantId(tenantId);
  }

  final String tenantId;

  @override
  String buildParent(String projectId) =>
      'projects/$projectId/tenants/$tenantId';

  @override
  String buildOAuthIdpParent(String projectId, String parentId) =>
      'projects/$projectId/tenants/$tenantId/oauthIdpConfigs/$parentId';

  @override
  String buildSamlParent(String projectId, String parentId) =>
      'projects/$projectId/tenants/$tenantId/inboundSamlConfigs/$parentId';
}
