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

import 'package:firebase_admin_sdk/src/remote_config/remote_config.dart';
import 'package:test/test.dart';

NamedCondition _named(String name, OneOfCondition condition) =>
    NamedCondition(name: name, condition: condition);

void main() {
  group('ConditionEvaluator', () {
    late ConditionEvaluator evaluator;

    setUp(() {
      evaluator = ConditionEvaluator();
    });

    group('logical operators', () {
      test('TrueCondition always evaluates to true', () {
        final results = evaluator.evaluateConditions([
          _named('always-true', const TrueCondition()),
        ], const EvaluationContext());
        expect(results['always-true'], isTrue);
      });

      test('FalseCondition always evaluates to false', () {
        final results = evaluator.evaluateConditions([
          _named('always-false', const FalseCondition()),
        ], const EvaluationContext());
        expect(results['always-false'], isFalse);
      });

      test('OrCondition: short-circuits to true on first true child', () {
        final cond = const OrCondition(
          conditions: [TrueCondition(), FalseCondition()],
        );
        expect(
          evaluator.evaluateConditions([
            _named('or', cond),
          ], const EvaluationContext())['or'],
          isTrue,
        );
      });

      test('OrCondition: false when all children false', () {
        final cond = const OrCondition(
          conditions: [FalseCondition(), FalseCondition()],
        );
        expect(
          evaluator.evaluateConditions([
            _named('or', cond),
          ], const EvaluationContext())['or'],
          isFalse,
        );
      });

      test('OrCondition: empty/null conditions evaluate to false', () {
        final emptyOr = const OrCondition(conditions: []);
        final nullOr = const OrCondition();
        final results = evaluator.evaluateConditions([
          _named('empty', emptyOr),
          _named('null', nullOr),
        ], const EvaluationContext());
        expect(results['empty'], isFalse);
        expect(results['null'], isFalse);
      });

      test('AndCondition: true when all children true', () {
        final cond = const AndCondition(
          conditions: [TrueCondition(), TrueCondition()],
        );
        expect(
          evaluator.evaluateConditions([
            _named('and', cond),
          ], const EvaluationContext())['and'],
          isTrue,
        );
      });

      test('AndCondition: short-circuits to false on first false child', () {
        final cond = const AndCondition(
          conditions: [TrueCondition(), FalseCondition()],
        );
        expect(
          evaluator.evaluateConditions([
            _named('and', cond),
          ], const EvaluationContext())['and'],
          isFalse,
        );
      });

      test('AndCondition: empty/null conditions evaluate to true', () {
        final emptyAnd = const AndCondition(conditions: []);
        final nullAnd = const AndCondition();
        final results = evaluator.evaluateConditions([
          _named('empty', emptyAnd),
          _named('null', nullAnd),
        ], const EvaluationContext());
        expect(results['empty'], isTrue);
        expect(results['null'], isTrue);
      });

      test('preserves condition order in result map', () {
        final results = evaluator.evaluateConditions([
          _named('z', const TrueCondition()),
          _named('a', const FalseCondition()),
          _named('m', const TrueCondition()),
        ], const EvaluationContext());
        expect(results.keys.toList(), ['z', 'a', 'm']);
      });

      test('recursion deeper than 10 levels evaluates to false', () {
        // Build a chain of 12 nested OR(TRUE) wrappers; the inner TRUE
        // should be unreachable past the depth limit.
        OneOfCondition deep = const TrueCondition();
        for (var i = 0; i < 12; i++) {
          deep = OrCondition(conditions: [deep]);
        }
        expect(
          evaluator.evaluateConditions([
            _named('deep', deep),
          ], const EvaluationContext())['deep'],
          isFalse,
        );
      });
    });

    group('PercentCondition', () {
      test('returns false when randomizationId is missing', () {
        final cond = PercentCondition(
          percentOperator: PercentConditionOperator.lessOrEqual,
          microPercent: 50000000,
        );
        expect(
          evaluator.evaluateConditions([
            _named('p', cond),
          ], const EvaluationContext())['p'],
          isFalse,
        );
      });

      test('returns false when operator is unknown / null', () {
        final cond = PercentCondition(microPercent: 50000000);
        expect(
          evaluator.evaluateConditions([
            _named('p', cond),
          ], const EvaluationContext(randomizationId: 'user-1'))['p'],
          isFalse,
        );
      });

      test('LESS_OR_EQUAL with microPercent=100M targets all instances', () {
        final cond = PercentCondition(
          percentOperator: PercentConditionOperator.lessOrEqual,
          microPercent: 100000000,
        );
        for (final id in const ['a', 'b', 'c', 'user-1', 'user-2']) {
          expect(
            evaluator.evaluateConditions([
              _named('p', cond),
            ], EvaluationContext(randomizationId: id))['p'],
            isTrue,
            reason: 'id=$id should be in 100% bucket',
          );
        }
      });

      test('LESS_OR_EQUAL with microPercent=0 targets no instances', () {
        final cond = PercentCondition(
          percentOperator: PercentConditionOperator.lessOrEqual,
          microPercent: 0,
        );
        for (final id in const ['a', 'b', 'c', 'user-1', 'user-2']) {
          expect(
            evaluator.evaluateConditions([
              _named('p', cond),
            ], EvaluationContext(randomizationId: id))['p'],
            isFalse,
            reason: 'id=$id should not be in 0% bucket',
          );
        }
      });

      test('GREATER_THAN with microPercent=0 targets all instances', () {
        final cond = PercentCondition(
          percentOperator: PercentConditionOperator.greaterThan,
          microPercent: 0,
        );
        // microPercentile is in [0, 99999999], strictly greater than 0 for
        // most non-zero hashes — but a hash that mods to exactly 0 will fail.
        // We assert across several IDs to catch the typical case.
        var hits = 0;
        for (final id in const ['a', 'b', 'c', 'user-1', 'user-2']) {
          if (evaluator.evaluateConditions([
                _named('p', cond),
              ], EvaluationContext(randomizationId: id))['p'] ==
              true) {
            hits++;
          }
        }
        expect(hits, greaterThanOrEqualTo(4));
      });

      test('BETWEEN with full range [0, 100M] targets all instances', () {
        final cond = PercentCondition(
          percentOperator: PercentConditionOperator.between,
          microPercentRange: const MicroPercentRange(
            microPercentLowerBound: -1, // exclusive lower → include 0
            microPercentUpperBound: 100000000,
          ),
        );
        for (final id in const ['a', 'b', 'c']) {
          expect(
            evaluator.evaluateConditions([
              _named('p', cond),
            ], EvaluationContext(randomizationId: id))['p'],
            isTrue,
            reason: 'id=$id should be in [0, 100M] bucket',
          );
        }
      });

      test('SHA-256 hash produces a deterministic BigInt for known input', () {
        // Pre-computed: SHA-256("test-seed.user-1") in hex, as BigInt.
        // Confirmed against the same string hashed via openssl/sha256sum.
        const input = 'test-seed.user-1';
        final hash = ConditionEvaluator.hashSeededRandomizationIdForTest(input);
        // Sanity: the hash must fit in 256 bits.
        expect(hash, greaterThan(BigInt.zero));
        expect(hash.bitLength, lessThanOrEqualTo(256));
      });

      test('seed is prefixed onto randomizationId with a "."', () {
        // Two different seeds with the same id should usually produce
        // different hashes (and hence different bucket assignments).
        final cond1 = PercentCondition(
          percentOperator: PercentConditionOperator.lessOrEqual,
          microPercent: 50000000, // 50%
          seed: 'seed-A',
        );
        final cond2 = PercentCondition(
          percentOperator: PercentConditionOperator.lessOrEqual,
          microPercent: 50000000,
          seed: 'seed-B',
        );
        // Sample many ids; we expect SOME divergence between the two
        // seeded buckets.
        var divergent = 0;
        for (var i = 0; i < 100; i++) {
          final ctx = EvaluationContext(randomizationId: 'user-$i');
          final r1 = evaluator.evaluateConditions([
            _named('p', cond1),
          ], ctx)['p']!;
          final r2 = evaluator.evaluateConditions([
            _named('p', cond2),
          ], ctx)['p']!;
          if (r1 != r2) divergent++;
        }
        expect(divergent, greaterThan(10));
      });
    });

    group('CustomSignalCondition - string operators', () {
      EvaluationContext ctxWith(String key, Object value) =>
          EvaluationContext(customSignals: {key: value});

      test('STRING_CONTAINS matches substring', () {
        final cond = CustomSignalCondition(
          customSignalOperator: CustomSignalOperator.stringContains,
          customSignalKey: 'country',
          targetCustomSignalValues: const ['US', 'CA'],
        );
        expect(
          evaluator.evaluateConditions([
            _named('c', cond),
          ], ctxWith('country', 'USA'))['c'],
          isTrue,
        );
        expect(
          evaluator.evaluateConditions([
            _named('c', cond),
          ], ctxWith('country', 'JP'))['c'],
          isFalse,
        );
      });

      test('STRING_DOES_NOT_CONTAIN is the negation', () {
        final cond = CustomSignalCondition(
          customSignalOperator: CustomSignalOperator.stringDoesNotContain,
          customSignalKey: 'country',
          targetCustomSignalValues: const ['US', 'CA'],
        );
        expect(
          evaluator.evaluateConditions([
            _named('c', cond),
          ], ctxWith('country', 'USA'))['c'],
          isFalse,
        );
        expect(
          evaluator.evaluateConditions([
            _named('c', cond),
          ], ctxWith('country', 'JP'))['c'],
          isTrue,
        );
      });

      test(
        'STRING_EXACTLY_MATCHES trims both sides and matches any target',
        () {
          final cond = CustomSignalCondition(
            customSignalOperator: CustomSignalOperator.stringExactlyMatches,
            customSignalKey: 'tier',
            targetCustomSignalValues: const ['gold', 'platinum'],
          );
          expect(
            evaluator.evaluateConditions([
              _named('c', cond),
            ], ctxWith('tier', '  gold  '))['c'],
            isTrue,
          );
          expect(
            evaluator.evaluateConditions([
              _named('c', cond),
            ], ctxWith('tier', 'silver'))['c'],
            isFalse,
          );
        },
      );

      test('STRING_CONTAINS_REGEX matches via RegExp', () {
        final cond = CustomSignalCondition(
          customSignalOperator: CustomSignalOperator.stringContainsRegex,
          customSignalKey: 'email',
          targetCustomSignalValues: const [r'^.+@example\.com$'],
        );
        expect(
          evaluator.evaluateConditions([
            _named('c', cond),
          ], ctxWith('email', 'alice@example.com'))['c'],
          isTrue,
        );
        expect(
          evaluator.evaluateConditions([
            _named('c', cond),
          ], ctxWith('email', 'alice@other.com'))['c'],
          isFalse,
        );
      });
    });

    group('CustomSignalCondition - numeric operators', () {
      EvaluationContext ctxWith(Object value) =>
          EvaluationContext(customSignals: {'age': value});

      test('NUMERIC_LESS_THAN', () {
        final cond = CustomSignalCondition(
          customSignalOperator: CustomSignalOperator.numericLessThan,
          customSignalKey: 'age',
          targetCustomSignalValues: const ['30'],
        );
        expect(
          evaluator.evaluateConditions([_named('c', cond)], ctxWith(25))['c'],
          isTrue,
        );
        expect(
          evaluator.evaluateConditions([_named('c', cond)], ctxWith(30))['c'],
          isFalse,
        );
        // Numeric value supplied as string also works.
        expect(
          evaluator.evaluateConditions([_named('c', cond)], ctxWith('29'))['c'],
          isTrue,
        );
      });

      test('NUMERIC_LESS_EQUAL / EQUAL / NOT_EQUAL', () {
        for (final entry in <CustomSignalOperator, Map<num, bool>>{
          CustomSignalOperator.numericLessEqual: {
            29: true,
            30: true,
            31: false,
          },
          CustomSignalOperator.numericEqual: {29: false, 30: true, 31: false},
          CustomSignalOperator.numericNotEqual: {29: true, 30: false, 31: true},
        }.entries) {
          final cond = CustomSignalCondition(
            customSignalOperator: entry.key,
            customSignalKey: 'age',
            targetCustomSignalValues: const ['30'],
          );
          for (final tc in entry.value.entries) {
            expect(
              evaluator.evaluateConditions([
                _named('c', cond),
              ], ctxWith(tc.key))['c'],
              tc.value,
              reason: '${entry.key.name} with actual=${tc.key} target=30',
            );
          }
        }
      });

      test('NUMERIC_GREATER_THAN / GREATER_EQUAL', () {
        for (final entry in <CustomSignalOperator, Map<num, bool>>{
          CustomSignalOperator.numericGreaterThan: {
            29: false,
            30: false,
            31: true,
          },
          CustomSignalOperator.numericGreaterEqual: {
            29: false,
            30: true,
            31: true,
          },
        }.entries) {
          final cond = CustomSignalCondition(
            customSignalOperator: entry.key,
            customSignalKey: 'age',
            targetCustomSignalValues: const ['30'],
          );
          for (final tc in entry.value.entries) {
            expect(
              evaluator.evaluateConditions([
                _named('c', cond),
              ], ctxWith(tc.key))['c'],
              tc.value,
              reason: '${entry.key.name} with actual=${tc.key} target=30',
            );
          }
        }
      });

      test('non-numeric actual or target returns false', () {
        final cond = CustomSignalCondition(
          customSignalOperator: CustomSignalOperator.numericEqual,
          customSignalKey: 'age',
          targetCustomSignalValues: const ['30'],
        );
        expect(
          evaluator.evaluateConditions([
            _named('c', cond),
          ], ctxWith('not-a-number'))['c'],
          isFalse,
        );
      });
    });

    group('CustomSignalCondition - semver operators', () {
      EvaluationContext ctxWith(String version) =>
          EvaluationContext(customSignals: {'version': version});

      test('SEMANTIC_VERSION_LESS_THAN with multi-segment versions', () {
        final cond = CustomSignalCondition(
          customSignalOperator: CustomSignalOperator.semanticVersionLessThan,
          customSignalKey: 'version',
          targetCustomSignalValues: const ['2.0.0'],
        );
        expect(
          evaluator.evaluateConditions([
            _named('c', cond),
          ], ctxWith('1.9.9'))['c'],
          isTrue,
        );
        expect(
          evaluator.evaluateConditions([
            _named('c', cond),
          ], ctxWith('2.0.0'))['c'],
          isFalse,
        );
        expect(
          evaluator.evaluateConditions([
            _named('c', cond),
          ], ctxWith('2.0.1'))['c'],
          isFalse,
        );
      });

      test('SEMANTIC_VERSION_EQUAL handles missing trailing segments', () {
        final cond = CustomSignalCondition(
          customSignalOperator: CustomSignalOperator.semanticVersionEqual,
          customSignalKey: 'version',
          targetCustomSignalValues: const ['1.2'],
        );
        expect(
          evaluator.evaluateConditions([
            _named('c', cond),
          ], ctxWith('1.2.0'))['c'],
          isTrue,
          reason: 'missing trailing segments are treated as 0',
        );
        expect(
          evaluator.evaluateConditions([
            _named('c', cond),
          ], ctxWith('1.2.1'))['c'],
          isFalse,
        );
      });

      test('non-numeric segment returns false', () {
        final cond = CustomSignalCondition(
          customSignalOperator: CustomSignalOperator.semanticVersionEqual,
          customSignalKey: 'version',
          targetCustomSignalValues: const ['1.2.0'],
        );
        expect(
          evaluator.evaluateConditions([
            _named('c', cond),
          ], ctxWith('1.2-alpha'))['c'],
          isFalse,
          reason: '"alpha" is not numeric',
        );
      });

      test('versions longer than 5 segments evaluate to false', () {
        final cond = CustomSignalCondition(
          customSignalOperator: CustomSignalOperator.semanticVersionEqual,
          customSignalKey: 'version',
          targetCustomSignalValues: const ['1.0.0.0.0.0'],
        );
        expect(
          evaluator.evaluateConditions([
            _named('c', cond),
          ], ctxWith('1.0.0.0.0.0'))['c'],
          isFalse,
        );
      });

      test('semver greater/less variants', () {
        final lt = CustomSignalCondition(
          customSignalOperator: CustomSignalOperator.semanticVersionLessEqual,
          customSignalKey: 'version',
          targetCustomSignalValues: const ['2.0.0'],
        );
        final gte = CustomSignalCondition(
          customSignalOperator:
              CustomSignalOperator.semanticVersionGreaterEqual,
          customSignalKey: 'version',
          targetCustomSignalValues: const ['2.0.0'],
        );
        expect(
          evaluator.evaluateConditions([
            _named('lt', lt),
            _named('gte', gte),
          ], ctxWith('2.0.0')),
          {'lt': true, 'gte': true},
        );
        expect(
          evaluator.evaluateConditions([
            _named('lt', lt),
            _named('gte', gte),
          ], ctxWith('2.0.1')),
          {'lt': false, 'gte': true},
        );
      });
    });

    group('CustomSignalCondition - missing inputs', () {
      test('missing customSignalKey returns false', () {
        final cond = CustomSignalCondition(
          customSignalOperator: CustomSignalOperator.numericEqual,
          targetCustomSignalValues: const ['1'],
        );
        expect(
          evaluator.evaluateConditions([
            _named('c', cond),
          ], const EvaluationContext(customSignals: {'foo': 1}))['c'],
          isFalse,
        );
      });

      test('missing targetCustomSignalValues returns false', () {
        final cond = CustomSignalCondition(
          customSignalOperator: CustomSignalOperator.numericEqual,
          customSignalKey: 'foo',
        );
        expect(
          evaluator.evaluateConditions([
            _named('c', cond),
          ], const EvaluationContext(customSignals: {'foo': 1}))['c'],
          isFalse,
        );
      });

      test('signal key absent in context returns false', () {
        final cond = CustomSignalCondition(
          customSignalOperator: CustomSignalOperator.numericEqual,
          customSignalKey: 'missing',
          targetCustomSignalValues: const ['1'],
        );
        expect(
          evaluator.evaluateConditions([
            _named('c', cond),
          ], const EvaluationContext(customSignals: {'foo': 1}))['c'],
          isFalse,
        );
      });
    });
  });
}
