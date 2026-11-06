---
type: Divergence
title: Named parameters for optional arguments and Pipeline options
description: Node's trailing optional positionals become Dart named parameters; for Pipeline stages, Node options objects also become named parameters (enforced), while the admin services mostly keep Node's options objects as Dart classes.
tags: [conventions, api-design, node-parity]
agents_md: reference
sources:
  - id: parity-options-rule
    resource: ../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: A Node options object
    title: The Pipeline parity test's mapping rules
  - id: order-by-descending
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/query.dart
    symbol: "{bool descending = false}"
    title: "`orderBy(path, descending: true)`"
  - id: send-dry-run
    resource: ../../../packages/firebase_admin_sdk/lib/src/messaging/messaging.dart
    symbol: "{bool? dryRun}"
    title: "`send(message, dryRun: true)`"
---

# Node.js

Node uses trailing optional positionals and options objects:

- `orderBy(path, 'desc')`, `createCustomToken(uid, claims?)`, `listUsers(maxResults?, pageToken?)`, `send(message, dryRun?)`, `initializeApp(options?, name?)`;
- `doc.set(data, {merge: true})`;
- Pipeline stage options objects such as `CollectionStageOptions`.

# Dart

- **Named parameters** replace trailing optional positionals: `orderBy(path, descending: true)`,[^order-by-descending] `createCustomToken(uid, developerClaims: …)`, `listUsers(maxResults: …, pageToken: …)`, `send(message, dryRun: …)`,[^send-dry-run] `initializeApp(options: …, name: …)`, and `set(data, options: SetOptions.merge())`. Some required Node positionals became named too: `setCustomUserClaims(uid, customUserClaims: …)` and `getUserByProviderUid(providerId: …, uid: …)`.
- **Pipeline stages** map a Node options object onto named parameters; a stage's required keys may instead be positional.[^parity-options-rule]
- **Admin services keep Node's options classes** one to one, mostly unshared: `createSessionCookie(idToken, SessionCookieOptions)`, `AppCheck.createToken(appId, [AppCheckTokenOptions?])`, `VerifyAppCheckTokenOptions`, `TaskOptions`, `UserImportOptions` and `ActionCodeSettings`, which four `_BaseAuth` methods share.

# Why

- Pipelines: the stated mapping rule, in the parity test, is that "A Node options object (`CollectionStageOptions`, ...) maps onto Dart named parameters; a stage's required keys may instead be positional."[^parity-options-rule] The parity test enforces it.
- Elsewhere: the likely reason (not recorded) is the same convention. It doesn't extend to options objects: the admin services keep their options classes.

# Rules for agents

- **Must:** for Pipeline APIs, map options objects onto named parameters. The parity test enforces it.
- **Must:** elsewhere, follow the shape the surrounding service already uses. Never use an untyped `Map`.
- **Ask first:** before converting an existing options class to named parameters. It's a breaking change.

# Related

- [Dart idioms win where Node's shape does not fit](/architecture/dart-idioms-over-node-shapes.md)
- [Overloads become separate methods; rest params become lists](/conventions/no-overloads-or-rest-params.md)

[^order-by-descending]: `Query.orderBy`
[^send-dry-run]: `Messaging.send`
[^parity-options-rule]: The parity test's mapping rules
