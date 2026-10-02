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

/// Static guard over the live Pipeline E2E suite in `test/e2e/pipeline/`.
///
/// The live suite needs credentials, so it only runs in its own workflow; this
/// guard runs in the ordinary credential-free `dart test`. It resolves the E2E
/// sources with `package:analyzer` and checks them against the Pipeline API
/// derived from the resolved library, so a newly added public function fails
/// here until it gets a live case:
///
/// 1. **Member coverage.** Every public member declared in
///    `lib/src/pipeline.dart` — top-level functions, static and instance
///    methods, getters and constructors of its classes, and every enum value —
///    plus `Firestore.pipeline` and `Transaction.executePipeline`, is
///    referenced somewhere under `test/e2e/pipeline/`. References match by
///    resolved element, so the static `PipelineFunctions.round` and the fluent
///    `PipelineExpression.round` are distinct members, as are an override such
///    as `PipelineField.ascending` and `PipelineExpression.ascending`. Public
///    declarations of `pipeline.dart` missing from the barrel are reported
///    too.
/// 2. **Optional parameters.** Each optional parameter of those members is
///    supplied by at least one invocation and omitted by another. An explicit
///    `null` argument counts as omitted.
/// 3. **Value positions.** A parameter typed `Object`, `Object?` or `dynamic`
///    receives an argument whose static type is a `PipelineExpression` in at
///    least one invocation, and a plain value (a literal, a field-name
///    `String`, a number, ...) in another. For a parameter typed
///    `Iterable<Object>` or `Iterable<Object?>` the same applies to the
///    elements of list literals passed to it.
/// 4. **Required shapes.** Each parameter listed in [_requiredShapes]
///    receives every listed argument shape at least once, and every
///    enum-typed parameter (such as `findNearest`'s `distanceMeasure`)
///    receives every value of its enum.
///
/// [_notExecutable] and [_notValuePositions] exempt the few members and
/// parameters these rules cannot apply to. Entries that name nothing, or that
/// no longer prevent a gap, fail the guard, as do stale entries in the shape
/// and family tables.
///
/// The E2E files must also import only the public barrel, `package:test`,
/// the harness and `dart:` libraries, be tagged `prod`, and declare their tests
/// through `pipelineE2E`.
///
/// **Adding a Pipeline API member:** add a live case for it — and for each of
/// its optional and value-position parameters — to the file of its family
/// (see [_families] and [_familyOf]), or this guard fails. A member whose name
/// matches no family table fails the guard until it is assigned one.
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:test/test.dart';

/// The E2E sources this guard scans, relative to the package root.
const _e2eDirectory = 'test/e2e/pipeline';

const _barrelUri = 'package:google_cloud_firestore/google_cloud_firestore.dart';

/// The library whose `pipeline.dart` part declares the Pipeline API.
const _implementationUri = 'package:google_cloud_firestore/src/firestore.dart';

const _pipelinePart = 'package:google_cloud_firestore/src/pipeline.dart';

/// Pipeline API members declared outside `pipeline.dart`.
const _entryPoints = {
  'Firestore': ['pipeline'],
  'Transaction': ['executePipeline'],
};

/// Members of `Object`, which are never part of the universe.
const _objectMembers = {
  '==',
  'hashCode',
  'noSuchMethod',
  'runtimeType',
  'toString',
};

/// The families the API is split into, with the E2E file owning each.
///
/// The function families follow the README's "Function reference" table:
/// Generic (`length`, `reverse`, `concat`) belongs to `string`, Reference to
/// `map_reference`, and Type, Debug and Search to `type_debug`.
const _families = <String, String>{
  'sources': 'sources_test.dart',
  'stages': 'stages_test.dart',
  'results': 'results_test.dart',
  'execute': 'execute_test.dart',
  'aggregates': 'aggregates_test.dart',
  'comparison_logical': 'functions_comparison_logical_test.dart',
  'arithmetic': 'functions_arithmetic_test.dart',
  'string': 'functions_string_test.dart',
  'array': 'functions_array_test.dart',
  'map_reference': 'functions_map_reference_test.dart',
  'timestamp_vector': 'functions_timestamp_vector_test.dart',
  'type_debug': 'functions_type_debug_test.dart',
};

/// Family overrides for single members, checked first by [_familyOf].
const _familyByMember = <String, String>{
  'Pipeline.aggregate': 'aggregates',
  'Pipeline.execute': 'execute',
  'Pipeline.firestore': 'execute',
  'PipelineField.path': 'type_debug',
};

/// Families by declaring class, checked second by [_familyOf].
const _familyByClass = <String, String>{
  'Firestore': 'sources',
  'Pipeline': 'stages',
  'PipelineAliasedExpression': 'stages',
  'PipelineExplainMode': 'execute',
  'PipelineExplainOptions': 'execute',
  'PipelineExplainOutputFormat': 'execute',
  'PipelineIndexMode': 'execute',
  'PipelineResult': 'results',
  'PipelineSnapshot': 'results',
  'PipelineSource': 'sources',
  'PipelineValueType': 'type_debug',
  'Transaction': 'execute',
};

