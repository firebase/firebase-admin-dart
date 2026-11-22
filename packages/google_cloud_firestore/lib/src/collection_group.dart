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

@immutable
interface class CollectionGroup<T> extends Query<T> {
  CollectionGroup._(
    String collectionId, {
    required super.firestore,
    required _FirestoreDataConverter<T> converter,
  }) : super._(
         queryOptions: _QueryOptions.forCollectionGroupQuery(
           collectionId,
           converter,
         ),
       );

  /// Partitions a query by returning partition cursors that can be used to run
  /// the query in parallel.
  ///
  /// The returned partition cursors are split points that can be used as
  /// starting and end points for individual query invocations.
  ///
  /// This method automatically handles paginated API responses and fetches
  /// all available partition cursors across multiple pages.
  ///
  /// Example:
  /// ```dart
  /// final query = firestore.collectionGroup('collectionId');
  /// await for (final partition in query.getPartitions(42)) {
  ///   final partitionedQuery = partition.toQuery();
  ///   final querySnapshot = await partitionedQuery.get();
  ///   print('Partition contained ${querySnapshot.docs.length} documents');
  /// }
  /// ```
  ///
  /// [desiredPartitionCount] The desired maximum number of partition points.
  /// The number must be strictly positive. The actual number of partitions
  /// returned may be fewer.
  ///
  /// Returns a stream of [QueryPartition]s.
  Stream<QueryPartition<T>> getPartitions(int desiredPartitionCount) async* {
    // Validate the partition count
    _validatePartitionCount(desiredPartitionCount);

    // Fetch all partition cursors
    final partitions = desiredPartitionCount > 1
        ? await _fetchAllPartitionCursors(desiredPartitionCount)
        : <List<firestore_v1.Value>>[];

    // Sort partitions as they may not be ordered across multiple pages
    if (partitions.isNotEmpty) {
      mergeSort(partitions, compare: compareArrays);
    }

    // Yield all partitions
    yield* _yieldPartitions(partitions);
  }

  /// Validates that the partition count is valid.
  void _validatePartitionCount(int desiredPartitionCount) {
    if (desiredPartitionCount < 1) {
      throw FirestoreException(
        FirestoreClientErrorCode.invalidArgument,
        'Value for argument "desiredPartitionCount" must be within [1, Infinity] inclusive, but was: $desiredPartitionCount',
      );
    }
  }

  /// Fetches all partition cursors from the API, handling pagination automatically.
  Future<List<List<firestore_v1.Value>>> _fetchAllPartitionCursors(
    int desiredPartitionCount,
  ) async {
    final partitions = <List<firestore_v1.Value>>[];

    // Partition queries require explicit ordering by __name__.
    final queryWithDefaultOrder = orderBy(FieldPath.documentId);
    final structuredQuery = queryWithDefaultOrder._toStructuredQuery();

    // Since we are always returning an extra partition (with an empty endBefore
    // cursor), we reduce the desired partition count by one.
    final adjustedPartitionCount = desiredPartitionCount - 1;

    // Fetch all partition cursors, automatically handling pagination
    String? pageToken;
    do {
      final response = await _fetchPartitionPage(
        structuredQuery: structuredQuery,
        partitionCount: adjustedPartitionCount,
        pageToken: pageToken,
      );

      // Collect partitions from this page
      for (final cursor in response.partitions) {
        if (cursor.values.isNotEmpty) {
          partitions.add(cursor.values);
        }
      }

      // Continue to next page if token is present
      pageToken = response.nextPageToken;
    } while (pageToken.isNotEmpty);

    return partitions;
  }

  /// Fetches a single page of partition cursors from the API.
  Future<firestore_v1.PartitionQueryResponse> _fetchPartitionPage({
    required firestore_v1.StructuredQuery structuredQuery,
    required int partitionCount,
    String? pageToken,
  }) async {
    final partitionRequest = firestore_v1.PartitionQueryRequest(
      parent: '${firestore._formattedDatabaseName}/documents',
      structuredQuery: structuredQuery,
      partitionCount: partitionCount,
      pageToken: pageToken ?? '',
    );

    return firestore._firestoreClient.v1((api, projectId) {
      return api.partitionQuery(partitionRequest);
    });
  }

  /// Yields all partitions from the sorted list of cursor values.
  Stream<QueryPartition<T>> _yieldPartitions(
    List<List<firestore_v1.Value>> partitions,
  ) async* {
    // Yield partitions with appropriate start and end cursors
    for (var i = 0; i < partitions.length; i++) {
      yield QueryPartition<T>(
        firestore,
        _queryOptions.collectionId,
        _queryOptions.converter,
        i > 0 ? partitions[i - 1] : null,
        partitions[i],
      );
    }

    // Return the extra partition with the empty cursor.
    yield QueryPartition<T>(
      firestore,
      _queryOptions.collectionId,
      _queryOptions.converter,
      partitions.isNotEmpty ? partitions.last : null,
      null,
    );
  }

  @override
  CollectionGroup<U> withConverter<U>({
    FromFirestore<U>? fromFirestore,
    ToFirestore<U>? toFirestore,
  }) {
    // If null, use the default JSON converter
    final converter = (fromFirestore == null || toFirestore == null)
        ? _jsonConverter as _FirestoreDataConverter<U>
        : (fromFirestore: fromFirestore, toFirestore: toFirestore);

    return CollectionGroup._(
      _queryOptions.collectionId,
      firestore: firestore,
      converter: converter,
    );
  }

  @override
  // ignore: hash_and_equals, already implemented by Query
  bool operator ==(Object other) {
    return super == other && other is CollectionGroup<T>;
  }
}
