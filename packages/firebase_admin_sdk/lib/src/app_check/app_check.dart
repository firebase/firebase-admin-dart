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

import 'package:googleapis/firebaseappcheck/v1.dart' as appcheck1;
import 'package:googleapis_auth/auth_io.dart' as googleapis_auth;
import 'package:meta/meta.dart';

import '../app.dart';
import '../utils/jwt.dart';
import 'app_check_api.dart';
import 'token_generator.dart';
import 'token_verifier.dart';

part 'app_check_exception.dart';
part 'app_check_http_client.dart';
part 'app_check_request_handler.dart';

class AppCheck implements FirebaseService {
  /// Creates or returns the cached AppCheck instance for the given app.
  @internal
  factory AppCheck.internal(
    FirebaseApp app, {
    AppCheckRequestHandler? requestHandler,
    AppCheckTokenGenerator? tokenGenerator,
    AppCheckTokenVerifier? tokenVerifier,
  }) {
    return app.getOrInitService(
      FirebaseServiceType.appCheck.name,
      (app) => AppCheck._(
        app,
        requestHandler: requestHandler,
        tokenGenerator: tokenGenerator,
        tokenVerifier: tokenVerifier,
      ),
    );
  }

  AppCheck._(
    this.app, {
    AppCheckRequestHandler? requestHandler,
    AppCheckTokenGenerator? tokenGenerator,
    AppCheckTokenVerifier? tokenVerifier,
  }) : _requestHandler = requestHandler ?? AppCheckRequestHandler(app),
       _tokenGenerator = tokenGenerator ?? AppCheckTokenGenerator(app),
       _appCheckTokenVerifier = tokenVerifier ?? AppCheckTokenVerifier(app);

  @override
  final FirebaseApp app;
  final AppCheckRequestHandler _requestHandler;
  final AppCheckTokenGenerator _tokenGenerator;
  final AppCheckTokenVerifier _appCheckTokenVerifier;

  /// Creates a new [AppCheckToken] that can be sent
  /// back to a client.
  ///
  /// [appId] - The app ID to use as the JWT app_id.
  /// [options] - Optional options object when creating a new App Check Token.
  ///
  /// Returns a future that fulfills with a [AppCheckToken].
  Future<AppCheckToken> createToken(
    String appId, [
    AppCheckTokenOptions? options,
  ]) async {
    if (appId.isEmpty) {
      throw FirebaseAppCheckException(
        AppCheckErrorCode.invalidArgument,
        '`appId` must be a non-empty string.',
      );
    }

    final customToken = await _tokenGenerator.createCustomToken(appId, options);

    return _requestHandler.exchangeToken(customToken, appId);
  }

  /// Verifies a Firebase App Check token (JWT). If the token is valid, the returned
  /// [Future] completes with the token's decoded claims; otherwise, it
  /// throws a [FirebaseAppCheckException].
  ///
  /// [appCheckToken] - The App Check token to verify.
  /// [options] - Optional [VerifyAppCheckTokenOptions] when verifying an App Check Token.
  ///
  /// Returns a [Future] that completes with the token's decoded claims
  ///   if the App Check token is valid; otherwise, throws.
  Future<VerifyAppCheckTokenResponse> verifyToken(
    String appCheckToken, [
    VerifyAppCheckTokenOptions? options,
  ]) async {
    if (appCheckToken.isEmpty) {
      throw FirebaseAppCheckException(
        AppCheckErrorCode.invalidArgument,
        '`appCheckToken` must be a non-empty string.',
      );
    }

    final decodedToken = await _appCheckTokenVerifier.verifyToken(
      appCheckToken,
    );

    if (options?.consume ?? false) {
      final alreadyConsumed = await _requestHandler.verifyReplayProtection(
        appCheckToken,
      );
      return VerifyAppCheckTokenResponse(
        alreadyConsumed: alreadyConsumed,
        appId: decodedToken.appId,
        token: decodedToken,
      );
    }

    return VerifyAppCheckTokenResponse(
      alreadyConsumed: null,
      appId: decodedToken.appId,
      token: decodedToken,
    );
  }

  @override
  Future<void> delete() async {
    // AppCheck service cleanup if needed
  }
}
