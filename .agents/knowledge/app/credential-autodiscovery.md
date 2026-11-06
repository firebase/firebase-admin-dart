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

# Decision

When the caller passes no credential, the SDK discovers one:[^credential-from-env]

1. If `GOOGLE_APPLICATION_CREDENTIALS` points to a service-account file, that file becomes the credential.
2. Otherwise, the SDK falls back to Application Default Credentials.

Discovery runs both for `initializeApp()` without options and for `AppOptions` whose `credential` is null, so setting other options doesn't turn it off.[^null-credential-case]

# Why

The maintainers' stated reason: discovery that runs only when `options` is null altogether leaves callers that set any other option without a credential. Extending it to options with a null `credential` fixed this for the Dart Cloud Functions runtime (`firebase_functions`).

The alternative would be to require an explicit credential; no discussion of it is recorded.

# Rules for agents

- **Must not:** make `credential` required.
- **Must not:** skip discovery when other options are set.

# Related

- [Credential is a sealed class with factories](/app/credential-sealed-hierarchy.md)
- [Stay resolvable for firebase_functions and Flutter workspaces](/dependencies/flutter-and-functions-consumers.md)

[^credential-from-env]: Discovery from `GOOGLE_APPLICATION_CREDENTIALS`
[^null-credential-case]: Discovery for options without a credential
