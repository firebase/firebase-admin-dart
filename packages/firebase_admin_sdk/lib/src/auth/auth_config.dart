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

/// The possible types for [AuthProviderConfigFilter._type].
enum _AuthProviderConfigFilterType { saml, oidc }

/// The filter interface used for listing provider configurations. This is used
/// when specifying how to list configured identity providers via
/// [_BaseAuth.listProviderConfigs].
class AuthProviderConfigFilter {
  AuthProviderConfigFilter.oidc({this.maxResults, this.pageToken})
    : _type = _AuthProviderConfigFilterType.oidc;

  AuthProviderConfigFilter.saml({this.maxResults, this.pageToken})
    : _type = _AuthProviderConfigFilterType.saml;

  /// The Auth provider configuration filter. This can be either `saml` or `oidc`.
  /// The former is used to look up SAML providers only, while the latter is used
  /// for OIDC providers.
  final _AuthProviderConfigFilterType _type;

  /// The maximum number of results to return per page. The default and maximum is
  /// 100.
  final int? maxResults;

  /// The next page token. When not specified, the lookup starts from the beginning
  /// of the list.
  final String? pageToken;
}

/// The response interface for listing provider configs. This is only available
/// when listing all identity providers' configurations via
/// [_BaseAuth.listProviderConfigs].
class ListProviderConfigResults {
  ListProviderConfigResults({
    required this.providerConfigs,
    required this.pageToken,
  });

  /// The list of providers for the specified project in the current page.
  final List<AuthProviderConfig> providerConfigs;

  /// The next page token, if available.
  final String? pageToken;
}

abstract class UpdateAuthProviderRequest {}

abstract class _SAMLAuthProviderRequestBase
    implements UpdateAuthProviderRequest {
  _SAMLAuthProviderRequestBase({
    this.displayName,
    this.enabled,
    this.idpEntityId,
    this.ssoURL,
    this.x509Certificates,
    this.rpEntityId,
    this.callbackURL,
  });

  bool? get enableRequestSigning;

  String? get issuer;

  /// The SAML provider's updated provider ID. If not provided, the existing
  /// configuration's value is not modified.
  String? get providerId;

  /// The SAML provider's updated display name. If not provided, the existing
  /// configuration's value is not modified.
  final String? displayName;

  /// Whether the SAML provider is enabled or not. If not provided, the existing
  /// configuration's setting is not modified.
  final bool? enabled;

  /// The SAML provider's updated IdP entity ID. If not provided, the existing
  /// configuration's value is not modified.
  final String? idpEntityId;

  /// The SAML provider's updated SSO URL. If not provided, the existing
  /// configuration's value is not modified.
  final String? ssoURL;

  /// The SAML provider's updated list of X.509 certificated. If not provided, the
  /// existing configuration list is not modified.
  final List<String>? x509Certificates;

  /// The SAML provider's updated RP entity ID. If not provided, the existing
  /// configuration's value is not modified.
  final String? rpEntityId;

  /// The SAML provider's callback URL. If not provided, the existing
  /// configuration's value is not modified.
  final String? callbackURL;
}

/// The request interface for updating a SAML Auth provider. This is used
/// when updating a SAML provider's configuration via
/// [_BaseAuth.updateProviderConfig].
class SAMLUpdateAuthProviderRequest extends _SAMLAuthProviderRequestBase
    implements UpdateAuthProviderRequest {
  SAMLUpdateAuthProviderRequest({
    super.displayName,
    super.enabled,
    super.idpEntityId,
    super.ssoURL,
    super.x509Certificates,
    super.rpEntityId,
    super.callbackURL,
  });

  @override
  bool? get enableRequestSigning => null;

  @override
  String? get issuer => null;

  @override
  String? get providerId => null;
}

abstract class _OIDCAuthProviderRequestBase {
  _OIDCAuthProviderRequestBase({
    this.displayName,
    this.enabled,
    this.clientId,
    this.issuer,
    this.clientSecret,
    this.responseType,
  });

  /// The OIDC provider's updated provider ID. If not provided, the existing
  /// configuration's value is not modified.
  String? get providerId;

  /// The OIDC provider's updated display name. If not provided, the existing
  /// configuration's value is not modified.
  final String? displayName;

  /// Whether the OIDC provider is enabled or not. If not provided, the existing
  /// configuration's setting is not modified.
  final bool? enabled;