/// Families by member name, checked last by [_familyOf].
///
/// Shared by every form of a function: static (`PipelineFunctions`,
/// `Expression`), fluent (`PipelineExpression`, `PipelineBooleanExpression`,
/// `PipelineField`) and top-level.
const _familyByName = <String, String>{
  // Comparison and logical.
  'and': 'comparison_logical',
  'cmp': 'comparison_logical',
  'coalesce': 'comparison_logical',
  'conditional': 'comparison_logical',
  'equal': 'comparison_logical',
  'equalAny': 'comparison_logical',
  'greaterThan': 'comparison_logical',
  'greaterThanOrEqual': 'comparison_logical',
  'ifNull': 'comparison_logical',
  'lessThan': 'comparison_logical',
  'lessThanOrEqual': 'comparison_logical',
  'nor': 'comparison_logical',
  'not': 'comparison_logical',
  'notEqual': 'comparison_logical',
  'notEqualAny': 'comparison_logical',
  'or': 'comparison_logical',
  'switchOn': 'comparison_logical',
  'xor': 'comparison_logical',
  // Aggregates.
  'arrayAgg': 'aggregates',
  'arrayAggDistinct': 'aggregates',
  'average': 'aggregates',
  'count': 'aggregates',
  'countAll': 'aggregates',
  'countDistinct': 'aggregates',
  'countIf': 'aggregates',
  'first': 'aggregates',
  'last': 'aggregates',
  'maximum': 'aggregates',
  'minimum': 'aggregates',
  'sum': 'aggregates',
  // Arithmetic.
  'abs': 'arithmetic',
  'add': 'arithmetic',
  'ceil': 'arithmetic',
  'divide': 'arithmetic',
  'exp': 'arithmetic',
  'floor': 'arithmetic',
  'ln': 'arithmetic',
  'log': 'arithmetic',
  'log10': 'arithmetic',
  'logicalMaximum': 'arithmetic',
  'logicalMinimum': 'arithmetic',
  'mod': 'arithmetic',
  'multiply': 'arithmetic',
  'pow': 'arithmetic',
  'rand': 'arithmetic',
  'round': 'arithmetic',
  'sqrt': 'arithmetic',
  'subtract': 'arithmetic',
  'trunc': 'arithmetic',
  // Array.
  'array': 'array',
  'arrayConcat': 'array',
  'arrayConcatMultiple': 'array',
  'arrayContains': 'array',
  'arrayContainsAll': 'array',
  'arrayContainsAllFrom': 'array',
  'arrayContainsAny': 'array',
  'arrayFilter': 'array',
  'arrayFirst': 'array',
  'arrayFirstN': 'array',
  'arrayGet': 'array',
  'arrayIndexOf': 'array',
  'arrayIndexOfAll': 'array',
  'arrayLast': 'array',
  'arrayLastIndexOf': 'array',
  'arrayLastN': 'array',
  'arrayLength': 'array',
  'arrayMaximum': 'array',
  'arrayMaximumN': 'array',
  'arrayMinimum': 'array',
  'arrayMinimumN': 'array',
  'arrayReverse': 'array',
  'arraySlice': 'array',
  'arraySum': 'array',
  'arrayTransform': 'array',
  'arrayTransformWithIndex': 'array',
  'join': 'array',
  'joinLiteral': 'array',
  'maximumN': 'array',
  'minimumN': 'array',
  'variable': 'array',
  // String, including the generic length / reverse / concat.
  'byteLength': 'string',
  'charLength': 'string',
  'concat': 'string',
  'endsWith': 'string',
  'length': 'string',
  'like': 'string',
  'ltrim': 'string',
  'regexContains': 'string',
  'regexFind': 'string',
  'regexFindAll': 'string',
  'regexMatch': 'string',
  'reverse': 'string',
  'rtrim': 'string',
  'split': 'string',
  'splitLiteral': 'string',
  'startsWith': 'string',
  'stringConcat': 'string',
  'stringContains': 'string',
  'stringIndexOf': 'string',
  'stringRepeat': 'string',
  'stringReplaceAll': 'string',
  'stringReplaceAllLiteral': 'string',
  'stringReplaceOne': 'string',
  'stringReplaceOneLiteral': 'string',
  'stringReverse': 'string',
  'substring': 'string',
  'substringLiteral': 'string',
  'toLower': 'string',
  'toLowerCase': 'string',
  'toUpper': 'string',
  'toUpperCase': 'string',
  'trim': 'string',
  // Map and reference.
  'collectionId': 'map_reference',
  'currentDocument': 'map_reference',
  'documentId': 'map_reference',
  'getField': 'map_reference',
  'map': 'map_reference',
  'mapEntries': 'map_reference',
  'mapGet': 'map_reference',
  'mapGetLiteral': 'map_reference',
  'mapKeys': 'map_reference',
  'mapMerge': 'map_reference',
  'mapRemove': 'map_reference',
  'mapSet': 'map_reference',
  'mapValues': 'map_reference',
  'parent': 'map_reference',
  'referenceSlice': 'map_reference',
  // Timestamp and vector.
  'cosineDistance': 'timestamp_vector',
  'currentTimestamp': 'timestamp_vector',
  'dotProduct': 'timestamp_vector',
  'euclideanDistance': 'timestamp_vector',
  'geoDistance': 'timestamp_vector',
  'timestampAdd': 'timestamp_vector',
  'timestampDiff': 'timestamp_vector',
  'timestampExtract': 'timestamp_vector',
  'timestampSubtract': 'timestamp_vector',
  'timestampToUnixMicros': 'timestamp_vector',
  'timestampToUnixMillis': 'timestamp_vector',
  'timestampToUnixSeconds': 'timestamp_vector',
  'timestampTruncate': 'timestamp_vector',
  'unixMicrosToTimestamp': 'timestamp_vector',
  'unixMillisToTimestamp': 'timestamp_vector',
  'unixSecondsToTimestamp': 'timestamp_vector',
  'vector': 'timestamp_vector',
  'vectorLength': 'timestamp_vector',
  // Type, debugging, search and expression primitives.
  'asBoolean': 'type_debug',
  'constant': 'type_debug',
  'documentMatches': 'type_debug',
  'exists': 'type_debug',
  'field': 'type_debug',
  'ifAbsent': 'type_debug',
  'ifError': 'type_debug',
  'isAbsent': 'type_debug',
  'isError': 'type_debug',
  'isType': 'type_debug',
  'pipelineFunction': 'type_debug',
  'raw': 'type_debug',
  'score': 'type_debug',
  'type': 'type_debug',
  // Orderings and aliases, used by the sort and projection stages.
  'as': 'stages',
  'ascending': 'stages',
  'descending': 'stages',
};

