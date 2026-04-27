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

const _algorithmRS256 = 'RS256';

final _clientCertUrl = Uri.parse(
  'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com',
);

class FirebaseTokenInfo {
  FirebaseTokenInfo({
    required this.url,
    required this.verifyApiName,
    required this.jwtName,
    required this.shortName,
    required this.expiredErrorCode,
  }) {
    if (verifyApiName.isEmpty) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.invalidArgument,
        'The JWT verify API name must be a non-empty string.',
      );
    }
    if (jwtName.isEmpty) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.invalidArgument,
        'The JWT public full name must be a non-empty string.',
      );
    }
    if (shortName.isEmpty) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.invalidArgument,
        'The JWT public full name must be a non-empty string.',
      );
    }
  }

  /// Documentation URL.
  final Uri url;

  /// verify API name.
  final String verifyApiName;

  /// The JWT full name.
  final String jwtName;

  /// The JWT short name.
  final String shortName;

  /// JWT Expiration error code.
  final AuthClientErrorCode expiredErrorCode;
}

class FirebaseTokenVerifier {
  FirebaseTokenVerifier({
    required Uri clientCertUrl,
    required this.issuer,
    required this.tokenInfo,
    required this.app,
  }) : _shortNameArticle =
           RegExp(
             '[aeiou]',
             caseSensitive: false,
           ).hasMatch(tokenInfo.shortName[0])
           ? 'an'
           : 'a',
       _signatureVerifier = PublicKeySignatureVerifier.withCertificateUrl(
         clientCertUrl,
       );

  final FirebaseApp app;
  final String _shortNameArticle;
  final Uri issuer;
  final FirebaseTokenInfo tokenInfo;
  final SignatureVerifier _signatureVerifier;

  Future<DecodedIdToken> verifyJWT(
    String jwtToken, {
    bool isEmulator = false,
  }) async {
    final projectId = await app.getProjectId();
    final decoded = await _decodeAndVerify(
      jwtToken,
      projectId: projectId,
      isEmulator: isEmulator,
    );

    return DecodedIdToken.fromMap(decoded.payload);
  }

  Future<DecodedToken> _decodeAndVerify(
    String token, {
    required String projectId,
    required bool isEmulator,
    String? audience,
  }) async {
    final decodedToken = await _safeDecode(token);
    _verifyContent(
      decodedToken,
      projectId: projectId,
      isEmulator: isEmulator,
      audience: audience,
    );

    await _verifySignature(token, isEmulator: isEmulator);
    return DecodedToken(
      header: decodedToken.header ?? {},
      payload: Map.from(decodedToken.payload as Map),
    );
  }

  Future<dart_jsonwebtoken.JWT> _safeDecode(String jtwToken) async {
    try {
      return dart_jsonwebtoken.JWT.decode(jtwToken);
    } catch (error, stackTrace) {
      // JWT.decode() throws JWTUndefinedException for invalid tokens
      // Convert to FirebaseAuthAdminException with auth/argument-error
      final verifyJwtTokenDocsMessage =
          ' See ${tokenInfo.url} '
          'for details on how to retrieve $_shortNameArticle ${tokenInfo.shortName}.';
      final errorMessage =
          '${tokenInfo.jwtName} has invalid format.$verifyJwtTokenDocsMessage';
      Error.throwWithStackTrace(
        FirebaseAuthAdminException(
          AuthClientErrorCode.invalidArgument,
          errorMessage,
        ),
        stackTrace,
      );
    }
  }

  Future<void> _verifySignature(
    String token, {
    required bool isEmulator,
  }) async {
    try {
      final verifier = isEmulator
          ? EmulatorSignatureVerifier()
          : _signatureVerifier;
      await verifier.verify(token);
    } on JwtException catch (error, stackTrace) {
      Error.throwWithStackTrace(_mapJwtErrorToAuthError(error), stackTrace);
    }
  }

