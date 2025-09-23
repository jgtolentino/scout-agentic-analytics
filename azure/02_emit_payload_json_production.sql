/* =========================================================
   SCOUT EDGE • Production JSON Payload Builder (Azure SQL)
   Single-procedure emitter with validation
   ========================================================= */

-- (Idempotent helper views used by the proc)
CREATE OR ALTER VIEW dbo.v_txn_ts AS
WITH t AS (
  SELECT
    transactionId,
    TRY_CONVERT(datetimeoffset(0), COALESCE(CreatedOn, InteractionStartTime, EventTime)) AS ts
  FROM dbo.SalesInteractionTranscripts
)
SELECT transactionId, MIN(ts) AS txn_ts
FROM t
GROUP BY transactionId;
GO

CREATE OR ALTER VIEW dbo.v_items_dedup AS
WITH raw AS (
  SELECT
    pt.transactionId,
    COALESCE(JSON_VALUE(j.value,'$.sku'), JSON_VALUE(j.value,'$.SKU')) AS sku,
    NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(j.value,'$.brand'), JSON_VALUE(j.value,'$.brandName')))),'') AS brand,
    TRY_CONVERT(int, JSON_VALUE(j.value,'$.quantity')) AS qty,
    TRY_CONVERT(decimal(18,2), JSON_VALUE(j.value,'$.unitPrice')) AS unitPrice,
    TRY_CONVERT(decimal(18,2), JSON_VALUE(j.value,'$.totalPrice')) AS totalPrice
  FROM dbo.PayloadTransactions pt
  CROSS APPLY OPENJSON(pt.payload_json, '$.items') AS j
),
norm AS (
  SELECT
    transactionId,
    COALESCE(sku, CONCAT('SKU-', ROW_NUMBER() OVER (PARTITION BY transactionId ORDER BY (SELECT 1)))) AS sku,
    brand, qty, unitPrice, totalPrice
  FROM raw
),
dedup AS (
  SELECT
    transactionId, sku, brand,
    SUM(COALESCE(qty,1)) AS qty,
    MAX(COALESCE(unitPrice,
        TRY_CONVERT(decimal(18,2),
          NULLIF(NULLIF(totalPrice,0)/NULLIF(NULLIF(qty,0),0),0)))) AS unitPrice,
    SUM(COALESCE(totalPrice, COALESCE(unitPrice,0)*COALESCE(qty,1))) AS totalPrice
  FROM norm
  GROUP BY transactionId, sku, brand
)
SELECT d.*,
       ROW_NUMBER() OVER (PARTITION BY d.transactionId ORDER BY d.sku, d.brand) AS lineId
FROM dedup d;
GO

CREATE OR ALTER VIEW dbo.v_requested_brand AS
WITH base AS (
  SELECT
    t.transactionId,
    NULLIF(LTRIM(RTRIM(t.DetectedBrand)),'') AS requested_brand,
    TRY_CONVERT(datetimeoffset(0), COALESCE(t.CreatedOn, t.InteractionStartTime, t.EventTime)) AS ts,
    LOWER(COALESCE(t.TranscriptText,'')) AS txt
  FROM dbo.SalesInteractionTranscripts t
),
first_brand AS (
  SELECT transactionId, requested_brand
  FROM (
    SELECT transactionId, requested_brand,
           ROW_NUMBER() OVER (PARTITION BY transactionId ORDER BY ts) rn
    FROM base
    WHERE requested_brand IS NOT NULL
  ) x
  WHERE rn=1
),
reason AS (
  SELECT transactionId,
         CASE
           WHEN txt LIKE '%out of stock%' OR txt LIKE '%no stock%' OR txt LIKE N'%wala%' OR txt LIKE N'%ubos%' THEN 'stockout'
           WHEN txt LIKE '%suggest%' OR txt LIKE N'%ibang brand%' OR txt LIKE N'%pwede na ito%' OR txt LIKE '%alternative%' THEN 'suggestion'
           ELSE 'unknown'
         END AS substitution_reason,
         ROW_NUMBER() OVER (PARTITION BY transactionId ORDER BY ts) rn
  FROM base
)
SELECT b.transactionId,
       b.requested_brand,
       COALESCE(r.substitution_reason,'unknown') AS substitution_reason
FROM first_brand b
LEFT JOIN (SELECT transactionId, substitution_reason FROM reason WHERE rn=1) r
  ON r.transactionId = b.transactionId;
GO

