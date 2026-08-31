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

// Firestore Pipeline examples.
//
// Pipelines require a Firestore **Enterprise edition** database. Running these
// against a Standard edition database fails with an `unimplemented` error.
//
// Set the database up front, e.g.:
//
//   export GOOGLE_CLOUD_PROJECT="your-project-id"
//   dart run example/pipeline_example.dart your-enterprise-database-id
//
// Each example seeds the documents it needs and deletes them afterwards, so
// they can be run individually and in any order.

import 'package:google_cloud_firestore/google_cloud_firestore.dart';

Future<void> main(List<String> args) async {
  final databaseId = args.isEmpty ? '(default)' : args.first;
  final firestore = Firestore(settings: Settings(databaseId: databaseId));

  await basicPipeline(firestore);
  await aggregatePipeline(firestore);
  await unnestPipeline(firestore);
  await replaceWithPipeline(firestore);
  await distinctAndSamplePipeline(firestore);
  await unionPipeline(firestore);
  await vectorSearchPipeline(firestore);
  await queryToPipeline(firestore);
}

/// Source, filter, sort, project and limit.
Future<void> basicPipeline(Firestore firestore) async {
  print('\n### Basic pipeline ###\n');

  await _withBooks(firestore, (books) async {
    // [START firestore_pipelines_basic]
    final snapshot = await firestore
        .pipeline()
        .collection(books.path)
        .where(field('rating').greaterThan(4.0))
        .sort([field('rating').descending()])
        .select([
          'title',
          'rating',
          field('title').toUpper().as('shoutedTitle'),
          field('tags').arrayLength().as('tagCount'),
        ])
        .limit(10)
        .execute();

    for (final result in snapshot.results) {
      print('> ${result.data()}');
    }
    // [END firestore_pipelines_basic]
  });
}

/// Aggregates, with and without grouping.
Future<void> aggregatePipeline(Firestore firestore) async {
  print('\n### Aggregate pipeline ###\n');

  await _withBooks(firestore, (books) async {
    // [START firestore_pipelines_aggregate]
    // Aggregate over every input document.
    final totals = await firestore.pipeline().collection(books.path).aggregate([
      PipelineFunctions.count().as('bookCount'),
      field('rating').average().as('averageRating'),
      field('rating').maximum().as('bestRating'),
    ]).execute();

    print('> Totals: ${totals.results.single.data()}');

    // Or group first, producing one document per genre.
    final byGenre = await firestore
        .pipeline()
        .collection(books.path)
        .aggregate(
          [
            PipelineFunctions.count().as('bookCount'),
            field('rating').average().as('averageRating'),
          ],
          groups: ['genre'],
        )
        .sort([field('genre').ascending()])
        .execute();

    for (final result in byGenre.results) {
      print('> ${result.data()}');
    }
    // [END firestore_pipelines_aggregate]
  });
}

/// Emits one document per array element.
Future<void> unnestPipeline(Firestore firestore) async {
  print('\n### Unnest pipeline ###\n');

  await _withBooks(firestore, (books) async {
    // [START firestore_pipelines_unnest]
    // The selectable's alias names the field each element lands on, so
    // `field('tags').as('tag')` emits one document per tag with a `tag` field.
    // `indexField` additionally records each element's position.
    final snapshot = await firestore
        .pipeline()
        .collection(books.path)
        .unnest(field('tags').as('tag'), indexField: 'tagIndex')
        .select(['title', 'tag', 'tagIndex'])
        .sort([field('title').ascending(), field('tagIndex').ascending()])
        .execute();

    for (final result in snapshot.results) {
      print(
        '> ${result.get('title')} #${result.get('tagIndex')}: '
        '${result.get('tag')}',
      );
    }
    // [END firestore_pipelines_unnest]
  });
}

/// Promotes a nested map to the top level, and adds/removes fields.
Future<void> replaceWithPipeline(Firestore firestore) async {
  print('\n### ReplaceWith pipeline ###\n');

  await _withBooks(firestore, (books) async {
    // [START firestore_pipelines_replace_with]
    final snapshot = await firestore
        .pipeline()
        .collection(books.path)
        .where(field('metadata').exists())
        // Each key of the `metadata` map becomes a top-level field.
        .replaceWith('metadata')
        .addFields([field('language').toUpper().as('languageCode')])
        .removeFields(['language'])
        .execute();

    for (final result in snapshot.results) {
      print('> ${result.data()}');
    }
    // [END firestore_pipelines_replace_with]
  });
}

