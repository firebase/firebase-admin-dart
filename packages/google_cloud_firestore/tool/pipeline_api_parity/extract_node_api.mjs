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

// Extracts the Pipelines API of the Node.js Firestore SDK into a JSON
// snapshot that test/pipeline_api_parity_test.dart compares the Dart API
// against. See README.md in this directory.
//
// The declarations are read syntactically with the TypeScript compiler API
// (no type checking), so the output only depends on the pinned
// @google-cloud/firestore and typescript versions and on this script.

import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import ts from 'typescript';

const toolDir = path.dirname(fileURLToPath(import.meta.url));
const outputPath = path.resolve(
  toolDir,
  '../../test/fixtures/node_pipeline_api.json',
);

const require = createRequire(import.meta.url);
const packageJsonPath = require.resolve('@google-cloud/firestore/package.json');
const packageDir = path.dirname(packageJsonPath);
const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
const pinnedVersion = JSON.parse(
  fs.readFileSync(path.join(toolDir, 'package.json'), 'utf8'),
).dependencies['@google-cloud/firestore'];
if (packageJson.version !== pinnedVersion) {
  throw new Error(
    `Installed @google-cloud/firestore ${packageJson.version} does not match ` +
      `the pinned ${pinnedVersion}. Run \`npm ci\` in ${toolDir}.`,
  );
}

const typingsRelativePath = 'types/firestore.d.ts';
const runtimeIndexRelativePath = 'build/src/pipelines/index.js';

// The simplified kind of the classes that need one; any other class is named
// after itself (`VectorValue` is `vectorValue`).
const classKinds = new Map([
  ['Expression', 'expression'],
  ['FunctionExpression', 'expression'],
  ['Constant', 'expression'],
  ['BooleanExpression', 'booleanExpression'],
  ['Field', 'field'],
  ['AggregateFunction', 'aggregateFunction'],
  ['AliasedExpression', 'aliasedExpression'],
  ['AliasedAggregate', 'aliasedAggregate'],
  ['Selectable', 'selectable'],
  ['Ordering', 'ordering'],
  ['Pipeline', 'pipeline'],
  ['PipelineSnapshot', 'pipelineSnapshot'],
  ['PipelineResult', 'pipelineResult'],
  ['PipelineSource', 'pipelineSource'],
  ['ExplainStats', 'explainStats'],
  ['Buffer', 'bytes'],
  ['Uint8Array', 'bytes'],
]);

function readSource(relativePath, scriptKind) {
  const filePath = path.join(packageDir, relativePath);
  return ts.createSourceFile(
    filePath,
    fs.readFileSync(filePath, 'utf8'),
    ts.ScriptTarget.Latest,
    /* setParentNodes */ true,
    scriptKind,
  );
}

function isExported(node) {
  return (ts.getCombinedModifierFlags(node) & ts.ModifierFlags.Export) !== 0;
}

function hasModifier(node, kind) {
  return (node.modifiers ?? []).some(modifier => modifier.kind === kind);
}

function nameOf(node) {
  return node.name && ts.isIdentifier(node.name)
    ? node.name.text
    : node.name?.getText();
}

const printer = ts.createPrinter({removeComments: true});

/** Comment-free, single-line text of a type, for humans reading diffs. */
function typeText(node) {
  if (!node) return null;
  return printer
    .printNode(ts.EmitHint.Unspecified, node, node.getSourceFile())
    .replace(/\s+/g, ' ')
    .replace(/([({[<]) /g, '$1')
    .replace(/,? ([)}\]>])/g, '$1')
    .replace(/^\| /, '');
}

function sorted(values) {
  return [...new Set(values)].sort();
}

// --- Locate the Pipelines namespace ---------------------------------------

const typings = readSource(typingsRelativePath, ts.ScriptKind.TS);

function findNamespace(statements, name) {
  for (const statement of statements) {
    if (
      ts.isModuleDeclaration(statement) &&
      statement.name.text === name &&
      statement.body &&
      ts.isModuleBlock(statement.body)
    ) {
      return statement.body;
    }
  }
  throw new Error(`Namespace ${name} not found in ${typingsRelativePath}.`);
}

