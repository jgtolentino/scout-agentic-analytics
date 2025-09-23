/* ================================================
   AZURE SQL: Scout Edge Fact Transactions Location
   Creates fact_transactions_location with substitution analysis
   Optimized for Azure SQL Database/Server
   ================================================ */

-- Enable JSON support and optimize for large operations
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- Drop existing table if present
IF OBJECT_ID('dbo.fact_transactions_location','U') IS NOT NULL
    DROP TABLE dbo.fact_transactions_location;
GO

-- Create the main fact table
CREATE TABLE dbo.fact_transactions_location (
    -- Primary identifiers
    canonical_tx_id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    transaction_id NVARCHAR(100) NOT NULL,

    -- Device & Store dimensions
    device_id NVARCHAR(50) NOT NULL,
    store_id INT NOT NULL,

    -- Location dimensions (NCR)
    region NVARCHAR(50) DEFAULT 'NCR',
    province_name NVARCHAR(100) DEFAULT 'Metro Manila',
    municipality_name NVARCHAR(100),
    barangay_name NVARCHAR(120),
    geo_latitude DECIMAL(10,8),
    geo_longitude DECIMAL(11,8),
    store_polygon NVARCHAR(MAX),

    -- PSGC codes
    psgc_region CHAR(9),
    psgc_citymun CHAR(9),
    psgc_barangay CHAR(9),

    -- Transaction totals
    total_amount DECIMAL(10,2) NOT NULL,
    total_items INT NOT NULL DEFAULT 0,
    branded_amount DECIMAL(10,2) DEFAULT 0,
    unbranded_amount DECIMAL(10,2) DEFAULT 0,
    branded_count INT DEFAULT 0,
    unbranded_count INT DEFAULT 0,
    unique_brands_count INT DEFAULT 0,

    -- Customer demographics
    age_bracket NVARCHAR(20),
    gender NVARCHAR(10),
    role NVARCHAR(20),

    -- Time dimensions
    weekday_or_weekend NVARCHAR(10),
    time_of_day NVARCHAR(10),
    basket_flag BIT DEFAULT 0,

    -- Substitution analysis
    substitution_occurred BIT DEFAULT 0,
    substitution_from NVARCHAR(100),
    substitution_to NVARCHAR(100),
    substitution_reason NVARCHAR(50) DEFAULT 'unknown',
    brand_switching_score DECIMAL(4,3),

    -- Audio & processing context
    audio_transcript NVARCHAR(MAX),
    processing_duration DECIMAL(6,2),
    payment_method NVARCHAR(20),

    -- Privacy compliance
    audio_stored BIT DEFAULT 0,
    facial_recognition BIT DEFAULT 0,
    anonymization_level NVARCHAR(10) DEFAULT 'high',
    data_retention_days INT DEFAULT 30,
    consent_timestamp DATETIMEOFFSET(0),

    -- Technical metadata
    edge_version NVARCHAR(20),
    processing_methods NVARCHAR(500),
    source_file_path NVARCHAR(500),

    -- Original payload for audit
    payload_json NVARCHAR(MAX),

    -- Timestamps
    txn_ts DATETIMEOFFSET(0),
    processed_at DATETIMEOFFSET(0) DEFAULT SYSDATETIMEOFFSET(),
    created_at DATETIMEOFFSET(0) DEFAULT SYSDATETIMEOFFSET(),
    updated_at DATETIMEOFFSET(0) DEFAULT SYSDATETIMEOFFSET()
);
GO

-- Create performance indexes
CREATE NONCLUSTERED INDEX IX_fact_tx_location_store_id
ON dbo.fact_transactions_location(store_id);

CREATE NONCLUSTERED INDEX IX_fact_tx_location_device_id
ON dbo.fact_transactions_location(device_id);

CREATE NONCLUSTERED INDEX IX_fact_tx_location_municipality
ON dbo.fact_transactions_location(municipality_name);

CREATE NONCLUSTERED INDEX IX_fact_tx_location_substitution
ON dbo.fact_transactions_location(substitution_occurred);

CREATE NONCLUSTERED INDEX IX_fact_tx_location_processed_at
ON dbo.fact_transactions_location(processed_at);

