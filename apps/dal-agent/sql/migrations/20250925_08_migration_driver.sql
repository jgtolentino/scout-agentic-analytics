SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* DRY RUN: row counts and dup diagnostics from staging */
CREATE OR ALTER PROCEDURE etl.sp_migration_dryrun
AS
BEGIN
  SET NOCOUNT ON;

  PRINT '== DRY RUN: staging counts ==';
  IF OBJECT_ID('analytics.v_stg_stores','V') IS NOT NULL      SELECT 'v_stg_stores' AS src, COUNT(*) AS rows FROM analytics.v_stg_stores;
  IF OBJECT_ID('analytics.v_stg_brands','V') IS NOT NULL      SELECT 'v_stg_brands' AS src, COUNT(*) AS rows FROM analytics.v_stg_brands;
  IF OBJECT_ID('analytics.v_stg_products','V') IS NOT NULL    SELECT 'v_stg_products' AS src, COUNT(*) AS rows FROM analytics.v_stg_products;
  IF OBJECT_ID('analytics.v_stg_transactions','V') IS NOT NULL SELECT 'v_stg_transactions' AS src, COUNT(*) AS rows FROM analytics.v_stg_transactions;
  IF OBJECT_ID('analytics.v_stg_transaction_items','V') IS NOT NULL SELECT 'v_stg_transaction_items' AS src, COUNT(*) AS rows FROM analytics.v_stg_transaction_items;
  IF OBJECT_ID('analytics.v_stg_sales_interactions','V') IS NOT NULL SELECT 'v_stg_sales_interactions' AS src, COUNT(*) AS rows FROM analytics.v_stg_sales_interactions;

  -- canonical_tx_id dup check
  IF OBJECT_ID('analytics.v_stg_transactions','V') IS NOT NULL
  BEGIN
    SELECT TOP 10 canonical_tx_id, COUNT(*) AS dup_cnt
    FROM analytics.v_stg_transactions
    WHERE canonical_tx_id IS NOT NULL AND LTRIM(RTRIM(canonical_tx_id)) <> ''
    GROUP BY canonical_tx_id
    HAVING COUNT(*) > 1
    ORDER BY dup_cnt DESC;
  END
END
GO

/* EXECUTE migration end-to-end */
CREATE OR ALTER PROCEDURE etl.sp_migration_execute
AS
BEGIN
  SET NOCOUNT ON;

  EXEC etl.sp_build_staging_views;

  -- 1) domain refs
  EXEC etl.sp_migrate_stores;
  EXEC etl.sp_migrate_brands;
  EXEC etl.sp_migrate_products;

  -- 2) facts in landing
  EXEC etl.sp_migrate_transactions;
  EXEC etl.sp_migrate_transaction_items;
  EXEC etl.sp_migrate_sales_interactions;

  -- 3) dedupe landing
  EXEC dbo.usp_dedupe_transactions;

  -- 4) load v2.0 facts/dims
  EXEC etl.sp_upsert_dim_brands;
  EXEC etl.sp_upsert_dim_products;
  EXEC etl.sp_load_fact_transactions;
  EXEC etl.sp_load_fact_transaction_items;
END
GO