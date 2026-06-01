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

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Display tag color for a [RemoteConfigCondition] in the Firebase Console.
enum TagColor {
  blue('BLUE'),
  brown('BROWN'),
  cyan('CYAN'),
  deepOrange('DEEP_ORANGE'),
  green('GREEN'),
  indigo('INDIGO'),
  lime('LIME'),
  orange('ORANGE'),
  pink('PINK'),
  purple('PURPLE'),
  teal('TEAL');

  const TagColor(this.name);

  final String name;

  static TagColor? fromName(String? value) {
    if (value == null) return null;
    for (final color in TagColor.values) {
      if (color.name == value) return color;
    }
    return null;
  }
}

/// Data type of a Remote Config parameter value. Defaults to [string] if
/// unspecified.
enum ParameterValueType {
  string('STRING'),
  boolean('BOOLEAN'),
  number('NUMBER'),
  json('JSON');

  const ParameterValueType(this.name);

  final String name;

  static ParameterValueType? fromName(String? value) {
    if (value == null) return null;
    for (final t in ParameterValueType.values) {
      if (t.name == value) return t;
    }
    return null;
  }
}

/// Comparison operators for [PercentCondition].
enum PercentConditionOperator {
  unknown('UNKNOWN'),
  lessOrEqual('LESS_OR_EQUAL'),
  greaterThan('GREATER_THAN'),
  between('BETWEEN');

  const PercentConditionOperator(this.name);

  final String name;

  static PercentConditionOperator fromName(String? value) {
    if (value == null) return PercentConditionOperator.unknown;
    for (final op in PercentConditionOperator.values) {
      if (op.name == value) return op;
    }
    return PercentConditionOperator.unknown;
  }
}

/// Comparison operators for [CustomSignalCondition].
enum CustomSignalOperator {
  unknown('UNKNOWN'),
  numericLessThan('NUMERIC_LESS_THAN'),
  numericLessEqual('NUMERIC_LESS_EQUAL'),
  numericEqual('NUMERIC_EQUAL'),
  numericNotEqual('NUMERIC_NOT_EQUAL'),
  numericGreaterThan('NUMERIC_GREATER_THAN'),
  numericGreaterEqual('NUMERIC_GREATER_EQUAL'),
  stringContains('STRING_CONTAINS'),
  stringDoesNotContain('STRING_DOES_NOT_CONTAIN'),
  stringExactlyMatches('STRING_EXACTLY_MATCHES'),
  stringContainsRegex('STRING_CONTAINS_REGEX'),
  semanticVersionLessThan('SEMANTIC_VERSION_LESS_THAN'),
  semanticVersionLessEqual('SEMANTIC_VERSION_LESS_EQUAL'),
  semanticVersionEqual('SEMANTIC_VERSION_EQUAL'),
  semanticVersionNotEqual('SEMANTIC_VERSION_NOT_EQUAL'),
  semanticVersionGreaterThan('SEMANTIC_VERSION_GREATER_THAN'),
  semanticVersionGreaterEqual('SEMANTIC_VERSION_GREATER_EQUAL');

  const CustomSignalOperator(this.name);

  final String name;

  static CustomSignalOperator fromName(String? value) {
    if (value == null) return CustomSignalOperator.unknown;
    for (final op in CustomSignalOperator.values) {
      if (op.name == value) return op;
    }
    return CustomSignalOperator.unknown;
  }
}

/// Source of a value returned by [ServerConfig].
enum ValueSource {
  /// The value was defined by a static constant. Returned by [ServerConfig]
  /// for keys with no default and no remote value.
  valueStatic('static'),

  /// The value came from the in-app default config provided to
  /// [RemoteConfig.initServerTemplate] or [RemoteConfig.getServerTemplate].
  valueDefault('default'),

  /// The value came from evaluating a server template parameter.
  valueRemote('remote');

  const ValueSource(this.name);

  /// The on-the-wire representation.
  final String name;
}

// ---------------------------------------------------------------------------
// Helpers (private)
// ---------------------------------------------------------------------------

Map<String, T> _decodeMap<T>(
  Object? raw,
  T Function(Map<String, Object?>) decode,
) {
  if (raw == null) return <String, T>{};
  if (raw is! Map) {
    throw FirebaseRemoteConfigException(
      RemoteConfigErrorCode.invalidArgument,
      'Expected an object, got ${raw.runtimeType}.',
    );
  }
  final result = <String, T>{};
  raw.forEach((key, value) {
    result[key as String] = decode(value as Map<String, Object?>);
  });
  return result;
}

Map<String, Object?> _encodeMap<T>(
  Map<String, T> map,
  Map<String, Object?> Function(T) encode,
) {
  return <String, Object?>{
    for (final entry in map.entries) entry.key: encode(entry.value),
  };
}

