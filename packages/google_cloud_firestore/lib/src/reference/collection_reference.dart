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
interface class CollectionReference<T> extends Query<T> {
  CollectionReference._({
    required super.firestore,
    required _ResourcePath path,
    required _FirestoreDataConverter<T> converter,
  }) : super._(queryOptions: _QueryOptions.forCollectionQuery(path, converter));

  _ResourcePath get _resourcePath => _queryOptions.parentPath._append(id);

  /// The last path element of the referenced collection.
  String get id => _queryOptions.collectionId;

  /// A reference to the containing Document if this is a subcollection, else
  /// null.
  ///
  /// ```dart
  /// final collectionRef = firestore.collection('col/doc/subcollection');
  /// final documentRef = collectionRef.parent;
  /// print('Parent name: ${documentRef.path}');
  /// ```
  DocumentReference<DocumentData>? get parent {
    if (!_queryOptions.parentPath.isDocument) return null;

    return DocumentReference<DocumentData>._(
      firestore: firestore,
      path: _queryOptions.parentPath,
      converter: _jsonConverter,
    );
  }

  /// A string representing the path of the referenced collection (relative
  /// to the root of the database).
  String get path => _resourcePath.relativeName;

  /// Gets a [DocumentReference] instance that refers to the document at
  /// the specified path.
  ///
  /// If no path is specified, an automatically-generated unique ID will be
  /// used for the returned [DocumentReference].
  ///
  /// If using [withConverter], the [path] must not contain any slash.
  DocumentReference<T> doc([String? documentPath]) {
    final effectivePath = documentPath ?? autoId();

    if (documentPath != null) {
      _validateResourcePath('documentPath', documentPath);
    }

    final path = _resourcePath._append(effectivePath);
    if (!path.isDocument) {
      throw ArgumentError.value(
        documentPath,
        'documentPath',
        'Value for argument "documentPath" must point to a document, but was '
            '"$documentPath". Your path does not contain an even number of components.',
      );
    }

    if (!identical(_queryOptions.converter, _jsonConverter) &&
        path.parent() != _resourcePath) {
      throw ArgumentError.value(
        documentPath,
        'documentPath',
        'Value for argument "documentPath" must not contain a slash (/) if '
            'the parent collection has a custom converter.',
      );
    }

    return DocumentReference<T>._(
      firestore: firestore,
      path: path,
      converter: _queryOptions.converter,
    );
  }

  /// Retrieves the list of documents in this collection.
  ///
  /// The document references returned may include references to "missing
  /// documents", i.e. document locations that have no document present but
  /// which contain subcollections with documents. Attempting to read such a
  /// document reference (e.g. via [DocumentReference.get]) will return a
  /// [DocumentSnapshot] whose [DocumentSnapshot.exists] property is `false`.
  Future<List<DocumentReference<T>>> listDocuments() async {
    final response = await firestore._firestoreClient.v1((api, projectId) {
      final parentPath = _queryOptions.parentPath._toQualifiedResourcePath(
        projectId,
        firestore.databaseId,
      );

      final request = firestore_v1.ListDocumentsRequest(
        parent: parentPath._formattedName,
        collectionId: id,
        showMissing: true,
        // Setting `pageSize` to an arbitrarily large value lets the backend cap
        // the page size (currently to 300). Note that the backend rejects
        // MAX_INT32 (b/146883794).
        pageSize: math.pow(2, 16 - 1).toInt(),
        mask: firestore_v1.DocumentMask(fieldPaths: []),
      );

      return api.listDocuments(request);
    });

    return [
      for (final document in response.documents)
        doc(
          _QualifiedResourcePath.fromSlashSeparatedString(document.name).id!,
        ),
    ];
  }

  /// Add a new document to this collection with the specified data, assigning
  /// it a document ID automatically.
  Future<DocumentReference<T>> add(T data) async {
    final firestoreData = _queryOptions.converter.toFirestore(data);
    _validateDocumentData('data', firestoreData, allowDeletes: false);

    final documentRef = doc();
    final jsonDocumentRef = documentRef.withConverter<DocumentData>(
      fromFirestore: _jsonConverter.fromFirestore,
      toFirestore: _jsonConverter.toFirestore,
    );

    return jsonDocumentRef.create(firestoreData).then((_) => documentRef);
  }

  @override
  CollectionReference<U> withConverter<U>({
    FromFirestore<U>? fromFirestore,
    ToFirestore<U>? toFirestore,
  }) {
    // If null, use the default JSON converter
    final converter = (fromFirestore == null || toFirestore == null)
        ? _jsonConverter as _FirestoreDataConverter<U>
        : (fromFirestore: fromFirestore, toFirestore: toFirestore);

    return CollectionReference<U>._(
      firestore: firestore,
      path: _queryOptions.parentPath._append(id),
      converter: converter,
    );
  }

  @override
  // ignore: hash_and_equals, already implemented in Query
  bool operator ==(Object other) {
    return other is CollectionReference<T> && super == other;
  }
}