CREATE NONCLUSTERED INDEX IX_fact_tx_location_total_amount
ON dbo.fact_transactions_location(total_amount);

-- Composite indexes for common queries
CREATE NONCLUSTERED INDEX IX_fact_tx_location_store_date
ON dbo.fact_transactions_location(store_id, processed_at);

CREATE NONCLUSTERED INDEX IX_fact_tx_location_municipality_amount
ON dbo.fact_transactions_location(municipality_name, total_amount);

CREATE NONCLUSTERED INDEX IX_fact_tx_location_substitution_analysis
ON dbo.fact_transactions_location(substitution_occurred, substitution_reason, municipality_name);
GO

-- Normalized items table for detailed analysis
CREATE TABLE dbo.fact_transaction_items (
    item_id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    canonical_tx_id UNIQUEIDENTIFIER NOT NULL,

    -- Item details
    brand_name NVARCHAR(100),
    product_name NVARCHAR(200),
    generic_name NVARCHAR(100),
    local_name NVARCHAR(100),
    sku NVARCHAR(50),

    -- Quantities & pricing
    quantity INT NOT NULL DEFAULT 1,
    unit NVARCHAR(10) DEFAULT 'pc',
    unit_price DECIMAL(10,2),
    total_price DECIMAL(10,2),

    -- Categorization
    category NVARCHAR(50),
    subcategory NVARCHAR(50),
    is_unbranded BIT DEFAULT 0,
    is_bulk BIT DEFAULT 0,

    -- Detection analysis
    detection_method NVARCHAR(50),
    confidence DECIMAL(4,3),
    brand_confidence DECIMAL(4,3),

    -- Customer behavior
    customer_request_type NVARCHAR(20),
    specific_brand_requested BIT DEFAULT 0,
    pointed_to_product BIT DEFAULT 0,
    accepted_suggestion BIT DEFAULT 0,

    notes NVARCHAR(500),
    created_at DATETIMEOFFSET(0) DEFAULT SYSDATETIMEOFFSET(),

    -- Foreign key constraint
    CONSTRAINT FK_fact_tx_items_canonical_tx
        FOREIGN KEY (canonical_tx_id)
        REFERENCES dbo.fact_transactions_location(canonical_tx_id)
        ON DELETE CASCADE
);
GO

-- Indexes for items table
CREATE NONCLUSTERED INDEX IX_fact_tx_items_canonical_tx
ON dbo.fact_transaction_items(canonical_tx_id);

CREATE NONCLUSTERED INDEX IX_fact_tx_items_brand
ON dbo.fact_transaction_items(brand_name);

CREATE NONCLUSTERED INDEX IX_fact_tx_items_category
ON dbo.fact_transaction_items(category);

CREATE NONCLUSTERED INDEX IX_fact_tx_items_detection
ON dbo.fact_transaction_items(detection_method);
GO

-- NCR store dimension table
CREATE TABLE dbo.dim_ncr_stores (
    store_id INT PRIMARY KEY,
    store_name NVARCHAR(200),
    municipality_name NVARCHAR(100) NOT NULL,
    barangay_name NVARCHAR(120),
    region NVARCHAR(50) DEFAULT 'NCR',
    province_name NVARCHAR(100) DEFAULT 'Metro Manila',
    geo_latitude DECIMAL(10,8),
    geo_longitude DECIMAL(11,8),
    psgc_region CHAR(9),
    psgc_citymun CHAR(9),
    psgc_barangay CHAR(9),
    store_polygon NVARCHAR(MAX),
    is_active BIT DEFAULT 1,
    created_at DATETIMEOFFSET(0) DEFAULT SYSDATETIMEOFFSET(),
    updated_at DATETIMEOFFSET(0) DEFAULT SYSDATETIMEOFFSET()
);
GO

-- Initialize NCR store mappings
INSERT INTO dbo.dim_ncr_stores (store_id, municipality_name) VALUES
(102, 'Manila'),
(103, 'Quezon City'),
(104, 'Makati'),
(108, 'Pasig'),
(109, 'Mandaluyong'),
(110, N'Parañaque'),
(112, 'Taguig');
GO

