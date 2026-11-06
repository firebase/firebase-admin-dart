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
  - id: explicit-project-id-marker
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
    symbol: getExplicitProjectId
    title: A "matches Node" marker on project-ID resolution
  - id: implicit-order-by-marker
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/query.dart
    symbol: Mirrors the Node SDK's `createImplicitOrderBy`
    title: A "mirrors Node" marker in Firestore queries
  - id: node-auth
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/auth/
    title: Node's `src/auth/`, the layout the Dart Auth module follows
---

# Decision

The SDK is a close port of the Node.js Admin SDK (`firebase-admin-node`) and of Node Firestore (`@google-cloud/firestore`). Node's source is the reference for API names, file layout, validation rules and error codes. A contribution that redesigned a feature instead of porting it was sent back: port first, and record any deliberate redesign.

Parity is kept by convention:

- The file layout mirrors Node module by module. `auth/` has `action_code_settings_builder`, `auth_config`, `base_auth`, `token_generator`, `token_verifier`, `user_import_builder` and the rest, like Node's `src/auth/`.[^auth-layout][^node-auth]
- Dartdoc and comments mark ported logic with "Mirrors/Matches the Node SDK's X". Most are in `google_cloud_firestore`'s `pipeline.dart`; others sit on the implicit order-by in queries and on project-ID resolution.[^implicit-order-by-marker][^explicit-project-id-marker]
- CHANGELOG entries justify fixes by matching the Node Admin SDK.
- CONTRIBUTING says "Match the behaviour of the Node.js Admin SDK where applicable." That line sits under "Error Handling", so it is an error-behaviour rule rather than a general port policy.[^contributing-node-rule]
- Behaviours matched by hand include project-ID precedence, the Firestore credential restriction, revocation checks in `verifyIdToken` under the emulator, FCM v1 topic management with deprecated legacy IID methods, `listDocuments` following `nextPageToken`, and the JSON keys of `UserRecord.toJson` and `Timestamp.toJson`.

Firestore Pipelines are the only product with parity checks enforced in CI. Auth, App Check, Messaging, Functions, Security Rules, Storage, the app core and non-Pipeline Firestore have no parity check: parity there depends on review and on the conventions above.

One Node TypeScript source remains in the Dart `lib/`: `utils/validator.ts`, and it ships in the published package.[^validator-ts] Whether it is kept on purpose isn't recorded; ask a maintainer.

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

[^auth-layout]: The Auth module's file layout
[^node-auth]: Node's `src/auth/`
[^implicit-order-by-marker]: "Mirrors the Node SDK" marker in `query.dart`
[^explicit-project-id-marker]: `getExplicitProjectId` marker in `firebase_app.dart`
[^contributing-node-rule]: CONTRIBUTING's error-handling rule
[^validator-ts]: Leftover `validator.ts`
