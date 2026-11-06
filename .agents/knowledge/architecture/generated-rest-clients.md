---
type: Decision
title: Admin services use generated REST clients from googleapis
description: Admin services call Google's REST/JSON APIs through generated `package:googleapis` discovery clients, and hand-written HTTP is the exception.
tags: [architecture, transport, dependencies]
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
---

# Decision

Admin services call Google's REST/JSON APIs through generated discovery clients from `package:googleapis`:[^googleapis-dependency]

- Auth: identitytoolkit v1, v2 and v3;[^auth-generated-client]
- Messaging: fcm v1;[^messaging-generated-client]
- Security Rules: firebaserules v1;
- Functions: cloudtasks v2;
- App Check: firebaseappcheck v1.

Hand-written HTTP is the exception. Five places use it:

- App Check's `v1beta` `verifyAppCheckToken` call, which is raw REST because the SDK doesn't depend on `googleapis_beta`.[^app-check-rest]
- FCM v1 topic subscriptions, built in `messaging_request_handler.dart`.
- The legacy IID topic calls, through `invokeRequestHandler` in `messaging_http_client.dart`.
- Storage's `getDownloadURL`, which calls the Firebase Storage `v0` endpoint.
- The public-key fetches for token verification in `utils/jwt.dart`, which are plain `GET`s of certificate and JWKS URLs rather than API calls.

Firestore and Storage don't use `googleapis`: Firestore uses the generated `google_cloud_firestore_v1` client, and Storage wraps `google_cloud_storage`.

# Why

The maintainers' stated reason, in part: `googleapis` was adopted because it is the more recent generated layer, and it fixed the encoding of `+` in paths. A maintainer has described `googleapis` as the package all Firebase services are routed through. That statement predates the hand-written FCM topic calls.

Why REST and not gRPC isn't recorded. The likely reason (not recorded): Dart has maintained generated REST clients for these APIs, and none of these admin APIs needs streaming.

Whether hand-written REST is the accepted pattern for APIs missing from `googleapis` is undecided; ask a maintainer. It matters for Remote Config: a port has been proposed over raw REST, because the generated clients can't read `ETag` or send `If-Match`.

# Rules for agents

- **Must not:** add a service on hand-rolled HTTP without a maintainer decision on the transport for that product.
- **Must not:** depend on `googleapis_beta` again.

# Related

- [No general retry layer for admin REST calls](/architecture/admin-http-retries.md)
- [Firestore uses the generated google_cloud_firestore_v1 client](/firestore/generated-client.md)
- [Firestore runs over REST, not gRPC](/firestore/rest-transport.md)
- [Storage is a thin wrapper over google_cloud_storage](/storage/google-cloud-storage-wrapper.md)
- [Firebase services Node has and Dart does not](/scope/unsupported-services.md)

[^googleapis-dependency]: The `googleapis` dependency
[^auth-generated-client]: Auth's generated identitytoolkit clients
[^messaging-generated-client]: Messaging's generated FCM v1 client
[^app-check-rest]: App Check's hand-written `verifyAppCheckToken`
