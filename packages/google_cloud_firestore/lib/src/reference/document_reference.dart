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
interface class DocumentReference<T> implements _Serializable {
  const DocumentReference._({
    required this.firestore,
    required _ResourcePath path,
    required _FirestoreDataConverter<T> converter,
  }) : _converter = converter,
       _path = path;

  final _ResourcePath _path;
  final _FirestoreDataConverter<T> _converter;
  final Firestore firestore;

  /// A string representing the path of the referenced document (relative
  /// to the root of the database).
  ///
  /// ```dart
  /// final collectionRef = firestore.collection('col');
  ///
  /// collectionRef.add({'foo': 'bar'}).then((documentReference) {
  ///   print('Added document at "${documentReference.path}"');
  /// });
  /// ```
  String get path => _path.relativeName;

  /// The last path element of the referenced document.
  String get id => _path.id!;

  /// A reference to the collection to which this DocumentReference belongs.
  CollectionReference<T> get parent {
    return CollectionReference<T>._(
      firestore: firestore,
      path: _path.parent()!,
      converter: _converter,
    );
  }

  /// The string representation of the DocumentReference's location.
  /// This can only be called after projectId has been discovered.
  String get _formattedName {
    return _path
        ._toQualifiedResourcePath(firestore.projectId, firestore.databaseId)
        ._formattedName;
  }

  /// Fetches the subcollections that are direct children of this document.
  ///
  /// ```dart
  /// final documentRef = firestore.doc('col/doc');
  ///
  /// documentRef.listCollections().then((collections) {
  ///   for (final collection in collections) {
  ///     print('Found subcollection with id: ${collection.id}');
  ///   }
  /// });
  /// ```
  Future<List<CollectionReference<DocumentData>>> listCollections() {
    return firestore._firestoreClient.v1((a, projectId) async {
      final request = firestore_v1.ListCollectionIdsRequest(
        parent: _formattedName,
        // Setting `pageSize` to an arbitrarily large value lets the backend cap
        // the page size (currently to 300). Note that the backend rejects
        // MAX_INT32 (b/146883794).
        pageSize: (math.pow(2, 16) - 1).toInt(),
      );

      final result = await a.listCollectionIds(request);

      final ids = result.collectionIds;
      ids.sort((a, b) => a.compareTo(b));

      return [for (final id in ids) collection(id)];
    });
  }

  /// Changes the de/serializing mechanism for this [DocumentReference].
  ///
  /// Passing `null` for both parameters removes the current converter and
  /// returns an untyped `DocumentReference<DocumentData>`.
  ///
  /// This changes the return value of [DocumentSnapshot.data].
  DocumentReference<R> withConverter<R>({
    FromFirestore<R>? fromFirestore,
    ToFirestore<R>? toFirestore,
  }) {
    // If null, use the default JSON converter
    final converter = (fromFirestore == null || toFirestore == null)
        ? _jsonConverter as _FirestoreDataConverter<R>
        : (fromFirestore: fromFirestore, toFirestore: toFirestore);

    return DocumentReference<R>._(
      firestore: firestore,
      path: _path,
      converter: converter,
    );
  }

  Future<DocumentSnapshot<T>> get() async {
    final result = await firestore.getAll([this]);
    return result.single;
  }

  /// Create a document with the provided object values. This will fail the write
  /// if a document exists at its location.
  ///
  /// - [data]: An object that contains the fields and data to
  ///   serialize as the document.
  ///
  /// Throws if the provided input is not a valid Firestore document.
  ///
  /// Returns a Future that resolves with the write time of this create.
  ///
  /// ```dart
  /// final documentRef = firestore.collection('col').doc();
  ///
  /// documentRef.create({foo: 'bar'}).then((res) {
  ///   print('Document created at ${res.updateTime}');
  /// }).catch((err) => {
  ///   print('Failed to create document: ${err}');
  /// });
  /// ```
  Future<WriteResult> create(T data) async {
    final writeBatch = WriteBatch._(firestore)..create<T>(this, data);

    final results = await writeBatch.commit();
    return results.single;
  }

  /// Deletes the document referred to by this [DocumentReference].
  ///
  /// A delete for a non-existing document is treated as a success (unless
  /// [precondition] is specified).
  Future<WriteResult> delete([Precondition? precondition]) async {
    final writeBatch = WriteBatch._(firestore)
      ..delete(this, precondition: precondition);

    final results = await writeBatch.commit();
    return results.single;
  }

  /// Writes to the document referred to by this DocumentReference. If the
  /// document does not yet exist, it will be created. If [SetOptions] is provided,
  /// the data can be merged into the existing document.
  Future<WriteResult> set(T data, {SetOptions? options}) async {
    final writeBatch = WriteBatch._(firestore)
      ..set(this, data, options: options);

    final results = await writeBatch.commit();
    return results.single;
  }

  /// Updates fields in the document referred to by this DocumentReference.
  /// If the document doesn't yet exist, the update fails and the returned
  /// Promise will be rejected.
  ///
  /// The update() method accepts either an object with field paths encoded as
  /// keys and field values encoded as values, or a variable number of arguments
  /// that alternate between field paths and field values.
  ///
  /// A [Precondition] restricting this update can be specified as the last
  /// argument.
  Future<WriteResult> update(
    Map<Object?, Object?> data, [
    Precondition? precondition,
  ]) async {
    final writeBatch = WriteBatch._(firestore)
      ..update(this, {
        for (final entry in data.entries)
          FieldPath.from(entry.key): entry.value,
      }, precondition: precondition);

    final results = await writeBatch.commit();
    return results.single;
  }

  /// Gets a [CollectionReference] instance
  /// that refers to the collection at the specified path.
  ///
  /// - [collectionPath]: A slash-separated path to a collection.
  ///
  /// Returns A reference to the new subcollection.
  ///
  /// ```dart
  /// final documentRef = firestore.doc('col/doc');
  /// final subcollection = documentRef.collection('subcollection');
  /// print('Path to subcollection: ${subcollection.path}');
  /// ```
  CollectionReference<DocumentData> collection(String collectionPath) {
    _validateResourcePath('collectionPath', collectionPath);

    final path = _path._append(collectionPath);
    if (!path.isCollection) {
      throw ArgumentError.value(
        collectionPath,
        'collectionPath',
        'Value for argument "collectionPath" must point to a collection, but was '
            '"$collectionPath". Your path does not contain an odd number of components.',
      );
    }

    return CollectionReference<DocumentData>._(
      firestore: firestore,
      path: path,
      converter: _jsonConverter,
    );
  }

  // TODO snapshots

  @override
  firestore_v1.Value _toProto() {
    return firestore_v1.Value(referenceValue: _formattedName);
  }

  @override
  bool operator ==(Object other) {
    return other is DocumentReference<T> &&
        runtimeType == other.runtimeType &&
        firestore == other.firestore &&
        _path == other._path &&
        _converter == other._converter;
  }

  @override
  int get hashCode => Object.hash(runtimeType, firestore, _path, _converter);
}