  /// The OIDC provider's updated client ID. If not provided, the existing
  /// configuration's value is not modified.
  final String? clientId;

  /// The OIDC provider's updated issuer. If not provided, the existing
  /// configuration's value is not modified.
  final String? issuer;

  /// The OIDC provider's client secret to enable OIDC code flow.
  /// If not provided, the existing configuration's value is not modified.
  final String? clientSecret;

  /// The OIDC provider's response object for OAuth authorization flow.
  final OAuthResponseType? responseType;
}

/// The request interface for updating an OIDC Auth provider. This is used
/// when updating an OIDC provider's configuration via
/// [_BaseAuth.updateProviderConfig].
class OIDCUpdateAuthProviderRequest extends _OIDCAuthProviderRequestBase
    implements UpdateAuthProviderRequest {
  OIDCUpdateAuthProviderRequest({
    super.displayName,
    super.enabled,
    super.clientId,
    super.issuer,
    super.clientSecret,
    super.responseType,
  });

  @override
  String? get providerId => null;
}

sealed class AuthProviderConfig {
  AuthProviderConfig._({
    required this.providerId,
    required this.displayName,
    required this.enabled,
  });

  /// The provider ID defined by the developer.
  /// For a SAML provider, this is always prefixed by `saml.`.
  /// For an OIDC provider, this is always prefixed by `oidc.`.
  final String providerId;

  /// The user-friendly display name to the current configuration. This name is
  /// also used as the provider label in the Cloud Console.
  final String? displayName;

  /// Whether the provider configuration is enabled or disabled. A user
  /// cannot sign in using a disabled provider.
  final bool enabled;
}