const firebaseFirestore = findNamespace(
  typings.statements,
  'FirebaseFirestore',
);
const pipelines = findNamespace(firebaseFirestore.statements, 'Pipelines');

const typeAliases = new Map();
for (const statement of pipelines.statements) {
  if (ts.isTypeAliasDeclaration(statement)) {
    typeAliases.set(statement.name.text, statement);
  }
}

// --- Type simplification ----------------------------------------------------

/** String literal values of [node] when it is a union of string literals. */
function stringLiterals(node, seen = new Set()) {
  if (ts.isParenthesizedTypeNode(node)) return stringLiterals(node.type, seen);
  if (ts.isUnionTypeNode(node)) {
    const values = [];
    for (const member of node.types) {
      const memberValues = stringLiterals(member, seen);
      if (memberValues === null) return null;
      values.push(...memberValues);
    }
    return values;
  }
  if (ts.isLiteralTypeNode(node) && ts.isStringLiteral(node.literal)) {
    return [node.literal.text];
  }
  if (ts.isTypeReferenceNode(node) && ts.isIdentifier(node.typeName)) {
    const alias = typeAliases.get(node.typeName.text);
    if (alias && !seen.has(alias)) {
      seen.add(alias);
      return stringLiterals(alias.type, seen);
    }
  }
  return null;
}

/**
 * Simplifies [node] to a set of kinds such as `expression`, `string`,
 * `array` or `options`, collecting details into [info].
 */
function collectKinds(node, info) {
  if (ts.isParenthesizedTypeNode(node)) return collectKinds(node.type, info);
  if (ts.isUnionTypeNode(node)) {
    for (const member of node.types) collectKinds(member, info);
    return;
  }
  if (ts.isLiteralTypeNode(node) && ts.isStringLiteral(node.literal)) {
    info.kinds.add('literal');
    info.literals.add(node.literal.text);
    return;
  }
  if (
    ts.isTypeReferenceNode(node) &&
    ts.isIdentifier(node.typeName) &&
    typeAliases.has(node.typeName.text) &&
    stringLiterals(node) !== null
  ) {
    // A named string union such as `TimeUnit`; its values are under `types`.
    info.kinds.add('literal');
    info.aliases.add(node.typeName.text);
    return;
  }
  switch (node.kind) {
    case ts.SyntaxKind.StringKeyword:
      info.kinds.add('string');
      return;
    case ts.SyntaxKind.NumberKeyword:
      info.kinds.add('number');
      return;
    case ts.SyntaxKind.BooleanKeyword:
      info.kinds.add('boolean');
      return;
    case ts.SyntaxKind.UnknownKeyword:
    case ts.SyntaxKind.AnyKeyword:
      info.kinds.add('any');
      return;
    case ts.SyntaxKind.VoidKeyword:
      info.kinds.add('void');
      return;
    case ts.SyntaxKind.UndefinedKeyword:
      info.kinds.add('undefined');
      return;
  }
  if (ts.isLiteralTypeNode(node)) {
    if (node.literal.kind === ts.SyntaxKind.NullKeyword) {
      info.kinds.add('null');
    } else if (
      node.literal.kind === ts.SyntaxKind.TrueKeyword ||
      node.literal.kind === ts.SyntaxKind.FalseKeyword
    ) {
      info.kinds.add('boolean');
    } else if (ts.isNumericLiteral(node.literal)) {
      info.kinds.add('number');
    } else {
      info.kinds.add('other');
    }
    return;
  }
  if (ts.isArrayTypeNode(node)) {
    info.kinds.add('array');
    collectKinds(node.elementType, info.elements);
    return;
  }
  if (ts.isTypeLiteralNode(node)) {
    info.kinds.add('map');
    return;
  }
  if (ts.isTypeReferenceNode(node)) {
    const name = node.typeName.getText().replace(/^Pipelines\./, '');
    const typeArguments = node.typeArguments ?? [];
    if (name === 'Array' && typeArguments.length === 1) {
      info.kinds.add('array');
      collectKinds(typeArguments[0], info.elements);
      return;
    }
    if (name === 'Record') {
      info.kinds.add('map');
      return;
    }
    if (name === 'Promise' && typeArguments.length === 1) {
      info.kinds.add('promise');
      collectKinds(typeArguments[0], info.elements);
      return;
    }
    if (classKinds.has(name)) {
      info.kinds.add(classKinds.get(name));
      return;
    }
    if (typeAliases.has(name) && isOptionsType(typeAliases.get(name))) {
      info.kinds.add('options');
      info.options.add(name);
      return;
    }
    const simpleName = name.split('.').pop();
    info.kinds.add(simpleName.charAt(0).toLowerCase() + simpleName.slice(1));
    return;
  }
  info.kinds.add('other');
}

