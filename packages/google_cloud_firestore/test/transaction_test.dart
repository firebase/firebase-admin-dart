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

import 'dart:core';
import 'dart:math';

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'fixtures/helpers.dart' as helpers;

Firestore _makeFirestore() =>
    Firestore(settings: const Settings(projectId: 'unit-test-project'));

void main() {
  group('Transaction (unit)', () {
    late Firestore firestore;

    setUp(() {
      firestore = _makeFirestore();
    });

    group('constants', () {
      test('defaultMaxTransactionsAttempts is 5', () {
        expect(Transaction.defaultMaxTransactionsAttempts, 5);
      });

      test('readAfterWriteErrorMsg describes ordering constraint', () {
        expect(
          Transaction.readAfterWriteErrorMsg,
          contains('reads to be executed before all writes'),
        );
      });

      test('readOnlyWriteErrorMsg describes read-only restriction', () {
        expect(
          Transaction.readOnlyWriteErrorMsg,
          contains('read-only transactions cannot execute writes'),
        );
      });
    });

    group('read-only transaction write guard', () {
      late Transaction readOnlyTx;

      setUp(() {
        readOnlyTx = Transaction(firestore, ReadOnlyTransactionOptions());
      });

      test('create() throws on read-only transaction', () {
        final docRef = firestore.doc('col/doc');
        expect(
          () => readOnlyTx.create(docRef, {'foo': 'bar'}),
          throwsA(
            isA<FirestoreException>().having(
              (e) => e.message,
              'message',
              contains('read-only transactions cannot execute writes'),
            ),
          ),
        );
      });

      test('set() throws on read-only transaction', () {
        final docRef = firestore.doc('col/doc');
        expect(
          () => readOnlyTx.set(docRef, {'foo': 'bar'}),
          throwsA(isA<FirestoreException>()),
        );
      });

      test('update() throws on read-only transaction', () {
        final docRef = firestore.doc('col/doc');
        expect(
          () => readOnlyTx.update(docRef, {'foo': 'bar'}),
          throwsA(isA<FirestoreException>()),
        );
      });

      test('delete() throws on read-only transaction', () {
        final docRef = firestore.doc('col/doc');
        expect(
          () => readOnlyTx.delete(docRef),
          throwsA(isA<FirestoreException>()),
        );
      });
    });

    group('read-after-write guard', () {
      test('get() after write throws', () async {
        final docRef = firestore.doc('col/doc');
        final tx = Transaction(firestore, null);

        tx.create(docRef, {'foo': 'bar'});

        await expectLater(
          tx.get(docRef),
          throwsA(
            isA<FirestoreException>().having(
              (e) => e.message,
              'message',
              contains('reads to be executed before all writes'),
            ),
          ),
        );
      });

      test('getQuery() after write throws', () async {
        final docRef = firestore.doc('col/doc');
        final query = firestore.collection('col');
        final tx = Transaction(firestore, null);

        tx.create(docRef, {'foo': 'bar'});

        await expectLater(
          tx.getQuery(query),
          throwsA(isA<FirestoreException>()),
        );
      });

      test('getAll() after write throws', () async {
        final docRef = firestore.doc('col/doc');
        final tx = Transaction(firestore, null);

        tx.create(docRef, {'foo': 'bar'});

        await expectLater(
          tx.getAll([docRef]),
          throwsA(isA<FirestoreException>()),
        );
      });
    });

    group('retry logic', () {
      final nonRetryableCodes = [
        (FirestoreClientErrorCode.notFound, 'notFound'),
        (FirestoreClientErrorCode.alreadyExists, 'alreadyExists'),
        (FirestoreClientErrorCode.permissionDenied, 'permissionDenied'),
        (FirestoreClientErrorCode.failedPrecondition, 'failedPrecondition'),
        (FirestoreClientErrorCode.outOfRange, 'outOfRange'),
        (FirestoreClientErrorCode.unimplemented, 'unimplemented'),
        (FirestoreClientErrorCode.dataLoss, 'dataLoss'),
      ];

      for (final (code, name) in nonRetryableCodes) {
        test('does not retry on non-retryable code: $name', () async {
          var callCount = 0;
          await expectLater(
            firestore.runTransaction((_) async {
              callCount++;
              throw FirestoreException(code, 'non-retryable error');
            }),
            throwsA(
              isA<FirestoreException>().having(
                (e) => e.errorCode,
                'errorCode',
                code,
              ),
            ),
          );
          expect(callCount, 1);
        });
      }

      final retryableCodes = [
        (FirestoreClientErrorCode.aborted, 'aborted'),
        (FirestoreClientErrorCode.cancelled, 'cancelled'),
        (FirestoreClientErrorCode.unknown, 'unknown'),
        (FirestoreClientErrorCode.deadlineExceeded, 'deadlineExceeded'),
        (FirestoreClientErrorCode.internal, 'internal'),
        (FirestoreClientErrorCode.unavailable, 'unavailable'),
        (FirestoreClientErrorCode.unauthenticated, 'unauthenticated'),
        (FirestoreClientErrorCode.resourceExhausted, 'resourceExhausted'),
      ];

      for (final (code, name) in retryableCodes) {
        test('retries on retryable code: $name (maxAttempts=1)', () async {
          var callCount = 0;
          await expectLater(
            firestore.runTransaction((_) async {
              callCount++;
              throw FirestoreException(code, 'retryable error');
            }, transactionOptions: ReadWriteTransactionOptions(maxAttempts: 1)),
            throwsA(
              isA<FirestoreException>().having(
                (e) => e.message,
                'message',
                contains('max attempts exceeded'),
              ),
            ),
          );
          expect(callCount, 1);
        });
      }

      test(
        'INVALID_ARGUMENT with "transaction has expired" is retried',
        () async {
          var callCount = 0;
          await expectLater(
            firestore.runTransaction((_) async {
              callCount++;
              throw FirestoreException(
                FirestoreClientErrorCode.invalidArgument,
                'The transaction has expired. Please retry.',
              );
            }, transactionOptions: ReadWriteTransactionOptions(maxAttempts: 1)),
            throwsA(
              isA<FirestoreException>().having(
                (e) => e.message,
                'message',
                contains('max attempts exceeded'),
              ),
            ),
          );
          expect(callCount, 1);
        },
      );

      test('INVALID_ARGUMENT without expiry message is not retried', () async {
        var callCount = 0;
        await expectLater(
          firestore.runTransaction((_) async {
            callCount++;
            throw FirestoreException(
              FirestoreClientErrorCode.invalidArgument,
              'some other invalid argument',
            );
          }),
          throwsA(
            isA<FirestoreException>().having(
              (e) => e.errorCode,
              'errorCode',
              FirestoreClientErrorCode.invalidArgument,
            ),
          ),
        );
        expect(callCount, 1);
      });

      test('respects maxAttempts from ReadWriteTransactionOptions', () async {
        var callCount = 0;
        await expectLater(
          firestore.runTransaction((_) async {
            callCount++;
            throw FirestoreException(
              FirestoreClientErrorCode.aborted,
              'test abort',
            );
          }, transactionOptions: ReadWriteTransactionOptions(maxAttempts: 3)),
          throwsA(
            isA<FirestoreException>().having(
              (e) => e.message,
              'message',
              contains('max attempts exceeded'),
            ),
          ),
        );
        expect(callCount, 3);
      }, timeout: const Timeout(Duration(seconds: 10)));

      test('user-thrown non-FirestoreException is not retried', () async {
        var callCount = 0;
        await expectLater(
          firestore.runTransaction((_) async {
            callCount++;
            throw StateError('user error');
          }),
          throwsA(isA<StateError>()),
        );
        expect(callCount, 1);
      });
    });
  });

  group('Transaction', () {
    late Firestore firestore;

    setUp(() async {
      firestore = await helpers.createFirestore();
    });

    Future<DocumentReference<Map<String, dynamic>>> initializeTest(
      String path,
    ) async {
      final prefixedPath = 'flutter-tests/$path';
      await firestore.doc(prefixedPath).delete();
      addTearDown(() => firestore.doc(prefixedPath).delete());

      return firestore.doc(prefixedPath);
    }

    test('get a document in a transaction', () async {
      final docRef = await initializeTest('simpleDocument');

      await docRef.set({'value': 42});

      expect(
        await firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(docRef);
          return Future.value(snapshot.data()!['value']);
        }),
        42,
      );
    });

    test('getAll documents in a transaction', () async {
      final docRef1 = await initializeTest('simpleDocument');
      final docRef2 = await initializeTest('simpleDocument2');
      final docRef3 = await initializeTest('simpleDocument3');

      await docRef1.set({'value': 42});
      await docRef2.set({'value': 44});
      await docRef3.set({'value': 'foo'});

      expect(
        await firestore.runTransaction((transaction) async {
          final snapshot = await transaction.getAll([
            docRef1,
            docRef2,
            docRef3,
          ]);
          return Future.value(
            snapshot,
          ).then((v) => v.map((e) => e.data()!['value']).toList());
        }),
        [42, 44, 'foo'],
      );
    });

    test('getAll documents with FieldMask in a transaction', () async {
      final docRef1 = await initializeTest('simpleDocument');
      final docRef2 = await initializeTest('simpleDocument2');
      final docRef3 = await initializeTest('simpleDocument3');

      await docRef1.set({'value': 42, 'otherValue': 'bar'});
      await docRef2.set({'value': 44, 'otherValue': 'bar'});
      await docRef3.set({'value': 'foo', 'otherValue': 'bar'});

      expect(
        await firestore.runTransaction((transaction) async {
          final snapshot = await transaction.getAll(
            [docRef1, docRef2, docRef3],
            fieldMasks: [
              FieldPath(const ['value']),
            ],
          );
          return Future.value(
            snapshot,
          ).then((v) => v.map((e) => e.data()!).toList());
        }),
        [
          {'value': 42},
          {'value': 44},
          {'value': 'foo'},
        ],
      );
    });

    test('set a document in a transaction', () async {
      final docRef = await initializeTest('simpleDocument');

      await firestore.runTransaction((transaction) async {
        transaction.set(docRef, {'value': 44});
      });

      expect((await docRef.get()).data()!['value'], 44);
    });

    test('update a document in a transaction', () async {
      final docRef = await initializeTest('simpleDocument');

      await firestore.runTransaction((transaction) async {
        transaction.set(docRef, {'value': 44, 'foo': 'bar'});
        transaction.update(docRef, {'value': 46});
      });

      expect((await docRef.get()).data()!['value'], 46);
    });

    test('update a non existing document in a transaction', () async {
      final docRef = await initializeTest('simpleDocument');

      final nonExistingDocRef = await initializeTest('simpleDocument2');

      expect(
        () async {
          await firestore.runTransaction((transaction) async {
            transaction.set(docRef, {'value': 44, 'foo': 'bar'});
            transaction.update(nonExistingDocRef, {'value': 46});
          });
        },
        throwsA(
          isA<FirestoreException>().having(
            (e) => e.errorCode.statusCode,
            'statusCode',
            StatusCode.notFound,
          ),
        ),
      );
    });

    test('update a document with precondition in a transaction', () async {
      final docRef = await initializeTest('simpleDocument');

      final setResult = await docRef.set({'value': 42});

      final precondition = Precondition.timestamp(setResult.writeTime);

      await firestore.runTransaction((transaction) async {
        transaction.update(docRef, {'value': 44}, precondition: precondition);
      });

      expect((await docRef.get()).data()!['value'], 44);

      expect(
        () async {
          await firestore.runTransaction((transaction) async {
            transaction.update(docRef, {
              'value': 46,
            }, precondition: precondition);
          });
        },
        throwsA(
          isA<FirestoreException>().having(
            (e) => e.errorCode.statusCode,
            'statusCode',
            StatusCode.failedPrecondition,
          ),
        ),
      );
    });

    test('get and set a document in a transaction', () async {
      final docRef = await initializeTest('simpleDocument');
      await docRef.set({'value': 42});
      DocumentSnapshot<Map<String, dynamic>> getData;
      DocumentSnapshot<Map<String, dynamic>> setData;

      getData = await firestore.runTransaction((transaction) async {
        final getData0 = await transaction.get(docRef);
        transaction.set(docRef, {'value': 44});
        return getData0;
      });

      setData = await docRef.get();

      expect(getData.data()!['value'], 42);

      expect(setData.data()!['value'], 44);
    });

    test('delete a existing document in a transaction', () async {
      final docRef = await initializeTest('simpleDocument');

      await docRef.set({'value': 42});

      await firestore.runTransaction((transaction) async {
        transaction.delete(docRef);
      });

      expect(
        await docRef.get(),
        isA<DocumentSnapshot<Map<String, dynamic>>>().having(
          (e) => e.exists,
          'exists',
          false,
        ),
      );
    });

    test('delete a non existing document in a transaction', () async {
      final docRef = await initializeTest('simpleDocument');

      expect(
        await firestore.runTransaction((transaction) async {
          transaction.delete(docRef);
        }),
        null,
      );
    });

    test(
      'delete a non existing document with existing precondition in a transaction',
      () async {
        final docRef = await initializeTest('simpleDocument');
        final precondition = Precondition.exists(true);
        expect(
          () async {
            await firestore.runTransaction((transaction) async {
              transaction.delete(docRef, precondition: precondition);
            });
          },
          throwsA(
            isA<FirestoreException>().having(
              (e) => e.errorCode.statusCode,
              'statusCode',
              StatusCode.notFound,
            ),
          ),
        );
      },
    );

    test('delete a document with precondition in a transaction', () async {
      final docRef = await initializeTest('simpleDocument');

      final writeResult = await docRef.set({'value': 42});
      var precondition = Precondition.timestamp(
        Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
      );

      expect(
        () async {
          await firestore.runTransaction((transaction) async {
            transaction.delete(docRef, precondition: precondition);
          });
        },
        throwsA(
          isA<FirestoreException>().having(
            (e) => e.errorCode.statusCode,
            'statusCode',
            StatusCode.failedPrecondition,
          ),
        ),
      );

      expect(
        await docRef.get(),
        isA<DocumentSnapshot<Map<String, dynamic>>>().having(
          (e) => e.exists,
          'exists',
          true,
        ),
      );
      precondition = Precondition.timestamp(writeResult.writeTime);

      await firestore.runTransaction((transaction) async {
        transaction.delete(docRef, precondition: precondition);
      });

      expect(
        await docRef.get(),
        isA<DocumentSnapshot<Map<String, dynamic>>>().having(
          (e) => e.exists,
          'exists',
          false,
        ),
      );
    });

    test('prevent get after set in a transaction', () async {
      final docRef = await initializeTest('simpleDocument');

      expect(
        () async {
          await firestore.runTransaction((transaction) async {
            transaction.set(docRef, {'value': 42});
            return transaction.get(docRef);
          });
          fail('Transaction should not have resolved');
        },
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains(Transaction.readAfterWriteErrorMsg),
          ),
        ),
      );
    });

    test('prevent set in a readOnly transaction', () async {
      final docRef = await initializeTest('simpleDocument');

      expect(
        () async {
          await firestore.runTransaction((transaction) async {
            transaction.set(docRef, {'value': 42});
          }, transactionOptions: ReadOnlyTransactionOptions());
          fail('Transaction should not have resolved');
        },
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains(Transaction.readOnlyWriteErrorMsg),
          ),
        ),
      );
    });

    test('detects document change during transaction', () async {
      final docRef = await initializeTest('simpleDocument');

      expect(
        () async {
          await firestore.runTransaction((transaction) async {
            // ignore: unused_local_variable
            final data = await transaction.get(docRef);

            // Intentionally set doc during transaction
            await docRef.set({'value': 46});

            transaction.set(docRef, {'value': 42});
          }, transactionOptions: ReadWriteTransactionOptions(maxAttempts: 1));
          fail('Transaction should not have resolved');
        },
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Transaction max attempts exceeded'),
          ),
        ),
      );
    });

    test('runs multiple transactions in parallel', () async {
      final doc1 = await initializeTest('transaction-multi-1');
      final doc2 = await initializeTest('transaction-multi-2');

      await Future.wait([
        firestore.runTransaction((transaction) async {
          transaction.set(doc1, {'test': 'value3'});
        }),
        firestore.runTransaction((transaction) async {
          transaction.set(doc2, {'test': 'value4'});
        }),
      ]);

      final snapshot1 = await doc1.get();
      expect(snapshot1.data()!['test'], equals('value3'));
      final snapshot2 = await doc2.get();
      expect(snapshot2.data()!['test'], equals('value4'));
    });

    test(
      'should not collide transaction if number of maxAttempts is enough',
      () async {
        final doc1 = await initializeTest('transaction-maxAttempts-1');

        await doc1.set({'test': 0});

        await Future.wait([
          firestore.runTransaction((transaction) async {
            final value = await transaction.get(doc1);
            transaction.set(doc1, {'test': (value.data()!['test'] as int) + 1});
          }),
          firestore.runTransaction((transaction) async {
            final value = await transaction.get(doc1);
            transaction.set(doc1, {'test': (value.data()!['test'] as int) + 1});
          }),
        ]);

        final snapshot1 = await doc1.get();
        expect(snapshot1.data()!['test'], equals(2));
      },
    );

    test(
      'should collide transaction if number of maxAttempts is not enough',
      retry: 2,
      () async {
        final doc1 = await initializeTest('transaction-maxAttempts-1');

        await doc1.set({'test': 0});
        expect(
          () async => Future.wait([
            firestore.runTransaction((transaction) async {
              final value = await transaction.get(doc1);
              transaction.set(doc1, {
                'test': (value.data()!['test'] as int) + 1,
              });
            }, transactionOptions: ReadWriteTransactionOptions(maxAttempts: 1)),
            firestore.runTransaction((transaction) async {
              final value = await transaction.get(doc1);
              transaction.set(doc1, {
                'test': (value.data()!['test'] as int) + 1,
              });
            }, transactionOptions: ReadWriteTransactionOptions(maxAttempts: 1)),
          ]),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Transaction max attempts exceeded'),
            ),
          ),
        );
      },
    );

    test('works with withConverter', () async {
      final rawDoc = await initializeTest('with-converter-batch');

      final doc = rawDoc.withConverter(
        fromFirestore: (snapshot) {
          return snapshot.data()['value']! as int;
        },
        toFirestore: (value) => {'value': value},
      );

      await doc.set(42);

      expect(
        await firestore.runTransaction<int?>((transaction) async {
          final snapshot = await transaction.get<int>(doc);
          return snapshot.data();
        }),
        42,
      );

      await firestore.runTransaction((transaction) async {
        transaction.set(doc, 21);
      });

      expect(await doc.get().then((s) => s.data()), 21);

      await firestore.runTransaction((transaction) async {
        transaction.update(doc, {'value': 0});
      });

      expect(await doc.get().then((s) => s.data()), 0);
    });

    test('should resolve with user value', () async {
      final randomValue = Random().nextInt(9999);
      final response = await firestore.runTransaction<int>((transaction) async {
        return randomValue;
      });
      expect(response, equals(randomValue));
    });
  }, tags: 'firebase-emulator');
}
