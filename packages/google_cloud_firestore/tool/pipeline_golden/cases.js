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

'use strict';

/**
 * The golden corpus: named Pipelines built with the Node.js SDK.
 *
 * Every case id must have a matching entry in
 * `test/pipeline_golden_test.dart`, which builds the same Pipeline with the
 * Dart SDK and compares the requests.
 *
 * Id scheme: `<area>/<subject>/<variant>`.
 *
 * - `static-...` variants call the top-level function
 *   (`PipelineFunctions.x` or a top-level helper in Dart), `method-...`
 *   variants call the `Expression` method (`PipelineExpression` in Dart).
 * - `field-name` is a field passed as a plain string, `expression` an
 *   `Expression`, `literal` a plain value.
 *
 * Function cases are wrapped in a minimal Pipeline over `books`:
 * aggregate functions in `aggregate(<fn>.as('result'))`, boolean
 * expressions in `where(<fn>)`, and everything else in
 * `select(<fn>.as('result'))`.
 *
 * @param {object} sdk The loaded `@google-cloud/firestore` module.
 * @param {FirebaseFirestore.Firestore} db The Firestore instance under test.
 * @returns {Array<{id: string, pipeline: () => object, options?: object}>}
 */
module.exports = function buildCases(sdk, db) {
  const {FieldPath, FieldValue, Filter, GeoPoint, Timestamp, Pipelines: P} =
    sdk;
  const {field, constant, variable} = P;

  const cases = [];
  const ids = new Set();

  /** Registers a case whose Pipeline is built lazily by [pipeline]. */
  function add(id, pipeline, options) {
    if (ids.has(id)) throw new Error(`Duplicate case id: ${id}`);
    ids.add(id);
    cases.push({id, pipeline, options});
  }

  const books = () => db.pipeline().collection('books');

  /** Wraps an expression in the smallest Pipeline that accepts it. */
  function wrap(expr) {
    if (expr instanceof P.AggregateFunction) {
      return books().aggregate(expr.as('result'));
    }
    if (expr instanceof P.BooleanExpression) {
      return books().where(expr);
    }
    return books().select(expr.as('result'));
  }

  /** Registers one function case per entry of [variants]. */
  function fn(area, name, variants) {
    for (const [variant, makeExpr] of Object.entries(variants)) {
      add(`${area}/${name}/${variant}`, () => wrap(makeExpr()));
    }
  }

  /**
   * A function of one target, accepted as a field name or an expression.
   *
   * `static-field-name`: `fn('target')`, `static-expression`:
   * `fn(field('target'))`, `method`: `field('target').method()`.
   */
  function unary(name, target, {area = 'functions', method = name} = {}) {
    fn(area, name, {
      'static-field-name': () => P[name](target),
      'static-expression': () => P[name](field(target)),
      method: () => field(target)[method](),
    });
  }

  /**
   * A function of a target and a second operand.
   *
   * The target is a field name or an expression; the operand is [literal]
   * or the expression built by [operand].
   */
  function binary(name, target, literal, operand, {method = name} = {}) {
    fn('functions', name, {
      'static-field-name-literal': () => P[name](target, literal),
      'static-field-name-expression': () => P[name](target, operand()),
      'static-expression-literal': () => P[name](field(target), literal),
      'static-expression-expression': () => P[name](field(target), operand()),
      'method-literal': () => field(target)[method](literal),
      'method-expression': () => field(target)[method](operand()),
    });
  }

  // Fixed, deterministic values.
  const timestamp = new Timestamp(1700000000, 123456789);
  const date = new Date(Date.UTC(2024, 0, 2, 3, 4, 5, 678));
  const geoPoint = new GeoPoint(37.7749, -122.4194);
  const bytes = new Uint8Array([1, 2, 3, 255]);
  const vector = FieldValue.vector([0.1, 0.2, 0.3]);
  const docRef = () => db.doc('books/book1');

  // ---------------------------------------------------------------------------
  // Sources
  // ---------------------------------------------------------------------------

  add('sources/collection/path', () => db.pipeline().collection('books'));
  add('sources/collection/nested-path', () =>
    db.pipeline().collection('authors/author1/books'),
  );
  add('sources/collection/reference', () =>
    db.pipeline().collection(db.collection('books')),
  );
  add('sources/collection/force-index', () =>
    db.pipeline().collection({collection: 'books', forceIndex: 'my_index'}),
  );
  add('sources/collection/raw-options', () =>
    db.pipeline().collection({
      collection: 'books',
      rawOptions: {foo: 'bar', 'outer.inner': 1},
    }),
  );
  add('sources/collection/reference-raw-options', () =>
    db.pipeline().collection({
      collection: db.collection('books'),
      rawOptions: {foo: 'bar'},
    }),
  );
  add('sources/collection-group/id', () =>
    db.pipeline().collectionGroup('reviews'),
  );
  add('sources/collection-group/force-index', () =>
    db
      .pipeline()
      .collectionGroup({collectionId: 'reviews', forceIndex: 'my_index'}),
  );
  add('sources/collection-group/raw-options', () =>
    db.pipeline().collectionGroup({
      collectionId: 'reviews',
      rawOptions: {foo: 'bar'},
    }),
  );
  add('sources/database/plain', () => db.pipeline().database());
  add('sources/database/raw-options', () =>
    db.pipeline().database({rawOptions: {foo: 'bar'}}),
  );
  add('sources/documents/paths', () =>
    db.pipeline().documents(['books/book1', 'books/book2']),
  );
  add('sources/documents/references', () =>
    db.pipeline().documents([db.doc('books/book1'), db.doc('books/book2')]),
  );
  add('sources/documents/nested', () =>
    db.pipeline().documents([db.doc('authors/author1/books/book1')]),
  );
  add('sources/documents/raw-options', () =>
    db.pipeline().documents({
      docs: [db.doc('books/book1')],
      rawOptions: {foo: 'bar'},
    }),
  );
  add('sources/documents/nested-path', () =>
    db.pipeline().documents(['authors/author1/books/book1']),
  );
  add('sources/documents/leading-slash-path', () =>
    db.pipeline().documents(['/books/book1']),
  );
  add('sources/documents/paths-and-references', () =>
    db.pipeline().documents(['books/book1', db.doc('books/book2')]),
  );
  add('sources/subcollection/as-array-expression', () =>
    db
      .pipeline()
      .collection('books')
      .addFields(
        P.subcollection('reviews')
          .select('rating')
          .toArrayExpression()
          .as('reviews'),
      ),
  );

  // ---------------------------------------------------------------------------
  // createFrom(query)
  // ---------------------------------------------------------------------------

  const fromQuery = query => () => db.pipeline().createFrom(query());
  const col = () => db.collection('books');
  const query = (id, q) => add(`queries/${id}`, fromQuery(q));

  query('collection/plain', () => col());
  query('collection/nested-path', () => db.collection('authors/author1/books'));
  query('collection-group/plain', () => db.collectionGroup('reviews'));
  query('collection-group/where', () =>
    db.collectionGroup('reviews').where('rating', '>', 3),
  );
  query('collection-group/not-equal', () =>
    db.collectionGroup('reviews').where('rating', '!=', 3),
  );

  query('where/less-than', () => col().where('rating', '<', 4));
  query('where/less-than-or-equal', () => col().where('rating', '<=', 4));
  query('where/equal', () => col().where('genre', '==', 'Fantasy'));
  query('where/not-equal', () => col().where('genre', '!=', 'Fantasy'));
  query('where/greater-than-or-equal', () => col().where('rating', '>=', 4));
  query('where/greater-than', () => col().where('rating', '>', 4));
  query('where/array-contains', () =>
    col().where('tags', 'array-contains', 'magic'),
  );
  query('where/in', () => col().where('genre', 'in', ['Fantasy', 'Sci-Fi']));
  query('where/not-in', () =>
    col().where('genre', 'not-in', ['Fantasy', 'Sci-Fi']),
  );
  query('where/array-contains-any', () =>
    col().where('tags', 'array-contains-any', ['magic', 'epic']),
  );
  query('where/equal-null', () => col().where('genre', '==', null));
  query('where/not-equal-null', () => col().where('genre', '!=', null));
  query('where/equal-nan', () => col().where('rating', '==', NaN));
  query('where/double', () => col().where('rating', '>', 4.5));
  query('where/timestamp', () => col().where('published', '<', timestamp));
  query('where/nested-field', () =>
    col().where('metadata.lang', '==', 'en'),
  );
  query('where/special-characters', () =>
    col().where('first-name', '==', 'Ada'),
  );
  query('where/field-path-object', () =>
    col().where(new FieldPath('a.b'), '==', 1),
  );
  query('where/document-id', () =>
    col().where(FieldPath.documentId(), '==', 'book1'),
  );
  query('where/multiple', () =>
    col().where('genre', '==', 'Fantasy').where('rating', '>', 4),
  );
  query('where/composite-and', () =>
    col().where(
      Filter.and(
        Filter.where('genre', '==', 'Fantasy'),
        Filter.where('rating', '>', 4),
      ),
    ),
  );
  query('where/composite-or', () =>
    col().where(
      Filter.or(
        Filter.where('genre', '==', 'Fantasy'),
        Filter.where('rating', '>', 4),
      ),
    ),
  );
  query('where/composite-nested', () =>
    col().where(
      Filter.or(
        Filter.and(
          Filter.where('genre', '==', 'Fantasy'),
          Filter.where('rating', '>', 4),
        ),
        Filter.where('published', '<', 1950),
      ),
    ),
  );

  query('order-by/ascending', () => col().orderBy('rating'));
  query('order-by/descending', () => col().orderBy('rating', 'desc'));
  query('order-by/multiple', () =>
    col().orderBy('rating', 'desc').orderBy('title'),
  );
  query('order-by/document-id', () => col().orderBy(FieldPath.documentId()));
  query('order-by/special-characters', () => col().orderBy('first-name'));
  query('order-by/field-path-object', () =>
    col().orderBy(new FieldPath('a.b')),
  );
  query('order-by/implicit-from-inequality', () =>
    col().where('rating', '>', 4),
  );
  query('order-by/implicit-from-inequalities', () =>
    col().where('rating', '>', 4).where('published', '<', 2000),
  );
  query('order-by/explicit-and-inequality', () =>
    col().where('rating', '>', 4).orderBy('title', 'desc'),
  );
  // '!=' and 'not-in' are inequalities too: the backend orders by their
  // fields, together with the range fields, in field path order.
  query('order-by/implicit-from-mixed-inequalities', () =>
    col().where('rating', '>', 4).where('genre', '!=', 'Horror'),
  );
  query('order-by/implicit-from-repeated-field', () =>
    col().where('rating', '>', 2).where('rating', '<', 5),
  );
  query('order-by/implicit-from-composite-or', () =>
    col().where(
      Filter.or(
        Filter.where('rating', '>', 4),
        Filter.where('genre', 'not-in', ['Horror', 'Romance']),
      ),
    ),
  );
  // Field paths sort segment by segment, not by their quoted form.
  query('order-by/implicit-field-path-order', () =>
    col().where('price-tier', '<', 3).where('price.amount', '>', 1),
  );
  query('order-by/implicit-quoted-segments', () =>
    col()
      .where('field', '>=', 'field 100')
      .where(new FieldPath('field.dot'), '!=', 300)
      .where('field\\slash', '<', 400)
      .orderBy('name', 'desc'),
  );
  query('order-by/not-equal-explicitly-ordered', () =>
    col().where('genre', '!=', 'Horror').orderBy('genre', 'desc'),
  );
  query('order-by/not-in-and-descending', () =>
    col()
      .where('genre', 'not-in', ['Horror', 'Romance'])
      .orderBy('rating', 'desc'),
  );
  query('order-by/document-id-and-inequality', () =>
    col().where(FieldPath.documentId(), '>', 'book1').where('rating', '<', 5),
  );

  query('limit/with-order-by', () => col().orderBy('rating').limit(5));
  query('limit/without-order-by', () => col().limit(5));
  query('limit-to-last/plain', () => col().orderBy('rating').limitToLast(5));
  query('limit-to-last/with-inequality', () =>
    col().where('genre', '!=', 'Horror').orderBy('rating').limitToLast(2),
  );
  query('offset/plain', () => col().offset(10));
  query('offset/with-limit', () => col().orderBy('rating').limit(5).offset(10));

  query('cursor/start-at', () => col().orderBy('rating').startAt(4));
  query('cursor/start-after', () => col().orderBy('rating').startAfter(4));
  query('cursor/end-at', () => col().orderBy('rating').endAt(4));
  query('cursor/end-before', () => col().orderBy('rating').endBefore(4));
  query('cursor/multiple-fields', () =>
    col().orderBy('rating').orderBy('title').startAt(4, 'M'),
  );
  query('cursor/start-and-end', () =>
    col().orderBy('rating').startAfter(2).endAt(4),
  );
  query('cursor/limit-to-last', () =>
    col().orderBy('rating').startAt(2).endBefore(5).limitToLast(3),
  );
  // A cursor is a position in the query's order: on a descending ordering,
  // startAt keeps the smaller values.
  query('cursor/start-at-descending', () =>
    col().orderBy('rating', 'desc').startAt(4),
  );
  query('cursor/end-before-descending', () =>
    col().orderBy('rating', 'desc').endBefore(2),
  );
  query('cursor/mixed-directions', () =>
    col().orderBy('rating', 'desc').orderBy('title').startAfter(4, 'M'),
  );
  query('cursor/descending-limit-to-last', () =>
    col().orderBy('rating', 'desc').startAt(4).endAt(1).limitToLast(2),
  );
  query('cursor/with-inequality', () =>
    col().where('genre', '!=', 'Horror').orderBy('rating').startAfter(4),
  );
  query('cursor/with-inequality-and-limit-to-last', () =>
    col()
      .where('genre', 'not-in', ['Horror'])
      .orderBy('rating')
      .startAfter(2)
      .endAt(4)
      .limitToLast(3),
  );

  query('select/fields', () => col().select('title', 'author'));
  query('select/empty', () => col().select());
  query('select/special-characters', () =>
    col().select('first-name', 'last name'),
  );

  const vectorQuery = (id, makeQuery) => query(`vector/${id}`, makeQuery);
  const nearest = (options, base = col()) =>
    base.findNearest({
      vectorField: 'embedding',
      queryVector: [0.1, 0.2, 0.3],
      limit: 5,
      distanceMeasure: 'EUCLIDEAN',
      ...options,
    });
  vectorQuery('euclidean', () => nearest({}));
  vectorQuery('cosine', () => nearest({distanceMeasure: 'COSINE'}));
  vectorQuery('dot-product', () => nearest({distanceMeasure: 'DOT_PRODUCT'}));
  vectorQuery('vector-value', () => nearest({queryVector: vector}));
  vectorQuery('with-prefilter', () =>
    nearest({}, col().where('genre', '==', 'Fantasy')),
  );
  vectorQuery('distance-result-field', () =>
    nearest({distanceResultField: 'distance'}),
  );
  vectorQuery('distance-threshold', () => nearest({distanceThreshold: 0.5}));
  vectorQuery('special-characters', () =>
    nearest({vectorField: 'my embedding'}),
  );
  vectorQuery('field-path-object', () =>
    nearest({vectorField: new FieldPath('a.b')}),
  );
  vectorQuery('distance-threshold-cosine', () =>
    nearest({distanceMeasure: 'COSINE', distanceThreshold: 0.5}),
  );
  vectorQuery('distance-threshold-dot-product', () =>
    nearest({distanceMeasure: 'DOT_PRODUCT', distanceThreshold: 0.5}),
  );
  vectorQuery('distance-threshold-and-result-field', () =>
    nearest({distanceThreshold: 0.5, distanceResultField: 'distance'}),
  );
  vectorQuery('with-inequality-prefilter', () =>
    nearest({}, col().where('genre', '!=', 'Horror')),
  );

  // ---------------------------------------------------------------------------
  // Stages
  // ---------------------------------------------------------------------------

  const stage = (id, pipeline) => add(`stages/${id}`, pipeline);

  stage('where/condition', () =>
    books().where(field('rating').greaterThan(4)),
  );
  stage('where/chained', () =>
    books()
      .where(field('rating').greaterThan(4))
      .where(field('genre').equal('Fantasy')),
  );
  stage('where/raw-options', () =>
    books().where({
      condition: field('rating').greaterThan(4),
      rawOptions: {foo: 'bar', 'outer.inner': true},
    }),
  );

  stage('select/field-names', () => books().select('title', 'author'));
  stage('select/fields', () =>
    books().select(field('title'), field('author')),
  );
  stage('select/aliased', () =>
    books().select(
      field('title').as('name'),
      field('rating').multiply(2).as('doubled'),
    ),
  );
  stage('select/mixed', () =>
    books().select('title', field('author'), field('rating').as('score')),
  );
  stage('select/nested-field-path', () =>
    books().select('metadata.lang', field('awards.hugo')),
  );
  stage('select/special-characters', () =>
    books().select('first-name', field('last name')),
  );
  stage('select/options-object', () =>
    books().select({selections: ['title', field('rating').as('score')]}),
  );
  stage('select/raw-options', () =>
    books().select({selections: ['title'], rawOptions: {foo: 'bar'}}),
  );

  stage('add-fields/single', () =>
    books().addFields(field('rating').as('copiedRating')),
  );
  stage('add-fields/multiple', () =>
    books().addFields(
      field('rating').as('copiedRating'),
      constant(true).as('annotated'),
    ),
  );
  stage('add-fields/field', () => books().addFields(field('rating')));
  stage('add-fields/raw-options', () =>
    books().addFields({
      fields: [field('rating').as('copiedRating')],
      rawOptions: {foo: 'bar'},
    }),
  );

  stage('remove-fields/field-names', () =>
    books().removeFields('title', 'author'),
  );
  stage('remove-fields/fields', () =>
    books().removeFields(field('title'), field('author')),
  );
  stage('remove-fields/nested', () => books().removeFields('metadata.lang'));
  stage('remove-fields/raw-options', () =>
    books().removeFields({fields: ['title'], rawOptions: {foo: 'bar'}}),
  );
  stage('remove-fields/special-characters', () =>
    books().removeFields('first-name', field('last name')),
  );

  stage('sort/ascending-method', () => books().sort(field('rating').ascending()));
  stage('sort/descending-method', () =>
    books().sort(field('rating').descending()),
  );
  stage('sort/multiple', () =>
    books().sort(field('rating').descending(), field('title').ascending()),
  );
  stage('sort/top-level-field-name', () =>
    books().sort(P.ascending('rating'), P.descending('title')),
  );
  stage('sort/top-level-expression', () =>
    books().sort(
      P.ascending(field('rating')),
      P.descending(field('title').charLength()),
    ),
  );
  stage('sort/expression-method', () =>
    books().sort(field('title').charLength().descending()),
  );
  stage('sort/raw-options', () =>
    books().sort({
      orderings: [field('rating').descending()],
      rawOptions: {foo: 'bar'},
    }),
  );
  stage('sort/special-characters', () =>
    books().sort(P.ascending('first-name'), field('last name').descending()),
  );

  stage('offset/plain', () => books().offset(10));
  stage('offset/raw-options', () =>
    books().offset({offset: 10, rawOptions: {foo: 'bar'}}),
  );
  stage('limit/plain', () => books().limit(10));
  stage('limit/zero', () => books().limit(0));
  stage('limit/raw-options', () =>
    books().limit({limit: 10, rawOptions: {foo: 'bar'}}),
  );

  stage('distinct/field-names', () => books().distinct('genre', 'author'));
  stage('distinct/fields', () => books().distinct(field('genre')));
  stage('distinct/aliased', () =>
    books().distinct(field('genre').toLower().as('lowerGenre')),
  );
  stage('distinct/raw-options', () =>
    books().distinct({groups: ['genre'], rawOptions: {foo: 'bar'}}),
  );
  stage('distinct/special-characters', () =>
    books().distinct('first-name', field('last name')),
  );

  stage('aggregate/single', () => books().aggregate(P.countAll().as('total')));
  stage('aggregate/multiple', () =>
    books().aggregate(
      P.countAll().as('total'),
      P.average('rating').as('averageRating'),
    ),
  );
  stage('aggregate/groups-field-names', () =>
    books().aggregate({
      accumulators: [P.countAll().as('total')],
      groups: ['genre'],
    }),
  );
  stage('aggregate/groups-mixed', () =>
    books().aggregate({
      accumulators: [
        P.countAll().as('total'),
        P.maximum('rating').as('best'),
      ],
      groups: [
        'genre',
        field('author'),
        field('published').divide(10).floor().as('decade'),
      ],
    }),
  );
  stage('aggregate/raw-options', () =>
    books().aggregate({
      accumulators: [P.countAll().as('total')],
      groups: ['genre'],
      rawOptions: {foo: 'bar'},
    }),
  );
  stage('aggregate/groups-special-characters', () =>
    books().aggregate({
      accumulators: [P.countAll().as('total')],
      groups: ['first-name', field('last name')],
    }),
  );

  const findNearest = options =>
    books().findNearest({
      field: 'embedding',
      vectorValue: [0.1, 0.2, 0.3],
      distanceMeasure: 'euclidean',
      ...options,
    });
  stage('find-nearest/number-array', () => findNearest({}));
  stage('find-nearest/integer-array', () =>
    findNearest({vectorValue: [1, 2, 3]}),
  );
  stage('find-nearest/vector-value', () => findNearest({vectorValue: vector}));
  stage('find-nearest/field', () => findNearest({field: field('embedding')}));
  stage('find-nearest/cosine', () => findNearest({distanceMeasure: 'cosine'}));
  stage('find-nearest/dot-product', () =>
    findNearest({distanceMeasure: 'dot_product'}),
  );
  stage('find-nearest/limit', () => findNearest({limit: 10}));
  stage('find-nearest/distance-field', () =>
    findNearest({distanceField: 'distance'}),
  );
  stage('find-nearest/all-options', () =>
    findNearest({limit: 10, distanceField: 'distance'}),
  );
  // rawOptions override the typed options they share a name with.
  stage('find-nearest/raw-options', () =>
    findNearest({
      limit: 10,
      distanceField: 'distance',
      rawOptions: {limit: 20, 'extra.flag': true},
    }),
  );
  stage('find-nearest/special-characters', () =>
    findNearest({field: 'my embedding', distanceField: 'my distance'}),
  );

  stage('replace-with/field-name', () => books().replaceWith('metadata'));
  stage('replace-with/field', () => books().replaceWith(field('metadata')));
  stage('replace-with/map-expression', () =>
    books().replaceWith(
      P.map({title: field('title'), rating: field('rating')}),
    ),
  );
  stage('replace-with/raw-options', () =>
    books().replaceWith({map: 'metadata', rawOptions: {foo: 'bar'}}),
  );

  stage('sample/documents', () => books().sample(10));
  stage('sample/documents-option', () => books().sample({documents: 10}));
  stage('sample/percentage', () => books().sample({percentage: 0.25}));
  stage('sample/raw-options', () =>
    books().sample({documents: 10, rawOptions: {foo: 'bar'}}),
  );

  stage('union/plain', () =>
    books().union(db.pipeline().collection('magazines')),
  );
  stage('union/complex', () =>
    books()
      .select('title')
      .union(
        db
          .pipeline()
          .collectionGroup('reviews')
          .where(field('rating').greaterThan(3))
          .select('title'),
      ),
  );
  stage('union/raw-options', () =>
    books().union({
      other: db.pipeline().collection('magazines'),
      rawOptions: {foo: 'bar'},
    }),
  );

  stage('unnest/field', () => books().unnest(field('tags')));
  stage('unnest/aliased-field', () => books().unnest(field('tags').as('tag')));
  stage('unnest/index-field', () =>
    books().unnest(field('tags').as('tag'), 'index'),
  );
  stage('unnest/expression', () =>
    books().unnest(P.array([1, 2, field('rating')]).as('item')),
  );
  stage('unnest/options-object', () =>
    books().unnest({selectable: field('tags').as('tag'), indexField: 'idx'}),
  );
  stage('unnest/raw-options', () =>
    books().unnest({
      selectable: field('tags').as('tag'),
      indexField: 'idx',
      rawOptions: {index_field: field('position'), foo: 'bar'},
    }),
  );
  stage('unnest/special-characters', () =>
    books().unnest(field('tags').as('my tag'), 'tag index'),
  );
  stage('unnest/field-special-characters', () =>
    books().unnest(field('my tags')),
  );

  stage('raw-stage/expression-params', () =>
    books().rawStage('where', [field('rating').greaterThan(4)]),
  );
  stage('raw-stage/literal-params', () => books().rawStage('limit', [10]));
  stage('raw-stage/string-params', () =>
    books().rawStage('custom', ['a', 1.5, true, null]),
  );
  stage('raw-stage/plain-object-param', () =>
    books().rawStage('select', [{title: field('title'), one: 1}]),
  );
  stage('raw-stage/nested-plain-object-param', () =>
    books().rawStage('select', [{meta: {lang: field('lang')}}]),
  );
  // A plain object param is a literal map whose values go through
  // valueToDefaultExpr: a nested object or array becomes a map(...) or
  // array(...) function, with or without expressions in it.
  stage('raw-stage/plain-object-param-literals', () =>
    books().rawStage('custom', [{a: 1, b: 'x', c: null}]),
  );
  stage('raw-stage/empty-object-param', () => books().rawStage('custom', [{}]));
  stage('raw-stage/nested-plain-object-param-literals', () =>
    books().rawStage('custom', [{meta: {lang: 'en', year: 2020}}]),
  );
  stage('raw-stage/nested-empty-object-param', () =>
    books().rawStage('custom', [{meta: {}}]),
  );
  stage('raw-stage/array-in-object-param', () =>
    books().rawStage('custom', [{tags: [field('genre'), 'classic']}]),
  );
  stage('raw-stage/array-in-object-param-literals', () =>
    books().rawStage('custom', [{tags: [1, 2]}]),
  );
  stage('raw-stage/deeply-nested-object-param', () =>
    books().rawStage('custom', [
      {a: {b: {c: field('x')}, d: [field('y'), {e: 1}]}},
    ]),
  );
  stage('raw-stage/constant-in-object-param', () =>
    books().rawStage('custom', [{meta: constant({lang: 'en'})}]),
  );
  stage('raw-stage/array-param', () =>
    books().rawStage('custom', [[1, 'a', field('title')]]),
  );
  // Any other param, an array included, is a constant: a literal value all
  // the way down.
  stage('raw-stage/array-param-literals', () =>
    books().rawStage('custom', [[1, 2, 3]]),
  );
  stage('raw-stage/nested-array-param', () =>
    books().rawStage('custom', [[1, [2, field('x')]]]),
  );
  stage('raw-stage/object-in-array-param', () =>
    books().rawStage('custom', [[{a: field('x'), b: {c: 1}}]]),
  );
  stage('raw-stage/aggregate-params', () =>
    books().rawStage('aggregate', [
      {total: P.countAll(), best: P.maximum('rating')},
      {genre: field('genre')},
    ]),
  );
  stage('raw-stage/options', () =>
    books().rawStage(
      'find_nearest',
      [field('embedding'), vector, 'euclidean'],
      {limit: 10, distance_field: field('distance')},
    ),
  );
  stage('raw-stage/options-dot-notation', () =>
    books().rawStage('custom', [], {'outer.inner': 'value'}),
  );
  stage('raw-stage/options-nested-object', () =>
    books().rawStage('custom', [], {outer: {inner: 'value', n: 1}}),
  );
  stage('raw-stage/options-expression-values', () =>
    books().rawStage('custom', [], {
      target: field('x'),
      nested: {target: field('y')},
    }),
  );
  stage('raw-stage/options-dot-notation-siblings', () =>
    books().rawStage('custom', [], {'outer.a': 1, 'outer.b': 2}),
  );
  stage('raw-stage/options-dot-notation-deep', () =>
    books().rawStage('custom', [], {'a.b.c': true}),
  );
  // Keys apply in order: a dotted key merges into an earlier object, an
  // object replaces what earlier dotted keys built, and a dotted key
  // replaces an earlier value that is not a map.
  stage('raw-stage/options-dot-notation-merges-object', () =>
    books().rawStage('custom', [], {outer: {a: 1}, 'outer.b': 2}),
  );
  stage('raw-stage/options-object-replaces-dot-notation', () =>
    books().rawStage('custom', [], {'outer.a': 1, outer: {b: 2}}),
  );
  stage('raw-stage/options-dot-notation-replaces-scalar', () =>
    books().rawStage('custom', [], {outer: 'x', 'outer.a': 1}),
  );
  // Segments are not unescaped: backticks are part of the name.
  stage('raw-stage/options-dot-notation-backticks', () =>
    books().rawStage('custom', [], {'a.`b.c`': 1}),
  );

  stage('search/query-string', () => books().search({query: 'breakfast'}));
  stage('search/query-expression', () =>
    books().search({query: P.documentMatches('breakfast')}),
  );
  stage('search/limit-offset', () =>
    books().search({query: 'breakfast', limit: 10, offset: 5}),
  );
  stage('search/retrieval-depth-language', () =>
    books().search({
      query: 'breakfast',
      retrievalDepth: 100,
      languageCode: 'en',
    }),
  );
  stage('search/sort-single', () =>
    books().search({query: 'breakfast', sort: P.score().descending()}),
  );
  stage('search/sort-list', () =>
    books().search({
      query: 'breakfast',
      sort: [P.score().descending(), field('title').ascending()],
    }),
  );
  stage('search/add-fields', () =>
    books().search({
      query: 'breakfast',
      addFields: [P.score().as('searchScore')],
    }),
  );
  stage('search/raw-options', () =>
    books().search({
      query: 'breakfast',
      limit: 10,
      rawOptions: {limit: 20, 'extra.flag': true},
    }),
  );

  stage('define/plain', () =>
    books().define(field('rating').as('currentRating')),
  );
  stage('delete/plain', () => books().delete());
  stage('update/plain', () =>
    books().update([field('rating').add(1).as('rating')]),
  );
  stage('to-scalar-expression/plain', () =>
    books().addFields(
      db
        .pipeline()
        .collection('reviews')
        .aggregate(P.average('rating').as('avg'))
        .toScalarExpression()
        .as('averageRating'),
    ),
  );

  // ---------------------------------------------------------------------------
  // Execute options
  // ---------------------------------------------------------------------------

  const execute = (id, options) => add(`options/${id}`, books, options);

  execute('none/plain', undefined);
  execute('none/empty-object', {});
  execute('index-mode/recommended', {indexMode: 'recommended'});
  execute('explain/mode-analyze', {explainOptions: {mode: 'analyze'}});
  execute('explain/mode-execute', {explainOptions: {mode: 'execute'}});
  execute('explain/output-format-text', {explainOptions: {outputFormat: 'text'}});
  execute('explain/mode-and-output-format', {
    explainOptions: {mode: 'analyze', outputFormat: 'text'},
  });
  execute('explain/empty', {explainOptions: {}});
  execute('combined/index-mode-and-explain', {
    indexMode: 'recommended',
    explainOptions: {mode: 'analyze', outputFormat: 'text'},
  });
  execute('raw-options/flat', {rawOptions: {foo: 'bar', count: 3}});
  execute('raw-options/nested-object', {
    rawOptions: {explain_options: {mode: 'analyze'}},
  });
  execute('raw-options/dot-notation', {
    rawOptions: {'explain_options.mode': 'analyze'},
  });
  execute('raw-options/override-known', {
    indexMode: 'recommended',
    rawOptions: {index_mode: 'custom'},
  });
  execute('raw-options/merge-into-explain', {
    explainOptions: {mode: 'analyze'},
    rawOptions: {'explain_options.output_format': 'text'},
  });
  execute('raw-options/dot-notation-overrides-known', {
    explainOptions: {mode: 'analyze', outputFormat: 'text'},
    rawOptions: {'explain_options.mode': 'execute'},
  });
  execute('raw-options/object-replaces-known', {
    explainOptions: {mode: 'analyze', outputFormat: 'text'},
    rawOptions: {explain_options: {mode: 'execute'}},
  });
  execute('raw-options/dot-notation-into-empty-explain', {
    explainOptions: {},
    rawOptions: {'explain_options.mode': 'analyze'},
  });
  execute('raw-options/dot-notation-replaces-known-scalar', {
    indexMode: 'recommended',
    rawOptions: {'index_mode.mode': 'custom'},
  });
  execute('raw-options/dot-notation-siblings', {
    rawOptions: {'outer.a': 1, 'outer.b': 'two'},
  });
  execute('raw-options/dot-notation-deep', {rawOptions: {'a.b.c': true}});

  // ---------------------------------------------------------------------------
  // Values: constants, fields, variables and plain values in value positions
  // ---------------------------------------------------------------------------

  const selectConstant = (id, value) =>
    add(`values/constant/${id}`, () =>
      books().select(constant(value).as('result')),
    );
  selectConstant('integer', 42);
  selectConstant('negative-integer', -7);
  selectConstant('zero', 0);
  selectConstant('double', 3.14);
  selectConstant('nan', NaN);
  selectConstant('infinity', Infinity);
  selectConstant('negative-infinity', -Infinity);
  selectConstant('string', 'Fantasy');
  selectConstant('empty-string', '');
  selectConstant('true', true);
  selectConstant('false', false);
  selectConstant('null', null);
  selectConstant('timestamp', timestamp);
  selectConstant('timestamp-millis', new Timestamp(1700000000, 123000000));
  selectConstant('date', date);
  selectConstant('geo-point', geoPoint);
  selectConstant('bytes', bytes);
  add('values/constant/document-reference', () =>
    books().select(constant(docRef()).as('result')),
  );
  selectConstant('vector', vector);
  selectConstant('array', [1, 'a', true, null]);
  selectConstant('map', {a: 1, b: 'x', nested: {c: [1, 2]}});

  const selectField = (id, name) =>
    add(`values/field/${id}`, () => books().select(field(name).as('result')));
  selectField('simple', 'title');
  selectField('nested', 'metadata.lang');
  selectField('document-id', '__name__');
  selectField('special-characters', 'first-name');
  selectField('space', 'last name');
  selectField('non-ascii', 'naïve');
  selectField('backtick', 'a`b');
  selectField('backslash', 'a\\b');
  selectField('reserved-characters', 'a/b');
  add('values/field/field-path-object', () =>
    books().select(field(new FieldPath('a.b', 'c')).as('result')),
  );
  add('values/field/field-name-argument', () =>
    books().where(P.equal('first-name', 'Ada')),
  );

  add('values/variable/plain', () =>
    books().select(variable('x').as('result')),
  );

  // A plain value in a value position, carried by `equal`.
  const equalValue = (id, makeValue) =>
    add(`values/value-position/${id}`, () =>
      books().where(field('value').equal(makeValue())),
    );
  equalValue('integer', () => 1);
  equalValue('double', () => 1.5);
  equalValue('string', () => 'a');
  equalValue('boolean', () => true);
  equalValue('null', () => null);
  equalValue('timestamp', () => timestamp);
  equalValue('date', () => date);
  equalValue('geo-point', () => geoPoint);
  equalValue('bytes', () => bytes);
  equalValue('document-reference', docRef);
  equalValue('vector', () => vector);
  equalValue('list-plain', () => ['a', 'b']);
  equalValue('list-with-expression', () => ['a', field('b')]);
  equalValue('list-nested', () => [['a'], {k: 'v'}]);
  equalValue('list-empty', () => []);
  equalValue('map-plain', () => ({a: 1, b: 'x'}));
  equalValue('map-with-expression', () => ({a: field('x'), b: 1}));
  equalValue('map-nested', () => ({inner: {k: field('y')}, list: [field('z')]}));
  equalValue('map-empty', () => ({}));
  equalValue('constant-list', () => constant(['a', 'b']));

  // The "supported data types" Node system test.
  add('values/data-types/all-constants', () =>
    books()
      .limit(1)
      .select(
        constant(1).as('number'),
        constant('a string').as('string'),
        constant(true).as('boolean'),
        constant(null).as('null'),
        constant(geoPoint).as('geoPoint'),
        constant(timestamp).as('timestamp'),
        constant(date).as('date'),
        constant(bytes).as('bytes'),
        constant(docRef()).as('documentReference'),
        constant(vector).as('vectorValue'),
        P.map({
          number: 1,
          string: 'a string',
          boolean: true,
          null: null,
          geoPoint,
          timestamp,
          date,
          uint8Array: bytes,
          documentReference: docRef(),
          vectorValue: vector,
          map: {number: 2, string: 'b string'},
          array: [1, 'c string'],
        }).as('map'),
        P.array([
          1,
          'a string',
          true,
          null,
          geoPoint,
          timestamp,
          date,
          bytes,
          docRef(),
          vector,
          {number: 2, string: 'b string'},
        ]).as('array'),
      ),
  );
  // The "converts arrays and plain objects to functionValues" Node system
  // test.
  add('values/data-types/array-and-map-functions', () =>
    books()
      .sort(field('rating').descending())
      .limit(1)
      .select('title', 'author', 'genre', 'rating', 'published', 'tags')
      .addFields(
        P.array([
          1,
          2,
          field('genre'),
          P.multiply('rating', 10),
          [field('title')],
          {published: field('published')},
        ]).as('metadataArray'),
        P.map({
          genre: field('genre'),
          rating: P.multiply('rating', 10),
          nestedArray: [field('title')],
          nestedMap: {published: field('published')},
        }).as('metadata'),
      )
      .where(
        P.and(
          P.equal('metadataArray', [
            1,
            2,
            field('genre'),
            P.multiply('rating', 10),
            [field('title')],
            {published: field('published')},
          ]),
          P.equal('metadata', {
            genre: field('genre'),
            rating: P.multiply('rating', 10),
            nestedArray: [field('title')],
            nestedMap: {published: field('published')},
          }),
        ),
      ),
  );

  // ---------------------------------------------------------------------------
  // Functions: arithmetic
  // ---------------------------------------------------------------------------

  binary('add', 'rating', 1, () => field('bonus'));
  fn('functions', 'add', {
    'method-double': () => field('rating').add(0.5),
    'method-variadic': () => field('rating').add(1, field('bonus')),
    'static-variadic': () => P.add('rating', 1, field('bonus')),
  });
  binary('subtract', 'rating', 1, () => field('penalty'));
  binary('multiply', 'rating', 2, () => field('weight'));
  fn('functions', 'multiply', {
    'method-variadic': () => field('rating').multiply(2, field('weight')),
    'static-variadic': () => P.multiply('rating', 2, field('weight')),
  });
  binary('divide', 'rating', 2, () => field('count'));
  binary('mod', 'rating', 2, () => field('divisor'));
  binary('pow', 'rating', 2, () => field('exponent'));
  for (const name of ['abs', 'ceil', 'floor', 'exp', 'ln', 'sqrt', 'log10']) {
    unary(name, 'rating');
  }
  for (const name of ['round', 'trunc']) {
    unary(name, 'rating');
    fn('functions', name, {
      'static-field-name-places-literal': () => P[name]('rating', 2),
      'static-expression-places-expression': () =>
        P[name](field('rating'), field('places')),
      'method-places-literal': () => field('rating')[name](2),
      'method-places-expression': () => field('rating')[name](field('places')),
    });
  }
  fn('functions', 'rand', {static: () => P.rand()});

  // ---------------------------------------------------------------------------
  // Functions: comparison
  // ---------------------------------------------------------------------------

  for (const name of [
    'equal',
    'notEqual',
    'lessThan',
    'lessThanOrEqual',
    'greaterThan',
    'greaterThanOrEqual',
  ]) {
    binary(name, 'rating', 4, () => field('threshold'));
    fn('functions', name, {
      'static-field-name-string': () => P[name]('genre', 'Fantasy'),
    });
  }

  // ---------------------------------------------------------------------------
  // Functions: logical
  // ---------------------------------------------------------------------------

  const isFantasy = () => field('genre').equal('Fantasy');
  const isGood = () => field('rating').greaterThan(4);
  const isOld = () => field('published').lessThan(1950);

  for (const name of ['and', 'or', 'xor', 'nor']) {
    fn('functions', name, {
      'static-two': () => P[name](isFantasy(), isGood()),
      'static-three': () => P[name](isFantasy(), isGood(), isOld()),
    });
  }
  fn('functions', 'not', {
    static: () => P.not(isFantasy()),
    method: () => isFantasy().not(),
  });
  fn('functions', 'conditional', {
    static: () => P.conditional(isGood(), field('title'), constant('n/a')),
    method: () => isGood().conditional(field('title'), constant('n/a')),
  });
  fn('functions', 'switchOn', {
    'static-pair': () => P.switchOn(isGood(), constant('good')),
    'static-pairs-and-default': () =>
      P.switchOn(
        isGood(),
        constant('good'),
        isOld(),
        constant('old'),
        constant('other'),
      ),
  });
  fn('functions', 'logicalMaximum', {
    'static-field-name-literal': () => P.logicalMaximum('rating', 1),
    'static-expression-variadic': () =>
      P.logicalMaximum(field('rating'), field('floor'), 3),
    'method-literal': () => field('rating').logicalMaximum(1),
    'method-variadic': () => field('rating').logicalMaximum(field('floor'), 3),
  });
  fn('functions', 'logicalMinimum', {
    'static-field-name-literal': () => P.logicalMinimum('rating', 5),
    'static-expression-variadic': () =>
      P.logicalMinimum(field('rating'), field('ceiling'), 3),
    'method-literal': () => field('rating').logicalMinimum(5),
    'method-variadic': () =>
      field('rating').logicalMinimum(field('ceiling'), 3),
  });

  // ---------------------------------------------------------------------------
  // Functions: existence, null and error handling
  // ---------------------------------------------------------------------------

  unary('exists', 'title');
  unary('isAbsent', 'title');
  binary('ifAbsent', 'nickname', 'anonymous', () => field('name'));
  binary('ifNull', 'nickname', 'anonymous', () => field('name'));
  const failing = () => field('rating').divide(0);
  fn('functions', 'isError', {
    'static-expression': () => P.isError(failing()),
    method: () => failing().isError(),
  });
  fn('functions', 'ifError', {
    'static-expression-literal': () => P.ifError(failing(), 0),
    'static-expression-expression': () =>
      P.ifError(failing(), field('fallback')),
    'static-boolean-boolean': () => P.ifError(isGood(), constant(false)),
    'method-literal': () => failing().ifError(0),
    'method-expression': () => failing().ifError(field('fallback')),
    'method-boolean-boolean': () => isGood().ifError(constant(false)),
    'method-boolean-literal': () => isGood().ifError(false),
  });
  fn('functions', 'coalesce', {
    'static-field-name-literal': () => P.coalesce('nickname', 'anonymous'),
    'static-expression-variadic': () =>
      P.coalesce(field('nickname'), field('name'), 'anonymous'),
    'method-literal': () => field('nickname').coalesce('anonymous'),
    'method-variadic': () =>
      field('nickname').coalesce(field('name'), 'anonymous'),
  });

  // ---------------------------------------------------------------------------
  // Functions: strings
  // ---------------------------------------------------------------------------

  for (const name of [
    'charLength',
    'byteLength',
    'toLower',
    'toUpper',
    'stringReverse',
    'reverse',
    'length',
  ]) {
    unary(name, 'title');
  }
  binary('like', 'title', 'The%', () => field('pattern'));
  binary('regexContains', 'title', 'Lord', () => field('pattern'));
  binary('regexMatch', 'title', '^The.*', () => field('pattern'));
  binary('regexFind', 'title', '[A-Z]\\w+', () => field('pattern'));
  binary('regexFindAll', 'title', '[A-Z]\\w+', () => field('pattern'));
  binary('stringContains', 'title', 'Ring', () => field('needle'));
  binary('startsWith', 'title', 'The', () => field('prefix'));
  binary('endsWith', 'title', 'Rings', () => field('suffix'));
  binary('stringIndexOf', 'title', 'Ring', () => field('needle'));
  binary('stringRepeat', 'title', 2, () => field('times'));
  binary('split', 'csv', ',', () => field('delimiter'));
  binary('join', 'tags', ', ', () => field('delimiter'));
  for (const name of ['trim', 'ltrim', 'rtrim']) {
    unary(name, 'title');
    fn('functions', name, {
      'static-field-name-literal': () => P[name]('title', '-'),
      'static-expression-expression': () =>
        P[name](field('title'), field('chars')),
      'method-literal': () => field('title')[name]('-'),
      'method-expression': () => field('title')[name](field('chars')),
    });
  }
  fn('functions', 'stringConcat', {
    'static-field-name-literal': () => P.stringConcat('title', ' by '),
    'static-field-name-variadic': () =>
      P.stringConcat('title', ' by ', field('author')),
    'static-expression-expression': () =>
      P.stringConcat(field('title'), field('author')),
    'method-literal': () => field('title').stringConcat(' by '),
    'method-variadic': () => field('title').stringConcat(' by ', field('author')),
  });
  fn('functions', 'concat', {
    'static-field-name-literal': () => P.concat('title', '!'),
    'static-expression-variadic': () =>
      P.concat(field('title'), ' by ', field('author')),
    'method-literal': () => field('title').concat('!'),
    'method-list': () => field('tags').concat(['extra']),
    'method-variadic': () => field('title').concat(' by ', field('author')),
  });
  for (const name of ['stringReplaceAll', 'stringReplaceOne']) {
    fn('functions', name, {
      'static-field-name-literals': () => P[name]('title', 'a', 'b'),
      'static-expression-expressions': () =>
        P[name](field('title'), field('find'), field('replacement')),
      'method-literals': () => field('title')[name]('a', 'b'),
      'method-expressions': () =>
        field('title')[name](field('find'), field('replacement')),
    });
  }
  fn('functions', 'substring', {
    'static-field-name-position': () => P.substring('title', 2),
    'static-field-name-position-length': () => P.substring('title', 2, 3),
    'static-expression-expressions': () =>
      P.substring(field('title'), field('start'), field('count')),
    'method-position': () => field('title').substring(2),
    'method-position-length': () => field('title').substring(2, 3),
    'method-expressions': () =>
      field('title').substring(field('start'), field('count')),
  });

  // ---------------------------------------------------------------------------
  // Functions: arrays
  // ---------------------------------------------------------------------------

  fn('functions', 'array', {
    'static-literals': () => P.array([1, 'a', true, null]),
    'static-with-expressions': () => P.array([field('title'), 1]),
    'static-nested': () => P.array([[1, field('a')], {k: field('b')}]),
    'static-empty': () => P.array([]),
  });
  fn('functions', 'arrayConcat', {
    'static-field-name-list': () => P.arrayConcat('tags', ['x', 'y']),
    'static-field-name-expression': () =>
      P.arrayConcat('tags', field('moreTags')),
    'static-expression-variadic': () =>
      P.arrayConcat(field('tags'), field('moreTags'), ['z']),
    'method-list': () => field('tags').arrayConcat(['x', 'y']),
    'method-expression': () => field('tags').arrayConcat(field('moreTags')),
    'method-variadic': () =>
      field('tags').arrayConcat(field('moreTags'), ['z']),
  });
  binary('arrayContains', 'tags', 'magic', () => field('wanted'));
  for (const name of ['arrayContainsAll', 'arrayContainsAny']) {
    fn('functions', name, {
      'static-field-name-list': () => P[name]('tags', ['magic', 'epic']),
      'static-field-name-list-with-expression': () =>
        P[name]('tags', ['magic', field('wanted')]),
      'static-field-name-list-nested': () => P[name]('tags', ['magic', ['epic']]),
      'static-field-name-array-expression': () =>
        P[name]('tags', field('wanted')),
      'static-expression-list': () => P[name](field('tags'), ['magic', 'epic']),
      'method-list': () => field('tags')[name](['magic', 'epic']),
      'method-list-with-expression': () =>
        field('tags')[name](['magic', field('wanted')]),
      'method-array-expression': () => field('tags')[name](field('wanted')),
    });
  }
  for (const name of ['equalAny', 'notEqualAny']) {
    fn('functions', name, {
      'static-field-name-list': () => P[name]('genre', ['Fantasy', 'Sci-Fi']),
      'static-field-name-list-with-expression': () =>
        P[name]('genre', ['Fantasy', field('favorite')]),
      'static-field-name-list-nested': () =>
        P[name]('genre', ['Fantasy', ['Sci-Fi']]),
      'static-field-name-array-expression': () =>
        P[name]('genre', field('genres')),
      'static-expression-list': () =>
        P[name](field('genre'), ['Fantasy', 'Sci-Fi']),
      'method-list': () => field('genre')[name](['Fantasy', 'Sci-Fi']),
      'method-list-with-expression': () =>
        field('genre')[name](['Fantasy', field('favorite')]),
      'method-array-expression': () => field('genre')[name](field('genres')),
    });
  }
  for (const name of [
    'arrayLength',
    'arrayFirst',
    'arrayLast',
    'arrayReverse',
    'arraySum',
    'arrayMaximum',
    'arrayMinimum',
  ]) {
    unary(name, 'tags');
  }
  for (const name of [
    'arrayFirstN',
    'arrayLastN',
    'arrayMaximumN',
    'arrayMinimumN',
  ]) {
    binary(name, 'scores', 2, () => field('n'));
  }
  binary('arrayGet', 'tags', 1, () => field('index'));
  binary('arrayIndexOf', 'tags', 'magic', () => field('wanted'));
  binary('arrayLastIndexOf', 'tags', 'magic', () => field('wanted'));
  binary('arrayIndexOfAll', 'tags', 'magic', () => field('wanted'));
  fn('functions', 'arraySlice', {
    'static-field-name-offset': () => P.arraySlice('tags', 1),
    'static-field-name-offset-length': () => P.arraySlice('tags', 1, 2),
    'static-expression-expressions': () =>
      P.arraySlice(field('tags'), field('start'), field('count')),
    'method-offset': () => field('tags').arraySlice(1),
    'method-offset-length': () => field('tags').arraySlice(1, 2),
    'method-expressions': () =>
      field('tags').arraySlice(field('start'), field('count')),
  });
  const isMagic = () => variable('tag').equal('magic');
  fn('functions', 'arrayFilter', {
    'static-field-name': () => P.arrayFilter('tags', 'tag', isMagic()),
    'static-expression': () => P.arrayFilter(field('tags'), 'tag', isMagic()),
    method: () => field('tags').arrayFilter('tag', isMagic()),
  });
  const upper = () => variable('tag').toUpper();
  fn('functions', 'arrayTransform', {
    'static-field-name': () => P.arrayTransform('tags', 'tag', upper()),
    'static-expression': () => P.arrayTransform(field('tags'), 'tag', upper()),
    method: () => field('tags').arrayTransform('tag', upper()),
  });
  const indexed = () => variable('tag').stringConcat(variable('i'));
  fn('functions', 'arrayTransformWithIndex', {
    'static-field-name': () =>
      P.arrayTransformWithIndex('tags', 'tag', 'i', indexed()),
    'static-expression': () =>
      P.arrayTransformWithIndex(field('tags'), 'tag', 'i', indexed()),
    method: () => field('tags').arrayTransformWithIndex('tag', 'i', indexed()),
  });

  // ---------------------------------------------------------------------------
  // Functions: maps
  // ---------------------------------------------------------------------------

  fn('functions', 'map', {
    'static-literals': () => P.map({a: 1, b: 'x'}),
    'static-with-expressions': () => P.map({a: field('title'), b: 1}),
    'static-nested': () =>
      P.map({inner: {k: field('y')}, list: [field('z'), 1]}),
    'static-empty': () => P.map({}),
  });
  fn('functions', 'mapGet', {
    'static-field-name': () => P.mapGet('metadata', 'lang'),
    'static-expression': () => P.mapGet(field('metadata'), 'lang'),
    method: () => field('metadata').mapGet('lang'),
  });
  fn('functions', 'mapSet', {
    'static-field-name-literal': () => P.mapSet('metadata', 'lang', 'en'),
    'static-expression-variadic': () =>
      P.mapSet(field('metadata'), 'lang', 'en', 'pages', field('pageCount')),
    'method-literal': () => field('metadata').mapSet('lang', 'en'),
    'method-expression-key': () =>
      field('metadata').mapSet(field('key'), field('value')),
    'method-variadic': () =>
      field('metadata').mapSet('lang', 'en', 'pages', field('pageCount')),
  });
  binary('mapRemove', 'metadata', 'lang', () => field('key'));
  fn('functions', 'mapMerge', {
    'static-field-name-map': () => P.mapMerge('metadata', {extra: 1}),
    'static-expression-expression': () =>
      P.mapMerge(field('metadata'), field('overrides')),
    'static-field-name-variadic': () =>
      P.mapMerge('metadata', {extra: field('title')}, field('overrides')),
    'method-map': () => field('metadata').mapMerge({extra: 1}),
    'method-variadic': () =>
      field('metadata').mapMerge({extra: field('title')}, field('overrides')),
  });
  for (const name of ['mapKeys', 'mapValues', 'mapEntries']) {
    unary(name, 'metadata');
  }
  binary('getField', 'metadata', 'lang', () => field('key'));

  // ---------------------------------------------------------------------------
  // Functions: timestamps
  // ---------------------------------------------------------------------------

  for (const name of [
    'unixMicrosToTimestamp',
    'unixMillisToTimestamp',
    'unixSecondsToTimestamp',
    'timestampToUnixMicros',
    'timestampToUnixMillis',
    'timestampToUnixSeconds',
  ]) {
    unary(name, 'published');
  }
  for (const name of ['timestampAdd', 'timestampSubtract']) {
    fn('functions', name, {
      'static-field-name-literals': () => P[name]('published', 'day', 1),
      'static-expression-literals': () =>
        P[name](field('published'), 'hour', 2),
      'static-expression-expressions': () =>
        P[name](field('published'), field('unit'), field('amount')),
      'method-literals': () => field('published')[name]('minute', 30),
      'method-expressions': () =>
        field('published')[name](field('unit'), field('amount')),
    });
  }
  fn('functions', 'timestampTruncate', {
    'static-field-name-literal': () => P.timestampTruncate('published', 'day'),
    'static-field-name-literal-timezone': () =>
      P.timestampTruncate('published', 'week(monday)', 'America/New_York'),
    'static-expression-expression': () =>
      P.timestampTruncate(field('published'), field('granularity')),
    'static-expression-timezone-expression': () =>
      P.timestampTruncate(field('published'), 'month', field('tz')),
    'method-literal': () => field('published').timestampTruncate('year'),
    'method-literal-timezone': () =>
      field('published').timestampTruncate('day', 'UTC'),
    'method-expression-timezone-expression': () =>
      field('published').timestampTruncate(field('granularity'), field('tz')),
  });
  fn('functions', 'timestampExtract', {
    'static-field-name-literal': () => P.timestampExtract('published', 'year'),
    'static-field-name-literal-timezone': () =>
      P.timestampExtract('published', 'dayofweek', 'America/New_York'),
    'static-expression-expression': () =>
      P.timestampExtract(field('published'), field('part')),
    'static-expression-timezone-expression': () =>
      P.timestampExtract(field('published'), 'month', field('tz')),
    'method-literal': () => field('published').timestampExtract('dayofyear'),
    'method-literal-timezone': () =>
      field('published').timestampExtract('hour', 'UTC'),
    'method-expression-timezone-expression': () =>
      field('published').timestampExtract(field('part'), field('tz')),
  });
  fn('functions', 'timestampDiff', {
    'static-field-names': () => P.timestampDiff('end', 'start', 'day'),
    'static-field-name-expression': () =>
      P.timestampDiff('end', field('start'), 'second'),
    'static-expression-field-name': () =>
      P.timestampDiff(field('end'), 'start', 'hour'),
    'static-expressions-unit-expression': () =>
      P.timestampDiff(field('end'), field('start'), field('unit')),
    'method-field-name': () => field('end').timestampDiff('start', 'day'),
    'method-expressions': () =>
      field('end').timestampDiff(field('start'), field('unit')),
  });
  fn('functions', 'currentTimestamp', {static: () => P.currentTimestamp()});

  // ---------------------------------------------------------------------------
  // Functions: types
  // ---------------------------------------------------------------------------

  unary('type', 'value');
  fn('functions', 'isType', {
    'static-field-name': () => P.isType('value', 'string'),
    'static-expression': () => P.isType(field('value'), 'string'),
  });
  for (const type of [
    'null',
    'array',
    'boolean',
    'bytes',
    'timestamp',
    'geo_point',
    'number',
    'int32',
    'int64',
    'float64',
    'decimal128',
    'map',
    'reference',
    'string',
    'vector',
    'max_key',
    'min_key',
    'object_id',
    'regex',
    'request_timestamp',
  ]) {
    fn('functions', 'isType', {
      [`method-${type.replace(/_/g, '-')}`]: () => field('value').isType(type),
    });
  }

  // ---------------------------------------------------------------------------
  // Functions: vectors and geo
  // ---------------------------------------------------------------------------

  for (const name of ['cosineDistance', 'dotProduct', 'euclideanDistance']) {
    fn('functions', name, {
      'static-field-name-number-array': () =>
        P[name]('embedding', [0.1, 0.2, 0.3]),
      'static-field-name-integer-array': () => P[name]('embedding', [1, 2, 3]),
      'static-field-name-vector-value': () => P[name]('embedding', vector),
      'static-field-name-expression': () =>
        P[name]('embedding', field('other')),
      'static-expression-number-array': () =>
        P[name](field('embedding'), [0.1, 0.2, 0.3]),
      'static-expression-expression': () =>
        P[name](field('embedding'), field('other')),
      'method-number-array': () => field('embedding')[name]([0.1, 0.2, 0.3]),
      'method-vector-value': () => field('embedding')[name](vector),
      'method-expression': () => field('embedding')[name](field('other')),
    });
  }
  unary('vectorLength', 'embedding');
  fn('functions', 'geoDistance', {
    'static-field-name-geo-point': () => P.geoDistance('location', geoPoint),
    'static-field-geo-point': () => P.geoDistance(field('location'), geoPoint),
    'static-field-name-expression': () =>
      P.geoDistance('location', field('other')),
    'method-geo-point': () => field('location').geoDistance(geoPoint),
    'method-expression': () => field('location').geoDistance(field('other')),
  });

  // ---------------------------------------------------------------------------
  // Functions: references, documents and search
  // ---------------------------------------------------------------------------

  unary('collectionId', '__name__');
  for (const name of ['documentId', 'parent']) {
    fn('functions', name, {
      'static-path': () => P[name]('books/book1'),
      'static-reference': () => P[name](docRef()),
      'static-expression': () => P[name](field('__name__')),
      method: () => field('__name__')[name](),
    });
  }
  fn('functions', 'currentDocument', {static: () => P.currentDocument()});
  fn('functions', 'documentMatches', {
    'static-literal': () => P.documentMatches('breakfast'),
    'static-expression': () => P.documentMatches(field('query')),
  });
  fn('functions', 'score', {static: () => P.score()});

  // ---------------------------------------------------------------------------
  // Aggregates
  // ---------------------------------------------------------------------------

  fn('aggregates', 'countAll', {static: () => P.countAll()});
  for (const name of [
    'count',
    'sum',
    'average',
    'minimum',
    'maximum',
    'first',
    'last',
    'arrayAgg',
    'arrayAggDistinct',
    'countDistinct',
  ]) {
    unary(name, 'rating', {area: 'aggregates'});
  }
  fn('aggregates', 'countIf', {
    static: () => P.countIf(isGood()),
    method: () => isGood().countIf(),
  });

  return cases;
};
