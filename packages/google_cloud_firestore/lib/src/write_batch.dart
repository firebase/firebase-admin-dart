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

/// A WriteResult wraps the write time set by the Firestore servers on sets(),
/// updates(), and creates().
@immutable
class WriteResult {
  const WriteResult._(this.writeTime);

  /// The write time as set by the Firestore servers.
  final Timestamp writeTime;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WriteResult && writeTime == other.writeTime;
  }

  @override
  int get hashCode => writeTime.hashCode;
}

/// A Firestore WriteBatch that can be used to atomically commit multiple write
/// operations at once.
class WriteBatch {
  WriteBatch._(this.firestore);

  final Firestore firestore;
  var _commited = false;
  final _operations = <({String docPath, firestore_v1.Write Function() op})>[];

  /// Create a document with the provided object values. This will fail the batch
  /// if a document exists at its location.
  ///
  /// - [ref]: A reference to the document to be created.
  /// - [data] The object to serialize as the document.
  ///
  /// Throws if the provided input is not a valid Firestore document.
  ///
  /// ```dart
  /// final writeBatch = firestore.batch();
  /// final documentRef = firestore.collection('col').doc();
  ///
  /// writeBatch.create(documentRef, {foo: 'bar'});
  ///
  /// writeBatch.commit().then(() {
  ///   print('Successfully executed batch.');
  /// });
  /// ```
  void create<T>(DocumentReference<T> ref, T data) {
    final firestoreData = ref._converter.toFirestore(data);
    _validateDocumentData('data', firestoreData, allowDeletes: false);

    _verifyNotCommited();

    final transform = _DocumentTransform.fromObject(ref, firestoreData);
    transform.validate();

    firestore_v1.Write op() {
      final document = DocumentSnapshot._fromObject(ref, firestoreData);
      final writeProto = document._toWriteProto();
      return firestore_v1.Write(
        update: writeProto.update,
        updateTransforms:
            transform.transforms.isNotEmpty
                ? transform.toProto(firestore._serializer)
                : const [],
        currentDocument: firestore_v1.Precondition(exists: false),
      );
    }


    _operations.add((docPath: ref.path, op: op));
  }

  /// Atomically commits all pending operations to the database and verifies all
  /// preconditions. Fails the entire write if any precondition is not met.
  ///
  /// Returns a future that resolves when this batch completes.
  ///
  /// ```dart
  /// final writeBatch = firestore.batch();
  /// final documentRef = firestore.doc('col/doc');
  ///
  /// writeBatch.set(documentRef, {foo: 'bar'});
  ///
  /// writeBatch.commit().then(() {
  ///   console.log('Successfully executed batch.');
  /// });
  /// ```
  Future<List<WriteResult>> commit([String? transactionId]) async {
    final response = await _commit(transactionId: transactionId);

    return [
      for (final writeResult in response.writeResults)
        WriteResult._(
          Timestamp._fromProto(writeResult.updateTime ?? response.commitTime!),
        ),
    ];
  }