/// The argument shapes [_requiredShapes] can demand.
enum _Shape {
  /// The argument is a list, set or map literal holding a `PipelineExpression`
  /// at any depth.
  collectionWithExpression(
    'a list/set/map literal holding a PipelineExpression',
  ),

  /// The argument is a list literal with an element that is itself a list,
  /// set or map literal holding a `PipelineExpression`.
  nestedCollectionWithExpression(
    'a list literal whose element is a list/set/map literal holding a '
    'PipelineExpression',
  ),

  /// The argument is a non-empty list literal of numbers.
  numericList('a list literal of numbers'),

  /// The argument is a `String` literal containing a dot.
  dottedPath("a dotted String literal such as 'a.b'"),

  /// The argument's static type is `FieldPath`.
  fieldPath('a FieldPath');

  const _Shape(this.description);

  final String description;
}

/// Argument shapes that must each be exercised at least once (rule 4).
///
/// Collections holding expressions: wherever the Node SDK types a parameter
/// `Array<Expression | unknown>`, `unknown[]` or `Record<string, unknown>` —
/// and wherever it takes `unknown`, which it converts with
/// `valueToDefaultExpr` — a Dart collection literal may hold expressions and
/// must reach the backend as an `array(...)` / `map(...)` function rather
/// than a literal value. Each distinct encoding path appears here at least
/// once: the search-space functions, the generic value path, the variadic
/// first-argument path and nested construction.
///
/// Numeric lists: vector positions accept a plain list of numbers, which must
/// be sent as a vector rather than an array.
const _requiredShapes = <String, List<_Shape>>{
  // Search spaces.
  'PipelineFunctions.equalAny(searchSpace)': [_Shape.collectionWithExpression],
  'PipelineFunctions.notEqualAny(searchSpace)': [
    _Shape.collectionWithExpression,
  ],
  'PipelineFunctions.arrayContainsAll(searchValues)': [
    _Shape.collectionWithExpression,
  ],
  'PipelineFunctions.arrayContainsAny(searchValues)': [
    _Shape.collectionWithExpression,
  ],
  'PipelineExpression.equalAny(searchSpace)': [_Shape.collectionWithExpression],
  'PipelineExpression.notEqualAny(searchSpace)': [
    _Shape.collectionWithExpression,
  ],
  'PipelineExpression.arrayContainsAll(values)': [
    _Shape.collectionWithExpression,
  ],
  'PipelineExpression.arrayContainsAny(values)': [
    _Shape.collectionWithExpression,
  ],
  // Generic value positions.
  'equal(right)': [_Shape.collectionWithExpression],
  'PipelineFunctions.equal(right)': [_Shape.collectionWithExpression],
  'PipelineExpression.equal(other)': [_Shape.collectionWithExpression],
  'PipelineFunctions.conditional(trueCase)': [_Shape.collectionWithExpression],
  'PipelineBooleanExpression.conditional(thenExpression)': [
    _Shape.collectionWithExpression,
  ],
  'PipelineExpression.mapSet(value)': [_Shape.collectionWithExpression],
  'PipelineExpression.arrayConcat(secondArray)': [
    _Shape.collectionWithExpression,
  ],
  // Variadic arguments and nested construction.
  'PipelineFunctions.arrayConcat(arrays)': [
    _Shape.nestedCollectionWithExpression,
  ],
  'PipelineExpression.arrayConcatMultiple(otherArrays)': [
    _Shape.nestedCollectionWithExpression,
  ],
  'PipelineFunctions.mapMerge(maps)': [_Shape.nestedCollectionWithExpression],
  'PipelineExpression.mapMerge(maps)': [_Shape.nestedCollectionWithExpression],
  'PipelineFunctions.mapSet(keyValues)': [
    _Shape.nestedCollectionWithExpression,
  ],
  'PipelineFunctions.array(values)': [_Shape.nestedCollectionWithExpression],
  'Expression.array(values)': [_Shape.nestedCollectionWithExpression],
  'PipelineFunctions.map(keyValues)': [_Shape.nestedCollectionWithExpression],
  // Vector positions.
  'PipelineFunctions.cosineDistance(right)': [_Shape.numericList],
  'PipelineFunctions.dotProduct(right)': [_Shape.numericList],
  'PipelineFunctions.euclideanDistance(right)': [_Shape.numericList],
  'PipelineExpression.cosineDistance(other)': [_Shape.numericList],
  'PipelineExpression.dotProduct(other)': [_Shape.numericList],
  'PipelineExpression.euclideanDistance(other)': [_Shape.numericList],
  'Pipeline.findNearest(queryVector)': [_Shape.numericList],
  // Result paths.
  'PipelineResult.get(field)': [_Shape.dottedPath, _Shape.fieldPath],
};

