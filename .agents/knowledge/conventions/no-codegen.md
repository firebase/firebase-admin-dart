---
type: Decision
title: Library code is written by hand
description: Library code uses no code generation; `freezed` was removed and the only generated file is `version.g.dart`.
tags: [conventions, codegen, dependencies]
agents_md: when-touching
governs:
  - packages/*/pubspec.yaml
  - "**/*.g.dart"
sources:
  - id: version-g-dart
    resource: ../../../packages/firebase_admin_sdk/lib/src/version.g.dart
    symbol: GENERATED CODE - DO NOT MODIFY BY HAND
    title: "`version.g.dart`, the one generated library file"
  - id: gen-version
    resource: ../../../scripts/gen-version.sh
    symbol: version.g.dart
    title: The script that writes `version.g.dart`
---

# Decision

Library code in both packages is written by hand. No library type uses `freezed`, `json_serializable` or another code generator.

The only generated library file is `packages/firebase_admin_sdk/lib/src/version.g.dart`,[^version-g-dart] which `scripts/gen-version.sh` writes from the pubspec (see [version.g.dart](/generated/version-g-dart.md)).[^gen-version]

`freezed`, once used for Firestore's settings, was replaced by manual implementations.

# Why

- The maintainers recorded only the fact: code-generation dependencies (`freezed`) were removed in favour of manual implementations. The motive isn't recorded.
- The likely reason (not recorded): fewer dependencies, and no `build_runner` step for consumers or for releases.

Whether "no code generation" is a firm rule or a side effect of splitting Firestore into its own package isn't recorded. Ask a maintainer before adding a generator.

# Rules for agents

- **Must not:** reintroduce `freezed` or `json_serializable` for library types.

# Related

- [version.g.dart is generated from the pubspec](/generated/version-g-dart.md)
- [Keep the dependency set small](/dependencies/minimal-dependencies.md)

[^version-g-dart]: `version.g.dart`
[^gen-version]: `scripts/gen-version.sh`