CREATE OR ALTER VIEW dbo.v_items_with_substitution AS
SELECT
  i.transactionId, i.lineId, i.sku, i.brand, i.qty, i.unitPrice, i.totalPrice,
  CAST(CASE
    WHEN rb.requested_brand IS NULL OR i.brand IS NULL THEN 0
    WHEN UPPER(i.brand) = UPPER(rb.requested_brand) THEN 0
    ELSE 1
  END AS bit) AS substitutionEvent,
  CASE
    WHEN rb.requested_brand IS NOT NULL AND i.brand IS NOT NULL AND UPPER(i.brand) <> UPPER(rb.requested_brand)
    THEN rb.requested_brand ELSE NULL END AS substitutionFrom
FROM dbo.v_items_dedup i
LEFT JOIN dbo.v_requested_brand rb
  ON rb.transactionId = i.transactionId;
GO

CREATE OR ALTER VIEW dbo.v_transaction_payload_json AS
SELECT
  pt.transactionId,
  (
    SELECT
      pt.transactionId AS [transactionId],
      pt.storeId       AS [storeId],
      pt.deviceId      AS [deviceId],
      FORMAT(SWITCHOFFSET(ts.txn_ts, '+00:00'), 'yyyy-MM-ddTHH:mm:ss') + 'Z' AS [timestamp],

      ( SELECT
          i.lineId AS [lineId],
          i.brand  AS [brand],
          i.sku    AS [sku],
          i.qty    AS [qty],
          i.unitPrice  AS [unitPrice],
          i.totalPrice AS [totalPrice],
          i.substitutionEvent AS [substitutionEvent],
          i.substitutionFrom  AS [substitutionFrom]
        FROM dbo.v_items_with_substitution i
        WHERE i.transactionId = pt.transactionId
        ORDER BY i.lineId
        FOR JSON PATH
      ) AS [basket.items],

      ( SELECT
          f.AgeBracket       AS [ageBracket],
          f.Gender           AS [gender],
          f.Role             AS [role],
          f.WeekdayOrWeekend AS [weekdayOrWeekend],
          f.TimeOfDay        AS [timeOfDay]
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
      ) AS [interaction],

      ( SELECT
          s.Region           AS [region],
          s.ProvinceName     AS [province],
          s.MunicipalityName AS [municipality],
          s.BarangayName     AS [barangay],
          s.psgc_region      AS [psgc_region],
          s.psgc_citymun     AS [psgc_citymun],
          s.psgc_barangay    AS [psgc_barangay],
          (SELECT s.GeoLatitude AS [lat], s.GeoLongitude AS [lon]
           FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS [geo]
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
      ) AS [location],

      ( SELECT
          CAST(CASE WHEN EXISTS (
                 SELECT 1 FROM dbo.v_items_with_substitution iw
                 WHERE iw.transactionId = pt.transactionId AND iw.brand IS NOT NULL
               ) THEN 1 ELSE 0 END AS bit) AS [brandMatched],
          CAST(CASE WHEN s.MunicipalityName IS NOT NULL AND
                           (s.StorePolygon IS NOT NULL OR (s.GeoLatitude IS NOT NULL AND s.GeoLongitude IS NOT NULL))
               THEN 1 ELSE 0 END AS bit) AS [locationVerified],
          CAST(CASE WHEN EXISTS (
                 SELECT 1 FROM dbo.v_items_with_substitution iw
                 WHERE iw.transactionId = pt.transactionId AND iw.substitutionEvent=1
               ) THEN 1 ELSE 0 END AS bit) AS [substitutionDetected]
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
      ) AS [qualityFlags],

      ( SELECT
          f.source_path AS [file],
          (SELECT COUNT(*) FROM dbo.v_items_dedup x WHERE x.transactionId = pt.transactionId) AS [rowCount]
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
      ) AS [source]
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  ) AS payload_json
FROM dbo.PayloadTransactions pt
LEFT JOIN dbo.v_txn_ts ts ON ts.transactionId = pt.transactionId
LEFT JOIN dbo.fact_transactions_location f ON f.transactionId = pt.transactionId
LEFT JOIN dbo.Stores s ON s.StoreID = pt.storeId;
GO

CREATE OR ALTER PROCEDURE dbo.sp_emit_fact_payload_json
AS
BEGIN
  SET NOCOUNT ON;

  PRINT '========================================'
  PRINT 'Scout Edge JSON Payload Generation'
  PRINT '========================================'

  -- 1) Materialize JSON into fact table
  PRINT 'Materializing JSON payloads...'
  ;WITH up AS (
    SELECT f.transactionId, v.payload_json
    FROM dbo.fact_transactions_location f
    JOIN dbo.v_transaction_payload_json v
      ON v.transactionId = f.transactionId
  )
  UPDATE f
    SET f.payload_json = up.payload_json,
        updated_at = SYSDATETIME()
  FROM dbo.fact_transactions_location f
  JOIN up ON up.transactionId = f.transactionId;

  DECLARE @updated_rows INT = @@ROWCOUNT;
  PRINT 'Updated ' + CAST(@updated_rows AS VARCHAR) + ' rows with JSON payloads'

  -- 2) Return validation summary
  PRINT 'Generating validation summary...'
  SELECT
    'VALIDATION_SUMMARY' AS report_type,
    total_rows              = COUNT(*),
    json_payload_rows       = SUM(CASE WHEN payload_json IS NOT NULL THEN 1 ELSE 0 END),
    null_payload_rows       = SUM(CASE WHEN payload_json IS NULL THEN 1 ELSE 0 END),
    avg_payload_size_kb     = AVG(LEN(payload_json)) / 1024.0,
    max_payload_size_kb     = MAX(LEN(payload_json)) / 1024.0,
    substitution_transactions = SUM(CASE WHEN JSON_VALUE(payload_json, '$.qualityFlags.substitutionDetected') = 'true' THEN 1 ELSE 0 END),
    brand_matched_transactions = SUM(CASE WHEN JSON_VALUE(payload_json, '$.qualityFlags.brandMatched') = 'true' THEN 1 ELSE 0 END),
    location_verified_transactions = SUM(CASE WHEN JSON_VALUE(payload_json, '$.qualityFlags.locationVerified') = 'true' THEN 1 ELSE 0 END)
  FROM dbo.fact_transactions_location;

  -- 3) Quality checks
  SELECT
    'QUALITY_CHECKS' AS report_type,
    check_name = 'JSON Structure Validity',
    violations = SUM(CASE WHEN payload_json IS NOT NULL AND ISJSON(payload_json) = 0 THEN 1 ELSE 0 END),
    total_applicable = SUM(CASE WHEN payload_json IS NOT NULL THEN 1 ELSE 0 END)
  FROM dbo.fact_transactions_location

  UNION ALL

  SELECT
    'QUALITY_CHECKS',
    'Missing Transaction ID in JSON',
    SUM(CASE WHEN payload_json IS NOT NULL AND JSON_VALUE(payload_json, '$.transactionId') IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN payload_json IS NOT NULL THEN 1 ELSE 0 END)
  FROM dbo.fact_transactions_location

  UNION ALL

  SELECT
    'QUALITY_CHECKS',
    'Empty Basket Items',
    SUM(CASE WHEN payload_json IS NOT NULL AND JSON_QUERY(payload_json, '$.basket.items') = '[]' THEN 1 ELSE 0 END),
    SUM(CASE WHEN payload_json IS NOT NULL THEN 1 ELSE 0 END)
  FROM dbo.fact_transactions_location;

  -- 4) Sample output for verification
  SELECT
    'SAMPLE_DATA' AS report_type,
    transactionId,
    storeId = JSON_VALUE(payload_json, '$.storeId'),
    item_count = JSON_VALUE(payload_json, '$.basket.items.length()'),
    municipality = JSON_VALUE(payload_json, '$.location.municipality'),
    has_substitution = JSON_VALUE(payload_json, '$.qualityFlags.substitutionDetected'),
    payload_size_kb = LEN(payload_json) / 1024,
    preview = LEFT(payload_json, 200) + '...'
  FROM dbo.fact_transactions_location
  WHERE payload_json IS NOT NULL
  ORDER BY transactionId
  OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;

  PRINT '========================================'
  PRINT 'JSON Payload Generation Complete'
  PRINT 'Total Updated: ' + CAST(@updated_rows AS VARCHAR) + ' transactions'
  PRINT '========================================'
END;
GO

-- ==========================================
-- EXECUTION INSTRUCTIONS
-- ==========================================

/*
-- Execute the full transformation
EXEC dbo.sp_emit_fact_payload_json;

-- Quick validation query
SELECT
    COUNT(*) as total_transactions,
    COUNT(payload_json) as with_json_payload,
    AVG(LEN(payload_json)) / 1024.0 as avg_payload_kb,
    COUNT(*) FILTER (WHERE JSON_VALUE(payload_json, '$.qualityFlags.substitutionDetected') = 'true') as substitution_events
FROM dbo.fact_transactions_location;

-- Sample JSON structure
SELECT TOP 1
    transactionId,
    JSON_QUERY(payload_json, '$.basket.items[0]') as first_item,
    JSON_QUERY(payload_json, '$.location') as location_data,
    JSON_QUERY(payload_json, '$.qualityFlags') as quality_flags
FROM dbo.fact_transactions_location
WHERE payload_json IS NOT NULL;
*/