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

'use strict';

/**
 * Writes the `ExecutePipelineRequest` the Node.js Firestore SDK sends for
 * every case in `cases.js` to `test/fixtures/pipeline_golden/<area>.json`.
 *
 * Nothing touches the network: `Firestore.requestStream`, the single call the
 * SDK makes to run `executePipeline`, is replaced with a stub that records
 * the request and returns an empty response stream. Everything up to that
 * point (`Pipeline.execute`, user data validation, `StructuredPipeline`
 * serialization) is the SDK's own code.
 *
 * The recorded request is converted to proto3 JSON the same way google-gax
 * does for the REST transport (`Type.fromObject` + `toProto3JSON`), which is
 * also the encoding the Dart SDK sends. See README.md for the normalization
 * applied on top.
 */

const fs = require('fs');
const path = require('path');
const {PassThrough} = require('stream');

const sdkPackage = require.resolve('@google-cloud/firestore/package.json');
const sdkDir = path.dirname(sdkPackage);
const gaxDir = path.dirname(require.resolve('google-gax', {paths: [sdkDir]}));
// Resolve protobufjs and the proto3 JSON serializer the same way the SDK and
// google-gax do, so the encoding matches the REST transport exactly.
const protobuf = require(require.resolve('protobufjs', {paths: [sdkDir]}));
const {toProto3JSON} = require(
  require.resolve('proto3-json-serializer', {paths: [gaxDir]}),
);

const sdk = require('@google-cloud/firestore');
const buildCases = require('./cases');

const SDK_VERSION = require(sdkPackage).version;
const PROJECT_ID = 'test-project';
const DATABASE_ID = '(default)';
const OUT_DIR = path.resolve(
  __dirname,
  '..',
  '..',
  'test',
  'fixtures',
  'pipeline_golden',
);

/**
 * Repeated and map fields that proto3 JSON omits when empty.
 *
 * protobufjs keeps some of them (for example `options: {}` on every stage),
 * the Dart SDK drops them; both mean the same thing on the wire. Message
 * fields such as an empty `mapValue` are kept: they carry a value.
 */
const OMIT_WHEN_EMPTY = new Set(['args', 'options', 'fields', 'values']);

/**
 * Names that are deliberately not exercised as `functions/<name>/...` or
 * `aggregates/<name>/...`, and where they are covered instead.
 */
const COVERED_ELSEWHERE = {
  field: 'values/field/*',
  constant: 'values/constant/*',
  variable: 'values/variable/*, functions/arrayFilter/*',
  ascending: 'stages/sort/*',
  descending: 'stages/sort/*',
  subcollection: 'sources/subcollection/*',
};

/** `Expression` methods that are not Pipeline functions. */
const NOT_FUNCTIONS = new Set(['constructor', 'as', 'asBoolean']);

function isEmpty(value) {
  if (Array.isArray(value)) return value.length === 0;
  return (
    value !== null && typeof value === 'object' && Object.keys(value).length === 0
  );
}

/** Orders keys alphabetically, except that a function or stage `name` leads. */
function compareKeys(a, b) {
  if (a === b) return 0;
  if (a === 'name') return -1;
  if (b === 'name') return 1;
  return a < b ? -1 : 1;
}

/** Sorts object keys and drops empty repeated/map fields, recursively. */
function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value === null || typeof value !== 'object') return value;
  const result = {};
  for (const key of Object.keys(value).sort(compareKeys)) {
    const child = canonicalize(value[key]);
    if (OMIT_WHEN_EMPTY.has(key) && isEmpty(child)) continue;
    result[key] = child;
  }
  return result;
}

/**
 * Pretty-prints [value] as JSON, keeping any object or array that fits in
 * [LINE_WIDTH] columns on one line, so a fixture reads like the request:
 * `{"fieldReferenceValue": "rating"}` instead of three lines.
 */
const LINE_WIDTH = 80;

function format(value, indent = '', column = indent.length) {
  const inline = formatInline(value);
  if (column + inline.length <= LINE_WIDTH || value === null) return inline;
  if (typeof value !== 'object') return inline;

  const inner = indent + '  ';
  if (Array.isArray(value)) {
    const items = value.map(item => inner + format(item, inner));
    return `[\n${items.join(',\n')}\n${indent}]`;
  }
  const entries = Object.keys(value).map(key => {
    const prefix = `${inner}${JSON.stringify(key)}: `;
    return prefix + format(value[key], inner, prefix.length);
  });
  return `{\n${entries.join(',\n')}\n${indent}}`;
}

