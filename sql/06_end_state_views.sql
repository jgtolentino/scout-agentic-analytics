-- File: sql/06_end_state_views.sql
-- End-state production views: JSON-safe, canonical joins, SI timestamp authority
-- Purpose: Complete Scout analytics views with DB-driven device mapping

GO
CREATE OR ALTER VIEW dbo.v_transactions_flat_production
AS
WITH f AS (
  SELECT
    -- Canonical ID from payload JSON if valid else sessionId (normalized, hyphens removed, lower)
    LOWER(REPLACE(COALESCE(
      CASE WHEN ISJSON(pt.payload_json)=1 THEN JSON_VALUE(pt.payload_json,'$.transactionId') END,
      pt.sessionId
    ),'-',''))                                    AS canonical_tx_id,

    CAST(pt.sessionId AS varchar(64))             AS transaction_id,
    CAST(pt.deviceId  AS varchar(64))             AS device_id,

    -- Resolve store via DB mapping first, else payload storeId
    COALESCE(
      CAST(dm.StoreID AS int),
      TRY_CAST(pt.storeId AS int)
    )                                             AS store_id,

    -- Prefer real Stores name if present
    COALESCE(s.StoreName, CONCAT(N'Store_', TRY_CAST(pt.storeId AS int))) AS store_name,

    -- Business fields from payload (guarded)
    CASE WHEN ISJSON(pt.payload_json)=1 THEN JSON_VALUE(pt.payload_json,'$.items[0].brandName') END     AS brand,
    CASE WHEN ISJSON(pt.payload_json)=1 THEN JSON_VALUE(pt.payload_json,'$.items[0].productName') END   AS product_name,
    CASE WHEN ISJSON(pt.payload_json)=1 THEN JSON_VALUE(pt.payload_json,'$.items[0].category') END      AS category,
    CASE WHEN ISJSON(pt.payload_json)=1 THEN TRY_CONVERT(decimal(12,2), JSON_VALUE(pt.payload_json,'$.totals.totalAmount')) END AS total_amount,
    CASE WHEN ISJSON(pt.payload_json)=1 THEN TRY_CONVERT(int,           JSON_VALUE(pt.payload_json,'$.totals.totalItems')) END  AS total_items,
    CASE WHEN ISJSON(pt.payload_json)=1 THEN JSON_VALUE(pt.payload_json,'$.transactionContext.paymentMethod') END               AS payment_method,
    CASE WHEN ISJSON(pt.payload_json)=1 THEN JSON_VALUE(pt.payload_json,'$.transactionContext.audioTranscript') END             AS audio_transcript
  FROM dbo.PayloadTransactions AS pt
  OUTER APPLY (
      SELECT TOP 1 dsm.StoreID
      FROM dbo.DeviceStoreMap dsm
      WHERE dsm.DeviceID = pt.deviceId AND dsm.EffectiveTo IS NULL
  ) AS dm
  LEFT JOIN dbo.Stores AS s
    ON s.StoreID = COALESCE(TRY_CAST(dm.StoreID AS int), TRY_CAST(pt.storeId AS int))
),
si AS (
  SELECT
    LOWER(REPLACE(CAST(InteractionID AS varchar(64)),'-','')) AS canonical_tx_id,
    CAST(TransactionDate AS datetime2(0))                    AS txn_ts
  FROM dbo.SalesInteractions
)
SELECT
  f.canonical_tx_id,
  f.transaction_id,
  f.device_id,
  f.store_id,
  f.store_name,
  f.brand,
  f.product_name,
  f.category,
  f.total_amount,
  f.total_items,
  f.payment_method,
  -- authoritative timestamp ONLY from SalesInteractions
  si.txn_ts,
  CONVERT(date, si.txn_ts) AS transaction_date,
  CASE WHEN si.txn_ts IS NULL THEN NULL
       WHEN DATEPART(HOUR, si.txn_ts) BETWEEN 6  AND 11 THEN 'Morning'
       WHEN DATEPART(HOUR, si.txn_ts) BETWEEN 12 AND 17 THEN 'Afternoon'
       WHEN DATEPART(HOUR, si.txn_ts) BETWEEN 18 AND 21 THEN 'Evening'
       ELSE 'Night' END AS daypart,
  CASE WHEN si.txn_ts IS NULL THEN NULL
       WHEN DATEPART(WEEKDAY, si.txn_ts) IN (1,7) THEN 'Weekend' ELSE 'Weekday' END AS weekday_weekend,
  -- audio transcript (exposed for dashboard use)
  f.audio_transcript
FROM f
LEFT JOIN si ON si.canonical_tx_id = f.canonical_tx_id;
GO

-- Crosstab production (v10; long form)
CREATE OR ALTER VIEW dbo.v_transactions_crosstab_production
AS
SELECT
  CONVERT(date, txn_ts)              AS [date],
  store_id,
  store_name,
  daypart,
  ISNULL(brand,'Unknown')            AS brand,
  COUNT(*)                           AS txn_count,
  SUM(COALESCE(total_amount,0))      AS total_amount,
  CAST(AVG(CAST(NULLIF(total_items,0) AS float)) AS decimal(12,2)) AS avg_basket_amount,
  0                                  AS substitution_events  -- placeholder until you wire events
FROM dbo.v_transactions_flat_production
WHERE txn_ts IS NOT NULL
GROUP BY CONVERT(date, txn_ts), store_id, store_name, daypart, ISNULL(brand,'Unknown');
GO

-- v24 compatibility adapter (24 columns; stable)
CREATE OR ALTER VIEW dbo.v_transactions_flat_v24
AS
SELECT
  -- Contract IDs
  CAST(transaction_id AS varchar(64))                 AS TransactionID,
  CAST(canonical_tx_id AS varchar(64))                AS CanonicalTxID,

  -- Device/Store
  CAST(device_id AS varchar(64))                      AS DeviceID,
  CAST(store_id  AS int)                              AS StoreID,
  CAST(store_name AS nvarchar(200))                   AS StoreName,

  -- Location contract (kept nullable; fill when you enrich)
  CAST(NULL AS varchar(8))                            AS Region,
  CAST(NULL AS nvarchar(50))                          AS ProvinceName,
  CAST(NULL AS nvarchar(80))                          AS MunicipalityName,
  CAST(NULL AS nvarchar(120))                         AS BarangayName,
  CAST(NULL AS char(9))                               AS psgc_region,
  CAST(NULL AS char(9))                               AS psgc_citymun,
  CAST(NULL AS char(9))                               AS psgc_barangay,
  CAST(NULL AS float)                                 AS GeoLatitude,
  CAST(NULL AS float)                                 AS GeoLongitude,
  CAST(NULL AS nvarchar(max))                         AS StorePolygon,

  -- Basket
  CAST(total_amount AS decimal(12,2))                 AS Amount,
  CAST(total_items  AS int)                           AS Basket_Item_Count,
  CAST(weekday_weekend AS varchar(8))                 AS WeekdayOrWeekend,
  CAST(daypart AS varchar(10))                        AS TimeOfDay,
  CAST(NULL AS bit)                                   AS BasketFlag,
  CAST(NULL AS nvarchar(50))                          AS AgeBracket,
  CAST(NULL AS nvarchar(20))                          AS Gender,
  CAST(NULL AS nvarchar(50))                          AS Role,
  CAST(NULL AS bit)                                   AS Substitution_Flag,

  -- Timestamp
  CAST(txn_ts AS datetime2(0))                        AS Txn_TS
FROM dbo.v_transactions_flat_production;
GO