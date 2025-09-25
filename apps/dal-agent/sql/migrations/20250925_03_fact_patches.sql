SET NOCOUNT ON;

-- Add canonical_tx_id to fact.transactions if missing, and unique index
IF COL_LENGTH('fact.transactions','canonical_tx_id') IS NULL
  ALTER TABLE fact.transactions ADD canonical_tx_id varchar(64) NOT NULL DEFAULT(CONVERT(varchar(64), NEWID()));

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_fact_transactions_canonical' AND object_id=OBJECT_ID('fact.transactions'))
  CREATE UNIQUE INDEX UX_fact_transactions_canonical ON fact.transactions(canonical_tx_id);
GO