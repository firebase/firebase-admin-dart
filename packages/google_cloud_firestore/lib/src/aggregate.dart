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

class AggregateField {
  const AggregateField._({
    required this.fieldPath,
    required this.alias,
    required this.type,
  });

  /// Creates a count aggregation.
  ///
  /// Count aggregations provide the number of documents that match the query.
  /// The result can be accessed using [AggregateQuerySnapshot.count].
  factory AggregateField.count() {
    return const AggregateField._(
      fieldPath: null,
      alias: 'count',
      type: AggregateType.count,
    );
  }

  /// Creates a sum aggregation for the specified field.
  ///
  /// - [field]: The field to sum across all matching documents. Can be a
  ///   String or a [FieldPath] for nested fields.
  ///
  /// The result can be accessed using [AggregateQuerySnapshot.getSum].
  factory AggregateField.sum(Object field) {
    assert(
      field is String || field is FieldPath,
      'field must be a String or FieldPath, got ${field.runtimeType}',
    );
    final fieldPath = FieldPath.from(field);
    final fieldName = fieldPath._formattedName;
    return AggregateField._(
      fieldPath: fieldName,
      alias: 'sum_$fieldName',
      type: AggregateType.sum,
    );
  }

  /// Creates an average aggregation for the specified field.
  ///
  /// - [field]: The field to average across all matching documents. Can be a
  ///   String or a [FieldPath] for nested fields.
  ///
  /// The result can be accessed using [AggregateQuerySnapshot.getAverage].
  factory AggregateField.average(Object field) {
    assert(
      field is String || field is FieldPath,
      'field must be a String or FieldPath, got ${field.runtimeType}',
    );
    final fieldPath = FieldPath.from(field);
    final fieldName = fieldPath._formattedName;
    return AggregateField._(
      fieldPath: fieldName,
      alias: 'avg_$fieldName',
      type: AggregateType.average,
    );
  }

  /// The field to aggregate on, or null for count aggregations.
  final String? fieldPath;

  /// The alias to use for this aggregation result.
  final String alias;

  /// The type of aggregation.
  final AggregateType type;

  /// Converts this public field to the internal representation.
  AggregateFieldInternal _toInternal() {
    firestore_v1.StructuredAggregationQuery_Aggregation aggregation;
    switch (type) {
      case AggregateType.count:
        aggregation = firestore_v1.StructuredAggregationQuery_Aggregation(
          alias: alias,
          count: firestore_v1.StructuredAggregationQuery_Aggregation_Count(),
        );
      case AggregateType.sum:
        aggregation = firestore_v1.StructuredAggregationQuery_Aggregation(
          alias: alias,
          sum: firestore_v1.StructuredAggregationQuery_Aggregation_Sum(
            field: firestore_v1.StructuredQuery_FieldReference(
              fieldPath: fieldPath!,
            ),
          ),
        );
      case AggregateType.average:
        aggregation = firestore_v1.StructuredAggregationQuery_Aggregation(
          alias: alias,
          avg: firestore_v1.StructuredAggregationQuery_Aggregation_Avg(
            field: firestore_v1.StructuredQuery_FieldReference(
              fieldPath: fieldPath!,
            ),
          ),
        );
    }

    return AggregateFieldInternal(alias: alias, aggregation: aggregation);
  }
}

/// The type of aggregation to perform.
enum AggregateType { count, sum, average }

/// Create a CountAggregateField object that can be used to compute
/// the count of documents in the result set of a query.
// ignore: camel_case_types
class count extends AggregateField {
  /// Creates a count aggregation.
  const count()
    : super._(fieldPath: null, alias: 'count', type: AggregateType.count);
}

/// Create an object that can be used to compute the sum of a specified field
/// over a range of documents in the result set of a query.
// ignore: camel_case_types
class sum extends AggregateField {
  /// Creates a sum aggregation for the specified field.
  const sum(this.field)
    : super._(fieldPath: field, alias: 'sum_$field', type: AggregateType.sum);

  /// The field to sum.
  final String field;
}

/// Create an object that can be used to compute the average of a specified field
/// over a range of documents in the result set of a query.
// ignore: camel_case_types
class average extends AggregateField {
  /// Creates an average aggregation for the specified field.
  const average(this.field)
    : super._(
        fieldPath: field,
        alias: 'avg_$field',
        type: AggregateType.average,
      );

  /// The field to average.
  final String field;
}

/// Internal representation of an aggregation field.
@immutable
@internal
class AggregateFieldInternal {
  const AggregateFieldInternal({
    required this.alias,
    required this.aggregation,
  });

  final String alias;
  final firestore_v1.StructuredAggregationQuery_Aggregation aggregation;

  @override
  bool operator ==(Object other) {
    return other is AggregateFieldInternal &&
        alias == other.alias &&
        // For count aggregations, we just check that both have count set
        ((aggregation.count != null && other.aggregation.count != null) ||
            (aggregation.sum != null && other.aggregation.sum != null) ||
            (aggregation.avg != null && other.aggregation.avg != null));
  }

  @override
  int get hashCode => Object.hash(
    alias,
    aggregation.count != null ||
        aggregation.sum != null ||
        aggregation.avg != null,
  );
}
