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
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:google_cloud/constants.dart' as google_cloud;
import 'package:google_cloud/google_cloud.dart' as google_cloud;
import 'package:google_cloud_firestore/google_cloud_firestore.dart'
    as google_cloud_firestore;
import 'package:googleapis/identitytoolkit/v3.dart' as auth3;
import 'package:googleapis_auth/auth_io.dart' as googleapis_auth;
import 'package:http/http.dart';
import 'package:meta/meta.dart';

import '../app_check.dart';
import '../auth.dart';
import '../firestore.dart';
import '../functions.dart';
import '../messaging.dart';
import '../remote_config.dart';
import '../security_rules.dart';
import '../storage.dart';
import 'utils/utils.dart';
import 'version.g.dart';

part 'app/app_exception.dart';
part 'app/app_options.dart';
part 'app/app_registry.dart';
part 'app/credential.dart';
part 'app/emulator_client.dart';
part 'app/environment.dart';
part 'app/exception.dart';
part 'app/firebase_app.dart';
part 'app/firebase_service.dart';
part 'app/firebase_user_agent_client.dart';
