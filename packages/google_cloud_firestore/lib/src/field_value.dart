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

/// Represents a vector value in Firestore.
///
/// Create an instance with [FieldValue.vector].
@immutable
class VectorValue {
  /// Creates a VectorValue from a list of numbers.
  ///
  /// Makes a copy of the provided list to ensure immutability.
  VectorValue(List<double> values) : _values = List.unmodifiable(values);

  final List<double> _values;

  /// Returns a copy of the raw number array form of the vector.
  List<double> toArray() => List.from(_values);

  /// Returns true if the two VectorValue instances have the same raw number arrays.
  bool isEqual(VectorValue other) {
    if (_values.length != other._values.length) return false;
    for (var i = 0; i < _values.length; i++) {
      if (_values[i] != other._values[i]) return false;
    }
    return true;
  }

  /// Converts this VectorValue to its Firestore protobuf representation.
  firestore_v1.Value _toProto(Serializer serializer) {
    return serializer.encodeVector(_values);
  }

  @override
  bool operator ==(Object other) {
    return other is VectorValue && isEqual(other);
  }

  @override
  int get hashCode => Object.hashAll(_values);
}

abstract class FieldValue {
  /// Returns a special value that can be used with set(), create() or update()
  /// that tells the server to increment the the field's current value by the
  /// given value.
  ///
  /// If either current field value or the operand uses floating point
  /// precision, both values will be interpreted as floating point numbers and
  /// all arithmetic will follow IEEE 754 semantics. Otherwise, integer
  /// precision is kept and the result is capped between -2^63 and 2^63-1.
  ///
  /// If the current field value is not of type 'number', or if the field does
  /// not yet exist, the transformation will set the field to the given value.
  ///
  /// ```dart
  /// final documentRef = firestore.doc('col/doc');
  ///
  /// documentRef.update({
  ///   'counter', Firestore.FieldValue.increment(1),
  /// }).then(() {
  ///   return documentRef.get();
  /// }).then((doc) {
  ///   // doc.get('counter') was incremented
  /// });
  /// ```
  const factory FieldValue.increment(num n) = _NumericIncrementTransform;

  /// Returns a special value that can be used with set(), create() or update()
  /// that tells the server to union the given elements with any array value that
  /// already exists on the server. Each specified element that doesn't already
  /// exist in the array will be added to the end. If the field being modified is
  /// not already an array it will be overwritten with an array containing
  /// exactly the specified elements.
  ///
  /// ```dart
  /// final documentRef = firestore.doc('col/doc');
  ///
  /// documentRef.update({
  ///   'array': Firestore.FieldValue.arrayUnion('foo'),
  /// }).then(() {
  ///   return documentRef.get();
  /// }).then((doc) {
  ///   // doc.get('array') contains field 'foo'
  /// });
  /// ```
  const factory FieldValue.arrayUnion(List<Object?> elements) =
      _ArrayUnionTransform;

  /// Returns a special value that can be used with set(), create() or update()
  /// that tells the server to remove the given elements from any array value
  /// that already exists on the server. All instances of each element specified
  /// will be removed from the array. If the field being modified is not already
  /// an array it will be overwritten with an empty array.
  ///
  /// ```dart
  /// final documentRef = firestore.doc('col/doc');
  ///
  /// documentRef.update({
  ///   'array': Firestore.FieldValue.arrayRemove('foo'),
  /// }).then(() {
  ///   return documentRef.get();
  /// }).then((doc) {
  ///   // doc.get('array') no longer contains field 'foo'
  /// });
  /// ```
  const factory FieldValue.arrayRemove(List<Object?> elements) =
      _ArrayRemoveTransform;

  /// Creates a VectorValue instance from an array of numbers.
  ///
  /// Vector values are used for vector similarity search operations in Firestore.
  ///
  /// ```dart
  /// final vector = FieldValue.vector([1.0, 2.0, 3.0]);
  /// await documentRef.set({'embedding': vector});
  /// ```
  static VectorValue vector(List<double> values) => VectorValue(values);

  /// Returns a sentinel for use with update() to mark a field for deletion.
  ///
  /// ```dart
  /// final documentRef = firestore.doc('col/doc');
  /// final data = { a: 'b', c: 'd' };
  ///
  /// documentRef.set(data).then(() {
  ///   return documentRef.update({a: Firestore.FieldValue.delete()});
  /// }).then(() {
  ///   // Document now only contains { c: 'd' }
  /// });
  /// ```
  static const FieldValue delete = _DeleteTransform.deleteSentinel;

  /// Returns a sentinel used with set(), create() or update() to include a
  /// server-generated timestamp in the written data.
  ///
  /// ```dart
  /// final documentRef = firestore.doc('col/doc');
  ///
  /// documentRef.set({
  ///   'time': Firestore.FieldValue.serverTimestamp()
  /// }).then(() {
  ///   return documentRef.get();
  /// }).then((doc) {
  ///   print('Server time set to ${doc.get('time')}');
  /// });
  /// ```
  static const FieldValue serverTimestamp =
      _ServerTimestampTransform.serverTimestampSentinel;
}

