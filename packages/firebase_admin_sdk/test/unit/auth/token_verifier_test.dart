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

import 'package:firebase_admin_sdk/src/auth.dart';
import 'package:test/test.dart';

void main() {
  group('DecodedIdToken', () {
    test('.fromMap', () async {
      final idToken = DecodedIdToken.fromMap({
        'aud': 'mock-aud',
        'auth_time': 1,
        'email': 'mock-email',
        'email_verified': true,
        'exp': 1,
        'firebase': {
          'identities': {'email': 'mock-email'},
          'sign_in_provider': 'mock-sign-in-provider',
          'sign_in_second_factor': 'mock-sign-in-second-factor',
          'second_factor_identifier': 'mock-second-factor-identifier',
          'tenant': 'mock-tenant',
        },
        'iat': 1,
        'iss': 'mock-iss',
        'phone_number': 'mock-phone-number',
        'picture': 'mock-picture',
        'sub': 'mock-sub',
        'custom_claim': 'mock-custom-claim',
        'isAdmin': true,
        'numberOfTests': 3,
      });
      expect(idToken.aud, 'mock-aud');
      expect(idToken.authTime, DateTime.fromMillisecondsSinceEpoch(1000));
      expect(idToken.email, 'mock-email');
      expect(idToken.emailVerified, true);
      expect(idToken.exp, 1);
      expect(idToken.firebase.identities, {'email': 'mock-email'});
      expect(idToken.firebase.signInProvider, 'mock-sign-in-provider');
      expect(idToken.firebase.signInSecondFactor, 'mock-sign-in-second-factor');
      expect(
        idToken.firebase.secondFactorIdentifier,
        'mock-second-factor-identifier',
      );
      expect(idToken.firebase.tenant, 'mock-tenant');
      expect(idToken.iat, 1);
      expect(idToken.iss, 'mock-iss');
      expect(idToken.phoneNumber, 'mock-phone-number');
      expect(idToken.picture, 'mock-picture');
      expect(idToken.sub, 'mock-sub');
      expect(idToken.uid, 'mock-sub');
      expect(idToken.claims['custom_claim'], 'mock-custom-claim');
      expect(idToken.claims['isAdmin'], true);
      expect(idToken.claims['numberOfTests'], 3);
      expect(idToken.claims.containsKey('aud'), false);
      expect(idToken.claims.containsKey('sub'), false);
    });
  });
}
