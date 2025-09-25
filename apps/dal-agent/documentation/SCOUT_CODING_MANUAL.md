# Scout Analytics Platform - Complete Coding Manual

**Version**: 3.0
**Database**: SQL-TBWA-ProjectScout-Reporting-Prod
**Updated**: September 2025

## Table of Contents

1. [Development Standards](#development-standards)
2. [Database Development](#database-development)
3. [ETL Best Practices](#etl-best-practices)
4. [TypeScript/JavaScript Standards](#typescriptjavascript-standards)
5. [Python Development](#python-development)
6. [Performance Optimization](#performance-optimization)
7. [Testing & Quality Assurance](#testing--quality-assurance)
8. [Deployment & Operations](#deployment--operations)

## Development Standards

### Code Organization

```
scout-v7/
├── apps/
│   ├── dal-agent/                    # Data Access Layer Agent
│   │   ├── sql/                      # All SQL scripts
│   │   ├── lib/                      # Shared TypeScript libraries
│   │   ├── scripts/                  # Python ETL scripts
│   │   ├── exports/                  # Generated queries and data
│   │   └── documentation/            # Complete documentation
│   ├── standalone-dashboard/         # Suqi Public Dashboard
│   │   ├── src/
│   │   │   ├── components/           # React components
│   │   │   ├── lib/                  # Utilities and helpers
│   │   │   └── styles/               # CSS and styling
│   │   └── public/                   # Static assets
│   └── scout-widget/                 # Analytics Widget
└── packages/                         # Shared packages
    ├── ui/                          # Shared UI components
    └── database/                    # Database utilities
```

### Naming Conventions

#### Database Objects

```sql
-- Tables: PascalCase for main entities, descriptive names
PayloadTransactions
TransactionItems
BrandSubstitutions
ProductAssociations

-- Views: Prefix with 'v_', lowercase with underscores
v_transactions_flat_production
v_nielsen_complete_analytics
v_data_quality_monitor

-- Stored Procedures: Prefix with 'sp_', descriptive action
sp_IngestRawTransactionData
sp_ExtractTransactionItems
sp_ValidateCanonicalTaxonomy

-- Functions: Prefix with 'fn_', descriptive purpose
fn_DetectBrandName
fn_ClassifyCategory
fn_FuzzyMatch

-- Indexes: Descriptive with table reference
IX_TransactionItems_Brand_Category_Date
IX_PayloadTransactions_Processing
IX_Stores_Geography
```

#### Application Code

```typescript
// Files: kebab-case
transaction-processor.ts
brand-detection.service.ts
analytics-dashboard.component.tsx

// Variables: camelCase
const transactionData = {};
const brandConfidenceScore = 0.95;

// Functions: camelCase with descriptive verbs
async function extractTransactionItems() {}
function calculateQualityScore() {}
function validateBrandMapping() {}

// Constants: SCREAMING_SNAKE_CASE
const MAX_RETRY_ATTEMPTS = 3;
const DEFAULT_QUALITY_THRESHOLD = 0.8;
const NIELSEN_CATEGORY_MAPPING = {};

// Types/Interfaces: PascalCase
interface TransactionItem {}
type BrandMapping = {};
enum ProcessingStatus {}
```

### Git Workflow

```bash
# Branch naming convention
feature/nielsen-taxonomy-integration
bugfix/substitution-detection-accuracy
hotfix/data-quality-validation
release/v3.0.0

# Commit message format
feat: Add Nielsen taxonomy alignment for brand categorization
fix: Resolve substitution detection false positives
docs: Update ETL pipeline documentation
perf: Optimize transaction item extraction query

# PR title format
[FEAT] Nielsen Taxonomy Integration with 95% Accuracy
[FIX] Data Quality Validation for Transaction Processing
[PERF] Query Optimization Reduces Processing Time by 40%
```

## Database Development

### SQL Coding Standards

#### Query Structure

```sql
-- Standard query format
WITH descriptive_cte AS (
    -- Clear comment explaining CTE purpose
    SELECT
        t.canonical_tx_id,
        t.transaction_id,
        t.total_amount,
        -- Comments for complex calculations
        CASE
            WHEN t.total_amount > 1000 THEN 'High Value'
            WHEN t.total_amount > 500 THEN 'Medium Value'
            ELSE 'Low Value'
        END AS transaction_tier
    FROM dbo.Transactions t
    WHERE t.processing_status = 'active'
    AND t.txn_ts >= DATEADD(day, -30, GETDATE())
),
aggregated_data AS (
    -- Second CTE with clear business purpose
    SELECT
        dc.transaction_tier,
        COUNT(*) AS transaction_count,
        AVG(dc.total_amount) AS avg_amount,
        SUM(dc.total_amount) AS total_revenue
    FROM descriptive_cte dc
    GROUP BY dc.transaction_tier
)
SELECT
    ad.transaction_tier,
    ad.transaction_count,
    FORMAT(ad.avg_amount, 'C', 'en-PH') AS formatted_avg_amount,
    FORMAT(ad.total_revenue, 'C', 'en-PH') AS formatted_total_revenue,
    -- Business context in results
    CAST(ad.transaction_count * 100.0 / SUM(ad.transaction_count) OVER() AS DECIMAL(5,2)) AS percentage_of_total
FROM aggregated_data ad
ORDER BY ad.total_revenue DESC;
```

#### Stored Procedure Template

```sql
-- ================================================================
-- Procedure: sp_ProcessTransactionBatch
-- Purpose: Process a batch of transactions through ETL pipeline
-- Author: Data Team
-- Created: 2025-09-25
-- Modified: 2025-09-25
--
-- Parameters:
--   @BatchId - Unique identifier for processing batch
--   @ProcessingMode - 'full' or 'incremental' processing
--   @ValidationLevel - 'strict' or 'standard' validation
--
-- Returns: Processing summary and quality metrics
--
-- Example Usage:
--   EXEC sp_ProcessTransactionBatch
--       @BatchId = 'BATCH_20250925_001',
--       @ProcessingMode = 'incremental',
--       @ValidationLevel = 'strict'
-- ================================================================

CREATE OR ALTER PROCEDURE dbo.sp_ProcessTransactionBatch
    @BatchId VARCHAR(100),
    @ProcessingMode VARCHAR(20) = 'incremental',
    @ValidationLevel VARCHAR(20) = 'standard'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Declare variables with clear names
    DECLARE @StartTime DATETIME2 = GETDATE();
    DECLARE @ProcessedRecords INT = 0;
    DECLARE @SuccessfulRecords INT = 0;
    DECLARE @FailedRecords INT = 0;
    DECLARE @QualityScore DECIMAL(5,2) = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX) = NULL;

    -- Input validation
    IF @BatchId IS NULL OR LTRIM(RTRIM(@BatchId)) = ''
    BEGIN
        RAISERROR('BatchId cannot be null or empty', 16, 1);
        RETURN;
    END;

    IF @ProcessingMode NOT IN ('full', 'incremental')
    BEGIN
        RAISERROR('ProcessingMode must be either ''full'' or ''incremental''', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Log process start
        INSERT INTO audit.ETLProcessingLog (
            process_name, batch_id, start_time, status, records_processed
        )
        VALUES (
            'sp_ProcessTransactionBatch', @BatchId, @StartTime, 'running', 0
        );

        -- Main processing logic with clear sections

        -- SECTION 1: Data Validation
        EXEC dbo.sp_ValidateBatchData
            @BatchId = @BatchId,
            @ValidationLevel = @ValidationLevel;

        -- SECTION 2: Data Processing
        EXEC dbo.sp_ExtractTransactionItems
            @BatchId = @BatchId;

        -- SECTION 3: Quality Assessment
        SELECT
            @ProcessedRecords = COUNT(*),
            @SuccessfulRecords = COUNT(CASE WHEN processing_status = 'completed' THEN 1 END),
            @FailedRecords = COUNT(CASE WHEN processing_status = 'failed' THEN 1 END),
            @QualityScore = AVG(quality_score) * 100
        FROM dbo.PayloadTransactions
        WHERE etl_batch_id = @BatchId;

        -- Update process log with results
        UPDATE audit.ETLProcessingLog
        SET
            end_time = GETDATE(),
            status = 'completed',
            records_processed = @ProcessedRecords,
            records_successful = @SuccessfulRecords,
            records_failed = @FailedRecords,
            processing_duration_seconds = DATEDIFF(second, @StartTime, GETDATE())
        WHERE process_name = 'sp_ProcessTransactionBatch'
        AND batch_id = @BatchId
        AND status = 'running';

        COMMIT TRANSACTION;

        -- Return results for caller
        SELECT
            @BatchId AS batch_id,
            @ProcessedRecords AS processed_records,
            @SuccessfulRecords AS successful_records,
            @FailedRecords AS failed_records,
            @QualityScore AS quality_score_percentage,
            DATEDIFF(second, @StartTime, GETDATE()) AS processing_duration_seconds;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @ErrorMessage = ERROR_MESSAGE();

        -- Log error details
        UPDATE audit.ETLProcessingLog
        SET
            end_time = GETDATE(),
            status = 'failed',
            error_message = @ErrorMessage,
            error_details = CONCAT(
                'Error Number: ', ERROR_NUMBER(),
                ', Severity: ', ERROR_SEVERITY(),
                ', State: ', ERROR_STATE(),
                ', Procedure: ', ISNULL(ERROR_PROCEDURE(), 'N/A'),
                ', Line: ', ERROR_LINE()
            )
        WHERE process_name = 'sp_ProcessTransactionBatch'
        AND batch_id = @BatchId
        AND status = 'running';

        -- Re-raise error for caller
        RAISERROR('Batch processing failed: %s', 16, 1, @ErrorMessage);
    END CATCH;
END;
GO
```

#### View Development Standards

```sql
-- ================================================================
-- View: v_transaction_analytics_dashboard
-- Purpose: Pre-aggregated data for analytics dashboard
-- Dependencies: v_transactions_flat_production, dbo.Stores
-- Update Frequency: Near real-time (updated with each transaction)
-- Performance: Optimized with proper indexing on base tables
-- ================================================================

CREATE OR ALTER VIEW dbo.v_transaction_analytics_dashboard
AS
WITH transaction_metrics AS (
    SELECT
        -- Time dimensions for grouping
        CAST(vt.txn_ts AS DATE) AS transaction_date,
        DATEPART(YEAR, vt.txn_ts) AS year,
        DATEPART(MONTH, vt.txn_ts) AS month,
        DATEPART(WEEK, vt.txn_ts) AS week,
        vt.daypart,
        vt.weekday_weekend,

        -- Business dimensions
        vt.store_id,
        vt.store_name,
        vt.brand,
        vt.category,
        vt.nielsen_category,
        vt.nielsen_department,

        -- Metrics for aggregation
        vt.total_amount,
        vt.total_items,
        vt.data_quality_score,

        -- Window functions for analysis
        ROW_NUMBER() OVER (
            PARTITION BY CAST(vt.txn_ts AS DATE), vt.nielsen_category
            ORDER BY vt.total_amount DESC
        ) AS daily_category_rank
    FROM dbo.v_transactions_flat_production vt
    WHERE vt.data_quality_score >= 0.8  -- Only include high-quality data
    AND vt.txn_ts >= DATEADD(month, -12, GETDATE())  -- Performance optimization
),
aggregated_metrics AS (
    SELECT
        tm.transaction_date,
        tm.year,
        tm.month,
        tm.week,
        tm.daypart,
        tm.weekday_weekend,
        tm.store_id,
        tm.store_name,
        tm.brand,
        tm.category,
        tm.nielsen_category,
        tm.nielsen_department,

        -- Aggregated business metrics
        COUNT(*) AS transaction_count,
        SUM(tm.total_amount) AS total_revenue,
        AVG(tm.total_amount) AS avg_transaction_value,
        SUM(tm.total_items) AS total_items_sold,
        AVG(tm.total_items) AS avg_basket_size,

        -- Quality metrics
        AVG(tm.data_quality_score) AS avg_quality_score,

        -- Performance indicators
        COUNT(CASE WHEN tm.daily_category_rank <= 3 THEN 1 END) AS top_3_performance_days
    FROM transaction_metrics tm
    GROUP BY
        tm.transaction_date, tm.year, tm.month, tm.week,
        tm.daypart, tm.weekday_weekend, tm.store_id, tm.store_name,
        tm.brand, tm.category, tm.nielsen_category, tm.nielsen_department
)
SELECT
    am.*,

    -- Calculated business insights
    CASE
        WHEN am.avg_transaction_value >= 500 THEN 'High Value'
        WHEN am.avg_transaction_value >= 200 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS value_tier,

    CASE
        WHEN am.transaction_count >= 100 THEN 'High Volume'
        WHEN am.transaction_count >= 50 THEN 'Medium Volume'
        ELSE 'Low Volume'
    END AS volume_tier,

    -- Performance calculations
    am.total_revenue / NULLIF(SUM(am.total_revenue) OVER (
        PARTITION BY am.transaction_date, am.nielsen_category
    ), 0) * 100 AS daily_category_share_percentage,

    RANK() OVER (
        PARTITION BY am.year, am.month, am.nielsen_category
        ORDER BY am.total_revenue DESC
    ) AS monthly_brand_rank
FROM aggregated_metrics am;
GO

-- Create supporting index for view performance
CREATE NONCLUSTERED INDEX IX_v_transactions_flat_production_analytics
ON dbo.v_transactions_flat_production (txn_ts, nielsen_category, data_quality_score)
INCLUDE (total_amount, total_items, brand, store_name);
```

### Data Quality Standards

#### Validation Functions

```sql
-- Data quality validation function
CREATE FUNCTION dbo.fn_ValidateTransactionData(
    @CanonicalTxId VARCHAR(64),
    @TotalAmount DECIMAL(12,2),
    @TotalItems INT,
    @BrandDetected VARCHAR(100),
    @CategoryDetected VARCHAR(100)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        @CanonicalTxId AS canonical_tx_id,

        -- Individual validation checks
        CASE WHEN @TotalAmount > 0 THEN 1 ELSE 0 END AS amount_valid,
        CASE WHEN @TotalItems > 0 THEN 1 ELSE 0 END AS items_valid,
        CASE WHEN @BrandDetected IS NOT NULL AND LEN(@BrandDetected) > 0 THEN 1 ELSE 0 END AS brand_valid,
        CASE WHEN @CategoryDetected IS NOT NULL AND LEN(@CategoryDetected) > 0 THEN 1 ELSE 0 END AS category_valid,

        -- Overall quality score calculation
        (
            CASE WHEN @TotalAmount > 0 THEN 25 ELSE 0 END +
            CASE WHEN @TotalItems > 0 THEN 25 ELSE 0 END +
            CASE WHEN @BrandDetected IS NOT NULL AND LEN(@BrandDetected) > 0 THEN 25 ELSE 0 END +
            CASE WHEN @CategoryDetected IS NOT NULL AND LEN(@CategoryDetected) > 0 THEN 25 ELSE 0 END
        ) / 100.0 AS quality_score,

        -- Quality tier assessment
        CASE
            WHEN (
                CASE WHEN @TotalAmount > 0 THEN 25 ELSE 0 END +
                CASE WHEN @TotalItems > 0 THEN 25 ELSE 0 END +
                CASE WHEN @BrandDetected IS NOT NULL AND LEN(@BrandDetected) > 0 THEN 25 ELSE 0 END +
                CASE WHEN @CategoryDetected IS NOT NULL AND LEN(@CategoryDetected) > 0 THEN 25 ELSE 0 END
            ) >= 90 THEN 'Excellent'
            WHEN (
                CASE WHEN @TotalAmount > 0 THEN 25 ELSE 0 END +
                CASE WHEN @TotalItems > 0 THEN 25 ELSE 0 END +
                CASE WHEN @BrandDetected IS NOT NULL AND LEN(@BrandDetected) > 0 THEN 25 ELSE 0 END +
                CASE WHEN @CategoryDetected IS NOT NULL AND LEN(@CategoryDetected) > 0 THEN 25 ELSE 0 END
            ) >= 75 THEN 'Good'
            WHEN (
                CASE WHEN @TotalAmount > 0 THEN 25 ELSE 0 END +
                CASE WHEN @TotalItems > 0 THEN 25 ELSE 0 END +
                CASE WHEN @BrandDetected IS NOT NULL AND LEN(@BrandDetected) > 0 THEN 25 ELSE 0 END +
                CASE WHEN @CategoryDetected IS NOT NULL AND LEN(@CategoryDetected) > 0 THEN 25 ELSE 0 END
            ) >= 50 THEN 'Acceptable'
            ELSE 'Poor'
        END AS quality_tier
);
```

## ETL Best Practices

### Error Handling Pattern

```python
import logging
import pyodbc
from typing import Dict, List, Optional, Tuple
from datetime import datetime
import json

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ScoutETLProcessor:
    """
    Scout Analytics Platform ETL Processor

    Handles data extraction, transformation, and loading with comprehensive
    error handling, logging, and quality validation.
    """

    def __init__(self, connection_string: str):
        self.connection_string = connection_string
        self.batch_id = self._generate_batch_id()

    def _generate_batch_id(self) -> str:
        """Generate unique batch identifier"""
        return f"BATCH_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

    def process_transaction_batch(
        self,
        source_data: List[Dict],
        processing_mode: str = 'incremental',
        validation_level: str = 'standard'
    ) -> Dict:
        """
        Process a batch of transaction data through the ETL pipeline

        Args:
            source_data: List of transaction dictionaries
            processing_mode: 'full' or 'incremental'
            validation_level: 'strict' or 'standard'

        Returns:
            Processing summary with metrics and status
        """
        start_time = datetime.now()
        processed_records = 0
        successful_records = 0
        failed_records = 0

        try:
            logger.info(f"Starting ETL batch processing: {self.batch_id}")

            # Stage 1: Data Validation
            validated_data = self._validate_source_data(
                source_data, validation_level
            )
            logger.info(f"Validated {len(validated_data)} records")

            # Stage 2: Data Transformation
            transformed_data = self._transform_transaction_data(validated_data)
            logger.info(f"Transformed {len(transformed_data)} records")

            # Stage 3: Data Loading
            loading_results = self._load_transaction_data(
                transformed_data, processing_mode
            )

            processed_records = loading_results['processed']
            successful_records = loading_results['successful']
            failed_records = loading_results['failed']

            # Stage 4: Quality Assessment
            quality_metrics = self._assess_data_quality(self.batch_id)

            # Stage 5: Process Completion
            self._finalize_batch_processing(
                self.batch_id, 'completed',
                processed_records, successful_records, failed_records
            )

            duration_seconds = (datetime.now() - start_time).total_seconds()

            return {
                'status': 'completed',
                'batch_id': self.batch_id,
                'processed_records': processed_records,
                'successful_records': successful_records,
                'failed_records': failed_records,
                'duration_seconds': duration_seconds,
                'quality_metrics': quality_metrics
            }

        except Exception as e:
            logger.error(f"ETL batch processing failed: {str(e)}", exc_info=True)

            # Log failure details
            self._finalize_batch_processing(
                self.batch_id, 'failed',
                processed_records, successful_records, failed_records,
                error_message=str(e)
            )

            # Re-raise exception for caller handling
            raise ETLProcessingError(
                f"Batch processing failed for {self.batch_id}: {str(e)}"
            ) from e

    def _validate_source_data(
        self,
        source_data: List[Dict],
        validation_level: str
    ) -> List[Dict]:
        """Validate source data based on specified validation level"""

        validated_data = []
        validation_errors = []

        for idx, record in enumerate(source_data):
            try:
                # Required field validation
                required_fields = [
                    'transaction_id', 'canonical_tx_id',
                    'total_amount', 'total_items'
                ]

                missing_fields = [
                    field for field in required_fields
                    if field not in record or record[field] is None
                ]

                if missing_fields:
                    raise ValueError(f"Missing required fields: {missing_fields}")

                # Data type validation
                record['total_amount'] = float(record['total_amount'])
                record['total_items'] = int(record['total_items'])

                # Business logic validation
                if record['total_amount'] <= 0:
                    raise ValueError("Total amount must be greater than 0")

                if record['total_items'] <= 0:
                    raise ValueError("Total items must be greater than 0")

                # Strict validation additional checks
                if validation_level == 'strict':
                    if 'store_id' not in record:
                        raise ValueError("Store ID required for strict validation")

                    if len(record['canonical_tx_id']) != 64:
                        raise ValueError("Canonical transaction ID must be 64 characters")

                # Add validation metadata
                record['validation_status'] = 'passed'
                record['validation_timestamp'] = datetime.now().isoformat()

                validated_data.append(record)

            except Exception as e:
                validation_errors.append({
                    'record_index': idx,
                    'record_id': record.get('transaction_id', 'unknown'),
                    'error_message': str(e),
                    'validation_timestamp': datetime.now().isoformat()
                })

                logger.warning(
                    f"Record validation failed for index {idx}: {str(e)}"
                )

        # Log validation summary
        logger.info(
            f"Validation complete: {len(validated_data)} passed, "
            f"{len(validation_errors)} failed"
        )

        if validation_errors and validation_level == 'strict':
            raise ETLValidationError(
                f"Strict validation failed with {len(validation_errors)} errors",
                validation_errors
            )

        return validated_data

    def _transform_transaction_data(self, validated_data: List[Dict]) -> List[Dict]:
        """Transform validated data for database loading"""

        transformed_data = []

        for record in validated_data:
            try:
                # Data standardization
                transformed_record = {
                    'transaction_id': record['transaction_id'].strip(),
                    'canonical_tx_id': record['canonical_tx_id'].strip(),
                    'interaction_id': record.get('interaction_id', '').strip(),
                    'payload_json': json.dumps(record),
                    'payload_hash': self._calculate_payload_hash(record),
                    'txn_ts': self._parse_timestamp(record.get('timestamp')),
                    'total_amount': round(float(record['total_amount']), 2),
                    'total_items': int(record['total_items']),
                    'payment_method': record.get('payment_method', '').strip(),
                    'store_id': record.get('store_id', '').strip(),
                    'source_system': record.get('source_system', 'api_ingestion'),
                    'etl_batch_id': self.batch_id,
                    'processing_status': 'pending'
                }

                # Calculate quality score
                transformed_record['quality_score'] = self._calculate_quality_score(
                    transformed_record
                )

                transformed_data.append(transformed_record)

            except Exception as e:
                logger.warning(
                    f"Record transformation failed for {record.get('transaction_id')}: {str(e)}"
                )
                continue

        logger.info(f"Transformation complete: {len(transformed_data)} records")
        return transformed_data

    def _load_transaction_data(
        self,
        transformed_data: List[Dict],
        processing_mode: str
    ) -> Dict:
        """Load transformed data into database"""

        processed = 0
        successful = 0
        failed = 0

        try:
            with pyodbc.connect(self.connection_string) as conn:
                cursor = conn.cursor()

                # Prepare bulk insert statement
                insert_sql = """
                INSERT INTO dbo.PayloadTransactions (
                    transaction_id, canonical_tx_id, interaction_id, payload_json,
                    payload_hash, txn_ts, total_amount, total_items, payment_method,
                    store_id, source_system, etl_batch_id, processing_status, quality_score
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """

                # Process in batches for better performance
                batch_size = 1000
                for i in range(0, len(transformed_data), batch_size):
                    batch_data = transformed_data[i:i + batch_size]

                    try:
                        # Prepare batch parameters
                        batch_params = [
                            (
                                record['transaction_id'],
                                record['canonical_tx_id'],
                                record['interaction_id'],
                                record['payload_json'],
                                record['payload_hash'],
                                record['txn_ts'],
                                record['total_amount'],
                                record['total_items'],
                                record['payment_method'],
                                record['store_id'],
                                record['source_system'],
                                record['etl_batch_id'],
                                record['processing_status'],
                                record['quality_score']
                            )
                            for record in batch_data
                        ]

                        # Execute batch insert
                        cursor.executemany(insert_sql, batch_params)
                        conn.commit()

                        processed += len(batch_data)
                        successful += len(batch_data)

                        logger.info(
                            f"Loaded batch {i//batch_size + 1}: "
                            f"{len(batch_data)} records"
                        )

                    except Exception as e:
                        failed += len(batch_data)
                        logger.error(
                            f"Batch loading failed for batch {i//batch_size + 1}: {str(e)}"
                        )
                        conn.rollback()

        except Exception as e:
            logger.error(f"Database loading failed: {str(e)}")
            raise ETLLoadingError(f"Data loading failed: {str(e)}") from e

        return {
            'processed': processed,
            'successful': successful,
            'failed': failed
        }

    def _calculate_payload_hash(self, record: Dict) -> str:
        """Calculate SHA-256 hash for deduplication"""
        import hashlib

        # Create normalized string for hashing
        normalized_data = json.dumps(record, sort_keys=True)
        return hashlib.sha256(normalized_data.encode()).hexdigest()

    def _parse_timestamp(self, timestamp_value) -> Optional[datetime]:
        """Parse various timestamp formats"""
        if not timestamp_value:
            return None

        # Handle different timestamp formats
        timestamp_formats = [
            '%Y-%m-%d %H:%M:%S',
            '%Y-%m-%dT%H:%M:%S',
            '%Y-%m-%dT%H:%M:%S.%f',
            '%Y-%m-%dT%H:%M:%SZ'
        ]

        for fmt in timestamp_formats:
            try:
                return datetime.strptime(str(timestamp_value), fmt)
            except ValueError:
                continue

        logger.warning(f"Unable to parse timestamp: {timestamp_value}")
        return None

    def _calculate_quality_score(self, record: Dict) -> float:
        """Calculate data quality score for record"""
        score = 0.0
        max_score = 100.0

        # Required fields present and valid (50%)
        if record.get('total_amount', 0) > 0:
            score += 25.0
        if record.get('total_items', 0) > 0:
            score += 25.0

        # Optional but valuable fields (30%)
        if record.get('store_id', '').strip():
            score += 15.0
        if record.get('payment_method', '').strip():
            score += 15.0

        # Data consistency (20%)
        if record.get('canonical_tx_id', '') and len(record['canonical_tx_id']) == 64:
            score += 10.0
        if record.get('txn_ts'):
            score += 10.0

        return round(score / max_score, 2)

# Custom Exception Classes
class ETLProcessingError(Exception):
    """Base exception for ETL processing errors"""
    pass

class ETLValidationError(ETLProcessingError):
    """Exception for data validation errors"""
    def __init__(self, message: str, validation_errors: List[Dict]):
        super().__init__(message)
        self.validation_errors = validation_errors

class ETLLoadingError(ETLProcessingError):
    """Exception for data loading errors"""
    pass
```

## TypeScript/JavaScript Standards

### React Component Pattern

```typescript
// components/TransactionAnalytics.tsx
import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatCurrency, formatNumber } from '@/lib/utils';
import type { TransactionMetrics, DateRange } from '@/types/analytics';

interface TransactionAnalyticsProps {
  /** Date range for analytics data */
  dateRange: DateRange;
  /** Store ID filter (optional) */
  storeId?: string;
  /** Category filter (optional) */
  category?: string;
  /** Callback when data changes */
  onDataChange?: (metrics: TransactionMetrics) => void;
}

/**
 * TransactionAnalytics Component
 *
 * Displays comprehensive transaction analytics with filtering capabilities.
 * Implements proper error handling, loading states, and accessibility.
 */
export const TransactionAnalytics: React.FC<TransactionAnalyticsProps> = ({
  dateRange,
  storeId,
  category,
  onDataChange
}) => {
  // State management with proper typing
  const [metrics, setMetrics] = useState<TransactionMetrics | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Fetch analytics data with proper error handling
  const fetchAnalytics = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    try {
      const params = new URLSearchParams({
        start_date: dateRange.startDate,
        end_date: dateRange.endDate,
        ...(storeId && { store_id: storeId }),
        ...(category && { category })
      });

      const response = await fetch(`/api/analytics/transactions?${params}`);

      if (!response.ok) {
        throw new Error(`Analytics fetch failed: ${response.statusText}`);
      }

      const data: TransactionMetrics = await response.json();
      setMetrics(data);
      onDataChange?.(data);

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred';
      setError(errorMessage);
      console.error('Transaction analytics error:', err);
    } finally {
      setIsLoading(false);
    }
  }, [dateRange, storeId, category, onDataChange]);

  // Effect for data fetching
  useEffect(() => {
    fetchAnalytics();
  }, [fetchAnalytics]);

  // Memoized calculations for performance
  const calculatedMetrics = useMemo(() => {
    if (!metrics) return null;

    return {
      averageTransactionValue: metrics.totalRevenue / metrics.transactionCount,
      revenueGrowth: metrics.previousPeriodRevenue
        ? ((metrics.totalRevenue - metrics.previousPeriodRevenue) / metrics.previousPeriodRevenue) * 100
        : 0,
      topPerformingCategory: metrics.categoryBreakdown.reduce((top, current) =>
        current.revenue > top.revenue ? current : top
      )
    };
  }, [metrics]);

  // Loading state
  if (isLoading) {
    return (
      <Card className="w-full">
        <CardContent className="p-6">
          <div className="flex items-center justify-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
            <span className="ml-3 text-muted-foreground">Loading analytics...</span>
          </div>
        </CardContent>
      </Card>
    );
  }

  // Error state
  if (error) {
    return (
      <Card className="w-full border-destructive">
        <CardContent className="p-6">
          <div className="text-center">
            <p className="text-destructive mb-4">
              Failed to load analytics: {error}
            </p>
            <button
              onClick={fetchAnalytics}
              className="px-4 py-2 bg-primary text-primary-foreground rounded-md hover:bg-primary/90"
            >
              Retry
            </button>
          </div>
        </CardContent>
      </Card>
    );
  }

  // No data state
  if (!metrics || !calculatedMetrics) {
    return (
      <Card className="w-full">
        <CardContent className="p-6">
          <p className="text-center text-muted-foreground">
            No data available for the selected period
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-6">
      {/* Key Metrics Overview */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Total Revenue
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {formatCurrency(metrics.totalRevenue)}
            </div>
            {calculatedMetrics.revenueGrowth !== 0 && (
              <p className={`text-sm ${calculatedMetrics.revenueGrowth > 0 ? 'text-green-600' : 'text-red-600'}`}>
                {calculatedMetrics.revenueGrowth > 0 ? '+' : ''}{calculatedMetrics.revenueGrowth.toFixed(1)}% vs previous period
              </p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Transaction Count
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {formatNumber(metrics.transactionCount)}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Average Transaction Value
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {formatCurrency(calculatedMetrics.averageTransactionValue)}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Top Category
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-lg font-bold truncate">
              {calculatedMetrics.topPerformingCategory.name}
            </div>
            <p className="text-sm text-muted-foreground">
              {formatCurrency(calculatedMetrics.topPerformingCategory.revenue)}
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Category Breakdown */}
      <Card>
        <CardHeader>
          <CardTitle>Category Performance</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {metrics.categoryBreakdown.map((category) => (
              <div key={category.name} className="flex items-center justify-between">
                <div className="flex-1">
                  <div className="flex justify-between items-center mb-1">
                    <span className="font-medium">{category.name}</span>
                    <span className="text-sm text-muted-foreground">
                      {formatCurrency(category.revenue)}
                    </span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-2">
                    <div
                      className="bg-primary h-2 rounded-full transition-all duration-300"
                      style={{
                        width: `${(category.revenue / metrics.totalRevenue) * 100}%`
                      }}
                    />
                  </div>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  );
};

export default TransactionAnalytics;
```

### API Route Pattern

```typescript
// app/api/analytics/transactions/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import sql from 'mssql';
import { getDatabaseConnection } from '@/lib/database';
import { formatAnalyticsResponse } from '@/lib/analytics';
import type { TransactionMetrics } from '@/types/analytics';

// Request validation schema
const analyticsRequestSchema = z.object({
  start_date: z.string().datetime(),
  end_date: z.string().datetime(),
  store_id: z.string().optional(),
  category: z.string().optional(),
  limit: z.coerce.number().min(1).max(1000).default(100)
});

/**
 * GET /api/analytics/transactions
 *
 * Retrieve transaction analytics with filtering and aggregation
 */
export async function GET(request: NextRequest) {
  try {
    // Parse and validate query parameters
    const { searchParams } = new URL(request.url);
    const params = Object.fromEntries(searchParams);

    const validatedParams = analyticsRequestSchema.parse(params);

    // Get database connection
    const pool = await getDatabaseConnection();

    // Build dynamic query based on filters
    let query = `
      SELECT
        COUNT(*) as transaction_count,
        SUM(total_amount) as total_revenue,
        AVG(total_amount) as avg_transaction_value,
        SUM(total_items) as total_items,
        AVG(total_items) as avg_basket_size,
        nielsen_category,
        store_name,
        COUNT(DISTINCT store_id) as unique_stores,
        COUNT(DISTINCT brand) as unique_brands
      FROM dbo.v_nielsen_complete_analytics
      WHERE transaction_timestamp >= @start_date
      AND transaction_timestamp <= @end_date
    `;

    const queryParams: Record<string, any> = {
      start_date: validatedParams.start_date,
      end_date: validatedParams.end_date
    };

    // Add optional filters
    if (validatedParams.store_id) {
      query += ' AND store_id = @store_id';
      queryParams.store_id = validatedParams.store_id;
    }

    if (validatedParams.category) {
      query += ' AND nielsen_category = @category';
      queryParams.category = validatedParams.category;
    }

    query += `
      GROUP BY nielsen_category, store_name
      ORDER BY total_revenue DESC
    `;

    // Execute main query
    const request = pool.request();

    // Add parameters to request
    Object.entries(queryParams).forEach(([key, value]) => {
      request.input(key, value);
    });

    const result = await request.query(query);

    // Get category breakdown
    const categoryQuery = `
      SELECT
        nielsen_category,
        COUNT(*) as transaction_count,
        SUM(total_amount) as revenue,
        AVG(total_amount) as avg_value
      FROM dbo.v_nielsen_complete_analytics
      WHERE transaction_timestamp >= @start_date
      AND transaction_timestamp <= @end_date
      ${validatedParams.store_id ? 'AND store_id = @store_id' : ''}
      ${validatedParams.category ? 'AND nielsen_category = @category' : ''}
      GROUP BY nielsen_category
      ORDER BY revenue DESC
    `;

    const categoryRequest = pool.request();
    Object.entries(queryParams).forEach(([key, value]) => {
      categoryRequest.input(key, value);
    });

    const categoryResult = await categoryRequest.query(categoryQuery);

    // Format response data
    const analytics: TransactionMetrics = {
      transactionCount: result.recordset.reduce((sum, row) => sum + row.transaction_count, 0),
      totalRevenue: result.recordset.reduce((sum, row) => sum + row.total_revenue, 0),
      averageTransactionValue: result.recordset.length > 0
        ? result.recordset.reduce((sum, row) => sum + row.avg_transaction_value, 0) / result.recordset.length
        : 0,
      totalItems: result.recordset.reduce((sum, row) => sum + row.total_items, 0),
      averageBasketSize: result.recordset.length > 0
        ? result.recordset.reduce((sum, row) => sum + row.avg_basket_size, 0) / result.recordset.length
        : 0,
      uniqueStores: result.recordset.reduce((sum, row) => sum + row.unique_stores, 0),
      uniqueBrands: result.recordset.reduce((sum, row) => sum + row.unique_brands, 0),
      categoryBreakdown: categoryResult.recordset.map(row => ({
        name: row.nielsen_category,
        transactionCount: row.transaction_count,
        revenue: row.revenue,
        averageValue: row.avg_value
      })),
      storeBreakdown: result.recordset.map(row => ({
        name: row.store_name,
        category: row.nielsen_category,
        transactionCount: row.transaction_count,
        revenue: row.total_revenue,
        averageValue: row.avg_transaction_value
      }))
    };

    // Return formatted response
    return NextResponse.json(
      formatAnalyticsResponse(analytics),
      {
        status: 200,
        headers: {
          'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=600'
        }
      }
    );

  } catch (error) {
    console.error('Analytics API error:', error);

    // Handle validation errors
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        {
          error: 'Invalid request parameters',
          details: error.errors
        },
        { status: 400 }
      );
    }

    // Handle database errors
    if (error instanceof sql.RequestError) {
      return NextResponse.json(
        {
          error: 'Database query failed',
          message: error.message
        },
        { status: 500 }
      );
    }

    // Generic error response
    return NextResponse.json(
      {
        error: 'Internal server error',
        message: 'An unexpected error occurred'
      },
      { status: 500 }
    );
  }
}

// Type definitions
interface TransactionMetrics {
  transactionCount: number;
  totalRevenue: number;
  averageTransactionValue: number;
  totalItems: number;
  averageBasketSize: number;
  uniqueStores: number;
  uniqueBrands: number;
  categoryBreakdown: CategoryMetric[];
  storeBreakdown: StoreMetric[];
}

interface CategoryMetric {
  name: string;
  transactionCount: number;
  revenue: number;
  averageValue: number;
}

interface StoreMetric {
  name: string;
  category: string;
  transactionCount: number;
  revenue: number;
  averageValue: number;
}
```

## Performance Optimization

### Database Query Optimization

```sql
-- Optimized analytics query with proper indexing strategy
-- Before optimization: 15+ seconds
-- After optimization: <2 seconds

-- Step 1: Create supporting indexes
CREATE NONCLUSTERED INDEX IX_v_nielsen_complete_analytics_optimized
ON dbo.v_nielsen_complete_analytics (transaction_timestamp, nielsen_category, store_id)
INCLUDE (total_amount, total_items, brand_name);

-- Step 2: Optimized query with query hints
WITH daily_aggregates AS (
    SELECT
        CAST(vna.transaction_timestamp AS DATE) AS transaction_date,
        vna.nielsen_category,
        vna.store_id,
        vna.store_name,
        COUNT_BIG(*) AS transaction_count,  -- Use COUNT_BIG for large datasets
        SUM(vna.transaction_value) AS daily_revenue,
        SUM(vna.basket_size) AS daily_items,
        AVG(vna.transaction_value) AS avg_transaction_value
    FROM dbo.v_nielsen_complete_analytics vna WITH (NOLOCK)  -- Read uncommitted for analytics
    WHERE vna.transaction_timestamp >= @start_date
    AND vna.transaction_timestamp < DATEADD(DAY, 1, @end_date)  -- Use < instead of <=
    GROUP BY
        CAST(vna.transaction_timestamp AS DATE),
        vna.nielsen_category,
        vna.store_id,
        vna.store_name
),
category_totals AS (
    SELECT
        da.nielsen_category,
        SUM(da.transaction_count) AS total_transactions,
        SUM(da.daily_revenue) AS total_revenue,
        AVG(da.avg_transaction_value) AS avg_value,
        COUNT(DISTINCT da.store_id) AS store_count
    FROM daily_aggregates da
    GROUP BY da.nielsen_category
)
SELECT
    ct.nielsen_category,
    ct.total_transactions,
    ct.total_revenue,
    ct.avg_value,
    ct.store_count,
    -- Calculate percentages efficiently
    CAST(ct.total_revenue * 100.0 / SUM(ct.total_revenue) OVER() AS DECIMAL(5,2)) AS revenue_percentage
FROM category_totals ct
ORDER BY ct.total_revenue DESC
OPTION (MAXDOP 4, RECOMPILE);  -- Optimize for parallel execution
```

### Caching Strategy

```typescript
// lib/cache.ts
import { Redis } from 'ioredis';

interface CacheConfig {
  ttl: number;
  prefix: string;
}

class AnalyticsCache {
  private redis: Redis;
  private defaultTTL: number = 300; // 5 minutes

  constructor(redisUrl?: string) {
    this.redis = new Redis(redisUrl || process.env.REDIS_URL || 'redis://localhost:6379');
  }

  /**
   * Generate cache key with consistent naming
   */
  private generateKey(type: string, params: Record<string, any>): string {
    const sortedParams = Object.keys(params)
      .sort()
      .map(key => `${key}:${params[key]}`)
      .join('|');
    return `scout:analytics:${type}:${sortedParams}`;
  }

  /**
   * Get cached analytics data
   */
  async get<T>(
    type: string,
    params: Record<string, any>
  ): Promise<T | null> {
    try {
      const key = this.generateKey(type, params);
      const cached = await this.redis.get(key);

      if (cached) {
        return JSON.parse(cached) as T;
      }

      return null;
    } catch (error) {
      console.error('Cache get error:', error);
      return null;
    }
  }

  /**
   * Set cached analytics data
   */
  async set<T>(
    type: string,
    params: Record<string, any>,
    data: T,
    ttl?: number
  ): Promise<void> {
    try {
      const key = this.generateKey(type, params);
      const serialized = JSON.stringify(data);

      await this.redis.setex(
        key,
        ttl || this.defaultTTL,
        serialized
      );
    } catch (error) {
      console.error('Cache set error:', error);
    }
  }

  /**
   * Invalidate cache by pattern
   */
  async invalidate(pattern: string): Promise<void> {
    try {
      const keys = await this.redis.keys(`scout:analytics:${pattern}*`);

      if (keys.length > 0) {
        await this.redis.del(...keys);
      }
    } catch (error) {
      console.error('Cache invalidation error:', error);
    }
  }
}

// Export singleton instance
export const analyticsCache = new AnalyticsCache();

// Usage in API routes
export async function getCachedAnalytics<T>(
  type: string,
  params: Record<string, any>,
  fetchFn: () => Promise<T>,
  ttl?: number
): Promise<T> {
  // Try to get from cache first
  const cached = await analyticsCache.get<T>(type, params);
  if (cached) {
    return cached;
  }

  // Fetch fresh data
  const data = await fetchFn();

  // Cache for next time
  await analyticsCache.set(type, params, data, ttl);

  return data;
}
```

## Testing & Quality Assurance

### Database Unit Testing

```sql
-- Test framework for stored procedures and functions
-- File: tests/database/test_transaction_processing.sql

-- Test setup
DECLARE @TestBatchId VARCHAR(100) = 'TEST_BATCH_' + FORMAT(GETDATE(), 'yyyyMMdd_HHmmss');
DECLARE @TestResults TABLE (
    test_name VARCHAR(200),
    status VARCHAR(20),
    expected_value VARCHAR(100),
    actual_value VARCHAR(100),
    message NVARCHAR(500)
);

-- Test 1: Brand detection function accuracy
INSERT INTO @TestResults
SELECT
    'fn_DetectBrandName_Accuracy' AS test_name,
    CASE
        WHEN dbo.fn_DetectBrandName('Marlboro Red 20 sticks') = 'Marlboro'
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    'Marlboro' AS expected_value,
    dbo.fn_DetectBrandName('Marlboro Red 20 sticks') AS actual_value,
    'Brand detection should identify Marlboro from product name' AS message;

-- Test 2: Quality score calculation
INSERT INTO @TestResults
SELECT
    'Quality_Score_Calculation' AS test_name,
    CASE
        WHEN quality_score >= 0.8
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    '>=0.8' AS expected_value,
    CAST(quality_score AS VARCHAR(10)) AS actual_value,
    'Quality score should be at least 0.8 for complete data' AS message
FROM (
    SELECT quality_score FROM dbo.fn_ValidateTransactionData(
        'TEST123', 100.50, 3, 'Coca Cola', 'Soft Drinks'
    )
) AS quality_test;

-- Test 3: ETL processing stored procedure
BEGIN TRY
    -- Insert test data
    INSERT INTO dbo.PayloadTransactionsStaging (
        batch_id, payload, ingestion_timestamp
    ) VALUES (
        @TestBatchId,
        '{"transaction_id": "TEST001", "canonical_tx_id": "' + REPLICATE('1', 64) + '", "total_amount": 150.00, "total_items": 2}',
        GETDATE()
    );

    -- Execute procedure
    EXEC dbo.sp_IngestRawTransactionData
        @BatchId = @TestBatchId,
        @DataSource = 'unit_test',
        @ProcessingMode = 'full';

    -- Verify results
    INSERT INTO @TestResults
    SELECT
        'sp_IngestRawTransactionData_Processing' AS test_name,
        CASE
            WHEN COUNT(*) > 0 THEN 'PASS'
            ELSE 'FAIL'
        END AS status,
        '>0' AS expected_value,
        CAST(COUNT(*) AS VARCHAR(10)) AS actual_value,
        'Stored procedure should process test data successfully' AS message
    FROM dbo.PayloadTransactions
    WHERE etl_batch_id = @TestBatchId;

END TRY
BEGIN CATCH
    INSERT INTO @TestResults
    VALUES (
        'sp_IngestRawTransactionData_Processing',
        'FAIL',
        'SUCCESS',
        'EXCEPTION',
        'Stored procedure threw exception: ' + ERROR_MESSAGE()
    );
END CATCH;

-- Test 4: Data quality validation
INSERT INTO @TestResults
SELECT
    'Data_Quality_Validation' AS test_name,
    CASE
        WHEN AVG(quality_score) >= 0.9
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    '>=0.9' AS expected_value,
    CAST(AVG(quality_score) AS VARCHAR(10)) AS actual_value,
    'Average quality score should be >= 0.9 for test data' AS message
FROM dbo.PayloadTransactions
WHERE etl_batch_id = @TestBatchId;

-- Display test results
SELECT
    test_name,
    status,
    expected_value,
    actual_value,
    message,
    CASE
        WHEN status = 'PASS' THEN '✅'
        ELSE '❌'
    END AS result_icon
FROM @TestResults;

-- Summary
SELECT
    COUNT(*) AS total_tests,
    COUNT(CASE WHEN status = 'PASS' THEN 1 END) AS passed_tests,
    COUNT(CASE WHEN status = 'FAIL' THEN 1 END) AS failed_tests,
    CAST(COUNT(CASE WHEN status = 'PASS' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS pass_rate
FROM @TestResults;

-- Cleanup test data
DELETE FROM dbo.PayloadTransactions WHERE etl_batch_id = @TestBatchId;
DELETE FROM dbo.PayloadTransactionsStaging WHERE batch_id = @TestBatchId;
```

### TypeScript Testing Patterns

```typescript
// __tests__/analytics/transaction-analytics.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import { server } from '@/__mocks__/server';
import { TransactionAnalytics } from '@/components/TransactionAnalytics';
import { mockAnalyticsData } from '@/__mocks__/analytics-data';

// Mock server handlers
import { rest } from 'msw';

describe('TransactionAnalytics', () => {
  const defaultProps = {
    dateRange: {
      startDate: '2025-09-01T00:00:00Z',
      endDate: '2025-09-25T23:59:59Z'
    }
  };

  beforeEach(() => {
    // Reset mock handlers before each test
    server.resetHandlers();
  });

  it('renders loading state initially', () => {
    render(<TransactionAnalytics {...defaultProps} />);

    expect(screen.getByText('Loading analytics...')).toBeInTheDocument();
    expect(screen.getByRole('progressbar')).toBeInTheDocument();
  });

  it('displays analytics data when loaded successfully', async () => {
    // Mock successful API response
    server.use(
      rest.get('/api/analytics/transactions', (req, res, ctx) => {
        return res(ctx.json(mockAnalyticsData));
      })
    );

    render(<TransactionAnalytics {...defaultProps} />);

    // Wait for data to load
    await waitFor(() => {
      expect(screen.getByText('Total Revenue')).toBeInTheDocument();
    });

    // Verify key metrics are displayed
    expect(screen.getByText('₱125,450.00')).toBeInTheDocument(); // Total revenue
    expect(screen.getByText('1,247')).toBeInTheDocument(); // Transaction count
    expect(screen.getByText('₱100.60')).toBeInTheDocument(); // Average transaction value
  });

  it('handles API errors gracefully', async () => {
    // Mock API error
    server.use(
      rest.get('/api/analytics/transactions', (req, res, ctx) => {
        return res(ctx.status(500), ctx.json({ error: 'Database connection failed' }));
      })
    );

    render(<TransactionAnalytics {...defaultProps} />);

    // Wait for error state
    await waitFor(() => {
      expect(screen.getByText(/Failed to load analytics/)).toBeInTheDocument();
    });

    expect(screen.getByRole('button', { name: 'Retry' })).toBeInTheDocument();
  });

  it('filters data by store ID when provided', async () => {
    const propsWithStore = {
      ...defaultProps,
      storeId: 'STORE001'
    };

    server.use(
      rest.get('/api/analytics/transactions', (req, res, ctx) => {
        // Verify store_id parameter is sent
        expect(req.url.searchParams.get('store_id')).toBe('STORE001');
        return res(ctx.json(mockAnalyticsData));
      })
    );

    render(<TransactionAnalytics {...propsWithStore} />);

    await waitFor(() => {
      expect(screen.getByText('Total Revenue')).toBeInTheDocument();
    });
  });

  it('calls onDataChange callback when data is loaded', async () => {
    const mockOnDataChange = jest.fn();

    server.use(
      rest.get('/api/analytics/transactions', (req, res, ctx) => {
        return res(ctx.json(mockAnalyticsData));
      })
    );

    render(
      <TransactionAnalytics
        {...defaultProps}
        onDataChange={mockOnDataChange}
      />
    );

    await waitFor(() => {
      expect(mockOnDataChange).toHaveBeenCalledWith(mockAnalyticsData);
    });
  });

  it('displays category breakdown with proper formatting', async () => {
    server.use(
      rest.get('/api/analytics/transactions', (req, res, ctx) => {
        return res(ctx.json(mockAnalyticsData));
      })
    );

    render(<TransactionAnalytics {...defaultProps} />);

    await waitFor(() => {
      expect(screen.getByText('Category Performance')).toBeInTheDocument();
    });

    // Verify category data is displayed
    expect(screen.getByText('Soft Drinks')).toBeInTheDocument();
    expect(screen.getByText('Cigarettes')).toBeInTheDocument();
    expect(screen.getByText('Detergent')).toBeInTheDocument();
  });
});

// Mock data for testing
// __mocks__/analytics-data.ts
export const mockAnalyticsData = {
  transactionCount: 1247,
  totalRevenue: 125450.00,
  averageTransactionValue: 100.60,
  totalItems: 3741,
  averageBasketSize: 3.0,
  uniqueStores: 15,
  uniqueBrands: 45,
  categoryBreakdown: [
    {
      name: 'Soft Drinks',
      transactionCount: 425,
      revenue: 45230.50,
      averageValue: 106.43
    },
    {
      name: 'Cigarettes',
      transactionCount: 312,
      revenue: 38720.00,
      averageValue: 124.10
    },
    {
      name: 'Detergent',
      transactionCount: 510,
      revenue: 41499.50,
      averageValue: 81.37
    }
  ],
  storeBreakdown: [
    {
      name: 'Store Alpha',
      category: 'Soft Drinks',
      transactionCount: 145,
      revenue: 15670.25,
      averageValue: 108.07
    }
  ]
};
```

This comprehensive coding manual provides standardized patterns, best practices, and quality guidelines for developing and maintaining the Scout Analytics Platform. Following these standards ensures code quality, maintainability, and optimal performance across all system components.