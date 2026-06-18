## Unreleased

- Updated `Transaction.delete` and `Transaction.update` type constraints to accept `DocumentReference<Object?>`. (thanks to @Levin-Me)

## 0.5.2

- Fixed `Firestore.projectId` not reading `GOOGLE_CLOUD_PROJECT` when using Application Default Credentials locally.
- Fixed `FieldMask` not available from export. (thanks to @OutdatedGuy)
- Require `google_cloud: '>=0.4.0 <0.6.0'`

## 0.5.1

- Added retry support for `WriteBatch.commit()` on transient errors (`ABORTED`, `UNAVAILABLE`, `RESOURCE_EXHAUSTED`).
- Added an example.
- Added a more detailed project description.
- Update dependency `meta: ^1.17.0` to allow workspaces with stable Flutter.

## 0.5.0

- First release.
