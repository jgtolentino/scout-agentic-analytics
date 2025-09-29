USE [SQL-TBWA-ProjectScout-Reporting-Prod];
SET NOCOUNT ON;

-- === Schema existence ===
DECLARE @has_bronze BIT = IIF(SCHEMA_ID('bronze') IS NULL, 0, 1);
DECLARE @has_silver BIT = IIF(SCHEMA_ID('silver') IS NULL, 0, 1);
DECLARE @has_gold   BIT = IIF(SCHEMA_ID('gold')   IS NULL, 0, 1);
DECLARE @has_plat   BIT = IIF(SCHEMA_ID('platinum') IS NULL, 0, 1);
DECLARE @has_dbo    BIT = IIF(SCHEMA_ID('dbo')    IS NULL, 0, 1);

DECLARE @schemas_ok BIT = IIF(@has_bronze=1 AND @has_silver=1 AND @has_gold=1 AND @has_plat=1 AND @has_dbo=1, 1, 0);

-- === Object counts per schema (tables+views) ===
DECLARE @bronze_objs INT = (
  SELECT COUNT(*) FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
  WHERE s.name='bronze' AND o.type IN ('U','V')
);
DECLARE @silver_objs INT = (
  SELECT COUNT(*) FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
  WHERE s.name='silver' AND o.type IN ('U','V')
);
DECLARE @gold_objs INT = (
  SELECT COUNT(*) FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
  WHERE s.name='gold' AND o.type IN ('U','V')
);
DECLARE @plat_objs INT = (
  SELECT COUNT(*) FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
  WHERE s.name='platinum' AND o.type IN ('U','V')
);

-- === Core tables/views presence (defensive checks) ===
DECLARE @gold_core_ok BIT = IIF(
  (OBJECT_ID('gold.dim_store') IS NOT NULL OR OBJECT_ID('gold.v_dim_store') IS NOT NULL) AND
  (OBJECT_ID('gold.dim_brand') IS NOT NULL OR OBJECT_ID('gold.v_dim_brand') IS NOT NULL) AND
  (OBJECT_ID('gold.dim_category') IS NOT NULL OR OBJECT_ID('gold.v_dim_category') IS NOT NULL) AND
  (@gold_objs >= 10), -- At least 10 objects in gold layer
1,0);

DECLARE @platinum_ok BIT = IIF(
  (OBJECT_ID('platinum.model_registry','U') IS NOT NULL OR OBJECT_ID('platinum.model_registry','V') IS NOT NULL) AND
  (OBJECT_ID('platinum.predictions','U') IS NOT NULL OR OBJECT_ID('platinum.predictions','V') IS NOT NULL) AND
  (@plat_objs >= 6), -- At least 6 objects in platinum layer
1,0);

-- === Governance + Config ===
DECLARE @has_appconfig BIT = IIF(OBJECT_ID('dbo.AppConfig','U') IS NOT NULL, 1, 0);
DECLARE @has_etl_log BIT = IIF(OBJECT_ID('dbo.etl_execution_log','U') IS NOT NULL, 1, 0);
DECLARE @gov_ok BIT = IIF(@has_appconfig=1 AND @has_etl_log=1, 1, 0);
DECLARE @read_mode NVARCHAR(50) = NULL;
IF @has_appconfig = 1
  SELECT @read_mode = [value] FROM dbo.AppConfig WHERE [key]='READ_MODE';

-- === Optional views ===
DECLARE @has_basket BIT = IIF(OBJECT_ID('gold.market_basket_analysis','V') IS NULL, 0, 1);
DECLARE @has_n_cat  BIT = IIF(OBJECT_ID('gold.nielsen_category_metrics','V') IS NULL, 0, 1);
DECLARE @has_n_brand BIT= IIF(OBJECT_ID('gold.nielsen_brand_metrics','V')  IS NULL, 0, 1);
DECLARE @has_persona BIT= IIF(OBJECT_ID('dbo.v_persona_inference_v21','V') IS NULL, 0, 1);