/// The
/// [SAML](http://docs.oasis-open.org/security/saml/Post2.0/sstc-saml-tech-overview-2.0.html)
/// Auth provider configuration interface. A SAML provider can be created via
/// [_BaseAuth.createProviderConfig].
class SAMLAuthProviderConfig extends AuthProviderConfig
    implements _SAMLAuthProviderRequestBase {
  SAMLAuthProviderConfig({
    required this.idpEntityId,
    required this.ssoURL,
    required this.x509Certificates,
    required this.rpEntityId,
    this.callbackURL,
    required super.providerId,
    super.displayName,
    required super.enabled,
    this.issuer,
    this.enableRequestSigning,
  }) : super._();

  factory SAMLAuthProviderConfig.fromResponse(
    v2.GoogleCloudIdentitytoolkitAdminV2InboundSamlConfig response,
  ) {
    final idpConfig = response.idpConfig;
    final idpEntityId = idpConfig?.idpEntityId;
    final ssoURL = idpConfig?.ssoUrl;
    final spConfig = response.spConfig;
    final spEntityId = spConfig?.spEntityId;
    final providerId = response.name.let(
      SAMLAuthProviderConfig.getProviderIdFromResourceName,
    );

    if (idpConfig == null ||
        idpEntityId == null ||
        ssoURL == null ||
        spConfig == null ||
        spEntityId == null ||
        providerId == null) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.internalError,
        'INTERNAL ASSERT FAILED: Invalid SAML configuration response',
      );
    }

    return SAMLAuthProviderConfig(
      idpEntityId: idpEntityId,
      ssoURL: ssoURL,
      x509Certificates: [
        ...?idpConfig.idpCertificates?.map((c) => c.x509Certificate).nonNulls,
      ],
      rpEntityId: spEntityId,
      callbackURL: spConfig.callbackUri,
      providerId: providerId,
      displayName: response.displayName,
      enabled: response.enabled ?? false,
    );
  }

  /// The SAML IdP entity identifier.
  @override
  final String idpEntityId;

  /// The SAML IdP SSO URL. This must be a valid URL.
  @override
  final String ssoURL;

  /// The list of SAML IdP X.509 certificates issued by CA for this provider.
  /// Multiple certificates are accepted to prevent outages during
  /// IdP key rotation (for example ADFS rotates every 10 days). When the Auth
  /// server receives a SAML response, it will match the SAML response with the
  /// certificate on record. Otherwise the response is rejected.
  /// Developers are expected to manage the certificate updates as keys are
  /// rotated.
  @override
  final List<String> x509Certificates;

  /// The SAML relying party (service provider) entity ID.
  /// This is defined by the developer but needs to be provided to the SAML IdP.
  @override
  final String rpEntityId;

  /// This is fixed and must always be the same as the OAuth redirect URL
  /// provisioned by Firebase Auth,
  /// `https://project-id.firebaseapp.com/__/auth/handler` unless a custom
  /// `authDomain` is used.
  /// The callback URL should also be provided to the SAML IdP during
  /// configuration.
  @override
  final String? callbackURL;

  @override
  final bool? enableRequestSigning;

  @override
  final String? issuer;

  static v2.GoogleCloudIdentitytoolkitAdminV2InboundSamlConfig?
  _buildServerRequest(
    _SAMLAuthProviderRequestBase options, {
    bool ignoreMissingFields = false,
  }) {
    final makeRequest = options.providerId != null || ignoreMissingFields;
    if (!makeRequest) return null;

    SAMLAuthProviderConfig._validate(
      options,
      ignoreMissingFields: ignoreMissingFields,
    );

    return v2.GoogleCloudIdentitytoolkitAdminV2InboundSamlConfig(
      enabled: options.enabled,
      displayName: options.displayName,
      spConfig: options.callbackURL == null && options.rpEntityId == null
          ? null
          : v2.GoogleCloudIdentitytoolkitAdminV2SpConfig(
              callbackUri: options.callbackURL,
              spEntityId: options.rpEntityId,
            ),
      idpConfig:
          options.idpEntityId == null &&
              options.ssoURL == null &&
              options.x509Certificates == null
          ? null
          : v2.GoogleCloudIdentitytoolkitAdminV2IdpConfig(
              idpEntityId: options.idpEntityId,
              ssoUrl: options.ssoURL,
              signRequest: options.enableRequestSigning,
              idpCertificates: options.x509Certificates
                  ?.map(
                    (c) => v2.GoogleCloudIdentitytoolkitAdminV2IdpCertificate(
                      x509Certificate: c,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  static String? getProviderIdFromResourceName(String resourceName) {
    // name is of form projects/project1/inboundSamlConfigs/providerId1
    final matchProviderRes = RegExp(
      r'\/inboundSamlConfigs\/(saml\..*)$',
    ).firstMatch(resourceName);
    if (matchProviderRes == null || matchProviderRes.groupCount < 1) {
      return null;
    }
    return matchProviderRes[1];
  }

  static bool isProviderId(String providerId) {
    return providerId.startsWith('saml.') && isSafeUrlSegment(providerId);
  }

  static void _validate(
    _SAMLAuthProviderRequestBase options, {
    required bool ignoreMissingFields,
  }) {
    // Required fields.
    final providerId = options.providerId;
    if (providerId != null && providerId.isNotEmpty) {
      if (!SAMLAuthProviderConfig.isProviderId(providerId)) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.invalidProviderId,
          '"SAMLAuthProviderConfig.providerId" must be a valid non-empty string prefixed with "saml.".',
        );
      }
    } else if (!ignoreMissingFields) {
      // providerId is required and not provided correctly.
      throw FirebaseAuthAdminException(
        providerId == null
            ? AuthClientErrorCode.missingProviderId
            : AuthClientErrorCode.invalidProviderId,
        '"SAMLAuthProviderConfig.providerId" must be a valid non-empty string prefixed with "saml.".',
      );
    }

    final idpEntityId = options.idpEntityId;
    if (!(ignoreMissingFields && idpEntityId == null) &&
        !(idpEntityId != null && idpEntityId.isNotEmpty)) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.invalidConfig,
        '"SAMLAuthProviderConfig.idpEntityId" must be a valid non-empty string.',
      );
    }

    final ssoURL = options.ssoURL;
    if (!(ignoreMissingFields && ssoURL == null) &&
        Uri.tryParse(ssoURL ?? '') == null) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.invalidConfig,
        '"SAMLAuthProviderConfig.ssoURL" must be a valid URL string.',
      );
    }

    final rpEntityId = options.rpEntityId;
    if (!(ignoreMissingFields && rpEntityId == null) &&
        !(rpEntityId != null && rpEntityId.isNotEmpty)) {
      throw FirebaseAuthAdminException(
        rpEntityId == null
            ? AuthClientErrorCode.missingSamlRelyingPartyConfig
            : AuthClientErrorCode.invalidConfig,
        '"SAMLAuthProviderConfig.rpEntityId" must be a valid non-empty string.',
      );
    }

    final callbackURL = options.callbackURL;
    if (!(ignoreMissingFields && callbackURL == null) &&
        (callbackURL != null && Uri.tryParse(callbackURL) == null)) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.invalidConfig,
        '"SAMLAuthProviderConfig.callbackURL" must be a valid URL string.',
      );
    }

    final x509Certificates = options.x509Certificates;
    if (!(ignoreMissingFields && x509Certificates == null) &&
        x509Certificates == null) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.invalidConfig,
        '"SAMLAuthProviderConfig.x509Certificates" must be a valid array of X509 certificate strings.',
      );
    }
  }
}

