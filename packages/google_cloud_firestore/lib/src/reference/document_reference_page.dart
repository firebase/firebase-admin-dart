// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

part of '../firestore.dart';

/// A page of document references returned by
/// [CollectionReference.listDocumentsPages].
@immutable
final class DocumentReferencePage<T> {
  DocumentReferencePage._({
    required this.documents,
    required this.nextPageToken,
  });

  /// The document references in this page, including "missing documents".
  final List<DocumentReference<T>> documents;

  /// The token to pass as `pageToken` to
  /// [CollectionReference.listDocumentsPages] to resume after this page, or
  /// `null` if this is the last page.
  final String? nextPageToken;
}
