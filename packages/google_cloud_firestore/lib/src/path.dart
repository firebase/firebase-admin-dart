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

/// Validates that the given string can be used as a relative or absolute
/// resource path.
void _validateResourcePath(Object arg, String resourcePath) {
  if (resourcePath.isEmpty) {
    throw ArgumentError.value(
      resourcePath,
      arg.toString(),
      'Must be a non-empty string',
    );
  }

  if (resourcePath.contains('//')) {
    throw ArgumentError.value(
      resourcePath,
      arg.toString(),
      'Must not contain "//"',
    );
  }
}

@immutable
abstract class _Path<T extends _Path<Object?>> implements Comparable<_Path<T>> {
  const _Path(this.segments);

  final List<String> segments;

  /// Constructs a new instance of [_Path].
  T _construct(List<String> segments);

  /// Splits a string into path segments.
  List<String> _split(String relativePath);

  /// Returns the path of the parent node.
  T? parent() {
    if (segments.isEmpty) return null;

    return _construct(segments.sublist(0, segments.length - 1));
  }

  /// Create a child path beneath the current level.
  T _appendPath(_Path<T> relativePath) {
    return _construct([...segments, ...relativePath.segments]);
  }

  /// Create a child path beneath the current level.
  T _append(String relativePath) {
    return _construct([...segments, ..._split(relativePath)]);
  }

  List<String> _toList() => segments.toList();

  /// Checks whether the current path is a prefix of the specified path.
  bool _isPrefixOf(_Path<T> other) {
    if (other.segments.length < segments.length) {
      return false;
    }

    for (var i = 0; i < segments.length; i++) {
      if (segments[i] != other.segments[i]) {
        return false;
      }
    }

    return true;
  }

  @override
  int compareTo(_Path<T> other) {
    final len = math.min(segments.length, other.segments.length);
    for (var i = 0; i < len; i++) {
      final compare = segments[i].compareTo(other.segments[i]);
      if (compare != 0) return compare;
    }

    if (segments.length < other.segments.length) return -1;
    if (segments.length > other.segments.length) return 1;

    return 0;
  }

  @override
  bool operator ==(Object other) {
    return other is _Path<T> &&
        const ListEquality<String>().equals(segments, other.segments);
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const ListEquality<String>().hash(segments));
}

class _ResourcePath extends _Path<_ResourcePath> {
  const _ResourcePath._([super.segments = const []]);

  static const empty = _ResourcePath._();

  /// Returns the location of this path relative to the root of the
  /// project's database.
  String get relativeName => segments.join('/');

  /// Indicates whether this path points to a collection.
  bool get isCollection => segments.length.isOdd;

  /// Indicates whether this path points to a document.
  bool get isDocument => segments.isNotEmpty && segments.length.isEven;

  /// The last component of the path.
  String? get id {
    if (segments.isEmpty) return null;
    return segments.last;
  }

  @override
  _ResourcePath _construct(List<String> segments) => _ResourcePath._(segments);

  @override
  List<String> _split(String relativePath) {
    // We may have an empty segment at the beginning or end if they had a
    // leading or trailing slash (which we allow).
    return relativePath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
  }

  _QualifiedResourcePath _toQualifiedResourcePath(
    String projectId,
    String databaseId,
  ) {
    return _QualifiedResourcePath._(
      projectId: projectId,
      databaseId: databaseId,
      segments: segments,
    );
  }
}

class _QualifiedResourcePath extends _ResourcePath {
  const _QualifiedResourcePath._({
    required String projectId,
    required String databaseId,
    required List<String> segments,
  }) : _projectId = projectId,
       _databaseId = databaseId,
       super._(segments);

  factory _QualifiedResourcePath.fromSlashSeparatedString(String absolutePath) {
    final elements = _resourcePathRe.firstMatch(absolutePath);

    if (elements == null) {
      throw ArgumentError.value(absolutePath, 'absolutePath');
    }

    final project = elements.group(1)!;
    final database = elements.group(2)!;
    final path = elements.group(3)!;

    return _QualifiedResourcePath._(
      projectId: project,
      databaseId: database,
      segments: const [],
    )._append(path);
  }

  /// A regular expression to verify an absolute Resource Path in Firestore. It
  /// extracts the project ID, the database name and the relative resource path
  /// if available.
  static final _resourcePathRe = RegExp(
    // Note: [\s\S] matches all characters including newlines.
    r'^projects\/([^/]*)\/databases\/([^/]*)(?:\/documents\/)?([\s\S]*)$',
  );

  final String _projectId;
  final String _databaseId;

  @override
  _QualifiedResourcePath? parent() => super.parent() as _QualifiedResourcePath?;

