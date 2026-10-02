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

/// Live coverage of the map and reference Pipeline functions.
@Tags(['prod'])
library;

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// Matches a [DocumentReference] to the same path as [expected].
Matcher isReferenceTo(DocumentReference<Object?> expected) {
  return isA<DocumentReference<Object?>>().having(
    (reference) => reference.path,
    'path',
    expected.path,
  );
}

void main() {
  pipelineE2E('Pipeline map and reference functions', (ctx) {
    // Book 1's map fields, from the seed table.
    const metadata = {'lang': 'dart', 'category': 'sdk'};
    const stats = {'views': 100, 'likes': 7};

    ctx.functionCases('map construction and access', [
      FunctionCase('map', PipelineFunctions.map(['a', 1, 'b', 2]), {
        'a': 1,
        'b': 2,
      }),
      FunctionCase(
        'map with expression values',
        PipelineFunctions.map([
          'title',
          Expression.field('title'),
          'rating',
          Expression.field('rating'),
        ]),
        {'title': 'Dart Pipelines', 'rating': 5},
      ),
      FunctionCase(
        'mapGetLiteral',
        Expression.field('metadata').mapGetLiteral('category'),
        'sdk',
      ),
      FunctionCase(
        'mapGet',
        Expression.field('metadata').mapGet('lang'),
        'dart',
      ),
      FunctionCase(
        'mapGet with an expression key',
        Expression.field('metadata').mapGet(Expression.constant('category')),
        'sdk',
      ),
      // The key is a literal map key, not a field path.
      FunctionCase(
        'mapGet with a dotted key',
        Expression.field('nested').mapGet('dotted.key'),
        'dot',
      ),
      FunctionCase(
        'static mapGet on a field name',
        PipelineFunctions.mapGet('stats', 'views'),
        isInt(100),
      ),
      FunctionCase(
        'static mapGet on an expression',
        PipelineFunctions.mapGet(
          PipelineFunctions.mapGet('nested', 'level1'),
          Expression.constant('level2'),
        ),
        {'value': 42},
      ),
      FunctionCase(
        'getField',
        Expression.field('stats').getField('likes'),
        isInt(7),
      ),
      FunctionCase(
        'getField with an expression key',
        Expression.field('metadata').getField(Expression.constant('lang')),
        'dart',
      ),
      FunctionCase(
        'static getField on a field name',
        PipelineFunctions.getField('metadata', 'category'),
        'sdk',
      ),
      FunctionCase(
        'static getField on the current document',
        PipelineFunctions.getField(
          PipelineFunctions.currentDocument(),
          Expression.constant('title'),
        ),
        'Dart Pipelines',
      ),
      FunctionCase(
        'currentDocument',
        currentDocument(),
        allOf(
          containsPair('title', 'Dart Pipelines'),
          containsPair('price', 10),
          containsPair('metadata', metadata),
        ),
      ),
    ]);

    ctx.functionCases('map updates', [
      FunctionCase(
        'mapSet',
        Expression.field('metadata').mapSet('edition', 'enterprise'),
        {...metadata, 'edition': 'enterprise'},
      ),
      FunctionCase(
        'mapSet overwrites a key and sets more pairs',
        Expression.field(
          'metadata',
        ).mapSet('lang', 'go', ['edition', 'enterprise']),
        {'lang': 'go', 'category': 'sdk', 'edition': 'enterprise'},
      ),
      FunctionCase(
        'mapSet with expression keys and values',
        Expression.field('stats').mapSet(
          Expression.constant('shares'),
          Expression.field('rating'),
          [Expression.constant('likes'), Expression.field('discount')],
        ),
        {'views': 100, 'likes': 2, 'shares': 5},
      ),
      // Setting a key to an absent value removes it.
      FunctionCase(
        'mapSet to an absent value',
        Expression.field(
          'metadata',
        ).mapSet('lang', Expression.field('missing')),
        {'category': 'sdk'},
      ),
      FunctionCase(
        'static mapSet on a field name',
        PipelineFunctions.mapSet('metadata', ['edition', 'enterprise']),
        {...metadata, 'edition': 'enterprise'},
      ),
      FunctionCase(
        'static mapSet on an expression',
        PipelineFunctions.mapSet(Expression.field('stats'), [
          'views',
          Expression.field('price'),
        ]),
        {'views': 10, 'likes': 7},
      ),
      FunctionCase(
        'mapRemove',
        Expression.field('metadata').mapRemove('lang'),
        {'category': 'sdk'},
      ),
      FunctionCase(
        'mapRemove with an expression key',
        Expression.field('metadata').mapRemove(Expression.constant('lang')),
        {'category': 'sdk'},
      ),
      FunctionCase(
        'chained mapRemove',
        Expression.field('metadata').mapRemove('lang').mapRemove('category'),
        <String, Object?>{},
      ),
      FunctionCase(
        'mapRemove of an absent key',
        Expression.field('metadata').mapRemove('missing'),
        metadata,
      ),
      FunctionCase(
        'static mapRemove on a field name',
        PipelineFunctions.mapRemove('stats', 'likes'),
        {'views': 100},
      ),
      FunctionCase(
        'static mapRemove on an expression',
        PipelineFunctions.mapRemove(
          PipelineFunctions.map(['a', 1, 'b', 2]),
          Expression.constant('a'),
        ),
        {'b': 2},
      ),
      FunctionCase(
        'mapMerge',
        Expression.field('metadata').mapMerge([
          {'edition': 'enterprise'},
        ]),
        {...metadata, 'edition': 'enterprise'},
      ),
      FunctionCase(
        'mapMerge with a map expression',
        Expression.field('metadata').mapMerge([Expression.field('stats')]),
        {...metadata, ...stats},
      ),
      FunctionCase(
        'mapMerge with several maps, later keys winning',
        Expression.field('metadata').mapMerge([
          {'lang': 'go'},
          Expression.field('stats'),
        ]),
        {'lang': 'go', 'category': 'sdk', ...stats},
      ),
      FunctionCase(
        'static mapMerge on a field name',
        PipelineFunctions.mapMerge([
          'metadata',
          {'edition': 'enterprise'},
        ]),
        {...metadata, 'edition': 'enterprise'},
      ),
      FunctionCase(
        'static mapMerge on expressions',
        PipelineFunctions.mapMerge([
          Expression.field('stats'),
          Expression.field('metadata'),
        ]),
        {...stats, ...metadata},
      ),
    ]);

    // The backend does not guarantee the order of keys, values or entries.
    ctx.functionCases('map decomposition', [
      FunctionCase(
        'mapKeys',
        Expression.field('metadata').mapKeys(),
        unorderedEquals(['lang', 'category']),
      ),
      FunctionCase(
        'static mapKeys on a field name',
        PipelineFunctions.mapKeys('stats'),
        unorderedEquals(['views', 'likes']),
      ),
      FunctionCase(
        'static mapKeys on an expression',
        PipelineFunctions.mapKeys(Expression.field('emptyMap')),
        <Object?>[],
      ),
      FunctionCase(
        'mapValues',
        Expression.field('metadata').mapValues(),
        unorderedEquals(['dart', 'sdk']),
      ),
      FunctionCase(
        'static mapValues on a field name',
        PipelineFunctions.mapValues('stats'),
        unorderedEquals([100, 7]),
      ),
      FunctionCase(
        'static mapValues on an expression',
        PipelineFunctions.mapValues(Expression.field('nested.level1')),
        [
          {
            'level2': {'value': 42},
          },
        ],
      ),
      FunctionCase(
        'mapEntries',
        Expression.field('metadata').mapEntries(),
        unorderedEquals([
          {'k': 'lang', 'v': 'dart'},
          {'k': 'category', 'v': 'sdk'},
        ]),
      ),
      FunctionCase(
        'static mapEntries on a field name',
        PipelineFunctions.mapEntries('stats'),
        unorderedEquals([
          {'k': 'views', 'v': 100},
          {'k': 'likes', 'v': 7},
        ]),
      ),
      FunctionCase(
        'static mapEntries on an expression',
        PipelineFunctions.mapEntries(Expression.field('emptyMap')),
        <Object?>[],
      ),
    ]);

    // Book 1's `pathRef` is book 2, a top-level document; `chapter` is a
    // document in a subcollection of book 1, so its parent is a document.
    final chapter = ctx.firestore.doc('${ctx.book1Ref.path}/chapters/c1');

    ctx.functionCases('reference functions', [
      FunctionCase(
        'collectionId',
        Expression.field('pathRef').collectionId(),
        pipelineE2ECollection,
      ),
      FunctionCase(
        'collectionId of a subcollection document',
        Expression.constant(chapter).collectionId(),
        'chapters',
      ),
      FunctionCase(
        'static collectionId on a field name',
        PipelineFunctions.collectionId('pathRef'),
        pipelineE2ECollection,
      ),
      FunctionCase(
        'static collectionId on an expression',
        PipelineFunctions.collectionId(Expression.field('__name__')),
        pipelineE2ECollection,
      ),
      FunctionCase(
        'documentId',
        Expression.field('pathRef').documentId(),
        ctx.book2Ref.id,
      ),
      FunctionCase(
        'static documentId on an expression',
        PipelineFunctions.documentId(Expression.field('__name__')),
        ctx.book1Ref.id,
      ),
      FunctionCase(
        'static documentId on a DocumentReference',
        PipelineFunctions.documentId(chapter),
        'c1',
      ),
      FunctionCase(
        'parent',
        Expression.constant(chapter).parent(),
        isReferenceTo(ctx.book1Ref),
      ),
      FunctionCase(
        'static parent on a DocumentReference',
        PipelineFunctions.parent(chapter),
        isReferenceTo(ctx.book1Ref),
      ),
      FunctionCase(
        'static parent on an expression',
        PipelineFunctions.parent(Expression.constant(chapter)),
        isReferenceTo(ctx.book1Ref),
      ),
      // The parent of a top-level document is the database root, a reference
      // that has no parent itself.
      FunctionCase(
        'parent of a top-level document',
        PipelineFunctions.parent(
          Expression.field('pathRef'),
        ).isType(PipelineValueType.reference),
        true,
      ),
      FunctionCase(
        'parent of the root',
        Expression.field('pathRef').parent().parent(),
        isNull,
      ),
      // A reference is a list of (collection ID, document ID) segments, which
      // referenceSlice slices like an array.
      FunctionCase(
        'referenceSlice',
        Expression.constant(chapter).referenceSlice(0, 1),
        isReferenceTo(ctx.book1Ref),
      ),
      FunctionCase(
        'referenceSlice with expression bounds',
        Expression.field(
          'pathRef',
        ).referenceSlice(Expression.constant(0), Expression.constant(1)),
        isReferenceTo(ctx.book2Ref),
      ),
      FunctionCase(
        'static referenceSlice on a field name',
        PipelineFunctions.referenceSlice('pathRef', 0, 1),
        isReferenceTo(ctx.book2Ref),
      ),
      FunctionCase(
        'static referenceSlice on an expression',
        PipelineFunctions.referenceSlice(
          Expression.constant(chapter),
          Expression.constant(1),
          Expression.constant(1),
        ),
        isReferenceTo(ctx.firestore.doc('chapters/c1')),
      ),
    ]);

    // Collections that hold expressions must be built with array(...) /
    // map(...); the backend rejects them inside a literal array or map value.
    ctx.functionCases('collections holding expressions', [
      FunctionCase(
        'mapMerge',
        Expression.field('metadata').mapMerge([
          {'title': Expression.field('title')},
        ]),
        {...metadata, 'title': 'Dart Pipelines'},
      ),
      FunctionCase(
        'static mapMerge',
        PipelineFunctions.mapMerge([
          Expression.field('metadata'),
          {'price': Expression.field('price')},
        ]),
        {...metadata, 'price': 10},
      ),
      FunctionCase(
        'mapSet with a map value',
        Expression.field(
          'metadata',
        ).mapSet('extra', {'price': Expression.field('price')}),
        {
          ...metadata,
          'extra': {'price': 10},
        },
      ),
      FunctionCase(
        'mapSet with an array value',
        Expression.field(
          'metadata',
        ).mapSet('extra', [Expression.field('price'), 1]),
        {
          ...metadata,
          'extra': [10, 1],
        },
      ),
      FunctionCase(
        'static mapSet',
        PipelineFunctions.mapSet('stats', [
          'extra',
          {'rating': Expression.field('rating')},
        ]),
        {
          ...stats,
          'extra': {'rating': 5},
        },
      ),
      FunctionCase(
        'nestedMap',
        PipelineFunctions.map([
          'nested',
          {'price': Expression.field('price')},
        ]),
        {
          'nested': {'price': 10},
        },
      ),
    ]);
  });
}
