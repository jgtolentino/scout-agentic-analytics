-- ========================================================================
-- Scout Analytics - Create Analytics Marts
-- File: 004_create_marts.sql
-- Purpose: Create all analytics views for tobacco, laundry, and store insights
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

SET NOCOUNT ON;

PRINT '📊 Creating analytics marts...';
PRINT '📅 Started: ' + CONVERT(varchar(20), GETDATE(), 120);
PRINT '';

-- ========================================================================
-- MART 1: STORE PROFILES & OVERALL DEMOGRAPHICS
-- ========================================================================

PRINT '🏪 Creating store profiles mart...';

CREATE OR ALTER VIEW mart.v_store_profiles AS
WITH txn AS (
  SELECT
    p.canonical_tx_id,
    p.store_id,
    p.store_name,
    si.age_bracket,
    si.gender,
    CAST(p.total_amount AS decimal(18,2)) AS sales
  FROM dbo.v_transactions_flat_production p
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = p.canonical_tx_id
)
SELECT
  store_id,
  MAX(store_name) AS store_name,
  COUNT(DISTINCT canonical_tx_id) AS txn_count,
  SUM(sales) AS sales_amount,
  -- demographic mix
  SUM(CASE WHEN gender='Male'   THEN 1 ELSE 0 END) AS male_txn,
  SUM(CASE WHEN gender='Female' THEN 1 ELSE 0 END) AS female_txn,
  COUNT(*) AS demo_rows
FROM txn
GROUP BY store_id;

PRINT '✅ Created mart.v_store_profiles';

-- ========================================================================
-- MART 2: DEMOGRAPHIC × BRAND × CATEGORY
-- ========================================================================

PRINT '👥 Creating demographics by brand/category mart...';

CREATE OR ALTER VIEW mart.v_demo_brand_cat AS
SELECT
  COALESCE(si.gender,'Unknown') AS gender,
  COALESCE(si.age_bracket,'Unknown') AS age_bracket,
  COALESCE(p.brand,'Unspecified') AS brand,
  COALESCE(p.category,'Unspecified') AS category,
  COUNT(DISTINCT p.canonical_tx_id) AS txn
FROM dbo.v_transactions_flat_production p
LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = p.canonical_tx_id
GROUP BY si.gender, si.age_bracket, p.brand, p.category;

PRINT '✅ Created mart.v_demo_brand_cat';

-- ========================================================================
-- MART 3: TIME SPREADS (WEEK/MONTH & DAYPART × CATEGORY)
-- ========================================================================

PRINT '📅 Creating time spreads mart...';

CREATE OR ALTER VIEW mart.v_time_spreads AS
WITH t AS (
  SELECT
    p.canonical_tx_id,
    si.TransactionDate AS ts,                       -- authoritative timestamp
    DATENAME(WEEKDAY, si.TransactionDate) AS weekday_name,
    FORMAT(si.TransactionDate,'yyyy-MM') AS yyyymm,
    CASE
      WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 5 AND 11  THEN 'Morning'
      WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 12 AND 17 THEN 'Afternoon'
      WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 18 AND 22 THEN 'Evening'
      ELSE 'Night'
    END AS daypart,
    p.category
  FROM dbo.v_transactions_flat_production p
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = p.canonical_tx_id
)
SELECT
  yyyymm, weekday_name, daypart, category,
  COUNT(DISTINCT canonical_tx_id) AS txn
FROM t
GROUP BY yyyymm, weekday_name, daypart, category;

PRINT '✅ Created mart.v_time_spreads';

-- ========================================================================
-- MART 4: TOBACCO METRICS (STICKS PER VISIT & CO-PURCHASES)
-- ========================================================================

PRINT '🚬 Creating tobacco metrics mart...';