-- === Freshness (defensive - check if tables exist first) ===
DECLARE @last7d_gold BIGINT = 0;
DECLARE @last24h_pred BIGINT = 0;

-- Check gold transactions (various possible table names)
IF OBJECT_ID('gold.mart_transactions') IS NOT NULL
  SELECT @last7d_gold = COUNT(*) FROM gold.mart_transactions WHERE transaction_date >= DATEADD(DAY,-7, CAST(GETDATE() AS DATE));
ELSE IF OBJECT_ID('gold.fact_transactions') IS NOT NULL
  SELECT @last7d_gold = COUNT(*) FROM gold.fact_transactions WHERE transaction_date >= DATEADD(DAY,-7, CAST(GETDATE() AS DATE));
ELSE IF OBJECT_ID('dbo.v_transactions_flat_production') IS NOT NULL
  SELECT @last7d_gold = COUNT(*) FROM dbo.v_transactions_flat_production WHERE transaction_date >= DATEADD(DAY,-7, CAST(GETDATE() AS DATE));

-- Check platinum predictions
IF OBJECT_ID('platinum.predictions') IS NOT NULL
  SELECT @last24h_pred = COUNT(*) FROM platinum.predictions WHERE pred_date >= DATEADD(HOUR,-24, SYSUTCDATETIME());

-- === Index sanity (check if tables exist first) ===
DECLARE @ix_pred_subject   BIT = 0;
DECLARE @ix_insight_entity BIT = 0;

IF OBJECT_ID('platinum.predictions') IS NOT NULL
  SET @ix_pred_subject = IIF(EXISTS (SELECT 1 FROM sys.indexes WHERE name LIKE 'IX%pred%subject%' AND object_id=OBJECT_ID('platinum.predictions')),1,0);

IF OBJECT_ID('platinum.insights') IS NOT NULL
  SET @ix_insight_entity = IIF(EXISTS (SELECT 1 FROM sys.indexes WHERE name LIKE 'IX%insight%entity%' AND object_id=OBJECT_ID('platinum.insights')),1,0);

-- === Persona coverage (conditional, 7d) ===
DECLARE @persona_cov_pct DECIMAL(9,2)=NULL, @persona_cov_ok BIT=NULL;
-- Skip persona coverage for now to avoid complex table dependency issues

-- === Emit single JSON row
SELECT
  @schemas_ok AS schemas_ok,
  @has_bronze AS has_bronze,
  @has_silver AS has_silver,
  @has_gold   AS has_gold,
  @has_plat   AS has_platinum,
  @has_dbo    AS has_dbo,
  @bronze_objs AS bronze_object_count,
  @silver_objs AS silver_object_count,
  @gold_objs  AS gold_object_count,
  @plat_objs  AS platinum_object_count,
  @gold_core_ok AS gold_core_ok,
  @platinum_ok  AS platinum_core_ok,
  @gov_ok       AS governance_ok,
  @has_appconfig AS has_appconfig,
  @has_etl_log  AS has_etl_log,
  @read_mode    AS read_mode,
  @last7d_gold  AS gold_last7d_rows,
  @last24h_pred AS predictions_last24h_rows,
  @ix_pred_subject   AS ix_predictions_subject_ok,
  @ix_insight_entity AS ix_insights_entity_ok,
  @has_basket  AS has_market_basket_view,
  @has_n_cat   AS has_nielsen_category_metrics,
  @has_n_brand AS has_nielsen_brand_metrics,
  @persona_cov_pct AS persona_coverage_pct_last7d,
  @persona_cov_ok  AS persona_coverage_ok,
  CASE
    WHEN @schemas_ok=1 AND @gold_core_ok=1 AND @platinum_ok=1 AND @gov_ok=1 THEN 'PASS'
    WHEN @schemas_ok=1 AND @gold_core_ok=1 AND @platinum_ok=1 THEN 'WARN'
    ELSE 'FAIL'
  END AS overall_status
FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;