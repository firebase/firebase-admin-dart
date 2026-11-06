---
type: Divergence
title: Conveniences Dart adds on top of Node
description: Dart adds a few conveniences Node lacks, such as paged `listDocumentsPages`, `Settings.headers`, `FirebaseApp.instance` and `Timestamp.fromMicros`.
tags: [scope, node-parity, firestore]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/reference/collection_reference.dart
  - packages/google_cloud_firestore/lib/src/firestore.dart
  - packages/google_cloud_firestore/lib/src/timestamp.dart
  - packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
sources:
  - id: list-documents-pages
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/collection_reference.dart
    symbol: listDocumentsPages({
    title: "`CollectionReference.listDocumentsPages`"
  - id: settings-headers
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore.dart
    symbol: final Map<String, String>? headers;
    title: "`Settings.headers`"
  - id: app-instance
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
    symbol: static FirebaseApp get instance
    title: "`FirebaseApp.instance`"
  - id: timestamp-from-micros
    resource: ../../../packages/google_cloud_firestore/lib/src/timestamp.dart
    symbol: factory Timestamp.fromMicros
    title: "`Timestamp.fromMicros`"
---

# Node.js

Node has none of these. For example, it lists a collection's documents only through `listDocuments()`.

# Dart

Dart adds:

- `CollectionReference.listDocumentsPages({pageSize, pageToken})`, which returns a `Stream<DocumentReferencePage>`, one page at a time.[^list-documents-pages]
- `Settings.headers`: custom HTTP headers sent with every Firestore request.[^settings-headers]
- `FirebaseApp.instance`, the default app.[^app-instance]
- `Timestamp.fromMicros`.[^timestamp-from-micros]
- `Query.sum()` and `Query.average()` (see [the aggregate API](/firestore/aggregate-api.md)).
- `FirebaseApp.client`, `Credential.createClient` and `AppOptions.additionalScopes` (see [the app client and transport options](/app/app-client-and-transport-options.md)).

# Why

- `listDocumentsPages`: the stated reason, in `google_cloud_firestore`'s CHANGELOG, is that "large collections can be walked without holding every reference in memory".
- `Settings.headers`: the CHANGELOG states it is there to attach custom HTTP headers to every outgoing Firestore request.
- The others: the reason isn't recorded.

# Rules for agents

- **Must:** keep Dart's way.
- **Should:** add a new convenience alongside the Node-equivalent API.

# Related

- [Positional aggregate fields with auto-aliases](/firestore/aggregate-api.md)
- [Public authenticated app client and transport options](/app/app-client-and-transport-options.md)

[^list-documents-pages]: `listDocumentsPages`
[^settings-headers]: `Settings.headers`
[^app-instance]: `FirebaseApp.instance`
[^timestamp-from-micros]: `Timestamp.fromMicros`
