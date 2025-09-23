-- ==========================================
-- Scout Edge JSON Payload Builder - Azure SQL
-- Transforms raw staging data into deduplicated JSON payloads
-- ==========================================

USE [ScoutEdgeDB];  -- Adjust database name as needed
GO

-- ==========================================
-- 1. CREATE FACT TABLE FOR JSON PAYLOADS
-- ==========================================

-- Drop existing fact table if it exists
IF OBJECT_ID('dbo.fact_transactions_location','U') IS NOT NULL
    DROP TABLE dbo.fact_transactions_location;
GO

-- Create fact table with JSON payload column
CREATE TABLE dbo.fact_transactions_location (
    -- Primary identifiers
    canonical_tx_id     VARCHAR(64)     NOT NULL PRIMARY KEY,
    transaction_id      VARCHAR(64)     NOT NULL,
    store_id            INT             NULL,
    device_id           VARCHAR(64)     NULL,

    -- Summary metrics (for fast queries without JSON parsing)
    total_amount        DECIMAL(10,2)   NULL,
    item_count          INT             DEFAULT 0,
    substitution_detected BIT           DEFAULT 0,

    -- Location summary (for geographic queries)
    municipality_name   VARCHAR(100)    NULL,
    province_name       VARCHAR(100)    NULL,
    region              VARCHAR(50)     NULL,
    latitude            DECIMAL(10,8)   NULL,
    longitude           DECIMAL(11,8)   NULL,

    -- Quality metrics
    data_quality_score  DECIMAL(5,2)    NULL,

    -- JSON payload (the complete nested structure)
    payload_json        NVARCHAR(MAX)   NULL,

    -- Audit fields
    source_file_count   INT             DEFAULT 0,
    created_at          DATETIME2(0)    DEFAULT GETUTCDATE(),

    -- Check constraints
    CONSTRAINT CK_fact_quality_score CHECK (data_quality_score BETWEEN 0 AND 100),
    CONSTRAINT CK_fact_amount_positive CHECK (total_amount >= 0)
);
GO

-- Create indexes for performance
CREATE NONCLUSTERED INDEX IX_fact_store_location
    ON dbo.fact_transactions_location (store_id, municipality_name);

CREATE NONCLUSTERED INDEX IX_fact_substitution
    ON dbo.fact_transactions_location (substitution_detected, store_id)
    WHERE substitution_detected = 1;

CREATE NONCLUSTERED INDEX IX_fact_quality_score
    ON dbo.fact_transactions_location (data_quality_score DESC);
GO

-- ==========================================
-- 2. GEOGRAPHIC REFERENCE DATA
-- ==========================================

-- Create NCR store mapping if it doesn't exist
IF OBJECT_ID('dbo.dim_ncr_stores','U') IS NULL
CREATE TABLE dbo.dim_ncr_stores (
    store_id            INT             PRIMARY KEY,
    store_name          VARCHAR(100)    NOT NULL,
    device_id           VARCHAR(64)     NULL,
    municipality_name   VARCHAR(100)    NOT NULL,
    province_name       VARCHAR(100)    NOT NULL DEFAULT 'Metro Manila',
    region              VARCHAR(50)     NOT NULL DEFAULT 'NCR',
    barangay_name       VARCHAR(100)    NULL,
    psgc_region         VARCHAR(9)      DEFAULT '130000000',
    psgc_citymun        VARCHAR(9)      NULL,
    psgc_barangay       VARCHAR(9)      NULL,
    latitude            DECIMAL(10,8)   NOT NULL,
    longitude           DECIMAL(11,8)   NOT NULL
);

