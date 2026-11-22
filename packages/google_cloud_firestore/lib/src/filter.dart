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

enum WhereFilter {
  lessThan,
  lessThanOrEqual,
  equal,
  notEqual,
  greaterThanOrEqual,
  greaterThan,
  isIn,
  notIn,
  arrayContains,
  arrayContainsAny;

  firestore_v1.StructuredQuery_FieldFilter_Operator get proto {
    return switch (this) {
      WhereFilter.lessThan =>
        firestore_v1.StructuredQuery_FieldFilter_Operator.lessThan,
      WhereFilter.lessThanOrEqual =>
        firestore_v1.StructuredQuery_FieldFilter_Operator.lessThanOrEqual,
      WhereFilter.equal =>
        firestore_v1.StructuredQuery_FieldFilter_Operator.equal,
      WhereFilter.notEqual =>
        firestore_v1.StructuredQuery_FieldFilter_Operator.notEqual,
      WhereFilter.greaterThanOrEqual =>
        firestore_v1.StructuredQuery_FieldFilter_Operator.greaterThanOrEqual,
      WhereFilter.greaterThan =>
        firestore_v1.StructuredQuery_FieldFilter_Operator.greaterThan,
      WhereFilter.isIn => firestore_v1.StructuredQuery_FieldFilter_Operator.in$,
      WhereFilter.notIn =>
        firestore_v1.StructuredQuery_FieldFilter_Operator.notIn,
      WhereFilter.arrayContains =>
        firestore_v1.StructuredQuery_FieldFilter_Operator.arrayContains,
      WhereFilter.arrayContainsAny =>
        firestore_v1.StructuredQuery_FieldFilter_Operator.arrayContainsAny,
    };
  }
}

/// A `Filter` represents a restriction on one or more field values and can
/// be used to refine the results of a [Query].
/// `Filters`s are created by invoking [Filter.where], [Filter.or],
/// or [Filter.and] and can then be passed to [Query.where].
/// to create a new [Query] instance that also contains this `Filter`.
@immutable
sealed class Filter {
  /// Creates and returns a new [Filter], which can be applied to [Query.where],
  /// [Filter.or] or [Filter.and]. When applied to a [Query] it requires that
  /// documents must contain the specified field and that its value should
  /// satisfy the relation constraint provided.
  ///
  /// - [fieldPath]: The name of a property value to compare.
  /// - [op] A comparison operation in the form of a string.
  ///   Acceptable operator strings are "<", "<=", "==", "!=", ">=", ">", "array-contains",
  ///   "in", "not-in", and "array-contains-any".
  /// - [value] The value to which to compare the field for inclusion in
  ///   a query.
  ///
  /// ```dart
  /// final collectionRef = firestore.collection('col');
  ///
  /// collectionRef.where(Filter.where('foo', '==', 'bar')).get().then((querySnapshot) {
  ///   querySnapshot.forEach((documentSnapshot) {
  ///     print('Found document at ${documentSnapshot.ref.path}');
  ///   });
  /// });
  /// ```
  factory Filter.where(Object fieldPath, WhereFilter op, Object? value) =
      _UnaryFilter.fromString;

  /// Creates and returns a new [Filter], which can be applied to [Query.where],
  /// [Filter.or] or [Filter.and]. When applied to a [Query] it requires that
  /// documents must contain the specified field and that its value should
  /// satisfy the relation constraint provided.
  ///
  /// - [fieldPath]: The name of a property value to compare.
  /// - [op] A comparison operation in the form of a string.
  ///   Acceptable operator strings are "<", "<=", "==", "!=", ">=", ">", "array-contains",
  ///   "in", "not-in", and "array-contains-any".
  /// - [value] The value to which to compare the field for inclusion in
  ///   a query.
  ///
  /// ```dart
  /// final collectionRef = firestore.collection('col');
  ///
  /// collectionRef.where(Filter.where('foo', '==', 'bar')).get().then((querySnapshot) {
  ///   querySnapshot.forEach((documentSnapshot) {
  ///     print('Found document at ${documentSnapshot.ref.path}');
  ///   });
  /// });
  /// ```
  factory Filter.whereFieldPath(
    FieldPath fieldPath,
    WhereFilter op,
    Object? value,
  ) = _UnaryFilter;

