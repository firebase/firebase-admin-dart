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

part of '../firestore.dart';

bool _valuesEqual(List<firestore_v1.Value>? a, List<firestore_v1.Value>? b) {
  if (a == null) return b == null;
  if (b == null) return false;

  if (a.length != b.length) return false;

  for (final (index, value) in a.indexed) {
    if (!_valueEqual(value, b[index])) return false;
  }

  return true;
}

bool _valueEqual(firestore_v1.Value a, firestore_v1.Value b) {
  switch (a) {
    case firestore_v1.Value(:final arrayValue?):
      return _valuesEqual(arrayValue.values, b.arrayValue?.values);
    case firestore_v1.Value(:final booleanValue?):
      return booleanValue == b.booleanValue;
    case firestore_v1.Value(:final bytesValue?):
      return bytesValue == b.bytesValue;
    case firestore_v1.Value(:final doubleValue?):
      return doubleValue == b.doubleValue;
    case firestore_v1.Value(:final geoPointValue?):
      return geoPointValue.latitude == b.geoPointValue?.latitude &&
          geoPointValue.longitude == b.geoPointValue?.longitude;
    case firestore_v1.Value(:final integerValue?):
      return integerValue == b.integerValue;
    case firestore_v1.Value(:final mapValue?):
      final bMap = b.mapValue;
      if (bMap == null || bMap.fields.length != mapValue.fields.length) {
        return false;
      }

      for (final MapEntry(:key, :value) in mapValue.fields.entries) {
        final bValue = bMap.fields[key];
        if (bValue == null) return false;
        if (!_valueEqual(value, bValue)) return false;
      }
      return true;
    case firestore_v1.Value(:final nullValue?):
      return nullValue == b.nullValue;
    case firestore_v1.Value(:final referenceValue?):
      return referenceValue == b.referenceValue;
    case firestore_v1.Value(:final stringValue?):
      return stringValue == b.stringValue;
    case firestore_v1.Value(:final timestampValue?):
      return timestampValue == b.timestampValue;
  }
  return false;
}

/// Validates that 'value' can be used as a query value.
void _validateQueryValue(String arg, Object? value) {
  _validateUserInput(
    arg,
    value,
    description: 'query constraint',
    options: const _ValidateUserInputOptions(
      allowDeletes: _AllowDeletes.none,
      allowTransform: false,
    ),
  );
}
