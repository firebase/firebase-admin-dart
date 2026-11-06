---
type: Decision
title: Environment reads go through a zone override first
description: Code that reads environment variables checks `Zone.current[envSymbol]` before `Platform.environment`, so tests can inject or remove variables.
tags: [environment, testing]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/app/environment.dart
  - packages/firebase_admin_sdk/lib/src/app/app_registry.dart
  - packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
  - packages/firebase_admin_sdk/lib/src/app/credential.dart
  - packages/google_cloud_firestore/lib/src/environment.dart
  - packages/google_cloud_firestore/lib/google_cloud_firestore.dart
  - packages/*/test/fixtures/**
sources:
  - id: admin-symbol
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/credential.dart
    symbol: "const envSymbol = #_envSymbol;"
    title: The admin package's `envSymbol`
  - id: firestore-lookup
    resource: ../../../packages/google_cloud_firestore/lib/src/environment.dart
    symbol: Zone.current[envSymbol]
    title: Firestore's zone-first lookup
  - id: admin-lookup
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/environment.dart
    symbol: Zone.current[envSymbol] as Map<String, String>? ?? Platform.environment
    title: The admin package's zone-first lookup
---

# Decision

Code that reads environment variables checks `Zone.current[envSymbol]` before `Platform.environment`, so tests can inject or remove variables.[^admin-lookup][^firestore-lookup] An injected map replaces the process environment instead of layering on top of it.

Each package declares its own `envSymbol` constant, whose value is a library-private symbol, `#_envSymbol`:[^admin-symbol]

- `firebase_admin_sdk` in `lib/src/app/credential.dart`;
- `google_cloud_firestore` in `lib/google_cloud_firestore.dart`.

Private symbols are scoped to their library, so these are two different zone keys: a zone override made for `firebase_admin_sdk` doesn't reach `google_cloud_firestore`. Pass Firestore's environment through `Settings.environmentOverride`.

Consumers that read the environment natively, such as `google_cloud_storage`, ignore zones.

# Why

The maintainers' stated reason: if the code uses zones, the tests should use them too. Zones allow more robust and isolated testing, especially for production tests that need to unset emulator variables.

Rejected alternatives: shell scripts that set variables around `dart test`, and an `environmentOverride` map, which zones replaced (Firestore accepts it in places).

# Rules for agents

- **Must not:** read `Platform.environment` directly in new code.

# Related

- [Emulators found only through standard environment variables](/environment/emulator-detection.md)
- [Storage emulator host set in the native process environment](/environment/storage-emulator-native-env.md)
- [One fixed project-ID resolution order](/app/project-id-resolution.md)
- [Tests inject doubles through internal factories and use guarded emulator helpers](/tests/helpers-and-injection.md)

[^admin-lookup]: The admin package's lookups
[^firestore-lookup]: Firestore's lookup
[^admin-symbol]: The admin `envSymbol`