/// Members (`Member`) and parameters (`Member(param)`) that cannot run
/// against the E2E database, exempt from every rule.
///
/// Keep this minimal: anything the backend can execute gets a live case.
const _notExecutable = <String, String>{
  'Pipeline.search':
      'needs a full-text search index, which pipeline_e2e_books does not '
      'have; the Node SDK system tests do not cover search either '
      '(TODO(search))',
  'PipelineExpression.geoDistance': 'only valid inside a search stage',
  'PipelineFunctions.documentMatches': 'only valid inside a search stage',
  'PipelineFunctions.geoDistance': 'only valid inside a search stage',
  'PipelineFunctions.score': 'only valid inside a search stage',
  'documentMatches': 'only valid inside a search stage',
  'score': 'only valid inside a search stage',
  'Expression.raw(options)':
      'no backend function takes options yet (the Node SDK only uses them for '
      'the disabled snippet function); an empty map equals omitting it',
  'PipelineFunctions.raw(options)':
      'no backend function takes options yet (the Node SDK only uses them for '
      'the disabled snippet function); an empty map equals omitting it',
  'pipelineFunction(options)':
      'no backend function takes options yet (the Node SDK only uses them for '
      'the disabled snippet function); an empty map equals omitting it',
};

/// `Object`-typed parameters (`Member(param)`) that are not Pipeline value
/// positions, exempt from rule 3.
const _notValuePositions = <String, String>{
  'Expression.constant(value)':
      'wraps a literal value; an expression is not a constant',
  'PipelineResult.get(field)':
      'takes a String or a FieldPath; see the dottedPath and fieldPath shapes',
  'PipelineSource.createFrom(query)': 'takes a Query or a VectorQuery',
  'constant(value)': 'wraps a literal value; an expression is not a constant',
};

/// The imports an E2E file may use besides `dart:` libraries.
const _allowedImports = {_barrelUri, 'package:test/test.dart', 'harness.dart'};

void main() {
  late final _Analysis analysis;

  setUpAll(() async {
    analysis = await _Analysis.run();
  });

  test('the E2E sources resolve without errors', () {
    expect(analysis.diagnostics, isEmpty);
  });

  test('the E2E sources follow the suite conventions', () {
    expect(analysis.conventionErrors, isEmpty);
  });

  test('the guard tables match the Pipeline API', () {
    expect(analysis.configurationErrors, isEmpty);
  });

  test('every Pipeline API member has live E2E coverage', () {
    final report = analysis.coverageReport();
    if (report != null) fail(report);
  });
}

/// A member of the Pipeline API universe.
final class _Member {
  _Member(this.key, this.element);

  /// `Class.member`, `Class.new` for an unnamed constructor, or the bare name
  /// of a top-level function.
  final String key;
  final Element element;

  late final String? family = _familyOf(this);

  late final List<FormalParameterElement> parameters = switch (element) {
    final ExecutableElement executable => executable.formalParameters,
    _ => const [],
  };

  String get name => element.name!;

  String? get className => switch (element.enclosingElement) {
    final InterfaceElement owner => owner.name,
    _ => null,
  };
}

/// Returns the family that owns [member], or `null` when no table assigns
/// one.
String? _familyOf(_Member member) {
  return _familyByMember[member.key] ??
      _familyByClass[member.className] ??
      _familyByName[member.name];
}

/// How rule 3 treats a parameter.
enum _ValueKind {
  /// Not a value position.
  none,

  /// Typed `Object`, `Object?` or `dynamic`.
  value,

  /// Typed `Iterable` (or `List`) of `Object`, `Object?` or `dynamic`.
  iterable,
}

/// What the E2E sources do with one parameter of one member.
final class _ParameterUsage {
  _ParameterUsage(this.parameter, this.kind);

  final FormalParameterElement parameter;
  final _ValueKind kind;

  bool supplied = false;
  bool omitted = false;
  bool expression = false;
  bool plain = false;
  final shapes = <_Shape>{};

  /// The enum whose values this parameter takes, if it is enum-typed.
  late final EnumElement? enumElement = switch (parameter.type) {
    InterfaceType(element: final EnumElement element) => element,
    _ => null,
  };

  /// The names of the [enumElement] values passed to this parameter.
  final enumValues = <String>{};
}

/// A coverage gap, attributed to a member's family.
final class _Gap {
  _Gap(
    this.member,
    this.rule,
    this.subject,
    this.message, {
    this.waivable = true,
  });

  final _Member member;
  final int rule;

  /// Whether an exemption can waive this gap. A missing export never is.
  final bool waivable;

  /// The exemption key this gap would be waived by: the member key, or
  /// `Member(param)`.
  final String subject;
  final String message;

  String get line => '$subject: $message';
}

const _ruleTitles = {
  1: 'Rule 1: member coverage',
  2: 'Rule 2: optional parameters',
  3: 'Rule 3: value positions',
  4: 'Rule 4: required shapes',
};

final class _Analysis {
  _Analysis._(this._packageRoot);

  final String _packageRoot;

  final diagnostics = <String>[];
  final conventionErrors = <String>[];
  final configurationErrors = <String>[];

  /// The universe, keyed by [_Member.key].
  final members = <String, _Member>{};

  /// Universe members that are not exported from the barrel.
  final unexported = <_Member>[];

