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

/// Compares the signatures of the Dart Pipelines API with the Node.js SDK's.
///
/// The Node API is read from `test/fixtures/node_pipeline_api.json`, which
/// `tool/pipeline_api_parity` extracts from the pinned
/// `@google-cloud/firestore` typings. The Dart API is read with
/// `package:analyzer` from what `lib/google_cloud_firestore.dart` exports.
///
/// How Node maps onto Dart:
///
/// * A Node top-level function `x` is `PipelineFunctions.x`, a top-level `x`
///   from `lib/src/pipeline*.dart`, or `Expression.x`. Every one of those that
///   exists is compared.
/// * A Node class maps onto the Dart type in [_classes]; its methods and
///   properties are looked up on that type, inherited members included.
/// * A Node options object (`CollectionStageOptions`, ...) maps onto Dart
///   named parameters; a stage's required keys may instead be positional.
/// * A Node string union maps onto the `value`s of a Dart enum ([_enums]).
///
/// Signatures are compared on shape, not on exact types: argument counts,
/// which positions are optional, whether a parameter takes a single value or
/// a list, and whether Dart's type accepts each kind of value Node does (an
/// expression, a string, a number, ...). A Node rest parameter matches a
/// trailing Dart `Iterable`, either in its own position or folding the
/// arguments before it, as in `and(Iterable<PipelineBooleanExpression>)` for
/// Node's `and(first, second, ...more)`.
///
/// Every difference is reported as `id: message`, one per line. An `id` is
/// the Dart member (`PipelineFunctions.join`, `Pipeline.where`, `field` for a
/// top-level function) optionally followed by `#` and what differs: `#arity`,
/// a Dart parameter name, a Node option key, or `#returns`. Entries in
/// [_knownDifferences] and [_pendingFixes] are keyed by a full `id`, or by a
/// bare member to cover all of its differences. Stale entries fail the test.
@TestOn('vm')
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:test/test.dart';

/// The Node SDK version the snapshot must come from.
const _nodeVersion = '9.3.1';

/// Node member names that Dart spells differently, keyed by
/// `NodeOwner.member` (a class, `Transaction`, or an options type).
const _renames = <String, String>{
  // Named after Dart's String.toLowerCase()/toUpperCase().
  'Expression.toLower': 'toLowerCase',
  'Expression.toUpper': 'toUpperCase',
  'Field.fieldName': 'path',
  'PipelineResult.isEqual': '==',
  // Dart decodes the protobuf Any into a map; Node returns it as is.
  'ExplainStats.rawData': 'raw',
  'Transaction.execute': 'executePipeline',
  'PipelineExecuteOptions.explainOptions': 'explain',
  // Named like the VectorQueryOptions they are built from.
  'FindNearestStageOptions.field': 'vectorField',
  'FindNearestStageOptions.vectorValue': 'queryVector',
  'FindNearestStageOptions.distanceField': 'distanceResultField',
};

/// The Dart type standing for each Node class or interface.
const _classes = <String, String>{
  'Expression': 'PipelineExpression',
  // Node's implementation classes; Dart keeps them private and builds them
  // with constant() and pipelineFunction(). Their constructors are not
  // compared.
  'Constant': 'PipelineExpression',
  'FunctionExpression': 'PipelineExpression',
  'AggregateFunction': 'PipelineAggregateFunction',
  'BooleanExpression': 'PipelineBooleanExpression',
  'Field': 'PipelineField',
  'AliasedExpression': 'PipelineAliasedExpression',
  // Dart aliases aggregates like any other expression.
  'AliasedAggregate': 'PipelineAliasedExpression',
  'Selectable': 'Selectable',
  'Ordering': 'PipelineOrdering',
  'Pipeline': 'Pipeline',
  'PipelineSource': 'PipelineSource',
  'PipelineResult': 'PipelineResult',
  'PipelineSnapshot': 'PipelineSnapshot',
  'ExplainStats': 'ExplainStats',
};

/// The Dart enum standing for each Node string union, compared by `value`.
const _enums = <String, String>{'Type': 'PipelineValueType'};

/// Dart types that Node models as option objects or inline string unions,
/// and where. They are compared through the named parameters that use them.
const _optionTypes = <String, String>{
  'PipelineExplainOptions': 'PipelineExecuteOptions.explainOptions',
  'PipelineExplainMode': 'PipelineExecuteOptions.explainOptions.mode',
  'PipelineExplainOutputFormat':
      'PipelineExecuteOptions.explainOptions.outputFormat',
  'PipelineIndexMode': 'PipelineExecuteOptions.indexMode',
};

/// Dart classes whose static methods stand for Node's top-level functions.
const _functionNamespaces = {'PipelineFunctions', 'Expression'};

/// Node properties that only exist for TypeScript runtime type tests, such as
/// `expr.expressionType === 'Field'` or `'selectable' in value`. Dart uses its
/// type system (sealed classes and `is`) instead.
const _nodeTypeTags = {'expressionType', 'selectable'};

/// Public Dart members with no Node counterpart, and why.
///
/// `xLiteral` variants of an existing `x` are allowed without an entry; their
/// arity is still compared with Node's `x`.
const _dartOnly = <String, String>{
  'Expression.raw':
      'Escape hatch for backend functions this SDK does not wrap.',
  'Expression.vector': 'Shorthand for constant(FieldValue.vector(...)).',
  'PipelineFunctions.raw': 'Escape hatch, same as pipelineFunction().',
  'PipelineFunctions.maximumN':
      'Named after the backend maximum_n function; same as arrayMaximumN.',
  'PipelineFunctions.minimumN':
      'Named after the backend minimum_n function; same as arrayMinimumN.',
  'pipelineFunction':
      'Escape hatch for backend functions this SDK does not wrap; Node only '
      'offers `new FunctionExpression(name, params)`.',
  'PipelineExpression.arrayConcatMultiple':
      "Dart's arrayConcat takes one array; this is Node's variadic form.",
  'PipelineExpression.arrayContainsAllFrom':
      'Node overloads arrayContainsAll(values | arrayExpression); Dart splits '
      'off the expression form.',
  'PipelineExpression.geoDistance':
      'Node only offers geoDistance on Field; Dart allows any geo point '
      'expression.',
  'PipelineAliasedExpression.expression':
      'Node exposes it as the underscored _expr.',
  'PipelineAliasedExpression.name':
      'Node exposes it as the underscored _alias.',
  'Pipeline.firestore': 'Node keeps the Firestore instance private.',
  'PipelineResult.name':
      'The document name as returned by the backend; Node only exposes ref.',
  'PipelineSnapshot.empty': 'Mirrors QuerySnapshot.empty.',
  'PipelineSnapshot.size': 'Mirrors QuerySnapshot.size.',
  'ExplainStats.typeName': 'Node exposes it as rawData.type_url.',
};

