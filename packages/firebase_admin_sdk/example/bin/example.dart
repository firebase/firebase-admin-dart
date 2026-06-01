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

// ignore_for_file: unused_import

import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';

import 'package:firebase_admin_sdk_example/app_check_example.dart';
import 'package:firebase_admin_sdk_example/auth_example.dart';
import 'package:firebase_admin_sdk_example/firestore_example.dart';
import 'package:firebase_admin_sdk_example/functions_example.dart';
import 'package:firebase_admin_sdk_example/messaging_example.dart';
import 'package:firebase_admin_sdk_example/security_rules_example.dart';
import 'package:firebase_admin_sdk_example/storage_example.dart';

// To run this example with emulators:
// Run `dart run bin/run_with_emulator.dart` from the `example` directory.
Future<void> main() async {
  final admin = FirebaseApp.initializeApp();

  try {
    // await functionsExample(admin);

    // Uncomment to run auth example
    // await authExample(admin);

    // Uncomment to run project config example
    // await projectConfigExample(admin);

    // Uncomment to run the firestore example
    await firestoreExample(admin);

    // Uncomment to run storage example
    // await storageExample(admin);

    // Uncomment to run tenant example (requires Identity Platform upgrade)
    // await tenantExample(admin);

    // Uncomment to run messaging example (requires valid fcm token)
    // await messagingExample(admin);

    // Uncomment to run app check example (requires a real project and credentials)
    // await appCheckExample(admin);

    // Uncomment to run security rules example (requires a real project and credentials)
    // await securityRulesExample(admin);
  } finally {
    await admin.close();
  }
}