function newInfo() {
  return {
    kinds: new Set(),
    literals: new Set(),
    aliases: new Set(),
    options: new Set(),
    get elements() {
      return (this._elements ??= newInfo());
    },
  };
}

function encodeInfo(info) {
  const result = {kinds: sorted(info.kinds)};
  if (info.literals.size > 0) result.literals = sorted(info.literals);
  if (info.aliases.size > 0) result.aliases = sorted(info.aliases);
  if (info.options.size > 0) result.options = sorted(info.options);
  if (info._elements && info._elements.kinds.size > 0) {
    result.elements = encodeInfo(info._elements);
  }
  return result;
}

function simplifyType(node) {
  if (!node) return {kinds: ['any'], type: null};
  const info = newInfo();
  collectKinds(node, info);
  return {...encodeInfo(info), type: typeText(node)};
}

// --- Signatures -------------------------------------------------------------

function encodeParameter(parameter) {
  const rest = parameter.dotDotDotToken !== undefined;
  let type = simplifyType(parameter.type);
  if (rest) {
    // A rest parameter is typed as an array; each argument is one element.
    if (!type.elements) {
      throw new Error(`Rest parameter without an array type: ${parameter}`);
    }
    type = {...type.elements, type: type.type};
  }
  const result = {name: parameter.name.getText(), ...type};
  // Only flag the exceptions, to keep the snapshot compact.
  if (parameter.questionToken || parameter.initializer) result.optional = true;
  if (rest) result.rest = true;
  return result;
}

function encodeSignature(node) {
  return {
    params: node.parameters.map(encodeParameter),
    returns: simplifyType(node.type),
  };
}

function sortOverloads(overloads) {
  const unique = new Map();
  for (const overload of overloads) {
    unique.set(stableStringify(overload), overload);
  }
  return [...unique.keys()].sort().map(key => unique.get(key));
}

/** Properties of an object type literal, keyed by name. */
function encodeProperties(typeLiteral) {
  const properties = {};
  for (const member of typeLiteral.members) {
    if (ts.isPropertySignature(member)) {
      const property = {
        optional: member.questionToken !== undefined,
        ...simplifyType(member.type),
      };
      if (member.type && ts.isTypeLiteralNode(member.type)) {
        property.properties = encodeProperties(member.type);
      }
      properties[nameOf(member)] = property;
    } else if (ts.isIndexSignatureDeclaration(member)) {
      properties['[key]'] = {optional: true, ...simplifyType(member.type)};
    }
  }
  return properties;
}

/**
 * Whether [alias] is a `*Options` object type, possibly built with
 * `StageOptions & {...}` or `OneOf<{...}>`.
 */
function isOptionsType(alias) {
  return (
    /Options$/.test(alias.name.text) && objectParts(alias.type) !== null
  );
}

