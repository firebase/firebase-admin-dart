// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

part of 'firestore.dart';

const int _bundleVersion = 1;

/// Compares two Timestamps.
/// Returns:
/// - negative value if [a] is before [b]
/// - zero if [a] equals [b]
/// - positive value if [a] is after [b]
int _compareTimestamps(Timestamp a, Timestamp b) {
  final secondsDiff = a.seconds - b.seconds;
  if (secondsDiff != 0) return secondsDiff;
  return a.nanoseconds - b.nanoseconds;
}

/// Helper extension to convert LimitType to JSON string.
extension _LimitTypeJson on LimitType {
  String toJson() => name.toUpperCase();
}

/// Metadata for a Firestore bundle.
@immutable
class BundleMetadata {
  const BundleMetadata({
    required this.id,
    required this.createTime,
    required this.version,
    required this.totalDocuments,
    required this.totalBytes,
  });

  /// The ID of the bundle.
  final String id;

  /// The timestamp at which this bundle was created.
  final Timestamp createTime;

  /// The schema version of the bundle.
  final int version;

  /// The number of documents in the bundle.
  final int totalDocuments;

  /// The total byte size of the bundle.
  final int totalBytes;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createTime': {
        'seconds': createTime.seconds.toString(),
        'nanos': createTime.nanoseconds,
      },
      'version': version,
      'totalDocuments': totalDocuments,
      'totalBytes': totalBytes.toString(),
    };
  }
}

/// Metadata for a document in a bundle.
@immutable
class BundledDocumentMetadata {
  const BundledDocumentMetadata({
    required this.name,
    required this.readTime,
    required this.exists,
    this.queries = const [],
  });

  /// The document resource name.
  final String name;

  /// The snapshot version of the document.
  final Timestamp readTime;

  /// Whether the document exists.
  final bool exists;

  /// The names of the queries in this bundle that this document matches to.
  final List<String> queries;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'readTime': {
        'seconds': readTime.seconds.toString(),
        'nanos': readTime.nanoseconds,
      },
      'exists': exists,
      if (queries.isNotEmpty) 'queries': queries,
    };
  }
}

/// A query saved in a bundle.
@immutable
class BundledQuery {
  const BundledQuery({
    required this.parent,
    required this.structuredQuery,
    required this.limitType,
  });

  /// The parent resource name.
  final String parent;

  /// The structured query.
  final firestore_v1.StructuredQuery structuredQuery;

  /// The limit type of the query.
  final LimitType limitType;

  Map<String, dynamic> toJson() {
    // Convert structuredQuery to JSON
    final queryJson = _structuredQueryToJson(structuredQuery);

    return {
      'parent': parent,
      'structuredQuery': queryJson,
      'limitType': limitType.toJson(),
    };
  }

  /// Converts a StructuredQuery to JSON.
  /// This is a simplified version that handles the main query fields.
  static Map<String, dynamic> _structuredQueryToJson(
    firestore_v1.StructuredQuery query,
  ) {
    final json = <String, dynamic>{};

    if (query.select != null) {
      json['select'] = {
        'fields': query.select!.fields
            .map((f) => {'fieldPath': f.fieldPath})
            .toList(),
      };
    }

    if (query.from.isNotEmpty) {
      json['from'] = query.from
          .map(
            (f) => {
              'collectionId': f.collectionId,
              if (f.allDescendants) 'allDescendants': true,
            },
          )
          .toList();
    }

    if (query.where != null) {
      json['where'] = _filterToJson(query.where!);
    }

    if (query.orderBy.isNotEmpty) {
      json['orderBy'] = query.orderBy
          .map(
            (o) => {
              'field': {'fieldPath': o.field?.fieldPath},
              'direction': o.direction,
            },
          )
          .toList();
    }

    if (query.startAt != null) {
      json['startAt'] = {
        'values': query.startAt!.values.map(_valueToJson).toList(),
        if (query.startAt!.before) 'before': true,
      };
    }

    if (query.endAt != null) {
      json['endAt'] = {
        'values': query.endAt!.values.map(_valueToJson).toList(),
        if (query.endAt!.before) 'before': true,
      };
    }

    if (query.limit != null) {
      json['limit'] = query.limit;
    }

    if (query.offset != 0) {
      json['offset'] = query.offset;
    }

    return json;
  }