  void _verifyContent(
    dart_jsonwebtoken.JWT fullDecodedToken, {
    required String projectId,
    required bool isEmulator,
    String? audience,
  }) {
    Never throws(String message) {
      throw FirebaseAuthAdminException(
        AuthClientErrorCode.invalidArgument,
        message,
      );
    }

    final header = fullDecodedToken.header ?? <String, dynamic>{};
    final payload = fullDecodedToken.payload as Map;

    final projectIdMatchMessage =
        ' Make sure the ${tokenInfo.shortName} comes from the same '
        'Firebase project as the service account used to authenticate this SDK.';
    final verifyJwtTokenDocsMessage =
        ' See ${tokenInfo.url} '
        'for details on how to retrieve $_shortNameArticle ${tokenInfo.shortName}.';

    late final alg = header['alg'];
    late final sub = payload['sub'];

    if (!isEmulator && !header.containsKey('kid')) {
      final isCustomToken = (payload['aud'] == _firebaseAudience);

      late final d = payload['d'];
      final isLegacyCustomToken =
          alg == 'HS256' &&
          payload['v'] == 0 &&
          d is Map &&
          d.containsKey('uid');

      String message;
      if (isCustomToken) {
        message =
            '${tokenInfo.verifyApiName} expects $_shortNameArticle '
            '${tokenInfo.shortName}, but was given a custom token.';
      } else if (isLegacyCustomToken) {
        message =
            '${tokenInfo.verifyApiName} expects $_shortNameArticle '
            '${tokenInfo.shortName}, but was given a legacy custom token.';
      } else {
        message = '${tokenInfo.jwtName} has no "kid" claim.';
      }

      throws(message);
    } else if (!isEmulator && alg != _algorithmRS256) {
      throws(
        '${tokenInfo.jwtName} has incorrect algorithm. '
        'Expected "$_algorithmRS256" but got "$alg".'
        '$verifyJwtTokenDocsMessage',
      );
    } else if (audience != null &&
        !(payload['aud'] as String).contains(audience)) {
      throws(
        '${tokenInfo.jwtName} has incorrect "aud" (audience) claim. '
        'Expected "$audience" but got "${payload['aud']}".'
        '$verifyJwtTokenDocsMessage',
      );
    } else if (audience == null && payload['aud'] != projectId) {
      throws(
        '${tokenInfo.jwtName} has incorrect "aud" (audience) claim. '
        'Expected "$projectId" but got "${payload['aud']}".'
        '$projectIdMatchMessage$verifyJwtTokenDocsMessage',
      );
    } else if (payload['iss'] != '$issuer$projectId') {
      throws(
        '${tokenInfo.jwtName} has incorrect "iss" (issuer) claim. '
        'Expected "$issuer$projectId" but got "${payload['iss']}".'
        '$projectIdMatchMessage$verifyJwtTokenDocsMessage',
      );
    } else if (sub is! String) {
      throws(
        '${tokenInfo.jwtName} has no "sub" (subject) claim.'
        '$verifyJwtTokenDocsMessage',
      );
    } else if (sub.isEmpty) {
      throws(
        '${tokenInfo.jwtName} has an empty string "sub" (subject) claim.'
        '$verifyJwtTokenDocsMessage',
      );
    } else if (sub.length > 128) {
      throws(
        '${tokenInfo.jwtName} has "sub" (subject) claim longer than 128 characters.'
        '$verifyJwtTokenDocsMessage',
      );
    }
  }

  /// Maps JwtError to FirebaseAuthError
  Object _mapJwtErrorToAuthError(JwtException error) {
    final verifyJwtTokenDocsMessage =
        ' See ${tokenInfo.url} '
        'for details on how to retrieve $_shortNameArticle ${tokenInfo.shortName}.';
    if (error.code == JwtErrorCode.tokenExpired) {
      final errorMessage =
          '${tokenInfo.jwtName} has expired. Get a fresh ${tokenInfo.shortName}'
          ' from your client app and try again (auth/${tokenInfo.expiredErrorCode.name}).'
          '$verifyJwtTokenDocsMessage';
      return FirebaseAuthAdminException(
        tokenInfo.expiredErrorCode,
        errorMessage,
      );
    } else if (error.code == JwtErrorCode.invalidSignature) {
      final errorMessage =
          '${tokenInfo.jwtName} has invalid signature.'
          '$verifyJwtTokenDocsMessage';
      return FirebaseAuthAdminException(
        AuthClientErrorCode.invalidArgument,
        errorMessage,
      );
    } else if (error.code == JwtErrorCode.noMatchingKid) {
      final errorMessage =
          '${tokenInfo.jwtName} has "kid" claim which does not '
          'correspond to a known public key. Most likely the ${tokenInfo.shortName} '
          'is expired, so get a fresh token from your client app and try again.';
      return FirebaseAuthAdminException(
        AuthClientErrorCode.invalidArgument,
        errorMessage,
      );
    }
    return FirebaseAuthAdminException(
      AuthClientErrorCode.invalidArgument,
      error.message,
    );
  }
}