/** Splits an object type into its base aliases and literal members. */
function objectParts(node) {
  if (ts.isParenthesizedTypeNode(node)) return objectParts(node.type);
  if (ts.isTypeLiteralNode(node)) {
    return {bases: [], literals: [node], oneOf: []};
  }
  if (ts.isIntersectionTypeNode(node)) {
    const result = {bases: [], literals: [], oneOf: []};
    for (const member of node.types) {
      const part = objectParts(member);
      if (part === null) return null;
      result.bases.push(...part.bases);
      result.literals.push(...part.literals);
      result.oneOf.push(...part.oneOf);
    }
    return result;
  }
  if (ts.isTypeReferenceNode(node) && ts.isIdentifier(node.typeName)) {
    const name = node.typeName.text;
    const typeArguments = node.typeArguments ?? [];
    if (name === 'OneOf' && typeArguments.length === 1) {
      const inner = objectParts(typeArguments[0]);
      if (inner === null) return null;
      return {bases: [], literals: [], oneOf: inner.literals};
    }
    if (typeAliases.has(name) && /Options$/.test(name)) {
      return {bases: [name], literals: [], oneOf: []};
    }
  }
  return null;
}

function encodeTypeAlias(alias) {
  const literals = stringLiterals(alias.type);
  if (literals !== null) {
    return {kind: 'stringUnion', values: sorted(literals)};
  }
  const parts = objectParts(alias.type);
  if (parts !== null) {
    const properties = {};
    for (const literal of parts.literals) {
      Object.assign(properties, encodeProperties(literal));
    }
    const oneOf = [];
    for (const literal of parts.oneOf) {
      const members = encodeProperties(literal);
      // OneOf<T> makes every member optional; exactly one must be given.
      for (const [name, property] of Object.entries(members)) {
        properties[name] = {...property, optional: true};
      }
      oneOf.push(sorted(Object.keys(members)));
    }
    const result = {kind: 'object', properties};
    if (parts.bases.length > 0) result.extends = sorted(parts.bases);
    if (oneOf.length > 0) result.oneOf = oneOf;
    return result;
  }
  return {kind: 'other', ...simplifyType(alias.type)};
}

function encodeClassLike(node) {
  const methods = new Map();
  const properties = {};
  const constructors = [];
  for (const member of node.members) {
    if (
      hasModifier(member, ts.SyntaxKind.PrivateKeyword) ||
      hasModifier(member, ts.SyntaxKind.ProtectedKeyword)
    ) {
      continue;
    }
    if (ts.isConstructorDeclaration(member)) {
      constructors.push(encodeSignature(member));
      continue;
    }
    const name = nameOf(member);
    // Underscored members are internal by convention.
    if (!name || name.startsWith('_')) continue;
    const isStatic = hasModifier(member, ts.SyntaxKind.StaticKeyword);
    if (ts.isMethodDeclaration(member) || ts.isMethodSignature(member)) {
      const overloads = methods.get(name) ?? {static: isStatic, overloads: []};
      overloads.overloads.push(encodeSignature(member));
      methods.set(name, overloads);
    } else if (
      ts.isPropertyDeclaration(member) ||
      ts.isPropertySignature(member)
    ) {
      properties[name] = {
        static: isStatic,
        readonly: hasModifier(member, ts.SyntaxKind.ReadonlyKeyword),
        optional: member.questionToken !== undefined,
        ...simplifyType(member.type),
      };
    } else if (ts.isGetAccessorDeclaration(member)) {
      properties[name] = {
        static: isStatic,
        readonly: true,
        optional: false,
        ...simplifyType(member.type),
      };
    }
  }
  const result = {
    abstract: hasModifier(node, ts.SyntaxKind.AbstractKeyword),
    extends: null,
    implements: [],
    methods: Object.fromEntries(
      [...methods].map(([name, value]) => [
        name,
        {...value, overloads: sortOverloads(value.overloads)},
      ]),
    ),
    properties,
  };
  if (constructors.length > 0) {
    result.constructors = sortOverloads(constructors);
  }
  for (const clause of node.heritageClauses ?? []) {
    const names = clause.types.map(type => type.expression.getText());
    if (clause.token === ts.SyntaxKind.ExtendsKeyword) {
      result.extends = names.length === 1 ? names[0] : sorted(names);
    } else {
      result.implements = sorted(names);
    }
  }
  return result;
}

// --- Walk the namespace ---------------------------------------------------

