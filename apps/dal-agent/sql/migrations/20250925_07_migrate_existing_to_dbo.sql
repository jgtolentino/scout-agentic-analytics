SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* STORES */
CREATE OR ALTER PROCEDURE etl.sp_migrate_stores
AS
BEGIN
  SET NOCOUNT ON;
  IF OBJECT_ID('analytics.v_stg_stores','V') IS NULL RETURN;

  INSERT INTO dbo.Stores (store_code, store_name, region, province, city_municipality, barangay, device_id)
  SELECT DISTINCT
    NULLIF(LTRIM(RTRIM(store_code)),''),
    NULLIF(LTRIM(RTRIM(store_name)),''),
    NULLIF(LTRIM(RTRIM(region)),''),
    NULLIF(LTRIM(RTRIM(province)),''),
    NULLIF(LTRIM(RTRIM(city_municipality)),''),
    NULLIF(LTRIM(RTRIM(barangay)),''),
    NULLIF(LTRIM(RTRIM(device_id)),'')
  FROM analytics.v_stg_stores s
  WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Stores d
    WHERE (d.store_code IS NOT NULL AND s.store_code IS NOT NULL AND d.store_code = s.store_code)
       OR (d.store_name = s.store_name AND COALESCE(d.city_municipality,'') = COALESCE(s.city_municipality,''))
  );
END
GO

/* BRANDS */
CREATE OR ALTER PROCEDURE etl.sp_migrate_brands
AS
BEGIN
  SET NOCOUNT ON;
  IF OBJECT_ID('analytics.v_stg_brands','V') IS NULL RETURN;

  INSERT INTO dbo.Brands (brand_name, parent_company, category)
  SELECT DISTINCT NULLIF(LTRIM(RTRIM(brand_name)),''),
                  NULLIF(LTRIM(RTRIM(parent_company)),''),
                  NULLIF(LTRIM(RTRIM(category)),'')
  FROM analytics.v_stg_brands b
  WHERE NULLIF(LTRIM(RTRIM(brand_name)),'') IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM dbo.Brands d WHERE d.brand_name = b.brand_name);
END
GO

/* PRODUCTS (brand resolution by name) */
CREATE OR ALTER PROCEDURE etl.sp_migrate_products
AS
BEGIN
  SET NOCOUNT ON;
  IF OBJECT_ID('analytics.v_stg_products','V') IS NULL RETURN;

  INSERT INTO dbo.Products (sku_code, product_name, brand_id, category, uom, price)
  SELECT DISTINCT
    NULLIF(LTRIM(RTRIM(p.sku_code)),''),
    NULLIF(LTRIM(RTRIM(p.product_name)),''),
    b.brand_id,
    NULLIF(LTRIM(RTRIM(p.category)),''),
    NULLIF(LTRIM(RTRIM(p.uom)),''),
    TRY_CONVERT(decimal(18,2), p.price)
  FROM analytics.v_stg_products p
  LEFT JOIN dbo.Brands b ON b.brand_name = p.brand_name
  WHERE NULLIF(LTRIM(RTRIM(p.product_name)),'') IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM dbo.Products d
      WHERE (d.sku_code IS NOT NULL AND d.sku_code = p.sku_code)
         OR (d.product_name = p.product_name AND ISNULL(d.brand_id,0) = ISNULL(b.brand_id,0))
    );
END
GO

/* TRANSACTIONS */
CREATE OR ALTER PROCEDURE etl.sp_migrate_transactions
AS
BEGIN
  SET NOCOUNT ON;
  IF OBJECT_ID('analytics.v_stg_transactions','V') IS NULL RETURN;

  INSERT INTO dbo.Transactions (canonical_tx_id, txn_ts, store_id, total_amount, total_items)
  SELECT
    COALESCE(NULLIF(LTRIM(RTRIM(canonical_tx_id)),''), CONVERT(varchar(64), NEWID())),
    TRY_CONVERT(datetime2(0), txn_ts),
    s.store_id,
    TRY_CONVERT(decimal(18,2), total_amount),
    TRY_CONVERT(int, total_items)
  FROM analytics.v_stg_transactions t
  LEFT JOIN dbo.Stores s
    ON  (s.store_code IS NOT NULL AND s.store_code = CAST(t.store_id AS varchar(64)))
     OR (s.store_id = t.store_id)
     OR (s.store_name IS NOT NULL AND s.store_name = CAST(t.store_id AS nvarchar(200)))
  WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Transactions d WHERE d.canonical_tx_id = COALESCE(NULLIF(LTRIM(RTRIM(t.canonical_tx_id)),''), CONVERT(varchar(64), NEWID()))
  );
END
GO

/* TRANSACTION ITEMS */
CREATE OR ALTER PROCEDURE etl.sp_migrate_transaction_items
AS
BEGIN
  SET NOCOUNT ON;
  IF OBJECT_ID('analytics.v_stg_transaction_items','V') IS NULL RETURN;

  INSERT INTO dbo.TransactionItems (canonical_tx_id, product_id, brand_id, category, quantity, unit_price, line_amount)
  SELECT
    COALESCE(NULLIF(LTRIM(RTRIM(i.canonical_tx_id)),''), NULL),
    p.product_id,
    b.brand_id,
    NULLIF(LTRIM(RTRIM(i.category)),''),
    TRY_CONVERT(decimal(18,3), i.quantity),
    TRY_CONVERT(decimal(18,2), i.unit_price),
    TRY_CONVERT(decimal(18,2), i.line_amount)
  FROM analytics.v_stg_transaction_items i
  LEFT JOIN dbo.Products p ON p.sku_code = i.sku
  LEFT JOIN dbo.Brands  b ON b.brand_name = i.brand
  WHERE i.canonical_tx_id IS NOT NULL
    AND EXISTS (SELECT 1 FROM dbo.Transactions t WHERE t.canonical_tx_id = i.canonical_tx_id);
END
GO

/* SALES INTERACTIONS */
CREATE OR ALTER PROCEDURE etl.sp_migrate_sales_interactions
AS
BEGIN
  SET NOCOUNT ON;
  IF OBJECT_ID('analytics.v_stg_sales_interactions','V') IS NULL RETURN;

  INSERT INTO dbo.SalesInteractions (canonical_tx_id, interaction_ts, age_bracket, gender, emotion, confidence_score, device_id, store_id)
  SELECT
    COALESCE(NULLIF(LTRIM(RTRIM(canonical_tx_id)),''), NULL),
    TRY_CONVERT(datetime2(0), interaction_ts),
    NULLIF(LTRIM(RTRIM(age_bracket)),''),
    NULLIF(LTRIM(RTRIM(gender)),''),
    NULLIF(LTRIM(RTRIM(emotion)),''),
    TRY_CONVERT(decimal(9,6), confidence_score),
    NULLIF(LTRIM(RTRIM(device_id)),''),
    TRY_CONVERT(int, store_id)
  FROM analytics.v_stg_sales_interactions si
  WHERE si.canonical_tx_id IS NOT NULL
    AND EXISTS (SELECT 1 FROM dbo.Transactions t WHERE t.canonical_tx_id = si.canonical_tx_id);
END
GO