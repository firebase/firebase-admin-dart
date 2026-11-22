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

part of 'firestore.dart';

/// The type order as defined by the Firestore backend.
///
/// This enum represents the ordering of different Firestore value types when
/// comparing values of different types. Values are always ordered first by
/// type, then by value within the same type.
enum _TypeOrder {
  nullValue(0),
  booleanValue(1),
  numberValue(2),
  timestampValue(3),
  stringValue(4),
  blobValue(5),
  refValue(6),
  geoPointValue(7),
  arrayValue(8),
  vectorValue(9),
  objectValue(10);

  const _TypeOrder(this.order);
  final int order;
}

/// Detects the value type of a Firestore Value proto.
String _detectValueType(firestore_v1.Value value) {
  if (value.nullValue != null) return 'nullValue';
  if (value.booleanValue != null) return 'booleanValue';
  if (value.integerValue != null) return 'integerValue';
  if (value.doubleValue != null) return 'doubleValue';
  if (value.timestampValue != null) return 'timestampValue';
  if (value.stringValue != null) return 'stringValue';
  if (value.bytesValue != null) return 'bytesValue';
  if (value.referenceValue != null) return 'referenceValue';
  if (value.geoPointValue != null) return 'geoPointValue';
  if (value.arrayValue != null) return 'arrayValue';
  if (value.mapValue != null) {
    // Check if it's a vector (map with 'value' field containing array)
    final fields = value.mapValue?.fields;
    if (fields != null && fields.containsKey('value')) {
      final vectorValue = fields['value'];
      if (vectorValue?.arrayValue != null) {
        return 'vectorValue';
      }
    }
    return 'mapValue';
  }
  throw ArgumentError('Unexpected value type: $value');
}

/// Returns the type order for a given Firestore Value.
_TypeOrder _typeOrder(firestore_v1.Value value) {
  final valueType = _detectValueType(value);

  switch (valueType) {
    case 'nullValue':
      return _TypeOrder.nullValue;
    case 'integerValue':
    case 'doubleValue':
      return _TypeOrder.numberValue;
    case 'stringValue':
      return _TypeOrder.stringValue;
    case 'booleanValue':
      return _TypeOrder.booleanValue;
    case 'arrayValue':
      return _TypeOrder.arrayValue;
    case 'timestampValue':
      return _TypeOrder.timestampValue;
    case 'geoPointValue':
      return _TypeOrder.geoPointValue;
    case 'bytesValue':
      return _TypeOrder.blobValue;
    case 'referenceValue':
      return _TypeOrder.refValue;
    case 'mapValue':
      return _TypeOrder.objectValue;
    case 'vectorValue':
      return _TypeOrder.vectorValue;
    default:
      throw ArgumentError('Unexpected value type: $valueType');
  }
}

/// Compares two primitive values (strings, booleans, or numbers).
///
/// Returns:
/// - -1 if [left] < [right]
/// - 1 if [left] > [right]
/// - 0 if [left] == [right]
int _primitiveComparator(Comparable<Object> left, Comparable<Object> right) {
  return left.compareTo(right);
}

/// Compares two numbers using Firestore semantics for NaN.
///
/// In Firestore ordering:
/// - NaN is less than all other numbers
/// - NaN == NaN
int _compareNumbers(num left, num right) {
  if (left < right) return -1;
  if (left > right) return 1;
  if (left == right) return 0;

  // One or both are NaN
  if (left.isNaN) {
    return right.isNaN ? 0 : -1;
  }
  return 1;
}

/// Compares two Firestore number Value protos (integer or double).
int _compareNumberProtos(firestore_v1.Value left, firestore_v1.Value right) {
  final leftValue = left.integerValue ?? left.doubleValue!;
  final rightValue = right.integerValue ?? right.doubleValue!;

  return _compareNumbers(leftValue, rightValue);
}

