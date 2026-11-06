---
type: Playbook
title: Compare with Node before changing a Dart API or behaviour
description: How to check a Dart API or behaviour against the Node.js reference before changing it, covering which Node package, file and version to read, how the layouts map, where the automated parity checks live, and what to do when Node has something Dart lacks.
tags: [node-parity, porting, playbook]
agents_md: always
governs:
  - packages/*/lib/**
sources:
  - id: golden-pin
    resource: ../../../packages/google_cloud_firestore/tool/pipeline_golden/package.json
    symbol: "@google-cloud/firestore"
    title: The Node SDK pinned for the golden fixtures
  - id: snapshot-pin
    resource: ../../../packages/google_cloud_firestore/tool/pipeline_api_parity/package.json
    symbol: "@google-cloud/firestore"
    title: The Node SDK pinned for the API snapshot
  - id: node-version
    resource: ../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: const _nodeVersion
    title: The Node version the parity test expects
  - id: node-admin-src
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src
    title: firebase-admin-node sources, one directory per product
  - id: node-admin-firestore
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/firestore/firestore-internal.ts
    symbol: class FirestoreService
    title: How Node's admin SDK builds and caches Firestore instances
  - id: node-firestore-src
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src
    title: "`@google-cloud/firestore` sources"
---

# When to use

Before you change a Dart API or behaviour, or port a feature, in either package. The SDK is a port of two Node.js packages: firebase-admin-node for the admin services, and `@google-cloud/firestore` (googleapis/google-cloud-node, `handwritten/firestore/`) for Firestore.

# Steps

1. **Find the reference for the Dart path you are changing.**

   | Dart path | Node reference |
   | --- | --- |
   | `packages/firebase_admin_sdk/lib/src/<product>/`: app (credentials included, in `app/`), Auth, App Check, Messaging, Functions, Security Rules, Storage helpers | firebase-admin-node `src/<product>/`, with credentials in `src/app/`[^node-admin-src] |
   | `packages/firebase_admin_sdk/lib/src/firestore/`: how `app.firestore()` builds settings, maps credentials and caches databases | firebase-admin-node `src/firestore/firestore-internal.ts` and `src/firestore/index.ts`[^node-admin-firestore] |
   | `packages/google_cloud_firestore/` | `@google-cloud/firestore`: sources in google-cloud-node `handwritten/firestore/dev/src/`, public typings in `handwritten/firestore/types/firestore.d.ts`[^node-firestore-src] |
   | Storage object operations | the upstream `google_cloud_storage` package, not this repo |

   The only references are the Node Admin SDK and `@google-cloud/firestore`. Never use the JS Web SDK, or googleapis/nodejs-firestore, which is archived and older than the pinned version.

2. **Map Node's layout to Dart's.**
   - Files mirror Node module by module, kebab-case to snake_case: `src/auth/base-auth.ts` is `lib/src/auth/base_auth.dart`. `google_cloud_firestore/lib/src/` follows `dev/src/` the same way.
   - Node's per-service request file, `*-api-request.ts` for Auth and Messaging or `*-api-client-internal.ts` for App Check, Functions and Security Rules, is split in two: `*_http_client.dart` for transport and `*_request_handler.dart` for validation.
   - Node's hand-written endpoint paths, such as `/accounts:lookup`, mostly become methods of the generated `package:googleapis` client used in `*_http_client.dart`. The exceptions call their endpoints directly: FCM v1 topic subscriptions in `messaging_request_handler.dart`, the legacy IID topic calls in `messaging_http_client.dart`, App Check's `verifyAppCheckToken`, and Storage's `getDownloadURL`.

3. **Pick the Node version.**
   - Firestore Pipelines: the `@google-cloud/firestore` version pinned in `tool/pipeline_golden/package.json` and `tool/pipeline_api_parity/package.json`, which `_nodeVersion` in `test/pipeline_api_parity_test.dart` repeats.[^golden-pin][^snapshot-pin][^node-version] Nothing checks that the two tools pin the same version. To bump it, follow [Pipeline API snapshot](/generated/pipeline-api-snapshot.md).
   - Everything else is unpinned. Compare with the latest release of firebase-admin-node or `@google-cloud/firestore`, and name that version in the PR description. If Node changed behaviour after the Dart port, treat the difference as a gap unless a concept marks it deliberate.

4. **Port Node's test cases.** Node's unit tests (firebase-admin-node `test/unit/<product>/`, google-cloud-node `handwritten/firestore/dev/test/`) list the validation errors and edge cases to reproduce. Port the relevant ones into the matching Dart `test/unit/<product>/` or `test/*.dart`.

5. **Firestore Pipelines: make the automated checks pass.** They are the only parity checks CI enforces.
   - API signatures: `test/pipeline_api_parity_test.dart` against `test/fixtures/node_pipeline_api.json`.
   - Wire format: `test/pipeline_golden_test.dart` against [Node-generated fixtures](/generated/pipeline-golden-fixtures.md).
   - `pipeline_single_implementation_test.dart` and `pipeline_e2e_coverage_test.dart` also guard the Pipeline API, without comparing with Node.
   - Record each deliberate difference, with its reason, in the right table: `_renames`, `_classes`, `_enums`, `_optionTypes`, `_dartOnly`, `_knownDifferences` or `_pendingFixes` in the parity test; `_knownDivergences`, `_pendingFixes` or `_dartApiGaps` in the golden test. Stale entries fail the tests.

6. **Everything else: compare by hand.** Auth, App Check, Messaging, Functions, Security Rules, Storage, the app core and non-Pipeline Firestore have no parity check. Parity there rests on review and on the conventions in [Port of the Node.js Admin SDK](/architecture/node-port.md). Don't treat dartdoc as a spec: some of it was ported from Node or is stale.

7. **When Node has a feature and Dart doesn't, it is a gap, unless a concept marks it deliberate.** A difference is an idiom, a transport limit, a deliberate omission, a gap, a Dart-only addition, unclear, or a Node bug not copied (Dart sends something else on purpose because the backend rejects what Node sends). Check the Divergence concepts, then ask a maintainer before you call a feature out of scope. Never "fix" a Node bug not copied back to Node's behaviour.

8. **Check the concepts most often "fixed" the wrong way:** [no realtime listeners](/firestore/no-realtime-listeners.md); [Node's Pipeline bugs not copied](/firestore/pipelines/node-bugs-not-copied.md) and [the Pipeline surface](/firestore/pipelines/dart-surface.md); [admin exceptions](/errors/admin-exceptions.md), [`FirestoreException`](/errors/firestore-exception.md) and [programmer errors](/errors/programmer-errors.md); [unset versus null in Auth updates](/auth/unset-vs-null-sentinel.md); [service access](/app/service-access.md); [overloads and rest parameters](/conventions/no-overloads-or-rest-params.md) and [unions to sealed classes](/conventions/unions-to-sealed-classes.md); [the standalone Firestore package](/firestore/standalone-package.md); [emulator detection](/environment/emulator-detection.md). Then [`Timestamp`](/firestore/timestamp.md) and [acronym casing](/conventions/acronym-casing.md).

# Related

- [Port of the Node.js Admin SDK](/architecture/node-port.md)
- [Pipelines parity with Node](/firestore/pipelines/node-parity.md)
- [Services Node has and Dart does not](/scope/unsupported-services.md)
- [No realtime listeners](/firestore/no-realtime-listeners.md)

[^node-admin-src]: firebase-admin-node `src/`
[^node-admin-firestore]: firebase-admin-node `src/firestore/firestore-internal.ts`
[^node-firestore-src]: google-cloud-node `handwritten/firestore/dev/src/`
[^golden-pin]: The Node SDK pinned for the golden fixtures
[^snapshot-pin]: The Node SDK pinned for the API snapshot
[^node-version]: `_nodeVersion`
