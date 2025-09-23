-- Get ALL 12K PayloadTransactions records - ditch payload timestamp, use LEFT JOIN
CREATE OR ALTER VIEW dbo.v_transactions_flat_production
AS
SELECT
  -- IDs / store - using canonical transaction ID from payload_json
  JSON_VALUE(pt.payload_json, '$.transactionId') AS canonical_tx_id,
  JSON_VALUE(pt.payload_json, '$.transactionId') AS transaction_id,
  CAST(pt.deviceId AS varchar(64))               AS device_id,
  CAST(pt.storeId AS int)                        AS store_id,
  CONCAT(N'Store_', pt.storeId)                  AS store_name,

  -- Geo/demographics (not modeled here yet)
  CAST(NULL AS varchar(8))                       AS Region,
  CAST(NULL AS nvarchar(50))                     AS ProvinceName,
  CAST(NULL AS nvarchar(80))                     AS MunicipalityName,
  CAST(NULL AS nvarchar(120))                    AS BarangayName,
  CAST(NULL AS char(9))                          AS psgc_region,
  CAST(NULL AS char(9))                          AS psgc_citymun,
  CAST(NULL AS char(9))                          AS psgc_barangay,
  CAST(NULL AS float)                            AS GeoLatitude,
  CAST(NULL AS float)                            AS GeoLongitude,
  CAST(NULL AS nvarchar(max))                    AS StorePolygon,

  -- Merch / amounts
  CAST(NULL AS nvarchar(100))                    AS category,
  CAST(NULL AS nvarchar(120))                    AS brand,
  CAST(NULL AS nvarchar(200))                    AS product_name,
  CAST(pt.amount AS decimal(18,2))               AS total_amount,
  CAST(1 AS int)                                 AS total_items,
  CAST(NULL AS nvarchar(50))                     AS payment_method,
  CAST(si.TranscriptionText AS nvarchar(max))    AS audio_transcript,

  -- Authoritative time from SalesInteractions ONLY (NULL for unmatched)
  si.TransactionDate                             AS txn_ts,
  CASE
    WHEN si.TransactionDate IS NOT NULL THEN
      CASE
        WHEN CAST(si.TransactionDate AS time) >= '05:00' AND CAST(si.TransactionDate AS time) < '12:00' THEN 'Morning'
        WHEN CAST(si.TransactionDate AS time) >= '12:00' AND CAST(si.TransactionDate AS time) < '17:00' THEN 'Afternoon'
        WHEN CAST(si.TransactionDate AS time) >= '17:00' AND CAST(si.TransactionDate AS time) < '21:00' THEN 'Evening'
        ELSE 'Night'
      END
    ELSE NULL
  END                                            AS daypart,
  CASE
    WHEN si.TransactionDate IS NOT NULL THEN
      CASE WHEN DATEPART(WEEKDAY, si.TransactionDate) IN (1,7) THEN 'Weekend' ELSE 'Weekday' END
    ELSE NULL
  END                                            AS weekday_weekend,
  CASE
    WHEN si.TransactionDate IS NOT NULL THEN CONVERT(date, si.TransactionDate)
    ELSE NULL
  END                                            AS transaction_date
FROM dbo.PayloadTransactions pt
LEFT JOIN dbo.SalesInteractions si              -- << LEFT JOIN to keep all PayloadTransactions
  ON JSON_VALUE(pt.payload_json, '$.transactionId') = si.InteractionID
WHERE pt.amount IS NOT NULL;