CREATE OR ALTER VIEW mart.v_tobacco_metrics AS
WITH tob AS (
  SELECT
    p.canonical_tx_id,
    p.store_id,
    p.brand,
    ti.sku,
    ti.quantity,
    si.TransactionDate
  FROM dbo.v_transactions_flat_production p
  JOIN dbo.TransactionItems ti ON ti.canonical_tx_id = p.canonical_tx_id
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = p.canonical_tx_id
  WHERE UPPER(p.category) IN ('TOBACCO','CIGARETTES','CIGARETTE','SMOKES')
),
calc AS (
  SELECT
    t.canonical_tx_id,
    t.store_id,
    t.brand,
    t.TransactionDate,
    SUM(COALESCE(t.quantity,1) * COALESCE(r.sticks_per_pack, 1)) AS sticks_bought
  FROM tob t
  LEFT JOIN ref.tobacco_pack_specs r
    ON UPPER(r.brand) = UPPER(t.brand)
    AND (r.sku IS NULL OR r.sku = t.sku)
  GROUP BY t.canonical_tx_id, t.store_id, t.brand, t.TransactionDate
)
SELECT
  store_id,
  COUNT(DISTINCT canonical_tx_id) AS tobacco_txn,
  AVG(CAST(sticks_bought AS float)) AS avg_sticks_per_visit
FROM calc
GROUP BY store_id;

PRINT '✅ Created mart.v_tobacco_metrics';

-- Create tobacco co-purchases mart
PRINT '🚬 Creating tobacco co-purchases mart...';

CREATE OR ALTER VIEW mart.v_tobacco_copurchases AS
WITH tob_tx AS (
  SELECT DISTINCT canonical_tx_id
  FROM dbo.v_transactions_flat_production
  WHERE UPPER(category) IN ('TOBACCO','CIGARETTES','CIGARETTE','SMOKES')
),
others AS (
  SELECT
    ti.canonical_tx_id,
    UPPER(LTRIM(RTRIM(COALESCE(ti.brand,'')))) AS co_brand,
    UPPER(LTRIM(RTRIM(COALESCE(ti.category,'')))) AS co_category
  FROM dbo.TransactionItems ti
  JOIN tob_tx t ON t.canonical_tx_id = ti.canonical_tx_id
  WHERE UPPER(COALESCE(ti.category,'')) NOT IN ('TOBACCO','CIGARETTES','CIGARETTE','SMOKES')
)
SELECT
  co_brand,
  co_category,
  COUNT(DISTINCT canonical_tx_id) AS tx
FROM others
WHERE co_brand != '' OR co_category != ''
GROUP BY co_brand, co_category;

PRINT '✅ Created mart.v_tobacco_copurchases';

-- ========================================================================
-- MART 5: LAUNDRY METRICS (DETERGENT FORM & FABCON ATTACH)
-- ========================================================================

PRINT '🧼 Creating laundry metrics mart...';