List<T> _decodeList<T>(Object? raw, T Function(Map<String, Object?>) decode) {
  if (raw == null) return <T>[];
  if (raw is! List) {
    throw FirebaseRemoteConfigException(
      RemoteConfigErrorCode.invalidArgument,
      'Expected an array, got ${raw.runtimeType}.',
    );
  }
  return [for (final item in raw) decode(item as Map<String, Object?>)];
}

// ---------------------------------------------------------------------------
// Simple value types
// ---------------------------------------------------------------------------

/// User who performed an update on a Remote Config template (output only).
class RemoteConfigUser {
  const RemoteConfigUser({required this.email, this.name, this.imageUrl});

  factory RemoteConfigUser.fromJson(Map<String, Object?> json) {
    return RemoteConfigUser(
      email: (json['email'] as String?) ?? '',
      name: json['name'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  /// Email address. Output only.
  final String email;

  /// Display name. Output only.
  final String? name;

  /// Image URL. Output only.
  final String? imageUrl;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'email': email,
      'name': ?name,
      'imageUrl': ?imageUrl,
    };
  }
}

/// Inclusive upper / exclusive lower bound for [PercentConditionOperator.between].
class MicroPercentRange {
  const MicroPercentRange({
    this.microPercentLowerBound,
    this.microPercentUpperBound,
  });

  factory MicroPercentRange.fromJson(Map<String, Object?> json) {
    return MicroPercentRange(
      microPercentLowerBound: (json['microPercentLowerBound'] as num?)?.toInt(),
      microPercentUpperBound: (json['microPercentUpperBound'] as num?)?.toInt(),
    );
  }

  /// Lower bound in micro-percents, range `[0, 100_000_000]`.
  ///
  /// The bound is **exclusive** at evaluation time: a percentile equal to
  /// this value does not match.
  final int? microPercentLowerBound;

  /// Upper bound in micro-percents, range `[0, 100_000_000]`.
  ///
  /// The bound is **inclusive** at evaluation time: a percentile equal to
  /// this value matches.
  final int? microPercentUpperBound;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'microPercentLowerBound': ?microPercentLowerBound,
      'microPercentUpperBound': ?microPercentUpperBound,
    };
  }
}

/// Value linked to a [Rollout](https://firebase.google.com/docs/remote-config/parameters).
class RolloutValue {
  const RolloutValue({
    required this.rolloutId,
    required this.value,
    required this.percent,
  });

  factory RolloutValue.fromJson(Map<String, Object?> json) {
    return RolloutValue(
      rolloutId: (json['rolloutId'] as String?) ?? '',
      value: (json['value'] as String?) ?? '',
      percent: (json['percent'] as num?)?.toDouble() ?? 0,
    );
  }

  /// The identifier that associates this parameter value with a Rollout.
  final String rolloutId;

  /// The user-specified value to be rolled out.
  final String value;

  /// Percentage of users that will receive the rollout value, in the range
  /// `[0, 100]`. Stored as a `double` because the REST API allows fractional
  /// percentages.
  final double percent;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'rolloutId': rolloutId,
      'value': value,
      'percent': percent,
    };
  }
}

/// Personalization-derived parameter value reference.
class PersonalizationValue {
  const PersonalizationValue({required this.personalizationId});

  factory PersonalizationValue.fromJson(Map<String, Object?> json) {
    return PersonalizationValue(
      personalizationId: (json['personalizationId'] as String?) ?? '',
    );
  }

  /// Identifier that represents a personalization definition. The definition
  /// is used to resolve the value at config fetch time. This is system
  /// generated and should not be modified.
  final String personalizationId;

  Map<String, Object?> toJson() {
    return <String, Object?>{'personalizationId': personalizationId};
  }
}

/// Sealed type representing a single experiment variant value.
sealed class ExperimentVariantValue {
  const ExperimentVariantValue._({required this.variantId});

  factory ExperimentVariantValue.fromJson(Map<String, Object?> json) {
    if (json['noChange'] == true) {
      return ExperimentVariantNoChange(
        variantId: (json['variantId'] as String?) ?? '',
      );
    }
    return ExperimentVariantExplicitValue(
      variantId: (json['variantId'] as String?) ?? '',
      value: (json['value'] as String?) ?? '',
    );
  }

  /// The ID of this variant within the experiment.
  final String variantId;

  Map<String, Object?> toJson();
}

/// Experiment variant with an explicit string value.
class ExperimentVariantExplicitValue extends ExperimentVariantValue {
  const ExperimentVariantExplicitValue({
    required super.variantId,
    required this.value,
  }) : super._();

  /// The variant's value within the experiment.
  final String value;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'variantId': variantId, 'value': value};
  }
}

/// Experiment variant marked as "no change" — the SDK falls through to the
/// next matching condition or default value.
class ExperimentVariantNoChange extends ExperimentVariantValue {
  const ExperimentVariantNoChange({required super.variantId}) : super._();

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'variantId': variantId, 'noChange': true};
  }
}

/// Experiment-derived parameter value.
class ExperimentValue {
  const ExperimentValue({
    required this.experimentId,
    required this.variantValue,
    this.exposurePercent,
  });

