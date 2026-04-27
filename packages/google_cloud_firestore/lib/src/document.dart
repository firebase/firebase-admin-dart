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

class Optional<T> {
  const Optional(this.value);
  final T? value;
}

/// A DocumentSnapshot is an immutable representation for a document in a
/// Firestore database. The data can be extracted with [data].
///
/// For a DocumentSnapshot that points to a non-existing document, any data
/// access will return `null`. You can use the [exists] property to explicitly
/// verify a document's existence.
@immutable
class DocumentSnapshot<T> {
  const DocumentSnapshot._({
    required this.ref,
    required this.readTime,
    required this.createTime,
    required this.updateTime,
    required firestore_v1.MapValue? fieldsProto,
  }) : _fieldsProto = fieldsProto;

  factory DocumentSnapshot._fromObject(
    DocumentReference<T> ref,
    DocumentData data,
  ) {
    final serializer = ref.firestore._serializer;

    return DocumentSnapshot._(
      ref: ref,
      fieldsProto: serializer.encodeFields(data),
      readTime: null,
      createTime: null,
      updateTime: null,
    );
  }

  factory DocumentSnapshot.fromUpdateMap(
    DocumentReference<T> ref,
    UpdateMap data,
  ) {
    final serializer = ref.firestore._serializer;

    /// Merges 'value' at the field path specified by the path array into
    /// 'target'.
    ApiMapValue? merge({
      required ApiMapValue target,
      required Object? value,
      required List<String> path,
      required int pos,
    }) {
      final key = path[pos];
      final isLast = pos == path.length - 1;

      if (!target.containsKey(key)) {
        if (isLast) {
          if (value is _FieldTransform) {
            // If there is already data at this path, we need to retain it.
            // Otherwise, we don't include it in the DocumentSnapshot.
            return target.isNotEmpty ? target : null;
          }
          // The merge is done
          final leafNode = serializer.encodeValue(value);
          if (leafNode != null) {
            target[key] = leafNode;
          }
          return target;
        } else {
          // We need to expand the target object.
          final childNode = <String, firestore_v1.Value>{};

          final nestedValue = merge(
            target: childNode,
            value: value,
            path: path,
            pos: pos + 1,
          );

          if (nestedValue != null) {
            target[key] = firestore_v1.Value(
              mapValue: firestore_v1.MapValue(fields: nestedValue),
            );
            return target;
          } else {
            return target.isNotEmpty ? target : null;
          }
        }
      } else {
        assert(!isLast, "Can't merge current value into a nested object");
        target[key] = firestore_v1.Value(
          mapValue: firestore_v1.MapValue(
            fields: merge(
              target: target[key]!.mapValue!.fields,
              value: value,
              path: path,
              pos: pos + 1,
            )!,
          ),
        );
        return target;
      }
    }

    final res = <String, firestore_v1.Value>{};
    for (final entry in data.entries) {
      final path = entry.key._toList();
      merge(target: res, value: entry.value, path: path, pos: 0);
    }

    return DocumentSnapshot._(
      ref: ref,
      fieldsProto: firestore_v1.MapValue(fields: res),
      readTime: null,
      createTime: null,
      updateTime: null,
    );
  }

  static DocumentSnapshot<DocumentData> _fromDocument(
    firestore_v1.Document document,
    protobuf_v1.Timestamp? readTime,
    Firestore firestore,
  ) {
    final name = document.name;
    final ref = DocumentReference<DocumentData>._(
      firestore: firestore,
      path: _QualifiedResourcePath.fromSlashSeparatedString(name),
      converter: _jsonConverter,
    );

    final builder = _DocumentSnapshotBuilder(ref)
      ..fieldsProto = firestore_v1.MapValue(fields: document.fields)
      ..createTime = document.createTime.let(Timestamp._fromProto)
      ..readTime = readTime.let(Timestamp._fromProto)
      ..updateTime = document.updateTime.let(Timestamp._fromProto);

    return builder.build();
  }

