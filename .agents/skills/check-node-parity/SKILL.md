---
name: check-node-parity
description: Reports feature gaps, API drift and wire-format incompatibilities between a Dart product or API and the Node.js SDKs, each classified as deliberate or not. Changes no code. Use when asked to audit parity with Node, list what Dart is missing, or review what a Node release changed.
---

# Check parity with Node

The output is a report in the conversation. Don't change SDK code, write the report into the repo, or open issues.

The [compare-with-Node playbook](../../knowledge/playbooks/compare-with-node.md) gives the Node reference, version and layout for each Dart path. Read it first.

## 1. Scope

Agree the scope: a product, an API, or a range of Node releases. Record the Node version and the Dart commit. Read Node at that tag:

```bash
gh api -H 'Accept: application/vnd.github.raw' 'repos/<owner>/<repo>/contents/<path>?ref=<tag>'
```

For a range of releases, start from the release notes (`gh release view <tag> --repo <owner>/<repo>`) and check each listed change.

## 2. Firestore Pipelines, if in scope

Don't compare them by hand. Run the checks, and report from their tables:

```bash
cd packages/google_cloud_firestore
dart test test/pipeline_api_parity_test.dart test/pipeline_golden_test.dart
```

[Pipelines parity](../../knowledge/firestore/pipelines/node-parity.md) says what each table means. Bumping the pinned Node version edits tracked files, so do it only if the user asks.

## 3. Everything else

Compare by layer. For a whole product, do layers 1, 2 and 5, report, and ask before going deeper. For a single API, do all six.

1. **Surface:** Node's exported classes, members, option fields and enum values, from its typings, against the Dart barrel's exports.
2. **Signatures:** parameters, optionality, defaults and return types, after applying the Dart idioms.
3. **Validation:** the checks made before the request, and the error code each throws.
4. **Wire format:** endpoint, HTTP method, field names, field masks, headers, response decoding.
5. **Error codes:** Node's server-to-client table against Dart's.
6. **Tests:** Node `describe` blocks with no Dart counterpart.

## 4. Classify

Give each difference a class from step 7 of the playbook, or **drift**: both sides have it, and the signature or behaviour differs.

- Before calling something a gap or drift, look for a concept that covers it: `./scripts/knowledge.sh for <the Dart path>`, and search `.agents/knowledge/` for the member's name.
- Mark each gap and drift verified (you read both sides) or suspected.
- List differences that exist only in unreleased Node commits separately.
- Rank cross-compatibility first: data or tokens one SDK writes that the other can't read, such as `toJson()` keys, document encodings, custom-token claims and task payloads. These break mixed Node and Dart deployments.

## 5. Report

1. Scope, Node version and Dart commit.
2. Gaps, drift and cross-compatibility issues, most severe first: the Node member and file, the Dart member and file or "missing", what differs, verified or suspected, and whether a fix would be breaking.
3. The deliberate differences you found, each with its concept.
4. The layers and modules you didn't check.