/// The [OIDC](https://openid.net/specs/openid-connect-core-1_0-final.html) Auth
/// provider configuration interface. An OIDC provider can be created via
/// [_BaseAuth.createProviderConfig].
class OIDCAuthProviderConfig extends AuthProviderConfig
    implements _OIDCAuthProviderRequestBase {
  OIDCAuthProviderConfig({
    required super.providerId,
    super.displayName,
    required super.enabled,
    required this.clientId,
    required this.issuer,
    this.clientSecret,
    this.responseType,
  }) : super._();

  factory OIDCAuthProviderConfig.fromResponse(
    v2.GoogleCloudIdentitytoolkitAdminV2OAuthIdpConfig response,
  ) {
    final issuer = response.issuer;
    final clientID = response.clientId;
    final name = response.name;
    if (issuer == null || clientID == null || name == null) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.invalidArgument,
        'INTERNAL ASSERT FAILED: Invalid OIDC configuration response',
      );
    }

    final providerId = OIDCAuthProviderConfig.getProviderIdFromResourceName(
      name,
    );
    if (providerId == null) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.internalError,
        'INTERNAL ASSERT FAILED: Invalid OIDC configuration response',
      );
    }

    return OIDCAuthProviderConfig(
      providerId: providerId,
      displayName: response.displayName,
      enabled: response.enabled ?? false,
      clientId: clientID,
      issuer: issuer,
      clientSecret: response.clientSecret,
      responseType: response.responseType.let((responseType) {
        return OAuthResponseType._(
          idToken: responseType.idToken,
          code: responseType.code,
        );
      }),
    );
  }

  /// This is the required client ID used to confirm the audience of an OIDC
  /// provider's
  /// [ID token](https://openid.net/specs/openid-connect-core-1_0-final.html#IDToken).
  @override
  final String clientId;

  /// This is the required provider issuer used to match the provider issuer of
  /// the ID token and to determine the corresponding OIDC discovery document, eg.
  /// [`/.well-known/openid-configuration`](https://openid.net/specs/openid-connect-discovery-1_0.html#ProviderConfig).
  /// This is needed for the following:
  /// <ul>
  /// <li>To verify the provided issuer.</li>
  /// <li>Determine the authentication/authorization endpoint during the OAuth
  ///     `id_token` authentication flow.</li>
  /// <li>To retrieve the public signing keys via `jwks_uri` to verify the OIDC
  ///     provider's ID token's signature.</li>
  /// <li>To determine the claims_supported to construct the user attributes to be
  ///     returned in the additional user info response.</li>
  /// </ul>
  /// ID token validation will be performed as defined in the
  /// [spec](https://openid.net/specs/openid-connect-core-1_0.html#IDTokenValidation).
  @override
  final String issuer;

  /// The OIDC provider's client secret to enable OIDC code flow.
  @override
  final String? clientSecret;

  /// The OIDC provider's response object for OAuth authorization flow.
  @override
  final OAuthResponseType? responseType;

  static void _validate(
    _OIDCAuthProviderRequestBase options, {
    required bool ignoreMissingFields,
  }) {
    if (options.providerId case final providerId? when providerId.isNotEmpty) {
      if (!OIDCAuthProviderConfig.isProviderId(providerId)) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.invalidArgument,
          '"OIDCAuthProviderConfig.providerId" must be a valid non-empty string prefixed with "oidc.".',
        );
      }
    } else if (!ignoreMissingFields) {
      throw FirebaseAuthAdminException(
        options.providerId == null
            ? AuthClientErrorCode.missingProviderId
            : AuthClientErrorCode.invalidProviderId,
        '"OIDCAuthProviderConfig.providerId" must be a valid non-empty string prefixed with "oidc.".',
      );
    }

    final clientId = options.clientId;
    if (!(ignoreMissingFields && clientId == null) &&
        (clientId == null || clientId.isEmpty)) {
      throw FirebaseAuthAdminException(
        clientId == null
            ? AuthClientErrorCode.missingOauthClientId
            : AuthClientErrorCode.invalidOauthClientId,
        '"OIDCAuthProviderConfig.clientId" must be a valid non-empty string.',
      );
    }

    final issuer = options.issuer;
    if (!(ignoreMissingFields && issuer == null) &&
        (issuer == null || Uri.tryParse(issuer) == null)) {
      throw FirebaseAuthAdminException(
        issuer == null
            ? AuthClientErrorCode.missingIssuer
            : AuthClientErrorCode.invalidConfig,
        '"OIDCAuthProviderConfig.issuer" must be a valid URL string.',
      );
    }

    final clientSecret = options.clientSecret;
    if (!(ignoreMissingFields && clientSecret == null) &&
        (clientSecret == null || clientSecret.isEmpty)) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.invalidConfig,
        '"OIDCAuthProviderConfig.clientSecret" must be a valid non-empty string.',
      );
    }

    final responseType = options.responseType;
    if (responseType != null) {
      final code = responseType.code;

      // If code flow is enabled, client secret must be provided.
      if (code != null && options.clientSecret == null) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.missingOauthClientSecret,
          'The OAuth configuration client secret is required to enable OIDC code flow.',
        );
      }

      if ((responseType.code ?? false) && (responseType.idToken ?? false)) {
        throw FirebaseAuthAdminException(
          AuthClientErrorCode.invalidOauthResponseType,
          'Only exactly one OAuth responseType should be set to true.',
        );
      }
    }
  }

  static v2.GoogleCloudIdentitytoolkitAdminV2OAuthIdpConfig?
  _buildServerRequest(
    _OIDCAuthProviderRequestBase options, {
    bool ignoreMissingFields = false,
  }) {
    final makeRequest = options.providerId != null || ignoreMissingFields;
    if (!makeRequest) return null;

    OIDCAuthProviderConfig._validate(
      options,
      ignoreMissingFields: ignoreMissingFields,
    );

    return v2.GoogleCloudIdentitytoolkitAdminV2OAuthIdpConfig(
      enabled: options.enabled,
      displayName: options.displayName,
      issuer: options.issuer,
      clientId: options.clientId,
      clientSecret: options.clientSecret,
      responseType: options.responseType.let((responseType) {
        return v2.GoogleCloudIdentitytoolkitAdminV2OAuthResponseType(
          idToken: responseType.idToken,
          code: responseType.code,
        );
      }),
    );
  }

  /// Returns the provider ID corresponding to the resource name if available.
  static String? getProviderIdFromResourceName(String resourceName) {
    // name is of form projects/project1/oauthIdpConfigs/providerId1
    final matchProviderRes = RegExp(
      r'\/oauthIdpConfigs\/(oidc\..*)$',
    ).firstMatch(resourceName);
    if (matchProviderRes == null || matchProviderRes.groupCount < 1) {
      return null;
    }
    return matchProviderRes[1];
  }

  static bool isProviderId(String providerId) {
    return providerId.startsWith('oidc.') && isSafeUrlSegment(providerId);
  }
}

