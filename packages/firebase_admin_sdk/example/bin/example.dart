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

import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';

import 'package:firebase_admin_sdk_example/app_check_example.dart';
import 'package:firebase_admin_sdk_example/auth_example.dart';
import 'package:firebase_admin_sdk_example/firestore_example.dart';
import 'package:firebase_admin_sdk_example/functions_example.dart';
import 'package:firebase_admin_sdk_example/messaging_example.dart';
import 'package:firebase_admin_sdk_example/security_rules_example.dart';
import 'package:firebase_admin_sdk_example/storage_example.dart';

// Toggle examples on/off here instead of commenting/uncommenting calls below.
const _runFunctions = false;
const _runAuth = false;
const _runFirestore = true;
const _runStorage = false;
const _runMessaging = false; // requires a valid FCM token
const _runAppCheck = false; // requires a real project and credentials
const _runSecurityRules = false; // requires a real project and credentials

// To run this example with emulators:
// Run `dart run bin/run_with_emulator.dart` from the `example` directory.
Future<void> main() async {
  final admin = FirebaseApp.initializeApp();

  try {
    if (_runFunctions) await functionsExample(admin);
    if (_runAuth) await authExample(admin);
    if (_runFirestore) await firestoreExample(admin);
    if (_runStorage) await storageExample(admin);
    if (_runMessaging) await messagingExample(admin);
    if (_runAppCheck) await appCheckExample(admin);
    if (_runSecurityRules) await securityRulesExample(admin);
  } finally {
    await admin.close();
  }
}