const functions = new Map();
const classes = {};
const interfaces = {};
const types = {};

for (const statement of pipelines.statements) {
  if (!isExported(statement)) continue;
  if (ts.isFunctionDeclaration(statement)) {
    const name = nameOf(statement);
    const overloads = functions.get(name) ?? [];
    overloads.push(encodeSignature(statement));
    functions.set(name, overloads);
  } else if (ts.isClassDeclaration(statement)) {
    classes[nameOf(statement)] = encodeClassLike(statement);
  } else if (ts.isInterfaceDeclaration(statement)) {
    interfaces[nameOf(statement)] = encodeClassLike(statement);
  } else if (ts.isTypeAliasDeclaration(statement)) {
    types[statement.name.text] = encodeTypeAlias(statement);
  } else {
    throw new Error(
      `Unhandled export in the Pipelines namespace: ${statement.getText()}`,
    );
  }
}

// Pipeline entry points declared outside the namespace.
function findClassMethod(className, methodName) {
  for (const statement of firebaseFirestore.statements) {
    if (ts.isClassDeclaration(statement) && nameOf(statement) === className) {
      const overloads = statement.members
        .filter(
          member =>
            ts.isMethodDeclaration(member) && nameOf(member) === methodName,
        )
        .map(encodeSignature);
      if (overloads.length > 0) return {overloads: sortOverloads(overloads)};
    }
  }
  throw new Error(`${className}.${methodName} not found.`);
}

const entryPoints = {
  'Firestore.pipeline': findClassMethod('Firestore', 'pipeline'),
  'Transaction.execute': findClassMethod('Transaction', 'execute'),
};

// --- Runtime exports --------------------------------------------------------

// The typings omit some functions that the `@google-cloud/firestore/pipelines`
// entry point exports at runtime. Record their names and JavaScript parameter
// names so the Dart side can match them too.
const runtimeIndex = readSource(runtimeIndexRelativePath, ts.ScriptKind.JS);
const moduleVariables = new Map();
const runtimeExports = new Map();

function visitRuntimeIndex(node) {
  if (
    ts.isVariableDeclaration(node) &&
    ts.isIdentifier(node.name) &&
    node.initializer &&
    ts.isCallExpression(node.initializer) &&
    node.initializer.expression.getText() === 'require'
  ) {
    moduleVariables.set(node.name.text, node.initializer.arguments[0].text);
  }
  if (
    ts.isCallExpression(node) &&
    node.expression.getText() === 'Object.defineProperty' &&
    node.arguments[0].getText() === 'exports' &&
    ts.isStringLiteral(node.arguments[1])
  ) {
    const name = node.arguments[1].text;
    const getter = node.arguments[2].getText();
    const match = /return\s+(\w+)\.(\w+)/.exec(getter);
    if (name !== '__esModule' && match) {
      runtimeExports.set(name, {variable: match[1], symbol: match[2]});
    }
  }
  ts.forEachChild(node, visitRuntimeIndex);
}
visitRuntimeIndex(runtimeIndex);

const declaredNames = new Set([
  ...functions.keys(),
  ...Object.keys(classes),
  ...Object.keys(interfaces),
  ...Object.keys(types),
]);

function encodeJsParameters(declaration) {
  return declaration.parameters.map(parameter => {
    const result = {name: parameter.name.getText()};
    if (parameter.initializer) result.optional = true;
    if (parameter.dotDotDotToken) result.rest = true;
    return result;
  });
}

