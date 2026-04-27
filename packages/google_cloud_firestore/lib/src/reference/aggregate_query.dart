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
class AggregateQuery {
  const AggregateQuery._({required this.query, required this.aggregations});

  /// The query whose aggregations will be calculated by this object.
  final Query<Object?> query;

  @internal
  final List<AggregateFieldInternal> aggregations;

  /// Executes the aggregate query with explain options and returns performance
  /// metrics along with optional results.
  ///
  /// Use this method to understand how Firestore will execute your aggregation
  /// query and identify potential performance issues.
  ///
  /// Example:
  /// ```dart
  /// final aggregateQuery = firestore.collection('cities')
  ///     .where('population', WhereFilter.greaterThan, 1000000)
  ///     .count();
  ///
  /// // Get query plan without executing
  /// final planResult = await aggregateQuery.explain();
  /// print('Indexes: ${planResult.metrics.planSummary.indexesUsed}');
  ///
  /// // Get plan and execute the aggregation
  /// final fullResult = await aggregateQuery.explain(
  ///   ExplainOptions(analyze: true),
  /// );
  /// print('Read ops: ${fullResult.metrics.executionStats?.readOperations}');
  /// print('Count: ${fullResult.snapshot?.count}');
  /// ```
  Future<ExplainResults<AggregateQuerySnapshot?>> explain([
    ExplainOptions? options,
  ]) async {
    final firestore = query.firestore;

    final aggregationQuery = _toProto(
      parent: query._buildProtoParentPath(),
      transactionId: null,
      readTime: null,
      explainOptions: options?.toProto(),
    );

    final response = await firestore._firestoreClient.v1((
      api,
      projectId,
    ) async {
      return api.runAggregationQuery(aggregationQuery);
    });

    ExplainMetrics? metrics;
    AggregateQuerySnapshot? snapshot;
    final results = <String, Object?>{};
    Timestamp? readTime;
    var hadResult = false;

    await for (final result in response) {
      if (result.explainMetrics != null) {
        metrics = ExplainMetrics._fromProto(result.explainMetrics!);
      }

      if (result.result != null) {
        hadResult = true;
        for (final entry in result.result!.aggregateFields.entries) {
          final value = entry.value;
          if (value.integerValue != null) {
            results[entry.key] = value.integerValue;
          } else if (value.doubleValue != null) {
            results[entry.key] = value.doubleValue;
          } else if (value.nullValue != null) {
            results[entry.key] = null;
          }
        }
      }

      if (result.readTime != null) {
        readTime = Timestamp._fromProto(result.readTime!);
      }
    }

    // Create snapshot if backend returned a result
    if (hadResult) {
      snapshot = AggregateQuerySnapshot._(
        query: this,
        readTime: readTime,
        data: results,
      );
    }

    if (metrics == null) {
      throw StateError('No explain metrics returned from aggregate query');
    }

    return ExplainResults._create(metrics: metrics, snapshot: snapshot);
  }

  /// Executes the aggregate query and returns the results as an
  /// [AggregateQuerySnapshot].
  ///
  /// ```dart
  /// firestore.collection('cities').count().get().then(
  ///   (res) => print(res.count),
  ///   onError: (e) => print('Error completing: $e'),
  /// );
  /// ```
  Future<AggregateQuerySnapshot> get() async {
    final firestore = query.firestore;

    final request = _toProto(
      parent: query._buildProtoParentPath(),
      transactionId: null,
      readTime: null,
    );

    final response = await firestore._firestoreClient.v1((
      api,
      projectId,
    ) async {
      return api.runAggregationQuery(request);
    });

    final results = <String, Object?>{};
    Timestamp? readTime;

    await for (final result in response) {
      if (result.result case final aggregationResult?) {
        for (final entry in aggregationResult.aggregateFields.entries) {
          final value = entry.value;
          if (value.integerValue != null) {
            results[entry.key] = value.integerValue;
          } else if (value.doubleValue != null) {
            results[entry.key] = value.doubleValue;
          } else if (value.nullValue != null) {
            results[entry.key] = null;
          }
        }
      }

      if (result.readTime != null) {
        readTime = Timestamp._fromProto(result.readTime!);
      }
    }

    return AggregateQuerySnapshot._(
      query: this,
      readTime: readTime,
      data: results,
    );
  }

  /// Converts this aggregation query to a proto representation.
  ///
  /// Supports transaction parameters for executing within a transaction.
  firestore_v1.RunAggregationQueryRequest _toProto({
    required String parent,
    required String? transactionId,
    required Timestamp? readTime,
    firestore_v1.TransactionOptions? transactionOptions,
    firestore_v1.ExplainOptions? explainOptions,
  }) {
    // Validate mutual exclusivity of transaction parameters
    final providedParams = [
      transactionId,
      readTime,
      transactionOptions,
    ].nonNulls.length;

    if (providedParams > 1) {
      throw ArgumentError(
        'Only one of transactionId, readTime, or transactionOptions can be specified. '
        'Got: transactionId=$transactionId, readTime=$readTime, transactionOptions=$transactionOptions',
      );
    }

    return firestore_v1.RunAggregationQueryRequest(
      parent: parent,
      structuredAggregationQuery: firestore_v1.StructuredAggregationQuery(
        structuredQuery: query._toStructuredQuery(),
        aggregations: [
          for (final field in aggregations)
            firestore_v1.StructuredAggregationQuery_Aggregation(
              alias: field.alias,
              count: field.aggregation.count,
              sum: field.aggregation.sum,
              avg: field.aggregation.avg,
            ),
        ],
      ),
      explainOptions: explainOptions,
      transaction: transactionId.let(base64Decode),
      readTime: readTime?._toProto().timestampValue,
      newTransaction: transactionOptions,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AggregateQuery &&
        query == other.query &&
        const ListEquality<AggregateFieldInternal>().equals(
          aggregations,
          other.aggregations,
        );
  }

  @override
  int get hashCode => Object.hash(
    query,
    const ListEquality<AggregateFieldInternal>().hash(aggregations),
  );
}
