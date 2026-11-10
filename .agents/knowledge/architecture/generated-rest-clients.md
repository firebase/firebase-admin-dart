---
type: Decision
title: Admin services use generated REST clients from googleapis
description: Admin services call Google's REST/JSON APIs through generated `package:googleapis` discovery clients, hand-written HTTP is the exception, and there is no general retry layer as Node has.
tags: [architecture, transport, dependencies, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/**/*_http_client.dart
  - packages/firebase_admin_sdk/pubspec.yaml
sources:
  - id: googleapis-dependency
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "googleapis:"
    title: The `googleapis` dependency
  - id: auth-generated-client
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_http_client.dart
    symbol: auth1.GoogleCloudIdentitytoolkitV1
    title: Auth calls the generated identitytoolkit clients
  - id: messaging-generated-client
    resource: ../../../packages/firebase_admin_sdk/lib/src/messaging/messaging_http_client.dart
    symbol: fmc1.FirebaseCloudMessagingApi
    title: Messaging calls the generated FCM v1 client
  - id: app-check-rest
    resource: ../../../packages/firebase_admin_sdk/lib/src/app_check/app_check_http_client.dart
    symbol: _verifyAppCheckTokenRest
    title: The hand-written `v1beta` `verifyAppCheckToken` call
  - id: node-retry
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/utils/api-request.ts
    symbol: defaultRetryConfig
    title: Node's default retry policy for admin HTTP calls
---

# Where it lives

- Enforced by: nothing; review only.
- Which `googleapis` API and version each service calls: the `googleapis` dependency in the admin `pubspec.yaml`, and the imports of each `*_http_client.dart`, for example `auth_http_client.dart` and `messaging_http_client.dart`.[^googleapis-dependency][^auth-generated-client][^messaging-generated-client]
- The one raw call to a beta API: `_verifyAppCheckTokenRest` in `app_check_http_client.dart`.[^app-check-rest]

# Decision

Admin services call Google's REST/JSON APIs through generated discovery clients from `package:googleapis`. Firestore and Storage don't: Firestore uses the generated `google_cloud_firestore_v1` client, and Storage wraps `google_cloud_storage`.

Hand-written HTTP is the exception, in five places: App Check's `v1beta` `verifyAppCheckToken`, the FCM v1 topic subscriptions, the legacy IID topic calls, Storage's `getDownloadURL`, and the certificate and JWKS fetches in `utils/jwt.dart`. App Check's call is raw REST because the SDK doesn't depend on `googleapis_beta`.

**No retry layer, unlike Node.** Node's admin services share a hand-written `HttpClient` whose `defaultRetryConfig` retries HTTP 503, `ECONNRESET` and `ETIMEDOUT` with exponential backoff.[^node-retry] `firebase_admin_sdk` has no general retry layer, so a transient failure reaches the caller. Firestore has its own retries; see [Firestore retries transient errors like Node](/firestore/retries.md).

# Why

The maintainers' stated reason, in part: `googleapis` was adopted because it is the more recent generated layer, and it fixed the encoding of `+` in paths. A maintainer has described `googleapis` as the package all Firebase services are routed through. That statement predates the hand-written FCM topic calls.

Why REST and not gRPC isn't recorded. The likely reason (not recorded): Dart has maintained generated REST clients for these APIs, and none of these admin APIs needs streaming.

Whether hand-written REST is the accepted pattern for APIs missing from `googleapis` is undecided; ask a maintainer. Remote Config is the open case; see [Firebase services Node has and Dart does not](/scope/unsupported-services.md).

Why there is no retry layer isn't recorded. Ask a maintainer before changing it.

# Rules for agents

- **Must not:** add a service on hand-rolled HTTP without a maintainer decision on the transport for that product.
- **Must not:** depend on `googleapis_beta` again.
- **Ask first:** before adding a retry layer to admin REST calls. Whether they should retry like Node's `defaultRetryConfig` is undecided.

# Related

- [Firestore runs over REST, with buffered streaming](/firestore/rest-transport.md)
- [Firestore retries transient errors like Node](/firestore/retries.md)
- [Storage is a thin wrapper over google_cloud_storage](/storage/google-cloud-storage-wrapper.md)
- [Firebase services Node has and Dart does not](/scope/unsupported-services.md)

[^googleapis-dependency]: The `googleapis` dependency
[^auth-generated-client]: Auth's generated identitytoolkit clients
[^messaging-generated-client]: Messaging's generated FCM v1 client
[^app-check-rest]: App Check's hand-written `verifyAppCheckToken`
[^node-retry]: Node's `defaultRetryConfig`
