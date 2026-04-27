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

class _CompositeFilterInternal extends _FilterInternal {
  _CompositeFilterInternal({required this.op, required this.filters});

  final _CompositeOperator op;
  @override
  final List<_FilterInternal> filters;

  bool get isConjunction => op == _CompositeOperator.and;

  @override
  late final flattenedFilters = filters.fold<List<_FieldFilterInternal>>([], (
    allFilters,
    subFilter,
  ) {
    return allFilters..addAll(subFilter.flattenedFilters);
  });

  @override
  FieldPath? get firstInequalityField {
    return flattenedFilters
        .firstWhereOrNull((filter) => filter.isInequalityFilter)
        ?.field;
  }

  @override
  firestore_v1.StructuredQuery_Filter toProto() {
    if (filters.length == 1) return filters.single.toProto();

    return firestore_v1.StructuredQuery_Filter(
      compositeFilter: firestore_v1.StructuredQuery_CompositeFilter(
        op: op.proto,
        filters: filters.map((e) => e.toProto()).toList(),
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _CompositeFilterInternal &&
        runtimeType == other.runtimeType &&
        op == other.op &&
        const ListEquality<_FilterInternal>().equals(filters, other.filters);
  }

  @override
  int get hashCode => Object.hash(runtimeType, op, filters);
}
