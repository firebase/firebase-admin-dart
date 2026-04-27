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

/// Response wrapper containing both aggregation results and transaction ID.
class _AggregationReaderResponse {
  _AggregationReaderResponse(this.result, this.transaction);

  final AggregateQuerySnapshot result;
  final String? transaction;
}

/// Reader class for executing aggregation queries within transactions.
///
/// Follows the same pattern as [_QueryReader] to handle:
/// - Lazy transaction initialization via `transactionOptions`
/// - Reusing existing transactions via `transactionId`
/// - Read-only snapshots via `readTime`
/// - Capturing and returning transaction IDs from responses
class _AggregationReader {
  _AggregationReader({
    required this.aggregateQuery,
    this.transactionId,
    this.readTime,
    this.transactionOptions,
  }) : assert(
         [transactionId, readTime, transactionOptions].nonNulls.length <= 1,
         'Only transactionId or readTime or transactionOptions must be provided. '
         'transactionId = $transactionId, readTime = $readTime, transactionOptions = $transactionOptions',
       );

  final AggregateQuery aggregateQuery;
  final String? transactionId;
  final Timestamp? readTime;
  final firestore_v1.TransactionOptions? transactionOptions;

  String? _retrievedTransactionId;

  /// Executes the aggregation query and captures the transaction ID from the response.
  ///
  /// Returns a [_AggregationReaderResponse] containing both the aggregation results
  /// and the transaction ID (if one was started or provided).
  Future<_AggregationReaderResponse> _get() async {
    final request = aggregateQuery._toProto(
      parent: aggregateQuery.query._buildProtoParentPath(),
      transactionId: transactionId,
      readTime: readTime,
      transactionOptions: transactionOptions,
    );

    final response = await aggregateQuery.query.firestore._firestoreClient.v1((
      api,
      projectId,
    ) async {
      return api.runAggregationQuery(request);
    });

    final results = <String, Object?>{};
    Timestamp? aggregationReadTime;

    // Process streaming response
    await for (final result in response) {
      // Capture transaction ID from response (if present)
      if (result.transaction.isNotEmpty) {
        _retrievedTransactionId = base64Encode(result.transaction);
      }

      if (result.result != null) {
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
        aggregationReadTime = Timestamp._fromProto(result.readTime!);
      }
    }

    // Return both aggregation results and transaction ID
    return _AggregationReaderResponse(
      AggregateQuerySnapshot._(
        query: aggregateQuery,
        readTime: aggregationReadTime,
        data: results,
      ),
      _retrievedTransactionId,
    );
  }
}
