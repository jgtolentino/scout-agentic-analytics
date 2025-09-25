SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name=N'gold') EXEC('CREATE SCHEMA gold');
GO

/* Helper: choose a single interaction record per transaction (latest TransactionDate, with demographics) */
CREATE OR ALTER VIEW gold.v_txn_best_interaction
AS
WITH ranked AS (
  SELECT
    si.canonical_tx_id,
    si.TransactionDate,
    si.Age,
    si.Gender,
    si.EmotionalState,
    ROW_NUMBER() OVER (PARTITION BY si.canonical_tx_id
                       ORDER BY si.TransactionDate DESC, si.InteractionID DESC) AS rn
  FROM dbo.SalesInteractions si
  WHERE si.canonical_tx_id IS NOT NULL
)
SELECT *
FROM ranked
WHERE rn = 1;
GO

/* Sample sheet view using existing flat production view + demographics */
CREATE OR ALTER VIEW gold.v_sample_sari_transactions
AS
WITH base AS (
  SELECT
    vt.transaction_id                               AS Transaction_ID,
    TRY_CONVERT(decimal(18,2), vt.total_amount)     AS Transaction_Value,
    TRY_CONVERT(int, vt.total_items)                AS Basket_Size,
    COALESCE(vt.category, 'Unknown')               AS Category,
    COALESCE(vt.brand, 'Unknown')                  AS Brand,
    COALESCE(vt.daypart, 'Unknown')                AS Daypart,
    /* Demographics from best interaction */
    CASE
      WHEN bi.Age IS NOT NULL AND bi.Gender IS NOT NULL
      THEN CONCAT(CAST(bi.Age AS varchar(10)), ' ', LTRIM(RTRIM(REPLACE(bi.Gender, '''', ''))))
      WHEN bi.Gender IS NOT NULL
      THEN LTRIM(RTRIM(REPLACE(bi.Gender, '''', '')))
      WHEN bi.Age IS NOT NULL
      THEN CONCAT(CAST(bi.Age AS varchar(10)), ' Unknown')
      ELSE 'Unknown'
    END                                            AS [Demographics (Age/Gender/Role)],
    COALESCE(LTRIM(RTRIM(bi.EmotionalState)), '')  AS Emotions,
    COALESCE(vt.weekday_weekend, 'Unknown')        AS Weekday_vs_Weekend,
    /* Time label from existing daypart or construct from transaction_date */
    CASE
      WHEN vt.daypart IS NOT NULL THEN vt.daypart
      WHEN vt.txn_ts IS NOT NULL THEN
        CONCAT(
          CASE
            WHEN DATEPART(HOUR, vt.txn_ts) = 0  THEN '12'
            WHEN DATEPART(HOUR, vt.txn_ts) BETWEEN 1 AND 12 THEN CAST(DATEPART(HOUR, vt.txn_ts) AS varchar(2))
            ELSE CAST(DATEPART(HOUR, vt.txn_ts)-12 AS varchar(2))
          END,
          CASE WHEN DATEPART(HOUR, vt.txn_ts) < 12 THEN 'AM' ELSE 'PM' END
        )
      ELSE 'Unknown'
    END                                            AS [Time of transaction],
    COALESCE(vt.store_name, CONCAT('Store_', vt.store_id), 'Unknown') AS Location,
    /* Co-purchase info - get other brands from audio transcript if available */
    CASE
      WHEN LEN(COALESCE(vt.audio_transcript, '')) > 10
      THEN LEFT(COALESCE(vt.audio_transcript, ''), 50) + '...'
      ELSE ''
    END                                            AS [Were there other product bought with it?],
    /* Simple substitution indicator based on transcript keywords */
    CASE
      WHEN vt.audio_transcript LIKE '%substitute%' OR vt.audio_transcript LIKE '%instead%'
           OR vt.audio_transcript LIKE '%alternative%' OR vt.audio_transcript LIKE '%change%'
      THEN 'Possibly'
      ELSE ''
    END                                            AS [Was there substitution?]
  FROM dbo.v_transactions_flat_production vt
  LEFT JOIN gold.v_txn_best_interaction bi ON bi.canonical_tx_id = vt.canonical_tx_id
  WHERE vt.transaction_id IS NOT NULL
)
SELECT TOP 20 *
FROM base
ORDER BY Transaction_Value DESC, Transaction_ID;
GO