  /// String representation of a ResourcePath as expected by the API.
  String get _formattedName {
    final components = [
      'projects',
      _projectId,
      'databases',
      _databaseId,
      'documents',
      ...segments,
    ];
    return components.join('/');
  }

  @override
  _QualifiedResourcePath _append(String relativePath) {
    return super._append(relativePath) as _QualifiedResourcePath;
  }

  @override
  _QualifiedResourcePath _appendPath(_Path<_ResourcePath> relativePath) {
    return super._appendPath(relativePath) as _QualifiedResourcePath;
  }

  @override
  _QualifiedResourcePath _construct(List<String> segments) {
    return _QualifiedResourcePath._(
      projectId: _projectId,
      databaseId: _databaseId,
      segments: segments,
    );
  }

  @override
  int compareTo(_Path<_ResourcePath> other) {
    if (other is _QualifiedResourcePath) {
      final compare = _projectId.compareTo(other._projectId);
      if (compare != 0) return compare;

      final compare2 = _databaseId.compareTo(other._databaseId);
      if (compare2 != 0) return compare2;
    }

    return super.compareTo(other);
  }
}

sealed class FieldMask {
  factory FieldMask.field(String path) = _StringFieldMask;
  factory FieldMask.fieldPath(FieldPath fieldPath) = _FieldPathFieldMask;
}

final _fieldPathRegex = RegExp(r'^[^*~/[\]]+$');

class _StringFieldMask implements FieldMask {
  _StringFieldMask(this.path) {
    if (path.contains('..')) {
      throw ArgumentError.value(path, 'path', 'must not contain ".."');
    }

    if (path.startsWith('.') || path.endsWith('.')) {
      throw ArgumentError.value(path, 'path', 'must not start or end with "."');
    }

    if (!_fieldPathRegex.hasMatch(path)) {
      throw ArgumentError.value(
        path,
        'path',
        "Paths can't be empty and must not contain '*~/[]'.",
      );
    }
  }
  final String path;
}

class _FieldPathFieldMask implements FieldMask {
  _FieldPathFieldMask(this.fieldPath);
  final FieldPath fieldPath;
}

class FieldPath extends _Path<FieldPath> {
  FieldPath(super.segments) {
    if (segments.isEmpty) {
      throw ArgumentError.value(segments, 'segments', 'must not be empty.');
    }

    for (var i = 0; i < segments.length; ++i) {
      if (segments[i].isEmpty) {
        throw ArgumentError.value(
          segments[i],
          'Element at index $i',
          'should not be an empty string.',
        );
      }
    }
  }

  factory FieldPath.from(Object? object) {
    if (object is String) {
      return FieldPath.fromArgument(FieldMask.field(object));
    } else if (object is FieldPath) {
      return object;
    }

    throw ArgumentError.value(
      object,
      'object',
      'must be a String or FieldPath.',
    );
  }

  factory FieldPath.fromArgument(FieldMask fieldMask) {
    return switch (fieldMask) {
      _FieldPathFieldMask() => fieldMask.fieldPath,
      _StringFieldMask() => FieldPath(fieldMask.path.split('.').toList()),
    };
  }

  /// A special [FieldPath] value to refer to the ID of a document. It can be used
  /// in queries to sort or filter by the document ID.
  static final documentId = FieldPath(const <String>['__name__']);

  /// Returns the number of segments of this field path.
  int get _length => segments.length;

  /// Segments that are sent as-is; any other segment is backtick-quoted.
  static final _simpleSegment = RegExp(r'^[_a-zA-Z][_a-zA-Z0-9]*$');

  /// The canonical string form of this path, as the backend expects it.
  ///
  /// Segments are joined with dots. A segment that is not a simple
  /// identifier (letters, digits and underscores, not starting with a digit)
  /// is wrapped in backticks, with backslashes and backticks inside it
  /// escaped by a backslash: `FieldPath(['a.b', 'c-d'])` is `` `a.b`.`c-d` ``.
  /// Matches the Node SDK's `FieldPath.formattedName`.
  String get _formattedName {
    return segments
        .map((e) {
          if (_simpleSegment.hasMatch(e)) return e;
          return '`${e.replaceAll(r'\', r'\\').replaceAll('`', r'\`')}`';
        })
        .join('.');
  }

  /// Checks whether this field path is a prefix of the specified path.
  bool isPrefixOf(FieldPath other) => _isPrefixOf(other);

  /// Appends a child segment to this field path.
  FieldPath append(FieldPath childSegment) => _appendPath(childSegment);

  @override
  FieldPath _construct(List<String> segments) => FieldPath(segments);

  @override
  List<String> _split(String relativePath) => relativePath.split('.');
}