  /// Converts a Filter to JSON.
  static Map<String, dynamic> _filterToJson(
    firestore_v1.StructuredQuery_Filter filter,
  ) {
    if (filter.compositeFilter != null) {
      final composite = filter.compositeFilter!;
      return {
        'compositeFilter': {
          'op': composite.op,
          'filters': composite.filters.map(_filterToJson).toList(),
        },
      };
    }

    if (filter.fieldFilter != null) {
      final field = filter.fieldFilter!;
      return {
        'fieldFilter': {
          'field': {'fieldPath': field.field?.fieldPath},
          'op': field.op,
          'value': _valueToJson(field.value!),
        },
      };
    }

    if (filter.unaryFilter != null) {
      final unary = filter.unaryFilter!;
      return {
        'unaryFilter': {
          'op': unary.op,
          'field': {'fieldPath': unary.field?.fieldPath},
        },
      };
    }

    return {};
  }

  /// Converts a Value to JSON.
  static Map<String, dynamic> _valueToJson(firestore_v1.Value value) {
    if (value.nullValue != null) {
      return {'nullValue': value.nullValue};
    }
    if (value.booleanValue != null) {
      return {'booleanValue': value.booleanValue};
    }
    if (value.integerValue != null) {
      return {'integerValue': value.integerValue.toString()};
    }
    if (value.doubleValue != null) {
      return {'doubleValue': value.doubleValue};
    }
    if (value.timestampValue != null) {
      return {
        'timestampValue': _toGoogleDateTime(
          seconds: value.timestampValue!.seconds,
          nanoseconds: value.timestampValue!.nanos,
        ),
      };
    }
    if (value.stringValue != null) {
      return {'stringValue': value.stringValue};
    }
    if (value.bytesValue != null) {
      return {'bytesValue': base64Encode(value.bytesValue!)};
    }
    if (value.referenceValue != null) {
      return {'referenceValue': value.referenceValue};
    }
    if (value.geoPointValue != null) {
      final geo = value.geoPointValue!;
      return {
        'geoPointValue': {'latitude': geo.latitude, 'longitude': geo.longitude},
      };
    }
    if (value.arrayValue != null) {
      final array = value.arrayValue!;
      return {
        'arrayValue': {'values': array.values.map(_valueToJson).toList()},
      };
    }
    if (value.mapValue != null) {
      final map = value.mapValue!;
      return {
        'mapValue': {
          'fields': map.fields.map(
            (key, value) => MapEntry(key, _valueToJson(value)),
          ),
        },
      };
    }
    return {};
  }
}

/// A named query saved in a bundle.
@immutable
class NamedQuery {
  const NamedQuery({
    required this.name,
    required this.bundledQuery,
    required this.readTime,
  });

  /// The query name.
  final String name;

  /// The bundled query definition.
  final BundledQuery bundledQuery;

  /// The read time of the query results.
  final Timestamp readTime;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'bundledQuery': bundledQuery.toJson(),
      'readTime': {
        'seconds': readTime.seconds.toString(),
        'nanos': readTime.nanoseconds,
      },
    };
  }
}

/// An element in a Firestore bundle.
@immutable
class BundleElement {
  const BundleElement._({
    this.metadata,
    this.namedQuery,
    this.documentMetadata,
    this.document,
  }) : assert(
         (metadata != null ? 1 : 0) +
                 (namedQuery != null ? 1 : 0) +
                 (documentMetadata != null ? 1 : 0) +
                 (document != null ? 1 : 0) ==
             1,
         'Exactly one field must be set',
       );

  const BundleElement.metadata(BundleMetadata metadata)
    : this._(metadata: metadata);

  const BundleElement.namedQuery(NamedQuery namedQuery)
    : this._(namedQuery: namedQuery);

  const BundleElement.documentMetadata(BundledDocumentMetadata metadata)
    : this._(documentMetadata: metadata);

  const BundleElement.document(firestore_v1.Document document)
    : this._(document: document);

  final BundleMetadata? metadata;
  final NamedQuery? namedQuery;
  final BundledDocumentMetadata? documentMetadata;
  final firestore_v1.Document? document;