/// Intentional differences, keyed by mismatch id or bare member.
const _knownDifferences = <String, String>{
  'PipelineFunctions.count#arity':
      'count() with no argument counts every input, like countAll(); Node '
      'requires an argument.',
  'PipelineExpression.arrayConcat#arity':
      'Takes a single array; the variadic form is arrayConcatMultiple.',
  'PipelineSource.collection#collectionPath':
      'Takes a path; a CollectionReference goes to collectionReference(), '
      'since Dart has no overloads.',
  'PipelineSource.collectionReference':
      'The CollectionReference form of Node collection().',
  'Pipeline.addFields#fields':
      'Only aliased expressions: adding a bare field to itself is a no-op.',
  'Pipeline.search':
      'The search stage is still evolving; Dart passes a raw option map '
      'through instead of typing SearchStageOptions.',
  'Pipeline.rawStage#options':
      "Node's rawStage(name, params, options) takes options at runtime, but "
      'its typings omit them.',
  'Pipeline.execute#readTime':
      'Reads at a past time (ExecutePipelineRequest.read_time); Node only '
      'passes a read time internally.',
  'Transaction.executePipeline':
      'Takes the same execute options as Pipeline.execute; Node takes none.',
  'PipelineValueType#request_timestamp':
      "The backend's is_type rejects it: its list of accepted types does not "
      "include 'request_timestamp'.",
  'type:ExpressionType': 'The values of the expressionType type tag.',
  'type:TimeGranularity': 'Dart takes these as plain strings (Object?).',
  'type:TimePart': 'Dart takes these as plain strings (Object?).',
  'type:TimeUnit': 'Dart takes these as plain strings (Object?).',
};

/// Differences that look like Dart bugs or gaps, to be fixed in `lib/`.
///
/// Remove an entry once its fix lands; the test fails while it is stale.
const _pendingFixes = <String, String>{
  // Signatures.
  'PipelineFunctions.add#arity':
      'Node add(first, second, ...others) is variadic; Dart add(left, right) '
      'takes exactly two.',
  'PipelineFunctions.multiply#arity':
      'Node multiply(first, second, ...others) is variadic; Dart takes two.',
  'PipelineExpression.add#arity':
      'Node add(second, ...others) is variadic; Dart add(other) takes one.',
  'PipelineExpression.multiply#arity':
      'Node multiply(second, ...others) is variadic; Dart takes one.',
  'PipelineFunctions.map#keyValues':
      'Takes an Iterable of alternating keys and values; Node '
      'map(elements: Record<string, unknown>) takes a map, which Dart '
      'callers cannot pass.',
  'PipelineSource.documents#documents':
      'Only takes DocumentReferences; Node documents() also takes document '
      'path strings.',
  'Pipeline.findNearest#distanceThreshold':
      'Dart-only option, sent as `distance_threshold`: Node has no such '
      'find_nearest option and its createFrom(vectorQuery) drops '
      'distanceThreshold. Confirm the backend accepts it.',
  // Options.
  'PipelineSource.collection#forceIndex':
      'Node collection({collection, forceIndex}) can force an index; Dart '
      'cannot.',
  'PipelineSource.collectionGroup#forceIndex':
      'Node collectionGroup({collectionId, forceIndex}) can force an index; '
      'Dart cannot.',
  // Dart-only functions with no Node counterpart.
  'PipelineFunctions.log':
      'Node has no log function; check the backend supports `log`, or drop.',
  'PipelineExpression.log':
      'Node has no log method; check the backend supports `log`, or drop.',
  'PipelineFunctions.cmp':
      'Node has no cmp function; check the backend supports `cmp`, or drop.',
  'PipelineFunctions.referenceSlice':
      'Node has no referenceSlice; check the backend supports '
      '`reference_slice`, or drop.',
  'PipelineExpression.referenceSlice':
      'Node has no referenceSlice; check the backend supports '
      '`reference_slice`, or drop.',
  // Node APIs Dart does not implement yet.
  'PipelineFunctions.subcollection':
      'Missing: Node subcollection(path | options) starts a subcollection '
      'Pipeline for use inside another stage.',
  'Pipeline.define': 'Missing stage: Node define(...aliasedExpressions).',
  'Pipeline.delete': 'Missing stage: Node delete().',
  'Pipeline.update': 'Missing stage: Node update(transformedFields?).',
  'Pipeline.toArrayExpression':
      'Missing: Node turns a Pipeline into an array subquery expression.',
  'Pipeline.toScalarExpression':
      'Missing: Node turns a Pipeline into a scalar subquery expression.',
  'Pipeline.stream': 'Missing: Node streams results; Dart only has execute().',
  'PipelineOrdering.expr':
      'Missing getter: Node Ordering exposes its expression.',
  'PipelineOrdering.direction':
      "Missing getter: Node Ordering exposes 'ascending' | 'descending'.",
};

void main() {
  late _Report report;

  setUpAll(() async {
    final node = _NodeApi.load(
      File('test/fixtures/node_pipeline_api.json').readAsStringSync(),
    );
    final dart = await _DartApi.load(Directory.current.path);
    report = _Checker(node, dart).run();
  });

  test('the snapshot comes from the pinned Node SDK', () {
    expect(report.node.formatVersion, 1);
    expect(report.node.version, _nodeVersion);
  });

  test('the Dart Pipeline API matches the Node SDK signatures', () {
    final unexplained = [
      for (final mismatch in report.mismatches)
        if (report.coveringKey(mismatch) == null) mismatch,
    ];
    if (unexplained.isNotEmpty) {
      fail(
        '${unexplained.length} difference(s) from the Node SDK '
        '$_nodeVersion. Fix the Dart API, or record the difference in '
        '_knownDifferences (intentional) or _pendingFixes (to fix):\n'
        '${unexplained.join('\n')}',
      );
    }
  });

  test('the parity tables have no stale entries', () {
    final problems = [
      ...report.problems,
      for (final key in _knownDifferences.keys)
        if (_pendingFixes.containsKey(key))
          '$key: in both _knownDifferences and _pendingFixes',
      for (final MapEntry(key: name, value: entries) in {
        '_knownDifferences': _knownDifferences,
        '_pendingFixes': _pendingFixes,
      }.entries)
        for (final key in entries.keys)
          if (!report.mismatches.any((m) => m.matches(key)))
            '$key: stale $name entry, the difference is gone',
      for (final key in _dartOnly.keys)
        if (!report.dartOnlyUsed.contains(key))
          '$key: stale _dartOnly entry, Node has it or Dart no longer does',
      for (final key in _renames.keys)
        if (!report.renamesUsed.contains(key))
          '$key: stale _renames entry, Node or Dart no longer has it',
    ];
    if (problems.isNotEmpty) fail(problems.join('\n'));
  });
}

// --- Node API ----------------------------------------------------------------

final class _NodeType {
  _NodeType.fromJson(Map<String, Object?> json)
    : kinds = _strings(json['kinds']),
      literals = _strings(json['literals']),
      aliases = _strings(json['aliases']),
      options = _strings(json['options']),
      elements = json['elements'] == null
          ? null
          : _NodeType.fromJson(json['elements']! as Map<String, Object?>),
      properties = {
        for (final MapEntry(:key, :value)
            in ((json['properties'] as Map<String, Object?>?) ?? {}).entries)
          key: _NodeProperty.fromJson(value! as Map<String, Object?>),
      };

