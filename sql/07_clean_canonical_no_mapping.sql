-- Clean Canonical Transaction ID System
-- NO device mapping references - only use correct data from SalesInteractions
-- Completely ignore wrong device IDs from PayloadTransactions

-- Drop existing views
DROP VIEW IF EXISTS dbo.v_transactions_flat_production;
DROP VIEW IF EXISTS dbo.v_transactions_crosstab_production;
DROP VIEW IF EXISTS dbo.v_device_mapping;
GO

-- Add canonical_tx_id computed column to PayloadTransactions
IF COL_LENGTH('dbo.PayloadTransactions', 'canonical_tx_id') IS NULL
BEGIN
    ALTER TABLE dbo.PayloadTransactions
    ADD canonical_tx_id AS (
        LEFT(CASE
            WHEN ISJSON(payload_json) = 1
            THEN LOWER(REPLACE(JSON_VALUE(payload_json, '$.transactionId'), '-', ''))
            ELSE LOWER(REPLACE(sessionId, '-', ''))
        END, 32)
    ) PERSISTED;

    CREATE INDEX IX_PayloadTransactions_canonical_tx_id
    ON dbo.PayloadTransactions (canonical_tx_id);
END
GO

-- Add canonical_tx_id computed column to SalesInteractions
IF COL_LENGTH('dbo.SalesInteractions', 'canonical_tx_id') IS NULL
BEGIN
    ALTER TABLE dbo.SalesInteractions
    ADD canonical_tx_id AS (LEFT(LOWER(REPLACE(InteractionID, '-', '')), 32)) PERSISTED;

    CREATE INDEX IX_SalesInteractions_canonical_tx_id
    ON dbo.SalesInteractions (canonical_tx_id);
END
GO

-- Clean view using ONLY SalesInteractions for device info (authoritative source)
-- PayloadTransactions device info is IGNORED completely
CREATE OR ALTER VIEW dbo.v_transactions_flat_production AS
SELECT
    -- Single canonical transaction ID
    pt.canonical_tx_id,

    -- Original transaction IDs for reference
    CASE WHEN ISJSON(pt.payload_json) = 1
        THEN JSON_VALUE(pt.payload_json, '$.transactionId')
        ELSE pt.sessionId END AS original_tx_id,
    si.InteractionID AS sales_interaction_id,

    -- Store and device info ONLY from SalesInteractions (authoritative)
    si.StoreID AS storeId,
    si.DeviceID AS device_id,  -- ONLY correct device ID from SalesInteractions

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

    -- Store location data (not available in SalesInteractions)
    CAST(NULL AS NVARCHAR(100)) AS StoreName,
    CAST(NULL AS NVARCHAR(100)) AS Region,
    CAST(NULL AS NVARCHAR(100)) AS ProvinceName,
    CAST(NULL AS NVARCHAR(100)) AS MunicipalityName,
    CAST(NULL AS NVARCHAR(100)) AS BarangayName,
    CAST(NULL AS DECIMAL(10,6)) AS GeoLatitude,
    CAST(NULL AS DECIMAL(10,6)) AS GeoLongitude,

    -- Match status
    CASE WHEN si.InteractionID IS NOT NULL THEN 'MATCHED' ELSE 'UNMATCHED' END AS match_status

FROM dbo.PayloadTransactions pt
LEFT JOIN dbo.SalesInteractions si ON pt.canonical_tx_id = si.canonical_tx_id;
GO

-- Clean crosstab view
CREATE OR ALTER VIEW dbo.v_transactions_crosstab_production AS
SELECT
    CAST(txn_ts AS DATE) as [date],
    storeId as store_id,
    'Store ' + CAST(storeId AS VARCHAR(10)) as store_name,
    'Unknown' as municipality_name,
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
    CASE
        WHEN DATEPART(HOUR, txn_ts) BETWEEN 6 AND 11 THEN 'Morning'
        WHEN DATEPART(HOUR, txn_ts) BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN DATEPART(HOUR, txn_ts) BETWEEN 18 AND 23 THEN 'Evening'
        ELSE 'Night'
    END,
    COALESCE(brand, 'Unknown');
GO

PRINT 'Clean canonical system created - NO device mapping references';
PRINT 'Uses ONLY correct data from SalesInteractions for device info';
PRINT 'PayloadTransactions device info completely ignored';