const runtimeOnlyFunctions = {};
for (const [name, {variable, symbol}] of runtimeExports) {
  if (declaredNames.has(name)) continue;
  const modulePath = moduleVariables.get(variable);
  const moduleSource = readSource(
    path.posix.join(path.posix.dirname(runtimeIndexRelativePath), modulePath) +
      '.js',
    ts.ScriptKind.JS,
  );
  const declaration = moduleSource.statements.find(
    statement =>
      ts.isFunctionDeclaration(statement) && nameOf(statement) === symbol,
  );
  if (!declaration) {
    throw new Error(
      `Runtime export ${name} is neither declared in the typings nor a ` +
        `function of ${modulePath}.js; extend this script to handle it.`,
    );
  }
  runtimeOnlyFunctions[name] = {
    module: modulePath.replace(/^\.\//, ''),
    params: encodeJsParameters(declaration),
  };
}

// Likewise, public methods and getters of the declared classes that only the
// JavaScript implementation has.
const runtimeOnlyMembers = {};
const runtimeDir = path.join(packageDir, path.dirname(runtimeIndexRelativePath));
for (const file of fs.readdirSync(runtimeDir).sort()) {
  if (!file.endsWith('.js')) continue;
  const source = readSource(
    path.posix.join(path.posix.dirname(runtimeIndexRelativePath), file),
    ts.ScriptKind.JS,
  );
  for (const statement of source.statements) {
    if (!ts.isClassDeclaration(statement)) continue;
    const declared = classes[nameOf(statement)];
    if (!declared) continue;
    for (const member of statement.members) {
      const isMethod = ts.isMethodDeclaration(member);
      if (!isMethod && !ts.isGetAccessorDeclaration(member)) continue;
      const name = nameOf(member);
      if (
        !name ||
        name.startsWith('_') ||
        name.startsWith('#') ||
        name in declared.methods ||
        name in declared.properties
      ) {
        continue;
      }
      const members = (runtimeOnlyMembers[nameOf(statement)] ??= {});
      members[name] = isMethod
        ? {kind: 'method', module: file, params: encodeJsParameters(member)}
        : {kind: 'getter', module: file};
    }
  }
}

// --- Output -----------------------------------------------------------------

function stableStringify(value) {
  return JSON.stringify(sortKeys(value));
}

/**
 * Pretty-prints [value] with sorted keys, keeping any object or array that
 * fits on one line on a single line, so that each parameter is one line and
 * diffs stay readable.
 */
function format(value, indent = '') {
  const compact = stableStringify(value);
  if (
    value === null ||
    typeof value !== 'object' ||
    indent.length + compact.length <= 120
  ) {
    return compact;
  }
  const inner = indent + '  ';
  if (Array.isArray(value)) {
    if (value.length === 0) return '[]';
    const items = value.map(item => inner + format(item, inner));
    return `[\n${items.join(',\n')}\n${indent}]`;
  }
  const keys = Object.keys(value).sort();
  if (keys.length === 0) return '{}';
  const entries = keys.map(
    key => `${inner}${JSON.stringify(key)}: ${format(value[key], inner)}`,
  );
  return `{\n${entries.join(',\n')}\n${indent}}`;
}

function sortKeys(value) {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map(key => [key, sortKeys(value[key])]),
    );
  }
  return value;
}

const snapshot = {
  // Bump when the shape of this file changes, so the Dart test can tell.
  formatVersion: 1,
  source: {
    package: packageJson.name,
    version: packageJson.version,
    typings: typingsRelativePath,
    namespace: 'FirebaseFirestore.Pipelines',
    runtimeIndex: runtimeIndexRelativePath,
    generator: 'packages/google_cloud_firestore/tool/pipeline_api_parity',
  },
  functions: Object.fromEntries(
    [...functions].map(([name, overloads]) => [
      name,
      {overloads: sortOverloads(overloads)},
    ]),
  ),
  classes,
  interfaces,
  types,
  entryPoints,
  runtimeExports: sorted(runtimeExports.keys()),
  runtimeOnlyFunctions,
  runtimeOnlyMembers,
};

fs.writeFileSync(outputPath, format(snapshot) + '\n');
console.log(
  `Wrote ${path.relative(process.cwd(), outputPath)}: ` +
    `${functions.size} functions, ${Object.keys(classes).length} classes, ` +
    `${Object.keys(types).length} types, ` +
    `${Object.keys(runtimeOnlyFunctions).length} runtime-only functions, ` +
    `${Object.values(runtimeOnlyMembers).flatMap(Object.keys).length} ` +
    'runtime-only members ' +
    `(${packageJson.name} ${packageJson.version}).`,
);
