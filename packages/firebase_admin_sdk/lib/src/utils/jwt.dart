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

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

const algorithmRS256 = 'RS256';

/// Class for verifying unsigned (emulator) JWTs.
class EmulatorSignatureVerifier implements SignatureVerifier {
  @override
  Future<void> verify(String token) async {
    // Signature checks skipped for emulator; no need to fetch public keys.

    try {
      verifyJwtSignature(token, SecretKey(''));
    } on JWTInvalidException catch (e) {
      // Emulator tokens may have "alg": "none"
      if (e.message == 'unknown algorithm') return;
      if (e.message == 'invalid signature') return;
      rethrow;
    } catch (e) {
      // Emulator tokens may use RS256 with test keys, causing assertion
      // errors when verifying with SecretKey. Skip verification.
      return;
    }
  }
}

@internal
class DecodedToken {
  DecodedToken({required this.header, required this.payload});

  final Map<String, dynamic> header;
  final Map<String, dynamic> payload;
}

abstract class SignatureVerifier {
  Future<void> verify(String token);
}

abstract class KeyFetcher {
  Future<Map<String, JWTKey>> fetchPublicKeys();
}

class UrlKeyFetcher implements KeyFetcher {
  UrlKeyFetcher(this.clientCert, {http.Client? httpClient})
    : _httpClient = httpClient;

  final Uri clientCert;
  final http.Client? _httpClient;

  Map<String, JWTKey>? _publicKeys;
  late DateTime _publicKeysExpireAt;

  @override
  Future<Map<String, JWTKey>> fetchPublicKeys() async {
    if (_shouldRefresh()) return refresh();
    return _publicKeys ?? await refresh();
  }

  bool _shouldRefresh() {
    if (_publicKeys == null) return true;
    return _publicKeysExpireAt.isBefore(DateTime.now());
  }

  Future<Map<String, JWTKey>> refresh() async {
    final response =
        await (_httpClient?.get(clientCert) ?? http.get(clientCert));
    final json = jsonDecode(response.body) as Map<String, Object?>;
    final error = json['error'];
    if (error != null) {
      var errorMessage = 'Error fetching public keys for Google certs: $error';
      final description = json['error_description'];
      if (description != null) {
        errorMessage += ' ($description)';
      }
      throw Exception(errorMessage);
    }

    // reset expire at from previous set of keys.
    _publicKeysExpireAt = DateTime(0);
    final cacheControl = response.headers['cache-control'];
    if (cacheControl != null) {
      final parts = cacheControl.split(',');
      for (final part in parts) {
        final subParts = part.trim().split('=');
        if (subParts[0] == 'max-age') {
          final maxAge = int.parse(subParts[1]);
          // Is "seconds" correct?
          _publicKeysExpireAt = DateTime.now().add(Duration(seconds: maxAge));
        }
      }
    }

    final keys = <String, JWTKey>{};

    for (final entry in json.entries) {
      final pem = entry.value! as String;
      // Google X.509 certs are RSA
      keys[entry.key] = RSAPublicKey.cert(pem);
    }

    return _publicKeys = keys;
  }
}

class JwksFetcher implements KeyFetcher {
  JwksFetcher(this.jwksUrl);
  final Uri jwksUrl;
  Map<String, JWTKey>? _publicKeys;
  int _publicKeysExpireAt = 0;
  static const int hourInMilliseconds = 6 * 60 * 60 * 1000; // 6 hours

  @override
  Future<Map<String, JWTKey>> fetchPublicKeys() async {
    if (_shouldRefresh) return refresh();
    return _publicKeys ?? await refresh();
  }

  bool get _shouldRefresh {
    return _publicKeys == null ||
        _publicKeysExpireAt <= DateTime.now().millisecondsSinceEpoch;
  }

  Future<Map<String, JWTKey>> refresh() async {
    final response = await http.get(jwksUrl);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch JWKS');
    }

    final jwks = jsonDecode(response.body) as Map<String, dynamic>;
    final jwkList = jwks['keys'] as List<dynamic>?;

    if (jwkList == null) {
      throw Exception('Invalid JWKS: missing "keys" array');
    }

    // Reset expire time
    _publicKeysExpireAt = 0;

