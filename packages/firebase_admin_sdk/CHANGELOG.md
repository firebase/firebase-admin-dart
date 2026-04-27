## 0.5.2-wip

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
