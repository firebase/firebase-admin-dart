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

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart' hide throwsArgumentError;

import 'fixtures/helpers.dart';

/// Creates a Firestore instance for unit testing without needing an emulator.
Firestore createMockFirestore() {
  late Firestore firestore;
  runZoned(() {
    firestore = Firestore(settings: const Settings(projectId: 'test-project'));
  }, zoneValues: {envSymbol: <String, String>{}});
  return firestore;
}

int _fromFirestore(QueryDocumentSnapshot<DocumentData> snapshot) {
  return snapshot.data()['value']! as int;
}

DocumentData _toFirestore(int value) => {'value': value};

const _pairMessage =
    '"fromFirestore" and "toFirestore" must be provided together. '
    'Pass both to apply a converter, or neither to reset to DocumentData.';

void main() {
  group('withConverter', () {
    late Firestore firestore;

    setUp(() {
      firestore = createMockFirestore();
    });

    group('CollectionReference', () {
      late CollectionReference<int> typed;

      setUp(() {
        typed = firestore
            .collection('items')
            .withConverter<int>(
              fromFirestore: _fromFirestore,
              toFirestore: _toFirestore,
            );
      });

      test('both functions apply the converter', () {
        expect(typed, isA<CollectionReference<int>>());
        expect(typed.path, 'items');
      });

      test('both null resets to DocumentData', () {
        final reset = typed.withConverter<DocumentData>();

        expect(reset, isA<CollectionReference<DocumentData>>());
        expect(reset.path, 'items');
      });

      test('no type argument and no functions resets to DocumentData', () {
        // ignore: inference_failure_on_function_invocation
        final reset = typed.withConverter();

        expect(reset, isA<CollectionReference<DocumentData>>());
      });

      test('only fromFirestore with a custom type throws ArgumentError', () {
        expect(
          () => typed.withConverter<int>(fromFirestore: _fromFirestore),
          throwsArgumentError(message: _pairMessage),
        );
      });

      test('only toFirestore with a custom type throws ArgumentError', () {
        expect(
          () => typed.withConverter<int>(toFirestore: _toFirestore),
          throwsArgumentError(message: _pairMessage),
        );
      });

      test('only one function with DocumentData throws ArgumentError', () {
        expect(
          () => typed.withConverter<DocumentData>(
            fromFirestore: (snapshot) => snapshot.data(),
          ),
          throwsArgumentError(message: _pairMessage),
        );
        expect(
          () =>
              typed.withConverter<DocumentData>(toFirestore: (value) => value),
          throwsArgumentError(message: _pairMessage),
        );
      });

      test(
        'both null with a type that cannot hold DocumentData throws ArgumentError',
        () {
          expect(
            () => typed.withConverter<int>(),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                contains('withConverter<int>()'),
              ),
            ),
          );
        },
      );
    });

    group('DocumentReference', () {
      late DocumentReference<int> typed;

      setUp(() {
        typed = firestore
            .collection('items')
            .doc('one')
            .withConverter<int>(
              fromFirestore: _fromFirestore,
              toFirestore: _toFirestore,
            );
      });

      test('both null resets to DocumentData', () {
        final reset = typed.withConverter<DocumentData>();

        expect(reset, isA<DocumentReference<DocumentData>>());
        expect(reset.path, 'items/one');
      });

      test('no type argument and no functions resets to DocumentData', () {
        // ignore: inference_failure_on_function_invocation
        expect(typed.withConverter(), isA<DocumentReference<DocumentData>>());
      });

      test('only one function with a custom type throws ArgumentError', () {
        expect(
          () => typed.withConverter<int>(fromFirestore: _fromFirestore),
          throwsArgumentError(message: _pairMessage),
        );
        expect(
          () => typed.withConverter<int>(toFirestore: _toFirestore),
          throwsArgumentError(message: _pairMessage),
        );
      });

      test('only one function with DocumentData throws ArgumentError', () {
        expect(
          () =>
              typed.withConverter<DocumentData>(toFirestore: (value) => value),
          throwsArgumentError(message: _pairMessage),
        );
      });

      test(
        'both null with a type that cannot hold DocumentData throws ArgumentError',
        () {
          expect(() => typed.withConverter<int>(), throwsArgumentError());
        },
      );
    });

    group('Query', () {
      late Query<int> typed;

      setUp(() {
        typed = firestore
            .collection('items')
            .where('value', WhereFilter.equal, 1)
            .withConverter<int>(
              fromFirestore: _fromFirestore,
              toFirestore: _toFirestore,
            );
      });

      test('both null resets to DocumentData', () {
        final reset = typed.withConverter<DocumentData>();

        expect(reset, isA<Query<DocumentData>>());
        expect(reset, isNot(isA<CollectionReference<Object?>>()));
      });

      test('no type argument and no functions resets to DocumentData', () {
        // ignore: inference_failure_on_function_invocation
        expect(typed.withConverter(), isA<Query<DocumentData>>());
      });

      test('only one function with a custom type throws ArgumentError', () {
        expect(
          () => typed.withConverter<int>(fromFirestore: _fromFirestore),
          throwsArgumentError(message: _pairMessage),
        );
        expect(
          () => typed.withConverter<int>(toFirestore: _toFirestore),
          throwsArgumentError(message: _pairMessage),
        );
      });

      test('only one function with DocumentData throws ArgumentError', () {
        expect(
          () => typed.withConverter<DocumentData>(
            fromFirestore: (snapshot) => snapshot.data(),
          ),
          throwsArgumentError(message: _pairMessage),
        );
      });

      test(
        'both null with a type that cannot hold DocumentData throws ArgumentError',
        () {
          expect(() => typed.withConverter<int>(), throwsArgumentError());
        },
      );
    });

    group('CollectionGroup', () {
      late CollectionGroup<int> typed;

      setUp(() {
        typed = firestore
            .collectionGroup('items')
            .withConverter<int>(
              fromFirestore: _fromFirestore,
              toFirestore: _toFirestore,
            );
      });

      test('both null resets to DocumentData', () {
        expect(
          typed.withConverter<DocumentData>(),
          isA<CollectionGroup<DocumentData>>(),
        );
      });

      test('no type argument and no functions resets to DocumentData', () {
        // ignore: inference_failure_on_function_invocation
        expect(typed.withConverter(), isA<CollectionGroup<DocumentData>>());
      });

      test('only one function with a custom type throws ArgumentError', () {
        expect(
          () => typed.withConverter<int>(fromFirestore: _fromFirestore),
          throwsArgumentError(message: _pairMessage),
        );
        expect(
          () => typed.withConverter<int>(toFirestore: _toFirestore),
          throwsArgumentError(message: _pairMessage),
        );
      });

      test('only one function with DocumentData throws ArgumentError', () {
        expect(
          () =>
              typed.withConverter<DocumentData>(toFirestore: (value) => value),
          throwsArgumentError(message: _pairMessage),
        );
      });

      test(
        'both null with a type that cannot hold DocumentData throws ArgumentError',
        () {
          expect(() => typed.withConverter<int>(), throwsArgumentError());
        },
      );
    });
  });
}