/// An internal interface shared by all field transforms.
//
/// A [_FieldTransform] subclass should implement [includeInDocumentMask],
/// [includeInDocumentTransform] and 'toProto' (if [includeInDocumentTransform]
/// is `true`).
abstract class _FieldTransform implements FieldValue {
  /// Whether this field transform should be included in the document mask.
  bool get includeInDocumentMask;

  /// Whether this field transform should be included in the document transform.
  bool get includeInDocumentTransform;

  /// The method name used to obtain the field transform.
  String get methodName;

  /// Performs input validation on the values of this field transform.
  ///
  /// - `allowUndefined`: Whether to allow nested properties that are undefined
  void validate();

  /// The proto representation for this field transform.
  firestore_v1.DocumentTransform_FieldTransform _toProto(
    Serializer serializer,
    FieldPath fieldPath,
  );
}

/// A transform that deletes a field from a Firestore document.
class _DeleteTransform implements _FieldTransform {
  const _DeleteTransform._();

  /// A sentinel value for a field delete.
  static const deleteSentinel = _DeleteTransform._();

  /// Deletes are included in document masks
  @override
  bool get includeInDocumentMask => true;

  /// Deletes are are omitted from document transforms.
  @override
  bool get includeInDocumentTransform => false;

  @override
  String get methodName => 'FieldValue.delete';

  @override
  void validate() {}

  @override
  firestore_v1.DocumentTransform_FieldTransform _toProto(
    Serializer serializer,
    FieldPath fieldPath,
  ) {
    throw UnsupportedError(
      'FieldValue.delete() should not be included in a FieldTransform',
    );
  }
}

/// Increments a field value on the backend.
@immutable
class _NumericIncrementTransform implements _FieldTransform {
  const _NumericIncrementTransform(this.value);

  /// The value to increment by.
  final num value;

  @override
  bool get includeInDocumentMask => false;

  @override
  bool get includeInDocumentTransform => true;

  @override
  String get methodName => 'FieldValue.increment';

  @override
  void validate() {
    if (value.isNaN) {
      throw ArgumentError.value(
        value,
        'value',
        'Increment transforms require a valid numeric value, but got $value',
      );
    }
  }