  factory ExperimentValue.fromJson(Map<String, Object?> json) {
    return ExperimentValue(
      experimentId: (json['experimentId'] as String?) ?? '',
      variantValue: _decodeList(
        json['variantValue'],
        ExperimentVariantValue.fromJson,
      ),
      exposurePercent: (json['exposurePercent'] as num?)?.toDouble(),
    );
  }

  /// The identifier that associates this parameter value with an Experiment
  /// in Firebase A/B Testing.
  final String experimentId;

  /// Variants served by this experiment.
  final List<ExperimentVariantValue> variantValue;

  /// Server-side exposure evaluation: the fraction of users exposed to the
  /// experiment, in the range `[0, 100]` inclusive. `null` if the server did
  /// not include this field.
  final double? exposurePercent;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'experimentId': experimentId,
      'variantValue': [for (final v in variantValue) v.toJson()],
      'exposurePercent': ?exposurePercent,
    };
  }
}

// ---------------------------------------------------------------------------
// Parameter values
// ---------------------------------------------------------------------------

/// Sealed type for a Remote Config parameter value.
///
/// One of: [ExplicitParameterValue], [InAppDefaultValue],
/// [RolloutParameterValue], [PersonalizationParameterValue],
/// [ExperimentParameterValue].
sealed class RemoteConfigParameterValue {
  const RemoteConfigParameterValue._();

  Map<String, Object?> toJson();

  factory RemoteConfigParameterValue.fromJson(Map<String, Object?> json) {
    if (json.containsKey('useInAppDefault')) {
      return InAppDefaultValue(
        useInAppDefault: (json['useInAppDefault'] as bool?) ?? true,
      );
    }
    if (json.containsKey('rolloutValue')) {
      return RolloutParameterValue(
        rolloutValue: RolloutValue.fromJson(
          json['rolloutValue']! as Map<String, Object?>,
        ),
      );
    }
    if (json.containsKey('personalizationValue')) {
      return PersonalizationParameterValue(
        personalizationValue: PersonalizationValue.fromJson(
          json['personalizationValue']! as Map<String, Object?>,
        ),
      );
    }
    if (json.containsKey('experimentValue')) {
      return ExperimentParameterValue(
        experimentValue: ExperimentValue.fromJson(
          json['experimentValue']! as Map<String, Object?>,
        ),
      );
    }
    if (json.containsKey('value')) {
      return ExplicitParameterValue(value: (json['value'] as String?) ?? '');
    }
    throw FirebaseRemoteConfigException(
      RemoteConfigErrorCode.invalidArgument,
      'Unknown parameter value shape: ${json.keys.toList()}',
    );
  }
}

/// Parameter value with an explicit string value.
class ExplicitParameterValue extends RemoteConfigParameterValue {
  const ExplicitParameterValue({required this.value}) : super._();

  /// The string value the parameter is set to.
  final String value;

  @override
  Map<String, Object?> toJson() => <String, Object?>{'value': value};
}

/// Parameter value indicating the client should use its in-app default.
class InAppDefaultValue extends RemoteConfigParameterValue {
  const InAppDefaultValue({required this.useInAppDefault}) : super._();

  /// When `true`, the parameter is omitted from the server-evaluated config.
  final bool useInAppDefault;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'useInAppDefault': useInAppDefault};
  }
}

/// Parameter value linked to a rollout.
class RolloutParameterValue extends RemoteConfigParameterValue {
  const RolloutParameterValue({required this.rolloutValue}) : super._();

  /// The rollout descriptor.
  final RolloutValue rolloutValue;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'rolloutValue': rolloutValue.toJson()};
  }
}

/// Parameter value linked to a personalization.
class PersonalizationParameterValue extends RemoteConfigParameterValue {
  const PersonalizationParameterValue({required this.personalizationValue})
    : super._();

  /// The personalization descriptor.
  final PersonalizationValue personalizationValue;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'personalizationValue': personalizationValue.toJson(),
    };
  }
}

/// Parameter value linked to an experiment.
class ExperimentParameterValue extends RemoteConfigParameterValue {
  const ExperimentParameterValue({required this.experimentValue}) : super._();

  /// The experiment descriptor.
  final ExperimentValue experimentValue;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'experimentValue': experimentValue.toJson()};
  }
}

// ---------------------------------------------------------------------------
// Parameters and groups
// ---------------------------------------------------------------------------

/// A Remote Config parameter.
///
/// At minimum, a [defaultValue] or [conditionalValues] entry must be present
/// for the parameter to have any effect.
class RemoteConfigParameter {
  RemoteConfigParameter({
    this.defaultValue,
    Map<String, RemoteConfigParameterValue>? conditionalValues,
    this.description,
    this.valueType,
  }) : conditionalValues = conditionalValues == null
           ? null
           : Map<String, RemoteConfigParameterValue>.unmodifiable(
               conditionalValues,
             );