/// The interface representing OIDC provider's response object for OAuth
/// authorization flow.
/// One of the following settings is required:
/// <ul>
/// <li>Set <code>code</code> to <code>true</code> for the code flow.</li>
/// <li>Set <code>idToken</code> to <code>true</code> for the ID token flow.</li>
/// </ul>
class OAuthResponseType {
  OAuthResponseType._({required this.idToken, required this.code});

  /// Whether ID token is returned from IdP's authorization endpoint.
  final bool? idToken;

  /// Whether authorization code is returned from IdP's authorization endpoint.
  final bool? code;
}

const _sentinel = _Sentinel();

class _Sentinel {
  const _Sentinel();
}

/// An object used to differentiate "no value" from "a null value".
///
/// This is typically used to enable `update(displayName: null)`.
class _Box<T> {
  _Box(this.value);

  static _Box<T?>? unwrap<T>(Object? value) {
    if (value == _sentinel) return null;
    return _Box(value as T?);
  }

  final T value;
}

/// Interface representing the properties to set on a new user record to be
/// created.
class CreateRequest extends _BaseUpdateRequest {
  CreateRequest({
    super.disabled,
    super.displayName,
    super.email,
    super.emailVerified,
    super.password,
    super.phoneNumber,
    super.photoURL,
    this.multiFactor,
    this.uid,
  }) : assert(
         multiFactor is! MultiFactorUpdateSettings,
         'MultiFactorUpdateSettings is not supported for create requests.',
       );

