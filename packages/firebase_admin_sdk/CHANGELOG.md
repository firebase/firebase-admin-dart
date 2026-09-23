## 0.5.7-wip

- Use pooled HTTP/2 connections by default via `package:http2`'s `Http2Client` for `FirebaseApp.client`, multiplexing concurrent HTTPS requests over persistent connections while keeping plain HTTP endpoints (such as GCE metadata server) on HTTP/1.1 fallback.

## 0.5.6

- Widen dependency upper bounds for `googleapis` (`>=16.0.0 <18.0.0`), `google_cloud_firestore` (`>=0.5.4 <0.7.0`), and `google_cloud_storage` (`>=0.6.0 <0.8.0`).

## 0.5.5

- Ensure usage tracking headers (`X-Firebase-Client`, `X-Goog-Api-Client`) are appended to outgoing requests without overwriting existing client library headers or duplicating runtime tokens.
- Fixed `app.storage()` ignoring `AppOptions.credential` and authenticating with
  Application Default Credentials instead. Storage now uses the app's
  authenticated client and project ID, like `Firestore` and `FirebaseApp.client`.
- Fixed `app.storage()` starting a credential lookup on construction, which could
  fail as an unhandled exception even when no storage operation was performed.
  The underlying client is now created on first use.
- Project ID resolution now consults the `AppOptions.credential` service account
  before the ambient environment, the gcloud CLI and the GCE metadata server, and
  ignores empty project ID environment variables. Apps configured with a service
  account for one project while running on Google Cloud infrastructure in another
  now resolve the service account's project instead of the host project. This
  also applies to `Firestore`, which previously used `AppOptions.projectId` alone
  and threw `StateError` when only a credential was configured.
- Require `google_cloud_firestore: ^0.5.4`.

## 0.5.4

- Fixed double-close errors when calling `Storage.delete()` prior to `FirebaseApp.close()`.
- Fixed `Firestore` requests not carrying the SDK's usage-tracking headers
  (`X-Firebase-Client`, `X-Goog-Api-Client`).
- Update dependency `googleapis_auth: ^2.3.3` to fix `auth/insufficient-permission`
  errors with Application Default Credentials that have no quota project set.

## 0.5.3

- Require `google_cloud: '>=0.4.0 <0.6.0'`

## 0.5.2

- Remove dependency on `package:equatable`.
- Make `Query`, `CollectionReference`, `DocumentReference`, and `CollectionGroup` mockable.
- `Credential.createClient(List<String> scopes)` — create an authenticated `AuthClient` directly
  from a credential with custom scopes, without needing a `FirebaseApp` instance.
- AppOptions.additionalScopes` — append extra OAuth2 scopes to the SDK-managed HTTP client 
  without providing your own `AuthClient`.
- `FirebaseApp.client` is now part of the public API.
- Add support for custom claims in ID tokens.

## 0.5.1

- Reformatted CHANGELOG.md.
- Update dependency `meta: ^1.17.0` to allow workspaces with stable Flutter.
- Removed dependency on `package:googleapis_beta`.

## 0.5.0

- New release with a new name. See below for historical context.

> [!NOTE]
> Before 0.5.0, this package was published as
> [`package:dart_firebase_admin`](https://pub.dev/packages/dart_firebase_admin/versions/0.4.1)

> [!NOTE]
> Versions 0.0.1 to 0.0.6 were unrelated to this package and were released
> by [OttomanDeveloper](https://github.com/OttomanDeveloper/).

## 0.0.6 - 2024-04-07

- Updated dependencies

## 0.0.5

- Updated dependencies

## 0.0.4

- Updated dependencies

## 0.0.3

- Dart 3 Support Added
- Updated dependencies

## 0.0.2

- Updated dependencies

## 0.0.1

- admin sdk for firebase realtime database
- admin sdk for firebase authentication
- now you can load your service file as map [Just copy the data inside service-account.json file]