-- Function to generate canonical transaction ID
CREATE FUNCTION dbo.fn_generate_canonical_tx_id(
    @store_id NVARCHAR(10),
    @timestamp DATETIMEOFFSET,
    @amount DECIMAL(10,2),
    @device_id NVARCHAR(50)
)
RETURNS UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @hash_input NVARCHAR(500);
    DECLARE @hash_bytes VARBINARY(16);

    SET @hash_input = ISNULL(@store_id, '') + '|' +
                      ISNULL(CONVERT(NVARCHAR(50), @timestamp, 127), '') + '|' +
                      ISNULL(CONVERT(NVARCHAR(20), @amount), '') + '|' +
                      ISNULL(@device_id, '');

    SET @hash_bytes = CONVERT(VARBINARY(16), HASHBYTES('MD5', @hash_input));

    RETURN CONVERT(UNIQUEIDENTIFIER, @hash_bytes);
END;
GO

-- Function to detect substitution events
CREATE FUNCTION dbo.fn_detect_substitution_event(
    @transcript NVARCHAR(MAX),
    @purchased_brand NVARCHAR(100)
)
RETURNS TABLE
AS
RETURN (
    SELECT
        CASE
            WHEN LEN(ISNULL(@transcript, '')) > 0
                AND @purchased_brand IS NOT NULL
                AND CHARINDEX(LOWER(@purchased_brand), LOWER(@transcript)) = 0
            THEN CAST(1 AS BIT)
            ELSE CAST(0 AS BIT)
        END AS is_substitution,
        CASE
            WHEN LEN(ISNULL(@transcript, '')) > 0
                AND @purchased_brand IS NOT NULL
                AND CHARINDEX(LOWER(@purchased_brand), LOWER(@transcript)) = 0
            THEN 'Brand not mentioned in transcript'
            ELSE NULL
        END AS substitution_reason,
        CASE
            WHEN LEN(ISNULL(@transcript, '')) > 50 THEN 0.900
            WHEN LEN(ISNULL(@transcript, '')) > 20 THEN 0.700
            WHEN LEN(ISNULL(@transcript, '')) > 0 THEN 0.500
            ELSE 0.000
        END AS brand_switching_score
);
GO