class TokenProvider {
  @internal
  TokenProvider({
    required this.identities,
    required this.signInProvider,
    required this.signInSecondFactor,
    required this.secondFactorIdentifier,
    required this.tenant,
  });

  @internal
  TokenProvider.fromMap(Map<Object?, Object?> map)
    : identities = Map.from(map['identities']! as Map),
      signInProvider = map['sign_in_provider']! as String,
      signInSecondFactor = map['sign_in_second_factor'] as String?,
      secondFactorIdentifier = map['second_factor_identifier'] as String?,
      tenant = map['tenant'] as String?;

  /// Provider-specific identity details corresponding
  /// to the provider used to sign in the user.
  Map<String, Object?> identities;

  /// The ID of the provider used to sign in the user.
  /// One of `"anonymous"`, `"password"`, `"facebook.com"`, `"github.com"`,
  /// `"google.com"`, `"twitter.com"`, `"apple.com"`, `"microsoft.com"`,
  /// `"yahoo.com"`, `"phone"`, `"playgames.google.com"`, `"gc.apple.com"`,
  /// or `"custom"`.
  ///
  /// Additional Identity Platform provider IDs include `"linkedin.com"`,
  /// OIDC and SAML identity providers prefixed with `"saml."` and `"oidc."`
  /// respectively.
  String signInProvider;

  /// The type identifier or `factorId` of the second factor, provided the
  /// ID token was obtained from a multi-factor authenticated user.
  /// For phone, this is `"phone"`.
  String? signInSecondFactor;

  /// The `uid` of the second factor used to sign in, provided the
  /// ID token was obtained from a multi-factor authenticated user.
  String? secondFactorIdentifier;

  /// The ID of the tenant the user belongs to, if available.
  String? tenant;
  // TODO allow any key
  // [key: string]: any;
}

/// Interface representing a decoded Firebase ID token, returned from the
/// [_BaseAuth.verifyIdToken] method.
///
/// Firebase ID tokens are OpenID Connect spec-compliant JSON Web Tokens (JWTs).
/// See the
/// [ID Token section of the OpenID Connect spec](http://openid.net/specs/openid-connect-core-1_0.html#IDToken)
/// for more information about the specific properties below.
class DecodedIdToken {
  @internal
  DecodedIdToken({
    required this.aud,
    required this.authTime,
    required this.claims,
    required this.email,
    required this.emailVerified,
    required this.exp,
    required this.firebase,
    required this.iat,
    required this.iss,
    required this.phoneNumber,
    required this.picture,
    required this.sub,
    required this.uid,
  });

  @internal
  factory DecodedIdToken.fromMap(Map<String, Object?> map) {
    final claims = _extractCustomClaims(map);

    return DecodedIdToken(
      aud: map['aud']! as String,
      authTime: DateTime.fromMillisecondsSinceEpoch(
        (map['auth_time']! as int) * 1000,
      ),
      claims: Map.unmodifiable(claims),
      email: map['email'] as String?,
      emailVerified: map['email_verified'] as bool?,
      exp: map['exp']! as int,
      firebase: TokenProvider.fromMap(map['firebase']! as Map),
      iat: map['iat']! as int,
      iss: map['iss']! as String,
      phoneNumber: map['phone_number'] as String?,
      picture: map['picture'] as String?,
      sub: map['sub']! as String,
      uid: map['sub']! as String,
    );
  }

  /// The audience for which this token is intended.
  ///
  /// This value is a string equal to your Firebase project ID, the unique
  /// identifier for your Firebase project, which can be found in your project's
  /// settings](https://console.firebase.google.com/project/_/settings/general/android:com.random.android).
  String aud;

  /// Time, in seconds since the Unix epoch, when the end-user authentication
  /// occurred.
  ///
  /// This value is not set when this particular ID token was created, but when the
  /// user initially logged in to this session. In a single session, the Firebase
  /// SDKs will refresh a user's ID tokens every hour. Each ID token will have a
  /// different [`iat`](#iat) value, but the same `auth_time` value.
  DateTime authTime;

  /// The email of the user to whom the ID token belongs, if available.
  String? email;

  /// Whether or not the email of the user to whom the ID token belongs is
  /// verified, provided the user has an email.
  bool? emailVerified;

