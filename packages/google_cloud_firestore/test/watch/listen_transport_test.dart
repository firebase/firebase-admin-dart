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

import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:google_cloud_firestore/src/generated/google/firestore/v1/bloom_filter.pb.dart'
    as pb;
import 'package:google_cloud_firestore/src/generated/google/firestore/v1/document.pb.dart'
    as pb;
import 'package:google_cloud_firestore/src/generated/google/firestore/v1/firestore.pb.dart'
    as pb;
import 'package:google_cloud_firestore/src/generated/google/firestore/v1/write.pb.dart'
    as pb;
import 'package:google_cloud_firestore/src/generated/google/rpc/status.pb.dart'
    as pb;
import 'package:google_cloud_firestore/src/generated/google/type/latlng.pb.dart'
    as pb;
import 'package:google_cloud_firestore/src/watch/listen_transport.dart';
import 'package:google_cloud_firestore_v1/firestore.dart' as firestore_v1;
import 'package:google_cloud_protobuf/protobuf.dart' as protobuf_v1;
import 'package:google_cloud_type/type.dart' as type_v1;
import 'package:grpc/grpc.dart' as grpc;
import 'package:protobuf/well_known_types/google/protobuf/any.pb.dart'
    as pb_wkt;
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart'
    as pb_wkt;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as pb_wkt;
import 'package:test/test.dart';

const _database = 'projects/test-project/databases/(default)';
const _documents = '$_database/documents';

/// Every `Value` kind a listen target or document can carry.
Map<String, firestore_v1.Value> get _allValues => {
  'null': firestore_v1.Value(nullValue: protobuf_v1.NullValue.nullValue),
  'bool': firestore_v1.Value(booleanValue: true),
  'int': firestore_v1.Value(integerValue: 9007199254740993),
  'double': firestore_v1.Value(doubleValue: 1.5),
  'nan': firestore_v1.Value(doubleValue: double.nan),
  'infinity': firestore_v1.Value(doubleValue: double.negativeInfinity),
  'timestamp': firestore_v1.Value(
    timestampValue: protobuf_v1.Timestamp(seconds: 1700000000, nanos: 123000),
  ),
  'string': firestore_v1.Value(stringValue: 'héllo'),
  'bytes': firestore_v1.Value(bytesValue: Uint8List.fromList([0, 1, 254])),
  'reference': firestore_v1.Value(referenceValue: '$_documents/col/doc'),
  'geo': firestore_v1.Value(
    geoPointValue: type_v1.LatLng(latitude: 1.25, longitude: -2.5),
  ),
  'array': firestore_v1.Value(
    arrayValue: firestore_v1.ArrayValue(
      values: [
        firestore_v1.Value(integerValue: 1),
        firestore_v1.Value(stringValue: 'two'),
      ],
    ),
  ),
  'map': firestore_v1.Value(
    mapValue: firestore_v1.MapValue(
      fields: {'nested': firestore_v1.Value(booleanValue: false)},
    ),
  ),
};

/// Round-trips [request] through its protobuf form and back.
firestore_v1.ListenRequest _roundTrip(firestore_v1.ListenRequest request) {
  final proto = listenRequestToProto(request);
  // Through the wire format, as the transport sends it.
  final decoded = pb.ListenRequest.fromBuffer(proto.writeToBuffer());
  return firestore_v1.ListenRequest.fromJson(
    jsonDecode(jsonEncode(decoded.toProto3Json())),
  );
}

/// Decodes [response] from the wire format, as the transport receives it.
firestore_v1.ListenResponse _receive(pb.ListenResponse response) =>
    listenResponseFromProto(
      pb.ListenResponse.fromBuffer(response.writeToBuffer()),
    );

