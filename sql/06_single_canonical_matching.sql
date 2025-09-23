-- Single Canonical Transaction ID Matching System
-- Uses only transaction IDs, ignores payload timestamps (intentionally removed)

-- Drop existing views to recreate with single canonical ID
DROP VIEW IF EXISTS dbo.v_transactions_flat_production;
DROP VIEW IF EXISTS dbo.v_transactions_crosstab_production;
GO

-- Add canonical_tx_id computed column to PayloadTransactions
IF COL_LENGTH('dbo.PayloadTransactions', 'canonical_tx_id') IS NULL
BEGIN
    ALTER TABLE dbo.PayloadTransactions
    ADD canonical_tx_id AS (
        CASE
            WHEN ISJSON(payload_json) = 1
            THEN LOWER(REPLACE(JSON_VALUE(payload_json, '$.transactionId'), '-', ''))
            ELSE LOWER(REPLACE(sessionId, '-', ''))
        END
    ) PERSISTED;

    CREATE INDEX IX_PayloadTransactions_canonical_tx_id
    ON dbo.PayloadTransactions (canonical_tx_id);
END
GO

-- Add canonical_tx_id computed column to SalesInteractions
IF COL_LENGTH('dbo.SalesInteractions', 'canonical_tx_id') IS NULL
BEGIN
    ALTER TABLE dbo.SalesInteractions
    ADD canonical_tx_id AS (LOWER(REPLACE(InteractionID, '-', ''))) PERSISTED;

    CREATE INDEX IX_SalesInteractions_canonical_tx_id
    ON dbo.SalesInteractions (canonical_tx_id);
END
GO

-- Corrected device mapping table
CREATE OR ALTER VIEW dbo.v_device_mapping AS
SELECT
    storeId,
    deviceId AS payload_device,
    CASE
        WHEN storeId = 108 AND deviceId = 'SCOUTPI-0006' THEN '8'
        WHEN storeId = 102 AND deviceId = 'SCOUTPI-0002' THEN '2'
        WHEN storeId = 103 AND deviceId = 'SCOUTPI-0003' THEN '3'
        WHEN storeId = 104 AND deviceId = 'SCOUTPI-0004' THEN '4'
        WHEN storeId = 109 AND deviceId = 'SCOUTPI-0009' THEN '9'
        WHEN storeId = 110 AND deviceId = 'SCOUTPI-0010' THEN '10'
        WHEN storeId = 112 AND deviceId = 'SCOUTPI-0012' THEN '12'
        ELSE deviceId
    END AS correct_device
FROM (
    SELECT DISTINCT storeId, deviceId
    FROM dbo.PayloadTransactions
    WHERE storeId IS NOT NULL AND deviceId IS NOT NULL
) AS devices;
GO

-- Single canonical transaction ID view with corrected device mapping
CREATE OR ALTER VIEW dbo.v_transactions_flat_production AS
SELECT
    -- Single canonical transaction ID (primary key)
    pt.canonical_tx_id,

    -- Original IDs for reference
    CASE WHEN ISJSON(pt.payload_json) = 1
        THEN JSON_VALUE(pt.payload_json, '$.transactionId')
        ELSE pt.sessionId END AS original_tx_id,
    si.InteractionID AS sales_interaction_id,

    -- Store and device info with corrections
    pt.storeId,
    pt.deviceId AS payload_device_id,
    dm.correct_device AS corrected_device_id,
    si.DeviceID AS sales_device_id,

    -- Authoritative timestamp (ONLY from SalesInteractions)
    si.TransactionDate AS txn_ts,

    -- Business intelligence from JSON payload
    CASE WHEN ISJSON(pt.payload_json) = 1
        THEN JSON_VALUE(pt.payload_json, '$.items[0].brandName')
        ELSE NULL END AS brand,
    CASE WHEN ISJSON(pt.payload_json) = 1
        THEN JSON_VALUE(pt.payload_json, '$.items[0].productName')
        ELSE NULL END AS product_name,
    CASE WHEN ISJSON(pt.payload_json) = 1
        THEN JSON_VALUE(pt.payload_json, '$.items[0].category')
        ELSE NULL END AS category,
    CASE WHEN ISJSON(pt.payload_json) = 1
        THEN CAST(JSON_VALUE(pt.payload_json, '$.items[0].totalPrice') AS DECIMAL(10,2))
        ELSE NULL END AS total_amount,
    CASE WHEN ISJSON(pt.payload_json) = 1
        THEN JSON_VALUE(pt.payload_json, '$.items[0].quantity')
        ELSE NULL END AS total_items,
    CASE WHEN ISJSON(pt.payload_json) = 1
        THEN JSON_VALUE(pt.payload_json, '$.paymentMethod')
        ELSE NULL END AS payment_method,
    CASE WHEN ISJSON(pt.payload_json) = 1
        THEN JSON_VALUE(pt.payload_json, '$.audioTranscript')
        ELSE NULL END AS audio_transcript,

    -- Store location data
    si.StoreName,
    si.Region,
    si.ProvinceName,
    si.MunicipalityName,
    si.BarangayName,
    si.GeoLatitude,
    si.GeoLongitude,

    -- Match status for debugging
    CASE WHEN si.InteractionID IS NOT NULL THEN 'MATCHED' ELSE 'UNMATCHED' END AS match_status

FROM dbo.PayloadTransactions pt
LEFT JOIN dbo.v_device_mapping dm ON pt.storeId = dm.storeId AND pt.deviceId = dm.payload_device
LEFT JOIN dbo.SalesInteractions si ON pt.canonical_tx_id = si.canonical_tx_id
    AND pt.storeId = si.StoreID
    AND dm.correct_device = CAST(si.DeviceID AS VARCHAR(20));
GO

-- Crosstab view with single canonical ID
CREATE OR ALTER VIEW dbo.v_transactions_crosstab_production AS
SELECT
    CAST(txn_ts AS DATE) as [date],
    storeId as store_id,
    StoreName as store_name,
    MunicipalityName as municipality_name,
    CASE
        WHEN DATEPART(HOUR, txn_ts) BETWEEN 6 AND 11 THEN 'Morning'
        WHEN DATEPART(HOUR, txn_ts) BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN DATEPART(HOUR, txn_ts) BETWEEN 18 AND 23 THEN 'Evening'
        ELSE 'Night'
    END as daypart,
    COALESCE(brand, 'Unknown') as brand,
    COUNT(*) as txn_count,
    SUM(COALESCE(total_amount, 0)) as total_amount,
    AVG(COALESCE(total_amount, 0)) as avg_basket_amount,
    COUNT(CASE WHEN audio_transcript IS NOT NULL THEN 1 END) as substitution_events
FROM dbo.v_transactions_flat_production
WHERE txn_ts IS NOT NULL  -- Only timestamped transactions
GROUP BY
    CAST(txn_ts AS DATE),
    storeId,
    StoreName,
    MunicipalityName,
    CASE
        WHEN DATEPART(HOUR, txn_ts) BETWEEN 6 AND 11 THEN 'Morning'
        WHEN DATEPART(HOUR, txn_ts) BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN DATEPART(HOUR, txn_ts) BETWEEN 18 AND 23 THEN 'Evening'
        ELSE 'Night'
    END,
    COALESCE(brand, 'Unknown');
GO

PRINT 'Single canonical transaction ID system created successfully';
PRINT 'Uses only transaction IDs for matching, ignores payload timestamps';
PRINT 'Corrects device ID mappings for all stores';