  @override
  firestore_v1.DocumentTransform_FieldTransform _toProto(
    Serializer serializer,
    FieldPath fieldPath,
  ) {
    return firestore_v1.DocumentTransform_FieldTransform(
      fieldPath: fieldPath._formattedName,
      increment: serializer.encodeValue(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _NumericIncrementTransform && value == other.value;
  }

  @override
  int get hashCode => value.hashCode;
}

/// Transforms an array value via a union operation.
@immutable
class _ArrayUnionTransform implements _FieldTransform {
  const _ArrayUnionTransform(this.elements);

  final List<Object?> elements;

  @override
  bool get includeInDocumentMask => false;

  @override
  bool get includeInDocumentTransform => true;

  @override
  String get methodName => 'FieldValue.arrayUnion';

  @override
  void validate() {
    elements.forEachIndexed(_validateArrayElement);
  }

  @override
  firestore_v1.DocumentTransform_FieldTransform _toProto(
    Serializer serializer,
    FieldPath fieldPath,
  ) {
    return firestore_v1.DocumentTransform_FieldTransform(
      fieldPath: fieldPath._formattedName,
      appendMissingElements: serializer.encodeValue(elements)!.arrayValue,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _ArrayUnionTransform &&
        const DeepCollectionEquality().equals(elements, other.elements);
  }

  @override
  int get hashCode => const DeepCollectionEquality().hash(elements);
}

/// Transforms an array value via a remove operation.
@immutable
class _ArrayRemoveTransform implements _FieldTransform {
  const _ArrayRemoveTransform(this.elements);

  final List<Object?> elements;

  @override
  bool get includeInDocumentMask => false;

  @override
  bool get includeInDocumentTransform => true;

  @override
  String get methodName => 'FieldValue.arrayRemove';

  @override
  void validate() {
    elements.forEachIndexed(_validateArrayElement);
  }

  @override
  firestore_v1.DocumentTransform_FieldTransform _toProto(
    Serializer serializer,
    FieldPath fieldPath,
  ) {
    return firestore_v1.DocumentTransform_FieldTransform(
      fieldPath: fieldPath._formattedName,
      removeAllFromArray: serializer.encodeValue(elements)!.arrayValue,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _ArrayRemoveTransform &&
        const DeepCollectionEquality().equals(elements, other.elements);
  }

  @override
  int get hashCode => const DeepCollectionEquality().hash(elements);
}

/// A transform that sets a field to the Firestore server time.
class _ServerTimestampTransform implements _FieldTransform {
  const _ServerTimestampTransform();

  static const serverTimestampSentinel = _ServerTimestampTransform();

  @override
  bool get includeInDocumentMask => false;

  @override
  bool get includeInDocumentTransform => true;

  @override
  String get methodName => 'FieldValue.serverTimestamp';

  @override
  firestore_v1.DocumentTransform_FieldTransform _toProto(
    Serializer serializer,
    FieldPath fieldPath,
  ) {
    return firestore_v1.DocumentTransform_FieldTransform(
      fieldPath: fieldPath._formattedName,
      setToServerValue:
          firestore_v1.DocumentTransform_FieldTransform_ServerValue.requestTime,
    );
  }

  @override
  void validate() {}
}

enum _AllowDeletes { none, root, all }

/// The maximum depth of a Firestore object.
const _maxDepth = 20;

class _ValidateUserInputOptions {
  const _ValidateUserInputOptions({
    required this.allowDeletes,
    required this.allowTransform,
  });

  /// At what level field deletes are supported.
  final _AllowDeletes allowDeletes;

  /// Whether server transforms are supported.
  final bool allowTransform;
}

/// Validates a Dart value for usage as a Firestore value.
void _validateUserInput(
  Object arg,
  Object? value, {
  required String description,
  required _ValidateUserInputOptions options,
  int level = 0,
  bool inArray = false,
  FieldPath? path,
}) {
  if (path != null && path._length > _maxDepth) {
    throw ArgumentError.value(
      value,
      description,
      'Firestore objects may not contain more than $_maxDepth levels of nesting or contain a cycle',
    );
  }

  final fieldPathMessage = path == null
      ? ''
      : ' (found in field ${path._formattedName})';

  switch (value) {
    case List<Object?>():
      value.forEachIndexed((index, element) {
        _validateUserInput(
          arg,
          element,
          description: description,
          options: options,
          path: path == null
              ? FieldPath([arg.toString()])
              : path._append(arg.toString()),
          level: level + 1,
          inArray: true,
        );
      });

    case Map<Object?, Object?>():
      for (final entry in value.entries) {
        final keyPath = switch (entry.key) {
          final FieldPath fp => fp,
          final String s => FieldPath([s]),
          _ => FieldPath([entry.key.toString()]),
        };
        _validateUserInput(
          arg,
          entry.value,
          description: description,
          options: options,
          path: path == null ? keyPath : path._appendPath(keyPath),
          level: level + 1,
          inArray: inArray,
        );
      }

    case _DeleteTransform():
      if (inArray) {
        throw ArgumentError.value(
          value,
          value.methodName,
          'cannot be used inside an array$fieldPathMessage',
        );
      } else if (options.allowDeletes == _AllowDeletes.none) {
        throw ArgumentError.value(
          value,
          value.methodName,
          'must appear at the top-level and can only be used in update()$fieldPathMessage.',
        );
      } else if (options.allowDeletes == _AllowDeletes.root) {
        switch (level) {
          case 1:
            // Ok, at the root of update({})
            break;
          default:
            throw ArgumentError.value(
              value,
              value.methodName,
              'must appear at the top-level and can only be used in update()$fieldPathMessage.',
            );
        }
      }

    case _FieldTransform():
      if (inArray) {
        throw ArgumentError.value(
          value,
          value.methodName,
          'cannot be used inside an array$fieldPathMessage',
        );
      } else if (!options.allowTransform) {
        throw ArgumentError.value(
          value,
          value.methodName,
          'can only be used with set(), create() or update()$fieldPathMessage.',
        );
      }

    case FieldPath():
      throw ArgumentError.value(
        value,
        description,
        'Cannot use object of type "FieldPath" as a Firestore value$fieldPathMessage.',
      );

    case DocumentReference():
    case GeoPoint():
    case Timestamp() || DateTime():
    case VectorValue():
    case null:
    case num():
    case BigInt():
    case String():
    case bool():
      // Ok.
      break;

    default:
      throw ArgumentError.value(
        value,
        description,
        'Unsupported value type: ${value.runtimeType}$fieldPathMessage.',
      );
  }
}

// Validates that `value` can be used as an element inside of an array. Certain
// field values (such as ServerTimestamps) are rejected. Nested arrays are also
// rejected.
void _validateArrayElement(int index, Object? item) {
  if (item is List) {
    throw ArgumentError.value(
      item,
      'elements[$index]',
      'Nested arrays are not supported',
    );
  }

  _validateUserInput(
    index,
    item,
    description: 'array element',
    options: const _ValidateUserInputOptions(
      allowDeletes: _AllowDeletes.none,
      allowTransform: false,
    ),
    inArray: true,
  );
}
