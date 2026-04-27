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
sealed class _FilterInternal {
  /// Returns a list of all field filters that are contained within this filter
  List<_FieldFilterInternal> get flattenedFilters;

  /// Returns a list of all filters that are contained within this filter
  List<_FilterInternal> get filters;

  /// Returns the field of the first filter that's an inequality, or null if none.
  FieldPath? get firstInequalityField;

  /// Returns the proto representation of this filter
  firestore_v1.StructuredQuery_Filter toProto();

  @mustBeOverridden
  @override
  bool operator ==(Object other);

  @mustBeOverridden
  @override
  int get hashCode;
}
