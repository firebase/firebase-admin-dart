---
type: Decision
title: Typed per-service admin exceptions with Node's error codes
description: Admin errors are typed per service under `FirebaseAdminException`, with Node's `service/kebab-code` codes, Node's server-to-client code tables and `toJson()`, but without Node's error extras.
tags: [errors, node-parity]
agents_md: always
governs:
  - packages/firebase_admin_sdk/lib/src/**/*_exception.dart
  - packages/firebase_admin_sdk/lib/src/app/exception.dart
  - packages/firebase_admin_sdk/lib/src/utils/error.dart
  - packages/firebase_admin_sdk/lib/src/*/*_http_client.dart
sources:
  - id: admin-exception
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/exception.dart
    symbol: abstract class FirebaseAdminException implements Exception
    title: The base class, with `code`, `message` and `toJson()`
  - id: admin-to-json
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/exception.dart
    symbol: Map<String, dynamic> toJson()
    title: "`FirebaseAdminException.toJson()`, with only `code` and `message`"
  - id: auth-code-table
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_exception.dart
    symbol: const authServerToClientCode
    title: Auth's server-to-client code table, ported from Node
  - id: rethrow-leftover
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/base_auth.dart
    symbol: throw error;
    title: The one `throw error;` left, in an `onError` closure
  - id: exception-leftover
    resource: ../../../packages/firebase_admin_sdk/lib/src/utils/jwt.dart
    symbol: throw Exception('Failed to fetch JWKS');
    title: The bare `throw Exception(...)` calls left in `jwt.dart`
  - id: contributing-errors
    resource: ../../../CONTRIBUTING.md
    symbol: "### Error Handling"
    title: CONTRIBUTING's error-handling rules
  - id: node-firebase-error
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/utils/error.ts
    symbol: hasCode
    title: Node's `FirebaseError`, with `httpResponse`, `cause` and `hasCode()`
---

# Where it lives

- Enforced by: nothing; review only.
- The base class and its `toJson()`: `FirebaseAdminException` in `app/exception.dart`. Each service's subclass, its error-code enum, and whether it exposes `errorCode` or only `code`: its `*_exception.dart`.[^admin-exception][^admin-to-json]
- The server-to-client code tables, copied from Node: for example `authServerToClientCode` in `auth_exception.dart`.[^auth-code-table]
- The written rules (typed exceptions, Node behaviour where applicable): CONTRIBUTING's `### Error Handling`.[^contributing-errors]

# Decision

Admin errors are typed per service under `FirebaseAdminException`, with Node's `service/kebab-code` strings and Node's server-to-client code tables. The standalone Firestore package has its own `FirestoreException`.

**Node's error extras are a gap.** Node's `FirebaseError` has `httpResponse`, `cause`, `hasCode(code)` (which accepts the code with or without the service prefix) and a richer `toJSON()`.[^node-firebase-error] `FirebaseAdminException` has none of them, and its `toJson()` returns only `code` and `message`. Nothing records a decision to leave them out.

**Known leftovers.** One `throw error;` remains, in an `onError` closure in `auth/base_auth.dart`,[^rethrow-leftover] and `utils/jwt.dart` has a few bare `throw Exception(...)`.[^exception-leftover] Don't copy them.

# Why

The maintainers' stated reasons:

- The codes are official errors that the JS implementation has too, so removing them makes no sense.
- Always using `rethrow` keeps the stack trace.

The likely reason (not recorded) for an enum per service and `implements Exception`: Dart convention.

The reason for the "Admin" suffix (`FirebaseAuthAdminException`) isn't recorded. The likely reason (not recorded): it avoids clashing with FlutterFire's `FirebaseAuthException`. `FirebaseAppCheckException` and `FirebaseSecurityRulesException` lack the suffix; whether it is a rule for new services is undecided, so ask a maintainer.

Deriving FCM error codes from the HTTP status and pruning "duplicated" codes was rejected.

Why Node's error extras aren't ported isn't recorded.

# Rules for agents

- **Must:** match Node for code strings, messages and when each is thrown, where applicable.
- **Ask first:** before changing a place where Dart knowingly differs, such as [re-initializing an app with a different credential](/app/reinit-ignores-credential.md), or [the `app/` prefix in the Firestore wrapper](/firestore/multi-database.md).
- **Must:** keep Dart's class shape: an enum per service, and `implements Exception`.
- **Must:** map from the server's error code. Fall back to the HTTP status only when the response carries none, as Node does (see the non-JSON branch in `messaging/fmc_exception.dart`).
- **Must not:** remove codes that exist in Node.
- **Must not:** throw a bare `Exception` in new code.
- **Must not:** write `throw e` where `rethrow` keeps the stack.
- **Ask first:** before adding `httpResponse`, `cause`, `hasCode` or a richer `toJson()`. If they are added, follow Node's semantics with Dart names: `hasCode`, and `cause` as an `Object?`, possibly with a `StackTrace`.

# Related

- [FirestoreException is separate and maps HTTP to gRPC codes](/errors/firestore-exception.md)
- [Re-initializing an app ignores a different credential](/app/reinit-ignores-credential.md)
- [One cached Firestore per database, settings fixed](/firestore/multi-database.md)

[^admin-exception]: `FirebaseAdminException`
[^admin-to-json]: `FirebaseAdminException.toJson()`
[^auth-code-table]: `authServerToClientCode`
[^contributing-errors]: CONTRIBUTING's `### Error Handling`
[^node-firebase-error]: Node's `FirebaseError`
[^rethrow-leftover]: `throw error;` in `base_auth.dart`
[^exception-leftover]: `throw Exception` in `jwt.dart`