  _NodeType.union(Iterable<_NodeType> types)
    : kinds = {for (final type in types) ...type.kinds},
      literals = {for (final type in types) ...type.literals},
      aliases = {for (final type in types) ...type.aliases},
      options = {for (final type in types) ...type.options},
      elements = _unionOrNull([for (final type in types) ?type.elements]),
      properties = const {};

  static _NodeType? _unionOrNull(List<_NodeType> types) {
    return types.isEmpty ? null : _NodeType.union(types);
  }

  final Set<String> kinds;
  final Set<String> literals;
  final Set<String> aliases;
  final Set<String> options;
  final _NodeType? elements;
  final Map<String, _NodeProperty> properties;

  String get label {
    final sorted = kinds.toList()..sort();
    return sorted.join('|');
  }
}

final class _NodeProperty {
  _NodeProperty.fromJson(Map<String, Object?> json)
    : optional = json['optional'] == true,
      type = _NodeType.fromJson(json);

  final bool optional;
  final _NodeType type;
}

final class _NodeParam {
  _NodeParam.fromJson(Map<String, Object?> json)
    : name = json['name']! as String,
      optional = json['optional'] == true,
      rest = json['rest'] == true,
      // Runtime-only members have no types: anything goes.
      type = json.containsKey('kinds')
          ? _NodeType.fromJson(json)
          : _NodeType.fromJson(const {
              'kinds': ['any'],
            });

  final String name;
  final bool optional;
  final bool rest;
  final _NodeType type;

  bool get required => !optional && !rest;

  bool get isOptions =>
      type.kinds.length == 1 && type.kinds.single == 'options';
}

final class _NodeSignature {
  _NodeSignature.fromJson(Map<String, Object?> json)
    : params = [
        for (final param in json['params']! as List)
          _NodeParam.fromJson(param as Map<String, Object?>),
      ],
      returns = json['returns'] == null
          ? null
          : _NodeType.fromJson(json['returns']! as Map<String, Object?>);

  final List<_NodeParam> params;
  final _NodeType? returns;
}

final class _NodeMember {
  _NodeMember({
    required this.owner,
    required this.name,
    required this.isMethod,
    required this.overloads,
  }) : runtimeOnly = false;

  /// A member only the JavaScript implementation has, without types.
  _NodeMember.runtimeOnly({
    required this.owner,
    required this.name,
    required Map<String, Object?> json,
  }) : isMethod = json['kind'] != 'getter',
       overloads = [
         if (json['kind'] != 'getter') _NodeSignature.fromJson(json),
       ],
       runtimeOnly = true;

  final String owner;
  final String name;
  final bool isMethod;
  final List<_NodeSignature> overloads;

  /// Whether only the JavaScript implementation has this member: the typings
  /// omit it, so it is not part of the contract and has no types.
  final bool runtimeOnly;
}

final class _NodeClass {
  _NodeClass(this.name, Map<String, Object?> json, Map<String, Object?>? js)
    : superclass = json['extends'] as String?,
      interfaces = _strings(json['implements']),
      members = {
        for (final MapEntry(:key, :value)
            in (json['methods']! as Map<String, Object?>).entries)
          key: _NodeMember(
            owner: name,
            name: key,
            isMethod: true,
            overloads: _signatures(value),
          ),
        for (final key in (json['properties']! as Map<String, Object?>).keys)
          key: _NodeMember(
            owner: name,
            name: key,
            isMethod: false,
            overloads: const [],
          ),
        for (final MapEntry(:key, :value) in (js ?? {}).entries)
          key: _NodeMember.runtimeOnly(
            owner: name,
            name: key,
            json: value! as Map<String, Object?>,
          ),
      };

  final String name;
  final String? superclass;
  final Set<String> interfaces;
  final Map<String, _NodeMember> members;
}

final class _NodeApi {
  _NodeApi._(this._json);

  factory _NodeApi.load(String source) {
    return _NodeApi._(jsonDecode(source) as Map<String, Object?>);
  }

  final Map<String, Object?> _json;

  int get formatVersion => _json['formatVersion']! as int;

  String get version => (_json['source']! as Map)['version']! as String;

  late final Map<String, _NodeMember> functions = {
    for (final MapEntry(:key, :value)
        in (_json['functions']! as Map<String, Object?>).entries)
      key: _NodeMember(
        owner: '',
        name: key,
        isMethod: true,
        overloads: _signatures(value),
      ),
    for (final MapEntry(:key, :value)
        in (_json['runtimeOnlyFunctions']! as Map<String, Object?>).entries)
      key: _NodeMember.runtimeOnly(
        owner: '',
        name: key,
        json: value! as Map<String, Object?>,
      ),
  };

  late final Map<String, _NodeClass> classes = () {
    final js = _json['runtimeOnlyMembers']! as Map<String, Object?>;
    return {
      for (final section in ['classes', 'interfaces'])
        for (final MapEntry(:key, :value)
            in (_json[section]! as Map<String, Object?>).entries)
          key: _NodeClass(
            key,
            value! as Map<String, Object?>,
            js[key] as Map<String, Object?>?,
          ),
    };
  }();

  late final Map<String, Map<String, Object?>> types = {
    for (final MapEntry(:key, :value)
        in (_json['types']! as Map<String, Object?>).entries)
      key: value! as Map<String, Object?>,
  };

  /// The pipeline entry points declared outside the namespace, by owner.
  late final Map<String, Map<String, _NodeMember>> entryPoints = () {
    final result = <String, Map<String, _NodeMember>>{};
    for (final MapEntry(:key, :value)
        in (_json['entryPoints']! as Map<String, Object?>).entries) {
      final [owner, name] = key.split('.');
      (result[owner] ??= {})[name] = _NodeMember(
        owner: owner,
        name: name,
        isMethod: true,
        overloads: _signatures(value),
      );
    }
    return result;
  }();

  /// A member of [className] or of the classes it extends or implements.
  _NodeMember? lookUp(String className, String member) {
    final cls = classes[className];
    if (cls == null) return null;
    return cls.members[member] ??
        [
          ?cls.superclass,
          ...cls.interfaces,
        ].map((name) => lookUp(name, member)).nonNulls.firstOrNull;
  }

  /// The string values of a literal [type], resolving named unions.
  Set<String> literalValues(_NodeType type) {
    return {
      ...type.literals,
      for (final alias in type.aliases) ..._strings(types[alias]?['values']),
    };
  }

  /// The properties of the options object [name], without its base types.
  Map<String, _NodeProperty> optionProperties(String name) {
    return _NodeType.fromJson({
      'kinds': const ['options'],
      'properties': types[name]!['properties'],
    }).properties;
  }

  Set<String> optionBases(String name) => _strings(types[name]!['extends']);
}

