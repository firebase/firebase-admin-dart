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

/// Headers that identify a request as originating from this SDK, for
/// Firebase backend usage tracking.
///
/// Shared by `FirebaseUserAgentClient` (used by Auth, Messaging, and other
/// services that go through `FirebaseApp.client`) and the Firestore service,
/// which builds its own HTTP client and can't be wrapped by
/// `FirebaseUserAgentClient` directly.
Map<String, String> get firebaseUserAgentHeaders => {
  'X-Firebase-Client': 'fire-admin-dart/$packageVersion',
  'X-Goog-Api-Client': 'gl-dart/$dartVersion fire-admin/$packageVersion',
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