  /// Creates and returns a new [Filter] that is a disjunction of the given
  /// [Filter]s. A disjunction filter includes a document if it satisfies any
  /// of the given [Filter]s.
  ///
  /// The returned Filter can be applied to [Query.where] [Filter.or], or
  /// [Filter.and]. When applied to a [Query] it requires that documents must
  /// satisfy one of the provided [Filter]s.
  ///
  /// - [filters] The [Filter]s
  ///   for OR operation. These must be created with calls to [Filter],
  ///
  /// ```dart
  /// final collectionRef = firestore.collection('col');
  ///
  /// // doc.foo == 'bar' || doc.baz > 0
  /// final orFilter = Filter.or(Filter.where('foo', WhereFilter.equal, 'bar'), Filter.where('baz', WhereFilter.greaterThan, 0));
  ///
  /// collectionRef.where(orFilter).get().then((querySnapshot) {
  ///   querySnapshot.forEach((documentSnapshot) {
  ///     print('Found document at ${documentSnapshot.ref.path}');
  ///   });
  /// });
  /// ```
  factory Filter.or(List<Filter> filters) = _CompositeFilter.or;

  /// Creates and returns a new [Filter] that is a
  /// conjunction of the given [Filter]s. A conjunction filter includes
  /// a document if it satisfies all of the given [Filter]s.
  ///
  /// The returned Filter can be applied to [Query.where()], [Filter.or], or
  /// [Filter.and]. When applied to a [Query] it requires that documents must satisfy
  /// one of the provided [Filter]s.
  ///
  /// - [filters]: The [Filter]s
  ///   for AND operation. These must be created with calls to [Filter.where],
  ///   [Filter.or], or [Filter.and].
  ///
  /// ```dart
  /// final collectionRef = firestore.collection('col');
  ///
  /// // doc.foo == 'bar' && doc.baz > 0
  /// final andFilter = Filter.and(Filter.where('foo', WhereFilter.equal, 'bar'), Filter.where('baz', WhereFilter.greaterThan, 0));
  ///
  /// collectionRef.where(andFilter).get().then((querySnapshot) {
  ///   querySnapshot.forEach((documentSnapshot) {
  ///     print('Found document at ${documentSnapshot.ref.path}');
  ///   });
  /// });
  /// ```
  factory Filter.and(List<Filter> filters) = _CompositeFilter.and;
}

class _UnaryFilter implements Filter {
  _UnaryFilter(this.fieldPath, this.op, this.value) {
    if (value == null || identical(value, double.nan)) {
      if (op != WhereFilter.equal && op != WhereFilter.notEqual) {
        throw ArgumentError(
          'Invalid query for value $value. Only == and != are supported.',
        );
      }
    }
  }

  _UnaryFilter.fromString(Object field, WhereFilter op, Object? value)
    : this(FieldPath.from(field), op, value);

  final FieldPath fieldPath;
  final WhereFilter op;
  final Object? value;
}

class _CompositeFilter implements Filter {
  _CompositeFilter({required this.filters, required this.operator});

  _CompositeFilter.or(List<Filter> filters)
    : this(filters: filters, operator: _CompositeOperator.or);

  _CompositeFilter.and(List<Filter> filters)
    : this(filters: filters, operator: _CompositeOperator.and);

  final List<Filter> filters;
  final _CompositeOperator operator;
}

enum _CompositeOperator {
  and,
  or;

  firestore_v1.StructuredQuery_CompositeFilter_Operator get proto {
    return switch (this) {
      _CompositeOperator.and =>
        firestore_v1.StructuredQuery_CompositeFilter_Operator.and,
      _CompositeOperator.or =>
        firestore_v1.StructuredQuery_CompositeFilter_Operator.or,
    };
  }
}