  Map<String, dynamic> toJson() {
    if (metadata != null) {
      return {'metadata': metadata!.toJson()};
    }
    if (namedQuery != null) {
      return {'namedQuery': namedQuery!.toJson()};
    }
    if (documentMetadata != null) {
      return {'documentMetadata': documentMetadata!.toJson()};
    }
    if (document != null) {
      return {'document': _documentToJson(document!)};
    }
    throw StateError('BundleElement has no content');
  }

  /// Converts a Document to JSON.
  static Map<String, dynamic> _documentToJson(firestore_v1.Document doc) {
    return {
      'name': doc.name,
      'fields': doc.fields.map(
        (key, value) => MapEntry(key, BundledQuery._valueToJson(value)),
      ),
      if (doc.createTime != null)
        'createTime': _toGoogleDateTime(
          seconds: doc.createTime!.seconds,
          nanoseconds: doc.createTime!.nanos,
        ),
      if (doc.updateTime != null)
        'updateTime': _toGoogleDateTime(
          seconds: doc.updateTime!.seconds,
          nanoseconds: doc.updateTime!.nanos,
        ),
    };
  }
}

/// Internal class to hold document and its metadata for bundling.
class _BundledDocument {
  _BundledDocument({required this.metadata, this.document});

  BundledDocumentMetadata metadata;
  final firestore_v1.Document? document;
}

/// Builds a Firestore data bundle with results from the given document and
/// query snapshots.
///
/// Example:
/// ```dart
/// final bundle = firestore.bundle('data-bundle');
/// final docSnapshot = await firestore.doc('abc/123').get();
/// final querySnapshot = await firestore.collection('coll').get();
///
/// bundle
///   ..addDocument(docSnapshot)  // Add a document
///   ..addQuery('coll-query', querySnapshot);  // Add a named query
///
/// final bundleBuffer = bundle.build();
/// // Save `bundleBuffer` to CDN or stream it to clients.
/// ```
class BundleBuilder {
  /// Creates a BundleBuilder with the given bundle ID.
  BundleBuilder(this.bundleId) {
    if (bundleId.isEmpty) {
      throw ArgumentError('bundleId must not be empty');
    }
  }

  /// The ID of this bundle.
  final String bundleId;

  // Resulting documents for the bundle, keyed by full document path.
  final Map<String, _BundledDocument> _documents = {};

  // Named queries saved in the bundle, keyed by query name.
  final Map<String, NamedQuery> _namedQueries = {};

  // The latest read time among all bundled documents and queries.
  Timestamp _latestReadTime = Timestamp(seconds: 0, nanoseconds: 0);

  /// Adds a Firestore [DocumentSnapshot] to the bundle.
  ///
  /// Both the document's data and read time will be included in the bundle.
  void addDocument(DocumentSnapshot<Object?> documentSnapshot) {
    _addBundledDocument(documentSnapshot);
  }

  /// Adds a Firestore query snapshot to the bundle with the given [queryName].
  ///
  /// All documents in the query snapshot and the query's read time will be
  /// included in the bundle.
  ///
  /// Throws [ArgumentError] if a query with the same name was already added.
  void addQuery(String queryName, QuerySnapshot<Object?> querySnapshot) {
    if (queryName.isEmpty) {
      throw ArgumentError('queryName must not be empty');
    }

    if (_namedQueries.containsKey(queryName)) {
      throw ArgumentError(
        'Query name conflict: $queryName has already been added.',
      );
    }

    final query = querySnapshot.query;
    final structuredQuery = query._toStructuredQuery();

    // Determine limit type based on query options
    final limitType = query._queryOptions.limitType == LimitType.last
        ? LimitType.last
        : LimitType.first;

    final bundledQuery = BundledQuery(
      parent: query._queryOptions.parentPath.toString(),
      structuredQuery: structuredQuery,
      limitType: limitType,
    );

    final namedQuery = NamedQuery(
      name: queryName,
      bundledQuery: bundledQuery,
      readTime: querySnapshot.readTime ?? Timestamp(seconds: 0, nanoseconds: 0),
    );

    _namedQueries[queryName] = namedQuery;

    // Add all documents from the query snapshot
    for (final docSnapshot in querySnapshot.docs) {
      _addBundledDocument(docSnapshot, queryName: queryName);
    }

    final readTime = querySnapshot.readTime;
    if (readTime != null && _compareTimestamps(readTime, _latestReadTime) > 0) {
      _latestReadTime = readTime;
    }
  }

