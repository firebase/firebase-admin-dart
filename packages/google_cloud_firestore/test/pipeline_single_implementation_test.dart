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

/// Enforces that every Pipeline function has exactly one implementation.
///
/// A Pipeline function can be written in several forms: the static
/// `PipelineFunctions.equal('price', 1)`, the fluent `field('price').equal(1)`,
/// a top-level `equal('price', 1)`, and FlutterFire-style `Expression` aliases
/// such as `Expression.field`. When forms were implemented separately they
/// drifted apart (different backend names, argument conversions and optional
/// arguments). So this test resolves `lib/src/pipeline.dart` with
/// `package:analyzer`, groups its public members by name, and requires every
/// form but one to be a single call forwarding its parameters, in order, to
/// that one implementation. It then encodes every pair through each of its
/// forms and checks they send identical requests.
@TestOn('vm')
library;

import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/ast/visitor.dart' as ast;
import 'package:analyzer/dart/element/element.dart';
import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:google_cloud_firestore/src/firestore_http_client.dart';
import 'package:google_cloud_firestore_v1/firestore.dart' as firestore_v1;
import 'package:google_cloud_firestore_v1/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart' hide greaterThan, lessThan;

/// Pairs that cannot forward to their counterpart, with the reason.
///
/// Every entry must name a pair that fails the forwarding check; an entry
/// that no longer fails is stale and fails the test.
const _exceptions = <String, String>{
  'concat':
      'The fluent form keeps the FlutterFire-style `concat(List others)`, '
      "while PipelineFunctions.concat takes Node's `(first, second, [others])`. "
      'It still builds the function only through PipelineFunctions.concat, but '
      'has to split `others` into `second` and the rest to call it. Making it '
      '`concat(second, [others])` would silently turn existing `concat([x])` '
      'calls into concatenating the array `[x]`.',
  'ascending': _orderingException,
  'descending': _orderingException,
};

const _orderingException =
    'Inside PipelineExpression the name resolves to the fluent method itself, '
    'so it cannot call the top-level function, and PipelineFunctions has no '
    'ordering helpers to share. Both forms are a single PipelineOrdering '
    'constructor call, and _behaviour checks they encode identically.';

/// Public fluent members that are not a form of any Pipeline function, so
/// they have nothing to forward to.
const _notFunctions = <String, String>{
  'as': 'Wraps the expression in a PipelineAliasedExpression.',
  'asBoolean': 'Casts the expression to a PipelineBooleanExpression.',
};