/// Unique combinations, plus pseudo-random sampling.
Future<void> distinctAndSamplePipeline(Firestore firestore) async {
  print('\n### Distinct and sample pipeline ###\n');

  await _withBooks(firestore, (books) async {
    // [START firestore_pipelines_distinct]
    final genres = await firestore
        .pipeline()
        .collection(books.path)
        .distinct(['genre'])
        .sort([field('genre').ascending()])
        .execute();

    for (final result in genres.results) {
      print('> Genre: ${result.get('genre')}');
    }
    // [END firestore_pipelines_distinct]

    // [START firestore_pipelines_sample]
    // Sample a fixed number of documents...
    final twoBooks = await firestore
        .pipeline()
        .collection(books.path)
        .sample(documents: 2)
        .execute();
    print('> Sampled ${twoBooks.size} documents');

    // ...or a proportion of them, as a value between 0 and 1.
    final half = await firestore
        .pipeline()
        .collection(books.path)
        .sample(percentage: 0.5)
        .execute();
    print('> Sampled ${half.size} documents by percentage');
    // [END firestore_pipelines_sample]
  });
}

/// Concatenates the results of two pipelines.
Future<void> unionPipeline(Firestore firestore) async {
  print('\n### Union pipeline ###\n');

  await _withBooks(firestore, (books) async {
    // [START firestore_pipelines_union]
    final fiction = firestore
        .pipeline()
        .collection(books.path)
        .where(field('genre').equal('fiction'));

    // `union` keeps duplicates; follow it with `distinct` to drop them.
    final snapshot = await firestore
        .pipeline()
        .collection(books.path)
        .where(field('genre').equal('poetry'))
        .union(fiction)
        .select(['title', 'genre'])
        .execute();

    for (final result in snapshot.results) {
      print('> ${result.get('title')} (${result.get('genre')})');
    }
    // [END firestore_pipelines_union]
  });
}

/// Vector nearest-neighbour search.
///
/// Requires a vector index on the collection group. See the README for the
/// `gcloud firestore indexes composite create` invocation.
Future<void> vectorSearchPipeline(Firestore firestore) async {
  print('\n### Vector search pipeline ###\n');

  await _withBooks(firestore, (books) async {
    // [START firestore_pipelines_find_nearest]
    final snapshot = await firestore
        .pipeline()
        .collection(books.path)
        .findNearest(
          vectorField: 'embedding',
          queryVector: FieldValue.vector([1, 2, 3]),
          distanceMeasure: DistanceMeasure.cosine,
          limit: 3,
          distanceResultField: 'distance',
        )
        .select(['title', 'distance'])
        .execute();

    for (final result in snapshot.results) {
      print('> ${result.get('title')} at ${result.get('distance')}');
    }
    // [END firestore_pipelines_find_nearest]
  });
}

/// Converts an existing [Query] into a Pipeline.
Future<void> queryToPipeline(Firestore firestore) async {
  print('\n### Query to pipeline ###\n');

  await _withBooks(firestore, (books) async {
    // [START firestore_pipelines_create_from]
    // Any Query — filters, ordering, cursors, limit and offset included — can
    // be converted, then extended with Pipeline-only stages.
    final query = books
        .where('genre', WhereFilter.equal, 'fiction')
        .orderBy('rating', descending: true)
        .limit(5);

    final snapshot = await firestore.pipeline().createFrom(query).select([
      'title',
      field('rating').multiply(10).as('score'),
    ]).execute();

    for (final result in snapshot.results) {
      print('> ${result.get('title')} scored ${result.get('score')}');
    }
    // [END firestore_pipelines_create_from]
  });
}

/// Seeds a temporary `books` collection, runs [body], then deletes it.
Future<void> _withBooks(
  Firestore firestore,
  Future<void> Function(CollectionReference<DocumentData> books) body,
) async {
  final books = firestore.collection('pipeline_example_books');

  final seed = <String, DocumentData>{
    'book-1': {
      'title': 'The Hitchhiker\'s Guide to the Galaxy',
      'genre': 'fiction',
      'rating': 4.7,
      'tags': ['comedy', 'space'],
      'language': 'en',
      'embedding': FieldValue.vector([1, 2, 3]),
      'metadata': {'language': 'en', 'pages': 224},
    },
    'book-2': {
      'title': 'Dune',
      'genre': 'fiction',
      'rating': 4.5,
      'tags': ['space', 'politics'],
      'language': 'en',
      'embedding': FieldValue.vector([1, 2, 4]),
      'metadata': {'language': 'en', 'pages': 412},
    },
    'book-3': {
      'title': 'Leaves of Grass',
      'genre': 'poetry',
      'rating': 4.2,
      'tags': ['classic'],
      'language': 'en',
      'embedding': FieldValue.vector([9, 9, 9]),
      'metadata': {'language': 'en', 'pages': 150},
    },
  };

  final batch = firestore.batch();
  for (final entry in seed.entries) {
    batch.set(books.doc(entry.key), entry.value);
  }
  await batch.commit();

  try {
    await body(books);
  } on FirestoreException catch (e) {
    // Pipelines are Enterprise-edition only, and findNearest additionally
    // needs a vector index.
    print('> Firestore error: ${e.message}');
  } finally {
    final cleanup = firestore.batch();
    for (final id in seed.keys) {
      cleanup.delete(books.doc(id));
    }
    await cleanup.commit();
  }
}
