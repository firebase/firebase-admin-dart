---
name: check-node-parity
description: Compares firebase-admin-dart with the Node.js Admin SDK (firebase-admin-node) and @google-cloud/firestore, for one product, one API or a Node release, and reports feature gaps, API drift, behaviour differences and wire-format incompatibilities, each classified as deliberate or not. Use when asked to check parity, audit a product against Node, find what Dart is missing, review what a new Node release changed, or decide whether a difference from Node is a bug.
---

# Check parity with Node

This skill produces a report. It changes no SDK code. Fixing a gap is the `implement-sdk-feature` skill's job.

The [compare-with-Node playbook](../../knowledge/playbooks/compare-with-node.md) says which Node package, file and version is the reference for each Dart path, and how the layouts map. Read it first.

## 1. Fix the scope and the versions

- Agree the scope with the request: one product (`auth`), one API (`Auth.updateUser`), or a range of Node releases.
- Node side: the latest release of firebase-admin-node or `@google-cloud/firestore`, unless the user names one. For Pipelines, the pinned version. Record the version; the report names it.
- Dart side: the checked-out commit. Say so if it isn't `main`.
- Read Node at that tag with `gh api repos/<owner>/<repo>/contents/<path>?ref=<tag>`, or from a shallow clone outside this repository.

## 2. Firestore Pipelines: run the machine checks

Pipelines are the one area checked by machine. Don't compare them by hand.

```bash
cd packages/google_cloud_firestore
dart test test/pipeline_api_parity_test.dart test/pipeline_golden_test.dart \
  test/pipeline_single_implementation_test.dart test/pipeline_e2e_coverage_test.dart
```

- The open gaps are the entries of `_pendingFixes` and `_dartApiGaps` in those tests. Report them from the tables.
- To compare against a newer Node release, bump the pin as [Pipelines parity with Node](../../knowledge/firestore/pipelines/node-parity.md) says. That edits tracked files, so do it only if the user asks.

## 3. Everything else: compare by hand

Work through these layers, in this order, for each Node module in scope.

1. **Public surface.** List Node's exported classes, methods, properties, option fields and enum values from its typings (`src/<product>/index.ts` and the files it exports, or `types/firestore.d.ts`). List the Dart equivalents from the product's barrel in `lib/` and the files it exports. Match them name by name.
2. **Signatures.** For each matched member: parameters, optionality, defaults and return type, after applying the [Dart idioms](../../knowledge/architecture/dart-idioms-over-node-shapes.md).
3. **Validation.** For each method, the checks made before the request, and the error code each one throws.
4. **Wire format.** The endpoint, HTTP method, field names, field masks and headers of the request, and how the response is decoded.
5. **Errors.** Node's server-to-client code table for the product against Dart's. A code Node has and Dart lacks is a difference.
6. **Tests.** Node `describe` blocks with no Dart counterpart point at behaviour nobody checked.

Don't trust dartdoc as evidence of behaviour. Read the code, or run it: a short unit test with a request-handler double shows what Dart sends.

For a range of Node releases, start from the release notes (`gh release view <tag> --repo firebase/firebase-admin-node`), and check each listed change against Dart.

## 4. Classify every difference

Before calling anything a gap, look for a concept that covers it: run `./scripts/knowledge.sh for <the Dart path>`, and search `.agents/knowledge/` for the member's name. Then give the difference one class:

| Class | Meaning | Evidence |
| --- | --- | --- |
| Idiom | Same behaviour, Dart shape | A row of the idioms table |
| Deliberate | Dart differs on purpose | A Divergence or Decision concept, or a Pipeline parity table entry |
| Transport limit | REST can't do it yet | [Firestore over REST](../../knowledge/firestore/rest-transport.md) |
| Node bug not copied | Dart sends what the backend accepts | A `_knownDivergences` entry or a concept |
| Dart-only | Dart has something Node lacks | The Dart member |
| **Gap** | Node has it, Dart doesn't | No concept covers it |
| **Drift** | Both have it, behaviour or signature differs | No concept covers it |
| Unclear | Can't tell which side is right | Say what would settle it |

Rules:

- A feature Node has and Dart lacks is a gap unless a concept marks it deliberate. Don't call anything "out of scope" yourself. [Unsupported products](../../knowledge/scope/unsupported-services.md)
- A difference in an unreleased Node commit isn't a gap yet. Note it separately.
- Mark each gap and drift as verified (you read both sides, or ran a test) or suspected.
- Flag cross-compatibility separately: data or tokens one SDK writes that the other can't read, such as `toJson()` keys, document encodings, custom-token claims or task payloads. These break mixed Node and Dart deployments, so they rank first.

## 5. Report

Give the user one report, in the conversation unless they ask for a file. Don't write it into the repository.

1. **Scope and versions:** the products, the Node version and the Dart commit.
2. **Summary:** counts per class, and the three findings that matter most.
3. **Gaps and drift**, most severe first. For each: the Node member and file, the Dart member and file or "missing", what differs in one sentence, verified or suspected, and whether a fix would be a breaking change.
4. **Cross-compatibility issues**, if any.
5. **Deliberate differences found,** as a short list with the concept that covers each, so the reader sees they were checked.
6. **Not checked:** the layers or modules you skipped.

Then offer the next steps, and do none of them unasked: implement a gap, port the missing Node tests with the `write-and-sync-tests` skill, or record a newly confirmed deliberate difference with the `update-knowledge-base` skill. Don't open issues.
