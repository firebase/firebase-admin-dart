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

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

void main() {
  group('Filter', () {
    group('where()', () {
      test('creates filter with field name and operator', () {
        final filter = Filter.where('foo', WhereFilter.equal, 'bar');
        expect(filter, isA<Filter>());
      });

      test('creates filter with less than operator', () {
        final filter = Filter.where('count', WhereFilter.lessThan, 10);
        expect(filter, isA<Filter>());
      });

      test('creates filter with less than or equal operator', () {
        final filter = Filter.where('count', WhereFilter.lessThanOrEqual, 10);
        expect(filter, isA<Filter>());
      });

      test('creates filter with equal operator', () {
        final filter = Filter.where('status', WhereFilter.equal, 'active');
        expect(filter, isA<Filter>());
      });

      test('creates filter with not equal operator', () {
        final filter = Filter.where('status', WhereFilter.notEqual, 'deleted');
        expect(filter, isA<Filter>());
      });

      test('creates filter with greater than or equal operator', () {
        final filter = Filter.where('count', WhereFilter.greaterThanOrEqual, 5);
        expect(filter, isA<Filter>());
      });

      test('creates filter with greater than operator', () {
        final filter = Filter.where('count', WhereFilter.greaterThan, 5);
        expect(filter, isA<Filter>());
      });

      test('creates filter with array-contains operator', () {
        final filter = Filter.where(
          'tags',
          WhereFilter.arrayContains,
          'firebase',
        );
        expect(filter, isA<Filter>());
      });

      test('creates filter with in operator', () {
        final filter = Filter.where('status', WhereFilter.isIn, const [
          'active',
          'pending',
        ]);
        expect(filter, isA<Filter>());
      });

      test('creates filter with not-in operator', () {
        final filter = Filter.where('status', WhereFilter.notIn, const [
          'deleted',
          'archived',
        ]);
        expect(filter, isA<Filter>());
      });

      test('creates filter with array-contains-any operator', () {
        final filter = Filter.where(
          'tags',
          WhereFilter.arrayContainsAny,
          const ['firebase', 'google'],
        );
        expect(filter, isA<Filter>());
      });

      test('creates filter with null value', () {
        final filter = Filter.where('optional', WhereFilter.equal, null);
        expect(filter, isA<Filter>());
      });

      test('creates filter with FieldPath', () {
        final filter = Filter.whereFieldPath(
          FieldPath(const ['nested', 'field']),
          WhereFilter.equal,
          'value',
        );
        expect(filter, isA<Filter>());
      });
    });

    group('and()', () {
      test('creates composite AND filter with two filters', () {
        final filter1 = Filter.where('foo', WhereFilter.equal, 'bar');
        final filter2 = Filter.where('baz', WhereFilter.greaterThan, 0);
        final andFilter = Filter.and([filter1, filter2]);

        expect(andFilter, isA<Filter>());
      });

      test('creates composite AND filter with multiple filters', () {
        final filter1 = Filter.where('foo', WhereFilter.equal, 'bar');
        final filter2 = Filter.where('baz', WhereFilter.greaterThan, 0);
        final filter3 = Filter.where('status', WhereFilter.equal, 'active');
        final andFilter = Filter.and([filter1, filter2, filter3]);

        expect(andFilter, isA<Filter>());
      });

      test('creates composite AND filter with single filter', () {
        final filter1 = Filter.where('foo', WhereFilter.equal, 'bar');
        final andFilter = Filter.and([filter1]);

        expect(andFilter, isA<Filter>());
      });

      test('creates composite AND filter with empty list', () {
        final andFilter = Filter.and(const []);
        expect(andFilter, isA<Filter>());
      });

      test('creates nested AND filter', () {
        final filter1 = Filter.where('a', WhereFilter.equal, 1);
        final filter2 = Filter.where('b', WhereFilter.equal, 2);
        final innerAnd = Filter.and([filter1, filter2]);

        final filter3 = Filter.where('c', WhereFilter.equal, 3);
        final outerAnd = Filter.and([innerAnd, filter3]);

        expect(outerAnd, isA<Filter>());
      });
    });

    group('or()', () {
      test('creates composite OR filter with two filters', () {
        final filter1 = Filter.where('foo', WhereFilter.equal, 'bar');
        final filter2 = Filter.where('baz', WhereFilter.greaterThan, 0);
        final orFilter = Filter.or([filter1, filter2]);

        expect(orFilter, isA<Filter>());
      });

      test('creates composite OR filter with multiple filters', () {
        final filter1 = Filter.where('status', WhereFilter.equal, 'active');
        final filter2 = Filter.where('status', WhereFilter.equal, 'pending');
        final filter3 = Filter.where('status', WhereFilter.equal, 'review');
        final orFilter = Filter.or([filter1, filter2, filter3]);

        expect(orFilter, isA<Filter>());
      });

      test('creates composite OR filter with single filter', () {
        final filter1 = Filter.where('foo', WhereFilter.equal, 'bar');
        final orFilter = Filter.or([filter1]);

        expect(orFilter, isA<Filter>());
      });

      test('creates composite OR filter with empty list', () {
        final orFilter = Filter.or(const []);
        expect(orFilter, isA<Filter>());
      });

      test('creates nested OR filter', () {
        final filter1 = Filter.where('a', WhereFilter.equal, 1);
        final filter2 = Filter.where('b', WhereFilter.equal, 2);
        final innerOr = Filter.or([filter1, filter2]);

        final filter3 = Filter.where('c', WhereFilter.equal, 3);
        final outerOr = Filter.or([innerOr, filter3]);

        expect(outerOr, isA<Filter>());
      });
    });

    group('mixed composite filters', () {
      test('creates AND filter containing OR filters', () {
        // (a == 1 OR a == 2) AND (b == 3 OR b == 4)
        final orFilter1 = Filter.or([
          Filter.where('a', WhereFilter.equal, 1),
          Filter.where('a', WhereFilter.equal, 2),
        ]);
        final orFilter2 = Filter.or([
          Filter.where('b', WhereFilter.equal, 3),
          Filter.where('b', WhereFilter.equal, 4),
        ]);
        final andFilter = Filter.and([orFilter1, orFilter2]);

        expect(andFilter, isA<Filter>());
      });

      test('creates OR filter containing AND filters', () {
        // (a == 1 AND b == 2) OR (c == 3 AND d == 4)
        final andFilter1 = Filter.and([
          Filter.where('a', WhereFilter.equal, 1),
          Filter.where('b', WhereFilter.equal, 2),
        ]);
        final andFilter2 = Filter.and([
          Filter.where('c', WhereFilter.equal, 3),
          Filter.where('d', WhereFilter.equal, 4),
        ]);
        final orFilter = Filter.or([andFilter1, andFilter2]);

        expect(orFilter, isA<Filter>());
      });

      test('creates complex nested filter', () {
        // ((a == 1 AND b == 2) OR (c == 3)) AND d == 4
        final innerAnd = Filter.and([
          Filter.where('a', WhereFilter.equal, 1),
          Filter.where('b', WhereFilter.equal, 2),
        ]);
        final innerOr = Filter.or([
          innerAnd,
          Filter.where('c', WhereFilter.equal, 3),
        ]);
        final outerAnd = Filter.and([
          innerOr,
          Filter.where('d', WhereFilter.equal, 4),
        ]);

        expect(outerAnd, isA<Filter>());
      });
    });
  });
}