  /// The ID token's expiration time, in seconds since the Unix epoch. That is, the
  /// time at which this ID token expires and should no longer be considered valid.
  ///
  /// The Firebase SDKs transparently refresh ID tokens every hour, issuing a new
  /// ID token with up to a one hour expiration.
  int exp;

  /// Information about the sign in event, including which sign in provider was
  /// used and provider-specific identity details.
  ///
  /// This data is provided by the Firebase Authentication service and is a
  /// reserved claim in the ID token.
  TokenProvider firebase;

  /// The ID token's issued-at time, in seconds since the Unix epoch. That is, the
  /// time at which this ID token was issued and should start to be considered
  /// valid.
  ///
  /// The Firebase SDKs transparently refresh ID tokens every hour, issuing a new
  /// ID token with a new issued-at time. If you want to get the time at which the
  /// user session corresponding to the ID token initially occurred, see the
  /// [`auth_time`](#auth_time) property.
  int iat;

  /// The issuer identifier for the issuer of the response.
  ///
  /// This value is a URL with the format
  /// `https://securetoken.google.com/<PROJECT_ID>`, where `<PROJECT_ID>` is the
  /// same project ID specified in the [`aud`](#aud) property.
  String iss;

  /// The phone number of the user to whom the ID token belongs, if available.
  String? phoneNumber;

  /// The photo URL for the user to whom the ID token belongs, if available.
  String? picture;

  /// The `uid` corresponding to the user who the ID token belonged to.
  ///
  /// As a convenience, this value is copied over to the [`uid`](#uid) property.
  String sub;

  /// The `uid` corresponding to the user who the ID token belonged to.
  ///
  /// This value is not actually in the JWT token claims itself. It is added as a
  /// convenience, and is set as the value of the [`sub`](#sub) property.
  String uid;

  /// Other arbitrary claims included in the ID token.
  final Map<String, Object?> claims;
}

/// Extracts custom claims from the raw ID token payload map.
///
/// Custom claims are all claims that are not standard OpenID Connect claims
/// or reserved Firebase claims.
Map<String, Object?> _extractCustomClaims(Map<String, Object?> map) {
  return {...map}..removeWhere(
    (key, _) => const {
      'aud',
      'auth_time',
      'email',
      'email_verified',
      'exp',
      'firebase',
      'iat',
      'iss',
      'phone_number',
      'picture',
      'sub',
    }.contains(key),
  );
}

/// User facing token information related to the Firebase ID token.
final _idTokenInfo = FirebaseTokenInfo(
  url: Uri.parse(
    'https://firebase.google.com/docs/auth/admin/verify-id-tokens',
  ),
  verifyApiName: 'verifyIdToken()',
  jwtName: 'Firebase ID token',
  shortName: 'ID token',
  expiredErrorCode: AuthClientErrorCode.idTokenExpired,
);

/// Creates a new FirebaseTokenVerifier to verify Firebase ID tokens.
FirebaseTokenVerifier _createIdTokenVerifier(FirebaseApp app) {
  return FirebaseTokenVerifier(
    clientCertUrl: _clientCertUrl,
    issuer: Uri.parse('https://securetoken.google.com/'),
    tokenInfo: _idTokenInfo,
    app: app,
  );
}

// URL containing the public keys for Firebase session cookies. This will be updated to a different URL soon.
final _sessionCookieCertUrl = Uri.parse(
  'https://www.googleapis.com/identitytoolkit/v3/relyingparty/publicKeys',
);

/// Creates a new FirebaseTokenVerifier to verify Firebase session cookies.
FirebaseTokenVerifier _createSessionCookieVerifier(FirebaseApp app) {
  return FirebaseTokenVerifier(
    clientCertUrl: _sessionCookieCertUrl,
    issuer: Uri.parse('https://session.firebase.google.com/'),
    tokenInfo: _sessionCookieInfo,
    app: app,
  );
}

/// User facing token information related to the Firebase session cookie.
final _sessionCookieInfo = FirebaseTokenInfo(
  url: Uri.parse('https://firebase.google.com/docs/auth/admin/manage-cookies'),
  verifyApiName: 'verifySessionCookie()',
  jwtName: 'Firebase session cookie',
  shortName: 'session cookie',
  expiredErrorCode: AuthClientErrorCode.sessionCookieExpired,
);