  factory RemoteConfigParameter.fromJson(Map<String, Object?> json) {
    final defaultValueJson = json['defaultValue'];
    final conditionalValuesJson = json['conditionalValues'];
    return RemoteConfigParameter(
      defaultValue: defaultValueJson == null
          ? null
          : RemoteConfigParameterValue.fromJson(
              defaultValueJson as Map<String, Object?>,
            ),
      conditionalValues: conditionalValuesJson == null
          ? null
          : _decodeMap(
              conditionalValuesJson,
              RemoteConfigParameterValue.fromJson,
            ),
      description: json['description'] as String?,
      valueType: ParameterValueType.fromName(json['valueType'] as String?),
    );
  }

  /// Value used when no condition matches.
  final RemoteConfigParameterValue? defaultValue;

  /// Map from condition name to value. Conditions are evaluated in template
  /// order; the first match wins.
  final Map<String, RemoteConfigParameterValue>? conditionalValues;

  /// Optional human-readable description for this parameter (≤256 unicode
  /// characters).
  final String? description;

  /// Data type for all values of this parameter in the current version of
  /// the template. Defaults to [ParameterValueType.string] when unspecified.
  final ParameterValueType? valueType;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'defaultValue': ?defaultValue?.toJson(),
      if (conditionalValues != null)
        'conditionalValues': _encodeMap(conditionalValues!, (v) => v.toJson()),
      'description': ?description,
      'valueType': ?valueType?.name,
    };
  }
}

/// A logical grouping of Remote Config parameters (management-only; does not
/// affect client-side fetches).
class RemoteConfigParameterGroup {
  RemoteConfigParameterGroup({
    this.description,
    Map<String, RemoteConfigParameter>? parameters,
  }) : parameters = Map<String, RemoteConfigParameter>.unmodifiable(
         parameters ?? const <String, RemoteConfigParameter>{},
       );

  factory RemoteConfigParameterGroup.fromJson(Map<String, Object?> json) {
    return RemoteConfigParameterGroup(
      description: json['description'] as String?,
      parameters: _decodeMap(
        json['parameters'],
        RemoteConfigParameter.fromJson,
      ),
    );
  }

  /// Optional human-readable description (≤256 unicode characters).
  final String? description;

  /// Parameters that belong to this group.
  final Map<String, RemoteConfigParameter> parameters;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'description': ?description,
      'parameters': _encodeMap(parameters, (p) => p.toJson()),
    };
  }
}

// ---------------------------------------------------------------------------
// Conditions
// ---------------------------------------------------------------------------

/// A client-side condition used by [RemoteConfigTemplate]. The expression is
/// a free-form string evaluated by the Remote Config client SDK.
///
/// Server-side templates use [NamedCondition] instead.
class RemoteConfigCondition {
  const RemoteConfigCondition({
    required this.name,
    required this.expression,
    this.tagColor,
  });

  factory RemoteConfigCondition.fromJson(Map<String, Object?> json) {
    return RemoteConfigCondition(
      name: (json['name'] as String?) ?? '',
      expression: (json['expression'] as String?) ?? '',
      tagColor: TagColor.fromName(json['tagColor'] as String?),
    );
  }

  /// Required. Non-empty and unique name of this condition.
  final String name;

  /// Condition expression syntax — see the
  /// [Condition reference](https://firebase.google.com/docs/remote-config/condition-reference).
  final String expression;

  /// Optional display color for the Firebase Console.
  final TagColor? tagColor;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'expression': expression,
      'tagColor': ?tagColor?.name,
    };
  }
}

/// A server-side named condition used by [ServerTemplateData].
///
/// Unlike [RemoteConfigCondition], the [condition] tree is structured and is
/// evaluated in-process by the Admin SDK.
class NamedCondition {
  const NamedCondition({required this.name, required this.condition});

  factory NamedCondition.fromJson(Map<String, Object?> json) {
    return NamedCondition(
      name: (json['name'] as String?) ?? '',
      condition: OneOfCondition.fromJson(
        (json['condition'] as Map<String, Object?>?) ??
            const <String, Object?>{},
      ),
    );
  }

  /// Required. Non-empty and unique name of this condition.
  final String name;

  /// The structured condition tree.
  final OneOfCondition condition;
}

/// Sealed type for the structured server-side condition tree.
sealed class OneOfCondition {
  const OneOfCondition._();

  Map<String, Object?> toJson();

  factory OneOfCondition.fromJson(Map<String, Object?> json) {
    final or = json['orCondition'];
    if (or is Map<String, Object?>) return OrCondition.fromJson(or);
    final and = json['andCondition'];
    if (and is Map<String, Object?>) return AndCondition.fromJson(and);
    if (json.containsKey('true')) return const TrueCondition();
    if (json.containsKey('false')) return const FalseCondition();
    final percent = json['percent'];
    if (percent is Map<String, Object?>) {
      return PercentCondition.fromJson(percent);
    }
    final custom = json['customSignal'];
    if (custom is Map<String, Object?>) {
      return CustomSignalCondition.fromJson(custom);
    }
    // Forward compat: unknown shape → constant false at evaluation time.
    return const FalseCondition();
  }
}

