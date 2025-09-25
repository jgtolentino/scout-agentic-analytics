SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name=N'gold') EXEC('CREATE SCHEMA gold');
GO
/* Canonical projection for all analytics exports */
CREATE OR ALTER VIEW gold.v_export_projection AS
SELECT
  /* IDs & timing */
  f.Transaction_ID                                   AS transaction_id,
  CAST(f.Txn_Timestamp AS datetime2(3))              AS transaction_date,

  /* Store / geo */
  f.Store_ID                                         AS store_id,
  f.Store_Name                                       AS store_name,
  LOWER(COALESCE(f.Location_Region, f.Region))       AS region,

  /* Merch / taxonomy */
  f.Category                                         AS category,
  f.Brand                                            AS brand,
  f.Product_Name                                     AS product_name,

  /* Basket & payment */
  COALESCE(f.Basket_Size, f.total_items)             AS basket_size,
  COALESCE(f.Transaction_Value, f.total_amount)      AS transaction_value,
  COALESCE(f.PaymentMethod, f.payment_method)        AS payment_method,

  /* Time features */
  f.Daypart                                          AS daypart,
  f.WeekType                                         AS week_type,

  /* Conversation */
  COALESCE(f.transcript_clean, f.Audio_Transcript)   AS audio_transcript,

  /* Demographics (fallback chain) */
  COALESCE(f.Demographics,
           f.Demographics_Age_Gender_Role,
           f.Demographics_Age_Gender)                AS demographics,

  /* Pass-through keys often used in joins */
  f.canonical_tx_id                                  AS canonical_tx_id
FROM dbo.v_transactions_flat_production f;
GO