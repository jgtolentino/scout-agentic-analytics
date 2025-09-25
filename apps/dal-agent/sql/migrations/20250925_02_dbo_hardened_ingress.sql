SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ---------- Core Tables ---------- */
IF OBJECT_ID('dbo.Stores','U') IS NULL
CREATE TABLE dbo.Stores (
  store_id           int            IDENTITY(1,1) PRIMARY KEY,
  store_code         varchar(64)    NULL,
  store_name         nvarchar(200)  NOT NULL,
  region             nvarchar(100)  NULL,
  province           nvarchar(100)  NULL,
  city_municipality  nvarchar(100)  NULL,
  barangay           nvarchar(100)  NULL,
  device_id          varchar(64)    NULL,
  CONSTRAINT UQ_Stores_store_code UNIQUE (store_code)
);
GO

IF OBJECT_ID('dbo.Brands','U') IS NULL
CREATE TABLE dbo.Brands (
  brand_id       int            IDENTITY(1,1) PRIMARY KEY,
  brand_name     nvarchar(120)  NOT NULL,
  parent_company nvarchar(120)  NULL,
  category       nvarchar(120)  NULL,
  CONSTRAINT UQ_Brands_brand_name UNIQUE (brand_name)
);
GO

IF OBJECT_ID('dbo.Products','U') IS NULL
CREATE TABLE dbo.Products (
  product_id   int            IDENTITY(1,1) PRIMARY KEY,
  sku_code     varchar(64)    NULL,
  product_name nvarchar(200)  NOT NULL,
  brand_id     int            NOT NULL,
  category     nvarchar(120)  NULL,
  uom          nvarchar(40)   NULL,
  price        decimal(18,2)  NULL,
  CONSTRAINT FK_Products_Brands FOREIGN KEY (brand_id) REFERENCES dbo.Brands(brand_id)
);
GO

IF OBJECT_ID('dbo.Transactions','U') IS NULL
CREATE TABLE dbo.Transactions (
  transaction_id     bigint        IDENTITY(1,1) PRIMARY KEY,
  canonical_tx_id    varchar(64)   NOT NULL,
  txn_ts             datetime2(0)  NOT NULL,
  store_id           int           NOT NULL,
  total_amount       decimal(18,2) NULL,
  total_items        int           NULL,
  weekday_weekend    varchar(10)   NULL,
  daypart            varchar(10)   NULL,
  demographics_json  nvarchar(max) NULL,
  source_payload_sha char(64)      NULL,
  CONSTRAINT UQ_Transactions_Canonical UNIQUE (canonical_tx_id),
  CONSTRAINT FK_Transactions_Stores FOREIGN KEY (store_id) REFERENCES dbo.Stores(store_id)
);
GO

IF OBJECT_ID('dbo.TransactionItems','U') IS NULL
CREATE TABLE dbo.TransactionItems (
  tx_item_id       bigint        IDENTITY(1,1) PRIMARY KEY,
  canonical_tx_id  varchar(64)   NOT NULL,
  product_id       int           NULL,
  brand_id         int           NULL,
  category         nvarchar(120) NULL,
  quantity         decimal(18,3) NULL,
  unit_price       decimal(18,2) NULL,
  line_amount      decimal(18,2) NULL,
  CONSTRAINT FK_TxItems_Brands   FOREIGN KEY (brand_id)   REFERENCES dbo.Brands(brand_id),
  CONSTRAINT FK_TxItems_Products FOREIGN KEY (product_id) REFERENCES dbo.Products(product_id),
  CONSTRAINT FK_TxItems_Tx       FOREIGN KEY (canonical_tx_id) REFERENCES dbo.Transactions(canonical_tx_id)
);
GO

IF OBJECT_ID('dbo.SalesInteractions','U') IS NULL
CREATE TABLE dbo.SalesInteractions (
  interaction_id    bigint       IDENTITY(1,1) PRIMARY KEY,
  canonical_tx_id   varchar(64)  NOT NULL,
  interaction_ts    datetime2(0) NULL,
  age_bracket       varchar(32)  NULL,
  gender            varchar(16)  NULL,
  emotion           varchar(32)  NULL,
  confidence_score  decimal(9,6) NULL,
  device_id         varchar(64)  NULL,
  store_id          int          NULL,
  CONSTRAINT FK_SI_Tx    FOREIGN KEY (canonical_tx_id) REFERENCES dbo.Transactions(canonical_tx_id),
  CONSTRAINT FK_SI_Store FOREIGN KEY (store_id) REFERENCES dbo.Stores(store_id)
);
GO

/* ---------- Indexing ---------- */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Tx_Store_Ts' AND object_id=OBJECT_ID('dbo.Transactions'))
  CREATE INDEX IX_Tx_Store_Ts ON dbo.Transactions(store_id, txn_ts);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Tx_Canonical' AND object_id=OBJECT_ID('dbo.Transactions'))
  CREATE INDEX IX_Tx_Canonical ON dbo.Transactions(canonical_tx_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_TxItems_Canonical' AND object_id=OBJECT_ID('dbo.TransactionItems'))
  CREATE INDEX IX_TxItems_Canonical ON dbo.TransactionItems(canonical_tx_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_SI_Canonical' AND object_id=OBJECT_ID('dbo.SalesInteractions'))
  CREATE INDEX IX_SI_Canonical ON dbo.SalesInteractions(canonical_tx_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='CCI_TxItems' AND object_id=OBJECT_ID('dbo.TransactionItems'))
  CREATE CLUSTERED COLUMNSTORE INDEX CCI_TxItems ON dbo.TransactionItems;
GO

/* ---------- Views ---------- */
CREATE OR ALTER VIEW dbo.v_transactions_flat AS
SELECT
  t.canonical_tx_id,
  t.txn_ts,
  t.total_amount,
  t.total_items,
  s.store_name,
  s.city_municipality,
  s.barangay,
  t.weekday_weekend,
  t.daypart,
  si.age_bracket,
  si.gender,
  si.emotion
FROM dbo.Transactions t
LEFT JOIN dbo.Stores s ON s.store_id = t.store_id
OUTER APPLY (
  SELECT TOP (1) age_bracket, gender, emotion
  FROM dbo.SalesInteractions si
  WHERE si.canonical_tx_id = t.canonical_tx_id
  ORDER BY si.interaction_ts ASC
) si;
GO

CREATE OR ALTER VIEW dbo.v_xtab_daypart AS
SELECT daypart,
       COUNT(*) AS txn_count,
       SUM(total_amount) AS revenue
FROM dbo.Transactions
GROUP BY daypart;
GO

/* ---------- Dedup Procedure ---------- */
CREATE OR ALTER PROCEDURE dbo.usp_dedupe_transactions
AS
BEGIN
  SET NOCOUNT ON;
  ;WITH ranked AS (
    SELECT *,
           ROW_NUMBER() OVER(PARTITION BY canonical_tx_id ORDER BY txn_ts ASC, transaction_id ASC) AS rn
    FROM dbo.Transactions
  )
  DELETE FROM ranked WHERE rn > 1;

  DELETE si
  FROM dbo.SalesInteractions si
  LEFT JOIN dbo.Transactions t ON t.canonical_tx_id = si.canonical_tx_id
  WHERE t.canonical_tx_id IS NULL;

  DELETE ti
  FROM dbo.TransactionItems ti
  LEFT JOIN dbo.Transactions t ON t.canonical_tx_id = ti.canonical_tx_id
  WHERE t.canonical_tx_id IS NULL;
END;
GO