-- Insert NCR store mappings
MERGE dbo.dim_ncr_stores AS target
USING (VALUES
    (102, 'Scout Store Manila', 'scoutpi-0102', 'Manila', 'Metro Manila', 'NCR', 'Ermita', '130000000', '137601000', '137601034', 14.5995, 120.9842),
    (103, 'Scout Store Quezon City', 'scoutpi-0103', 'Quezon City', 'Metro Manila', 'NCR', 'Bagumbayan', '130000000', '137404000', '137404018', 14.6760, 121.0437),
    (104, 'Scout Store Makati', 'scoutpi-0104', 'Makati', 'Metro Manila', 'NCR', 'Poblacion', '130000000', '137404000', '137404032', 14.5547, 121.0244),
    (108, 'Scout Store Pasig', 'scoutpi-0108', 'Pasig', 'Metro Manila', 'NCR', 'Kapitolyo', '130000000', '137307000', '137307015', 14.5764, 121.0851),
    (109, 'Scout Store Mandaluyong', 'scoutpi-0109', 'Mandaluyong', 'Metro Manila', 'NCR', 'Addition Hills', '130000000', '137501000', '137501001', 14.5833, 121.0333),
    (110, 'Scout Store Parañaque', 'scoutpi-0110', 'Parañaque', 'Metro Manila', 'NCR', 'BF Homes', '130000000', '137307000', '137307004', 14.4793, 121.0195),
    (112, 'Scout Store Taguig', 'scoutpi-0112', 'Taguig', 'Metro Manila', 'NCR', 'Bonifacio Global City', '130000000', '137601000', '137601008', 14.5176, 121.0509)
) AS source (store_id, store_name, device_id, municipality_name, province_name, region, barangay_name, psgc_region, psgc_citymun, psgc_barangay, latitude, longitude)
ON target.store_id = source.store_id
WHEN MATCHED THEN UPDATE SET
    store_name = source.store_name,
    device_id = source.device_id,
    municipality_name = source.municipality_name,
    barangay_name = source.barangay_name,
    psgc_citymun = source.psgc_citymun,
    psgc_barangay = source.psgc_barangay,
    latitude = source.latitude,
    longitude = source.longitude
WHEN NOT MATCHED THEN INSERT VALUES
    (source.store_id, source.store_name, source.device_id, source.municipality_name, source.province_name, source.region, source.barangay_name, source.psgc_region, source.psgc_citymun, source.psgc_barangay, source.latitude, source.longitude);
GO

-- ==========================================
-- 3. JSON PAYLOAD BUILDER FUNCTION
-- ==========================================