    final newKeys = <String, JWTKey>{};
    for (final jwkJson in jwkList) {
      final jwk = jwkJson as Map<String, dynamic>;
      final kid = jwk['kid'] as String?;
      if (kid != null) {
        newKeys[kid] = JWTKey.fromJWK(jwk);
      }
    }

    // Set new expiration time
    _publicKeysExpireAt =
        DateTime.now().millisecondsSinceEpoch + hourInMilliseconds;

    return _publicKeys = newKeys;
  }
}

class PublicKeySignatureVerifier implements SignatureVerifier {
  PublicKeySignatureVerifier(this.keyFetcher);

  PublicKeySignatureVerifier.withCertificateUrl(
    Uri clientCert, {
    http.Client? httpClient,
  }) : this(UrlKeyFetcher(clientCert, httpClient: httpClient));

  factory PublicKeySignatureVerifier.withJwksUrl(Uri jwksUrl) {
    return PublicKeySignatureVerifier(JwksFetcher(jwksUrl));
  }

  final KeyFetcher keyFetcher;

  /// Verifies a JWT token.
  ///
  /// This verifies the token's signature. The signing key is selected using the
  /// 'kid' claim in the token's header.
  /// The token's expiration is also verified.
  @override
  Future<void> verify(String token) async {
    try {
      final jwt = JWT.decode(token);
      final kid = jwt.header?['kid'] as String?;

      if (kid == null) {
        throw JwtException(
          JwtErrorCode.noKidInHeader,
          'no-kid-in-header-error',
        );
      }

      final keys = await keyFetcher.fetchPublicKeys();
      final key = keys[kid];

      if (key == null) {
        throw JwtException(JwtErrorCode.noMatchingKid, 'no-matching-kid-error');
      }

      try {
        // Firebase session cookies omit the `typ` header claim, which
        // dart_jsonwebtoken 3.x rejects by default. Disable the check here;
        // signature, issuer, audience, and expiry are validated separately.
        JWT.verify(token, key, checkHeaderType: false);
      } catch (e, stackTrace) {
        Error.throwWithStackTrace(
          JwtException(
            JwtErrorCode.invalidSignature,
            'Error while verifying signature of Firebase ID token: $e',
          ),
          stackTrace,
        );
      }

      // At this point most JWTException's should have been caught in
      // verifyJwtSignature, but we could still get some from JWT.decode above
    } on JWTException catch (e) {
      throw JwtException(
        JwtErrorCode.unknown,
        e is JWTUndefinedException
            ? e.message
            : '${e.runtimeType}: ${e.message}',
      );
    }
  }
}

sealed class SecretOrPublicKey {}

/// Decodes general purpose Firebase JWTs.
///
/// [jwtToken] - JWT token to be decoded.
///
/// Returns a decoded token containing the header and payload.
Future<DecodedToken> decodeJwt(String jwtToken) async {
  final fullDecodedToken = JWT.decode(jwtToken);

  return DecodedToken(
    header: fullDecodedToken.header ?? {},
    payload: Map.from(fullDecodedToken.payload as Map),
  );
}

@internal
void verifyJwtSignature(
  String token,
  JWTKey key, {
  Duration? issueAt,
  Audience? audience,
  String? subject,
  String? issuer,
  String? jwtId,
}) {
  try {
    JWT.verify(
      token,
      key,
      issueAt: issueAt,
      audience: audience,
      subject: subject,
      issuer: issuer,
      jwtId: jwtId,
    );
  } on JWTExpiredException catch (e, stackTrace) {
    Error.throwWithStackTrace(
      JwtException(
        JwtErrorCode.tokenExpired,
        'The provided token has expired. Get a fresh token from your '
        'client app and try again.',
      ),
      stackTrace,
    );
  }
}

/// Jwt error code structure.
class JwtException implements Exception {
  JwtException(this.code, this.message);

  final JwtErrorCode code;
  final String message;
}

/// JWT error codes.
enum JwtErrorCode {
  invalidArgument('invalid-argument'),
  invalidCredential('invalid-credential'),
  tokenExpired('token-expired'),
  invalidSignature('invalid-token'),
  noMatchingKid('no-matching-kid-error'),
  noKidInHeader('no-kid-error'),
  keyFetchError('key-fetch-error'),
  unknown('unknown');

  const JwtErrorCode(this.value);

  final String value;
}