  static DocumentSnapshot<DocumentData> _missing(
    String document,
    protobuf_v1.Timestamp? readTime,
    Firestore firestore,
  ) {
    final ref = DocumentReference<DocumentData>._(
      firestore: firestore,
      path: _QualifiedResourcePath.fromSlashSeparatedString(document),
      converter: _jsonConverter,
    );

    final builder = _DocumentSnapshotBuilder(ref)
      ..readTime = readTime.let(Timestamp._fromProto);

    return builder.build();
  }

  /// A [DocumentReference] for the document stored in this snapshot.
  final DocumentReference<T> ref;
  final Timestamp? readTime;
  final Timestamp? createTime;
  final Timestamp? updateTime;
  final firestore_v1.MapValue? _fieldsProto;

  /// The ID of the document for which this DocumentSnapshot contains data.
  String get id => ref.id;

  /// True if the document exists.
  ///
  /// @type {boolean}
  /// @name DocumentSnapshot#exists
  /// @readonly
  ///
  /// ```dart
  /// final documentRef = firestore.doc('col/doc');
  ///
  /// documentRef.get().then((documentSnapshot) {
  ///   if (documentSnapshot.exists) {
  ///     print('Data: ${JSON.stringify(documentSnapshot.data())}');
  ///   }
  /// });
  /// ```
  bool get exists => _fieldsProto != null;

  /// Retrieves all fields in the document as an object. Returns `null` if
  /// the document doesn't exist.
  ///
  /// ```dart
  /// final documentRef = firestore.doc('col/doc');
  ///
  /// final documentSnapshot = await documentRef.get();
  /// final data = documentSnapshot.data();
  /// print('Retrieved data: ${jsonEncode(data)}');
  /// ```
  T? data() {
    final fieldsProto = _fieldsProto;
    final fields = fieldsProto?.fields;
    if (fields == null || fieldsProto == null) return null;

    final converter = ref._converter;
    // We only want to use the converter and create a new QueryDocumentSnapshot
    // if a converter has been provided.
    if (!identical(converter, _jsonConverter)) {
      final untypedReference = DocumentReference._(
        firestore: ref.firestore,
        path: ref._path,
        converter: _jsonConverter,
      );

      return converter.fromFirestore(
        QueryDocumentSnapshot._(
          ref: untypedReference,
          fieldsProto: fieldsProto,
          readTime: readTime,
          createTime: createTime,
          updateTime: updateTime,
        ),
      );
    } else {
      final object = <String, Object?>{
        for (final prop in fields.entries)
          prop.key: ref.firestore._serializer.decodeValue(prop.value),
      };

      return object as T;
    }
  }

  /// Retrieves the field specified by [field].
  ///
  /// Will return `null` if the field does not exists.
  /// Will return `Optional(null)` if the field exists but is `null`.
  Optional<Object?>? get(Object field) {
    final fieldPath = FieldPath.from(field);
    final protoField = _protoField(fieldPath);

    if (protoField == null) return null;

    return Optional(ref.firestore._serializer.decodeValue(protoField));
  }

  firestore_v1.Value? _protoField(FieldPath field) {
    final fieldsProto = _fieldsProto?.fields;
    if (fieldsProto == null) return null;
    var fields = fieldsProto;

    final components = field._toList();
    for (var i = 0; i < components.length - 1; i++) {
      final component = components[i];

      final newFields = fields[component]?.mapValue;
      // The field component is not present.
      if (newFields == null) return null;

      fields = newFields.fields;
    }

    return fields[components.last];
  }