/// `OR` collection of conditions; true if any sub-condition is true.
class OrCondition extends OneOfCondition {
  const OrCondition({this.conditions}) : super._();

  factory OrCondition.fromJson(Map<String, Object?> json) {
    final raw = json['conditions'];
    if (raw == null) return const OrCondition();
    if (raw is! List) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.invalidArgument,
        'OrCondition.conditions must be an array.',
      );
    }
    return OrCondition(
      conditions: [
        for (final item in raw)
          OneOfCondition.fromJson(item as Map<String, Object?>),
      ],
    );
  }

  /// Sub-conditions; null or empty evaluates to false.
  final List<OneOfCondition>? conditions;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'orCondition': <String, Object?>{
        if (conditions != null)
          'conditions': [for (final c in conditions!) c.toJson()],
      },
    };
  }
}

/// `AND` collection of conditions; true only if all sub-conditions are true.
class AndCondition extends OneOfCondition {
  const AndCondition({this.conditions}) : super._();

  factory AndCondition.fromJson(Map<String, Object?> json) {
    final raw = json['conditions'];
    if (raw == null) return const AndCondition();
    if (raw is! List) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.invalidArgument,
        'AndCondition.conditions must be an array.',
      );
    }
    return AndCondition(
      conditions: [
        for (final item in raw)
          OneOfCondition.fromJson(item as Map<String, Object?>),
      ],
    );
  }

  /// Sub-conditions; null or empty evaluates to true.
  final List<OneOfCondition>? conditions;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'andCondition': <String, Object?>{
        if (conditions != null)
          'conditions': [for (final c in conditions!) c.toJson()],
      },
    };
  }
}

/// Always-true condition.
///
/// Not declared in the public Firebase Remote Config v1 discovery document
/// but accepted by the runtime wire format on the `firebase-server`
/// namespace, so [OneOfCondition.fromJson] decodes it and the evaluator
/// returns `true` without recursing.
class TrueCondition extends OneOfCondition {
  const TrueCondition() : super._();

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'true': <String, Object?>{}};
  }
}

/// Always-false condition.
///
/// Not declared in the public Firebase Remote Config v1 discovery document;
/// see [TrueCondition] for the same caveat.
class FalseCondition extends OneOfCondition {
  const FalseCondition() : super._();

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'false': <String, Object?>{}};
  }
}

/// Targets a percentile range of an instance's pseudo-random hash.
class PercentCondition extends OneOfCondition {
  PercentCondition({
    this.percentOperator,
    this.microPercent,
    this.seed,
    this.microPercentRange,
  }) : super._() {
    final microPercent = this.microPercent;
    if (microPercent != null &&
        (microPercent < 0 || microPercent > 100000000)) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.invalidArgument,
        'microPercent must be in [0, 100000000], got $microPercent.',
      );
    }
    if (seed != null && seed!.length > 32) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.invalidArgument,
        'seed must be 0-32 characters, got ${seed!.length}.',
      );
    }
  }

  factory PercentCondition.fromJson(Map<String, Object?> json) {
    final rangeJson = json['microPercentRange'];
    return PercentCondition(
      percentOperator: PercentConditionOperator.fromName(
        json['percentOperator'] as String?,
      ),
      microPercent: (json['microPercent'] as num?)?.toInt(),
      seed: json['seed'] as String?,
      microPercentRange: rangeJson is Map<String, Object?>
          ? MicroPercentRange.fromJson(rangeJson)
          : null,
    );
  }

  /// Operator to use; null is treated as [PercentConditionOperator.unknown].
  final PercentConditionOperator? percentOperator;

  /// Target percentile in micro-percents for `LESS_OR_EQUAL` / `GREATER_THAN`.
  final int? microPercent;

  /// Optional seed (0-32 ASCII chars `[-_.0-9a-zA-Z]`).
  final String? seed;

  /// Range for [PercentConditionOperator.between].
  final MicroPercentRange? microPercentRange;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'percent': <String, Object?>{
        'percentOperator': ?percentOperator?.name,
        'microPercent': ?microPercent,
        'seed': ?seed,
        'microPercentRange': ?microPercentRange?.toJson(),
      },
    };
  }
}

/// Compares a custom signal from the [EvaluationContext] against target value(s).
class CustomSignalCondition extends OneOfCondition {
  CustomSignalCondition({
    this.customSignalOperator,
    this.customSignalKey,
    List<String>? targetCustomSignalValues,
  }) : targetCustomSignalValues = targetCustomSignalValues == null
           ? null
           : List<String>.unmodifiable(targetCustomSignalValues),
       super._() {
    if (targetCustomSignalValues != null) {
      if (targetCustomSignalValues.isEmpty) {
        throw FirebaseRemoteConfigException(
          RemoteConfigErrorCode.invalidArgument,
          'targetCustomSignalValues must contain at least one value.',
        );
      }
      if (targetCustomSignalValues.length > 100) {
        throw FirebaseRemoteConfigException(
          RemoteConfigErrorCode.invalidArgument,
          'targetCustomSignalValues must contain at most 100 values, '
          'got ${targetCustomSignalValues.length}.',
        );
      }
    }
  }

