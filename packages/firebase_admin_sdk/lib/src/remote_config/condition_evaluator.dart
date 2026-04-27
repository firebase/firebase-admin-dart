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

part of 'remote_config.dart';

/// Server-side condition evaluator for [ServerTemplate.evaluate].
@internal
class ConditionEvaluator {
  static const int _maxRecursionDepth = 10;

  /// Evaluates each named condition in [namedConditions] against [context],
  /// returning a map from condition name to boolean result. The returned map
  /// preserves insertion order, matching the priority order of the input.
  Map<String, bool> evaluateConditions(
    List<NamedCondition> namedConditions,
    EvaluationContext context,
  ) {
    final results = <String, bool>{};
    for (final namedCondition in namedConditions) {
      results[namedCondition.name] = _evaluate(
        namedCondition.condition,
        context,
        0,
      );
    }
    return results;
  }

  bool _evaluate(
    OneOfCondition condition,
    EvaluationContext context,
    int nestingLevel,
  ) {
    if (nestingLevel >= _maxRecursionDepth) return false;
    return switch (condition) {
      TrueCondition() => true,
      FalseCondition() => false,
      OrCondition() => _evaluateOr(condition, context, nestingLevel + 1),
      AndCondition() => _evaluateAnd(condition, context, nestingLevel + 1),
      PercentCondition() => _evaluatePercent(condition, context),
      CustomSignalCondition() => _evaluateCustomSignal(condition, context),
    };
  }

  bool _evaluateOr(
    OrCondition cond,
    EvaluationContext context,
    int nestingLevel,
  ) {
    final subs = cond.conditions ?? const <OneOfCondition>[];
    for (final sub in subs) {
      if (_evaluate(sub, context, nestingLevel + 1)) return true;
    }
    return false;
  }

  bool _evaluateAnd(
    AndCondition cond,
    EvaluationContext context,
    int nestingLevel,
  ) {
    final subs = cond.conditions ?? const <OneOfCondition>[];
    for (final sub in subs) {
      if (!_evaluate(sub, context, nestingLevel + 1)) return false;
    }
    return true;
  }

  bool _evaluatePercent(PercentCondition cond, EvaluationContext context) {
    final randomizationId = context.randomizationId;
    if (randomizationId == null) return false;

    final op = cond.percentOperator;
    if (op == null || op == PercentConditionOperator.unknown) return false;

    final microPercent = cond.microPercent ?? 0;
    final upper = cond.microPercentRange?.microPercentUpperBound ?? 0;
    final lower = cond.microPercentRange?.microPercentLowerBound ?? 0;

    final seed = cond.seed;
    final seedPrefix = (seed != null && seed.isNotEmpty) ? '$seed.' : '';
    final stringToHash = '$seedPrefix$randomizationId';

    final hash = _hashSeededRandomizationId(stringToHash);
    final instanceMicroPercentile = (hash % BigInt.from(100 * 1000000)).toInt();

    return switch (op) {
      PercentConditionOperator.lessOrEqual =>
        instanceMicroPercentile <= microPercent,
      PercentConditionOperator.greaterThan =>
        instanceMicroPercentile > microPercent,
      PercentConditionOperator.between =>
        instanceMicroPercentile > lower && instanceMicroPercentile <= upper,
      PercentConditionOperator.unknown => false,
    };
  }

  /// SHA-256 the input string and return the resulting digest as a [BigInt].
  /// Visible for testing.
  @internal
  static BigInt hashSeededRandomizationIdForTest(
    String seededRandomizationId,
  ) => _hashSeededRandomizationId(seededRandomizationId);

