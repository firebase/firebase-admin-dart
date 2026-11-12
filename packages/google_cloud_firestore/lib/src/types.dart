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

/// A map of string keys to dynamic values representing Firestore document data.
typedef DocumentData = Map<String, Object?>;

/// Update data that has been resolved to a mapping of FieldPaths to values.
typedef UpdateMap = Map<FieldPath, Object?>;

/// Function type for converting a Firestore document snapshot to a custom type.
typedef FromFirestore<T> =
    T Function(QueryDocumentSnapshot<DocumentData> value);

/// Function type for converting a custom type to Firestore document data.
typedef ToFirestore<T> = DocumentData Function(T value);

DocumentData _jsonFromFirestore(QueryDocumentSnapshot<DocumentData> value) {
  return value.data();
}

DocumentData _jsonToFirestore(DocumentData value) => value;

const _FirestoreDataConverter<DocumentData> _jsonConverter = (
  fromFirestore: _jsonFromFirestore,
  toFirestore: _jsonToFirestore,
);

/// The error thrown by `withConverter` when exactly one of its two functions
/// is provided.
ArgumentError _withConverterPairError() {
  return ArgumentError(
    '"fromFirestore" and "toFirestore" must be provided together. '
    'Pass both to apply a converter, or neither to reset to DocumentData.',
  );
}

/// The error thrown by `withConverter<U>()` when neither function is provided
/// but `U` cannot hold the [DocumentData] the reset reference produces.
ArgumentError _withConverterResetError<U>() {
  return ArgumentError(
    'withConverter<$U>() without "fromFirestore" and "toFirestore" resets to '
    'DocumentData, so the type argument must be DocumentData or a supertype '
    'of it.',
  );
}

/// A converter for transforming data between Firestore and application types.
typedef _FirestoreDataConverter<T> = ({
  FromFirestore<T> fromFirestore,
  ToFirestore<T> toFirestore,
});

/// Internal user data validation options.
class ValidationOptions {
  const ValidationOptions({
    required this.allowDeletes,
    required this.allowTransforms,
    required this.allowUndefined,
  });

  /// At what level field deletes are supported: 'none', 'root', or 'all'.
  final String allowDeletes;

  /// Whether server transforms are supported.
  final bool allowTransforms;

  /// Whether undefined (null) values are allowed.
  final bool allowUndefined;
}
