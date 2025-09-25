SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
  etl.sp_build_staging_views
  - Detects likely legacy tables and columns
  - Creates or replaces staging views:
      analytics.v_stg_stores
      analytics.v_stg_brands
      analytics.v_stg_products
      analytics.v_stg_transactions
      analytics.v_stg_transaction_items
      analytics.v_stg_sales_interactions
  - Non-destructive; safe to re-run.
*/
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'analytics') EXEC('CREATE SCHEMA analytics');
GO

CREATE OR ALTER PROCEDURE etl.sp_build_staging_views
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @sql nvarchar(max);

  /* Helper: resolve columns by priority list */
  DECLARE @stores_src sysname, @tx_src sysname, @items_src sysname, @brands_src sysname, @products_src sysname, @si_src sysname;

  -- resolve candidate sources by presence (adjust priorities as needed)
  SELECT TOP 1 @stores_src  = QUOTENAME(s.name)+'.'+QUOTENAME(t.name)
  FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
  WHERE t.name IN ('Stores','stores','store','dim_stores') ORDER BY t.name;

  SELECT TOP 1 @brands_src  = QUOTENAME(s.name)+'.'+QUOTENAME(t.name)
  FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
  WHERE t.name IN ('Brands','brands','ref_brands','dim_brands') ORDER BY t.name;

  SELECT TOP 1 @products_src= QUOTENAME(s.name)+'.'+QUOTENAME(t.name)
  FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
  WHERE t.name IN ('Products','products','ref_products','dim_products') ORDER BY t.name;

  SELECT TOP 1 @tx_src     = QUOTENAME(s.name)+'.'+QUOTENAME(t.name)
  FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
  WHERE t.name IN ('transactions','Transactions','fact_transactions','sales_transactions','scout_transactions') ORDER BY t.name;

  SELECT TOP 1 @items_src  = QUOTENAME(s.name)+'.'+QUOTENAME(t.name)
  FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
  WHERE t.name IN ('transaction_items','TransactionItems','fact_transaction_items','sales_transaction_items') ORDER BY t.name;

  SELECT TOP 1 @si_src     = QUOTENAME(s.name)+'.'+QUOTENAME(t.name)
  FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
  WHERE t.name IN ('SalesInteractions','sales_interactions','interactions','azure_interactions') ORDER BY t.name;

  /* Macro to test column existence in a given table */
  CREATE TABLE #col(c sysname);
  DECLARE @q nvarchar(max);

  -- Build analytics.v_stg_stores
  IF @stores_src IS NOT NULL
  BEGIN
    SET @sql = N'
    CREATE OR ALTER VIEW analytics.v_stg_stores AS
    SELECT
      ' + CASE WHEN COL_LENGTH(@stores_src, 'StoreID') IS NOT NULL        THEN 'CAST(StoreID AS int)'
               WHEN COL_LENGTH(@stores_src, 'store_id') IS NOT NULL       THEN 'CAST(store_id AS int)'
               WHEN COL_LENGTH(@stores_src, 'id') IS NOT NULL             THEN 'CAST(id AS int)'
               ELSE 'CAST(NULL AS int)'
          END + N' AS store_id,
      ' + CASE WHEN COL_LENGTH(@stores_src, 'StoreCode') IS NOT NULL      THEN 'StoreCode'
               WHEN COL_LENGTH(@stores_src, 'store_code') IS NOT NULL     THEN 'store_code'
               WHEN COL_LENGTH(@stores_src, 'code') IS NOT NULL           THEN 'code'
               ELSE 'NULL'
          END + N' AS store_code,
      ' + CASE WHEN COL_LENGTH(@stores_src, 'StoreName') IS NOT NULL      THEN 'StoreName'
               WHEN COL_LENGTH(@stores_src, 'store_name') IS NOT NULL     THEN 'store_name'
               ELSE 'NULL'
          END + N' AS store_name,
      ' + CASE WHEN COL_LENGTH(@stores_src, 'Region') IS NOT NULL         THEN 'Region'
               WHEN COL_LENGTH(@stores_src, 'region') IS NOT NULL         THEN 'region'
               ELSE 'NULL'
          END + N' AS region,
      ' + CASE WHEN COL_LENGTH(@stores_src, 'Province') IS NOT NULL       THEN 'Province'
               WHEN COL_LENGTH(@stores_src, 'province') IS NOT NULL       THEN 'province'
               ELSE 'NULL'
          END + N' AS province,
      ' + CASE WHEN COL_LENGTH(@stores_src, 'City') IS NOT NULL           THEN 'City'
               WHEN COL_LENGTH(@stores_src, 'city_municipality') IS NOT NULL THEN 'city_municipality'
               WHEN COL_LENGTH(@stores_src, 'municipality') IS NOT NULL   THEN 'municipality'
               ELSE 'NULL'
          END + N' AS city_municipality,
      ' + CASE WHEN COL_LENGTH(@stores_src, 'Barangay') IS NOT NULL       THEN 'Barangay'
               WHEN COL_LENGTH(@stores_src, 'barangay') IS NOT NULL       THEN 'barangay'
               ELSE 'NULL'
          END + N' AS barangay,
      ' + CASE WHEN COL_LENGTH(@stores_src, 'DeviceId') IS NOT NULL       THEN 'DeviceId'
               WHEN COL_LENGTH(@stores_src, 'device_id') IS NOT NULL      THEN 'device_id'
               ELSE 'NULL'
          END + N' AS device_id
    FROM ' + @stores_src + N' WITH (NOLOCK);';
    EXEC sp_executesql @sql;
  END

  -- analytics.v_stg_brands
  IF @brands_src IS NOT NULL
  BEGIN
    SET @sql = N'
    CREATE OR ALTER VIEW analytics.v_stg_brands AS
    SELECT
      ' + CASE WHEN COL_LENGTH(@brands_src,'BrandName') IS NOT NULL THEN 'BrandName'
               WHEN COL_LENGTH(@brands_src,'brand_name') IS NOT NULL THEN 'brand_name'
               ELSE 'NULL' END + N' AS brand_name,
      ' + CASE WHEN COL_LENGTH(@brands_src,'ParentCompany') IS NOT NULL THEN 'ParentCompany'
               WHEN COL_LENGTH(@brands_src,'parent_company') IS NOT NULL THEN 'parent_company'
               ELSE 'NULL' END + N' AS parent_company,
      ' + CASE WHEN COL_LENGTH(@brands_src,'Category') IS NOT NULL THEN 'Category'
               WHEN COL_LENGTH(@brands_src,'category') IS NOT NULL THEN 'category'
               ELSE 'NULL' END + N' AS category
    FROM ' + @brands_src + N' WITH (NOLOCK);';
    EXEC sp_executesql @sql;
  END

  -- analytics.v_stg_products
  IF @products_src IS NOT NULL
  BEGIN
    SET @sql = N'
    CREATE OR ALTER VIEW analytics.v_stg_products AS
    SELECT
      ' + CASE WHEN COL_LENGTH(@products_src,'SKU') IS NOT NULL THEN 'SKU'
               WHEN COL_LENGTH(@products_src,'sku_code') IS NOT NULL THEN 'sku_code'
               ELSE 'NULL' END + N' AS sku_code,
      ' + CASE WHEN COL_LENGTH(@products_src,'ProductName') IS NOT NULL THEN 'ProductName'
               WHEN COL_LENGTH(@products_src,'product_name') IS NOT NULL THEN 'product_name'
               ELSE 'NULL' END + N' AS product_name,
      ' + CASE WHEN COL_LENGTH(@products_src,'BrandName') IS NOT NULL THEN 'BrandName'
               WHEN COL_LENGTH(@products_src,'brand_name') IS NOT NULL THEN 'brand_name'
               ELSE 'NULL' END + N' AS brand_name,
      ' + CASE WHEN COL_LENGTH(@products_src,'Category') IS NOT NULL THEN 'Category'
               WHEN COL_LENGTH(@products_src,'category') IS NOT NULL THEN 'category'
               ELSE 'NULL' END + N' AS category,
      ' + CASE WHEN COL_LENGTH(@products_src,'UOM') IS NOT NULL THEN 'UOM'
               WHEN COL_LENGTH(@products_src,'uom') IS NOT NULL THEN 'uom'
               ELSE 'NULL' END + N' AS uom,
      ' + CASE WHEN COL_LENGTH(@products_src,'Price') IS NOT NULL THEN 'Price'
               WHEN COL_LENGTH(@products_src,'price') IS NOT NULL THEN 'price'
               ELSE 'NULL' END + N' AS price
    FROM ' + @products_src + N' WITH (NOLOCK);';
    EXEC sp_executesql @sql;
  END

  -- analytics.v_stg_transactions
  IF @tx_src IS NOT NULL
  BEGIN
    SET @sql = N'
    CREATE OR ALTER VIEW analytics.v_stg_transactions AS
    SELECT
      ' + CASE WHEN COL_LENGTH(@tx_src,'Canonical_Tx_Id') IS NOT NULL THEN 'Canonical_Tx_Id'
               WHEN COL_LENGTH(@tx_src,'canonical_tx_id') IS NOT NULL THEN 'canonical_tx_id'
               WHEN COL_LENGTH(@tx_src,'sessionId') IS NOT NULL THEN 'sessionId'
               ELSE 'NULL' END + N' AS canonical_tx_id,
      ' + CASE WHEN COL_LENGTH(@tx_src,'TransactionTS') IS NOT NULL THEN 'TransactionTS'
               WHEN COL_LENGTH(@tx_src,'txn_ts') IS NOT NULL THEN 'txn_ts'
               WHEN COL_LENGTH(@tx_src,'transaction_datetime') IS NOT NULL THEN 'transaction_datetime'
               ELSE 'NULL' END + N' AS txn_ts,
      ' + CASE WHEN COL_LENGTH(@tx_src,'StoreID') IS NOT NULL THEN 'CAST(StoreID AS int)'
               WHEN COL_LENGTH(@tx_src,'store_id') IS NOT NULL THEN 'CAST(store_id AS int)'
               ELSE 'NULL' END + N' AS store_id,
      ' + CASE WHEN COL_LENGTH(@tx_src,'TotalAmount') IS NOT NULL THEN 'TotalAmount'
               WHEN COL_LENGTH(@tx_src,'total_amount') IS NOT NULL THEN 'total_amount'
               ELSE 'NULL' END + N' AS total_amount,
      ' + CASE WHEN COL_LENGTH(@tx_src,'TotalItems') IS NOT NULL THEN 'TotalItems'
               WHEN COL_LENGTH(@tx_src,'total_items') IS NOT NULL THEN 'total_items'
               ELSE 'NULL' END + N' AS total_items
    FROM ' + @tx_src + N' WITH (NOLOCK);';
    EXEC sp_executesql @sql;
  END

  -- analytics.v_stg_transaction_items
  IF @items_src IS NOT NULL
  BEGIN
    SET @sql = N'
    CREATE OR ALTER VIEW analytics.v_stg_transaction_items AS
    SELECT
      ' + CASE WHEN COL_LENGTH(@items_src,'Canonical_Tx_Id') IS NOT NULL THEN 'Canonical_Tx_Id'
               WHEN COL_LENGTH(@items_src,'canonical_tx_id') IS NOT NULL THEN 'canonical_tx_id'
               ELSE 'NULL' END + N' AS canonical_tx_id,
      ' + CASE WHEN COL_LENGTH(@items_src,'SKU') IS NOT NULL THEN 'SKU'
               WHEN COL_LENGTH(@items_src,'sku') IS NOT NULL THEN 'sku'
               WHEN COL_LENGTH(@items_src,'product_sku') IS NOT NULL THEN 'product_sku'
               ELSE 'NULL' END + N' AS sku,
      ' + CASE WHEN COL_LENGTH(@items_src,'Brand') IS NOT NULL THEN 'Brand'
               WHEN COL_LENGTH(@items_src,'brand') IS NOT NULL THEN 'brand'
               ELSE 'NULL' END + N' AS brand,
      ' + CASE WHEN COL_LENGTH(@items_src,'Category') IS NOT NULL THEN 'Category'
               WHEN COL_LENGTH(@items_src,'category') IS NOT NULL THEN 'category'
               ELSE 'NULL' END + N' AS category,
      ' + CASE WHEN COL_LENGTH(@items_src,'Qty') IS NOT NULL THEN 'Qty'
               WHEN COL_LENGTH(@items_src,'quantity') IS NOT NULL THEN 'quantity'
               ELSE 'NULL' END + N' AS quantity,
      ' + CASE WHEN COL_LENGTH(@items_src,'UnitPrice') IS NOT NULL THEN 'UnitPrice'
               WHEN COL_LENGTH(@items_src,'unit_price') IS NOT NULL THEN 'unit_price'
               ELSE 'NULL' END + N' AS unit_price,
      ' + CASE WHEN COL_LENGTH(@items_src,'LineAmount') IS NOT NULL THEN 'LineAmount'
               WHEN COL_LENGTH(@items_src,'line_amount') IS NOT NULL THEN 'line_amount'
               ELSE 'NULL' END + N' AS line_amount
    FROM ' + @items_src + N' WITH (NOLOCK);';
    EXEC sp_executesql @sql;
  END

  -- analytics.v_stg_sales_interactions
  IF @si_src IS NOT NULL
  BEGIN
    SET @sql = N'
    CREATE OR ALTER VIEW analytics.v_stg_sales_interactions AS
    SELECT
      ' + CASE WHEN COL_LENGTH(@si_src,'Canonical_Tx_Id') IS NOT NULL THEN 'Canonical_Tx_Id'
               WHEN COL_LENGTH(@si_src,'canonical_tx_id') IS NOT NULL THEN 'canonical_tx_id'
               ELSE 'NULL' END + N' AS canonical_tx_id,
      ' + CASE WHEN COL_LENGTH(@si_src,'InteractionTS') IS NOT NULL THEN 'InteractionTS'
               WHEN COL_LENGTH(@si_src,'interaction_ts') IS NOT NULL THEN 'interaction_ts'
               ELSE 'NULL' END + N' AS interaction_ts,
      ' + CASE WHEN COL_LENGTH(@si_src,'AgeBracket') IS NOT NULL THEN 'AgeBracket'
               WHEN COL_LENGTH(@si_src,'age_bracket') IS NOT NULL THEN 'age_bracket'
               ELSE 'NULL' END + N' AS age_bracket,
      ' + CASE WHEN COL_LENGTH(@si_src,'Gender') IS NOT NULL THEN 'Gender'
               WHEN COL_LENGTH(@si_src,'gender') IS NOT NULL THEN 'gender'
               ELSE 'NULL' END + N' AS gender,
      ' + CASE WHEN COL_LENGTH(@si_src,'Emotion') IS NOT NULL THEN 'Emotion'
               WHEN COL_LENGTH(@si_src,'emotion') IS NOT NULL THEN 'emotion'
               ELSE 'NULL' END + N' AS emotion,
      ' + CASE WHEN COL_LENGTH(@si_src,'Confidence') IS NOT NULL THEN 'Confidence'
               WHEN COL_LENGTH(@si_src,'confidence_score') IS NOT NULL THEN 'confidence_score'
               ELSE 'NULL' END + N' AS confidence_score,
      ' + CASE WHEN COL_LENGTH(@si_src,'DeviceId') IS NOT NULL THEN 'DeviceId'
               WHEN COL_LENGTH(@si_src,'device_id') IS NOT NULL THEN 'device_id'
               ELSE 'NULL' END + N' AS device_id,
      ' + CASE WHEN COL_LENGTH(@si_src,'StoreID') IS NOT NULL THEN 'CAST(StoreID AS int)'
               WHEN COL_LENGTH(@si_src,'store_id') IS NOT NULL THEN 'CAST(store_id AS int)'
               ELSE 'NULL' END + N' AS store_id
    FROM ' + @si_src + N' WITH (NOLOCK);';
    EXEC sp_executesql @sql;
  END
END;
GO