Set<String> _strings(Object? json) => {...?(json as List?)?.cast<String>()};

List<_NodeSignature> _signatures(Object? json) {
  return [
    for (final overload in (json! as Map)['overloads']! as List)
      _NodeSignature.fromJson(overload as Map<String, Object?>),
  ];
}

// --- Dart API ----------------------------------------------------------------

final class _DartApi {
  _DartApi._(this.barrel, this.typedData, this.core);

  static Future<_DartApi> load(String packageRoot) async {
    final collection = AnalysisContextCollection(includedPaths: [packageRoot]);
    final session = collection.contextFor(packageRoot).currentSession;
    Future<LibraryElement> library(String uri) async {
      final result = await session.getLibraryByUri(uri);
      if (result is! LibraryElementResult) {
        throw StateError('Could not resolve $uri: $result');
      }
      return result.element;
    }

    return _DartApi._(
      await library(
        'package:google_cloud_firestore/google_cloud_firestore.dart',
      ),
      await library('dart:typed_data'),
      await library('dart:core'),
    );
  }

  final LibraryElement barrel;
  final LibraryElement typedData;
  final LibraryElement core;

  TypeSystem get typeSystem => barrel.typeSystem;

  TypeProvider get typeProvider => barrel.typeProvider;

  late final Map<String, Element> exports =
      barrel.exportNamespace.definedNames2;

  /// The class an exported name stands for, looking through typedefs.
  InterfaceElement? interfaceNamed(String name) {
    return switch (exports[name]) {
      final InterfaceElement element => element,
      final TypeAliasElement alias => switch (alias.aliasedType) {
        final InterfaceType type => type.element,
        _ => null,
      },
      _ => null,
    };
  }

  /// [element]'s type with its type parameters at their bounds.
  InterfaceType instantiate(InterfaceElement element) {
    return typeSystem.instantiateInterfaceToBounds(
      element: element,
      nullabilitySuffix: NullabilitySuffix.none,
    );
  }

  InterfaceType exportedType(String name) {
    final element = interfaceNamed(name);
    if (element == null) throw StateError('$name is not exported.');
    return instantiate(element);
  }

  InterfaceType libraryType(LibraryElement library, String name) {
    return instantiate(
      library.exportNamespace.definedNames2[name]! as InterfaceElement,
    );
  }

  /// The library declaring the Pipeline API (`lib/src/firestore.dart`).
  late final LibraryElement implementation = interfaceNamed(
    'PipelineFunctions',
  )!.library;

  /// Whether [element] is declared in a `lib/src/pipeline*.dart` file.
  bool isPipelineDeclaration(Element element) {
    final path = element.firstFragment.libraryFragment?.source.fullName ?? '';
    return RegExp(
          r'[/\\]lib[/\\]src[/\\]pipeline[^/\\]*\.dart$',
        ).hasMatch(path) ||
        RegExp(r'[/\\]lib[/\\]src[/\\]pipeline[/\\]').hasMatch(path);
  }

  /// Every public top-level declaration of the Pipeline API files.
  late final List<Element> pipelineDeclarations = [
    for (final element in <Element>[
      ...implementation.classes,
      ...implementation.enums,
      ...implementation.mixins,
      ...implementation.extensions,
      ...implementation.extensionTypes,
      ...implementation.typeAliases,
      ...implementation.topLevelFunctions,
      ...implementation.topLevelVariables,
    ])
      if (element.isPublic && isPipelineDeclaration(element)) element,
  ];

  late final Map<String, TopLevelFunctionElement> topLevelFunctions = {
    for (final element
        in pipelineDeclarations.whereType<TopLevelFunctionElement>())
      element.name!: element,
  };

  /// Public instance members of [element], inherited ones included unless
  /// [declaredOnly].
  Map<String, ExecutableElement> members(
    InterfaceElement element, {
    bool declaredOnly = false,
  }) {
    final result = <String, ExecutableElement>{};
    final chain = [
      element,
      if (!declaredOnly)
        for (final type in element.allSupertypes)
          if (!type.isDartCoreObject) type.element,
    ];
    for (final cls in chain) {
      for (final member in <ExecutableElement>[
        ...cls.methods,
        ...cls.getters,
      ]) {
        final name = member.name;
        if (name == null || member.isStatic || name.startsWith('_')) continue;
        result.putIfAbsent(name, () => member);
      }
    }
    return result;
  }

  Map<String, MethodElement> statics(InterfaceElement element) {
    return {
      for (final method in element.methods)
        if (method.isStatic && method.isPublic) method.name!: method,
    };
  }

  /// The `value` of each constant of [element], an enum.
  Set<String> enumValues(EnumElement element) {
    return {
      for (final constant in element.constants)
        ?constant.computeConstantValue()?.getField('value')?.toStringValue(),
    };
  }
}

final class _DartCallable {
  _DartCallable(this.id, this.element);

  final String id;
  final ExecutableElement element;

  bool get isGetter => element is GetterElement;

  List<FormalParameterElement> get positional => [
    for (final param in element.formalParameters)
      if (!param.isNamed) param,
  ];

  Map<String, FormalParameterElement> get named => {
    for (final param in element.formalParameters)
      if (param.isNamed) param.name!: param,
  };

  int get requiredPositional =>
      positional.where((param) => param.isRequiredPositional).length;

  String render() {
    final positional = this.positional;
    final required = [
      for (final param in positional)
        if (param.isRequiredPositional) _renderParam(param),
    ];
    final optional = [
      for (final param in positional)
        if (param.isOptionalPositional) _renderParam(param),
    ];
    final named = [
      for (final param in this.named.values)
        '${param.isRequiredNamed ? 'required ' : ''}${_renderParam(param)}',
    ];
    final parts = [
      ...required,
      if (optional.isNotEmpty) '[${optional.join(', ')}]',
      if (named.isNotEmpty) '{${named.join(', ')}}',
    ];
    return '${element.name}(${parts.join(', ')})';
  }

  static String _renderParam(FormalParameterElement param) {
    return '${param.type.getDisplayString()} ${param.name}';
  }
}

// --- Comparison --------------------------------------------------------------

final class _Mismatch {
  _Mismatch(this.id, this.message);

  final String id;
  final String message;

  String get member => id.split('#').first;

  bool matches(String key) => key == id || key == member;

  @override
  String toString() => '$id: $message';
}

final class _Report {
  _Report(this.node);

  final _NodeApi node;
  final List<_Mismatch> mismatches = [];

  /// Problems with the tables themselves, such as unknown names.
  final List<String> problems = [];
  final Set<String> dartOnlyUsed = {};
  final Set<String> renamesUsed = {};

  String? coveringKey(_Mismatch mismatch) {
    for (final table in [_knownDifferences, _pendingFixes]) {
      if (table.containsKey(mismatch.id)) return mismatch.id;
      if (table.containsKey(mismatch.member)) return mismatch.member;
    }
    return null;
  }
}

/// Signature style of a callable, which decides what may differ.
enum _Style {
  /// Functions and expression methods.
  plain,

