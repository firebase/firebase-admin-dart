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

/// Response wrapper containing both query results and transaction ID.
class _QueryReaderResponse<T> {
  _QueryReaderResponse(this.result, this.transaction);

  final QuerySnapshot<T> result;
  final String? transaction;
}

/// Reader class for executing queries within transactions.
///
/// Follows the same pattern as [_DocumentReader] to handle:
/// - Lazy transaction initialization via `transactionOptions`
/// - Reusing existing transactions via `transactionId`
/// - Read-only snapshots via `readTime`
/// - Capturing and returning transaction IDs from responses
class _QueryReader<T> {
  _QueryReader({
    required this.query,
    this.transactionId,
    this.readTime,
    this.transactionOptions,
  }) : assert(
         [transactionId, readTime, transactionOptions].nonNulls.length <= 1,
         'Only transactionId or readTime or transactionOptions must be provided. '
         'transactionId = $transactionId, readTime = $readTime, transactionOptions = $transactionOptions',
       );

  final Query<T> query;
  final String? transactionId;
  final Timestamp? readTime;
  final firestore_v1.TransactionOptions? transactionOptions;

  String? _retrievedTransactionId;

  /// Executes the query and captures the transaction ID from the response stream.
  ///
  /// Returns a [_QueryReaderResponse] containing both the query results and
  /// the transaction ID (if one was started or provided).
  Future<_QueryReaderResponse<T>> _get() async {
    final request = query._toProto(
      parent: query._buildProtoParentPath(),
      transactionId: transactionId,
      readTime: readTime,
      transactionOptions: transactionOptions,
    );

    final response = await query.firestore._firestoreClient.v1((
      api,
      projectId,
    ) async {
      return api.runQuery(request);
    });

    Timestamp? queryReadTime;
    final snapshots = <QueryDocumentSnapshot<T>>[];

    // Process streaming response
    await for (final e in response) {
      // Capture transaction ID from response (if present)
      if (e.transaction.isNotEmpty) {
        _retrievedTransactionId = base64Encode(e.transaction);
      }

      final document = e.document;
      if (document == null) {
        // End of stream marker
        if (e.readTime != null) {
          queryReadTime = Timestamp._fromProto(e.readTime!);
        }
        continue;
      }

      // Convert proto document to DocumentSnapshot
      final snapshot = DocumentSnapshot._fromDocument(
        document,
        e.readTime,
        query.firestore,
      );

      // Recreate with proper converter
      final finalDoc =
          _DocumentSnapshotBuilder(
              snapshot.ref.withConverter<T>(
                fromFirestore: query._queryOptions.converter.fromFirestore,
                toFirestore: query._queryOptions.converter.toFirestore,
              ),
            )
            ..fieldsProto = firestore_v1.MapValue(fields: document.fields)
            ..readTime = snapshot.readTime
            ..createTime = snapshot.createTime
            ..updateTime = snapshot.updateTime;

      snapshots.add(finalDoc.build() as QueryDocumentSnapshot<T>);
    }

    // Return both query results and transaction ID
    return _QueryReaderResponse<T>(
      QuerySnapshot<T>._(
        query: query,
        readTime: queryReadTime,
        docs: snapshots,
      ),
      _retrievedTransactionId,
    );
  }
}
