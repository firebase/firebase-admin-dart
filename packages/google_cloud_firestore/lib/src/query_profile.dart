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

/// PlanSummary contains information about the planning stage of a query.
class PlanSummary {
  const PlanSummary._(this.indexesUsed);

  factory PlanSummary._fromProto(firestore_v1.PlanSummary proto) {
    return PlanSummary._([
      for (final index in proto.indexesUsed) index.toJson() as Map<String, Object?>,
    ]);
  }

  /// Information about the indexes that were used to serve the query.
  ///
  /// This should be inspected or logged, because the contents are intended to be
  /// human-readable. Contents are subject to change, and it is advised to not
  /// program against this object.
  final List<Map<String, Object?>> indexesUsed;
}

/// ExecutionStats contains information about the execution of a query.
class ExecutionStats {
  const ExecutionStats._({
    required this.resultsReturned,
    required this.executionDuration,
    required this.readOperations,
    required this.debugStats,
  });

  factory ExecutionStats._fromProto(firestore_v1.ExecutionStats proto) {
    return ExecutionStats._(
      resultsReturned: proto.resultsReturned,
      executionDuration:
          proto.executionDuration?.let((d) {
            final seconds = d.seconds;
            final nanos = d.nanos;
            if (nanos == 0) return '${seconds}s';
            return '$seconds.${nanos.toString().padLeft(9, '0').replaceAll(RegExp(r'0+$'), '')}s';
          }) ??
          '0s',
      readOperations: proto.readOperations,
      debugStats:
          proto.debugStats?.toJson() as Map<String, Object?>? ?? const {},
    );
  }

  /// The number of query results.
  final int resultsReturned;

  /// The total execution time of the query (in string format like "1.234s").
  final String executionDuration;

  /// The number of read operations that occurred when executing the query.
  final int readOperations;

  /// Contains additional statistics related to the query execution.
  ///
  /// This should be inspected or logged, because the contents are intended to be
  /// human-readable. Contents are subject to change, and it is advised to not
  /// program against this object.
  final Map<String, Object?> debugStats;
}

/// ExplainMetrics contains information about planning and execution of a query.
class ExplainMetrics {
  const ExplainMetrics._({required this.planSummary, this.executionStats});

  factory ExplainMetrics._fromProto(firestore_v1.ExplainMetrics proto) {
    return ExplainMetrics._(
      planSummary: PlanSummary._fromProto(proto.planSummary!),
      executionStats: proto.executionStats != null
          ? ExecutionStats._fromProto(proto.executionStats!)
          : null,
    );
  }

  /// Information about the query plan.
  final PlanSummary planSummary;

  /// Information about the execution of the query.
  ///
  /// Only present when [ExplainOptions.analyze] is set to true.
  final ExecutionStats? executionStats;
}

/// ExplainResults contains information about planning, execution, and results
/// of a query.
class ExplainResults<T> {
  const ExplainResults._({required this.metrics, this.snapshot});

  factory ExplainResults._create({
    required ExplainMetrics metrics,
    T? snapshot,
  }) {
    return ExplainResults._(metrics: metrics, snapshot: snapshot);
  }

  /// Information about planning and execution of the query.
  final ExplainMetrics metrics;

  /// The snapshot that contains the results of executing the query.
  ///
  /// Null if the query was not executed (i.e., [ExplainOptions.analyze] was false).
  final T? snapshot;
}

/// Options to use when explaining a query.
class ExplainOptions {
  const ExplainOptions({this.analyze});

  /// Whether to execute the query.
  ///
  /// When false (the default), the query will be planned, returning only
  /// metrics from the planning stages.
  ///
  /// When true, the query will be planned and executed, returning the full
  /// query results along with both planning and execution stage metrics.
  final bool? analyze;

  firestore_v1.ExplainOptions toProto() {
    return firestore_v1.ExplainOptions(analyze: analyze ?? false);
  }
}
