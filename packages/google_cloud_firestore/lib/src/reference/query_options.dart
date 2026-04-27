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

@immutable
class _QueryCursor {
  const _QueryCursor({required this.before, required this.values});

  final bool before;
  final List<firestore_v1.Value> values;

  @override
  bool operator ==(Object other) {
    return other is _QueryCursor &&
        runtimeType == other.runtimeType &&
        before == other.before &&
        _valuesEqual(values, other.values);
  }

  @override
  int get hashCode => Object.hash(
    before,
    const ListEquality<firestore_v1.Value>().hash(values),
  );
}

@immutable
class _QueryOptions<T> {
  const _QueryOptions({
    required this.parentPath,
    required this.collectionId,
    required this.converter,
    required this.allDescendants,
    required this.filters,
    required this.fieldOrders,
    this.startAt,
    this.endAt,
    this.limit,
    this.projection,
    this.limitType,
    this.offset,
    this.kindless = false,
    this.requireConsistency = true,
  });

  /// Returns query options for a single-collection query.
  /// Returns query options for a single-collection query.
  factory _QueryOptions.forCollectionQuery(
    _ResourcePath collectionRef,
    _FirestoreDataConverter<T> converter,
  ) {
    return _QueryOptions<T>(
      parentPath: collectionRef.parent()!,
      collectionId: collectionRef.id!,
      converter: converter,
      allDescendants: false,
      filters: const [],
      fieldOrders: const [],
    );
  }

  /// Returns query options for a collection group query.
  factory _QueryOptions.forCollectionGroupQuery(
    String collectionId,
    _FirestoreDataConverter<T> converter,
  ) {
    return _QueryOptions(
      parentPath: _ResourcePath.empty,
      collectionId: collectionId,
      converter: converter,
      allDescendants: true,
      filters: const [],
      fieldOrders: const [],
    );
  }

  /// Returns query options for querying all descendants of the specified reference.
  /// Used by recursiveDelete.
  /// @private
  /// @internal
  factory _QueryOptions.forKindlessAllDescendants(
    _ResourcePath parentPath,
    String collectionId, {
    required bool requireConsistency,
  }) {
    return _QueryOptions(
      parentPath: parentPath,
      collectionId: collectionId,
      converter: _jsonConverter as _FirestoreDataConverter<T>,
      allDescendants: true,
      filters: const [],
      fieldOrders: const [],
      kindless: true,
      requireConsistency: requireConsistency,
    );
  }

  final _ResourcePath parentPath;
  final String collectionId;
  final _FirestoreDataConverter<T> converter;
  final bool allDescendants;
  final List<_FilterInternal> filters;
  final List<_FieldOrder> fieldOrders;
  final _QueryCursor? startAt;
  final _QueryCursor? endAt;
  final int? limit;
  final firestore_v1.StructuredQuery_Projection? projection;
  final LimitType? limitType;
  final int? offset;
  final bool kindless;
  final bool requireConsistency;

  bool get hasFieldOrders => fieldOrders.isNotEmpty;

  _QueryOptions<U> withConverter<U>(_FirestoreDataConverter<U> converter) {
    return _QueryOptions<U>(
      converter: converter,
      parentPath: parentPath,
      collectionId: collectionId,
      allDescendants: allDescendants,
      filters: filters,
      fieldOrders: fieldOrders,
      startAt: startAt,
      endAt: endAt,
      limit: limit,
      limitType: limitType,
      offset: offset,
      projection: projection,
      kindless: kindless,
      requireConsistency: requireConsistency,
    );
  }

  _QueryOptions<T> copyWith({
    _ResourcePath? parentPath,
    String? collectionId,
    _FirestoreDataConverter<T>? converter,
    bool? allDescendants,
    List<_FilterInternal>? filters,
    List<_FieldOrder>? fieldOrders,
    _QueryCursor? startAt,
    _QueryCursor? endAt,
    int? limit,
    firestore_v1.StructuredQuery_Projection? projection,
    LimitType? limitType,
    int? offset,
    bool? kindless,
    bool? requireConsistency,
  }) {
    return _QueryOptions<T>(
      parentPath: parentPath ?? this.parentPath,
      collectionId: collectionId ?? this.collectionId,
      converter: converter ?? this.converter,
      allDescendants: allDescendants ?? this.allDescendants,
      filters: filters ?? this.filters,
      fieldOrders: fieldOrders ?? this.fieldOrders,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      limit: limit ?? this.limit,
      projection: projection ?? this.projection,
      limitType: limitType ?? this.limitType,
      offset: offset ?? this.offset,
      kindless: kindless ?? this.kindless,
      requireConsistency: requireConsistency ?? this.requireConsistency,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _QueryOptions<T> &&
            runtimeType == other.runtimeType &&
            parentPath == other.parentPath &&
            collectionId == other.collectionId &&
            converter == other.converter &&
            allDescendants == other.allDescendants &&
            const ListEquality<_FilterInternal>().equals(
              filters,
              other.filters,
            ) &&
            const ListEquality<_FieldOrder>().equals(
              fieldOrders,
              other.fieldOrders,
            ) &&
            startAt == other.startAt &&
            endAt == other.endAt &&
            limit == other.limit &&
            projection == other.projection &&
            limitType == other.limitType &&
            offset == other.offset &&
            kindless == other.kindless &&
            requireConsistency == other.requireConsistency;
  }

  @override
  int get hashCode => Object.hash(
    parentPath,
    collectionId,
    converter,
    allDescendants,
    const ListEquality<_FilterInternal>().hash(filters),
    const ListEquality<_FieldOrder>().hash(fieldOrders),
    startAt,
    endAt,
    limit,
    projection,
    limitType,
    offset,
    kindless,
    requireConsistency,
  );
}