  /// Pipeline stages: options objects map onto named parameters.
  stage,

  /// `xLiteral` conveniences: only the arity is compared.
  literal,
}

final class _Checker {
  _Checker(this.node, this.dart) : report = _Report(node);

  final _NodeApi node;
  final _DartApi dart;
  final _Report report;

  /// For each base option key (`StageOptions.rawOptions`), the stages that
  /// lack it in Dart, and how many stages Node offers it on.
  final Map<String, List<String>> _missingBaseKeys = {};
  final Map<String, int> _baseKeyStages = {};

  void _mismatch(String id, String message) {
    report.mismatches.add(_Mismatch(id, message));
  }

  String _rename(String nodeOwner, String name) {
    final key = '$nodeOwner.$name';
    final renamed = _renames[key];
    if (renamed == null) return name;
    report.renamesUsed.add(key);
    return renamed;
  }

  /// The Dart-only check: allowed when listed in [_dartOnly].
  void _dartOnlyMember(String id, String message) {
    if (_dartOnly.containsKey(id)) {
      report.dartOnlyUsed.add(id);
      return;
    }
    _mismatch(id, message);
  }

  _Report run() {
    _checkFunctions();
    _checkClasses();
    _checkEntryPoints();
    _checkEnums();
    _checkTypes();
    _checkExports();
    for (final MapEntry(key: key, value: missing) in _missingBaseKeys.entries) {
      if (missing.isEmpty) continue;
      _mismatch(
        'StageOptions#$key',
        'Node accepts `$key` on every stage; Dart lacks it on '
            '${missing.length} of the ${_baseKeyStages[key]} stages it has: '
            '${missing.join(', ')}',
      );
    }
    return report;
  }

  // Top-level functions.

  void _checkFunctions() {
    final namespaces = <String, Map<String, MethodElement>>{};
    for (final name in _functionNamespaces) {
      final element = dart.interfaceNamed(name);
      if (element == null) {
        report.problems.add('_functionNamespaces: Dart exports no $name');
      } else {
        namespaces[name] = dart.statics(element);
      }
    }

    for (final function in node.functions.values) {
      final candidates = [
        if (dart.topLevelFunctions[function.name] case final element?)
          _DartCallable(function.name, element),
        for (final MapEntry(key: owner, value: statics) in namespaces.entries)
          if (statics[function.name] case final element?)
            _DartCallable('$owner.${function.name}', element),
      ];
      if (candidates.isEmpty) {
        if (!function.runtimeOnly) {
          _mismatch(
            'PipelineFunctions.${function.name}',
            'missing in Dart: Node exports '
                '${_renderNode(function.name, function.overloads)}',
          );
        }
        continue;
      }
      for (final candidate in candidates) {
        _compare(function, candidate, _Style.plain);
      }
    }

    for (final MapEntry(key: owner, value: statics) in namespaces.entries) {
      for (final name in statics.keys) {
        if (!node.functions.containsKey(name)) {
          _dartOnlyMember(
            '$owner.$name',
            'Dart-only: Node has no top-level function `$name`',
          );
        }
      }
    }
    for (final name in dart.topLevelFunctions.keys) {
      if (!node.functions.containsKey(name)) {
        _dartOnlyMember(name, 'Dart-only: Node has no function `$name`');
      }
    }
  }

  // Classes.

  void _checkClasses() {
    final nodeClassesByDart = <String, List<String>>{};
    for (final MapEntry(key: nodeName, value: dartName) in _classes.entries) {
      final nodeClass = node.classes[nodeName];
      final dartClass = dart.interfaceNamed(dartName);
      if (nodeClass == null) {
        report.problems.add('_classes: Node has no $nodeName');
        continue;
      }
      if (dartClass == null) {
        _mismatch(
          'export:$dartName',
          'Node exports $nodeName, but its Dart counterpart $dartName is not '
              'exported from lib/google_cloud_firestore.dart',
        );
        continue;
      }
      final dartLabel = dartClass.name!;
      (nodeClassesByDart[dartLabel] ??= []).add(nodeName);
      final dartMembers = dart.members(dartClass);

      for (final member in nodeClass.members.values) {
        // Runtime-only members are not part of the typed contract; they only
        // count as Node having the Dart member.
        if (member.runtimeOnly) continue;
        if (_nodeTypeTags.contains(member.name)) continue;
        final dartName = _rename(nodeName, member.name);
        final id = '$dartLabel.$dartName';
        final element = dartMembers[dartName];
        if (element == null) {
          _mismatch(
            id,
            'missing in Dart: Node $nodeName.'
            '${member.isMethod ? _renderNode(member.name, member.overloads) : member.name}',
          );
          continue;
        }
        _compareMember(member, _DartCallable(id, element));
      }
    }

    // Dart members must exist on one of the Node classes they stand for.
    for (final MapEntry(key: dartName, value: nodeNames)
        in nodeClassesByDart.entries) {
      final dartClass = dart.interfaceNamed(dartName)!;
      final reverseRenames = {
        for (final nodeName in nodeNames)
          for (final MapEntry(:key, :value) in _renames.entries)
            if (key.startsWith('$nodeName.')) value: key.split('.').last,
      };
      final declared = dart.members(dartClass, declaredOnly: true);
      for (final MapEntry(key: name, value: element) in declared.entries) {
        if (const {
          'hashCode',
          'toString',
          'noSuchMethod',
          'runtimeType',
        }.contains(name)) {
          continue;
        }
        final nodeName = reverseRenames[name] ?? name;
        if (nodeName == '==' && !reverseRenames.containsKey('==')) continue;
        if (nodeNames.any((cls) => node.lookUp(cls, nodeName) != null)) {
          continue;
        }
        final id = '$dartName.$name';
        if (_isLiteralVariant(name, declared)) {
          final base = name.substring(0, name.length - 'Literal'.length);
          final nodeBase = nodeNames
              .map((cls) => node.lookUp(cls, _unrename(cls, base)))
              .nonNulls
              .firstOrNull;
          if (nodeBase != null) {
            _compare(nodeBase, _DartCallable(id, element), _Style.literal);
          }
          continue;
        }
        _dartOnlyMember(
          id,
          'Dart-only: Node ${nodeNames.join('/')} has no `$name`',
        );
      }
    }
  }

  String _unrename(String nodeClass, String dartName) {
    for (final MapEntry(:key, :value) in _renames.entries) {
      if (value == dartName && key.startsWith('$nodeClass.')) {
        return key.split('.').last;
      }
    }
    return dartName;
  }

  bool _isLiteralVariant(String name, Map<String, ExecutableElement> members) {
    if (!name.endsWith('Literal') || name == 'Literal') return false;
    return members.containsKey(
      name.substring(0, name.length - 'Literal'.length),
    );
  }

