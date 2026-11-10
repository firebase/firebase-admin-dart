---
type: Decision
title: Credential discovery when none is passed
description: With no credential, the SDK reads `GOOGLE_APPLICATION_CREDENTIALS` as a service account if it is one and otherwise falls back to ADC.
tags: [app, credentials, environment]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/app/app_registry.dart
  - packages/firebase_admin_sdk/lib/src/app/app_options.dart
sources:
  - id: credential-from-env
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/app_registry.dart
    symbol: env['GOOGLE_APPLICATION_CREDENTIALS']
    title: Service account from `GOOGLE_APPLICATION_CREDENTIALS`, else ADC
  - id: null-credential-case
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/app_registry.dart
    symbol: "AppOptions(credential: null) =>"
    title: Discovery also runs for options without a credential
---

# Where it lives

- Enforced by: nothing; review only.
- The discovery order: `_credentialFromEnv` in `app_registry.dart`.[^credential-from-env]
- Discovery for options without a credential: the `AppOptions(credential: null)` case of `AppRegistry.initializeApp`.[^null-credential-case]

# Decision

When the caller passes no credential, the SDK discovers one from the environment, as Node does. It does so both for `initializeApp()` without options and for `AppOptions` whose `credential` is null, so setting other options doesn't turn discovery off.

# Why

The maintainers' stated reason: discovery that runs only when `options` is null altogether leaves callers that set any other option without a credential. Extending it to options with a null `credential` fixed this for the Dart Cloud Functions runtime (`firebase_functions`).

The original API required an explicit credential; making it optional, with discovery from the environment as Node does, replaced that.

# Rules for agents

- **Must not:** make `credential` required.
- **Must not:** skip discovery when other options are set.

# Related

- [Credential is a sealed class with factories](/app/credential-sealed-hierarchy.md)
- [Stay resolvable for firebase_functions and Flutter workspaces](/dependencies/flutter-and-functions-consumers.md)

[^credential-from-env]: Discovery from `GOOGLE_APPLICATION_CREDENTIALS`
[^null-credential-case]: Discovery for options without a credential
