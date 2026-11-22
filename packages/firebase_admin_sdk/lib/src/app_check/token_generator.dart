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

import 'package:googleapis_auth/auth_io.dart' as googleapis_auth;
import 'package:meta/meta.dart';

import '../../firebase_admin_sdk.dart';
import '../utils/app_extension.dart';
import 'app_check.dart';
import 'app_check_api.dart';

// Audience to use for Firebase App Check Custom tokens
const firebaseAppCheckAudience =
    'https://firebaseappcheck.googleapis.com/google.firebase.appcheck.v1.TokenExchangeService';

const oneMinuteInSeconds = 60;

/// Class for generating Firebase App Check tokens.
@internal
class AppCheckTokenGenerator {
  AppCheckTokenGenerator(this.app);

  final FirebaseApp app;

  /// Creates a new custom token that can be exchanged to an App Check token.
  ///
  /// [appId] - The Application ID to use for the generated token.
  ///
  /// Returns a [Future] that completes with a custom token signed with a service account key
  /// that can be exchanged to an App Check token.
  Future<String> createCustomToken(
    String appId, [
    AppCheckTokenOptions? options,
  ]) async {
    try {
      final account = await app.serviceAccountEmail;

      final header = {'alg': 'RS256', 'typ': 'JWT'};
      final iat = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
      final body = {
        'iss': account,
        'sub': account,
        'app_id': appId,
        'aud': firebaseAppCheckAudience,
        'exp': iat + (oneMinuteInSeconds * 5),
        'iat': iat,
        if (options?.ttlMillis case final ttl?) 'ttl': '${ttl.inSeconds}s',
      };

      final token = '${_encodeSegment(header)}.${_encodeSegment(body)}';

      final signature = await app.sign(utf8.encode(token));

      return '$token.$signature';
    } on googleapis_auth.ServerRequestFailedException catch (err) {
      throw FirebaseAppCheckException(
        AppCheckErrorCode.invalidCredential,
        err.message,
      );
    }
  }

  String _encodeSegment(Map<String, Object?> segment) {
    return _encodeSegmentBuffer(utf8.encode(jsonEncode(segment)));
  }

  String _encodeSegmentBuffer(List<int> buffer) {
    final base64 = _toWebSafeBase64(buffer);

    return base64.replaceAll(RegExp(r'=+$'), '');
  }

  String _toWebSafeBase64(List<int> data) {
    return base64Encode(data).replaceAll('/', '_').replaceAll('+', '-');
  }
}
