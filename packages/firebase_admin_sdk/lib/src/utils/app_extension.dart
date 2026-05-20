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

import 'package:googleapis_auth/auth_io.dart';

import '../app.dart';

extension AppExtension on FirebaseApp {
  Future<String> get serviceAccountEmail async =>
      options.credential?.serviceAccountId ??
      (await client).getServiceAccountEmail();

  /// Signs the given data using the IAM Credentials API or local credentials.
  ///
  /// Returns a base64-encoded signature string. In emulator mode, returns an
  /// empty string to produce unsigned tokens.
  Future<String> sign(List<int> data, {String? endpoint}) async {
    if (Environment.isAuthEmulatorEnabled()) return '';

    // When a service account private key is available, sign locally without
    // making an OAuth network call. This avoids a round-trip to the token
    // endpoint and works in unit tests with mock credentials.
    final creds = options.credential?.serviceAccountCredentials;
    if (creds != null) {
      return base64Encode(creds.sign(data));
    }

    return (await client).sign(
      data,
      serviceAccountEmail: options.credential?.serviceAccountId,
      endpoint: endpoint,
    );
  }
}