  firestore_v1.Write _toWriteProto() {
    return firestore_v1.Write(
      update: firestore_v1.Document(
        name: ref._formattedName,
        fields: _fieldsProto?.fields ?? const {},
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DocumentSnapshot<T> &&
        runtimeType == other.runtimeType &&
        ref == other.ref &&
        const DeepCollectionEquality().equals(_fieldsProto, other._fieldsProto);
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    ref,
    const DeepCollectionEquality().hash(_fieldsProto),
  );
}

class _DocumentSnapshotBuilder<T> {
  _DocumentSnapshotBuilder(this.ref);

  final DocumentReference<T> ref;

  Timestamp? readTime;
  Timestamp? createTime;
  Timestamp? updateTime;
  firestore_v1.MapValue? fieldsProto;

  DocumentSnapshot<T> build() {
    assert(
      (this.fieldsProto != null) == (createTime != null),
      'Create time should be set iff document exists.',
    );
    assert(
      (this.fieldsProto != null) == (updateTime != null),
      'Update time should be set iff document exists.',
    );

    final fieldsProto = this.fieldsProto;
    if (fieldsProto != null) {
      return QueryDocumentSnapshot._(
        ref: ref,
        fieldsProto: fieldsProto,
        readTime: readTime,
        createTime: createTime,
        updateTime: updateTime,
      );
    }

    return DocumentSnapshot<T>._(
      ref: ref,
      readTime: readTime,
      createTime: createTime,
      updateTime: updateTime,
      fieldsProto: null,
    );
  }
}

class QueryDocumentSnapshot<T> extends DocumentSnapshot<T> {
  const QueryDocumentSnapshot._({
    required super.ref,
    required super.readTime,
    required super.createTime,
    required super.updateTime,
    required super.fieldsProto,
  }) : super._();

  @override
  Timestamp get createTime => super.createTime!;

  @override
  Timestamp get updateTime => super.updateTime!;

  @override
  T data() {
    final data = super.data();
    if (data == null) {
      throw StateError(
        'The data in a QueryDocumentSnapshot should always exist.',
      );
    }
    return data;
  }
}

/// A Firestore Document Transform.
///
/// A DocumentTransform contains pending server-side transforms and their
/// corresponding field paths.
class _DocumentTransform<T> {
  _DocumentTransform({required this.ref, required this.transforms});

  factory _DocumentTransform.fromObject(
    DocumentReference<T> ref,
    DocumentData data,
  ) {
    final updateMap = <FieldPath, Object?>{
      for (final entry in data.entries) FieldPath([entry.key]): entry.value,
    };

    return _DocumentTransform.fromUpdateMap(ref, updateMap);
  }

  factory _DocumentTransform.fromUpdateMap(
    DocumentReference<T> ref,
    UpdateMap data,
  ) {
    final transforms = <FieldPath, _FieldTransform>{};

    void encode(Object? val, FieldPath path, {required bool allowTransforms}) {
      if (val is _FieldTransform && val.includeInDocumentTransform) {
        if (allowTransforms) {
          transforms[path] = val;
        } else {
          throw ArgumentError(
            '${val.methodName}() is not supported inside of array values.',
          );
        }
      } else if (val is List<Object?>) {
        val.forEachIndexed((i, value) {
          // We need to verify that no array value contains a document transform
          encode(value, path._append('$i'), allowTransforms: false);
        });
      } else if (val is Map<Object?, Object?>) {
        for (final entry in val.entries) {
          encode(
            entry.value,
            path._append(entry.key.toString()),
            allowTransforms: allowTransforms,
          );
        }
      }
    }

    for (final entry in data.entries) {
      encode(entry.value, entry.key, allowTransforms: true);
    }

    return _DocumentTransform(ref: ref, transforms: transforms);
  }

  final DocumentReference<T> ref;
  final Map<FieldPath, _FieldTransform> transforms;

  void validate() {
    for (final transform in transforms.values) {
      transform.validate();
    }
  }

  /// Converts a document transform to the Firestore 'FieldTransform' Proto.
  List<firestore_v1.DocumentTransform_FieldTransform> toProto(Serializer serializer) {
    return [
      for (final entry in transforms.entries)
        entry.value._toProto(serializer, entry.key),
    ];
  }
}

/// A condition to check before performing an operation.
class Precondition {
  /// Checks that the document exists or not.
  Precondition.exists(bool this._exists) : _lastUpdateTime = null;

  /// Checks that the document has last been updated at the specified time.
  Precondition.timestamp(Timestamp this._lastUpdateTime) : _exists = null;

  final bool? _exists;
  final Timestamp? _lastUpdateTime;

  /// Whether this DocumentTransform contains any enforcement.
  bool get _isEmpty => _exists == null && _lastUpdateTime == null;

  firestore_v1.Precondition? _toProto() {
    if (_isEmpty) return null;

    final lastUpdateTime = _lastUpdateTime;
    if (lastUpdateTime != null) {
      return firestore_v1.Precondition(
        updateTime: lastUpdateTime._toProto().timestampValue,
      );
    }

    return firestore_v1.Precondition(exists: _exists);
  }
}

class _DocumentMask {
  _DocumentMask(List<FieldPath> fieldPaths)
    : _sortedPaths = fieldPaths.sorted((a, b) => a.compareTo(b));

  factory _DocumentMask.fromUpdateMap(Map<FieldPath, Object?> data) {
    final fieldPaths = <FieldPath>[];

    for (final entry in data.entries) {
      final value = entry.value;
      if (value is! _FieldTransform || value.includeInDocumentMask) {
        fieldPaths.add(entry.key);
      }
    }

    return _DocumentMask(fieldPaths);
  }

  /// Creates a document mask from a list of field paths.
  factory _DocumentMask.fromFieldMask(List<FieldPath> fieldMask) {
    return _DocumentMask(List.from(fieldMask));
  }

  /// Creates a document mask with the field names of a document.
  /// Recursively extracts all field paths from the data object.
  factory _DocumentMask.fromObject(Map<String, Object?> data) {
    final fieldPaths = <FieldPath>[];

    void extractFieldPaths(
      Map<String, Object?> currentData, [
      FieldPath? currentPath,
    ]) {
      var isEmpty = true;

      for (final entry in currentData.entries) {
        isEmpty = false;

        final key = entry.key;
        final childSegment = FieldPath([key]);
        final childPath = currentPath != null
            ? currentPath.append(childSegment)
            : childSegment;
        final value = entry.value;

        if (value is _FieldTransform) {
          if (value.includeInDocumentMask) {
            fieldPaths.add(childPath);
          }
        } else if (value is Map<String, Object?>) {
          extractFieldPaths(value, childPath);
        } else if (value != null) {
          fieldPaths.add(childPath);
        }
      }

      // Add a field path for an explicitly updated empty map.
      if (currentPath != null && isEmpty) {
        fieldPaths.add(currentPath);
      }
    }

    extractFieldPaths(data);
    return _DocumentMask(fieldPaths);
  }

  final List<FieldPath> _sortedPaths;

  bool get isEmpty => _sortedPaths.isEmpty;

  /// Removes the specified field paths from this document mask.
  void removeFields(List<FieldPath> fieldPaths) {
    _sortedPaths.removeWhere((path) => fieldPaths.any((fp) => path == fp));
  }

  /// Returns whether this document mask contains the specified field path.
  bool contains(FieldPath fieldPath) {
    return _sortedPaths.any((path) => path == fieldPath);
  }

  /// Applies this DocumentMask to data and returns a new object containing only
  /// the fields specified in the mask.
  Map<String, Object?> applyTo(Map<String, Object?> data) {
    final remainingPaths = List<FieldPath>.from(_sortedPaths);

    Map<String, Object?> processObject(
      Map<String, Object?> currentData, [
      FieldPath? currentPath,
    ]) {
      final result = <String, Object?>{};

      for (final entry in currentData.entries) {
        final key = entry.key;
        final childSegment = FieldPath([key]);
        final childPath = currentPath != null
            ? currentPath.append(childSegment)
            : childSegment;

        // Check if this field or any of its children are in the mask
        final shouldInclude = remainingPaths.any((path) {
          return path == childPath || path.isPrefixOf(childPath);
        });

        if (shouldInclude) {
          final value = entry.value;

          if (value is Map<String, Object?>) {
            result[key] = processObject(value, childPath);
          } else {
            result[key] = value;
          }

          // Remove this path from remaining
          remainingPaths.removeWhere((path) => path == childPath);
        }
      }

      return result;
    }

    return processObject(data);
  }

  firestore_v1.DocumentMask toProto() {
    if (_sortedPaths.isEmpty) return firestore_v1.DocumentMask();

    return firestore_v1.DocumentMask(
      fieldPaths: _sortedPaths.map((e) => e._formattedName).toList(),
    );
  }
}
