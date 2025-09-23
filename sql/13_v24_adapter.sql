SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER VIEW dbo.v_transactions_flat_v24
AS
/* 24-column compatibility view mirroring gold.v_transactions_flat
   - Source: dbo.v_transactions_flat_production (JSON-safe with canonical joins)
   - Exact column mapping to ensure export parity
*/
SELECT
  canonical_tx_id                         AS CanonicalTxID,
  transaction_id                          AS TransactionID,
  device_id                               AS DeviceID,
  store_id                                AS StoreID,
  store_name                              AS StoreName,
  brand,
  product_name,
  category,
  total_amount                            AS Amount,
  total_items                             AS Basket_Item_Count,
  payment_method,
  audio_transcript,
  txn_ts                                  AS Txn_TS,
  daypart,
  weekday_weekend,
  transaction_date
FROM dbo.v_transactions_flat_production
WHERE txn_ts IS NOT NULL;
GO

/* Optional: make sure the reader can select (usually covered by db_datareader) */
GRANT SELECT ON OBJECT::dbo.v_transactions_flat_v24 TO [scout_reader];
GO