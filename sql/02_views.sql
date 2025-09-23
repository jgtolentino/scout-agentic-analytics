-- File: sql/02_views.sql
-- Batch 1/2 ---------------------------------------------------------------
IF SCHEMA_ID('dbo') IS NULL THROW 50000,'dbo schema missing',1;
GO

-- Flat view: canonical_tx_id join; timestamp ONLY from SalesInteractions
CREATE OR ALTER VIEW dbo.v_transactions_flat_production
AS
SELECT
  -- IDs / store
  canonical_tx_id = LOWER(REPLACE(COALESCE(
    CASE WHEN ISJSON(pt.payload_json) = 1
         THEN JSON_VALUE(pt.payload_json,'$.transactionId')
         ELSE NULL END,
    pt.sessionId),'-','')),
  transaction_id  = LOWER(REPLACE(COALESCE(
    CASE WHEN ISJSON(pt.payload_json) = 1
         THEN JSON_VALUE(pt.payload_json,'$.transactionId')
         ELSE NULL END,
    pt.sessionId),'-','')),
  device_id       = CAST(pt.deviceId AS varchar(64)),
  store_id        = TRY_CAST(pt.storeId AS int),
  store_name      = CONCAT(N'Store_', pt.storeId),

  -- Business fields (null-safe; derive from payload if present)
  brand           = CASE WHEN ISJSON(pt.payload_json) = 1
                         THEN JSON_VALUE(pt.payload_json,'$.items[0].brandName')
                         ELSE NULL END,
  product_name    = CASE WHEN ISJSON(pt.payload_json) = 1
                         THEN JSON_VALUE(pt.payload_json,'$.items[0].productName')
                         ELSE NULL END,
  category        = CASE WHEN ISJSON(pt.payload_json) = 1
                         THEN JSON_VALUE(pt.payload_json,'$.items[0].category')
                         ELSE NULL END,
  total_amount    = CASE WHEN ISJSON(pt.payload_json) = 1
                         THEN TRY_CONVERT(decimal(18,2), JSON_VALUE(pt.payload_json,'$.totals.totalAmount'))
                         ELSE NULL END,
  total_items     = CASE WHEN ISJSON(pt.payload_json) = 1
                         THEN TRY_CONVERT(int, JSON_VALUE(pt.payload_json,'$.totals.totalItems'))
                         ELSE NULL END,
  payment_method  = CASE WHEN ISJSON(pt.payload_json) = 1
                         THEN JSON_VALUE(pt.payload_json,'$.transactionContext.paymentMethod')
                         ELSE NULL END,
  audio_transcript= CASE WHEN ISJSON(pt.payload_json) = 1
                         THEN JSON_VALUE(pt.payload_json,'$.transactionContext.audioTranscript')
                         ELSE NULL END,

  -- Authoritative time (ONLY from SalesInteractions)
  txn_ts          = si.TransactionDate,

  -- Derived from authoritative time
  daypart = CASE
              WHEN si.TransactionDate IS NULL           THEN NULL
              WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 6  AND 11 THEN 'Morning'
              WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 12 AND 17 THEN 'Afternoon'
              WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 18 AND 22 THEN 'Evening'
              ELSE 'Night'
            END,
  weekday_weekend = CASE
                      WHEN si.TransactionDate IS NULL THEN NULL
                      WHEN DATEPART(WEEKDAY, si.TransactionDate) IN (1,7) THEN 'Weekend'
                      ELSE 'Weekday'
                    END,
  transaction_date = CAST(si.TransactionDate AS date)

FROM dbo.PayloadTransactions pt
LEFT JOIN dbo.SalesInteractions si
  ON LOWER(REPLACE(COALESCE(
    CASE WHEN ISJSON(pt.payload_json) = 1
         THEN JSON_VALUE(pt.payload_json,'$.transactionId')
         ELSE NULL END,
    pt.sessionId),'-',''))
   = LOWER(REPLACE(si.InteractionID,'-',''));
GO

-- Crosstab (long form, stable 10 cols)
CREATE OR ALTER VIEW dbo.v_transactions_crosstab_production
AS
WITH f AS (
  SELECT
    [date]       = CAST(txn_ts AS date),
    store_id,
    daypart,
    brand,
    total_amount
  FROM dbo.v_transactions_flat_production
  WHERE txn_ts IS NOT NULL
)
SELECT
  [date],
  store_id,
  store_name = CONCAT(N'Store_', store_id),
  municipality_name = CAST(NULL AS nvarchar(100)), -- not available in current source
  daypart,
  brand,
  txn_count        = COUNT(*) ,
  total_amount     = SUM(TRY_CONVERT(decimal(18,2), total_amount)),
  avg_basket_amount= NULL,           -- not available (no basket items count at match-time)
  substitution_events = 0            -- not tracked here
FROM f
GROUP BY [date], store_id, daypart, brand;
GO