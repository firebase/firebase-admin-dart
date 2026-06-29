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

import 'package:meta/meta.dart';

export 'src/credential.dart' show Credential;
export 'src/firestore.dart'
    show
        AggregateField,
        AggregateQuery,
        AggregateQuerySnapshot,
        AliasedExpression,
        BooleanExpression,
        BulkWriter,
        BulkWriterError,
        BulkWriterOptions,
        BulkWriterThrottling,
        BundleBuilder,
        CollectionGroup,
        CollectionReference,
        DisabledThrottling,
        DistanceMeasure,
        DocumentChange,
        DocumentChangeType,
        DocumentData,
        DocumentReference,
        DocumentSnapshot,
        EnabledThrottling,
        ExecutionStats,
        ExplainMetrics,
        ExplainOptions,
        ExplainResults,
        Expression,
        FieldMask,
        FieldPath,
        FieldValue,
        Filter,
        Firestore,
        GeoPoint,
        Ordering,
        Pipeline,
        PipelineAggregateFunction,
        PipelineAliasedExpression,
        PipelineBooleanExpression,
        PipelineExpression,
        PipelineField,
        PipelineFunctions,
        PipelineOrdering,
        PipelineResult,
        PipelineSnapshot,
        PipelineSource,
        PipelineValueType,
        PlanSummary,
        Precondition,
        Query,
        QueryDocumentSnapshot,
        QueryPartition,
        QuerySnapshot,
        ReadOnlyTransactionOptions,
        ReadOptions,
        ReadWriteTransactionOptions,
        Selectable,
        SetOptions,
        Settings,
        Timestamp,
        Transaction,
        TransactionHandler,
        TransactionOptions,
        VectorQuery,
        VectorQueryOptions,
        VectorQuerySnapshot,
        VectorValue,
        WhereFilter,
        WriteBatch,
        WriteResult,
        and,
        ascending,
        average,
        constant,
        count,
        currentDocument,
        descending,
        equal,
        field,
        greaterThan,
        greaterThanOrEqual,
        lessThan,
        lessThanOrEqual,
        not,
        notEqual,
        or,
        pipelineFunction,
        sum;
export 'src/firestore_exception.dart'
    show FirestoreClientErrorCode, FirestoreException;
export 'src/status_code.dart' show StatusCode;

/// Symbol for accessing environment variables in tests via Zones.
/// This allows tests to override Platform.environment values.
@internal
const envSymbol = #_envSymbol;
