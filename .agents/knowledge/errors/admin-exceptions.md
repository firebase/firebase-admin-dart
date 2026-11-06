---
type: Decision
title: Typed per-service admin exceptions with Node's error codes
description: Admin errors are typed per service under `FirebaseAdminException`, with Node's `service/kebab-code` codes, Node's server-to-client code tables and `toJson()`.
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
  - id: auth-exception
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_exception.dart
    symbol: class FirebaseAuthAdminException extends FirebaseAdminException
    title: A per-service subclass
  - id: auth-code-table
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_exception.dart
    symbol: const authServerToClientCode
    title: Auth's server-to-client code table, ported from Node
  - id: app-error-code
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/app_exception.dart
    symbol: enum AppErrorCode
    title: A per-service error-code enum
  - id: node-firebase-error
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/utils/error.ts
    symbol: FirebaseError
    title: Node's `FirebaseError`
---

# Decision

Admin errors are typed per service. `FirebaseAdminException` is an `abstract class … implements Exception`.[^admin-exception] Each service subclasses it and carries a typed enum `errorCode`: `FirebaseAuthAdminException(AuthClientErrorCode)`, `FirebaseMessagingAdminException`, `FirebaseAppCheckException`, `FirebaseAppException(AppErrorCode)` and so on.[^auth-exception][^app-error-code]

The rest matches Node's `FirebaseError` and its per-service subclasses:[^node-firebase-error]

- `code` has Node's `service/kebab-code` form, such as `auth/invalid-uid`.
- `message`, and `toJson()` for structured output.
- Server error codes map to client codes through tables copied from Node, such as `authServerToClientCode`.[^auth-code-table] A platform-code message is the fallback.
- Invalid arguments throw these exceptions with `invalid-*` codes, as in Node.

The standalone Firestore package has its own `FirestoreException`.

Catch blocks use `rethrow`. One `throw error;` remains, in an `onError` closure in `auth/base_auth.dart`, and `utils/jwt.dart` has a few `throw Exception(...)`.

# Why

The maintainers' stated reasons:

- The codes are official errors that the JS implementation has too, so removing them makes no sense.
- CONTRIBUTING says "Use typed exceptions … with appropriate error codes for user-facing errors" and "Match the behaviour of the Node.js Admin SDK where applicable."
- Always using `rethrow` keeps the stack trace.

The likely reason (not recorded) for an enum per service and `implements Exception`: Dart convention.

The reason for the "Admin" suffix (`FirebaseAuthAdminException`) isn't recorded. The likely reason (not recorded): it avoids clashing with FlutterFire's `FirebaseAuthException`. `FirebaseAppCheckException` and `FirebaseSecurityRulesException` lack the suffix; whether it is a rule for new services is undecided, so ask a maintainer.

Deriving FCM error codes from the HTTP status and pruning "duplicated" codes was rejected.

# Rules for agents

- **Must:** match Node for code strings, messages and when each is thrown, where applicable.
- **Ask first:** before changing a place where Dart knowingly differs, such as re-initializing an app with a different credential, or the `app/` prefix in the Firestore wrapper.
- **Must:** keep Dart's class shape: an enum per service, and `implements Exception`.
- **Must:** map from the server's error code. Fall back to the HTTP status only when the response carries none, as Node does (see the non-JSON branch in `messaging/fmc_exception.dart`).
- **Must not:** remove codes that exist in Node.
- **Must not:** throw a bare `Exception` in new code.
- **Must not:** write `throw e` where `rethrow` keeps the stack.

# Related

- [Node's error extras are not ported](/errors/node-error-extras.md)
- [FirestoreException is separate and maps HTTP to gRPC codes](/errors/firestore-exception.md)
- [Firestore misuse throws ArgumentError and StateError](/errors/programmer-errors.md)
- [Re-initializing an app ignores a different credential](/app/reinit-ignores-credential.md)

[^admin-exception]: `FirebaseAdminException`
[^auth-exception]: `FirebaseAuthAdminException`
[^app-error-code]: `AppErrorCode`
[^node-firebase-error]: Node's `FirebaseError`
[^auth-code-table]: `authServerToClientCode`
