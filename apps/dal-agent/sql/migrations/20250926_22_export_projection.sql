SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name=N'gold') EXEC('CREATE SCHEMA gold');
GO
/* Canonical projection for all analytics exports */
CREATE OR ALTER VIEW gold.v_export_projection AS
SELECT
  /* IDs & timing */
  f.transaction_id                                   AS transaction_id,
  f.transaction_date                                 AS transaction_date,

  /* Store / geo */
  f.store_id                                         AS store_id,
  f.store_name                                       AS store_name,
  '(unknown)'                                        AS region,  -- placeholder for future region field

  /* Merch / taxonomy */
  f.category                                         AS category,
  f.brand                                            AS brand,
  f.product_name                                     AS product_name,

  /* Basket & payment */
  f.total_items                                      AS basket_size,
  f.total_amount                                     AS transaction_value,
  f.payment_method                                   AS payment_method,

  /* Time features */
  f.daypart                                          AS daypart,
  f.weekday_weekend                                  AS week_type,

  /* Conversation */
  f.audio_transcript                                 AS audio_transcript,

  /* Demographics (placeholder for future field) */
  '(unknown)'                                        AS demographics,

  /* Pass-through keys often used in joins */
  f.canonical_tx_id                                  AS canonical_tx_id
FROM dbo.v_transactions_flat_production f;
GO