CREATE OR ALTER FUNCTION dbo.fn_build_scout_json_payload(
    @transaction_id VARCHAR(64)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @json_payload NVARCHAR(MAX);

    -- Build complete JSON payload using FOR JSON PATH
    WITH transaction_base AS (
        SELECT
            s.transactionId,
            s.storeId,
            s.deviceId,
            MIN(s._ingested_at) as earliest_timestamp,
            COUNT(*) as interaction_count,
            SUM(ISNULL(s.totalAmount, 0)) as total_amount,
            -- Demographics (prefer latest non-null values)
            MAX(CASE WHEN s.payload_json LIKE '%"ageBracket"%' THEN JSON_VALUE(s.payload_json, '$.ageBracket') END) as age_bracket,
            MAX(CASE WHEN s.payload_json LIKE '%"gender"%' THEN JSON_VALUE(s.payload_json, '$.gender') END) as gender,
            MAX(CASE WHEN s.payload_json LIKE '%"role"%' THEN JSON_VALUE(s.payload_json, '$.role') END) as role,
            -- Quality flags
            CASE WHEN COUNT(*) FILTER (WHERE s.substitution IN ('true', '1', 'TRUE')) > 0 THEN 1 ELSE 0 END as has_substitution,
            CASE WHEN s.storeId IS NOT NULL THEN 1 ELSE 0 END as location_verified,
            CASE WHEN COUNT(*) FILTER (WHERE s.audioTranscript IS NOT NULL AND LEN(s.audioTranscript) > 0) > 0 THEN 1 ELSE 0 END as has_audio
        FROM staging.payload_transactions_raw s
        WHERE s.transactionId = @transaction_id
        GROUP BY s.transactionId, s.storeId, s.deviceId
    ),
    basket_items AS (
        SELECT
            s.transactionId,
            -- Build basket items array
            (SELECT
                ROW_NUMBER() OVER (ORDER BY s2._ingested_at) as lineId,
                ISNULL(JSON_VALUE(s2.payload_json, '$.brand'), 'Unknown') as brand,
                ISNULL(JSON_VALUE(s2.payload_json, '$.sku'), 'SKU-' + s2.deviceId) as sku,
                ISNULL(TRY_CAST(JSON_VALUE(s2.payload_json, '$.qty') AS INT), 1) as qty,
                ISNULL(s2.totalAmount, 0) as unitPrice,
                ISNULL(s2.totalAmount, 0) as totalPrice,
                CASE WHEN s2.substitution IN ('true', '1', 'TRUE') THEN CAST(1 as bit) ELSE CAST(0 as bit) END as substitutionEvent,
                CASE WHEN s2.substitution IN ('true', '1', 'TRUE') THEN JSON_VALUE(s2.payload_json, '$.substitutionFrom') END as substitutionFrom
             FROM staging.payload_transactions_raw s2
             WHERE s2.transactionId = s.transactionId
             FOR JSON PATH) as basket_items_json
        FROM staging.payload_transactions_raw s
        WHERE s.transactionId = @transaction_id
        GROUP BY s.transactionId
    )
    SELECT @json_payload = (
        SELECT
            tb.transactionId,
            tb.storeId,
            tb.deviceId,
            CONVERT(VARCHAR(23), tb.earliest_timestamp, 126) + 'Z' as timestamp,
            JSON_QUERY(bi.basket_items_json) as 'basket.items',
            tb.age_bracket as 'interaction.ageBracket',
            tb.gender as 'interaction.gender',
            tb.role as 'interaction.role',
            CASE WHEN DATEPART(WEEKDAY, tb.earliest_timestamp) IN (1, 7) THEN 'Weekend' ELSE 'Weekday' END as 'interaction.weekdayOrWeekend',
            FORMAT(tb.earliest_timestamp, 'hhtt') as 'interaction.timeOfDay',
            ds.region as 'location.region',
            ds.province_name as 'location.province',
            ds.municipality_name as 'location.municipality',
            ds.barangay_name as 'location.barangay',
            ds.psgc_region as 'location.psgc_region',
            ds.psgc_citymun as 'location.psgc_citymun',
            ds.psgc_barangay as 'location.psgc_barangay',
            ds.latitude as 'location.geo.lat',
            ds.longitude as 'location.geo.lon',
            CASE WHEN ds.store_id IS NOT NULL THEN CAST(1 as bit) ELSE CAST(0 as bit) END as 'qualityFlags.brandMatched',
            CASE WHEN ds.municipality_name IS NOT NULL AND ds.latitude IS NOT NULL THEN CAST(1 as bit) ELSE CAST(0 as bit) END as 'qualityFlags.locationVerified',
            CASE WHEN tb.has_substitution = 1 THEN CAST(1 as bit) ELSE CAST(0 as bit) END as 'qualityFlags.substitutionDetected',
            'blob://gdrive-scout-ingest/' as 'source.file',
            tb.interaction_count as 'source.rowCount'
        FROM transaction_base tb
        LEFT JOIN basket_items bi ON tb.transactionId = bi.transactionId
        LEFT JOIN dbo.dim_ncr_stores ds ON tb.storeId = ds.store_id
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );

    RETURN @json_payload;
END;
GO

-- ==========================================
-- 4. DEDUPLICATION AND TRANSFORMATION PROCEDURE
-- ==========================================

CREATE OR ALTER PROCEDURE dbo.sp_transform_to_json_payloads
    @clean_fact_table BIT = 1,
    @batch_size INT = 1000
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_time DATETIME2 = GETUTCDATE();
    DECLARE @processed_count INT = 0;
    DECLARE @error_count INT = 0;

    PRINT '========================================';
    PRINT 'Scout Edge JSON Payload Transformation';
    PRINT '========================================';
    PRINT 'Start Time: ' + CONVERT(VARCHAR, @start_time, 120);

    -- Clean fact table if requested
    IF @clean_fact_table = 1
    BEGIN
        TRUNCATE TABLE dbo.fact_transactions_location;
        PRINT 'Fact table cleaned.';
    END;

    -- Get distinct transaction IDs to process
    DECLARE @transaction_ids TABLE (
        transaction_id VARCHAR(64),
        row_num INT
    );

    INSERT INTO @transaction_ids (transaction_id, row_num)
    SELECT DISTINCT
        transactionId,
        ROW_NUMBER() OVER (ORDER BY transactionId)
    FROM staging.payload_transactions_raw
    WHERE transactionId IS NOT NULL;

    DECLARE @total_transactions INT = (SELECT COUNT(*) FROM @transaction_ids);
    PRINT 'Total unique transactions to process: ' + CAST(@total_transactions AS VARCHAR);

    -- Process transactions in batches
    DECLARE @batch_start INT = 1;
    DECLARE @batch_end INT;

    WHILE @batch_start <= @total_transactions
    BEGIN
        SET @batch_end = @batch_start + @batch_size - 1;
        IF @batch_end > @total_transactions SET @batch_end = @total_transactions;

        PRINT 'Processing batch: ' + CAST(@batch_start AS VARCHAR) + ' to ' + CAST(@batch_end AS VARCHAR);

        BEGIN TRY
            -- Process current batch
            WITH batch_transactions AS (
                SELECT t.transaction_id
                FROM @transaction_ids t
                WHERE t.row_num BETWEEN @batch_start AND @batch_end
            ),
            transaction_summary AS (
                SELECT
                    s.transactionId as canonical_tx_id,
                    s.transactionId,
                    s.storeId as store_id,
                    s.deviceId as device_id,
                    SUM(ISNULL(s.totalAmount, 0)) as total_amount,
                    COUNT(*) as item_count,
                    CASE WHEN COUNT(*) FILTER (WHERE s.substitution IN ('true', '1', 'TRUE')) > 0 THEN 1 ELSE 0 END as substitution_detected,
                    ds.municipality_name,
                    ds.province_name,
                    ds.region,
                    ds.latitude,
                    ds.longitude,
                    -- Calculate quality score (0-100)
                    (CASE WHEN s.transactionId IS NOT NULL THEN 20 ELSE 0 END +
                     CASE WHEN s.storeId IS NOT NULL THEN 20 ELSE 0 END +
                     CASE WHEN s.deviceId IS NOT NULL THEN 10 ELSE 0 END +
                     CASE WHEN ds.municipality_name IS NOT NULL THEN 20 ELSE 0 END +
                     CASE WHEN COUNT(*) FILTER (WHERE s.audioTranscript IS NOT NULL AND LEN(s.audioTranscript) > 0) > 0 THEN 20 ELSE 0 END +
                     CASE WHEN COUNT(*) FILTER (WHERE s.substitution IN ('true', '1', 'TRUE')) > 0 THEN 10 ELSE 0 END) as data_quality_score,
                    COUNT(DISTINCT s.source_path) as source_file_count,
                    dbo.fn_build_scout_json_payload(s.transactionId) as payload_json
                FROM staging.payload_transactions_raw s
                INNER JOIN batch_transactions bt ON s.transactionId = bt.transaction_id
                LEFT JOIN dbo.dim_ncr_stores ds ON s.storeId = ds.store_id
                GROUP BY s.transactionId, s.storeId, s.deviceId, ds.municipality_name, ds.province_name, ds.region, ds.latitude, ds.longitude
            )
            INSERT INTO dbo.fact_transactions_location (
                canonical_tx_id, transaction_id, store_id, device_id, total_amount, item_count,
                substitution_detected, municipality_name, province_name, region, latitude, longitude,
                data_quality_score, source_file_count, payload_json
            )
            SELECT
                canonical_tx_id, transaction_id, store_id, device_id, total_amount, item_count,
                substitution_detected, municipality_name, province_name, region, latitude, longitude,
                data_quality_score, source_file_count, payload_json
            FROM transaction_summary;

            SET @processed_count = @processed_count + @@ROWCOUNT;

        END TRY
        BEGIN CATCH
            SET @error_count = @error_count + 1;
            PRINT 'Error in batch ' + CAST(@batch_start AS VARCHAR) + ': ' + ERROR_MESSAGE();
        END CATCH

        SET @batch_start = @batch_end + 1;

        -- Progress update every 10 batches
        IF (@batch_start - 1) % (@batch_size * 10) = 0
        BEGIN
            PRINT 'Progress: ' + CAST(@processed_count AS VARCHAR) + ' / ' + CAST(@total_transactions AS VARCHAR) + ' transactions processed';
        END;
    END;

    -- Final statistics
    DECLARE @end_time DATETIME2 = GETUTCDATE();
    DECLARE @duration_seconds INT = DATEDIFF(SECOND, @start_time, @end_time);

    PRINT '========================================';
    PRINT 'Transformation Complete';
    PRINT '========================================';
    PRINT 'Transactions processed: ' + CAST(@processed_count AS VARCHAR);
    PRINT 'Errors encountered: ' + CAST(@error_count AS VARCHAR);
    PRINT 'Duration: ' + CAST(@duration_seconds AS VARCHAR) + ' seconds';
    PRINT 'End Time: ' + CONVERT(VARCHAR, @end_time, 120);

    -- Quality summary
    SELECT
        COUNT(*) as total_fact_rows,
        AVG(data_quality_score) as avg_quality_score,
        MIN(data_quality_score) as min_quality_score,
        MAX(data_quality_score) as max_quality_score,
        SUM(item_count) as total_items,
        SUM(CASE WHEN substitution_detected = 1 THEN 1 ELSE 0 END) as substitution_events,
        COUNT(DISTINCT store_id) as unique_stores,
        COUNT(*) FILTER (WHERE municipality_name IS NOT NULL) as with_location_data
    FROM dbo.fact_transactions_location;
END;
GO

-- ==========================================
-- 5. VALIDATION QUERIES
-- ==========================================

CREATE OR ALTER PROCEDURE dbo.sp_validate_json_payloads
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '========================================';
    PRINT 'JSON Payload Validation Report';
    PRINT '========================================';

    -- Basic statistics
    DECLARE @total_rows INT, @avg_quality DECIMAL(5,2), @json_null_count INT;

    SELECT
        @total_rows = COUNT(*),
        @avg_quality = AVG(data_quality_score),
        @json_null_count = COUNT(*) FILTER (WHERE payload_json IS NULL)
    FROM dbo.fact_transactions_location;

    PRINT 'Total fact rows: ' + CAST(@total_rows AS VARCHAR);
    PRINT 'Average quality score: ' + CAST(@avg_quality AS VARCHAR);
    PRINT 'NULL JSON payloads: ' + CAST(@json_null_count AS VARCHAR);

    -- Expected range validation
    IF @total_rows BETWEEN 10000 AND 200000
        PRINT '✅ Row count within expected range (10K-200K)';
    ELSE
        PRINT '⚠️ Row count outside expected range';

    IF @avg_quality >= 70
        PRINT '✅ Average quality score acceptable (≥70)';
    ELSE
        PRINT '⚠️ Low average quality score (<70)';

    -- Store distribution
    PRINT '';
    PRINT 'Store Distribution:';
    SELECT
        store_id,
        municipality_name,
        COUNT(*) as transactions,
        AVG(data_quality_score) as avg_quality,
        SUM(item_count) as total_items,
        SUM(CASE WHEN substitution_detected = 1 THEN 1 ELSE 0 END) as substitutions
    FROM dbo.fact_transactions_location
    WHERE store_id IS NOT NULL
    GROUP BY store_id, municipality_name
    ORDER BY store_id;

    -- JSON structure validation
    PRINT '';
    PRINT 'JSON Structure Validation:';
    SELECT
        'Valid JSON Objects' as metric,
        COUNT(*) FILTER (WHERE ISJSON(payload_json) = 1) as count,
        ROUND((COUNT(*) FILTER (WHERE ISJSON(payload_json) = 1) * 100.0 / COUNT(*)), 1) as percentage
    FROM dbo.fact_transactions_location
    WHERE payload_json IS NOT NULL

    UNION ALL

    SELECT
        'With Basket Items' as metric,
        COUNT(*) FILTER (WHERE JSON_QUERY(payload_json, '$.basket.items') IS NOT NULL) as count,
        ROUND((COUNT(*) FILTER (WHERE JSON_QUERY(payload_json, '$.basket.items') IS NOT NULL) * 100.0 / COUNT(*)), 1) as percentage
    FROM dbo.fact_transactions_location
    WHERE payload_json IS NOT NULL

    UNION ALL

    SELECT
        'With Location Data' as metric,
        COUNT(*) FILTER (WHERE JSON_VALUE(payload_json, '$.location.municipality') IS NOT NULL) as count,
        ROUND((COUNT(*) FILTER (WHERE JSON_VALUE(payload_json, '$.location.municipality') IS NOT NULL) * 100.0 / COUNT(*)), 1) as percentage
    FROM dbo.fact_transactions_location
    WHERE payload_json IS NOT NULL;

    -- Sample JSON payload
    PRINT '';
    PRINT 'Sample JSON Payload:';
    SELECT TOP 1
        canonical_tx_id,
        LEFT(payload_json, 500) + '...' as sample_json
    FROM dbo.fact_transactions_location
    WHERE payload_json IS NOT NULL
    ORDER BY data_quality_score DESC;

    PRINT 'Validation completed.';
END;
GO

-- ==========================================
-- 6. PERFORMANCE INDEXES FOR JSON QUERIES
-- ==========================================

-- Computed columns for common JSON queries
ALTER TABLE dbo.fact_transactions_location
ADD json_store_id AS CAST(JSON_VALUE(payload_json, '$.storeId') AS INT);

ALTER TABLE dbo.fact_transactions_location
ADD json_municipality AS JSON_VALUE(payload_json, '$.location.municipality');

ALTER TABLE dbo.fact_transactions_location
ADD json_substitution_detected AS CAST(JSON_VALUE(payload_json, '$.qualityFlags.substitutionDetected') AS BIT);

-- Indexes on computed columns
CREATE NONCLUSTERED INDEX IX_fact_json_store
    ON dbo.fact_transactions_location (json_store_id);

CREATE NONCLUSTERED INDEX IX_fact_json_municipality
    ON dbo.fact_transactions_location (json_municipality);

CREATE NONCLUSTERED INDEX IX_fact_json_substitution
    ON dbo.fact_transactions_location (json_substitution_detected)
    WHERE json_substitution_detected = 1;
GO

-- ==========================================
-- 7. EXECUTION EXAMPLES AND READY COMMANDS
-- ==========================================

/*
-- Transform staging data to JSON payloads
EXEC dbo.sp_transform_to_json_payloads @clean_fact_table = 1, @batch_size = 1000;

-- Validate the transformation
EXEC dbo.sp_validate_json_payloads;

-- Query examples:
-- 1. Get all transactions for a specific store
SELECT canonical_tx_id, payload_json
FROM dbo.fact_transactions_location
WHERE json_store_id = 103;

-- 2. Find substitution events
SELECT canonical_tx_id, JSON_VALUE(payload_json, '$.location.municipality'), payload_json
FROM dbo.fact_transactions_location
WHERE json_substitution_detected = 1;

-- 3. Geographic analysis
SELECT
    json_municipality,
    COUNT(*) as transactions,
    AVG(total_amount) as avg_amount
FROM dbo.fact_transactions_location
GROUP BY json_municipality;

-- 4. Extract basket items
SELECT
    canonical_tx_id,
    item.value as basket_item
FROM dbo.fact_transactions_location f
CROSS APPLY OPENJSON(f.payload_json, '$.basket.items') as item;
*/

PRINT '========================================';
PRINT 'Scout Edge JSON Payload Builder Complete';
PRINT '========================================';
PRINT 'Ready to execute:';
PRINT '1. EXEC dbo.sp_transform_to_json_payloads;';
PRINT '2. EXEC dbo.sp_validate_json_payloads;';
PRINT '';
PRINT 'Transform raw Scout Edge data into deduplicated JSON payloads! 🚀';
GO