-- Main ETL procedure to populate fact table from payload transactions
CREATE PROCEDURE dbo.sp_populate_fact_transactions_location
AS
BEGIN
    SET NOCOUNT ON;

    -- Clear existing data
    TRUNCATE TABLE dbo.fact_transaction_items;
    DELETE FROM dbo.fact_transactions_location;

    -- Base JSON items per transaction (for purchased brand & basket)
    WITH items AS (
        SELECT
            pt.transactionId,
            TRY_CONVERT(INT, JSON_VALUE(j.value, '$.quantity')) AS qty,
            NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(j.value,'$.brand'), JSON_VALUE(j.value,'$.brandName')))),'') AS brand,
            JSON_VALUE(j.value,'$.productName') AS product_name,
            JSON_VALUE(j.value,'$.category') AS category,
            TRY_CONVERT(DECIMAL(10,2), JSON_VALUE(j.value,'$.unitPrice')) AS unit_price,
            TRY_CONVERT(DECIMAL(10,2), JSON_VALUE(j.value,'$.totalPrice')) AS total_price
        FROM dbo.PayloadTransactions pt
        CROSS APPLY OPENJSON(pt.payload_json, '$.items') AS j
    ),
    purchased AS (  -- choose main purchased brand
        SELECT transactionId, brand, qty,
               ROW_NUMBER() OVER (
                   PARTITION BY transactionId
                   ORDER BY CASE WHEN qty IS NULL THEN 1 ELSE 0 END, qty DESC
               ) AS rn
        FROM items
        WHERE brand IS NOT NULL
    ),
    purchased_main AS (
        SELECT transactionId, brand AS purchased_brand
        FROM purchased
        WHERE rn = 1
    ),
    basket AS (  -- basket/co-purchase flag
        SELECT transactionId, COUNT(*) AS line_count
        FROM items
        GROUP BY transactionId
    ),

    -- Requested brand & timestamp from transcripts
    requested_raw AS (
        SELECT
            t.transactionId,
            NULLIF(LTRIM(RTRIM(t.DetectedBrand)),'') AS requested_brand,
            TRY_CONVERT(DATETIMEOFFSET(0), COALESCE(t.CreatedOn, t.InteractionStartTime, t.EventTime)) AS ts_candidate
        FROM dbo.SalesInteractionTranscripts t
        WHERE t.DetectedBrand IS NOT NULL
    ),
    requested_main AS (      -- earliest brand mention per transaction
        SELECT transactionId, requested_brand,
               ROW_NUMBER() OVER (PARTITION BY transactionId ORDER BY ts_candidate) AS rn
        FROM requested_raw
    ),
    req_one AS (
        SELECT transactionId, requested_brand
        FROM requested_main WHERE rn = 1
    ),
    txn_ts AS (              -- earliest transcript timestamp per transaction
        SELECT transactionId,
               MIN(ts_candidate) AS txn_ts
        FROM requested_raw
        GROUP BY transactionId
    ),
    reason_raw AS (          -- heuristic reason classifier
        SELECT
            t.transactionId,
            CASE
                WHEN t.TranscriptText LIKE '%wala%' OR t.TranscriptText LIKE '%ubos%'
                    OR t.TranscriptText LIKE '%out of stock%' OR t.TranscriptText LIKE '%no stock%' THEN 'stockout'
                WHEN t.TranscriptText LIKE '%suggest%' OR t.TranscriptText LIKE '%ibang brand%'
                    OR t.TranscriptText LIKE '%pwede na ito%' OR t.TranscriptText LIKE '%alternative%' THEN 'suggestion'
                ELSE 'unknown'
            END AS reason,
            TRY_CONVERT(DATETIMEOFFSET(0), COALESCE(t.CreatedOn, t.InteractionStartTime, t.EventTime)) AS ts_candidate
        FROM dbo.SalesInteractionTranscripts t
    ),
    reason_main AS (
        SELECT transactionId, reason
        FROM (
            SELECT transactionId, reason,
                   ROW_NUMBER() OVER (PARTITION BY transactionId ORDER BY ts_candidate) AS rn
            FROM reason_raw
        ) x
        WHERE rn = 1
    ),

    -- Demographics (first seen per transaction)
    demo_raw AS (
        SELECT
            t.transactionId,
            NULLIF(LTRIM(RTRIM(COALESCE(t.AgeBracket, t.Age))),'') AS AgeBracket,
            NULLIF(LTRIM(RTRIM(t.Gender)),'') AS Gender,
            NULLIF(LTRIM(RTRIM(t.Role)),'') AS Role,
            TRY_CONVERT(DATETIMEOFFSET(0), COALESCE(t.CreatedOn, t.InteractionStartTime, t.EventTime)) AS ts_candidate
        FROM dbo.SalesInteractionTranscripts t
    ),
    demo_one AS (
        SELECT transactionId, AgeBracket, Gender, Role
        FROM (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY transactionId ORDER BY ts_candidate) AS rn
            FROM demo_raw
        ) x
        WHERE rn = 1
    ),

    -- Assemble substitution decision
    sub_event AS (
        SELECT
            tx.transactionId,
            rq.requested_brand,
            pm.purchased_brand,
            CASE
                WHEN rq.requested_brand IS NULL OR pm.purchased_brand IS NULL THEN CAST(0 AS BIT)
                WHEN UPPER(rq.requested_brand) = UPPER(pm.purchased_brand) THEN CAST(0 AS BIT)
                ELSE CAST(1 AS BIT)
            END AS substitution_occurred,
            COALESCE(rm.reason,'unknown') AS substitution_reason
        FROM (SELECT DISTINCT transactionId FROM dbo.PayloadTransactions) tx
        LEFT JOIN req_one        rq ON rq.transactionId = tx.transactionId
        LEFT JOIN purchased_main pm ON pm.transactionId = tx.transactionId
        LEFT JOIN reason_main    rm ON rm.transactionId = tx.transactionId
    ),

    -- Time dims from interaction timestamp
    time_dims AS (
        SELECT
            t.transactionId,
            t.txn_ts,
            CASE WHEN DATEPART(weekday, t.txn_ts) IN (1,7)
                 THEN 'Weekend' ELSE 'Weekday' END AS WeekdayOrWeekend,
            RIGHT('0' + CONVERT(VARCHAR(2), DATEPART(HOUR, t.txn_ts) % 12
                   + CASE WHEN DATEPART(HOUR, t.txn_ts) % 12 = 0 THEN 12 ELSE 0 END), 2)
              + CASE WHEN DATEPART(HOUR, t.txn_ts) < 12 THEN 'AM' ELSE 'PM' END AS TimeOfDay
        FROM txn_ts t
    ),

    -- Extract totals from JSON payload
    payload_totals AS (
        SELECT
            pt.transactionId,
            TRY_CONVERT(DECIMAL(10,2), JSON_VALUE(pt.payload_json, '$.totals.totalAmount')) AS total_amount,
            TRY_CONVERT(INT, JSON_VALUE(pt.payload_json, '$.totals.totalItems')) AS total_items,
            TRY_CONVERT(DECIMAL(10,2), JSON_VALUE(pt.payload_json, '$.totals.brandedAmount')) AS branded_amount,
            TRY_CONVERT(DECIMAL(10,2), JSON_VALUE(pt.payload_json, '$.totals.unbrandedAmount')) AS unbranded_amount,
            TRY_CONVERT(INT, JSON_VALUE(pt.payload_json, '$.totals.brandedCount')) AS branded_count,
            TRY_CONVERT(INT, JSON_VALUE(pt.payload_json, '$.totals.unbrandedCount')) AS unbranded_count,
            TRY_CONVERT(INT, JSON_VALUE(pt.payload_json, '$.totals.uniqueBrandsCount')) AS unique_brands_count,
            JSON_VALUE(pt.payload_json, '$.transactionContext.audioTranscript') AS audio_transcript,
            TRY_CONVERT(DECIMAL(6,2), JSON_VALUE(pt.payload_json, '$.processingTime')) AS processing_duration,
            JSON_VALUE(pt.payload_json, '$.transactionContext.paymentMethod') AS payment_method,
            JSON_VALUE(pt.payload_json, '$.edgeVersion') AS edge_version,
            TRY_CONVERT(BIT, JSON_VALUE(pt.payload_json, '$.privacy.audioStored')) AS audio_stored,
            CASE WHEN JSON_VALUE(pt.payload_json, '$.privacy.noFacialRecognition') = 'true' THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END AS facial_recognition,
            JSON_VALUE(pt.payload_json, '$.privacy.anonymizationLevel') AS anonymization_level,
            TRY_CONVERT(INT, JSON_VALUE(pt.payload_json, '$.privacy.dataRetentionDays')) AS data_retention_days,
            TRY_CONVERT(DATETIMEOFFSET, JSON_VALUE(pt.payload_json, '$.privacy.consentTimestamp')) AS consent_timestamp
        FROM dbo.PayloadTransactions pt
    )

    -- Main INSERT
    INSERT INTO dbo.fact_transactions_location (
        canonical_tx_id, transaction_id, device_id, store_id,
        region, province_name, municipality_name, barangay_name,
        geo_latitude, geo_longitude, store_polygon,
        psgc_region, psgc_citymun, psgc_barangay,
        total_amount, total_items, branded_amount, unbranded_amount,
        branded_count, unbranded_count, unique_brands_count,
        age_bracket, gender, role,
        weekday_or_weekend, time_of_day, basket_flag,
        substitution_occurred, substitution_from, substitution_to, substitution_reason,
        brand_switching_score,
        audio_transcript, processing_duration, payment_method,
        audio_stored, facial_recognition, anonymization_level,
        data_retention_days, consent_timestamp,
        edge_version, payload_json, source_path, txn_ts
    )
    SELECT
        dbo.fn_generate_canonical_tx_id(CONVERT(NVARCHAR(10), pt.storeId), td.txn_ts, ISNULL(ptt.total_amount, 0), pt.deviceId),
        pt.transactionId,
        pt.deviceId,
        pt.storeId,
        s.Region, s.ProvinceName, s.MunicipalityName, s.BarangayName,
        s.GeoLatitude, s.GeoLongitude, s.StorePolygon,
        s.psgc_region, s.psgc_citymun, s.psgc_barangay,
        ISNULL(ptt.total_amount, 0),
        ISNULL(ptt.total_items, 0),
        ISNULL(ptt.branded_amount, 0),
        ISNULL(ptt.unbranded_amount, 0),
        ISNULL(ptt.branded_count, 0),
        ISNULL(ptt.unbranded_count, 0),
        ISNULL(ptt.unique_brands_count, 0),
        d.AgeBracket, d.Gender, d.Role,
        td.WeekdayOrWeekend, td.TimeOfDay,
        CAST(CASE WHEN ISNULL(b.line_count, 0) > 1 THEN 1 ELSE 0 END AS BIT),
        se.substitution_occurred,
        se.requested_brand,
        se.purchased_brand,
        se.substitution_reason,
        -- Calculate brand switching score
        CASE
            WHEN se.substitution_occurred = 1 AND LEN(ISNULL(ptt.audio_transcript, '')) > 50 THEN 0.900
            WHEN se.substitution_occurred = 1 AND LEN(ISNULL(ptt.audio_transcript, '')) > 20 THEN 0.700
            WHEN se.substitution_occurred = 1 AND LEN(ISNULL(ptt.audio_transcript, '')) > 0 THEN 0.500
            ELSE NULL
        END,
        ptt.audio_transcript,
        ptt.processing_duration,
        ptt.payment_method,
        ISNULL(ptt.audio_stored, 0),
        ISNULL(ptt.facial_recognition, 0),
        ISNULL(ptt.anonymization_level, 'high'),
        ISNULL(ptt.data_retention_days, 30),
        ptt.consent_timestamp,
        ptt.edge_version,
        pt.payload_json,
        pt.source_path,
        td.txn_ts
    FROM dbo.PayloadTransactions pt
    LEFT JOIN demo_one      d   ON d.transactionId  = pt.transactionId
    LEFT JOIN time_dims     td  ON td.transactionId = pt.transactionId
    LEFT JOIN basket        b   ON b.transactionId  = pt.transactionId
    LEFT JOIN sub_event     se  ON se.transactionId = pt.transactionId
    LEFT JOIN dbo.Stores    s   ON s.StoreID        = pt.storeId
    LEFT JOIN payload_totals ptt ON ptt.transactionId = pt.transactionId
    WHERE
        -- enforce location rule
        s.MunicipalityName IS NOT NULL
        AND ( s.StorePolygon IS NOT NULL
              OR (s.GeoLatitude IS NOT NULL AND s.GeoLongitude IS NOT NULL) );

    -- Insert item details
    INSERT INTO dbo.fact_transaction_items (
        canonical_tx_id, brand_name, product_name, category,
        quantity, unit_price, total_price
    )
    SELECT
        ft.canonical_tx_id,
        i.brand,
        i.product_name,
        i.category,
        ISNULL(i.qty, 1),
        i.unit_price,
        i.total_price
    FROM items i
    JOIN dbo.fact_transactions_location ft ON ft.transaction_id = i.transactionId;

    PRINT 'Fact table population completed';
    PRINT 'Rows inserted: ' + CONVERT(VARCHAR(10), @@ROWCOUNT);
END;
GO

-- Comments for documentation
EXEC sys.sp_addextendedproperty
    @name=N'MS_Description',
    @value=N'Scout Edge transactions with NCR location enrichment and substitution analysis - Azure SQL optimized',
    @level0type=N'SCHEMA', @level0name=N'dbo',
    @level1type=N'TABLE', @level1name=N'fact_transactions_location';

EXEC sys.sp_addextendedproperty
    @name=N'MS_Description',
    @value=N'Individual items purchased in Scout Edge transactions',
    @level0type=N'SCHEMA', @level0name=N'dbo',
    @level1type=N'TABLE', @level1name=N'fact_transaction_items';

EXEC sys.sp_addextendedproperty
    @name=N'MS_Description',
    @value=N'NCR store locations and geographic boundaries',
    @level0type=N'SCHEMA', @level0name=N'dbo',
    @level1type=N'TABLE', @level1name=N'dim_ncr_stores';
GO

PRINT 'Azure SQL Scout Edge fact table schema created successfully';
PRINT 'Run: EXEC dbo.sp_populate_fact_transactions_location to load data';
GO