  void _compareMember(_NodeMember member, _DartCallable callable) {
    if (member.isMethod == callable.isGetter) {
      _mismatch(
        '${callable.id}#kind',
        'Node ${member.owner}.${member.name} is a '
            '${member.isMethod ? 'method' : 'property'}, Dart has a '
            '${callable.isGetter ? 'getter' : 'method'}',
      );
      return;
    }
    if (!member.isMethod) return;
    final stage = const {'Pipeline', 'PipelineSource'}.contains(member.owner);
    _compare(member, callable, stage ? _Style.stage : _Style.plain);
  }

  void _checkEntryPoints() {
    for (final MapEntry(key: owner, value: members)
        in node.entryPoints.entries) {
      final dartClass = dart.interfaceNamed(owner);
      if (dartClass == null) {
        _mismatch(owner, 'missing in Dart: Node entry point owner $owner');
        continue;
      }
      final dartMembers = dart.members(dartClass);
      for (final member in members.values) {
        final dartName = _rename(owner, member.name);
        final id = '$owner.$dartName';
        final element = dartMembers[dartName];
        if (element == null) {
          _mismatch(
            id,
            'missing in Dart: Node ${_renderNode(member.name, member.overloads)}',
          );
          continue;
        }
        _compare(member, _DartCallable(id, element), _Style.plain);
      }
    }
  }

  // Signatures.

  void _compare(_NodeMember member, _DartCallable dart, _Style style) {
    final optionOverloads = [
      for (final overload in member.overloads)
        if (overload.params.length == 1 && overload.params.single.isOptions)
          overload,
    ];
    var positional = [
      for (final overload in member.overloads)
        if (!optionOverloads.contains(overload)) overload.params,
    ];
    final named = dart.named;

    if (style == _Style.stage) {
      // A stage may take a Node positional parameter as a named one, as
      // Dart's unnest(selectable, {indexField}) does.
      positional = [
        for (final params in positional) _dropTrailingNamed(params, named),
      ];
    }

    final coveredNamed = <String>{};
    if (optionOverloads.isNotEmpty) {
      coveredNamed.addAll(
        _compareOptions(
          dart,
          optionOverloads,
          hasPositionalForm: positional.isNotEmpty,
        ),
      );
    }
    if (style == _Style.stage) {
      for (final params in member.overloads.map((o) => o.params)) {
        coveredNamed.addAll(params.map((param) => param.name));
      }
    }
    if (style != _Style.literal) {
      for (final name in named.keys) {
        if (coveredNamed.contains(name)) continue;
        _mismatch(
          '${dart.id}#$name',
          'Dart-only named parameter `$name`: Node '
              '${_renderNode(member.name, member.overloads)} has no such option',
        );
      }
    }

    if (positional.isEmpty) {
      if (dart.positional.isNotEmpty) {
        _mismatch(
          '${dart.id}#arity',
          'Node takes only an options object, Dart takes '
              '${dart.positional.length} positional argument(s) — Node '
              '${_renderNode(member.name, member.overloads)}; Dart '
              '${dart.render()}',
        );
      }
    } else {
      _comparePositional(member, positional, dart, style);
    }

    if (style != _Style.literal && !member.runtimeOnly) {
      _compareReturns(member, dart);
    }
  }

  List<_NodeParam> _dropTrailingNamed(
    List<_NodeParam> params,
    Map<String, FormalParameterElement> named,
  ) {
    var end = params.length;
    while (end > 0 && named.containsKey(params[end - 1].name)) {
      end--;
    }
    return params.sublist(0, end);
  }

  void _comparePositional(
    _NodeMember member,
    List<List<_NodeParam>> overloads,
    _DartCallable dart,
    _Style style,
  ) {
    final nodeMin = overloads
        .map((params) => params.where((param) => param.required).length)
        .reduce((a, b) => a < b ? a : b);
    final restIndexes = [
      for (final params in overloads)
        for (final (index, param) in params.indexed)
          if (param.rest) index,
    ];
    final restIndex = restIndexes.isEmpty
        ? null
        : restIndexes.reduce((a, b) => a < b ? a : b);
    final nodeMax = restIndex != null
        ? null
        : overloads
              .map((params) => params.length)
              .reduce((a, b) => a > b ? a : b);

    final positional = dart.positional;
    final dartRequired = dart.requiredPositional;
    final dartTotal = positional.length;

    // A trailing Dart Iterable takes Node's rest parameter, possibly folding
    // the parameters before it too.
    final collapsedAt =
        restIndex != null &&
            dartTotal > 0 &&
            dartTotal - 1 <= restIndex &&
            _iterableElement(positional.last.type) != null
        ? dartTotal - 1
        : null;

    final problems = <String>[];
    if (member.runtimeOnly) {
      // JavaScript cannot tell which parameters are optional; only check that
      // Dart takes as many.
      if (collapsedAt == null && (nodeMax == null || nodeMax > dartTotal)) {
        problems.add(
          'Node takes ${nodeMax ?? 'any number of'} argument(s), Dart at most '
          '$dartTotal',
        );
      }
    } else if (collapsedAt != null) {
      final expected = nodeMin < collapsedAt ? nodeMin : collapsedAt;
      final actual = dartRequired < collapsedAt ? dartRequired : collapsedAt;
      if (expected != actual) {
        problems.add(
          'Node requires $expected argument(s) before '
          '`${positional[collapsedAt].name}`, Dart requires $actual',
        );
      }
      if (collapsedAt >= nodeMin &&
          positional[collapsedAt].isRequiredPositional) {
        problems.add(
          'Node lets the trailing arguments be omitted, Dart requires the '
          'Iterable `${positional[collapsedAt].name}`',
        );
      }
    } else {
      if (dartRequired != nodeMin) {
        problems.add(
          'Node requires $nodeMin argument(s), Dart requires $dartRequired',
        );
      }
      if (nodeMax == null) {
        problems.add(
          'Node accepts any number of arguments, Dart at most $dartTotal',
        );
      } else if (nodeMax > dartTotal) {
        problems.add('Node accepts up to $nodeMax, Dart at most $dartTotal');
      } else if (dartTotal > nodeMax) {
        problems.add('Dart accepts up to $dartTotal, Node at most $nodeMax');
      }
    }
    if (problems.isNotEmpty) {
      _mismatch(
        '${dart.id}#arity',
        '${problems.join('; ')} — Node '
            '${_renderNode(member.name, member.overloads)}; Dart '
            '${dart.render()}',
      );
    }

    if (style == _Style.literal || member.runtimeOnly) return;

    _NodeType? typeAt(int index) {
      final types = [
        for (final params in overloads)
          for (final (i, param) in params.indexed)
            if (i == index && !param.rest || i <= index && param.rest)
              param.type,
      ];
      return types.isEmpty ? null : _NodeType.union(types);
    }

    final compared = collapsedAt ?? dartTotal;
    for (var i = 0; i < compared; i++) {
      final type = typeAt(i);
      if (type == null) continue;
      _compareType(
        '${dart.id}#${positional[i].name}',
        'parameter ${i + 1} (`${positional[i].name}`)',
        type,
        positional[i].type,
      );
    }
    if (collapsedAt != null) {
      final folded = _NodeType.union([
        for (var i = collapsedAt; i <= restIndex!; i++) ?typeAt(i),
      ]);
      final param = positional[collapsedAt];
      _compareType(
        '${dart.id}#${param.name}',
        'the elements of `${param.name}`, which take Node\'s arguments from '
            'position ${collapsedAt + 1} on',
        folded,
        _iterableElement(param.type)!,
      );
    }
  }