void main() {
  group('listenRequestToProto', () {
    test('converts a documents target with a resume token', () {
      final resumeToken = Uint8List.fromList([0, 1, 2, 127, 128, 255]);
      final request = firestore_v1.ListenRequest(
        database: _database,
        addTarget: firestore_v1.Target(
          documents: firestore_v1.Target_DocumentsTarget(
            documents: ['$_documents/col/a', '$_documents/col/b'],
          ),
          resumeToken: resumeToken,
          targetId: 42,
          once: true,
        ),
        labels: {'goog-listen-tags': 'existence-filter'},
      );

      final proto = listenRequestToProto(request);

      expect(proto.database, _database);
      expect(proto.addTarget.targetId, 42);
      expect(proto.addTarget.once, isTrue);
      expect(proto.addTarget.resumeToken, resumeToken);
      expect(proto.addTarget.documents.documents, [
        '$_documents/col/a',
        '$_documents/col/b',
      ]);
      expect(proto.labels, {'goog-listen-tags': 'existence-filter'});
      expect(_roundTrip(request).toJson(), request.toJson());
    });

    test('converts a query target with a read time and every value kind', () {
      final values = _allValues;
      final request = firestore_v1.ListenRequest(
        database: _database,
        addTarget: firestore_v1.Target(
          query: firestore_v1.Target_QueryTarget(
            parent: '$_documents/rooms/a',
            structuredQuery: firestore_v1.StructuredQuery(
              from: [
                firestore_v1.StructuredQuery_CollectionSelector(
                  collectionId: 'messages',
                  allDescendants: true,
                ),
              ],
              where: firestore_v1.StructuredQuery_Filter(
                compositeFilter: firestore_v1.StructuredQuery_CompositeFilter(
                  op: firestore_v1.StructuredQuery_CompositeFilter_Operator.and,
                  filters: [
                    for (final MapEntry(:key, :value) in values.entries)
                      firestore_v1.StructuredQuery_Filter(
                        fieldFilter: firestore_v1.StructuredQuery_FieldFilter(
                          field: firestore_v1.StructuredQuery_FieldReference(
                            fieldPath: key,
                          ),
                          op: firestore_v1
                              .StructuredQuery_FieldFilter_Operator
                              .equal,
                          value: value,
                        ),
                      ),
                  ],
                ),
              ),
              orderBy: [
                firestore_v1.StructuredQuery_Order(
                  field: firestore_v1.StructuredQuery_FieldReference(
                    fieldPath: '__name__',
                  ),
                  direction: firestore_v1.StructuredQuery_Direction.descending,
                ),
              ],
              startAt: firestore_v1.Cursor(
                values: [values['reference']!],
                before: true,
              ),
              limit: protobuf_v1.Int32Value(value: 10),
            ),
          ),
          readTime: protobuf_v1.Timestamp(seconds: 1700000000, nanos: 5),
          targetId: 7,
          expectedCount: protobuf_v1.Int32Value(value: 3),
        ),
      );

      final proto = listenRequestToProto(request);

      final query = proto.addTarget.query;
      expect(query.parent, '$_documents/rooms/a');
      expect(query.structuredQuery.from.single.collectionId, 'messages');
      expect(query.structuredQuery.limit.value, 10);
      final filters = query.structuredQuery.where.compositeFilter.filters;
      expect(filters, hasLength(values.length));
      expect(
        filters
            .firstWhere((f) => f.fieldFilter.field_1.fieldPath == 'int')
            .fieldFilter
            .value
            .integerValue,
        Int64.parseInt('9007199254740993'),
      );
      expect(
        filters
            .firstWhere((f) => f.fieldFilter.field_1.fieldPath == 'null')
            .fieldFilter
            .value
            .hasNullValue(),
        isTrue,
      );
      expect(
        query.structuredQuery.startAt.values.single.referenceValue,
        '$_documents/col/doc',
      );
      expect(proto.addTarget.readTime.seconds, Int64(1700000000));
      expect(proto.addTarget.readTime.nanos, 5);
      expect(proto.addTarget.expectedCount.value, 3);
      expect(_roundTrip(request).toJson(), request.toJson());
    });

    test('keeps empty bytes and negative zero in a cursor', () {
      final request = firestore_v1.ListenRequest(
        database: _database,
        addTarget: firestore_v1.Target(
          query: firestore_v1.Target_QueryTarget(
            parent: _documents,
            structuredQuery: firestore_v1.StructuredQuery(
              startAt: firestore_v1.Cursor(
                values: [
                  firestore_v1.Value(bytesValue: Uint8List(0)),
                  firestore_v1.Value(doubleValue: -0.0),
                ],
              ),
            ),
          ),
        ),
      );

      final values = listenRequestToProto(
        request,
      ).addTarget.query.structuredQuery.startAt.values;

      expect(values[0].whichValueType(), pb.Value_ValueType.bytesValue);
      expect(values[0].bytesValue, isEmpty);
      expect(values[1].doubleValue.isNegative, isTrue);
    });

    test('converts a remove target request', () {
      final request = firestore_v1.ListenRequest(
        database: _database,
        removeTarget: 7,
      );

      final proto = listenRequestToProto(request);

      expect(
        proto.whichTargetChange(),
        pb.ListenRequest_TargetChange.removeTarget,
      );
      expect(proto.removeTarget, 7);
      expect(_roundTrip(request).toJson(), request.toJson());
    });
  });

  group('listenResponseFromProto', () {
    test('converts a REMOVE target change with a cause', () {
      final response = _receive(
        pb.ListenResponse(
          targetChange: pb.TargetChange(
            targetChangeType: pb.TargetChange_TargetChangeType.REMOVE,
            targetIds: [1, 2],
            cause: pb.Status(
              code: 7,
              message: 'Missing or insufficient permissions.',
            ),
          ),
        ),
      );

      final change = response.targetChange!;
      expect(
        change.targetChangeType,
        firestore_v1.TargetChange_TargetChangeType.remove,
      );
      expect(change.targetIds, [1, 2]);
      expect(change.cause!.code, StatusCode.permissionDenied.value);
      expect(change.cause!.message, 'Missing or insufficient permissions.');
    });

    test('drops cause details, keeping the code and message', () {
      final response = _receive(
        pb.ListenResponse(
          targetChange: pb.TargetChange(
            targetChangeType: pb.TargetChange_TargetChangeType.REMOVE,
            targetIds: [1],
            cause: pb.Status(
              code: 7,
              message: 'denied',
              details: [
                pb_wkt.Any(
                  typeUrl: 'type.googleapis.com/google.rpc.ErrorInfo',
                  value: [10, 3, 102, 111, 111],
                ),
              ],
            ),
          ),
        ),
      );

      final cause = response.targetChange!.cause!;
      expect(cause.code, 7);
      expect(cause.message, 'denied');
      expect(cause.details, isEmpty);
    });

    test(
      'converts a CURRENT target change with a resume token and read time',
      () {
        final resumeToken = [0, 1, 2, 250, 255];
        final response = _receive(
          pb.ListenResponse(
            targetChange: pb.TargetChange(
              targetChangeType: pb.TargetChange_TargetChangeType.CURRENT,
              resumeToken: resumeToken,
              readTime: pb_wkt.Timestamp(seconds: Int64(1700000000), nanos: 42),
            ),
          ),
        );

        final change = response.targetChange!;
        expect(
          change.targetChangeType,
          firestore_v1.TargetChange_TargetChangeType.current,
        );
        expect(change.targetIds, isEmpty);
        expect(change.resumeToken, resumeToken);
        expect(change.readTime!.seconds, 1700000000);
        expect(change.readTime!.nanos, 42);
      },
    );

    test('converts a NO_CHANGE target change, the proto3 default', () {
      final response = _receive(
        pb.ListenResponse(targetChange: pb.TargetChange(resumeToken: [9])),
      );

      expect(
        response.targetChange!.targetChangeType,
        firestore_v1.TargetChange_TargetChangeType.noChange,
      );
      expect(response.targetChange!.resumeToken, [9]);
    });

    test('converts a document change with every value kind', () {
      final response = _receive(
        pb.ListenResponse(
          documentChange: pb.DocumentChange(
            document: pb.Document(
              name: '$_documents/col/doc',
              fields: {
                'null': pb.Value(nullValue: pb_wkt.NullValue.NULL_VALUE),
                'bool': pb.Value(booleanValue: true),
                'int': pb.Value(
                  integerValue: Int64.parseInt('9007199254740993'),
                ),
                'double': pb.Value(doubleValue: 1.5),
                'nan': pb.Value(doubleValue: double.nan),
                'timestamp': pb.Value(
                  timestampValue: pb_wkt.Timestamp(
                    seconds: Int64(1700000000),
                    nanos: 123000,
                  ),
                ),
                'string': pb.Value(stringValue: 'héllo'),
                'bytes': pb.Value(bytesValue: [0, 1, 254]),
                'reference': pb.Value(referenceValue: '$_documents/col/other'),
                'geo': pb.Value(
                  geoPointValue: pb.LatLng(latitude: 1.25, longitude: -2.5),
                ),
                'array': pb.Value(
                  arrayValue: pb.ArrayValue(
                    values: [pb.Value(integerValue: Int64(1))],
                  ),
                ),
                'map': pb.Value(
                  mapValue: pb.MapValue(
                    fields: {'nested': pb.Value(booleanValue: false)}.entries,
                  ),
                ),
              }.entries,
              createTime: pb_wkt.Timestamp(seconds: Int64(1), nanos: 2),
              updateTime: pb_wkt.Timestamp(seconds: Int64(3), nanos: 4),
            ),
            targetIds: [1],
            removedTargetIds: [2],
          ),
        ),
      );

      final change = response.documentChange!;
      expect(change.targetIds, [1]);
      expect(change.removedTargetIds, [2]);
      final document = change.document!;
      expect(document.name, '$_documents/col/doc');
      expect(document.createTime!.seconds, 1);
      expect(document.updateTime!.nanos, 4);
      final fields = document.fields;
      expect(fields['null']!.nullValue, protobuf_v1.NullValue.nullValue);
      expect(fields['bool']!.booleanValue, isTrue);
      expect(fields['int']!.integerValue, 9007199254740993);
      expect(fields['double']!.doubleValue, 1.5);
      expect(fields['nan']!.doubleValue, isNaN);
      expect(fields['timestamp']!.timestampValue!.seconds, 1700000000);
      expect(fields['timestamp']!.timestampValue!.nanos, 123000);
      expect(fields['string']!.stringValue, 'héllo');
      expect(fields['bytes']!.bytesValue, [0, 1, 254]);
      expect(fields['reference']!.referenceValue, '$_documents/col/other');
      expect(fields['geo']!.geoPointValue!.latitude, 1.25);
      expect(fields['geo']!.geoPointValue!.longitude, -2.5);
      expect(fields['array']!.arrayValue!.values.single.integerValue, 1);
      expect(fields['map']!.mapValue!.fields['nested']!.booleanValue, isFalse);
    });

    test('converts a document delete', () {
      final response = _receive(
        pb.ListenResponse(
          documentDelete: pb.DocumentDelete(
            document: '$_documents/col/doc',
            removedTargetIds: [3],
            readTime: pb_wkt.Timestamp(seconds: Int64(5)),
          ),
        ),
      );

      final delete = response.documentDelete!;
      expect(delete.document, '$_documents/col/doc');
      expect(delete.removedTargetIds, [3]);
      expect(delete.readTime!.seconds, 5);
    });

    test('converts a document remove', () {
      final response = _receive(
        pb.ListenResponse(
          documentRemove: pb.DocumentRemove(
            document: '$_documents/col/doc',
            removedTargetIds: [4],
          ),
        ),
      );

      expect(response.documentRemove!.document, '$_documents/col/doc');
      expect(response.documentRemove!.removedTargetIds, [4]);
    });

    test('keeps empty bytes and negative zero, at any depth', () {
      pb.Value edgeCases() => pb.Value(
        mapValue: pb.MapValue(
          fields: {
            'bytes': pb.Value(bytesValue: []),
            'zero': pb.Value(doubleValue: -0.0),
          }.entries,
        ),
      );
      final response = _receive(
        pb.ListenResponse(
          documentChange: pb.DocumentChange(
            document: pb.Document(
              name: '$_documents/col/doc',
              fields: {
                'bytes': pb.Value(bytesValue: []),
                'zero': pb.Value(doubleValue: -0.0),
                'map': edgeCases(),
                'array': pb.Value(
                  arrayValue: pb.ArrayValue(
                    values: [
                      pb.Value(stringValue: 'x'),
                      edgeCases(),
                    ],
                  ),
                ),
              }.entries,
            ),
          ),
        ),
      );

      void expectEdgeCases(Map<String, firestore_v1.Value> fields) {
        expect(fields['bytes']!.bytesValue, isEmpty);
        expect(fields['zero']!.doubleValue, isZero);
        expect(fields['zero']!.doubleValue!.isNegative, isTrue);
      }

      final fields = response.documentChange!.document!.fields;
      expectEdgeCases(fields);
      expectEdgeCases(fields['map']!.mapValue!.fields);
      expectEdgeCases(fields['array']!.arrayValue!.values[1].mapValue!.fields);
    });

    test('converts timestamps before 1970', () {
      final response = _receive(
        pb.ListenResponse(
          documentChange: pb.DocumentChange(
            document: pb.Document(
              name: '$_documents/col/doc',
              fields: {
                'whole': pb.Value(
                  timestampValue: pb_wkt.Timestamp(seconds: Int64(-86400)),
                ),
                'fractional': pb.Value(
                  timestampValue: pb_wkt.Timestamp(
                    seconds: Int64(-1),
                    nanos: 500000000,
                  ),
                ),
              }.entries,
            ),
          ),
        ),
      );

      final fields = response.documentChange!.document!.fields;
      expect(fields['whole']!.timestampValue!.seconds, -86400);
      // Asserts current behaviour, which is wrong: 1969-12-31T23:59:59.5Z
      // should be (-1 s, 0.5e9 ns). google_cloud_protobuf's
      // `Timestamp.fromJson` truncates fractional pre-1970 times towards
      // zero, so they come back one second late. Fix that upstream.
      final fractional = fields['fractional']!.timestampValue!;
      expect((fractional.seconds, fractional.nanos), (0, 500000000));
    });

    test('converts an existence filter with a bloom filter', () {
      final response = _receive(
        pb.ListenResponse(
          filter: pb.ExistenceFilter(
            targetId: 5,
            count: 12,
            unchangedNames: pb.BloomFilter(
              bits: pb.BitSequence(bitmap: [0xff, 0x00, 0x81], padding: 3),
              hashCount: 7,
            ),
          ),
        ),
      );

      final filter = response.filter!;
      expect(filter.targetId, 5);
      expect(filter.count, 12);
      expect(filter.unchangedNames!.hashCount, 7);
      expect(filter.unchangedNames!.bits!.bitmap, [0xff, 0x00, 0x81]);
      expect(filter.unchangedNames!.bits!.padding, 3);
    });
  });

  group('firestoreExceptionFromGrpcError', () {
    test('keeps every gRPC status code', () {
      for (final code in StatusCode.values) {
        final exception = firestoreExceptionFromGrpcError(
          grpc.GrpcError.custom(code.value, 'boom'),
        );

        expect(exception.errorCode.statusCode, code);
        // As for REST errors, UNKNOWN also carries the raw status.
        expect(
          exception.message,
          code == StatusCode.unknown ? startsWith('boom Raw') : 'boom',
        );
      }
    });

    test('uses the default message when the status has none', () {
      final exception = firestoreExceptionFromGrpcError(
        const grpc.GrpcError.unavailable(),
      );

      expect(exception.errorCode, FirestoreClientErrorCode.unavailable);
      expect(exception.message, FirestoreClientErrorCode.unavailable.message);
    });

    test('maps an unrecognised code to unknown with the raw status', () {
      final exception = firestoreExceptionFromGrpcError(
        const grpc.GrpcError.custom(99, 'odd', null, null, {
          'x-debug': 'trace-1',
        }),
      );

      expect(exception.errorCode, FirestoreClientErrorCode.unknown);
      expect(exception.message, contains('odd'));
      expect(exception.message, contains('99'));
      expect(exception.message, contains('trace-1'));
    });
  });

  group('ListenEndpoint.fromSettings', () {
    ListenEndpoint resolve({
      String? host,
      bool ssl = true,
      Map<String, String> environment = const {},
    }) => ListenEndpoint.fromSettings(
      Settings(host: host, ssl: ssl, environmentOverride: environment),
    );

    test('defaults to production over TLS', () {
      expect(
        resolve(),
        const ListenEndpoint(
          host: 'firestore.googleapis.com',
          port: 443,
          secure: true,
          isEmulator: false,
        ),
      );
    });

    test('uses FIRESTORE_EMULATOR_HOST over plaintext', () {
      expect(
        resolve(environment: {'FIRESTORE_EMULATOR_HOST': '127.0.0.1:8080'}),
        const ListenEndpoint(
          host: '127.0.0.1',
          port: 8080,
          secure: false,
          isEmulator: true,
        ),
      );
    });

    test('prefers FIRESTORE_EMULATOR_HOST over a custom host', () {
      final endpoint = resolve(
        host: 'example.test',
        environment: {'FIRESTORE_EMULATOR_HOST': 'localhost:9090'},
      );

      expect(endpoint.host, 'localhost');
      expect(endpoint.port, 9090);
      expect(endpoint.isEmulator, isTrue);
    });

    test('parses an IPv6 emulator host', () {
      final endpoint = resolve(
        environment: {'FIRESTORE_EMULATOR_HOST': '[::1]:8080'},
      );

      expect(endpoint.host, '::1');
      expect(endpoint.port, 8080);
    });

    test('follows ssl for a custom host', () {
      expect(
        resolve(host: 'example.test'),
        const ListenEndpoint(
          host: 'example.test',
          port: 443,
          secure: true,
          isEmulator: false,
        ),
      );
      expect(
        resolve(host: 'example.test:8080', ssl: false),
        const ListenEndpoint(
          host: 'example.test',
          port: 8080,
          secure: false,
          isEmulator: false,
        ),
      );
    });
  });

  group('listenMetadata', () {
    test('sets auth and routing for the database', () {
      expect(
        listenMetadata(database: _database, accessToken: emulatorAccessToken),
        {
          'authorization': 'Bearer owner',
          'google-cloud-resource-prefix': _database,
          'x-goog-request-params': 'database=$_database',
        },
      );
    });

    test('leaves authorization to the per-call auth without a token', () {
      final metadata = listenMetadata(
        database: _database,
        headers: {'Authorization': 'x'},
      );

      expect(metadata.containsKey('authorization'), isFalse);
      expect(metadata['google-cloud-resource-prefix'], _database);
    });

    test('adds custom headers lower-cased without overriding auth', () {
      final metadata = listenMetadata(
        database: _database,
        accessToken: 'token',
        headers: {'X-Goog-Api-Client': 'fire-admin/1.0', 'Authorization': 'x'},
      );

      expect(metadata['x-goog-api-client'], 'fire-admin/1.0');
      expect(metadata['authorization'], 'Bearer token');
    });
  });
}