  factory CustomSignalCondition.fromJson(Map<String, Object?> json) {
    final values = json['targetCustomSignalValues'];
    return CustomSignalCondition(
      customSignalOperator: CustomSignalOperator.fromName(
        json['customSignalOperator'] as String?,
      ),
      customSignalKey: json['customSignalKey'] as String?,
      targetCustomSignalValues: values is List
          ? [for (final v in values) v as String]
          : null,
    );
  }

  /// Required. Operator used to compare the actual value against
  /// [targetCustomSignalValues]. Null is treated as
  /// [CustomSignalOperator.unknown] and evaluates to false.
  final CustomSignalOperator? customSignalOperator;

  /// Required. The custom signal name to look up in
  /// [EvaluationContext.customSignals].
  final String? customSignalKey;

  /// Required. 1–100 target values. Numeric and semantic-version operators
  /// must receive exactly one value; string operators may receive multiple.
  final List<String>? targetCustomSignalValues;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'customSignal': <String, Object?>{
        'customSignalOperator': ?customSignalOperator?.name,
        'customSignalKey': ?customSignalKey,
        'targetCustomSignalValues': ?targetCustomSignalValues,
      },
    };
  }
}

// ---------------------------------------------------------------------------
// Templates
// ---------------------------------------------------------------------------

/// A Remote Config template (client-style) returned by [RemoteConfig.getTemplate]
/// and friends.
class RemoteConfigTemplate {
  RemoteConfigTemplate({
    List<RemoteConfigCondition>? conditions,
    Map<String, RemoteConfigParameter>? parameters,
    Map<String, RemoteConfigParameterGroup>? parameterGroups,
    required this.etag,
    this.version,
  }) : conditions = List<RemoteConfigCondition>.unmodifiable(
         conditions ?? const <RemoteConfigCondition>[],
       ),
       parameters = Map<String, RemoteConfigParameter>.unmodifiable(
         parameters ?? const <String, RemoteConfigParameter>{},
       ),
       parameterGroups = Map<String, RemoteConfigParameterGroup>.unmodifiable(
         parameterGroups ?? const <String, RemoteConfigParameterGroup>{},
       );

  factory RemoteConfigTemplate.fromJson(Map<String, Object?> json) {
    final etag = json['etag'] as String?;
    if (etag == null || etag.isEmpty) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.invalidArgument,
        'Invalid Remote Config template: missing or empty etag.',
      );
    }
    final versionJson = json['version'];
    return RemoteConfigTemplate(
      conditions: switch (json['conditions']) {
        null => const <RemoteConfigCondition>[],
        final List<Object?> list => [
          for (final item in list)
            RemoteConfigCondition.fromJson(item as Map<String, Object?>),
        ],
        _ => throw FirebaseRemoteConfigException(
          RemoteConfigErrorCode.invalidArgument,
          'Remote Config conditions must be an array.',
        ),
      },
      parameters: _decodeMap(
        json['parameters'],
        RemoteConfigParameter.fromJson,
      ),
      parameterGroups: _decodeMap(
        json['parameterGroups'],
        RemoteConfigParameterGroup.fromJson,
      ),
      etag: etag,
      version: versionJson is Map<String, Object?>
          ? Version.fromJson(versionJson)
          : null,
    );
  }

  /// Conditions in priority (descending) order.
  final List<RemoteConfigCondition> conditions;

  /// Parameter map keyed by parameter name.
  final Map<String, RemoteConfigParameter> parameters;

  /// Parameter group map keyed by group name.
  final Map<String, RemoteConfigParameterGroup> parameterGroups;

  /// ETag of the current template (read-only).
  final String etag;

  /// Optional version metadata.
  final Version? version;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'conditions': [for (final c in conditions) c.toJson()],
      'parameters': _encodeMap(parameters, (p) => p.toJson()),
      'parameterGroups': _encodeMap(parameterGroups, (g) => g.toJson()),
      'etag': etag,
      'version': ?version?.toJson(),
    };
  }
}

/// A server-style template used by [ServerTemplate.evaluate]. Distinct from
/// [RemoteConfigTemplate] in that conditions are structured trees instead of
/// expression strings.
class ServerTemplateData {
  ServerTemplateData({
    List<NamedCondition>? conditions,
    Map<String, RemoteConfigParameter>? parameters,
    required this.etag,
    this.version,
  }) : conditions = List<NamedCondition>.unmodifiable(
         conditions ?? const <NamedCondition>[],
       ),
       parameters = Map<String, RemoteConfigParameter>.unmodifiable(
         parameters ?? const <String, RemoteConfigParameter>{},
       );

