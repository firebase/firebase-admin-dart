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

import 'package:meta/meta.dart';

import '../auth.dart';

/// Validates that a string is a valid phone number.
@internal
bool isPhoneNumber(String phoneNumber) {
  // Phone number validation is very lax here. Backend will enforce E.164
  // spec compliance and will normalize accordingly.
  // The phone number string must be non-empty and starts with a plus sign.
  final re1 = RegExp(r'^\+');
  // The phone number string must contain at least one alphanumeric character.
  final re2 = RegExp(r'[\da-zA-Z]+');
  return re1.hasMatch(phoneNumber) && re2.hasMatch(phoneNumber);
}

/// Verifies that a string is a valid phone number. Throws otherwise.
@internal
void assertIsPhoneNumber(String phoneNumber) {
  if (!isPhoneNumber(phoneNumber)) {
    throw FirebaseAuthAdminException(AuthClientErrorCode.invalidPhoneNumber);
  }
}

/// Validates that a string is a valid email.
@internal
bool isEmail(String email) {
  // There must at least one character before the @ symbol and another after.
  final re = RegExp(r'^[^@]+@[^@]+$');
  return re.hasMatch(email);
}

/// Verifies that a string is a valid email. Throws otherwise.
@internal
void assertIsEmail(String email) {
  if (!isEmail(email)) {
    throw FirebaseAuthAdminException(AuthClientErrorCode.invalidEmail);
  }
}

/// Validates that a string is a valid Firebase Auth uid.
@internal
bool isUid(String uid) => uid.isNotEmpty && uid.length <= 128;

/// Verifies that a string is a valid Firebase Auth uid. Throws otherwise.
@internal
void assertIsUid(String uid) {
  if (!isUid(uid)) {
    throw FirebaseAuthAdminException(AuthClientErrorCode.invalidUid);
  }
}

/// Validates that a string is a safe URL path segment.
@internal
bool isSafeUrlSegment(String? segment) {
  if (segment == null || segment.isEmpty || segment.endsWith('.')) {
    return false;
  }

  final validUrlSegmentRegExp = RegExp(r'^[a-zA-Z0-9\-_.~]+$');
  return validUrlSegmentRegExp.hasMatch(segment);
}

/// Validates that a string is a valid tenant ID.
@internal
bool isTenantId(String tenantId) => isSafeUrlSegment(tenantId);

/// Verifies that a string is a valid tenant ID. Throws otherwise.
@internal
void assertIsTenantId(String tenantId) {
  if (!isTenantId(tenantId)) {
    throw FirebaseAuthAdminException(AuthClientErrorCode.invalidTenantId);
  }
}

/// Validates that the provided topic is a valid FCM topic name.
bool isTopic(Object? topic) {
  if (topic is! String) return false;

  final validTopicRegExp = RegExp(
    r'^(\/topics\/)?(private\/)?[a-zA-Z0-9-_.~%]+$',
  );
  return validTopicRegExp.hasMatch(topic);
}

/// Validates that a value is a string.
@internal
bool isString(Object? value) => value is String;

/// Validates that a value is a non-empty string.
@internal
bool isNonEmptyString(Object? value) => value is String && value.isNotEmpty;

/// Validates that a string is a non-empty string. Throws otherwise.
@internal
void validateNonEmptyString(Object? value, String name) {
  if (!isNonEmptyString(value)) {
    throw ArgumentError('$name must be a non-empty string');
  }
}

/// Validates that a value is a string. Throws otherwise.
@internal
void validateString(Object? value, String name) {
  if (!isString(value)) {
    throw ArgumentError('$name must be a string');
  }
}

/// Validates that a string is a valid URL.
@internal
bool isURL(String? urlStr) {
  if (urlStr == null || urlStr.isEmpty) return false;

  // Check for illegal characters
  final illegalChars = RegExp(
    r'[^a-z0-9:/?#[\]@!$&'
    "'"
    r'()*+,;=.\-_~%]',
    caseSensitive: false,
  );
  if (illegalChars.hasMatch(urlStr)) {
    return false;
  }

  try {
    final uri = Uri.parse(urlStr);
    // Must have a scheme (http, https, etc.)
    return uri.hasScheme && uri.host.isNotEmpty;
  } catch (e) {
    return false;
  }
}

/// Validates that a string is a valid task ID.
///
/// Task IDs can only contain letters (A-Za-z), numbers (0-9),
/// hyphens (-), or underscores (_). Maximum length is 500 characters.
@internal
bool isValidTaskId(String? taskId) {
  if (taskId == null || taskId.isEmpty || taskId.length > 500) {
    return false;
  }

  final validTaskIdRegex = RegExp(r'^[A-Za-z0-9_-]+$');
  return validTaskIdRegex.hasMatch(taskId);
}
