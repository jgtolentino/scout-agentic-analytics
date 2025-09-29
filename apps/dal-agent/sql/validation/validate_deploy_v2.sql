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
DECLARE @gold_objs INT = (
  SELECT COUNT(*) FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
  WHERE s.name='gold' AND o.type IN ('U','V')
);
DECLARE @plat_objs INT = (
  SELECT COUNT(*) FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
  WHERE s.name='platinum' AND o.type IN ('U','V')
);

-- === Core tables/views presence ===
DECLARE @gold_core_ok BIT = IIF(
  OBJECT_ID('gold.dim_store') IS NOT NULL AND
  OBJECT_ID('gold.dim_brand') IS NOT NULL AND
  OBJECT_ID('gold.dim_category') IS NOT NULL AND
  (OBJECT_ID('gold.fact_transactions','U') IS NOT NULL OR OBJECT_ID('gold.fact_transactions','V') IS NOT NULL) AND
  (OBJECT_ID('gold.mart_transactions','U') IS NOT NULL OR OBJECT_ID('gold.mart_transactions','V') IS NOT NULL),
1,0);

DECLARE @platinum_ok BIT = IIF(
  OBJECT_ID('platinum.model_registry','U') IS NOT NULL AND
  OBJECT_ID('platinum.model_version','U')  IS NOT NULL AND
  OBJECT_ID('platinum.model_metric','U')   IS NOT NULL AND
  OBJECT_ID('platinum.features','U')       IS NOT NULL AND
  OBJECT_ID('platinum.predictions','U')    IS NOT NULL AND
  OBJECT_ID('platinum.insights','U')       IS NOT NULL,
1,0);

-- === Governance + Config ===
DECLARE @gov_ok BIT = IIF(OBJECT_ID('dbo.etl_execution_log','U') IS NOT NULL AND OBJECT_ID('dbo.data_quality_metrics','U') IS NOT NULL, 1, 0);
DECLARE @read_mode NVARCHAR(50) = (SELECT TOP 1 [value] FROM dbo.AppConfig WHERE [key]='READ_MODE');

-- === Optional views ===
DECLARE @has_basket BIT = IIF(OBJECT_ID('gold.market_basket_analysis','V') IS NULL, 0, 1);
DECLARE @has_n_cat  BIT = IIF(OBJECT_ID('gold.nielsen_category_metrics','V') IS NULL, 0, 1);
DECLARE @has_n_brand BIT= IIF(OBJECT_ID('gold.nielsen_brand_metrics','V')  IS NULL, 0, 1);
DECLARE @has_persona BIT= IIF(OBJECT_ID('dbo.v_persona_inference_v21','V') IS NULL, 0, 1);

-- === Freshness ===
DECLARE @last7d_gold BIGINT  = (SELECT COUNT(*) FROM gold.mart_transactions WHERE transaction_date >= DATEADD(DAY,-7, CAST(GETDATE() AS DATE)));
DECLARE @last24h_pred BIGINT = (SELECT COUNT(*) FROM platinum.predictions WHERE pred_date >= DATEADD(HOUR,-24, SYSUTCDATETIME()));

-- === Index sanity ===
DECLARE @ix_pred_subject   BIT = IIF(EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_pred_subject'   AND object_id=OBJECT_ID('platinum.predictions')),1,0);
DECLARE @ix_insight_entity BIT = IIF(EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_insight_entity' AND object_id=OBJECT_ID('platinum.insights')),1,0);

-- === Persona coverage (conditional, 7d) ===
DECLARE @persona_cov_pct DECIMAL(9,2)=NULL, @persona_cov_ok BIT=NULL;
IF @has_persona=1
BEGIN
  DECLARE @since DATE = DATEADD(DAY,-7, CAST(GETDATE() AS DATE));
  WITH T AS (SELECT DISTINCT canonical_tx_id FROM gold.mart_transactions WHERE transaction_date>=@since),
       P AS (SELECT DISTINCT subject_key FROM platinum.predictions WHERE subject_type='tx' AND pred_date>=@since AND label LIKE 'persona:%')
  SELECT @persona_cov_pct = CASE WHEN COUNT(*)=0 THEN 100.0
                                 ELSE 100.0 * SUM(CASE WHEN canonical_tx_id IN (SELECT subject_key FROM P) THEN 1 ELSE 0 END) / COUNT(*) END
  FROM T;
  SET @persona_cov_ok = IIF(@persona_cov_pct >= 95,1,0);
END;

-- === Emit single JSON row
SELECT
  @schemas_ok AS schemas_ok,
  @has_bronze AS has_bronze,
  @has_silver AS has_silver,
  @has_gold   AS has_gold,
  @has_plat   AS has_platinum,
  @has_dbo    AS has_dbo,
  @gold_objs  AS gold_object_count,
  @plat_objs  AS platinum_object_count,
  @gold_core_ok AS gold_core_ok,
  @platinum_ok  AS platinum_core_ok,
  @gov_ok       AS governance_ok,
  @read_mode    AS read_mode,
  @last7d_gold  AS gold_last7d_rows,
  @last24h_pred AS predictions_last24h_rows,
  @ix_pred_subject   AS ix_predictions_subject_ok,
  @ix_insight_entity AS ix_insights_entity_ok,
  @has_basket  AS has_market_basket_view,
  @has_n_cat   AS has_nielsen_category_metrics,
  @has_n_brand AS has_nielsen_brand_metrics,
  @persona_cov_pct AS persona_coverage_pct_last7d,
  @persona_cov_ok  AS persona_coverage_ok
FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;