/// Compares two Firestore Timestamps.
int _compareTimestampsInternal(
  protobuf_v1.Timestamp? left,
  protobuf_v1.Timestamp? right,
) {
  if (left == null && right == null) return 0;
  if (left == null) return -1;
  if (right == null) return 1;

  final secondsCompare = left.seconds.compareTo(right.seconds);
  if (secondsCompare != 0) return secondsCompare;
  return left.nanos.compareTo(right.nanos);
}

/// Compares two byte arrays (blobs).
int _compareBlobs(Uint8List? left, Uint8List? right) {
  if (left == null && right == null) return 0;
  if (left == null) return -1;
  if (right == null) return 1;

  final length = math.min(left.length, right.length);
  for (var i = 0; i < length; i++) {
    final byteCompare = left[i].compareTo(right[i]);
    if (byteCompare != 0) return byteCompare;
  }
  return left.length.compareTo(right.length);
}

/// Compares two Firestore document reference Value protos.
int _compareReferenceProtos(firestore_v1.Value left, firestore_v1.Value right) {
  final leftPath = _QualifiedResourcePath.fromSlashSeparatedString(
    left.referenceValue!,
  );
  final rightPath = _QualifiedResourcePath.fromSlashSeparatedString(
    right.referenceValue!,
  );
  return leftPath.compareTo(rightPath);
}

/// Compares two Firestore GeoPoint values.
///
/// GeoPoints are compared first by latitude, then by longitude.
int _compareGeoPoints(type_v1.LatLng? left, type_v1.LatLng? right) {
  if (left == null && right == null) return 0;
  if (left == null) return -1;
  if (right == null) return 1;

  final latComparison = _primitiveComparator(left.latitude, right.latitude);
  if (latComparison != 0) return latComparison;

  return _primitiveComparator(left.longitude, right.longitude);
}

/// Compares two Firestore array values element-by-element.
///
/// Arrays are compared element-by-element until a difference is found.
/// If all elements match, the shorter array is considered less than the longer.
int compareArrays(
  List<firestore_v1.Value> left,
  List<firestore_v1.Value> right,
) {
  for (var i = 0; i < left.length && i < right.length; i++) {
    final valueComparison = compare(left[i], right[i]);
    if (valueComparison != 0) {
      return valueComparison;
    }
  }
  // If all values matched, compare lengths
  return _primitiveComparator(left.length, right.length);
}

/// Compares two Firestore map (object) values.
///
/// Maps are compared by iterating over their keys in sorted order and comparing
/// values for each key. If all compared keys match, the map with fewer keys is
/// considered less than the one with more keys.
int _compareObjects(
  Map<String, firestore_v1.Value>? left,
  Map<String, firestore_v1.Value>? right,
) {
  if (left == null && right == null) return 0;
  if (left == null) return -1;
  if (right == null) return 1;

  final leftKeys = left.keys.toList()..sort(_compareUtf8Strings);
  final rightKeys = right.keys.toList()..sort(_compareUtf8Strings);

  for (var i = 0; i < leftKeys.length && i < rightKeys.length; i++) {
    final keyComparison = _compareUtf8Strings(leftKeys[i], rightKeys[i]);
    if (keyComparison != 0) {
      return keyComparison;
    }
    final key = leftKeys[i];
    final valueComparison = compare(left[key]!, right[key]!);
    if (valueComparison != 0) {
      return valueComparison;
    }
  }
  // If all keys matched, compare lengths
  return _primitiveComparator(leftKeys.length, rightKeys.length);
}

/// Compares two Firestore vector values.
///
/// Vectors are stored as maps with a 'value' field containing an array.
/// They are compared first by length, then element-by-element.
int _compareVectors(
  Map<String, firestore_v1.Value>? left,
  Map<String, firestore_v1.Value>? right,
) {
  if (left == null && right == null) return 0;
  if (left == null) return -1;
  if (right == null) return 1;

  final leftArray = left['value']?.arrayValue?.values ?? [];
  final rightArray = right['value']?.arrayValue?.values ?? [];

  final lengthCompare = _primitiveComparator(
    leftArray.length,
    rightArray.length,
  );
  if (lengthCompare != 0) {
    return lengthCompare;
  }

  return compareArrays(leftArray, rightArray);
}

