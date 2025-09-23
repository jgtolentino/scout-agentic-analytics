SET NOCOUNT ON;

-- Payload: canonical id from payload JSON
IF COL_LENGTH('dbo.PayloadTransactions','canonical_tx_id_payload') IS NULL
  ALTER TABLE dbo.PayloadTransactions ADD canonical_tx_id_payload AS (
    UPPER(REPLACE(LTRIM(RTRIM(TRY_CONVERT(nvarchar(128), JSON_VALUE(payload_json, '$.transactionId')))),'-',''))
  ) PERSISTED;

-- SalesInteractions: normalized InteractionID
IF COL_LENGTH('dbo.SalesInteractions','canonical_tx_id_norm') IS NULL
  ALTER TABLE dbo.SalesInteractions ADD canonical_tx_id_norm AS (
    UPPER(REPLACE(LTRIM(RTRIM(TRY_CONVERT(nvarchar(128), InteractionID))),'-',''))
  ) PERSISTED;

-- Helpful indexes
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payload_canon')
  CREATE INDEX IX_Payload_canon ON dbo.PayloadTransactions(canonical_tx_id_payload);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SI_canon')
  CREATE INDEX IX_SI_canon ON dbo.SalesInteractions(canonical_tx_id_norm);