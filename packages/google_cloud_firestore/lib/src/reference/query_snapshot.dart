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
class QuerySnapshot<T> {
  QuerySnapshot._({
    required this.docs,
    required this.query,
    required this.readTime,
    List<DocumentChange<T>>? changes,
  }) : _changes = changes;

  /// The query used in order to get this [QuerySnapshot].
  final Query<T> query;

  /// The time this query snapshot was obtained.
  final Timestamp? readTime;

  /// A list of all the documents in this QuerySnapshot.
  final List<QueryDocumentSnapshot<T>> docs;

  /// The number of documents in the QuerySnapshot.
  int get size => docs.length;

  /// Returns true if there are no documents in the QuerySnapshot.
  bool get empty => docs.isEmpty;

  /// The changes of a snapshot from [Query.snapshots], when it is one.
  final List<DocumentChange<T>>? _changes;

  /// Returns a list of the documents changes since the last snapshot.
  ///
  /// If this is the first snapshot, all documents will be in the list as added
  /// changes. A snapshot obtained with [Query.get] is always a first
  /// snapshot.
  late final List<DocumentChange<T>> docChanges =
      _changes ??
      [
        for (final (index, doc) in docs.indexed)
          DocumentChange<T>._(
            type: DocumentChangeType.added,
            oldIndex: -1,
            newIndex: index,
            doc: doc,
          ),
      ];

  @override
  bool operator ==(Object other) {
    return other is QuerySnapshot<T> &&
        runtimeType == other.runtimeType &&
        query == other.query &&
        const ListEquality<QueryDocumentSnapshot<Object?>>().equals(
          docs,
          other.docs,
        ) &&
        const ListEquality<DocumentChange<Object?>>().equals(
          docChanges,
          other.docChanges,
        );
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    query,
    const ListEquality<QueryDocumentSnapshot<Object?>>().hash(docs),
    const ListEquality<DocumentChange<Object?>>().hash(docChanges),
  );
}
