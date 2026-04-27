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

import 'dart:async';
import 'dart:convert' show base64Decode, base64Encode, jsonEncode, utf8;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:google_cloud_firestore_v1/firestore.dart' as firestore_v1;
import 'package:google_cloud_protobuf/protobuf.dart' as protobuf_v1;
import 'package:google_cloud_type/type.dart' as type_v1;
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

import 'backoff.dart';
import 'credential.dart';
import 'firestore_exception.dart';
import 'firestore_http_client.dart';
import 'status_code.dart';

part 'aggregate.dart';
part 'bulk_writer.dart';
part 'bundle.dart';
part 'collection_group.dart';
part 'convert.dart';
part 'aggregation_reader.dart';
part 'document.dart';
part 'document_change.dart';
part 'document_reader.dart';
part 'field_value.dart';
part 'recursive_delete.dart';
part 'filter.dart';
part 'geo_point.dart';
part 'order.dart';
part 'path.dart';
part 'query_partition.dart';
part 'query_profile.dart';
part 'rate_limiter.dart';
part 'query_reader.dart';
part 'reference/aggregate_query.dart';
part 'reference/aggregate_query_snapshot.dart';
part 'reference/collection_reference.dart';
part 'reference/composite_filter_internal.dart';
part 'reference/constants.dart';
part 'reference/document_reference.dart';
part 'reference/field_filter_internal.dart';
part 'reference/field_order.dart';
part 'reference/filter_internal.dart';
part 'reference/query.dart';
part 'reference/query_options.dart';
part 'reference/query_snapshot.dart';
part 'reference/query_util.dart';
part 'reference/types.dart';
part 'reference/vector_query.dart';
part 'reference/vector_query_options.dart';
part 'reference/vector_query_snapshot.dart';
part 'serializer.dart';
part 'set_options.dart';
part 'timestamp.dart';
part 'transaction.dart';
part 'types.dart';
part 'util.dart';
part 'validate.dart';
part 'write_batch.dart';

/// Settings used to configure a Firestore instance.
///
/// Example:
/// ```dart
/// // Option 1: With service account file
/// final firestore = Firestore(
///   settings: Settings(
///     credential: Credential.fromServiceAccount(
///       File('/path/to/service-account.json'),
///     ),
///   ),
/// );
///
/// // Option 2: With explicit parameters
/// final firestore = Firestore(
///   settings: Settings(
///     projectId: 'my-project',
///     credential: Credential.fromServiceAccountParams(
///       email: 'xxx@xxx.iam.gserviceaccount.com',
///       privateKey: '-----BEGIN PRIVATE KEY-----...',
///       projectId: 'my-project',
///     ),
///   ),
/// );
///
/// // Option 3: Use Application Default Credentials
/// final firestore = Firestore();
/// ```
@immutable
class Settings {
  /// Creates Firestore settings.
  const Settings({
    this.projectId,
    this.databaseId,
    this.host,
    this.ssl = true,
    this.credential,
    this.ignoreUndefinedProperties = false,
    this.useBigInt = false,
    this.environmentOverride,
  });

  /// The project ID from the Google Developer's Console, e.g. 'grape-spaceship-123'.
  ///
  /// Can be omitted in environments that support Application Default Credentials.
  /// The SDK will check the environment variable GCLOUD_PROJECT or
  /// GOOGLE_CLOUD_PROJECT for your project ID.
  final String? projectId;

  /// The database name. If omitted, the default database will be used.
  ///
  /// Defaults to '(default)'.
  final String? databaseId;

  /// The hostname to connect to.
  ///
  /// For emulator: Use the FIRESTORE_EMULATOR_HOST environment variable or
  /// set this to 'localhost:8080' (or your emulator's host:port).
  final String? host;

  /// Whether to use SSL when connecting.
  ///
  /// Defaults to true. Set to false when using the emulator.
  final bool ssl;

  /// The credential to use for authentication.
  ///
  /// Can be omitted to use Application Default Credentials.
  ///
  /// Example:
  /// ```dart
  /// credential: Credential.fromServiceAccount(
  ///   File('/path/to/service-account.json'),
  /// )
  /// ```
  final Credential? credential;