  /// The user's `uid`.
  final String? uid;

  /// The user's multi-factor related properties.
  final MultiFactorCreateSettings? multiFactor;
}

/// Interface representing the properties to update on the provided user.
class UpdateRequest extends _BaseUpdateRequest {
  /// Interface representing the properties to update on the provided user.
  UpdateRequest({
    super.disabled,
    String? super.displayName,
    super.email,
    super.emailVerified,
    super.password,
    String? super.phoneNumber,
    String? super.photoURL,
    this.multiFactor,
    this.providerToLink,
    this.providersToUnlink,
  });

  UpdateRequest._({
    super.disabled,
    super.displayName,
    super.email,
    super.emailVerified,
    super.password,
    super.phoneNumber,
    super.photoURL,
    this.multiFactor,
    this.providerToLink,
    this.providersToUnlink,
  });

  /// The user's updated multi-factor related properties.
  final MultiFactorUpdateSettings? multiFactor;

  /// Links this user to the specified provider.
  ///
  /// Linking a provider to an existing user account does not invalidate the
  /// refresh token of that account. In other words, the existing account
  /// would continue to be able to access resources, despite not having used
  /// the newly linked provider to log in. If you wish to force the user to
  /// authenticate with this new provider, you need to (a) revoke their
  /// refresh token (see
  /// https://firebase.google.com/docs/auth/admin/manage-sessions#revoke_refresh_tokens),
  /// and (b) ensure no other authentication methods are present on this
  /// account.
  final UserProvider? providerToLink;

  /// Unlinks this user from the specified providers.
  final List<String>? providersToUnlink;

  UpdateRequest Function({String? email, String? phoneNumber}) get copyWith {
    return ({Object? email = _sentinel, Object? phoneNumber = _sentinel}) {
      return UpdateRequest._(
        disabled: disabled,
        displayName: displayName,
        email: email == _sentinel ? this.email : email as String?,
        emailVerified: emailVerified,
        password: password,
        phoneNumber: phoneNumber == _sentinel
            ? this.phoneNumber
            : phoneNumber as String?,
        photoURL: photoURL,
        multiFactor: multiFactor,
        providerToLink: providerToLink,
        providersToUnlink: providersToUnlink,
      );
    };
  }
}

class _BaseUpdateRequest {
  /// A base request to update a user.
  /// This supports differentiating between unset properties and clearing
  /// properties by setting them to `null`.
  ///
  /// As in `UpdateRequest()` vs `UpdateRequest(displayName: null)`.
  ///
  /// Use [UpdateRequest] directly instead, as this constructor has some
  /// untyped parameters.
  _BaseUpdateRequest({
    required this.disabled,
    Object? displayName = _sentinel,
    required this.email,
    required this.emailVerified,
    required this.password,
    Object? phoneNumber = _sentinel,
    Object? photoURL = _sentinel,
  }) : displayName = _Box.unwrap(displayName),
       phoneNumber = _Box.unwrap(phoneNumber),
       photoURL = _Box.unwrap(photoURL);

  /// Whether or not the user is disabled: `true` for disabled;
  /// `false` for enabled.
  final bool? disabled;

  /// The user's display name.
  final _Box<String?>? displayName;

  /// The user's primary email.
  final String? email;

  /// Whether or not the user's primary email is verified.
  final bool? emailVerified;

  /// The user's unhashed password.
  final String? password;

  /// The user's primary phone number.
  final _Box<String?>? phoneNumber;

  /// The user's photo URL.
  final _Box<String?>? photoURL;
}

/// Represents a user identity provider that can be associated with a Firebase user.
class UserProvider {
  UserProvider({
    this.uid,
    this.displayName,
    this.email,
    this.phoneNumber,
    this.photoURL,
    this.providerId,
  });

  /// The user identifier for the linked provider.
  final String? uid;

  /// The display name for the linked provider.
  final String? displayName;

  /// The email for the linked provider.
  final String? email;

  /// The phone number for the linked provider.
  final String? phoneNumber;

  /// The photo URL for the linked provider.
  final String? photoURL;

  /// The linked provider ID (for example, "google.com" for the Google provider).
  final String? providerId;