  final referenced = <String>{};

  /// `Member(param)` to its usage.
  final usages = <String, _ParameterUsage>{};

  late final TypeSystem _typeSystem;
  late final InterfaceType _expressionType;
  late final InterfaceType _fieldPathType;
  late final InterfaceType _numType;

  static Future<_Analysis> run() async {
    final barrel = await Isolate.resolvePackageUri(Uri.parse(_barrelUri));
    final packageRoot = File.fromUri(barrel!).parent.parent.path;
    final analysis = _Analysis._(packageRoot);
    await analysis._analyze(barrel.toFilePath());
    return analysis;
  }

  String get _e2ePath => '$_packageRoot/$_e2eDirectory';

  Future<void> _analyze(String barrelPath) async {
    final sources =
        Directory(_e2ePath)
            .listSync(recursive: true)
            .whereType<File>()
            .map((file) => file.absolute.path)
            .where((path) => path.endsWith('.dart'))
            .toList()
          ..sort();

    final collection = AnalysisContextCollection(
      includedPaths: [barrelPath, ...sources],
    );
    final session = collection.contextFor(barrelPath).currentSession;

    final barrel =
        await session.getLibraryByUri(_barrelUri) as LibraryElementResult;
    final implementation =
        await session.getLibraryByUri(_implementationUri)
            as LibraryElementResult;
    _buildUniverse(barrel.element, implementation.element);

    for (final path in sources) {
      final result = await session.getResolvedUnit(path);
      if (result is! ResolvedUnitResult) {
        diagnostics.add('${_relative(path)}: could not be resolved ($result)');
        continue;
      }
      _checkUnit(result);
    }

    _checkConfiguration();
  }

  // ---------------------------------------------------------------------------
  // Universe.

  void _buildUniverse(LibraryElement barrel, LibraryElement implementation) {
    _typeSystem = implementation.typeSystem;
    _expressionType = implementation.getClass('PipelineExpression')!.thisType;
    _fieldPathType = implementation.getClass('FieldPath')!.thisType;
    _numType = implementation.typeProvider.numType;

    final exported = barrel.exportNamespace.definedNames2.values.toSet();
    bool isDeclaredInPipeline(Element element) {
      return element.firstFragment.libraryFragment?.source.uri.toString() ==
          _pipelinePart;
    }

    void add(Element element, {required bool exportedOwner}) {
      final key = _keyOf(element)!;
      final member = _Member(key, element);
      members[key] = member;
      if (!exportedOwner) unexported.add(member);
      for (final parameter in member.parameters) {
        usages['$key(${parameter.name})'] = _ParameterUsage(
          parameter,
          _valueKind(parameter.type),
        );
      }
    }

    for (final function in implementation.topLevelFunctions) {
      if (!function.isPublic || !isDeclaredInPipeline(function)) continue;
      add(function, exportedOwner: exported.contains(function));
    }
    for (final alias in implementation.typeAliases) {
      if (alias.isPublic &&
          isDeclaredInPipeline(alias) &&
          !exported.contains(alias)) {
        unexported.add(_Member(alias.name!, alias));
      }
    }
    for (final owner in <InterfaceElement>[
      ...implementation.classes,
      ...implementation.enums,
    ]) {
      if (!owner.isPublic || !isDeclaredInPipeline(owner)) continue;
      final isExported = exported.contains(owner);
      for (final element in _publicMembers(owner)) {
        add(element, exportedOwner: isExported);
      }
    }
    for (final MapEntry(key: className, value: names) in _entryPoints.entries) {
      final owner = implementation.getClass(className)!;
      for (final name in names) {
        add(owner.getMethod(name)!, exportedOwner: exported.contains(owner));
      }
    }
  }

  /// The public members [owner] declares: constructors of instantiable
  /// classes, methods and getters (fields included) — or, for an enum, only
  /// its values.
  Iterable<Element> _publicMembers(InterfaceElement owner) sync* {
    if (owner is EnumElement) {
      yield* owner.fields.where((field) => field.isEnumConstant);
      return;
    }
    if (owner is ClassElement && !owner.isAbstract && !owner.isSealed) {
      yield* owner.constructors.where(
        (constructor) =>
            constructor.isPublic && constructor.isOriginDeclaration,
      );
    }
    yield* owner.methods.where(
      (method) => method.isPublic && !_objectMembers.contains(method.name),
    );
    yield* owner.fields.where(
      (field) => field.isPublic && !_objectMembers.contains(field.name),
    );
  }

  _ValueKind _valueKind(DartType type) {
    bool isTop(DartType type) => type is DynamicType || type.isDartCoreObject;
    if (isTop(type)) return _ValueKind.value;
    if (type is InterfaceType &&
        (type.isDartCoreIterable || type.isDartCoreList) &&
        isTop(type.typeArguments.single)) {
      return _ValueKind.iterable;
    }
    return _ValueKind.none;
  }

  /// The universe key of [element], or `null` when it is not declared in the
  /// implementation library.
  String? _keyOf(Element element) {
    var base = element.baseElement;
    if (base is PropertyAccessorElement) base = base.variable;
    if (base.library?.uri.toString() != _implementationUri) return null;
    return switch (base.enclosingElement) {
      final InterfaceElement owner => '${owner.name}.${base.name}',
      _ => base.name,
    };
  }

  // ---------------------------------------------------------------------------
  // E2E sources.

  String _relative(String path) => path.substring(_packageRoot.length + 1);