  /// Compares the keys of Node's options objects with Dart's named
  /// parameters, returning the named parameters they account for.
  Set<String> _compareOptions(
    _DartCallable dart,
    List<_NodeSignature> overloads, {
    required bool hasPositionalForm,
  }) {
    final covered = <String>{};
    final named = dart.named;
    for (final optionsName in {
      for (final overload in overloads) ...overload.params.single.type.options,
    }) {
      for (final base in node.optionBases(optionsName)) {
        for (final key in node.optionProperties(base).keys) {
          _baseKeyStages[key] = (_baseKeyStages[key] ?? 0) + 1;
          final missing = _missingBaseKeys[key] ??= [];
          if (named.containsKey(key)) {
            covered.add(key);
          } else {
            missing.add(dart.id);
          }
        }
      }
      for (final MapEntry(key: key, value: property)
          in node.optionProperties(optionsName).entries) {
        final dartName = _rename(optionsName, key);
        final param = named[dartName];
        if (param == null) {
          // A stage's required option is its positional argument.
          if (property.optional || !hasPositionalForm) {
            _mismatch(
              '${dart.id}#$key',
              'Node option `$key` (${property.type.label}) of $optionsName '
                  'has no Dart named parameter — Dart ${dart.render()}',
            );
          }
          continue;
        }
        covered.add(dartName);
        if (property.optional == param.isRequiredNamed) {
          _mismatch(
            '${dart.id}#$dartName',
            'Node option `$key` of $optionsName is '
                '${property.optional ? 'optional' : 'required'}, Dart\'s '
                '`$dartName` is ${param.isRequiredNamed ? 'required' : 'optional'}',
          );
        }
        _compareOption(
          '${dart.id}#$dartName',
          '$optionsName.$key',
          property,
          param.type,
        );
      }
    }
    return covered;
  }

  /// Compares an option with the Dart type of its named parameter, recursing
  /// into inline option objects such as `explainOptions`.
  void _compareOption(
    String id,
    String nodeLabel,
    _NodeProperty property,
    DartType dartType,
  ) {
    // An index signature (`{[name: string]: unknown}`) is a plain map.
    final nested = {
      for (final MapEntry(:key, :value) in property.type.properties.entries)
        if (key != '[key]') key: value,
    };
    if (nested.isEmpty || property.type.kinds.length != 1) {
      _compareType(id, 'option `$nodeLabel`', property.type, dartType);
      return;
    }
    final element = dartType is InterfaceType ? dartType.element : null;
    final constructor = element?.unnamedConstructor;
    if (constructor == null) {
      _compareType(id, 'option `$nodeLabel`', property.type, dartType);
      return;
    }
    final params = {
      for (final param in constructor.formalParameters)
        if (param.isNamed) param.name!: param,
    };
    for (final MapEntry(key: key, value: nestedProperty) in nested.entries) {
      final param = params[key];
      if (param == null) {
        _mismatch(
          '$id.$key',
          'Node option `$nodeLabel.$key` has no named parameter on '
              '${element!.name}()',
        );
        continue;
      }
      _compareOption('$id.$key', '$nodeLabel.$key', nestedProperty, param.type);
    }
    for (final name in params.keys) {
      if (!nested.containsKey(name)) {
        _mismatch(
          '$id.$name',
          'Dart-only parameter `$name` of ${element!.name}(): Node '
              '`$nodeLabel` has no such key',
        );
      }
    }
  }

  void _compareReturns(_NodeMember member, _DartCallable callable) {
    final dartTypes = <DartType>[];
    for (final overload in member.overloads) {
      final returns = overload.returns;
      if (returns == null) return;
      for (final kind in returns.kinds) {
        final types = _dartTypesFor(kind, returns);
        // Unmapped kinds (`any`, `documentData`, ...) cannot be compared.
        if (types == null || types.length != 1) return;
        dartTypes.add(types.single);
      }
    }
    if (dartTypes.isEmpty) return;
    final expected = dartTypes.reduce(dart.typeSystem.leastUpperBound);
    final actual = callable.element.returnType;
    if (!dart.typeSystem.isSubtypeOf(actual, expected)) {
      _mismatch(
        '${callable.id}#returns',
        'Node returns ${expected.getDisplayString()}, Dart returns '
            '${actual.getDisplayString()} — Node '
            '${_renderNode(member.name, member.overloads)}',
      );
    }
  }

  // Types.

  DartType? _iterableElement(DartType type) {
    if (type is! InterfaceType) return null;
    return type
        .asInstanceOf(dart.typeProvider.iterableElement)
        ?.typeArguments
        .single;
  }

  bool _isObject(DartType type) => type is DynamicType || type.isDartCoreObject;

  /// The Dart types a Node [kind] stands for, all of which a parameter must
  /// accept; null when Dart has no equivalent.
  List<DartType>? _dartTypesFor(String kind, _NodeType type) {
    final provider = dart.typeProvider;
    InterfaceType exported(String name) => dart.exportedType(name);
    return switch (kind) {
      'string' || 'literal' => [provider.stringType],
      'number' => [provider.numType],
      'boolean' => [provider.boolType],
      'map' => [
        provider.mapType(provider.stringType, provider.objectQuestionType),
      ],
      'array' => [provider.iterableType(provider.objectQuestionType)],
      'expression' || 'aggregateFunction' => [exported('PipelineExpression')],
      'booleanExpression' => [exported('PipelineBooleanExpression')],
      'field' => [exported('PipelineField')],
      'aliasedExpression' ||
      'aliasedAggregate' => [exported('PipelineAliasedExpression')],
      'selectable' => [
        exported('PipelineField'),
        exported('PipelineAliasedExpression'),
      ],
      'ordering' => [exported('PipelineOrdering')],
      'pipeline' => [exported('Pipeline')],
      'pipelineSnapshot' => [exported('PipelineSnapshot')],
      'pipelineResult' => [exported('PipelineResult')],
      'pipelineSource' => [exported('PipelineSource')],
      'explainStats' => [exported('ExplainStats')],
      'vectorValue' => [exported('VectorValue')],
      'geoPoint' => [exported('GeoPoint')],
      'timestamp' => [exported('Timestamp')],
      'documentReference' => [exported('DocumentReference')],
      'collectionReference' => [exported('CollectionReference')],
      'fieldPath' => [exported('FieldPath')],
      'query' => [exported('Query')],
      'bytes' => [dart.libraryType(dart.typedData, 'Uint8List')],
      'date' => [dart.libraryType(dart.core, 'DateTime')],
      'promise' => switch (type.elements) {
        final elements? when elements.kinds.length == 1 =>
          switch (_dartTypesFor(elements.kinds.single, elements)) {
            [final value] => [provider.futureType(value)],
            _ => null,
          },
        _ => null,
      },
      _ => null,
    };
  }