CREATE OR ALTER VIEW mart.v_laundry_metrics AS
WITH l AS (
  SELECT
    p.canonical_tx_id,
    p.brand,
    ti.sku,
    si.TransactionDate
  FROM dbo.v_transactions_flat_production p
  JOIN dbo.TransactionItems ti ON ti.canonical_tx_id = p.canonical_tx_id
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = p.canonical_tx_id
  WHERE UPPER(p.category) IN ('LAUNDRY SOAP','LAUNDRY','DETERGENT','SOAP')
),
form AS (
  SELECT
    l.canonical_tx_id,
    MAX(ds.detergent_form) AS detergent_form
  FROM l
  LEFT JOIN ref.detergent_specs ds
    ON UPPER(ds.brand) = UPPER(l.brand)
    AND (ds.sku IS NULL OR ds.sku = l.sku)
  GROUP BY l.canonical_tx_id
),
fabcon AS (
  SELECT
    ti.canonical_tx_id,
    MAX(CASE
      WHEN UPPER(LTRIM(RTRIM(ti.category))) IN ('FABCON','FABRIC CONDITIONER','CONDITIONER','SOFTENER')
      THEN 1 ELSE 0
    END) AS has_fabcon
  FROM dbo.TransactionItems ti
  GROUP BY ti.canonical_tx_id
)
SELECT
  COALESCE(f.detergent_form, 'Unknown') AS detergent_form,
  SUM(CASE WHEN fab.has_fabcon = 1 THEN 1 ELSE 0 END) AS tx_with_fabcon,
  COUNT(*) AS total_laundry_tx,
  CAST(SUM(CASE WHEN fab.has_fabcon = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS decimal(5,2)) AS fabcon_attach_rate
FROM form f
LEFT JOIN fabcon fab ON fab.canonical_tx_id = f.canonical_tx_id
GROUP BY f.detergent_form;

PRINT '✅ Created mart.v_laundry_metrics';

-- ========================================================================
-- MART 6: TRANSCRIPT TERM MINING
-- ========================================================================

PRINT '📝 Creating transcript term mining mart...';

CREATE OR ALTER VIEW mart.v_transcript_terms AS
WITH t AS (
  SELECT
    canonical_tx_id,
    txt = LOWER(REPLACE(REPLACE(REPLACE(REPLACE(
      transcript_text,
      CHAR(10),' '),
      CHAR(13),' '),
      '.',' '),
      ',',' '))
  FROM dbo.SalesInteractionTranscripts
  WHERE NULLIF(LTRIM(RTRIM(transcript_text)),'') IS NOT NULL
),
lex AS (
  SELECT term_type, phrase, weight
  FROM ref.term_dictionary
),
hits AS (
  SELECT
    t.canonical_tx_id,
    l.term_type,
    l.phrase,
    l.weight
  FROM t
  JOIN lex l ON CHARINDEX(' ' + LOWER(l.phrase) + ' ', ' ' + t.txt + ' ') > 0
)
SELECT
  term_type,
  phrase,
  COUNT(DISTINCT canonical_tx_id) AS baskets,
  SUM(weight) AS score
FROM hits
GROUP BY term_type, phrase;

PRINT '✅ Created mart.v_transcript_terms';

-- ========================================================================
-- GRANT PERMISSIONS
-- ========================================================================

PRINT '';
PRINT '🔐 Setting up permissions...';

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rpt_reader')
BEGIN
    GRANT SELECT ON mart.v_store_profiles TO rpt_reader;
    GRANT SELECT ON mart.v_demo_brand_cat TO rpt_reader;
    GRANT SELECT ON mart.v_time_spreads TO rpt_reader;
    GRANT SELECT ON mart.v_tobacco_metrics TO rpt_reader;
    GRANT SELECT ON mart.v_tobacco_copurchases TO rpt_reader;
    GRANT SELECT ON mart.v_laundry_metrics TO rpt_reader;
    GRANT SELECT ON mart.v_transcript_terms TO rpt_reader;
    PRINT '✅ Granted SELECT permissions to rpt_reader for all marts';
END
ELSE
BEGIN
    PRINT '⚠️ rpt_reader role not found - permissions not granted';
END

-- ========================================================================
-- VALIDATION
-- ========================================================================

PRINT '';
PRINT '🔍 Validating mart creation...';

DECLARE @marts_created int = 0;

IF OBJECT_ID('mart.v_store_profiles', 'V') IS NOT NULL SET @marts_created = @marts_created + 1;
IF OBJECT_ID('mart.v_demo_brand_cat', 'V') IS NOT NULL SET @marts_created = @marts_created + 1;
IF OBJECT_ID('mart.v_time_spreads', 'V') IS NOT NULL SET @marts_created = @marts_created + 1;
IF OBJECT_ID('mart.v_tobacco_metrics', 'V') IS NOT NULL SET @marts_created = @marts_created + 1;
IF OBJECT_ID('mart.v_tobacco_copurchases', 'V') IS NOT NULL SET @marts_created = @marts_created + 1;
IF OBJECT_ID('mart.v_laundry_metrics', 'V') IS NOT NULL SET @marts_created = @marts_created + 1;
IF OBJECT_ID('mart.v_transcript_terms', 'V') IS NOT NULL SET @marts_created = @marts_created + 1;

PRINT '📊 Marts created: ' + CAST(@marts_created AS varchar(10)) + ' of 7';

IF @marts_created = 7
BEGIN
    PRINT '✅ All analytics marts created successfully:';
    PRINT '   ✓ mart.v_store_profiles';
    PRINT '   ✓ mart.v_demo_brand_cat';
    PRINT '   ✓ mart.v_time_spreads';
    PRINT '   ✓ mart.v_tobacco_metrics';
    PRINT '   ✓ mart.v_tobacco_copurchases';
    PRINT '   ✓ mart.v_laundry_metrics';
    PRINT '   ✓ mart.v_transcript_terms';
    PRINT '';
    PRINT '✅ Analytics marts creation validation PASSED';
END
ELSE
BEGIN
    PRINT '❌ Analytics marts creation validation FAILED';
    PRINT '   Expected 7 marts, found ' + CAST(@marts_created AS varchar(10));
    THROW 50004, 'Analytics marts creation validation failed', 1;
END

PRINT '';
PRINT '🎉 Analytics marts ready for business insights!';
PRINT '📅 Finished: ' + CONVERT(varchar(20), GETDATE(), 120);

GO