  static BigInt _hashSeededRandomizationId(String input) {
    final bytes = sha256.convert(utf8.encode(input)).bytes;
    final hex = StringBuffer();
    for (final b in bytes) {
      hex.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return BigInt.parse(hex.toString(), radix: 16);
  }

  bool _evaluateCustomSignal(
    CustomSignalCondition cond,
    EvaluationContext context,
  ) {
    final op = cond.customSignalOperator;
    final key = cond.customSignalKey;
    final targets = cond.targetCustomSignalValues;

    if (op == null ||
        op == CustomSignalOperator.unknown ||
        key == null ||
        targets == null ||
        targets.isEmpty) {
      return false;
    }

    final actual = context.customSignals[key];
    if (actual == null) return false;

    return switch (op) {
      CustomSignalOperator.stringContains => _compareStrings(
        targets,
        actual,
        (target, actualString) => actualString.contains(target),
      ),
      CustomSignalOperator.stringDoesNotContain => !_compareStrings(
        targets,
        actual,
        (target, actualString) => actualString.contains(target),
      ),
      CustomSignalOperator.stringExactlyMatches => _compareStrings(
        targets,
        actual,
        (target, actualString) => actualString.trim() == target.trim(),
      ),
      CustomSignalOperator.stringContainsRegex => _compareStrings(
        targets,
        actual,
        (target, actualString) => RegExp(target).hasMatch(actualString),
      ),
      CustomSignalOperator.numericLessThan => _compareNumbers(
        actual,
        targets[0],
        (r) => r < 0,
      ),
      CustomSignalOperator.numericLessEqual => _compareNumbers(
        actual,
        targets[0],
        (r) => r <= 0,
      ),
      CustomSignalOperator.numericEqual => _compareNumbers(
        actual,
        targets[0],
        (r) => r == 0,
      ),
      CustomSignalOperator.numericNotEqual => _compareNumbers(
        actual,
        targets[0],
        (r) => r != 0,
      ),
      CustomSignalOperator.numericGreaterThan => _compareNumbers(
        actual,
        targets[0],
        (r) => r > 0,
      ),
      CustomSignalOperator.numericGreaterEqual => _compareNumbers(
        actual,
        targets[0],
        (r) => r >= 0,
      ),
      CustomSignalOperator.semanticVersionLessThan => _compareSemver(
        actual,
        targets[0],
        (r) => r < 0,
      ),
      CustomSignalOperator.semanticVersionLessEqual => _compareSemver(
        actual,
        targets[0],
        (r) => r <= 0,
      ),
      CustomSignalOperator.semanticVersionEqual => _compareSemver(
        actual,
        targets[0],
        (r) => r == 0,
      ),
      CustomSignalOperator.semanticVersionNotEqual => _compareSemver(
        actual,
        targets[0],
        (r) => r != 0,
      ),
      CustomSignalOperator.semanticVersionGreaterThan => _compareSemver(
        actual,
        targets[0],
        (r) => r > 0,
      ),
      CustomSignalOperator.semanticVersionGreaterEqual => _compareSemver(
        actual,
        targets[0],
        (r) => r >= 0,
      ),
      CustomSignalOperator.unknown => false,
    };
  }
}

bool _compareStrings(
  List<String> targets,
  Object actualValue,
  bool Function(String target, String actual) predicate,
) {
  final actualString = actualValue.toString();
  return targets.any((target) => predicate(target, actualString));
}

bool _compareNumbers(
  Object actualValue,
  String targetValue,
  bool Function(int result) predicate,
) {
  final actual = _coerceDouble(actualValue);
  final target = double.tryParse(targetValue);
  if (actual == null || target == null) return false;
  final cmp = actual < target ? -1 : (actual > target ? 1 : 0);
  return predicate(cmp);
}

const int _semverMaxLength = 5;

bool _compareSemver(
  Object actualValue,
  String targetValue,
  bool Function(int result) predicate,
) {
  final v1 = actualValue.toString().split('.');
  final v2 = targetValue.split('.');

  if (v1.length > _semverMaxLength || v2.length > _semverMaxLength) {
    return false;
  }

  for (var i = 0; i < _semverMaxLength; i++) {
    // Semver segments are integers per spec; non-integer parts (e.g. "1.0-rc")
    // make the segment unparsable and the whole comparison return false.
    final s1 = i < v1.length ? int.tryParse(v1[i]) : 0;
    final s2 = i < v2.length ? int.tryParse(v2[i]) : 0;
    if (s1 == null || s2 == null) return false;
    if (s1 < s2) return predicate(-1);
    if (s1 > s2) return predicate(1);
  }
  return predicate(0);
}

double? _coerceDouble(Object value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