  void _checkUnit(ResolvedUnitResult result) {
    final file = _relative(result.path);
    for (final diagnostic in result.diagnostics) {
      if (diagnostic.severity != Severity.error) continue;
      final location = result.lineInfo.getLocation(diagnostic.offset);
      diagnostics.add('$file:${location.lineNumber}: ${diagnostic.message}');
    }

    final unit = result.unit;
    final isTest = file.endsWith('_test.dart');
    for (final directive in unit.directives) {
      if (directive is! ImportDirective) continue;
      final uri = directive.uri.stringValue ?? '';
      if (!uri.startsWith('dart:') && !_allowedImports.contains(uri)) {
        conventionErrors.add(
          '$file: imports $uri; E2E files may import only the barrel, '
          'package:test, harness.dart and dart: libraries',
        );
      }
    }
    if (isTest) {
      final tagged = unit.directives.whereType<LibraryDirective>().any(
        (library) => library.metadata.any(
          (annotation) =>
              annotation.name.name == 'Tags' &&
              (annotation.arguments?.toSource().contains("'prod'") ?? false),
        ),
      );
      if (!tagged) {
        conventionErrors.add("$file: missing @Tags(['prod']) on `library;`");
      }
    }

    final visitor = _ReferenceVisitor(this);
    unit.accept(visitor);
    if (isTest && !visitor.declaresSuite) {
      conventionErrors.add('$file: declares no tests through pipelineE2E');
    }
  }

  void _recordReference(Element? element) {
    if (element == null) return;
    final key = _keyOf(element);
    if (key != null && members.containsKey(key)) referenced.add(key);
  }

  void _recordInvocation(Element? element, ArgumentList arguments) {
    if (element == null) return;
    final key = _keyOf(element);
    final member = key == null ? null : members[key];
    if (member == null) return;

    final supplied = <String>{};
    for (final argument in arguments.arguments) {
      final parameter = argument.correspondingParameter;
      final value = _argumentValue(argument, parameter);
      final name = parameter?.name;
      if (name == null || value == null || value is NullLiteral) continue;
      supplied.add(name);

      final subject = '$key($name)';
      final usage = usages[subject];
      if (usage == null) continue;
      switch (usage.kind) {
        case _ValueKind.none:
          break;
        case _ValueKind.value:
          _classify(value, usage);
        case _ValueKind.iterable:
          if (_isListOrSetLiteral(value)) {
            for (final element in _leaves(value)) {
              _classify(element, usage);
            }
          }
      }
      for (final shape in _requiredShapes[subject] ?? const <_Shape>[]) {
        if (_hasShape(value, shape)) usage.shapes.add(shape);
      }
      if (usage.enumElement != null) {
        if (_enumConstantName(value) case final constant?) {
          usage.enumValues.add(constant);
        }
      }
    }

    for (final parameter in member.parameters) {
      if (!parameter.isOptional) continue;
      final usage = usages['$key(${parameter.name})']!;
      if (supplied.contains(parameter.name)) {
        usage.supplied = true;
      } else {
        usage.omitted = true;
      }
    }
  }

  /// The name of the enum value [value] reads, as in `DistanceMeasure.cosine`.
  String? _enumConstantName(Expression value) {
    var element = switch (value) {
      PrefixedIdentifier() => value.identifier.element,
      PropertyAccess() => value.propertyName.element,
      SimpleIdentifier() => value.element,
      _ => null,
    };
    if (element is PropertyAccessorElement) element = element.variable;
    return element is FieldElement && element.isEnumConstant
        ? element.name
        : null;
  }

  /// The expression passed by [argument].
  ///
  /// A named argument is a `NamedExpression` up to analyzer 12 and a
  /// `NamedArgument` from 13; neither type is named here so that the guard
  /// builds against both. In both, the value is the last expression child.
  Expression? _argumentValue(
    AstNode argument,
    FormalParameterElement? parameter,
  ) {
    if (parameter != null && parameter.isNamed) {
      return argument.childEntities.whereType<Expression>().lastOrNull;
    }
    return argument is Expression ? argument : null;
  }

  /// Records whether [value] is an expression or a plain value. Arguments
  /// whose static type could be either, such as `Object`, count as neither.
  void _classify(Expression value, _ParameterUsage usage) {
    switch (_expressionness(value)) {
      case true:
        usage.expression = true;
      case false:
        usage.plain = true;
      case null:
        break;
    }
  }

  /// Whether [value]'s static type is a `PipelineExpression` (`true`), cannot
  /// be one (`false`), or might be (`null`).
  bool? _expressionness(Expression value) {
    final type = value.staticType;
    if (type == null || type is InvalidType || type is NeverType) return null;
    if (type.isDartCoreNull) return false;
    final nonNull = _typeSystem.promoteToNonNull(type);
    if (_typeSystem.isSubtypeOf(nonNull, _expressionType)) return true;
    if (_typeSystem.isSubtypeOf(_expressionType, nonNull)) return null;
    return false;
  }

  bool _isSubtypeOf(Expression value, InterfaceType type) {
    final staticType = value.staticType;
    if (staticType == null || staticType is InvalidType) return false;
    if (staticType is NeverType || staticType.isDartCoreNull) return false;
    return _typeSystem.isSubtypeOf(
      _typeSystem.promoteToNonNull(staticType),
      type,
    );
  }

  bool _isListOrSetLiteral(Expression value) {
    return value is ListLiteral || (value is SetOrMapLiteral && value.isSet);
  }