  void _addBundledDocument(
    DocumentSnapshot<Object?> snapshot, {
    String? queryName,
  }) {
    final path = snapshot.ref.path;
    final existingDoc = _documents[path];
    final existingQueries = existingDoc?.metadata.queries ?? <String>[];

    // Update with document built from `snapshot` if it's newer
    final snapshotReadTime =
        snapshot.readTime ?? Timestamp(seconds: 0, nanoseconds: 0);

    if (existingDoc == null ||
        (_compareTimestamps(existingDoc.metadata.readTime, snapshotReadTime) <
            0)) {
      // Create document proto from snapshot
      final docProto = snapshot.exists
          ? firestore_v1.Document(
              name: snapshot.ref._formattedName,
              fields: snapshot._fieldsProto?.fields ?? const {},
              createTime: snapshot.createTime?._toProto().timestampValue,
              updateTime: snapshot.updateTime?._toProto().timestampValue,
            )
          : null;

      _documents[path] = _BundledDocument(
        metadata: BundledDocumentMetadata(
          name: snapshot.ref._formattedName,
          readTime: snapshotReadTime,
          exists: snapshot.exists,
        ),
        document: docProto,
      );
    }

    // Update queries list to include both original and new query name
    final doc = _documents[path]!;
    doc.metadata = BundledDocumentMetadata(
      name: doc.metadata.name,
      readTime: doc.metadata.readTime,
      exists: doc.metadata.exists,
      queries: [...existingQueries, ?queryName],
    );

    if (_compareTimestamps(snapshotReadTime, _latestReadTime) > 0) {
      _latestReadTime = snapshotReadTime;
    }
  }

  /// Builds the bundle.
  ///
  /// Returns the bundle content as a [Uint8List].
  Uint8List build() {
    final bufferParts = <Uint8List>[];

    // Add named queries
    for (final namedQuery in _namedQueries.values) {
      bufferParts.add(
        _elementToLengthPrefixedBuffer(BundleElement.namedQuery(namedQuery)),
      );
    }

    // Add documents
    for (final bundledDoc in _documents.values) {
      // Add document metadata
      bufferParts.add(
        _elementToLengthPrefixedBuffer(
          BundleElement.documentMetadata(bundledDoc.metadata),
        ),
      );

      // Add document if it exists
      if (bundledDoc.document != null) {
        bufferParts.add(
          _elementToLengthPrefixedBuffer(
            BundleElement.document(bundledDoc.document!),
          ),
        );
      }
    }

    // Calculate total bytes (sum of all buffer parts)
    var totalBytes = 0;
    for (final part in bufferParts) {
      totalBytes += part.length;
    }

    // Create bundle metadata
    final metadata = BundleMetadata(
      id: bundleId,
      createTime: _latestReadTime,
      version: _bundleVersion,
      totalDocuments: _documents.length,
      totalBytes: totalBytes,
    );

    // Prepend metadata to bundle
    final metadataBuffer = _elementToLengthPrefixedBuffer(
      BundleElement.metadata(metadata),
    );

    // Combine all parts: metadata + queries + documents
    final result = Uint8List(metadataBuffer.length + totalBytes);
    var offset = 0;

    // Copy metadata
    result.setRange(offset, offset + metadataBuffer.length, metadataBuffer);
    offset += metadataBuffer.length;

    // Copy all other parts
    for (final part in bufferParts) {
      result.setRange(offset, offset + part.length, part);
      offset += part.length;
    }

    return result;
  }

  /// Converts a [BundleElement] to a length-prefixed buffer.
  ///
  /// The format is: `[length][json_content]`
  /// where `length` is the byte length of the JSON string.
  Uint8List _elementToLengthPrefixedBuffer(BundleElement element) {
    final json = jsonEncode(element.toJson());
    final jsonBytes = utf8.encode(json);
    final lengthStr = jsonBytes.length.toString();
    final lengthBytes = utf8.encode(lengthStr);

    final result = Uint8List(lengthBytes.length + jsonBytes.length);
    result.setRange(0, lengthBytes.length, lengthBytes);
    result.setRange(lengthBytes.length, result.length, jsonBytes);

    return result;
  }
}
