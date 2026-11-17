---
type: Playbook
title: Compare with Node before changing a Dart API or behaviour
description: How to check a Dart API or behaviour against the Node.js reference before changing it, covering which Node package, file and version to read, how the layouts map, and what to do when Node has something Dart lacks.
tags: [node-parity, porting, playbook]
agents_md: always
governs:
  - packages/*/lib/**
sources:
  - id: parity-test
    resource: ../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: const _nodeVersion
    title: The Pipeline API parity test, and the Node version it expects
  - id: golden-test
    resource: ../../../packages/google_cloud_firestore/test/pipeline_golden_test.dart
    symbol: _knownDivergences
    title: The Pipeline wire-format test against Node-generated fixtures
  - id: golden-pin
    resource: ../../../packages/google_cloud_firestore/tool/pipeline_golden/package.json
    symbol: "@google-cloud/firestore"
    title: The Node SDK pinned for the golden fixtures
  - id: snapshot-pin
    resource: ../../../packages/google_cloud_firestore/tool/pipeline_api_parity/package.json
    symbol: "@google-cloud/firestore"
    title: The Node SDK pinned for the API snapshot
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

# Where it lives

- Enforced by: for Firestore Pipelines only, `test/pipeline_api_parity_test.dart`[^parity-test] and `test/pipeline_golden_test.dart`[^golden-test] in `google_cloud_firestore`. Everything else is review only.
- The Node version Pipelines are checked against: `@google-cloud/firestore` in `tool/pipeline_golden/package.json`[^golden-pin] and `tool/pipeline_api_parity/package.json`,[^snapshot-pin] repeated as `const _nodeVersion` in the parity test.[^parity-test]

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
   - Node's per-service request file, `auth-api-request.ts` for Auth, `messaging-api-request-internal.ts` for Messaging, or `*-api-client-internal.ts` for App Check, Functions and Security Rules, is split in two: `*_http_client.dart` and `*_request_handler.dart` (see [Product libraries, parts and barrel exports](/conventions/product-libraries-and-barrels.md)).
   - Node's hand-written endpoint paths, such as `/accounts:lookup`, mostly become methods of the generated `package:googleapis` client. The exceptions are listed in [Admin services use generated REST clients](/architecture/generated-rest-clients.md).

3. **Pick the Node version.**
   - Firestore Pipelines: the pinned version above. To bump it, follow [Pipelines parity with Node](/firestore/pipelines/node-parity.md).
   - Everything else is unpinned. Compare with the latest release of firebase-admin-node or `@google-cloud/firestore`, and name that version in the PR description. If Node changed behaviour after the Dart port, treat the difference as a gap unless a concept marks it deliberate.

4. **Port Node's test cases.** Node's unit tests (firebase-admin-node `test/unit/<product>/`, google-cloud-node `handwritten/firestore/dev/test/`) list the validation errors and edge cases to reproduce. Port the relevant ones into the matching Dart `test/unit/<product>/` or `test/*.dart`.

5. **Firestore Pipelines: make the automated checks pass.** When one fails, record a deliberate difference, with its reason, in the table the failure names. [Pipelines parity with Node](/firestore/pipelines/node-parity.md) says how to triage.

6. **Everything else: compare by hand.** Only Pipelines have parity checks (see [Port of the Node.js Admin SDK](/architecture/node-port.md)). Don't treat dartdoc as a spec: some of it was ported from Node or is stale.

7. **When Node has a feature and Dart doesn't, it is a gap, unless a concept marks it deliberate.** A difference is an idiom, a transport limit, a deliberate omission, a gap, a Dart-only addition, unclear, or a Node bug not copied (Dart sends something else on purpose because the backend rejects what Node sends). Check the Divergence concepts, then ask a maintainer before you call a feature out of scope. Never "fix" a Node bug not copied back to Node's behaviour.

8. **Check the concepts most often "fixed" the wrong way:** [no realtime listeners](/firestore/rest-transport.md); [Pipelines parity with Node](/firestore/pipelines/node-parity.md), for the Node bugs not copied and the Pipeline surface; [admin exceptions](/errors/admin-exceptions.md) and [Firestore errors](/errors/firestore-exception.md); [unset versus null in Auth updates](/auth/unset-vs-null-sentinel.md); [service access](/app/service-access.md); [Dart idioms over Node's shapes](/architecture/dart-idioms-over-node-shapes.md), for overloads, rest parameters and unions; [the standalone Firestore package](/firestore/standalone-package.md); [emulator detection](/environment/emulator-detection.md). Then [`Timestamp`](/firestore/timestamp.md) and [acronym casing](/conventions/acronym-casing.md).

# Related

- [Port of the Node.js Admin SDK](/architecture/node-port.md)
- [Pipelines parity with Node](/firestore/pipelines/node-parity.md)
- [Firebase services Node has and Dart does not](/scope/unsupported-services.md)
- [Firestore runs over REST: buffered streams, no listeners](/firestore/rest-transport.md)

[^parity-test]: `test/pipeline_api_parity_test.dart`
[^golden-test]: `test/pipeline_golden_test.dart`
[^golden-pin]: The Node SDK pinned for the golden fixtures
[^snapshot-pin]: The Node SDK pinned for the API snapshot
[^node-admin-src]: firebase-admin-node `src/`
[^node-admin-firestore]: firebase-admin-node `src/firestore/firestore-internal.ts`
[^node-firestore-src]: google-cloud-node `handwritten/firestore/dev/src/`