  factory ServerTemplateData.fromJson(Map<String, Object?> json) {
    final etag = json['etag'] as String?;
    if (etag == null || etag.isEmpty) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.invalidArgument,
        'Invalid Remote Config template: missing or empty etag.',
      );
    }
    final versionJson = json['version'];
    return ServerTemplateData(
      conditions: switch (json['conditions']) {
        null => const <NamedCondition>[],
        final List<Object?> list => [
          for (final item in list)
            NamedCondition.fromJson(item as Map<String, Object?>),
        ],
        _ => throw FirebaseRemoteConfigException(
          RemoteConfigErrorCode.invalidArgument,
          'Remote Config conditions must be an array.',
        ),
      },
      parameters: _decodeMap(
        json['parameters'],
        RemoteConfigParameter.fromJson,
      ),
      etag: etag,
      version: versionJson is Map<String, Object?>
          ? Version.fromJson(versionJson)
          : null,
    );
  }

  /// Conditions in priority (descending) order.
  final List<NamedCondition> conditions;

  /// Parameter map keyed by parameter name.
  final Map<String, RemoteConfigParameter> parameters;

  /// ETag of the current template (read-only).
  final String etag;

  /// Optional version metadata.
  final Version? version;
}

// ---------------------------------------------------------------------------
// Versions and listing
// ---------------------------------------------------------------------------

/// Origin of a Remote Config template update (output only).
const updateOriginUnspecified = 'REMOTE_CONFIG_UPDATE_ORIGIN_UNSPECIFIED';

/// Type of a Remote Config template update (output only).
const updateTypeUnspecified = 'REMOTE_CONFIG_UPDATE_TYPE_UNSPECIFIED';

/// Metadata about a published Remote Config template version.
class Version {
  const Version({
    this.versionNumber,
    this.updateTime,
    this.updateOrigin,
    this.updateType,
    this.updateUser,
    this.description,
    this.rollbackSource,
    this.isLegacy,
  });

  factory Version.fromJson(Map<String, Object?> json) {
    DateTime? parsedTime;
    final timeStr = json['updateTime'] as String?;
    if (timeStr != null && timeStr.isNotEmpty) {
      parsedTime = DateTime.tryParse(timeStr)?.toUtc();
    }
    final updateUserJson = json['updateUser'];
    return Version(
      versionNumber: json['versionNumber'] as String?,
      updateTime: parsedTime,
      updateOrigin: json['updateOrigin'] as String?,
      updateType: json['updateType'] as String?,
      updateUser: updateUserJson is Map<String, Object?>
          ? RemoteConfigUser.fromJson(updateUserJson)
          : null,
      description: json['description'] as String?,
      rollbackSource: json['rollbackSource'] as String?,
      isLegacy: json['isLegacy'] as bool?,
    );
  }

  /// Version number (int64 string). Output only.
  final String? versionNumber;

  /// When this version was written to the backend. Output only.
  final DateTime? updateTime;

  /// Source that triggered the update, as stamped by the Remote Config server
  /// (e.g. `CONSOLE`, `REST_API`, an `ADMIN_SDK_*` variant, or
  /// [updateOriginUnspecified]). The exact set of values is defined by the
  /// Remote Config service; clients should treat this as an opaque string.
  /// Output only.
  final String? updateOrigin;

  /// Update type — e.g. `INCREMENTAL_UPDATE`, `FORCED_UPDATE`, `ROLLBACK`,
  /// or [updateTypeUnspecified]. Output only.
  final String? updateType;

  /// Account that performed the update. Output only.
  final RemoteConfigUser? updateUser;

  /// User-provided description for this version. The only field on a Version
  /// that is settable on input — all other fields are output only and any
  /// values supplied at publish time are silently ignored by the server.
  final String? description;

  /// Version number this was rolled back from (int64 string). Output only;
  /// only present if this version is the result of a rollback.
  final String? rollbackSource;

  /// Whether this version was published before version history was supported.
  /// Output only.
  final bool? isLegacy;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'versionNumber': ?versionNumber,
      'updateTime': ?updateTime?.toUtc().toIso8601String(),
      'updateOrigin': ?updateOrigin,
      'updateType': ?updateType,
      'updateUser': ?updateUser?.toJson(),
      'description': ?description,
      'rollbackSource': ?rollbackSource,
      'isLegacy': ?isLegacy,
    };
  }
}

/// Options for [RemoteConfig.listVersions].
class ListVersionsOptions {
  ListVersionsOptions({
    this.pageSize,
    this.pageToken,
    this.endVersionNumber,
    this.startTime,
    this.endTime,
  }) {
    if (pageSize != null && (pageSize! < 1 || pageSize! > 300)) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.invalidArgument,
        'pageSize must be between 1 and 300 (inclusive), got $pageSize.',
      );
    }
  }

  /// Max items per page (1–300).
  final int? pageSize;

  /// Continuation token from a previous list versions response.
  final String? pageToken;

  /// Newest version number to include (int64 string).
  final String? endVersionNumber;

  /// Earliest update time to include.
  final DateTime? startTime;

  /// Latest update time to include (entries on or after this are omitted).
  final DateTime? endTime;
}