  /// The element and value expressions of a collection literal, looking
  /// through `if`, `for`, null-aware elements and spreads of literals.
  Iterable<Expression> _leaves(Expression literal) {
    final elements = switch (literal) {
      ListLiteral() => literal.elements,
      SetOrMapLiteral() => literal.elements,
      _ => const <CollectionElement>[],
    };
    return _collectionLeaves(elements);
  }

  Iterable<Expression> _collectionLeaves(
    Iterable<CollectionElement> elements,
  ) sync* {
    // An if-chain rather than a switch: the set of CollectionElement
    // subtypes differs between analyzer versions.
    for (final element in elements) {
      if (element is Expression) {
        yield element;
      } else if (element is NullAwareElement) {
        yield element.value;
      } else if (element is MapLiteralEntry) {
        yield element.value;
      } else if (element is IfElement) {
        yield* _collectionLeaves([element.thenElement, ?element.elseElement]);
      } else if (element is ForElement) {
        yield* _collectionLeaves([element.body]);
      } else if (element is SpreadElement) {
        yield* _leaves(element.expression);
      }
    }
  }

  /// Whether [value] is a collection literal holding an expression at any
  /// depth.
  bool _holdsExpression(Expression value) {
    if (value is! ListLiteral && value is! SetOrMapLiteral) return false;
    return _leaves(
      value,
    ).any((leaf) => (_expressionness(leaf) ?? false) || _holdsExpression(leaf));
  }

  bool _hasShape(Expression value, _Shape shape) {
    switch (shape) {
      case _Shape.collectionWithExpression:
        return _holdsExpression(value);
      case _Shape.nestedCollectionWithExpression:
        return _isListOrSetLiteral(value) &&
            _leaves(value).any(_holdsExpression);
      case _Shape.numericList:
        final leaves = value is ListLiteral ? _leaves(value).toList() : null;
        return leaves != null &&
            leaves.isNotEmpty &&
            leaves.every((leaf) => _isSubtypeOf(leaf, _numType));
      case _Shape.dottedPath:
        return value is StringLiteral &&
            (value.stringValue?.contains('.') ?? false);
      case _Shape.fieldPath:
        return _isSubtypeOf(value, _fieldPathType);
    }
  }

  // ---------------------------------------------------------------------------
  // Configuration.

