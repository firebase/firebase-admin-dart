---
type: Decision
title: Port of the Node.js Admin SDK
description: The SDK is a close port of the Node.js Admin SDK and of Node Firestore, so Node's API names, file layout, validation rules and error codes are the reference.
tags: [architecture, node-parity]
agents_md: when-touching
governs:
  - packages/*/lib/**
sources:
  - id: contributing-node-rule
    resource: ../../../CONTRIBUTING.md
    symbol: Match the behaviour of the Node.js Admin SDK where applicable
    title: CONTRIBUTING's error-handling rule to match Node "where applicable"
  - id: validator-ts
    resource: ../../../packages/firebase_admin_sdk/lib/src/utils/validator.ts
    title: A Node TypeScript source left in the Dart `lib/`
  - id: auth-layout
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/
    title: The Auth module, laid out file by file like Node's
  - id: implicit-order-by-marker
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/query.dart
    symbol: Mirrors the Node SDK's `createImplicitOrderBy`
    title: A "mirrors Node" marker in Firestore queries
  - id: pipeline-parity
    resource: ../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: const _renames
    title: The Pipeline API parity test, the one machine check of Node parity
  - id: node-auth
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/auth/
    title: Node's `src/auth/`, the layout the Dart Auth module follows
---

# Where it lives

- Enforced by: `pipeline_api_parity_test.dart` and the other Pipeline parity tests, for Firestore Pipelines only.[^pipeline-parity] Everything else: nothing; review only.
- The file layout mirrors Node module by module: compare `lib/src/auth/` with Node's `src/auth/`.[^auth-layout][^node-auth]
- Ported logic is marked in dartdoc and comments as "Mirrors (or Matches) the Node SDK's X", for example on `createImplicitOrderBy` in `query.dart`. Grep for the marker.[^implicit-order-by-marker]
- CONTRIBUTING's only Node rule: under `### Error Handling`.[^contributing-node-rule]

# Decision

The SDK is a close port of the Node.js Admin SDK (`firebase-admin-node`) and of Node Firestore (`@google-cloud/firestore`). Node's source is the reference for API names, file layout, validation rules and error codes. A contribution that redesigned a feature instead of porting it was sent back: port first, and record any deliberate redesign.

CONTRIBUTING's "Match the behaviour of the Node.js Admin SDK where applicable" sits under "Error Handling", so it is an error-behaviour rule rather than a general port policy. The port policy is this concept.

Firestore Pipelines are the only product with parity checks enforced in CI. Auth, App Check, Messaging, Functions, Security Rules, Storage, the app core and non-Pipeline Firestore have no parity check: parity there depends on review.

**Trap:** one Node TypeScript source remains in the Dart `lib/`, `utils/validator.ts`, and it ships in the published package.[^validator-ts] Whether it is kept on purpose isn't recorded; ask a maintainer.

# Why

The maintainers' stated reason: sticking as close as possible to a port of the official Node implementation makes maintenance much simpler, which matters given the size of the project. The per-module tracking issues set feature parity with the Node.js Admin SDK as the acceptance criterion.

When a Node validation fired where it shouldn't, the maintainers kept it because Node has it, and fixed the condition instead.

Writing features from scratch was rejected in favour of a port. Matching FlutterFire's `cloud_firestore` API was rejected too.

# Rules for agents

- **Should:** when porting, cite the Node source (a permalink, a file and line, or the Node PR). This is a convention seen in PRs, not a stated requirement.
- **Must not:** rename, drop or redesign a Node behaviour without recording why.
- **Must not:** delete a Node validation that fires wrongly. Fix its condition instead.

# Related

- [Dart idioms win where Node's shape does not fit](/architecture/dart-idioms-over-node-shapes.md)
- [Pipelines parity with Node is checked by machine](/firestore/pipelines/node-parity.md)
- [Firestore follows Node, not FlutterFire](/firestore/node-not-flutterfire.md)
- [Compare with Node before changing a Dart API or behaviour](/playbooks/compare-with-node.md)

[^pipeline-parity]: The Pipeline API parity test
[^auth-layout]: The Auth module's file layout
[^node-auth]: Node's `src/auth/`
[^implicit-order-by-marker]: "Mirrors the Node SDK" marker in `query.dart`
[^contributing-node-rule]: CONTRIBUTING's error-handling rule
[^validator-ts]: Leftover `validator.ts`