/// Compares strings in UTF-8 encoded byte order.
///
/// This comparison ensures consistent ordering with Firestore's backend by
/// comparing UTF-16 code units while handling surrogate pairs correctly.
///
/// The comparison works by finding the first differing character in the strings
/// and using that to determine the relative ordering. There are two cases:
///
/// Case 1: Both characters are non-surrogates or both are surrogates from a
/// surrogate pair. Their numeric order as UTF-16 code units matches the
/// lexicographical order of their corresponding UTF-8 byte sequences.
///
/// Case 2: One character is a surrogate and the other is not. The surrogate-
/// containing string is always ordered after the non-surrogate because
/// surrogates represent code points > 0xFFFF which have 4-byte UTF-8
/// representations that are lexicographically greater than 1, 2, or 3-byte
/// representations of code points <= 0xFFFF.
int _compareUtf8Strings(String left, String right) {
  final length = math.min(left.length, right.length);
  for (var i = 0; i < length; i++) {
    final leftChar = left[i];
    final rightChar = right[i];
    if (leftChar != rightChar) {
      final leftIsSurrogate = _isSurrogate(leftChar);
      final rightIsSurrogate = _isSurrogate(rightChar);

      if (leftIsSurrogate == rightIsSurrogate) {
        return _primitiveComparator(leftChar, rightChar);
      } else {
        return leftIsSurrogate ? 1 : -1;
      }
    }
  }

  // Use the lengths of the strings to determine the overall comparison
  return _primitiveComparator(left.length, right.length);
}

const _minSurrogate = 0xD800;
const _maxSurrogate = 0xDFFF;

/// Checks if a character is a UTF-16 surrogate.
bool _isSurrogate(String char) {
  if (char.isEmpty) return false;
  final code = char.codeUnitAt(0);
  return code >= _minSurrogate && code <= _maxSurrogate;
}

/// Compares two Firestore Value protos using Firestore's ordering semantics.
///
/// Values are compared first by type (according to [_TypeOrder]), then by
/// value within the same type. This matches the ordering used by Firestore
/// for query results and cursors.
///
/// Returns:
/// - -1 if [left] < [right]
/// - 1 if [left] > [right]
/// - 0 if [left] == [right]
int compare(firestore_v1.Value left, firestore_v1.Value right) {
  // First compare types
  final leftType = _typeOrder(left);
  final rightType = _typeOrder(right);
  final typeComparison = _primitiveComparator(leftType.order, rightType.order);
  if (typeComparison != 0) {
    return typeComparison;
  }

  // Same type, compare values
  switch (leftType) {
    case _TypeOrder.nullValue:
      // All nulls are equal
      return 0;
    case _TypeOrder.booleanValue:
      // Booleans: false < true
      final leftBool = left.booleanValue!;
      final rightBool = right.booleanValue!;
      if (leftBool == rightBool) return 0;
      return leftBool ? 1 : -1;
    case _TypeOrder.stringValue:
      return _compareUtf8Strings(left.stringValue!, right.stringValue!);
    case _TypeOrder.numberValue:
      return _compareNumberProtos(left, right);
    case _TypeOrder.timestampValue:
      return _compareTimestampsInternal(
        left.timestampValue,
        right.timestampValue,
      );
    case _TypeOrder.blobValue:
      return _compareBlobs(left.bytesValue, right.bytesValue);
    case _TypeOrder.refValue:
      return _compareReferenceProtos(left, right);
    case _TypeOrder.geoPointValue:
      return _compareGeoPoints(left.geoPointValue, right.geoPointValue);
    case _TypeOrder.arrayValue:
      return compareArrays(
        left.arrayValue?.values ?? [],
        right.arrayValue?.values ?? [],
      );
    case _TypeOrder.objectValue:
      return _compareObjects(left.mapValue?.fields, right.mapValue?.fields);
    case _TypeOrder.vectorValue:
      return _compareVectors(left.mapValue?.fields, right.mapValue?.fields);
  }
}