  /// Whether to skip nested properties that are set to `null` during
  /// object serialization.
  ///
  /// If set to `true`, these properties are skipped and not written to Firestore.
  /// If set to `false` (default), the SDK throws an exception when it encounters
  /// properties of type `null` in maps.
  final bool ignoreUndefinedProperties;

  /// Whether to use `BigInt` for integer types when deserializing Firestore
  /// Documents.
  ///
  /// Regardless of magnitude, all integer values are returned as `BigInt` to
  /// match the precision of the Firestore backend. Floating point numbers
  /// continue to use Dart's `double` type.
  ///
  /// Defaults to false.
  final bool useBigInt;

  /// Environment variable overrides for testing.
  ///
  /// This allows tests to inject environment variables (like FIRESTORE_EMULATOR_HOST)
  /// without modifying the actual process environment.
  ///
  /// Example:
  /// ```dart
  /// final settings = Settings(
  ///   environmentOverride: {'FIRESTORE_EMULATOR_HOST': 'localhost:8080'},
  /// );
  /// ```
  final Map<String, String>? environmentOverride;

  /// Creates a copy of this Settings with the given fields replaced.
  Settings copyWith({
    String? projectId,
    String? databaseId,
    String? host,
    bool? ssl,
    Credential? credential,
    bool? ignoreUndefinedProperties,
    bool? useBigInt,
    Map<String, String>? environmentOverride,
  }) {
    return Settings(
      projectId: projectId ?? this.projectId,
      databaseId: databaseId ?? this.databaseId,
      host: host ?? this.host,
      ssl: ssl ?? this.ssl,
      credential: credential ?? this.credential,
      ignoreUndefinedProperties:
          ignoreUndefinedProperties ?? this.ignoreUndefinedProperties,
      useBigInt: useBigInt ?? this.useBigInt,
      environmentOverride: environmentOverride ?? this.environmentOverride,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Settings &&
          runtimeType == other.runtimeType &&
          projectId == other.projectId &&
          databaseId == other.databaseId &&
          host == other.host &&
          ssl == other.ssl &&
          credential == other.credential &&
          ignoreUndefinedProperties == other.ignoreUndefinedProperties &&
          useBigInt == other.useBigInt;

  @override
  int get hashCode => Object.hash(
    projectId,
    databaseId,
    host,
    ssl,
    credential,
    ignoreUndefinedProperties,
    useBigInt,
  );
}

/// Options for configuring transactions.
sealed class TransactionOptions {
  /// Whether this is a read-only transaction.
  bool get readOnly;

  /// Maximum number of attempts for this transaction.
  int get maxAttempts;
}

/// Options for read-only transactions.
class ReadOnlyTransactionOptions extends TransactionOptions {
  /// Creates read-only transaction options.
  ///
  /// [readTime] Reads documents at the given time. This may not be older than
  /// 270 seconds.
  ReadOnlyTransactionOptions({Timestamp? readTime}) : _readTime = readTime;

  @override
  bool readOnly = true;

  @override
  int get maxAttempts => 1;

  /// The time at which to read documents.
  Timestamp? get readTime => _readTime;

  final Timestamp? _readTime;
}

/// Options for read-write transactions.
class ReadWriteTransactionOptions extends TransactionOptions {
  /// Creates read-write transaction options.
  ///
  /// [maxAttempts] The maximum number of attempts for this transaction.
  /// Defaults to 5.
  ReadWriteTransactionOptions({int maxAttempts = 5})
    : _maxAttempts = maxAttempts;

  final int _maxAttempts;

  @override
  bool readOnly = false;

  @override
  int get maxAttempts => _maxAttempts;
}

/// The Cloud Firestore service interface.
///
/// Example (standalone usage):
/// ```dart
/// // Using Application Default Credentials
/// final firestore = Firestore();
///
/// // With explicit credentials
/// final firestore = Firestore(
///   settings: Settings(
///     projectId: 'my-project',
///     credentials: Credentials(
///       clientEmail: 'xxx@xxx.iam.gserviceaccount.com',
///       privateKey: '-----BEGIN PRIVATE KEY-----...',
///     ),
///   ),
/// );
/// ```
class Firestore {
  /// Creates a Firestore instance.
  ///
  /// [settings] Configuration options for this Firestore instance.
  factory Firestore({Settings? settings}) {
    return Firestore._(settings: settings);
  }

  @internal
  factory Firestore.internal({
    Settings? settings,
    FirestoreHttpClient? client,
  }) {
    return Firestore._(settings: settings, client: client);
  }

  Firestore._({Settings? settings, FirestoreHttpClient? client})
    : _settings = settings ?? const Settings() {
    final credential =
        _settings.credential ?? Credential.fromApplicationDefaultCredentials();
    _firestoreClient =
        client ??
        FirestoreHttpClient(credential: credential, settings: _settings);
  }

  final Settings _settings;
  late final FirestoreHttpClient _firestoreClient;

  /// The serializer to use for the Protobuf transformation.
  /// @internal
  late final Serializer _serializer = Serializer._(this);

  @visibleForTesting
  Serializer get serializer => _serializer;

  /// Returns the project ID for this Firestore instance.
  ///
  /// Throws if the project ID has not been discovered yet.
  String get projectId {
    final cached = _firestoreClient.cachedProjectId;
    if (cached != null) return cached;

    // Fall back to explicitly set project ID
    final explicit = _settings.projectId;
    if (explicit != null) return explicit;

    throw StateError(
      'Project ID has not been discovered yet. '
      'Initialize the SDK with credentials that include a project ID, '
      'set project ID in Settings, or set the GOOGLE_CLOUD_PROJECT environment variable.',
    );
  }

  /// Returns the Database ID for this Firestore instance.
  String get databaseId => _settings.databaseId ?? '(default)';

  /// Returns the root path of the database.
  ///
  /// Format: 'projects/${projectId}/databases/${databaseId}'
  /// @internal
  String get _formattedDatabaseName {
    return 'projects/$projectId/databases/$databaseId';
  }

  /// Gets a [DocumentReference] instance that refers to the document at the
  /// specified path.
  ///
  /// [documentPath] A slash-separated path to a document.
  ///
  /// Returns the [DocumentReference] instance.
  ///
  /// Example:
  /// ```dart
  /// final documentRef = firestore.doc('collection/document');
  /// print('Path of document is ${documentRef.path}');
  /// ```
  DocumentReference<DocumentData> doc(String documentPath) {
    _validateResourcePath('documentPath', documentPath);

    final path = _ResourcePath.empty._append(documentPath);
    if (!path.isDocument) {
      throw ArgumentError(
        'Value for argument "documentPath" must point to a document, but was '
        '"$documentPath". Your path does not contain an even number of components.',
      );
    }

    return DocumentReference._(
      firestore: this,
      path: path,
      converter: _jsonConverter,
    );
  }

  /// Gets a [CollectionReference] instance that refers to the collection at
  /// the specified path.
  ///
  /// [collectionPath] A slash-separated path to a collection.
  ///
  /// Returns the [CollectionReference] instance.
  ///
  /// Example:
  /// ```dart
  /// final collectionRef = firestore.collection('collection');
  ///
  /// // Add a document with an auto-generated ID.
  /// collectionRef.add({'foo': 'bar'}).then((documentRef) {
  ///   print('Added document at ${documentRef.path})');
  /// });
  /// ```
  CollectionReference<DocumentData> collection(String collectionPath) {
    _validateResourcePath('collectionPath', collectionPath);

    final path = _ResourcePath.empty._append(collectionPath);
    if (!path.isCollection) {
      throw ArgumentError(
        'Value for argument "collectionPath" must point to a collection, but was '
        '"$collectionPath". Your path does not contain an odd number of components.',
      );
    }

    return CollectionReference._(
      firestore: this,
      path: path,
      converter: _jsonConverter,
    );
  }

  /// Creates and returns a new [Query] that includes all documents in the
  /// database that are contained in a collection or subcollection with the
  /// given [collectionId].
  ///
  /// [collectionId] Identifies the collections to query over. Every collection
  /// or subcollection with this ID as the last segment of its path will be
  /// included. Cannot contain a slash.
  ///
  /// Returns a [CollectionGroup] query.
  ///
  /// Example:
  /// ```dart
  /// await firestore.doc('my-group/docA').set({'foo': 'bar'});
  /// await firestore.doc('abc/def/my-group/docB').set({'foo': 'bar'});
  ///
  /// final query = firestore.collectionGroup('my-group')
  ///     .where('foo', isEqualTo: 'bar');
  /// final snapshot = await query.get();
  /// print('Found ${snapshot.docs.length} documents.');
  /// ```
  CollectionGroup<DocumentData> collectionGroup(String collectionId) {
    if (collectionId.contains('/')) {
      throw ArgumentError(
        'Invalid collectionId "$collectionId". Collection IDs must not contain "/".',
      );
    }

    return CollectionGroup._(
      collectionId,
      firestore: this,
      converter: _jsonConverter,
    );
  }

  /// Fetches the root collections that are associated with this Firestore
  /// database.
  ///
  /// Returns a list of [CollectionReference] instances.
  ///
  /// Example:
  /// ```dart
  /// final collections = await firestore.listCollections();
  /// for (final collection in collections) {
  ///   print('Found collection with id: ${collection.id}');
  /// }
  /// ```
  Future<List<CollectionReference<DocumentData>>> listCollections() {
    final rootDocument = DocumentReference<DocumentData>._(
      firestore: this,
      path: _ResourcePath.empty,
      converter: _jsonConverter,
    );

    return rootDocument.listCollections();
  }

  /// Creates a write batch, used for performing multiple writes as a single
  /// atomic operation.
  ///
  /// Returns a [WriteBatch] instance.
  ///
  /// Example:
  /// ```dart
  /// final batch = firestore.batch();
  ///
  /// final nycRef = firestore.collection('cities').doc('NYC');
  /// batch.set(nycRef, {'name': 'New York City'});
  ///
  /// final sfRef = firestore.collection('cities').doc('SF');
  /// batch.update(sfRef, {'population': 1000000});
  ///
  /// await batch.commit();
  /// ```
  WriteBatch batch() {
    return WriteBatch._(this);
  }

  /// Creates a [BundleBuilder] for building a Firestore data bundle.
  ///
  /// Data bundles contain snapshots of Firestore documents and queries that
  /// can be preloaded into clients for faster initial access or reduced costs.
  ///
  /// Example:
  /// ```dart
  /// final bundle = firestore.bundle('my-bundle');
  /// final docSnapshot = await firestore.doc('cities/SF').get();
  /// final querySnapshot = await firestore.collection('cities').get();
  ///
  /// bundle
  ///   ..addDocument(docSnapshot)
  ///   ..addQuery('all-cities', querySnapshot);
  ///
  /// final bytes = bundle.build();
  /// // Save bytes to CDN or stream to clients
  /// ```
  ///
  /// [bundleId] - The ID of the bundle.
  ///
  /// Returns a [BundleBuilder] instance.
  BundleBuilder bundle(String bundleId) {
    return BundleBuilder(bundleId);
  }

  /// Creates a DocumentSnapshot from raw proto data.
  ///
  /// This is an internal test helper method that allows creating snapshots
  /// from raw document protos or document names without actual Firestore operations.
  ///
  /// If passed a [firestore_v1.Document], creates a snapshot for an existing document.
  /// If passed a [String], creates a snapshot for a missing document.
  ///
  /// @nodoc
  @internal
  DocumentSnapshot<Object?> snapshot_(
    Object documentOrName,
    Timestamp readTime,
  ) {
    final readTimeProto = readTime._toProto().timestampValue;

    if (documentOrName is String) {
      return DocumentSnapshot._missing(documentOrName, readTimeProto, this);
    } else if (documentOrName is firestore_v1.Document) {
      return DocumentSnapshot._fromDocument(
        documentOrName,
        readTimeProto,
        this,
      );
    }

    throw ArgumentError(
      'documentOrName must be either a String or firestore_v1.Document',
    );
  }

  @internal
  QuerySnapshot<T> querySnapshot_<T>(
    Query<T> query,
    Timestamp readTime,
    List<QueryDocumentSnapshot<T>> docs,
  ) {
    return QuerySnapshot<T>._(query: query, readTime: readTime, docs: docs);
  }

  /// Creates a QuerySnapshot for testing purposes.
  ///
  /// This is an internal test helper method that allows creating query snapshots
  /// without actual Firestore operations.
  ///
  /// @internal
  @visibleForTesting
  QuerySnapshot<Object?> createQuerySnapshot({
    required Query<Object?> query,
    required Timestamp readTime,
    required List<QueryDocumentSnapshot<Object?>> docs,
  }) {
    return QuerySnapshot<Object?>._(
      query: query,
      readTime: readTime,
      docs: docs,
    );
  }

  /// Creates a [BulkWriter] instance for performing a large number of writes
  /// in parallel.
  ///
  /// BulkWriter automatically batches writes (maximum 20 operations per batch),
  /// sends them in parallel, and includes automatic retry logic for transient
  /// failures. Each write operation returns its own Future that resolves when
  /// that specific write completes.
  ///
  /// The [options] parameter allows you to configure rate limiting and throttling:
  /// - Default (no options): 500 ops/sec initial, 10,000 ops/sec max
  /// - Disable throttling entirely:
  ///   ```dart
  ///   firestore.bulkWriter(
  ///     BulkWriterOptions(throttling: DisabledThrottling()),
  ///   )
  ///   ```
  /// - Custom throttling:
  ///   ```dart
  ///   firestore.bulkWriter(
  ///     BulkWriterOptions(
  ///       throttling: EnabledThrottling(
  ///         initialOpsPerSecond: 100,
  ///         maxOpsPerSecond: 1000,
  ///       ),
  ///     ),
  ///   )
  ///   ```
  ///
  /// Example:
  /// ```dart
  /// final bulkWriter = firestore.bulkWriter();
  ///
  /// // Set up error handling
  /// bulkWriter.onWriteError((error) {
  ///   if (error.code == FirestoreClientErrorCode.unavailable &&
  ///       error.failedAttempts < 5) {
  ///     return true; // Retry
  ///   }
  ///   print('Failed write: ${error.documentRef.path}');
  ///   return false; // Don't retry
  /// });
  ///
  /// // Each write returns its own Future
  /// final future1 = bulkWriter.set(
  ///   firestore.collection('cities').doc('SF'),
  ///   {'name': 'San Francisco'},
  /// );
  /// final future2 = bulkWriter.set(
  ///   firestore.collection('cities').doc('LA'),
  ///   {'name': 'Los Angeles'},
  /// );
  ///
  /// // Wait for all writes to complete
  /// await bulkWriter.close();
  /// ```
  BulkWriter bulkWriter([BulkWriterOptions? options]) {
    return BulkWriter._(this, options);
  }

  /// Executes the given [updateFunction] and commits the changes applied
  /// within the transaction.
  ///
  /// You can use the transaction object passed to [updateFunction] to read and
  /// modify Firestore documents under lock. Transactions are committed once
  /// [updateFunction] resolves and attempted up to five times on failure.
  ///
  /// [updateFunction] The function to execute within the transaction context.
  /// [transactionOptions] Options to configure the transaction behavior.
  ///
  /// Returns a Future that resolves with the value returned by [updateFunction].
  ///
  /// Example:
  /// ```dart
  /// final cityRef = firestore.doc('cities/SF');
  /// await firestore.runTransaction((transaction) async {
  ///   final snapshot = await transaction.get(cityRef);
  ///   final newPopulation = snapshot.get('population') + 1;
  ///   transaction.update(cityRef, {'population': newPopulation});
  /// });
  /// ```
  Future<T> runTransaction<T>(
    TransactionHandler<T> updateFunction, {
    TransactionOptions? transactionOptions,
  }) async {
    final transaction = Transaction(this, transactionOptions);
    return transaction._runTransaction(updateFunction);
  }

  /// Retrieves multiple documents from Firestore.
  ///
  /// [documentRefs] The document references to fetch.
  /// [readOptions] Optional read options (for field mask, etc.).
  ///
  /// Returns a list of [DocumentSnapshot] instances in the same order as the
  /// input references.
  ///
  /// Example:
  /// ```dart
  /// final documentRef1 = firestore.doc('col/doc1');
  /// final documentRef2 = firestore.doc('col/doc2');
  ///
  /// final docs = await firestore.getAll([documentRef1, documentRef2]);
  /// print('First document: ${docs[0].data()}');
  /// print('Second document: ${docs[1].data()}');
  /// ```
  Future<List<DocumentSnapshot<T>>> getAll<T>(
    List<DocumentReference<T>> documentRefs, [
    ReadOptions? readOptions,
  ]) async {
    if (documentRefs.isEmpty) {
      throw ArgumentError('documentRefs must not be an empty array.');
    }

    final fieldMask = _parseFieldMask(readOptions);

    final reader = _DocumentReader(
      firestore: this,
      documents: documentRefs,
      fieldMask: fieldMask,
    );

    return reader.get();
  }

  /// Recursively deletes all documents and subcollections at and under the
  /// specified reference.
  ///
  /// If any delete fails, the Future is rejected with an error message
  /// containing the number of failed deletes and the stack trace of the last
  /// failed delete. The provided reference is deleted regardless of whether
  /// all deletes succeeded.
  ///
  /// `recursiveDelete()` uses a [BulkWriter] instance with default settings to
  /// perform the deletes. To customize throttling rates or add success/error
  /// callbacks, pass in a custom [BulkWriter] instance.
  ///
  /// [ref] The reference of a document or collection to delete.
  /// [bulkWriter] A custom BulkWriter instance used to perform the deletes.
  ///
  /// Returns a Future that resolves when all deletes have been performed.
  /// The Future is rejected if any of the deletes fail.
  ///
  /// Example:
  /// ```dart
  /// // Recursively delete a reference and log the references of failures.
  /// final bulkWriter = firestore.bulkWriter();
  /// bulkWriter.onWriteError((error) {
  ///   if (error.failedAttempts < maxRetryAttempts) {
  ///     return true;
  ///   } else {
  ///     print('Failed write at document: ${error.documentRef.path}');
  ///     return false;
  ///   }
  /// });
  /// await firestore.recursiveDelete(docRef, bulkWriter);
  /// ```
  Future<void> recursiveDelete(Object ref, [BulkWriter? bulkWriter]) async {
    if (ref is! DocumentReference && ref is! CollectionReference) {
      throw ArgumentError(
        'Value for argument "ref" must be a DocumentReference or '
        'CollectionReference, but was ${ref.runtimeType}.',
      );
    }

    final writer = bulkWriter ?? this.bulkWriter();
    final deleter = _RecursiveDelete(firestore: this, writer: writer, ref: ref);

    try {
      await deleter.run();
    } finally {
      // Close the writer only if we created it
      if (bulkWriter == null) {
        await writer.close();
      }
    }
  }

  /// Returns a JSON-serializable representation of this Firestore instance.
  ///
  /// Returns a Map containing the projectId if it has been determined.
  ///
  /// Example:
  /// ```dart
  /// final firestore = Firestore(Settings(projectId: 'my-project'));
  /// print(firestore.toJSON()); // {projectId: my-project}
  /// ```
  Map<String, String?> toJSON() {
    return {
      'projectId': _firestoreClient.cachedProjectId ?? _settings.projectId,
    };
  }

  /// Terminates the Firestore client and closes all open connections.
  ///
  /// After calling terminate, the Firestore instance is no longer usable.
  Future<void> terminate() async {
    // Close connections if needed
    await _firestoreClient.close();
  }
}
