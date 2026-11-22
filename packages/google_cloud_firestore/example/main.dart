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

import 'package:google_cloud_firestore/google_cloud_firestore.dart';

void main() async {
  // By default, the `Firestore` class will use the currently configured project
  // and automatically attempt to authenticate using Application Default
  // Credentials.
  //
  // When running locally with `gcloud auth application-default login`, the
  // project ID is not included in the credentials. Set the GOOGLE_CLOUD_PROJECT
  // environment variable or pass it via Settings(projectId: 'your-project-id').
  final firestore = Firestore();

  final users = firestore.collection('users');

  await users.doc('ada-lovelace').set({
    'first': 'Ada',
    'last': 'Lovelace',
    'born': 1815,
  });
  await users.doc('george-boole').set({
    'first': 'George',
    'last': 'Boole',
    'born': 1815,
  });
  await users.doc('grace-hopper').set({
    'first': 'Grace',
    'last': 'Hopper',
    'born': 1906,
  });

  final query = users.where('born', WhereFilter.lessThan, 1900);
  final querySnapshot = await query.get();
  print('Found ${querySnapshot.size} matching people:');
  for (final doc in querySnapshot.docs) {
    final data = doc.data();
    print(' - ${data['first']} ${data['last']}');
  }
}
