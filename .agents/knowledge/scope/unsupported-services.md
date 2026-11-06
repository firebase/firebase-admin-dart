---
type: Divergence
title: Firebase services Node has and Dart does not
description: Eight Firebase products that Node's Admin SDK offers are marked 🔴 "Not supported" in the README, a ninth, Phone Number Verification, is missing without being listed, and none has a recorded permanent out-of-scope decision.
tags: [scope, services, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/*.dart
  - packages/firebase_admin_sdk/lib/src/app/firebase_service.dart
  - packages/firebase_admin_sdk/README.md
sources:
  - id: readme-supported-services
    resource: ../../../packages/firebase_admin_sdk/README.md
    symbol: "## Supported Services"
    title: The README's support table and its legend
  - id: service-type
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_service.dart
    symbol: enum FirebaseServiceType
    title: The services the Dart SDK implements
  - id: node-phone-number-verification
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/phone-number-verification/index.ts
    symbol: getPhoneNumberVerification
    title: Node's Phone Number Verification
  - id: node-remote-config
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/remote-config/index.ts
    symbol: getRemoteConfig
    title: Node's Remote Config
  - id: node-database
    resource: https://github.com/firebase/firebase-admin-node/blob/main/package.json
    symbol: "@firebase/database-compat"
    title: Node's Realtime Database, through `@firebase/database-compat`
  - id: node-machine-learning
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/machine-learning/index.ts
    symbol: "@deprecated Firebase ML is deprecated"
    title: Node's Machine Learning, deprecated upstream
---

# Node.js

Node's Admin SDK ships Realtime Database,[^node-database] Remote Config,[^node-remote-config] Project Management, Installations, Machine Learning (deprecated upstream, with a shutdown announced),[^node-machine-learning] Eventarc, Extensions, Data Connect and Phone Number Verification.[^node-phone-number-verification]

# Dart

Dart ships none of them. The README's "Supported Services" table marks eight products 🔴, which its legend defines as "Not supported":[^readme-supported-services]

- Data Connect
- Realtime Database
- Event Arc
- Extensions
- Installations
- Machine Learning
- Project Management
- Remote Config

App, App Check, Authentication, Firestore, Functions, Messaging, Security Rules and Storage are 🟢; `FirebaseServiceType` lists the services the SDK implements.[^service-type]

Phone Number Verification has no row in the README at all, though Node ships it, so that gap is undocumented.

These are gaps. The README only says "Not supported", and nothing records a decision that any of these products is out of scope for good. The likely exceptions (not recorded) are Machine Learning, given Node's deprecation, and Extensions: Node's Extensions `Runtime` works only inside an extension (it requires `EXT_INSTANCE_ID`), and a maintainer has said Firebase Extensions don't use the Dart runtime.

# Why

Mostly unknown. The likely reason (not recorded): the supported set follows the module-by-module plan the SDK was built against.

- **Realtime Database:** no reason is recorded. RTDB doesn't go through Firestore's transport, so the reason Firestore has no realtime listeners doesn't explain it.
- **Remote Config:** no decision on the approach is recorded. The admin services go through the generated `googleapis` package, which has no Remote Config client; one proposal uses direct REST calls with server-side template evaluation.

# Rules for agents

- **Ask first:** before starting any of these products. The plan for each is undecided.
- **Must:** when implementing one, follow Node's shape through the existing idioms: `app.x()`, an `@internal` factory, sealed classes for unions and a typed `FirebaseAdminException` subclass (ask a maintainer whether its name takes the "Admin" suffix). The checklist is in [product libraries and barrels](/conventions/product-libraries-and-barrels.md).
- **Must not:** merge a new product module without a maintainer decision on its transport (see [generated REST clients](/architecture/generated-rest-clients.md)).
- **Must not:** describe these products as out of scope for good.

# Related

- [No realtime listeners](/firestore/no-realtime-listeners.md)
- [Admin services use generated REST clients](/architecture/generated-rest-clients.md)
- [No FID message targets](/messaging/fid-targets.md)
- [Product libraries, parts and barrel exports](/conventions/product-libraries-and-barrels.md)

[^node-database]: Node's `@firebase/database-compat` dependency
[^node-remote-config]: Node's Remote Config
[^node-machine-learning]: Node's Machine Learning deprecation
[^node-phone-number-verification]: Node's Phone Number Verification
[^readme-supported-services]: The README's "Supported Services" table
[^service-type]: `FirebaseServiceType`
