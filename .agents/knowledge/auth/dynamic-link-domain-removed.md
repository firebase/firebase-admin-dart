---
type: Divergence
title: ActionCodeSettings has linkDomain, not dynamicLinkDomain
description: Dart's `ActionCodeSettings` has only `linkDomain`, with no `dynamicLinkDomain`, where Node keeps `dynamicLinkDomain` as deprecated.
tags: [auth, deprecation, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/auth/action_code_settings_builder.dart
sources:
  - id: dart-link-domain
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/action_code_settings_builder.dart
    symbol: final String? linkDomain;
    title: "`ActionCodeSettings.linkDomain`"
  - id: node-dynamic-link-domain
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/auth/action-code-settings-builder.ts
    symbol: dynamicLinkDomain
    title: Node's deprecated `dynamicLinkDomain`
---

# Where it lives

- Enforced by: nothing; review only.
- The field Dart has: `linkDomain` in `action_code_settings_builder.dart`.[^dart-link-domain]

# Node.js

`ActionCodeSettings` has `linkDomain` and keeps `dynamicLinkDomain`, marked `@deprecated use linkDomain instead`.[^node-dynamic-link-domain]

# Dart

`ActionCodeSettings` has only `linkDomain`. `dynamicLinkDomain` is not there, not even as `@Deprecated`: it was removed outright rather than deprecated.

This is a deliberate omission, not a gap.

# Why

- The maintainers' stated reason: it was dropped during review, because a breaking major release was coming anyway, so a deprecation cycle wasn't needed. The change describes `linkDomain` as its replacement.
- The likely background (not recorded): Firebase Dynamic Links is deprecated and shut down upstream, Node added `linkDomain`, and Dart had no users of `dynamicLinkDomain` to deprecate it for.

# Rules for agents

- **Must:** keep Dart's way: only `linkDomain`.
- **Must not:** reintroduce `dynamicLinkDomain`.
- **Ask first:** before porting an API that Node has deprecated. There is no general rule: `dynamicLinkDomain` was dropped, while the `*Legacy` topic methods were ported as `@Deprecated`.

# Related

- [Releases, versioning, CHANGELOG and version.g.dart](/release/releases-and-versioning.md)
- [Messaging: no FID targets, topic management on FCM v1](/messaging/node-differences.md)

[^node-dynamic-link-domain]: Node's `dynamicLinkDomain`
[^dart-link-domain]: `ActionCodeSettings.linkDomain`