function formatInline(value) {
  if (Array.isArray(value)) {
    return `[${value.map(formatInline).join(', ')}]`;
  }
  if (value !== null && typeof value === 'object') {
    const entries = Object.keys(value).map(
      key => `${JSON.stringify(key)}: ${formatInline(value[key])}`,
    );
    return `{${entries.join(', ')}}`;
  }
  return JSON.stringify(value);
}

/** Fails when a Node function or method is not exercised by any case. */
function checkCoverage(ids) {
  const P = sdk.Pipelines;
  const subjects = new Set();
  const methodSubjects = new Set();
  for (const id of ids) {
    const [area, subject, variant] = id.split('/');
    if (area !== 'functions' && area !== 'aggregates') continue;
    subjects.add(subject);
    if (variant.startsWith('method')) methodSubjects.add(subject);
  }

  const missing = [];
  for (const name of Object.keys(P).sort()) {
    if (typeof P[name] !== 'function' || /^[A-Z]/.test(name)) continue;
    if (!subjects.has(name) && !(name in COVERED_ELSEWHERE)) {
      missing.push(`top-level function ${name}()`);
    }
  }

  const methods = new Set([
    ...Object.getOwnPropertyNames(P.Expression.prototype),
    ...Object.getOwnPropertyNames(P.BooleanExpression.prototype),
    ...Object.getOwnPropertyNames(P.Field.prototype),
  ]);
  for (const name of [...methods].sort()) {
    if (NOT_FUNCTIONS.has(name) || name.startsWith('_')) continue;
    if (name === 'fieldName' || name === 'ascending' || name === 'descending') {
      continue;
    }
    if (!methodSubjects.has(name)) missing.push(`Expression.${name}()`);
  }

  if (missing.length > 0) {
    throw new Error(
      'These Node Pipeline APIs have no golden case:\n  ' +
        missing.join('\n  '),
    );
  }
}

async function main() {
  const db = new sdk.Firestore({projectId: PROJECT_ID, databaseId: DATABASE_ID});
  const requestType = protobuf.Root.fromJSON(
    require(path.join(sdkDir, 'build', 'protos', 'v1.json')),
  ).lookupType('google.firestore.v1.ExecutePipelineRequest');

  let captured;
  db.requestStream = async (methodName, bidirectional, request) => {
    if (methodName !== 'executePipeline') {
      throw new Error(`Unexpected RPC ${methodName}`);
    }
    captured = request;
    const stream = new PassThrough({objectMode: true});
    stream.end();
    return stream;
  };

  const cases = buildCases(sdk, db);
  checkCoverage(cases.map(c => c.id));

  const areas = new Map();
  for (const {id, pipeline, options} of cases) {
    captured = undefined;
    try {
      await pipeline().execute(options);
    } catch (e) {
      throw new Error(`Case ${id} failed: ${e.stack || e}`);
    }
    if (!captured) throw new Error(`Case ${id} sent no request`);

    const json = canonicalize(toProto3JSON(requestType.fromObject(captured)));
    const area = id.split('/')[0];
    if (!areas.has(area)) areas.set(area, {});
    areas.get(area)[id] = json;
  }

  fs.mkdirSync(OUT_DIR, {recursive: true});
  for (const file of fs.readdirSync(OUT_DIR)) {
    if (file.endsWith('.json')) fs.rmSync(path.join(OUT_DIR, file));
  }
  for (const [area, requests] of [...areas].sort(([a], [b]) =>
    a < b ? -1 : 1,
  )) {
    const sorted = {};
    for (const id of Object.keys(requests).sort()) sorted[id] = requests[id];
    const fixture = {
      generator: 'tool/pipeline_golden (npm run generate)',
      sdk: `@google-cloud/firestore@${SDK_VERSION}`,
      cases: sorted,
    };
    fs.writeFileSync(
      path.join(OUT_DIR, `${area}.json`),
      format(fixture) + '\n',
    );
  }

  await db.terminate();
  const counts = [...areas]
    .map(([area, requests]) => `${area}: ${Object.keys(requests).length}`)
    .join(', ');
  console.log(`Wrote ${cases.length} cases (${counts}) to ${OUT_DIR}`);
}

main().catch(e => {
  console.error(e);
  process.exitCode = 1;
});