/// A page of [Version] metadata.
class ListVersionsResult {
  ListVersionsResult({List<Version>? versions, this.nextPageToken})
    : versions = List<Version>.unmodifiable(versions ?? const <Version>[]);

  factory ListVersionsResult.fromJson(Map<String, Object?> json) {
    return ListVersionsResult(
      versions: switch (json['versions']) {
        null => const <Version>[],
        final List<Object?> list => [
          for (final item in list)
            Version.fromJson(item as Map<String, Object?>),
        ],
        _ => const <Version>[],
      },
      nextPageToken: json['nextPageToken'] as String?,
    );
  }

  /// Versions in reverse chronological order.
  final List<Version> versions;

  /// Token for the next page, or null if no more pages.
  final String? nextPageToken;
}

// ---------------------------------------------------------------------------
// Server-side evaluation
// ---------------------------------------------------------------------------

/// Inputs to [ServerTemplate.evaluate].
class EvaluationContext {
  /// Builds an evaluation context. [customSignals] values must be `String` or
  /// `num`; other types are rejected by the operator implementations.
  const EvaluationContext({
    this.randomizationId,
    this.customSignals = const {},
  });

  /// Identifier used by [PercentCondition] to bucket users deterministically.
  final String? randomizationId;

  /// Developer-defined signals keyed by signal name. Values are `String` or
  /// `num`.
  final Map<String, Object> customSignals;
}

/// Configuration produced by [ServerTemplate.evaluate].
class ServerConfig {
  /// Internal: build a [ServerConfig] from an evaluated value map.
  @internal
  ServerConfig.internal(Map<String, Value> values)
    : _configValues = Map<String, Value>.unmodifiable(values);

  final Map<String, Value> _configValues;

  /// Returns the value for [key] as a boolean.
  bool getBoolean(String key) => getValue(key).asBoolean();

  /// Returns the value for [key] as an int.
  ///
  /// Returns `0` if the value cannot be parsed as an integer.
  int getInt(String key) => getValue(key).asInt();

  /// Returns the value for [key] as a double.
  ///
  /// Returns `0.0` if the value cannot be parsed as a double.
  double getDouble(String key) => getValue(key).asDouble();

  /// Returns the value for [key] as a string.
  String getString(String key) => getValue(key).asString();

  /// Returns the [Value] for [key], or a static default if unknown.
  Value getValue(String key) {
    return _configValues[key] ?? const Value._(ValueSource.valueStatic, '');
  }

  /// Returns a copy of every config value.
  Map<String, Value> getAll() => Map<String, Value>.from(_configValues);
}

/// Wraps a Remote Config parameter value with type-safe getters.
class Value {
  const Value._(this._source, [this._value = '']);

  /// Internal: builds a [Value] from a raw string and source.
  @internal
  factory Value.internal(ValueSource source, [String value = '']) {
    return Value._(source, value);
  }

  static const _truthy = {'1', 'true', 't', 'yes', 'y', 'on'};

  final ValueSource _source;
  final String _value;

  /// Returns the raw string value.
  String asString() => _value;

  /// Returns the value as a boolean.
  ///
  /// Truthy strings (case-insensitive): `1`, `true`, `t`, `yes`, `y`, `on`.
  /// Static-source values always return `false`.
  bool asBoolean() {
    if (_source == ValueSource.valueStatic) return false;
    return _truthy.contains(_value.toLowerCase());
  }

  /// Returns the value as an int.
  ///
  /// Static-source values always return `0`. Strings that don't parse as an
  /// integer (including float strings like `"3.14"`) return `0` — use
  /// [asDouble] for those.
  int asInt() {
    if (_source == ValueSource.valueStatic) return 0;
    return int.tryParse(_value) ?? 0;
  }

  /// Returns the value as a double.
  ///
  /// Static-source values always return `0.0`. Unparsable strings return `0.0`.
  double asDouble() {
    if (_source == ValueSource.valueStatic) return 0;
    return double.tryParse(_value) ?? 0;
  }

  /// Returns the source of this value.
  ValueSource getSource() => _source;
}

/// Options for [RemoteConfig.getServerTemplate].
class GetServerTemplateOptions {
  GetServerTemplateOptions({Map<String, Object>? defaultConfig})
    : defaultConfig = defaultConfig == null
          ? null
          : Map<String, Object>.unmodifiable(defaultConfig);

  /// Default config values used by [ServerConfig] for keys not defined in the
  /// evaluated template. Values must be `String`, `num`, or `bool`.
  final Map<String, Object>? defaultConfig;
}

/// Options for [RemoteConfig.initServerTemplate].
class InitServerTemplateOptions extends GetServerTemplateOptions {
  InitServerTemplateOptions({super.defaultConfig, this.template});

  /// Optional pre-loaded template — either a [ServerTemplateData] instance or
  /// a JSON string in [ServerTemplateData] shape.
  final Object? template;
}