  Future<firestore_v1.CommitResponse> _commit({
    required String? transactionId,
  }) async {
    _commited = true;

    final request = firestore_v1.CommitRequest(
      database: firestore._formattedDatabaseName,
      writes: _operations.map((op) => op.op()).toList(),
      transaction: transactionId.let(base64Decode),
    );

    if (transactionId != null) {
      return firestore._firestoreClient.v1((api, projectId) async {
        return api.commit(request);
      });
    }

    const retryCodes = StatusCode.resourceExhaustedAbortedUnavailable;
    const maxAttempts = 5;

    final backoff = ExponentialBackoff();
    FirestoreException? lastError;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await _maybeBackoff(backoff, lastError);
        return await firestore._firestoreClient.v1((api, projectId) async {
          return api.commit(request);
        });
      } on FirestoreException catch (e) {
        lastError = e;
        if (!retryCodes.contains(e.errorCode.statusCode)) {
          rethrow;
        }
      }
    }

    throw lastError!;
  }

  ///Resets the WriteBatch and dequeues all pending operations.
  void reset() {
    _operations.clear();
    _commited = false;
  }

  /// Deletes a document from the database.
  ///
  /// - [precondition] can be passed to specify custom requirements for the
  ///   request (e.g. only delete if it was last updated at a given time).
  void delete(
    DocumentReference<Object?> documentRef, {
    Precondition? precondition,
  }) {
    _verifyNotCommited();

    firestore_v1.Write op() {
      return firestore_v1.Write(
        delete: documentRef._formattedName,
        currentDocument: precondition?._toProto(),
      );
    }

    _operations.add((docPath: documentRef.path, op: op));
  }

  /// Write to the document referred to by the provided
  /// [DocumentReference]. If the document does not
  /// exist yet, it will be created. If [SetOptions] is provided,
  /// the data can be merged into the existing document.
  void set<T>(
    DocumentReference<T> documentReference,
    T data, {
    SetOptions? options,
  }) {
    final firestoreData = documentReference._converter.toFirestore(data);

    final mergeLeaves =
        options != null && options.isMerge && options.mergeFields == null;
    final mergePaths = options?.mergeFields;

    _validateDocumentData(
      'data',
      firestoreData,
      allowDeletes: mergePaths != null || mergeLeaves,
    );

    _verifyNotCommited();

    _DocumentMask? documentMask;

    if (mergePaths != null) {
      documentMask = _DocumentMask.fromFieldMask(mergePaths);
      final filteredData = documentMask.applyTo(firestoreData);

      final transform = _DocumentTransform.fromObject(
        documentReference,
        filteredData,
      );
      transform.validate();

      firestore_v1.Write op() {
        final document = DocumentSnapshot._fromObject(
          documentReference,
          filteredData,
        );

        final writeProto = document._toWriteProto();

        final mask = documentMask!;
        mask.removeFields(transform.transforms.keys.toList());

        return firestore_v1.Write(
          update: writeProto.update,
          updateMask: mask.toProto(),
          updateTransforms:
              transform.transforms.isNotEmpty
                  ? transform.toProto(firestore._serializer)
                  : const [],
        );
      }

      _operations.add((docPath: documentReference.path, op: op));
    } else {
      final transform = _DocumentTransform.fromObject(
        documentReference,
        firestoreData,
      );
      transform.validate();

      firestore_v1.Write op() {
        final document = DocumentSnapshot._fromObject(
          documentReference,
          firestoreData,
        );

        final writeProto = document._toWriteProto();
        firestore_v1.DocumentMask? updateMask;

        if (mergeLeaves) {
          final mask = _DocumentMask.fromObject(firestoreData);
          mask.removeFields(transform.transforms.keys.toList());
          updateMask = mask.toProto();
        }

        return firestore_v1.Write(
          update: writeProto.update,
          updateMask: updateMask,
          updateTransforms:
              transform.transforms.isNotEmpty
                  ? transform.toProto(firestore._serializer)
                  : const [],
        );
      }

      _operations.add((docPath: documentReference.path, op: op));
    }
  }

  /// Update fields of the document referred to by the provided
  /// [DocumentReference]. If the document doesn't yet exist,
  /// the update fails and the entire batch will be rejected.
  // TODO support update(ref, List<(FieldPath, value)>)
  void update(
    DocumentReference<Object?> documentRef,
    UpdateMap data, {
    Precondition? precondition,
  }) {
    _update(data: data, documentRef: documentRef, precondition: precondition);
  }

  void _update({
    required UpdateMap data,
    required DocumentReference<Object?> documentRef,
    required Precondition? precondition,
  }) {
    _verifyNotCommited();
    _validateUpdateMap('data', data);

    precondition ??= Precondition.exists(true);

    _validateNoConflictingFields('data', data);

    final transform = _DocumentTransform.fromUpdateMap(documentRef, data);
    transform.validate();

    final documentMask = _DocumentMask.fromUpdateMap(data);

    firestore_v1.Write op() {
      final document = DocumentSnapshot.fromUpdateMap(documentRef, data);
      final writeProto = document._toWriteProto();

      return firestore_v1.Write(
        update: writeProto.update,
        updateMask: documentMask.toProto(),
        updateTransforms:
            transform.transforms.isNotEmpty
                ? transform.toProto(firestore._serializer)
                : const [],
        currentDocument: precondition?._toProto(),
      );
    }


    _operations.add((docPath: documentRef.path, op: op));
  }

  void _verifyNotCommited() {
    if (_commited) {
      throw StateError('Cannot modify a WriteBatch that has been committed.');
    }
  }
}

/// Validates that the update data does not contain any ambiguous field
/// definitions (such as 'a.b' and 'a').
void _validateNoConflictingFields(String arg, Map<FieldPath, Object?> data) {
  final fields = data.keys.sorted((left, right) => left.compareTo(right));

  for (var i = 1; i < fields.length; i++) {
    if (fields[i - 1]._isPrefixOf(fields[i])) {
      throw ArgumentError.value(
        data,
        arg,
        'Field "${fields[i - 1]._formattedName}" was specified multiple times.',
      );
    }
  }
}

void _validateUpdateMap(String arg, UpdateMap obj) {
  if (obj.isEmpty) {
    throw ArgumentError.value(obj, arg, 'At least one field must be updated.');
  }

  _validateFieldValue(arg, obj);
}

void _validateFieldValue(String arg, UpdateMap obj, {FieldPath? path}) {
  _validateUserInput(
    arg,
    obj,
    description: 'Firestore value',
    options: const _ValidateUserInputOptions(
      allowDeletes: _AllowDeletes.root,
      allowTransform: true,
    ),
    path: path,
  );
}

void _validateDocumentData(
  String arg,
  Object? obj, {
  required bool allowDeletes,
}) {
  if (obj is! DocumentData) {
    throw ArgumentError.value(
      obj,
      arg,
      'Value for argument "$arg" is not a valid Firestore document. Input '
      'is not a plain JavaScript object.',
    );
  }

  _validateUserInput(
    arg,
    obj,
    description: 'Firestore document',
    options: _ValidateUserInputOptions(
      allowDeletes: allowDeletes ? _AllowDeletes.all : _AllowDeletes.none,
      allowTransform: true,
    ),
  );
}