void main() {
  group(
    'Pipeline functions have a single implementation',
    timeout: const Timeout(Duration(minutes: 3)),
    () {
      late _Inventory inventory;

      setUpAll(() async {
        inventory = await _Inventory.load();
      });

      test('derives the pairs from the library', () {
        // Guards against a derivation that silently finds nothing to check.
        expect(inventory.pairs.length, greaterThanOrEqualTo(100));
        expect(inventory.pairs['equal']?.map((member) => member.label), [
          'PipelineFunctions.equal',
          'equal',
          'PipelineExpression.equal',
        ]);
        expect(
          inventory.pairs['not']?.map((member) => member.label),
          containsAll([
            'PipelineFunctions.not',
            'PipelineBooleanExpression.not',
          ]),
        );
      });

      test('every form forwards to the one implementation', () {
        final problems = <String>[];
        for (final MapEntry(key: name, value: members)
            in inventory.pairs.entries) {
          if (_exceptions.containsKey(name)) continue;
          final implementation = members.first;
          for (final member in members.skip(1)) {
            final problem = _forwardingProblem(member, implementation);
            if (problem != null) {
              problems.add(
                '${member.label} must forward to ${implementation.label}: '
                '$problem.',
              );
            }
          }
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
      });

      test('fluent members without a same-named counterpart forward', () {
        final problems = <String>[];
        for (final member in inventory.unpairedFluent) {
          if (_notFunctions.containsKey(member.name)) continue;
          final target = inventory.calledMember(member);
          final problem = target == null
              ? 'its body must be a single call forwarding to a '
                    'PipelineFunctions function or another fluent method, '
                    'but it is `${_source(member.body)}`'
              : _forwardingProblem(member, target);
          if (problem != null) problems.add('${member.label}: $problem.');
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
      });

      test('exceptions are still needed', () {
        final stale = <String>[];
        for (final name in _exceptions.keys) {
          final members = inventory.pairs[name];
          if (members == null) {
            stale.add('$name is no longer a pair.');
            continue;
          }
          final forwards = members
              .skip(1)
              .every(
                (member) => _forwardingProblem(member, members.first) == null,
              );
          if (forwards) {
            stale.add('$name now forwards; remove it from _exceptions.');
          }
        }
        for (final name in _notFunctions.keys) {
          if (!inventory.unpairedFluent.any((member) => member.name == name)) {
            stale.add(
              '$name is no longer an unpaired fluent member; remove it from '
              '_notFunctions.',
            );
          }
        }
        expect(stale, isEmpty, reason: stale.join('\n'));
      });

      test('every pair has a behavioural check covering each form', () {
        final expected = <String, Set<String>>{
          for (final MapEntry(:key, :value) in inventory.pairs.entries)
            key: {for (final member in value) member.form.name},
          for (final alias in inventory.unpairedFluent)
            if (!_notFunctions.containsKey(alias.name))
              alias.name: {
                'alias',
                if (inventory.calledMember(alias) case final target?)
                  target.form.name,
              },
        };
        final problems = <String>[];
        for (final MapEntry(key: name, value: forms) in expected.entries) {
          final calls = _behaviour[name];
          if (calls == null) {
            problems.add('$name has no entry in _behaviour.');
            continue;
          }
          final covered = {for (final call in calls) ...call.forms.keys};
          if (covered.difference(forms) case final extra
              when extra.isNotEmpty) {
            problems.add('$name has no ${extra.join(', ')} form.');
          }
          if (forms.difference(covered) case final missing
              when missing.isNotEmpty) {
            problems.add(
              '_behaviour never calls $name in ${missing.join(', ')} form.',
            );
          }
          for (final call in calls) {
            if (call.forms.length < 2) {
              problems.add('$name: "${call.description}" compares one form.');
            }
          }
        }
        for (final name in _behaviour.keys) {
          if (!expected.containsKey(name)) {
            problems.add('_behaviour.$name is not a pair; remove it.');
          }
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
      });
    },
  );

  group('every form of a Pipeline function encodes identically', () {
    late Firestore firestore;
    firestore_v1.ExecutePipelineRequest? captured;

    setUp(() {
      final client = _MockFirestoreHttpClient();
      firestore = Firestore.internal(
        settings: const Settings(projectId: _projectId, databaseId: 'db'),
        client: client,
      );
      when(() => client.cachedProjectId).thenReturn(_projectId);
      when(
        () => client.v1<Stream<firestore_v1.ExecutePipelineResponse>>(any()),
      ).thenAnswer((invocation) async {
        final callback =
            invocation.positionalArguments.single
                as Future<Stream<firestore_v1.ExecutePipelineResponse>>
                Function(firestore_v1.Firestore api, String projectId);
        final api = FakeFirestore(
          executePipeline: (request) {
            captured = request;
            return const Stream<firestore_v1.ExecutePipelineResponse>.empty();
          },
        );
        return callback(api, _projectId);
      });
    });

    /// The JSON of the request that executes a Pipeline using [built].
    Future<Object?> encode(Object built) async {
      final pipeline = firestore.pipeline().collection('books');
      captured = null;
      await switch (built) {
        PipelineOrdering() => pipeline.sort([built]),
        PipelineExpression() => pipeline.select([built.as('result')]),
        _ => throw ArgumentError.value(built, 'built'),
      }.execute();
      return captured!.toJson();
    }

    for (final MapEntry(key: name, value: calls) in _behaviour.entries) {
      test(name, () async {
        for (final call in calls) {
          final [(firstForm, firstBuild), ...others] = [
            for (final MapEntry(:key, :value) in call.forms.entries)
              (key, value),
          ];
          final expected = await encode(firstBuild());
          for (final (form, build) in others) {
            expect(
              await encode(build()),
              expected,
              reason:
                  '$name ${call.description}: the $form form encodes '
                  'differently from the $firstForm form',
            );
          }
        }
      });
    }
  });
}

/// The forms a Pipeline function is written in.
///
/// The first form a function has holds its implementation, and the later
/// ones forward to it. The order is the only one that always compiles: a
/// later form can name an earlier one unambiguously, but inside a class a
/// bare name resolves to that class's own member, so `PipelineExpression.not`
/// or `Expression.field` cannot call the top-level `not` or `field`.
enum _Form {
  /// `PipelineFunctions.x(...)`.
  static,

  /// The FlutterFire-style `Expression.x(...)`.
  expression,

  /// A top-level `x(...)`.
  topLevel,

  /// `expression.x(...)`, on `PipelineExpression` or one of its subclasses.
  fluent,
}

/// A public member of `lib/src/pipeline.dart`.
final class _Member {
  _Member(this.form, this.element, this.body);

  final _Form form;
  final ExecutableElement element;
  final ast.FunctionBody body;

  String get name => element.name!;

  String get label {
    final owner = element.enclosingElement;
    return owner is InterfaceElement ? '${owner.name}.$name' : name;
  }

  bool isElement(Element? other) {
    return other is ExecutableElement &&
        other.baseElement == element.baseElement;
  }
}

/// The public Pipeline members, grouped by name.
final class _Inventory {
  _Inventory(List<_Member> members) {
    for (final member in members) {
      _byName.putIfAbsent(member.name, () => []).add(member);
    }
    for (final group in _byName.values) {
      group.sort((a, b) => a.form.index.compareTo(b.form.index));
    }
  }

  final _byName = <String, List<_Member>>{};

  /// The names written in more than one form, each with its members,
  /// implementation first.
  late final Map<String, List<_Member>> pairs = {
    for (final MapEntry(:key, :value) in _byName.entries)
      if (value.map((member) => member.form).toSet().length > 1) key: value,
  };

  /// Fluent members whose name no other form uses.
  late final List<_Member> unpairedFluent = [
    for (final MapEntry(:key, :value) in _byName.entries)
      if (!pairs.containsKey(key))
        ...value.where((member) => member.form == _Form.fluent),
  ];

  /// The `PipelineFunctions` or fluent member that [member]'s body calls, if
  /// its body is a single call.
  _Member? calledMember(_Member member) {
    final call = _singleExpression(member.body);
    if (call is! ast.MethodInvocation) return null;
    final callee = call.methodName.element;
    for (final group in _byName.values) {
      for (final candidate in group) {
        if ((candidate.form == _Form.static ||
                candidate.form == _Form.fluent) &&
            candidate.isElement(callee)) {
          return candidate;
        }
      }
    }
    return null;
  }

  static Future<_Inventory> load() async {
    final uri = await Isolate.resolvePackageUri(
      Uri.parse('package:google_cloud_firestore/src/firestore.dart'),
    );
    final libraryPath = uri!.toFilePath();
    final collection = AnalysisContextCollection(includedPaths: [libraryPath]);
    try {
      final result = await collection
          .contextFor(libraryPath)
          .currentSession
          .getResolvedLibrary(libraryPath);
      if (result is! ResolvedLibraryResult) {
        throw StateError('Could not resolve $libraryPath: $result');
      }
      final pipelinePath = uri.resolve('pipeline.dart').toFilePath();
      final unit = result.units
          .singleWhere((unit) => unit.path == pipelinePath)
          .unit;
      final members = <_Member>[];
      unit.accept(_MemberCollector(members));
      return _Inventory(members);
    } finally {
      await collection.dispose();
    }
  }
}

/// Collects the public functions and methods that are forms of a Pipeline
/// function.
final class _MemberCollector extends ast.RecursiveAstVisitor<void> {
  _MemberCollector(this._members);

  final List<_Member> _members;

  @override
  void visitFunctionDeclaration(ast.FunctionDeclaration node) {
    final element = node.declaredFragment?.element;
    if (node.parent is ast.CompilationUnit &&
        element is TopLevelFunctionElement &&
        element.isPublic) {
      _members.add(
        _Member(_Form.topLevel, element, node.functionExpression.body),
      );
    }
  }

  @override
  void visitMethodDeclaration(ast.MethodDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element is! MethodElement || !element.isPublic) return;
    final owner = element.enclosingElement;
    if (owner is! ClassElement || !owner.isPublic) return;

    final form = switch (owner.name) {
      'PipelineFunctions' when element.isStatic => _Form.static,
      'Expression' when element.isStatic => _Form.expression,
      _ when !element.isStatic && _isPipelineExpression(owner) => _Form.fluent,
      _ => null,
    };
    if (form != null) _members.add(_Member(form, element, node.body));
  }

  static bool _isPipelineExpression(ClassElement element) {
    return element.name == 'PipelineExpression' ||
        element.allSupertypes.any(
          (type) => type.element.name == 'PipelineExpression',
        );
  }
}

/// Explains why [member] is not a single call forwarding its parameters to
/// [target], or returns null when it is.
///
/// The call must pass `this` first when a fluent member forwards to a static
/// or top-level one, followed by each of [member]'s parameters, unchanged and
/// in order. A counterpart that takes its operands as one `Iterable` may
/// receive them packed, in the same order, into a list literal such as
/// `[this, second, ...others]`. Each parameter passed straight through must
/// match its counterpart's optionality and default value, and the counterpart
/// must not take parameters that [member] leaves out.
String? _forwardingProblem(_Member member, _Member target) {
  final call = _singleExpression(member.body);
  if (call is! ast.MethodInvocation ||
      !target.isElement(call.methodName.element)) {
    return 'its body must be a single call to ${target.label}, but it is '
        '`${_source(member.body)}`';
  }
  if (target.form == _Form.fluent &&
      call.target != null &&
      call.target is! ast.ThisExpression) {
    return 'it must call ${target.label} on `this`';
  }

  final parameters = member.element.formalParameters;
  FormalParameterElement? parameterOf(ast.AstNode node) {
    if (node is! ast.SimpleIdentifier) return null;
    final element = node.element;
    return element is FormalParameterElement
        ? _matching(element, parameters)
        : null;
  }

  final targetParameters = target.element.formalParameters;
  final bound = <FormalParameterElement>{};
  final passed = <String>[];

  for (final argument in call.argumentList.arguments) {
    final targetParameter = _matching(
      argument.correspondingParameter,
      targetParameters,
    );
    if (targetParameter == null) {
      return 'argument `${argument.toSource()}` does not bind to a parameter '
          'of ${target.label}';
    }
    bound.add(targetParameter);

    // A named argument is `name: value`, whose value is its last child. This
    // holds across analyzer versions, which model named arguments as
    // different node types.
    final value = targetParameter.isNamed
        ? argument.childEntities.last
        : argument;

    if (value is ast.ThisExpression) {
      passed.add('this');
    } else if (value is ast.ListLiteral) {
      for (final element in value.elements) {
        final packed = switch (element) {
          ast.ThisExpression() => 'this',
          ast.SpreadElement(isNullAware: false, :final expression) =>
            parameterOf(expression)?.name,
          _ => switch (parameterOf(element)) {
            final parameter? when parameter.isRequiredPositional =>
              parameter.name,
            _ => null,
          },
        };
        if (packed == null) {
          return 'list argument element `${element.toSource()}` must be '
              '`this`, a required parameter, or a spread parameter';
        }
        passed.add(packed);
      }
    } else {
      final parameter = value is ast.AstNode ? parameterOf(value) : null;
      if (parameter == null ||
          (targetParameter.isNamed && parameter.name != targetParameter.name)) {
        return 'argument `${argument.toSource()}` must pass one of its '
            'parameters through unchanged';
      }
      final mismatch = _parameterMismatch(parameter, targetParameter, target);
      if (mismatch != null) return mismatch;
      passed.add(parameter.name!);
    }
  }

  final dropped = [
    for (final parameter in targetParameters)
      if (!bound.contains(parameter)) parameter.name,
  ];
  if (dropped.isNotEmpty) {
    return '${target.label} also takes ${dropped.join(', ')}, which it does '
        'not expose';
  }

  final expected = [
    if (member.form == _Form.fluent && target.form != _Form.fluent) 'this',
    for (final parameter in parameters) parameter.name!,
  ];
  if (passed.join(', ') != expected.join(', ')) {
    return 'it passes (${passed.join(', ')}) but must pass '
        '(${expected.join(', ')}), in that order';
  }
  return null;
}

/// The parameter of [parameters] that [parameter] refers to.
FormalParameterElement? _matching(
  FormalParameterElement? parameter,
  List<FormalParameterElement> parameters,
) {
  for (final candidate in parameters) {
    if (candidate.baseElement == parameter?.baseElement) return candidate;
  }
  return null;
}

/// Explains how [parameter] differs from the [targetParameter] of [target] it
/// is passed to, or returns null when they match.
String? _parameterMismatch(
  FormalParameterElement parameter,
  FormalParameterElement targetParameter,
  _Member target,
) {
  String kind(FormalParameterElement parameter) {
    if (parameter.isRequiredPositional) return 'required';
    if (parameter.isOptionalPositional) return 'optional';
    return parameter.isRequiredNamed ? 'required named' : 'optional named';
  }

  if (kind(parameter) != kind(targetParameter)) {
    return '`${parameter.name}` is ${kind(parameter)} but '
        '${target.label}\'s `${targetParameter.name}` is '
        '${kind(targetParameter)}';
  }
  if (parameter.defaultValueCode != targetParameter.defaultValueCode) {
    return '`${parameter.name}` defaults to `${parameter.defaultValueCode}` '
        'but ${target.label}\'s `${targetParameter.name}` defaults to '
        '`${targetParameter.defaultValueCode}`';
  }
  return null;
}

/// The expression [body] evaluates, when it is `=> e` or `{ return e; }`.
ast.Expression? _singleExpression(ast.FunctionBody body) {
  return switch (body) {
    ast.ExpressionFunctionBody(:final expression) => expression,
    ast.BlockFunctionBody(
      block: ast.Block(statements: [ast.ReturnStatement(:final expression)]),
    ) =>
      expression,
    _ => null,
  };
}

String _source(ast.AstNode node) {
  return node.toSource().replaceAll(RegExp(r'\s+'), ' ');
}

const _projectId = 'test-project';

class _MockFirestoreHttpClient extends Mock implements FirestoreHttpClient {}

/// One call to a Pipeline function, written in several of its forms.
///
/// [forms] maps each form's name (a [_Form] name, or `alias` for a fluent
/// member forwarding to a differently named one) to a builder returning the
/// [PipelineExpression] or [PipelineOrdering] that form produces.
final class _Call {
  _Call(this.description, this.forms);

  final String description;
  final Map<String, Object Function()> forms;
}

/// A receiver that is an expression rather than a plain field.
final _expression = field('score').ifAbsent(0);

/// A boolean receiver.
final _condition = field('score').greaterThan(10);

/// [description] called on a field name and on an expression.
///
/// The static and top-level forms take the receiver as their first argument;
/// the fluent and alias forms are called on it. Pass [fieldName] false for
/// functions whose first argument is a value rather than a field.
List<_Call> _on(
  String description, {
  Object Function(Object? receiver)? static,
  Object Function(Object? receiver)? topLevel,
  Object Function(PipelineExpression receiver)? fluent,
  Object Function(PipelineExpression receiver)? alias,
  bool fieldName = true,
}) {
  _Call call(String on, Object? argument, PipelineExpression receiver) {
    return _Call('$description on $on', {
      if (static case final build?) 'static': () => build(argument),
      if (topLevel case final build?) 'topLevel': () => build(argument),
      if (fluent case final build?) 'fluent': () => build(receiver),
      if (alias case final build?) 'alias': () => build(receiver),
    });
  }

  return [
    if (fieldName) call('a field name', 'score', field('score')),
    call('an expression', _expression, _expression),
  ];
}

/// A function of its receiver alone.
List<_Call> _unary(
  Object Function(Object? receiver) static,
  Object Function(PipelineExpression receiver) fluent, {
  bool fieldName = true,
}) {
  return _on('called', static: static, fluent: fluent, fieldName: fieldName);
}

/// A function of its receiver and one argument, called with each of
/// [arguments].
List<_Call> _binary(
  Object Function(Object? receiver, Object? argument) static,
  Object Function(PipelineExpression receiver, Object? argument) fluent, {
  Object Function(Object? receiver, Object? argument)? topLevel,
  List<Object?>? arguments,
  bool fieldName = true,
}) {
  return [
    for (final argument in arguments ?? [2, 'text', field('other')])
      ..._on(
        'with $argument',
        static: (receiver) => static(receiver, argument),
        topLevel: topLevel == null
            ? null
            : (receiver) => topLevel(receiver, argument),
        fluent: (receiver) => fluent(receiver, argument),
        fieldName: fieldName,
      ),
  ];
}

/// A comparison, which also has a top-level form.
List<_Call> _comparison(
  Object Function(Object? left, Object? right) static,
  Object Function(Object? left, Object? right) topLevel,
  Object Function(PipelineExpression left, Object? right) fluent,
) {
  return _binary(
    static,
    fluent,
    topLevel: topLevel,
    arguments: [2, 'text', field('other'), null],
  );
}

/// A function of a boolean receiver.
List<_Call> _onCondition(
  String description, {
  required Object Function(PipelineBooleanExpression condition) static,
  Object Function(PipelineBooleanExpression condition)? topLevel,
  required Object Function(PipelineBooleanExpression condition) fluent,
}) {
  return [
    _Call(description, {
      'static': () => static(_condition),
      if (topLevel case final build?) 'topLevel': () => build(_condition),
      'fluent': () => fluent(_condition),
    }),
  ];
}

/// A list holding an expression, sent as an `array(...)` function.
final _mixedList = [1, field('other')];

/// Every Pipeline function pair and fluent alias, written in each form.
final _behaviour = <String, List<_Call>>{
  // Comparisons.
  'equal': _comparison(PipelineFunctions.equal, equal, (e, v) => e.equal(v)),
  'notEqual': _comparison(
    PipelineFunctions.notEqual,
    notEqual,
    (e, v) => e.notEqual(v),
  ),
  'lessThan': _comparison(
    PipelineFunctions.lessThan,
    lessThan,
    (e, v) => e.lessThan(v),
  ),
  'lessThanOrEqual': _comparison(
    PipelineFunctions.lessThanOrEqual,
    lessThanOrEqual,
    (e, v) => e.lessThanOrEqual(v),
  ),
  'greaterThan': _comparison(
    PipelineFunctions.greaterThan,
    greaterThan,
    (e, v) => e.greaterThan(v),
  ),
  'greaterThanOrEqual': _comparison(
    PipelineFunctions.greaterThanOrEqual,
    greaterThanOrEqual,
    (e, v) => e.greaterThanOrEqual(v),
  ),
  'equalAny': _binary(
    PipelineFunctions.equalAny,
    (e, v) => e.equalAny(v),
    arguments: [
      [1, 2],
      _mixedList,
      field('options'),
    ],
  ),
  'notEqualAny': _binary(
    PipelineFunctions.notEqualAny,
    (e, v) => e.notEqualAny(v),
    arguments: [
      [1, 2],
      _mixedList,
      field('options'),
    ],
  ),

  // Logic.
  'and': [
    _Call('of two conditions', {
      'static': () => PipelineFunctions.and([_condition, field('b').exists()]),
      'topLevel': () => and([_condition, field('b').exists()]),
    }),
  ],
  'or': [
    _Call('of two conditions', {
      'static': () => PipelineFunctions.or([_condition, field('b').exists()]),
      'topLevel': () => or([_condition, field('b').exists()]),
    }),
  ],
  'not': _onCondition(
    'of a condition',
    static: PipelineFunctions.not,
    topLevel: not,
    fluent: (c) => c.not(),
  ),
  'countIf': _onCondition(
    'of a condition',
    static: PipelineFunctions.countIf,
    fluent: (c) => c.countIf(),
  ),
  'conditional': [
    ..._onCondition(
      'with literals',
      static: (c) => PipelineFunctions.conditional(c, 1, 'text'),
      fluent: (c) => c.conditional(1, 'text'),
    ),
    ..._onCondition(
      'with expressions',
      static: (c) => PipelineFunctions.conditional(c, field('a'), _mixedList),
      fluent: (c) => c.conditional(field('a'), _mixedList),
    ),
  ],
  'exists': _unary(PipelineFunctions.exists, (e) => e.exists()),
  'isAbsent': _unary(PipelineFunctions.isAbsent, (e) => e.isAbsent()),
  'isError': _unary(
    PipelineFunctions.isError,
    (e) => e.isError(),
    fieldName: false,
  ),
  'ifAbsent': _binary(PipelineFunctions.ifAbsent, (e, v) => e.ifAbsent(v)),
  'ifNull': _binary(PipelineFunctions.ifNull, (e, v) => e.ifNull(v)),
  'ifError': _binary(
    PipelineFunctions.ifError,
    (e, v) => e.ifError(v),
    fieldName: false,
  ),
  'coalesce': [
    ..._on(
      'with one replacement',
      static: (r) => PipelineFunctions.coalesce(r, 0),
      fluent: (e) => e.coalesce(0),
    ),
    ..._on(
      'with more replacements',
      static: (r) => PipelineFunctions.coalesce(r, field('b'), [0, 'text']),
      fluent: (e) => e.coalesce(field('b'), [0, 'text']),
    ),
  ],
  'logicalMaximum': [
    ..._on(
      'with two operands',
      static: (r) => PipelineFunctions.logicalMaximum(r, 1),
      fluent: (e) => e.logicalMaximum(1),
    ),
    ..._on(
      'with more operands',
      static: (r) => PipelineFunctions.logicalMaximum(r, 1, [field('b'), 3]),
      fluent: (e) => e.logicalMaximum(1, [field('b'), 3]),
    ),
  ],
  'logicalMinimum': [
    ..._on(
      'with two operands',
      static: (r) => PipelineFunctions.logicalMinimum(r, 1),
      fluent: (e) => e.logicalMinimum(1),
    ),
    ..._on(
      'with more operands',
      static: (r) => PipelineFunctions.logicalMinimum(r, 1, [field('b'), 3]),
      fluent: (e) => e.logicalMinimum(1, [field('b'), 3]),
    ),
  ],

  // Arithmetic.
  'add': _binary(PipelineFunctions.add, (e, v) => e.add(v)),
  'subtract': _binary(PipelineFunctions.subtract, (e, v) => e.subtract(v)),
  'multiply': _binary(PipelineFunctions.multiply, (e, v) => e.multiply(v)),
  'divide': _binary(PipelineFunctions.divide, (e, v) => e.divide(v)),
  'mod': _binary(PipelineFunctions.mod, (e, v) => e.mod(v)),
  'pow': _binary(PipelineFunctions.pow, (e, v) => e.pow(v)),
  'abs': _unary(PipelineFunctions.abs, (e) => e.abs()),
  'ceil': _unary(PipelineFunctions.ceil, (e) => e.ceil()),
  'floor': _unary(PipelineFunctions.floor, (e) => e.floor()),
  'sqrt': _unary(PipelineFunctions.sqrt, (e) => e.sqrt()),
  'exp': _unary(PipelineFunctions.exp, (e) => e.exp()),
  'ln': _unary(PipelineFunctions.ln, (e) => e.ln()),
  'log10': _unary(PipelineFunctions.log10, (e) => e.log10()),
  'log': [
    ..._unary(PipelineFunctions.log, (e) => e.log()),
    ..._binary(PipelineFunctions.log, (e, v) => e.log(v)),
  ],
  'round': [
    ..._unary(PipelineFunctions.round, (e) => e.round()),
    ..._binary(PipelineFunctions.round, (e, v) => e.round(v)),
  ],
  'trunc': [
    ..._unary(PipelineFunctions.trunc, (e) => e.trunc()),
    ..._binary(PipelineFunctions.trunc, (e, v) => e.trunc(v)),
  ],

  // Aggregates.
  'count': _unary(PipelineFunctions.count, (e) => e.count()),
  'countDistinct': _unary(
    PipelineFunctions.countDistinct,
    (e) => e.countDistinct(),
  ),
  'sum': _unary(PipelineFunctions.sum, (e) => e.sum()),
  'average': _unary(PipelineFunctions.average, (e) => e.average()),
  'minimum': _unary(PipelineFunctions.minimum, (e) => e.minimum()),
  'maximum': _unary(PipelineFunctions.maximum, (e) => e.maximum()),
  'first': _unary(PipelineFunctions.first, (e) => e.first()),
  'last': _unary(PipelineFunctions.last, (e) => e.last()),
  'arrayAgg': _unary(PipelineFunctions.arrayAgg, (e) => e.arrayAgg()),
  'arrayAggDistinct': _unary(
    PipelineFunctions.arrayAggDistinct,
    (e) => e.arrayAggDistinct(),
  ),

  // Arrays.
  'array': [
    _Call('of literals and expressions', {
      'static': () => PipelineFunctions.array(_mixedList),
      'expression': () => Expression.array(_mixedList),
    }),
  ],
  'arrayConcat': _binary(
    (r, v) => PipelineFunctions.arrayConcat([r, v]),
    (e, v) => e.arrayConcat(v),
    arguments: [
      ['text'],
      _mixedList,
      field('other'),
    ],
  ),
  'arrayConcatMultiple': _on(
    'with two arrays',
    static: (r) => PipelineFunctions.arrayConcat([r, _mixedList, field('b')]),
    alias: (e) => e.arrayConcatMultiple([_mixedList, field('b')]),
  ),
  'arrayContains': _binary(
    PipelineFunctions.arrayContains,
    (e, v) => e.arrayContains(v),
  ),
  'arrayContainsAll': _binary(
    PipelineFunctions.arrayContainsAll,
    (e, v) => e.arrayContainsAll(v),
    arguments: [
      ['a', 'b'],
      _mixedList,
      field('wanted'),
    ],
  ),
  'arrayContainsAllFrom': _on(
    'with an array expression',
    static: (r) => PipelineFunctions.arrayContainsAll(r, field('wanted')),
    alias: (e) => e.arrayContainsAllFrom(field('wanted')),
  ),
  'arrayContainsAny': _binary(
    PipelineFunctions.arrayContainsAny,
    (e, v) => e.arrayContainsAny(v),
    arguments: [
      ['a', 'b'],
      _mixedList,
      field('wanted'),
    ],
  ),
  'arrayFilter': _on(
    'with a predicate',
    static: (r) => PipelineFunctions.arrayFilter(
      r,
      'tag',
      variable('tag').notEqual('draft'),
    ),
    fluent: (e) => e.arrayFilter('tag', variable('tag').notEqual('draft')),
  ),
  'arrayTransform': _on(
    'with a transform',
    static: (r) =>
        PipelineFunctions.arrayTransform(r, 'n', variable('n').add(1)),
    fluent: (e) => e.arrayTransform('n', variable('n').add(1)),
  ),
  'arrayTransformWithIndex': _on(
    'with a transform',
    static: (r) => PipelineFunctions.arrayTransformWithIndex(
      r,
      'n',
      'i',
      variable('n').add(variable('i')),
    ),
    fluent: (e) =>
        e.arrayTransformWithIndex('n', 'i', variable('n').add(variable('i'))),
  ),
  'arrayGet': _binary(PipelineFunctions.arrayGet, (e, v) => e.arrayGet(v)),
  'arrayFirst': _unary(PipelineFunctions.arrayFirst, (e) => e.arrayFirst()),
  'arrayFirstN': _binary(
    PipelineFunctions.arrayFirstN,
    (e, v) => e.arrayFirstN(v),
  ),
  'arrayLast': _unary(PipelineFunctions.arrayLast, (e) => e.arrayLast()),
  'arrayLastN': _binary(
    PipelineFunctions.arrayLastN,
    (e, v) => e.arrayLastN(v),
  ),
  'arrayIndexOf': _binary(
    PipelineFunctions.arrayIndexOf,
    (e, v) => e.arrayIndexOf(v),
  ),
  'arrayIndexOfAll': _binary(
    PipelineFunctions.arrayIndexOfAll,
    (e, v) => e.arrayIndexOfAll(v),
  ),
  'arrayLastIndexOf': _binary(
    PipelineFunctions.arrayLastIndexOf,
    (e, v) => e.arrayLastIndexOf(v),
  ),
  'arrayLength': _unary(PipelineFunctions.arrayLength, (e) => e.arrayLength()),
  'arrayReverse': _unary(
    PipelineFunctions.arrayReverse,
    (e) => e.arrayReverse(),
  ),
  'arrayMaximum': _unary(
    PipelineFunctions.arrayMaximum,
    (e) => e.arrayMaximum(),
  ),
  'arrayMaximumN': _binary(
    PipelineFunctions.arrayMaximumN,
    (e, v) => e.arrayMaximumN(v),
  ),
  'arrayMinimum': _unary(
    PipelineFunctions.arrayMinimum,
    (e) => e.arrayMinimum(),
  ),
  'arrayMinimumN': _binary(
    PipelineFunctions.arrayMinimumN,
    (e, v) => e.arrayMinimumN(v),
  ),
  'arraySum': _unary(PipelineFunctions.arraySum, (e) => e.arraySum()),
  'arraySlice': [
    ..._binary(PipelineFunctions.arraySlice, (e, v) => e.arraySlice(v)),
    ..._on(
      'with a length',
      static: (r) => PipelineFunctions.arraySlice(r, 1, 2),
      fluent: (e) => e.arraySlice(1, 2),
    ),
    ..._on(
      'with expressions',
      static: (r) => PipelineFunctions.arraySlice(r, field('o'), field('l')),
      fluent: (e) => e.arraySlice(field('o'), field('l')),
    ),
  ],

  // Maps.
  'mapGet': _binary(PipelineFunctions.mapGet, (e, v) => e.mapGet(v)),
  'mapGetLiteral': _on(
    'with a key',
    fluent: (e) => e.mapGet('key'),
    alias: (e) => e.mapGetLiteral('key'),
    fieldName: false,
  ),
  'getField': _binary(PipelineFunctions.getField, (e, v) => e.getField(v)),
  'mapSet': [
    ..._on(
      'with one entry',
      static: (r) => PipelineFunctions.mapSet(r, ['key', 1]),
      fluent: (e) => e.mapSet('key', 1),
    ),
    ..._on(
      'with more entries',
      static: (r) => PipelineFunctions.mapSet(r, [
        field('key'),
        _mixedList,
        'other',
        {'a': field('a')},
      ]),
      fluent: (e) => e.mapSet(field('key'), _mixedList, [
        'other',
        {'a': field('a')},
      ]),
    ),
  ],
  'mapRemove': _binary(
    PipelineFunctions.mapRemove,
    (e, v) => e.mapRemove(v),
    arguments: ['key', field('key')],
  ),
  'mapMerge': _on(
    'with two maps',
    static: (r) => PipelineFunctions.mapMerge([
      r,
      {'a': 1},
      {'b': field('b')},
    ]),
    fluent: (e) => e.mapMerge([
      {'a': 1},
      {'b': field('b')},
    ]),
  ),
  'mapKeys': _unary(PipelineFunctions.mapKeys, (e) => e.mapKeys()),
  'mapValues': _unary(PipelineFunctions.mapValues, (e) => e.mapValues()),
  'mapEntries': _unary(PipelineFunctions.mapEntries, (e) => e.mapEntries()),

  // Strings.
  'join': _binary(PipelineFunctions.join, (e, v) => e.join(v)),
  'joinLiteral': _on(
    'with a delimiter',
    fluent: (e) => e.join(', '),
    alias: (e) => e.joinLiteral(', '),
    fieldName: false,
  ),
  'split': _binary(PipelineFunctions.split, (e, v) => e.split(v)),
  'splitLiteral': _on(
    'with a delimiter',
    fluent: (e) => e.split(','),
    alias: (e) => e.splitLiteral(','),
    fieldName: false,
  ),
  'byteLength': _unary(PipelineFunctions.byteLength, (e) => e.byteLength()),
  'charLength': _unary(PipelineFunctions.charLength, (e) => e.charLength()),
  'length': _unary(PipelineFunctions.length, (e) => e.length()),
  'reverse': _unary(PipelineFunctions.reverse, (e) => e.reverse()),
  'stringReverse': _unary(
    PipelineFunctions.stringReverse,
    (e) => e.stringReverse(),
  ),
  'concat': [
    ..._on(
      'with one operand',
      static: (r) => PipelineFunctions.concat(r, field('b')),
      fluent: (e) => e.concat([field('b')]),
    ),
    ..._on(
      'with more operands',
      static: (r) => PipelineFunctions.concat(r, ' ', [_mixedList]),
      fluent: (e) => e.concat([' ', _mixedList]),
    ),
  ],
  'stringConcat': _on(
    'with two operands',
    static: (r) => PipelineFunctions.stringConcat([r, ' ', field('b')]),
    fluent: (e) => e.stringConcat([' ', field('b')]),
  ),
  'toLowerCase': _on(
    'called',
    static: PipelineFunctions.toLower,
    alias: (e) => e.toLowerCase(),
  ),
  'toUpperCase': _on(
    'called',
    static: PipelineFunctions.toUpper,
    alias: (e) => e.toUpperCase(),
  ),
  'trim': [
    ..._unary(PipelineFunctions.trim, (e) => e.trim()),
    ..._binary(PipelineFunctions.trim, (e, v) => e.trim(v)),
  ],
  'ltrim': [
    ..._unary(PipelineFunctions.ltrim, (e) => e.ltrim()),
    ..._binary(PipelineFunctions.ltrim, (e, v) => e.ltrim(v)),
  ],
  'rtrim': [
    ..._unary(PipelineFunctions.rtrim, (e) => e.rtrim()),
    ..._binary(PipelineFunctions.rtrim, (e, v) => e.rtrim(v)),
  ],
  'stringIndexOf': _binary(
    PipelineFunctions.stringIndexOf,
    (e, v) => e.stringIndexOf(v),
  ),
  'stringContains': _binary(
    PipelineFunctions.stringContains,
    (e, v) => e.stringContains(v),
  ),
  'stringRepeat': _binary(
    PipelineFunctions.stringRepeat,
    (e, v) => e.stringRepeat(v),
  ),
  'stringReplaceAll': [
    ..._on(
      'with literals',
      static: (r) => PipelineFunctions.stringReplaceAll(r, 'a', 'b'),
      fluent: (e) => e.stringReplaceAll('a', 'b'),
    ),
    ..._on(
      'with expressions',
      static: (r) =>
          PipelineFunctions.stringReplaceAll(r, field('a'), field('b')),
      fluent: (e) => e.stringReplaceAll(field('a'), field('b')),
    ),
  ],
  'stringReplaceAllLiteral': _on(
    'with literals',
    fluent: (e) => e.stringReplaceAll('a', 'b'),
    alias: (e) => e.stringReplaceAllLiteral('a', 'b'),
    fieldName: false,
  ),
  'stringReplaceOne': [
    ..._on(
      'with literals',
      static: (r) => PipelineFunctions.stringReplaceOne(r, 'a', 'b'),
      fluent: (e) => e.stringReplaceOne('a', 'b'),
    ),
    ..._on(
      'with expressions',
      static: (r) =>
          PipelineFunctions.stringReplaceOne(r, field('a'), field('b')),
      fluent: (e) => e.stringReplaceOne(field('a'), field('b')),
    ),
  ],
  'stringReplaceOneLiteral': _on(
    'with literals',
    fluent: (e) => e.stringReplaceOne('a', 'b'),
    alias: (e) => e.stringReplaceOneLiteral('a', 'b'),
    fieldName: false,
  ),
  'substring': [
    ..._binary(PipelineFunctions.substring, (e, v) => e.substring(v)),
    ..._on(
      'with a length',
      static: (r) => PipelineFunctions.substring(r, 1, 3),
      fluent: (e) => e.substring(1, 3),
    ),
    ..._on(
      'with expressions',
      static: (r) => PipelineFunctions.substring(r, field('p'), field('l')),
      fluent: (e) => e.substring(field('p'), field('l')),
    ),
  ],
  'substringLiteral': [
    ..._on(
      'with a position',
      fluent: (e) => e.substring(1),
      alias: (e) => e.substringLiteral(1),
      fieldName: false,
    ),
    ..._on(
      'with a length',
      fluent: (e) => e.substring(1, 3),
      alias: (e) => e.substringLiteral(1, 3),
      fieldName: false,
    ),
  ],
  'startsWith': _binary(
    PipelineFunctions.startsWith,
    (e, v) => e.startsWith(v),
  ),
  'endsWith': _binary(PipelineFunctions.endsWith, (e, v) => e.endsWith(v)),
  'like': _binary(PipelineFunctions.like, (e, v) => e.like(v)),
  'regexContains': _binary(
    PipelineFunctions.regexContains,
    (e, v) => e.regexContains(v),
  ),
  'regexMatch': _binary(
    PipelineFunctions.regexMatch,
    (e, v) => e.regexMatch(v),
  ),
  'regexFind': _binary(PipelineFunctions.regexFind, (e, v) => e.regexFind(v)),
  'regexFindAll': _binary(
    PipelineFunctions.regexFindAll,
    (e, v) => e.regexFindAll(v),
  ),

  // Timestamps.
  'timestampTruncate': [
    ..._binary(
      PipelineFunctions.timestampTruncate,
      (e, v) => e.timestampTruncate(v),
      arguments: ['day', field('granularity')],
    ),
    ..._on(
      'with a timezone',
      static: (r) => PipelineFunctions.timestampTruncate(r, 'day', 'UTC'),
      fluent: (e) => e.timestampTruncate('day', 'UTC'),
    ),
  ],
  'timestampExtract': [
    ..._binary(
      PipelineFunctions.timestampExtract,
      (e, v) => e.timestampExtract(v),
      arguments: ['year', field('part')],
    ),
    ..._on(
      'with a timezone',
      static: (r) => PipelineFunctions.timestampExtract(r, 'year', 'UTC'),
      fluent: (e) => e.timestampExtract('year', 'UTC'),
    ),
  ],
  'timestampAdd': [
    ..._on(
      'with literals',
      static: (r) => PipelineFunctions.timestampAdd(r, 'day', 1),
      fluent: (e) => e.timestampAdd('day', 1),
    ),
    ..._on(
      'with expressions',
      static: (r) =>
          PipelineFunctions.timestampAdd(r, field('unit'), field('amount')),
      fluent: (e) => e.timestampAdd(field('unit'), field('amount')),
    ),
  ],
  'timestampSubtract': [
    ..._on(
      'with literals',
      static: (r) => PipelineFunctions.timestampSubtract(r, 'day', 1),
      fluent: (e) => e.timestampSubtract('day', 1),
    ),
    ..._on(
      'with expressions',
      static: (r) => PipelineFunctions.timestampSubtract(
        r,
        field('unit'),
        field('amount'),
      ),
      fluent: (e) => e.timestampSubtract(field('unit'), field('amount')),
    ),
  ],
  'timestampDiff': [
    ..._on(
      'with a start field name',
      static: (r) => PipelineFunctions.timestampDiff(r, 'createdAt', 'day'),
      fluent: (e) => e.timestampDiff('createdAt', 'day'),
    ),
    ..._on(
      'with expressions',
      static: (r) =>
          PipelineFunctions.timestampDiff(r, _expression, field('unit')),
      fluent: (e) => e.timestampDiff(_expression, field('unit')),
    ),
  ],
  'timestampToUnixMicros': _unary(
    PipelineFunctions.timestampToUnixMicros,
    (e) => e.timestampToUnixMicros(),
  ),
  'timestampToUnixMillis': _unary(
    PipelineFunctions.timestampToUnixMillis,
    (e) => e.timestampToUnixMillis(),
  ),
  'timestampToUnixSeconds': _unary(
    PipelineFunctions.timestampToUnixSeconds,
    (e) => e.timestampToUnixSeconds(),
  ),
  'unixMicrosToTimestamp': _unary(
    PipelineFunctions.unixMicrosToTimestamp,
    (e) => e.unixMicrosToTimestamp(),
  ),
  'unixMillisToTimestamp': _unary(
    PipelineFunctions.unixMillisToTimestamp,
    (e) => e.unixMillisToTimestamp(),
  ),
  'unixSecondsToTimestamp': _unary(
    PipelineFunctions.unixSecondsToTimestamp,
    (e) => e.unixSecondsToTimestamp(),
  ),

  // References.
  'collectionId': _unary(
    PipelineFunctions.collectionId,
    (e) => e.collectionId(),
  ),
  'documentId': _unary(
    PipelineFunctions.documentId,
    (e) => e.documentId(),
    fieldName: false,
  ),
  'parent': _unary(
    PipelineFunctions.parent,
    (e) => e.parent(),
    fieldName: false,
  ),
  'referenceSlice': [
    ..._on(
      'with literals',
      static: (r) => PipelineFunctions.referenceSlice(r, 0, 2),
      fluent: (e) => e.referenceSlice(0, 2),
    ),
    ..._on(
      'with expressions',
      static: (r) =>
          PipelineFunctions.referenceSlice(r, field('o'), field('l')),
      fluent: (e) => e.referenceSlice(field('o'), field('l')),
    ),
  ],

  // Types.
  'type': _unary(PipelineFunctions.type, (e) => e.type()),
  'isType': _binary(
    PipelineFunctions.isType,
    (e, v) => e.isType(v),
    arguments: ['string', PipelineValueType.double],
  ),

  // Vectors and geo points.
  'cosineDistance': _binary(
    PipelineFunctions.cosineDistance,
    (e, v) => e.cosineDistance(v),
    arguments: _vectors,
  ),
  'dotProduct': _binary(
    PipelineFunctions.dotProduct,
    (e, v) => e.dotProduct(v),
    arguments: _vectors,
  ),
  'euclideanDistance': _binary(
    PipelineFunctions.euclideanDistance,
    (e, v) => e.euclideanDistance(v),
    arguments: _vectors,
  ),
  'vectorLength': _unary(
    PipelineFunctions.vectorLength,
    (e) => e.vectorLength(),
  ),
  'geoDistance': _binary(
    PipelineFunctions.geoDistance,
    (e, v) => e.geoDistance(v),
    arguments: [GeoPoint(latitude: 1, longitude: 2), field('location')],
  ),

  // Expressions with no receiver.
  'field': [
    _Call('of a path', {
      'expression': () => Expression.field('metadata.lang'),
      'topLevel': () => field('metadata.lang'),
    }),
  ],
  'constant': [
    for (final value in <Object?>[
      1,
      'text',
      null,
      [1, 2],
    ])
      _Call('of $value', {
        'expression': () => Expression.constant(value),
        'topLevel': () => constant(value),
      }),
  ],
  'variable': [
    _Call('of a name', {
      'expression': () => Expression.variable('tag'),
      'topLevel': () => variable('tag'),
    }),
  ],
  'raw': [
    _Call('without options', {
      'static': () => PipelineFunctions.raw('fn', [1, field('a')]),
      'expression': () => Expression.raw('fn', [1, field('a')]),
    }),
    _Call('with options', {
      'static': () =>
          PipelineFunctions.raw('fn', [field('a')], options: {'mode': 'fast'}),
      'expression': () =>
          Expression.raw('fn', [field('a')], options: {'mode': 'fast'}),
    }),
  ],
  'currentDocument': [
    _Call('called', {
      'static': PipelineFunctions.currentDocument,
      'topLevel': currentDocument,
    }),
  ],
  'score': [
    _Call('called', {'static': PipelineFunctions.score, 'topLevel': score}),
  ],
  'documentMatches': [
    for (final query in <Object?>['dart', field('query')])
      _Call('with $query', {
        'static': () => PipelineFunctions.documentMatches(query),
        'topLevel': () => documentMatches(query),
      }),
  ],

  // Orderings.
  'ascending': _on(
    'called',
    topLevel: (r) => ascending(r!),
    fluent: (e) => e.ascending(),
  ),
  'descending': _on(
    'called',
    topLevel: (r) => descending(r!),
    fluent: (e) => e.descending(),
  ),
};

/// Vector arguments: a list of numbers, a vector value and an expression.
final _vectors = <Object?>[
  [1.0, 2.0],
  FieldValue.vector([1.0, 2.0]),
  field('other'),
];
