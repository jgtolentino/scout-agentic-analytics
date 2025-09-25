SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* Fixed migration procedures with proper type handling */

/* BRANDS - AUTO UPSERT FROM PRODUCTS (FIXED) */
CREATE OR ALTER PROCEDURE etl.sp_migrate_brands_fixed
AS
BEGIN
  SET NOCOUNT ON;

  -- First, upsert from existing brand staging if available
  IF OBJECT_ID('analytics.v_stg_brands','V') IS NOT NULL
  BEGIN
    INSERT INTO dbo.Brands (brand_name, parent_company, category)
    SELECT DISTINCT NULLIF(LTRIM(RTRIM(brand_name)),''),
                    NULLIF(LTRIM(RTRIM(parent_company)),''),
                    NULLIF(LTRIM(RTRIM(category)),'')
    FROM analytics.v_stg_brands b
    WHERE NULLIF(LTRIM(RTRIM(brand_name)),'') IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dbo.Brands d WHERE d.brand_name = b.brand_name);
  END

  -- Auto-upsert brands from products if no brand staging exists
  IF OBJECT_ID('analytics.v_stg_products','V') IS NOT NULL
  BEGIN
    INSERT INTO dbo.Brands (brand_name, parent_company, category)
    SELECT DISTINCT NULLIF(LTRIM(RTRIM(brand_name)),''),
                    NULL, -- no parent company from products
                    NULLIF(LTRIM(RTRIM(category)),'')
    FROM analytics.v_stg_products p
    WHERE NULLIF(LTRIM(RTRIM(brand_name)),'') IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dbo.Brands d WHERE d.brand_name = p.brand_name);
  END
END
GO

/* TRANSACTIONS - FIXED TYPE HANDLING */
CREATE OR ALTER PROCEDURE etl.sp_migrate_transactions_fixed
AS
BEGIN
  SET NOCOUNT ON;
  IF OBJECT_ID('analytics.v_stg_transactions','V') IS NULL RETURN;

  INSERT INTO dbo.Transactions (canonical_tx_id, txn_ts, store_id, total_amount, total_items)
  SELECT DISTINCT
    COALESCE(NULLIF(LTRIM(RTRIM(canonical_tx_id)),''), CONVERT(varchar(64), NEWID())),
    TRY_CONVERT(datetime2(0), txn_ts),
    -- Use proper store_id (already extracted as int from staging view)
    t.store_id,
    TRY_CONVERT(decimal(18,2), total_amount),
    TRY_CONVERT(int, total_items)
  FROM analytics.v_stg_transactions t
  WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Transactions d
    WHERE d.canonical_tx_id = COALESCE(NULLIF(LTRIM(RTRIM(t.canonical_tx_id)),''), CONVERT(varchar(64), NEWID()))
  );
END
GO

/* TRANSACTION ITEMS - FIXED */
CREATE OR ALTER PROCEDURE etl.sp_migrate_transaction_items_fixed
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

/* SALES INTERACTIONS - FIXED DATETIME CONVERSION */
CREATE OR ALTER PROCEDURE etl.sp_migrate_sales_interactions_fixed
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
    -- Handle store_id conversion properly (may be string or int)
    CASE
      WHEN ISNUMERIC(CAST(store_id AS varchar)) = 1 THEN TRY_CONVERT(int, store_id)
      ELSE NULL
    END
  FROM analytics.v_stg_sales_interactions si
  WHERE si.canonical_tx_id IS NOT NULL
    AND EXISTS (SELECT 1 FROM dbo.Transactions t WHERE t.canonical_tx_id = si.canonical_tx_id);
END
GO

/* COMPLETE MIGRATION EXECUTION (FIXED) */
CREATE OR ALTER PROCEDURE etl.sp_migration_execute_fixed
AS
BEGIN
  SET NOCOUNT ON;

  PRINT '== Building staging views ==';
  EXEC etl.sp_build_staging_views;

  PRINT '== Step 1: Migrating stores ==';
  EXEC etl.sp_migrate_stores;

  PRINT '== Step 2: Migrating brands (auto-upsert from products) ==';
  EXEC etl.sp_migrate_brands_fixed;

  PRINT '== Step 3: Migrating products ==';
  EXEC etl.sp_migrate_products;

  PRINT '== Step 4: Migrating transactions (fixed type conversion) ==';
  EXEC etl.sp_migrate_transactions_fixed;

  PRINT '== Step 5: Migrating transaction items ==';
  EXEC etl.sp_migrate_transaction_items_fixed;

  PRINT '== Step 6: Migrating sales interactions (fixed datetime) ==';
  EXEC etl.sp_migrate_sales_interactions_fixed;

  PRINT '== Step 7: Deduplicating transactions ==';
  EXEC dbo.usp_dedupe_transactions;

  PRINT '== Migration completed ==';
END
GO