  void _checkConfiguration() {
    for (final MapEntry(:key, :value) in _families.entries) {
      if (!File('$_e2ePath/$value').existsSync()) {
        configurationErrors.add(
          'family $key: $_e2eDirectory/$value does not exist',
        );
      }
    }
    for (final member in members.values) {
      if (member.family == null) {
        configurationErrors.add(
          '${member.key}: no family; add it to _familyByName, '
          '_familyByClass or _familyByMember',
        );
      }
    }
    for (final MapEntry(:key, :value) in [
      ..._familyByMember.entries,
      ..._familyByClass.entries,
      ..._familyByName.entries,
    ]) {
      if (!_families.containsKey(value)) {
        configurationErrors.add(
          'family table entry $key: unknown family $value',
        );
      }
    }
    for (final key in _familyByMember.keys) {
      if (!members.containsKey(key)) {
        configurationErrors.add('_familyByMember: $key is not an API member');
      }
    }
    final classes = {for (final member in members.values) member.className};
    for (final key in _familyByClass.keys) {
      if (!classes.contains(key)) {
        configurationErrors.add('_familyByClass: $key declares no API member');
      }
    }
    final namesResolvedByName = {
      for (final member in members.values)
        if (_familyByMember[member.key] == null &&
            _familyByClass[member.className] == null)
          member.name,
    };
    for (final key in _familyByName.keys) {
      if (!namesResolvedByName.contains(key)) {
        configurationErrors.add('_familyByName: no API member named $key');
      }
    }

    for (final MapEntry(:key, :value) in _requiredShapes.entries) {
      final usage = usages[key];
      if (usage == null) {
        configurationErrors.add('_requiredShapes: $key is not a parameter');
      } else if (value.isEmpty) {
        configurationErrors.add('_requiredShapes: $key lists no shape');
      } else if (_notExecutable.containsKey(key) ||
          _notExecutable.containsKey(key.substring(0, key.indexOf('(')))) {
        configurationErrors.add(
          '_requiredShapes: $key is exempted by _notExecutable',
        );
      }
    }

    // An exemption is stale when it names nothing, or when the E2E sources
    // already cover what it waives.
    final unexempted = _gaps(
      applyExemptions: false,
    ).where((gap) => gap.waivable).toList();
    final waived = {for (final gap in unexempted) gap.subject};
    final waivedMembers = {for (final gap in unexempted) gap.member.key};
    for (final key in _notExecutable.keys) {
      if (!members.containsKey(key) && !usages.containsKey(key)) {
        configurationErrors.add(
          '_notExecutable: $key is not an API member or parameter',
        );
      } else if (!waived.contains(key) &&
          !(members.containsKey(key) && waivedMembers.contains(key))) {
        configurationErrors.add(
          '_notExecutable: $key has full coverage; remove the exemption',
        );
      }
    }
    final valueGaps = {
      for (final gap in unexempted)
        if (gap.rule == 3) gap.subject,
    };
    for (final key in _notValuePositions.keys) {
      final usage = usages[key];
      if (usage == null || usage.kind == _ValueKind.none) {
        configurationErrors.add(
          '_notValuePositions: $key is not an Object-typed parameter',
        );
      } else if (!valueGaps.contains(key)) {
        configurationErrors.add(
          '_notValuePositions: $key is covered; remove the exemption',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Gaps.

  List<_Gap> _gaps({required bool applyExemptions}) {
    final gaps = <_Gap>[];
    bool exempt(String subject, {bool valuePosition = false}) {
      if (!applyExemptions) return false;
      return _notExecutable.containsKey(subject) ||
          (valuePosition && _notValuePositions.containsKey(subject));
    }

    for (final member in unexported) {
      gaps.add(
        _Gap(
          member,
          1,
          member.key,
          'public in lib/src/pipeline.dart but not exported from '
          'lib/google_cloud_firestore.dart',
          waivable: false,
        ),
      );
    }

    for (final member in members.values) {
      final key = member.key;
      if (exempt(key)) continue;
      if (!referenced.contains(key)) {
        gaps.add(_Gap(member, 1, key, 'not referenced'));
      }
      for (final parameter in member.parameters) {
        final subject = '$key(${parameter.name})';
        final usage = usages[subject]!;
        if (exempt(subject)) continue;
        if (parameter.isOptional) {
          if (!usage.supplied) {
            gaps.add(_Gap(member, 2, subject, 'never supplied'));
          }
          if (!usage.omitted) {
            gaps.add(_Gap(member, 2, subject, 'never omitted'));
          }
        }
        if (!exempt(subject, valuePosition: true)) {
          switch (usage.kind) {
            case _ValueKind.none:
              break;
            case _ValueKind.value:
              if (!usage.expression) {
                gaps.add(
                  _Gap(member, 3, subject, 'never passed a PipelineExpression'),
                );
              }
              if (!usage.plain) {
                gaps.add(
                  _Gap(
                    member,
                    3,
                    subject,
                    'never passed a plain value (literal, field name, ...)',
                  ),
                );
              }
            case _ValueKind.iterable:
              if (!usage.expression) {
                gaps.add(
                  _Gap(
                    member,
                    3,
                    subject,
                    'no list-literal element is a PipelineExpression',
                  ),
                );
              }
              if (!usage.plain) {
                gaps.add(
                  _Gap(
                    member,
                    3,
                    subject,
                    'no list-literal element is a plain value',
                  ),
                );
              }
          }
        }
        if (usage.enumElement case final enumElement?) {
          for (final constant in enumElement.fields) {
            if (constant.isEnumConstant &&
                !usage.enumValues.contains(constant.name)) {
              gaps.add(
                _Gap(
                  member,
                  4,
                  subject,
                  'never passed ${enumElement.name}.${constant.name}',
                ),
              );
            }
          }
        }
        for (final shape in _requiredShapes[subject] ?? const <_Shape>[]) {
          if (!usage.shapes.contains(shape)) {
            gaps.add(
              _Gap(
                member,
                4,
                subject,
                'never passed ${shape.description} (${shape.name})',
              ),
            );
          }
        }
      }
    }
    return gaps;
  }

  /// The grouped gap report, or `null` when there are no gaps.
  String? coverageReport() {
    final gaps = _gaps(applyExemptions: true);
    if (gaps.isEmpty) return null;

    final byFamily = <String, List<_Gap>>{};
    for (final gap in gaps) {
      (byFamily[gap.member.family ?? '(no family)'] ??= []).add(gap);
    }
    final families = [
      ..._families.keys.where(byFamily.containsKey),
      ...byFamily.keys.where((family) => !_families.containsKey(family)),
    ];

    final buffer = StringBuffer()
      ..writeln(
        'Pipeline E2E coverage: ${gaps.length} gaps. Add live cases under '
        '$_e2eDirectory/ to the file named for each family; the rules are '
        'documented at the top of test/pipeline_e2e_coverage_test.dart.',
      )
      ..writeln()
      ..writeln('Gaps by family:');
    for (final family in families) {
      buffer.writeln(
        '  ${family.padRight(20)} ${'${byFamily[family]!.length}'.padLeft(4)}'
        '  $_e2eDirectory/${_families[family] ?? '?'}',
      );
    }

    for (final family in families) {
      final familyGaps = byFamily[family]!;
      buffer
        ..writeln()
        ..writeln(
          '== $family: $_e2eDirectory/${_families[family] ?? '?'} '
          '(${familyGaps.length}) ==',
        );
      for (final rule in _ruleTitles.keys) {
        final lines = [
          for (final gap in familyGaps)
            if (gap.rule == rule) gap.line,
        ];
        if (lines.isEmpty) continue;
        buffer.writeln('-- ${_ruleTitles[rule]} --');
        lines.forEach(buffer.writeln);
      }
    }
    return buffer.toString();
  }
}

/// Records every API reference and invocation in an E2E unit.
final class _ReferenceVisitor extends RecursiveAstVisitor<void> {
  _ReferenceVisitor(this._analysis);

  final _Analysis _analysis;

  /// Whether the unit invokes the harness's `pipelineE2E`.
  bool declaresSuite = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _analysis._recordReference(node.element);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final element = node.methodName.element;
    if (element is TopLevelFunctionElement && element.name == 'pipelineE2E') {
      declaresSuite = true;
    }
    _analysis._recordInvocation(element, node.argumentList);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final element = node.constructorName.element;
    _analysis
      .._recordReference(element)
      .._recordInvocation(element, node.argumentList);
    super.visitInstanceCreationExpression(node);
  }
}
