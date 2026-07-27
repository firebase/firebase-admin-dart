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

import 'dart:io';

import '../version.g.dart';

/// The current Dart SDK version in semver format (e.g. "3.3.0").
String get dartVersion =>
    Platform.version.split(RegExp('[^0-9]')).take(3).join('.');

/// The Firebase Admin SDK's `X-Firebase-Client` identity.
const String _fireAdminFirebaseClientId = 'fire-admin-dart/$packageVersion';

/// The Firebase Admin SDK's tag within `X-Goog-Api-Client`.
const String _fireAdminApiClientTag = 'fire-admin/$packageVersion';

/// Headers that identify a request as originating from this SDK, for
/// Firebase backend usage tracking.
///
/// Used by `FirebaseUserAgentClient`, which wraps HTTP clients (Auth,
/// Messaging, and other services that go through `FirebaseApp.client`) that
/// don't already set a client-identification header of their own.
final Map<String, String> firebaseUserAgentHeaders = Map.unmodifiable({
  'X-Firebase-Client': _fireAdminFirebaseClientId,
  'X-Goog-Api-Client': 'gl-dart/$dartVersion $_fireAdminApiClientTag',
});

/// Headers to attach to Firestore requests to identify them as originating
/// from this SDK, for Firebase backend usage tracking.
///
/// Unlike [firebaseUserAgentHeaders], `X-Goog-Api-Client` here omits the
/// `gl-dart/{version}` runtime tag: `google_cloud_firestore`'s
/// `FirestoreRequestClient` appends this value onto one that
/// `package:google_cloud_rpc` already set (which already carries that tag),
/// so repeating it here would duplicate it.
const Map<String, String> firestoreUsageTrackingHeaders = {
  'X-Firebase-Client': _fireAdminFirebaseClientId,
  'X-Goog-Api-Client': _fireAdminApiClientTag,
};

/// Generates the update mask for the provided object.
/// Note this will ignore the last key with value `null`.
List<String> _generateUpdateMask(Object? obj, String root) {
  if (obj is! Map) return [];

  final updateMask = <String>[];
  for (final key in obj.keys) {
    final nextPath = root.isEmpty ? key.toString() : '$root.$key';
    // We hit maximum path.
    // Consider switching to Set<string> if the list grows too large.
    final maskList = _generateUpdateMask(obj[key], nextPath);
    if (maskList.isNotEmpty) {
      for (final mask in maskList) {
        updateMask.add('$key.$mask');
      }
    } else {
      updateMask.add('$key');
    }
  }
  return updateMask;
}

/// Generates a list of field paths (update mask) for the provided object.
///
/// Returns an empty list if the [obj] is not a [Map].
///
/// All keys present in the map are included in the mask. If a key's value is
/// another map, the paths are extended to the keys of that map. If a key's
/// value is not a map (including primitive values like numbers, strings, and
/// `null`), that key becomes a leaf in the path.
///
/// Example:
/// ```dart
/// generateUpdateMask({'a': 1, 'b': {'c': null, 'd': {}}})
/// // Returns: ['a', 'b.c', 'b.d']
/// ```
List<String> generateUpdateMask(Object? obj) => _generateUpdateMask(obj, '');