  v1.GoogleCloudIdentitytoolkitV1ProviderUserInfo _toProviderUserInfo() {
    return v1.GoogleCloudIdentitytoolkitV1ProviderUserInfo(
      displayName: displayName,
      email: email,
      phoneNumber: phoneNumber,
      photoUrl: photoURL,
      providerId: providerId,
      rawId: uid,
    );
  }
}

/// The multi-factor related user settings for update operations.
class MultiFactorUpdateSettings {
  MultiFactorUpdateSettings({this.enrolledFactors});

  /// The updated list of enrolled second factors. The provided list overwrites the user's
  /// existing list of second factors.
  /// When null is passed, all of the user's existing second factors are removed.
  final List<UpdateMultiFactorInfoRequest>? enrolledFactors;

  v1.GoogleCloudIdentitytoolkitV1MfaInfo toMfaInfo() {
    final enrolledFactors = this.enrolledFactors;
    if (enrolledFactors == null || enrolledFactors.isEmpty) {
      // Remove all second factors.
      return v1.GoogleCloudIdentitytoolkitV1MfaInfo();
    }

    return v1.GoogleCloudIdentitytoolkitV1MfaInfo(
      enrollments: enrolledFactors.map((e) => e.toMfaEnrollment()).toList(),
    );
  }
}

/// The multi-factor related user settings for create operations.
class MultiFactorCreateSettings {
  MultiFactorCreateSettings({required this.enrolledFactors});

  /// The created user's list of enrolled second factors.
  final List<CreateMultiFactorInfoRequest> enrolledFactors;
}

/// Interface representing a phone specific user-enrolled second factor for a
/// `CreateRequest`.
class CreatePhoneMultiFactorInfoRequest extends CreateMultiFactorInfoRequest {
  CreatePhoneMultiFactorInfoRequest({
    required super.displayName,
    required this.phoneNumber,
  });

  /// The phone number associated with a phone second factor.
  final String phoneNumber;
}

/// Interface representing base properties of a user-enrolled second factor for a
/// `CreateRequest`.
sealed class CreateMultiFactorInfoRequest {
  CreateMultiFactorInfoRequest({required this.displayName});

  /// The optional display name for an enrolled second factor.
  final String? displayName;

  v1.GoogleCloudIdentitytoolkitV1MfaFactor
  toGoogleCloudIdentitytoolkitV1MfaFactor() {
    return switch (this) {
      CreatePhoneMultiFactorInfoRequest(:final phoneNumber) =>
        v1.GoogleCloudIdentitytoolkitV1MfaFactor(
          displayName: displayName,
          phoneInfo: phoneNumber,
        ),
    };
  }
}

/// Interface representing a phone specific user-enrolled second factor
/// for an `UpdateRequest`.
class UpdatePhoneMultiFactorInfoRequest extends UpdateMultiFactorInfoRequest {
  UpdatePhoneMultiFactorInfoRequest({
    required this.phoneNumber,
    super.uid,
    super.displayName,
    super.enrollmentTime,
  });

  /// The phone number associated with a phone second factor.
  final String phoneNumber;
}

/// Interface representing common properties of a user-enrolled second factor
/// for an `UpdateRequest`.
sealed class UpdateMultiFactorInfoRequest {
  UpdateMultiFactorInfoRequest({
    this.uid,
    this.displayName,
    this.enrollmentTime,
  }) {
    final enrollmentTime = this.enrollmentTime;
    if (enrollmentTime != null && !enrollmentTime.isUtc) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.invalidEnrollmentTime,
        'The second factor "enrollmentTime" for "$uid" must be a valid '
        'UTC date.',
      );
    }
  }

  /// The ID of the enrolled second factor. This ID is unique to the user. When not provided,
  /// a new one is provisioned by the Auth server.
  final String? uid;

  /// The optional display name for an enrolled second factor.
  final String? displayName;

  /// The optional date the second factor was enrolled.
  final DateTime? enrollmentTime;

  v1.GoogleCloudIdentitytoolkitV1MfaEnrollment toMfaEnrollment() {
    return switch (this) {
      UpdatePhoneMultiFactorInfoRequest(:final phoneNumber) =>
        v1.GoogleCloudIdentitytoolkitV1MfaEnrollment(
          mfaEnrollmentId: uid,
          displayName: displayName,
          // Required for all phone second factors.
          phoneInfo: phoneNumber,
          enrolledAt: enrollmentTime?.toUtc().toIso8601String(),
        ),
    };
  }
}
