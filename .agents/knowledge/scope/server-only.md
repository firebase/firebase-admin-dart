---
type: Decision
title: "Server only: no web, no mobile"
description: Both packages are native, server-side libraries that depend on `dart:io` (and `firebase_admin_sdk` also on `dart:ffi`); web is not supported and the SDK must not be used in mobile apps.
tags: [scope, platforms, security]
agents_md: when-touching
governs:
  - packages/*/pubspec.yaml
  - packages/*/README.md
  - packages/*/example/**
  - packages/firebase_admin_sdk/example_server_app/**
  - packages/*/lib/*.dart
sources:
  - id: admin-dart-io
    resource: ../../../packages/firebase_admin_sdk/lib/src/app.dart
    symbol: import 'dart:io';
    title: The admin SDK imports `dart:io`
  - id: firestore-dart-io
    resource: ../../../packages/google_cloud_firestore/lib/src/credential.dart
    symbol: import 'dart:io';
    title: "`google_cloud_firestore` imports `dart:io`"
  - id: native-environment
    resource: ../../../packages/firebase_admin_sdk/lib/src/utils/native_environment.dart
    symbol: import 'dart:ffi';
    title: "`dart:ffi` and `package:ffi`, for `setenv` and `SetEnvironmentVariableW`"
  - id: admin-readme
    resource: ../../../packages/firebase_admin_sdk/README.md
    symbol: privileged environments
    title: The README's server framing
---

# Where it lives

- Enforced by: the `dart:io` imports, for web only: compilation fails there.[^admin-dart-io][^firestore-dart-io] Nothing enforces it for mobile.
- `firebase_admin_sdk` also needs `dart:ffi`: `native_environment.dart`.[^native-environment]
- The server framing for users: the admin README.[^admin-readme]

# Decision

The SDK targets trusted server environments only. There is no web support, and the SDK must not be used in mobile apps.

**Nothing declares this.** Neither pubspec has a `platforms:` field, so pub.dev infers the platforms and tags both packages `sdk:flutter`, `platform:android` and `platform:ios`. A maintainer has said the mobile tags should be removed with a `platforms:` field.

# Why

The maintainers' stated reasons:

- The Admin SDKs are designed to run in a server environment only, because they need admin privileges such as a service account.
- iOS, Android and web are client environments, which can't be trusted.
- The package depends on `dart:io`, so it won't run on web.

Web support for test setups was requested and declined; the maintainers suggested a small backend API instead, and rejected leaving the choice to users as a serious footgun.

# Rules for agents

- **Must:** treat `dart:io` as allowed anywhere in `lib/`. The Flutter-workspace constraint is about dependency versions, not `dart:io`.
- **Must not:** add web support, try to make the packages web-compatible, or add conditional imports for web.
- **Must not:** advertise mobile platforms.
- **Should:** when you change a pubspec's metadata, declare `platforms:` without `android`, `ios` or `web`.
- **Must not:** add examples or docs that use the Admin SDK in a Flutter client app.

# Related

- [Dependency constraints: bounds, consumers and the SDK floor](/dependencies/constraints.md)
- [Storage wraps google_cloud_storage; emulator via native env](/storage/google-cloud-storage-wrapper.md)

[^admin-readme]: The README's server framing
[^admin-dart-io]: `dart:io` in the admin SDK
[^firestore-dart-io]: `dart:io` in `google_cloud_firestore`
[^native-environment]: `native_environment.dart`