  /// Whether a Dart parameter of type [dartType] accepts every value of
  /// Node [kind].
  bool _accepts(DartType dartType, String kind, _NodeType type) {
    if (kind == 'null' || kind == 'undefined') {
      return dart.typeSystem.isNullable(dartType);
    }
    if (_isObject(dartType)) return true;
    if (kind == 'any') return false;
    if (kind == 'number') {
      return dartType.isDartCoreNum ||
          dartType.isDartCoreInt ||
          dartType.isDartCoreDouble;
    }
    if (kind == 'array') return _iterableElement(dartType) != null;
    if (kind == 'literal' && dartType.element is EnumElement) {
      final values = {
        for (final value in dart.enumValues(dartType.element! as EnumElement))
          value.toLowerCase(),
      };
      return node
          .literalValues(type)
          .every((value) => values.contains(value.toLowerCase()));
    }
    final types = _dartTypesFor(kind, type);
    if (types == null) return false;
    return types.every((t) => dart.typeSystem.isSubtypeOf(t, dartType));
  }

  void _compareType(
    String id,
    String where,
    _NodeType nodeType,
    DartType dartType,
  ) {
    final iterable = _iterableElement(dartType) != null;
    if (iterable &&
        !nodeType.kinds.contains('array') &&
        !nodeType.kinds.contains('any')) {
      _mismatch(
        id,
        'Node takes a single value (${nodeType.label}) for $where, Dart takes '
        'an Iterable (${dartType.getDisplayString()})',
      );
      return;
    }
    final rejected = [
      for (final kind in nodeType.kinds)
        if (!_accepts(dartType, kind, nodeType)) kind,
    ]..sort();
    if (rejected.isNotEmpty) {
      _mismatch(
        id,
        'Node accepts ${nodeType.label} for $where, Dart\'s '
        '${dartType.getDisplayString()} rejects ${rejected.join('|')}',
      );
      return;
    }
    // Compare the elements of a list with Node's array elements.
    final nodeElements = nodeType.elements;
    final dartElement = _iterableElement(dartType);
    if (nodeElements != null && dartElement != null) {
      _compareType(id, 'the elements of $where', nodeElements, dartElement);
    }
  }

  // String unions and exports.

  void _checkEnums() {
    for (final MapEntry(key: nodeName, value: dartName) in _enums.entries) {
      final element = dart.exports[dartName];
      final union = node.types[nodeName];
      if (element is! EnumElement || union?['kind'] != 'stringUnion') {
        report.problems.add(
          '_enums: $nodeName -> $dartName is not a union/enum',
        );
        continue;
      }
      final nodeValues = _strings(union!['values']);
      final dartValues = dart.enumValues(element);
      for (final value in nodeValues.difference(dartValues)) {
        _mismatch(
          '$dartName#$value',
          "Node's $nodeName includes '$value'; $dartName has no member with "
              'that value',
        );
      }
      for (final value in dartValues.difference(nodeValues)) {
        _mismatch(
          '$dartName#$value',
          "Dart-only value '$value': Node's $nodeName does not include it",
        );
      }
    }
  }

  void _checkTypes() {
    // Options objects are compared through the parameters that take them.
    final options = <String>{};
    void addOptions(_NodeType type) {
      for (final name in type.options) {
        options
          ..add(name)
          ..addAll(node.optionBases(name));
      }
    }

    final members = [
      ...node.functions.values,
      for (final cls in node.classes.values) ...cls.members.values,
      for (final owner in node.entryPoints.values) ...owner.values,
    ];
    for (final member in members) {
      for (final overload in member.overloads) {
        overload.params.map((param) => param.type).forEach(addOptions);
      }
    }

    for (final MapEntry(key: name, value: type) in node.types.entries) {
      switch (type['kind']) {
        case 'stringUnion' when !_enums.containsKey(name):
          _mismatch(
            'type:$name',
            'Node string union $name has no Dart enum in _enums',
          );
        case 'object' when !options.contains(name):
          _mismatch(
            'type:$name',
            'Node object type $name is not an options parameter of any '
                'member; teach this test how it maps onto Dart',
          );
      }
    }

    for (final tag in _nodeTypeTags) {
      if (!node.classes.values.any((cls) => cls.members.containsKey(tag))) {
        report.problems.add('_nodeTypeTags: no Node class has `$tag`');
      }
    }
  }

  void _checkExports() {
    final accounted = {
      ..._classes.values,
      ..._enums.values,
      ..._optionTypes.keys,
      ..._functionNamespaces,
      ...dart.topLevelFunctions.keys,
    };
    // Typedefs of a mapped class, such as BooleanExpression, are accounted
    // for by that class.
    final accountedClasses = {
      for (final name in accounted) ?dart.interfaceNamed(name),
    };
    for (final name in {..._optionTypes.keys, ..._enums.values}) {
      if (!dart.exports.containsKey(name)) {
        report.problems.add('$name is listed but not exported');
      }
    }
    for (final element in dart.pipelineDeclarations) {
      final name = element.name!;
      if (dart.exports[name] != element) {
        _mismatch(
          'export:$name',
          '$name is declared in ${element.firstFragment.libraryFragment?.source.shortName} '
              'but not exported from lib/google_cloud_firestore.dart',
        );
      }
      if (!accounted.contains(name) &&
          !(element is TypeAliasElement &&
              accountedClasses.contains(dart.interfaceNamed(name)))) {
        _dartOnlyMember(
          name,
          'Dart-only type: map it onto Node in _classes, _enums or '
          '_optionTypes, or list it in _dartOnly',
        );
      }
    }
  }
}

/// Renders a Node overload set as one merged signature, such as
/// `join(arrayExpression: expression|string, delimiter: expression|string)`.
String _renderNode(String name, List<_NodeSignature> overloads) {
  if (overloads.isEmpty) return name;
  final length = overloads
      .map((overload) => overload.params.length)
      .reduce((a, b) => a > b ? a : b);
  final parts = <String>[];
  for (var i = 0; i < length; i++) {
    final params = [
      for (final overload in overloads)
        if (i < overload.params.length) overload.params[i],
    ];
    final names = <String, int>{};
    for (final param in params) {
      names[param.name] = (names[param.name] ?? 0) + 1;
    }
    final paramName =
        (names.entries.toList()..sort((a, b) {
              final byCount = b.value.compareTo(a.value);
              return byCount != 0 ? byCount : a.key.compareTo(b.key);
            }))
            .first
            .key;
    final optional =
        params.length < overloads.length || params.any((p) => p.optional);
    final rest = params.any((p) => p.rest);
    final type = _NodeType.union(params.map((p) => p.type));
    parts.add(
      '${rest ? '...' : ''}$paramName${optional && !rest ? '?' : ''}: '
      '${type.label}',
    );
  }
  return '$name(${parts.join(', ')})';
}
