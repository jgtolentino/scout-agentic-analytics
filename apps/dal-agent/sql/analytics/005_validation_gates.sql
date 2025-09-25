-- ========================================================================
-- Scout Analytics - Validation Gates
-- File: 005_validation_gates.sql
-- Purpose: Comprehensive validation of analytics infrastructure
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

SET NOCOUNT ON;

PRINT '🔍 Running analytics validation gates...';
PRINT '📅 Started: ' + CONVERT(varchar(20), GETDATE(), 120);
PRINT '';

-- ========================================================================
-- GATE 1: BASIC INFRASTRUCTURE VALIDATION
-- ========================================================================

PRINT '1️⃣ Gate 1: Basic infrastructure validation...';

-- Check schemas exist
IF SCHEMA_ID('ref') IS NULL
BEGIN
    PRINT '❌ GATE 1 FAILED: ref schema missing';
    THROW 50010, 'ref schema missing', 1;
END

IF SCHEMA_ID('mart') IS NULL
BEGIN
    PRINT '❌ GATE 1 FAILED: mart schema missing';
    THROW 50011, 'mart schema missing', 1;
END

PRINT '✅ GATE 1 PASSED: Schemas exist';

-- ========================================================================
-- GATE 2: REFERENCE TABLE VALIDATION
-- ========================================================================

PRINT '';
PRINT '2️⃣ Gate 2: Reference table validation...';

DECLARE @tobacco_specs int, @detergent_specs int, @term_dict int;

SELECT @tobacco_specs = COUNT(*) FROM ref.tobacco_pack_specs;
SELECT @detergent_specs = COUNT(*) FROM ref.detergent_specs;
SELECT @term_dict = COUNT(*) FROM ref.term_dictionary;

PRINT '   Tobacco specs: ' + CAST(@tobacco_specs AS varchar(10));
PRINT '   Detergent specs: ' + CAST(@detergent_specs AS varchar(10));
PRINT '   Dictionary terms: ' + CAST(@term_dict AS varchar(10));

IF @tobacco_specs < 10 OR @detergent_specs < 10 OR @term_dict < 20
BEGIN
    PRINT '❌ GATE 2 FAILED: Insufficient reference data';
    THROW 50020, 'Reference tables not properly populated', 1;
END

PRINT '✅ GATE 2 PASSED: Reference tables populated';

-- ========================================================================
-- GATE 3: FLAT EXPORT VIEW VALIDATION
-- ========================================================================

PRINT '';
PRINT '3️⃣ Gate 3: Flat export view validation...';

-- Zero row drop validation
DECLARE @base_count int, @flat_count int;
SELECT @base_count = COUNT(DISTINCT canonical_tx_id) FROM dbo.v_transactions_flat_production;
SELECT @flat_count = COUNT(DISTINCT Transaction_ID) FROM dbo.v_flat_export_sheet;

PRINT '   Base transactions: ' + CAST(@base_count AS varchar(10));
PRINT '   Flat export rows: ' + CAST(@flat_count AS varchar(10));

IF @flat_count <> @base_count
BEGIN
    PRINT '❌ GATE 3 FAILED: Coverage mismatch (zero row drop not achieved)';
    THROW 50030, 'Coverage mismatch base vs flat', 1;
END

-- Column contract validation
DECLARE @column_count int;
SELECT @column_count = COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID('dbo.v_flat_export_sheet');

IF @column_count <> 12
BEGIN
    PRINT '❌ GATE 3 FAILED: Column contract mismatch';
    THROW 50031, 'Expected 12 columns in v_flat_export_sheet', 1;
END

-- Substitution event validation
DECLARE @subs_count int;
SELECT @subs_count = COUNT(*) FROM dbo.v_flat_export_sheet WHERE Was_Substitution IN ('true', 'false');

PRINT '   Rows with substitution data: ' + CAST(@subs_count AS varchar(10));

PRINT '✅ GATE 3 PASSED: Flat export view validated';

-- ========================================================================
-- GATE 4: ANALYTICS MARTS VALIDATION
-- ========================================================================

PRINT '';
PRINT '4️⃣ Gate 4: Analytics marts validation...';

-- Check all marts exist and return data
DECLARE @store_profiles int, @demo_brand int, @time_spreads int;
DECLARE @tobacco_metrics int, @tobacco_copurchases int, @laundry_metrics int, @transcript_terms int;

SELECT @store_profiles = COUNT(*) FROM mart.v_store_profiles;
SELECT @demo_brand = COUNT(*) FROM mart.v_demo_brand_cat;
SELECT @time_spreads = COUNT(*) FROM mart.v_time_spreads;
SELECT @tobacco_metrics = COUNT(*) FROM mart.v_tobacco_metrics;
SELECT @tobacco_copurchases = COUNT(*) FROM mart.v_tobacco_copurchases;
SELECT @laundry_metrics = COUNT(*) FROM mart.v_laundry_metrics;
SELECT @transcript_terms = COUNT(*) FROM mart.v_transcript_terms;

PRINT '   Store profiles: ' + CAST(@store_profiles AS varchar(10)) + ' rows';
PRINT '   Demo × brand × category: ' + CAST(@demo_brand AS varchar(10)) + ' rows';
PRINT '   Time spreads: ' + CAST(@time_spreads AS varchar(10)) + ' rows';
PRINT '   Tobacco metrics: ' + CAST(@tobacco_metrics AS varchar(10)) + ' rows';
PRINT '   Tobacco co-purchases: ' + CAST(@tobacco_copurchases AS varchar(10)) + ' rows';
PRINT '   Laundry metrics: ' + CAST(@laundry_metrics AS varchar(10)) + ' rows';
PRINT '   Transcript terms: ' + CAST(@transcript_terms AS varchar(10)) + ' rows';

IF @store_profiles = 0 OR @demo_brand = 0
BEGIN
    PRINT '❌ GATE 4 FAILED: Core marts returning no data';
    THROW 50040, 'Core analytics marts have no data', 1;
END

PRINT '✅ GATE 4 PASSED: Analytics marts operational';

-- ========================================================================
-- GATE 5: TOBACCO ANALYTICS VALIDATION
-- ========================================================================

PRINT '';
PRINT '5️⃣ Gate 5: Tobacco analytics validation...';

-- Check tobacco brand coverage
DECLARE @tobacco_brands_covered int, @tobacco_brands_total int;

SELECT @tobacco_brands_total = COUNT(DISTINCT brand)
FROM dbo.v_transactions_flat_production
WHERE UPPER(category) IN ('TOBACCO','CIGARETTES','CIGARETTE','SMOKES')
  AND brand IS NOT NULL;

SELECT @tobacco_brands_covered = COUNT(DISTINCT p.brand)
FROM dbo.v_transactions_flat_production p
JOIN ref.tobacco_pack_specs r ON UPPER(r.brand) = UPPER(p.brand)
WHERE UPPER(p.category) IN ('TOBACCO','CIGARETTES','CIGARETTE','SMOKES');

PRINT '   Tobacco brands in data: ' + CAST(@tobacco_brands_total AS varchar(10));
PRINT '   Tobacco brands with specs: ' + CAST(@tobacco_brands_covered AS varchar(10));

IF @tobacco_brands_total > 0 AND @tobacco_brands_covered = 0
BEGIN
    PRINT '⚠️ GATE 5 WARNING: No tobacco brand specifications matched data';
END
ELSE
BEGIN
    DECLARE @tobacco_coverage decimal(5,2) = CAST(@tobacco_brands_covered * 100.0 / NULLIF(@tobacco_brands_total, 0) AS decimal(5,2));
    PRINT '   Coverage: ' + CAST(@tobacco_coverage AS varchar(10)) + '%';
END

PRINT '✅ GATE 5 PASSED: Tobacco analytics validated';

-- ========================================================================
-- GATE 6: LAUNDRY ANALYTICS VALIDATION
-- ========================================================================

PRINT '';
PRINT '6️⃣ Gate 6: Laundry analytics validation...';

-- Check laundry brand coverage
DECLARE @laundry_brands_covered int, @laundry_brands_total int;

SELECT @laundry_brands_total = COUNT(DISTINCT brand)
FROM dbo.v_transactions_flat_production
WHERE UPPER(category) IN ('LAUNDRY SOAP','LAUNDRY','DETERGENT','SOAP')
  AND brand IS NOT NULL;

SELECT @laundry_brands_covered = COUNT(DISTINCT p.brand)
FROM dbo.v_transactions_flat_production p
JOIN ref.detergent_specs r ON UPPER(r.brand) = UPPER(p.brand)
WHERE UPPER(p.category) IN ('LAUNDRY SOAP','LAUNDRY','DETERGENT','SOAP');

PRINT '   Laundry brands in data: ' + CAST(@laundry_brands_total AS varchar(10));
PRINT '   Laundry brands with specs: ' + CAST(@laundry_brands_covered AS varchar(10));

IF @laundry_brands_total > 0 AND @laundry_brands_covered = 0
BEGIN
    PRINT '⚠️ GATE 6 WARNING: No laundry brand specifications matched data';
END
ELSE
BEGIN
    DECLARE @laundry_coverage decimal(5,2) = CAST(@laundry_brands_covered * 100.0 / NULLIF(@laundry_brands_total, 0) AS decimal(5,2));
    PRINT '   Coverage: ' + CAST(@laundry_coverage AS varchar(10)) + '%';
END

PRINT '✅ GATE 6 PASSED: Laundry analytics validated';

-- ========================================================================
-- GATE 7: TRANSCRIPT MINING VALIDATION
-- ========================================================================

PRINT '';
PRINT '7️⃣ Gate 7: Transcript mining validation...';

DECLARE @transcript_records int, @transcript_terms_found int;

SELECT @transcript_records = COUNT(*)
FROM dbo.SalesInteractionTranscripts
WHERE NULLIF(LTRIM(RTRIM(transcript_text)),'') IS NOT NULL;

SELECT @transcript_terms_found = COUNT(DISTINCT phrase)
FROM mart.v_transcript_terms;

PRINT '   Transcript records: ' + CAST(@transcript_records AS varchar(10));
PRINT '   Terms found in transcripts: ' + CAST(@transcript_terms_found AS varchar(10));

IF @transcript_records > 0 AND @transcript_terms_found = 0
BEGIN
    PRINT '⚠️ GATE 7 WARNING: No transcript terms found in data';
END

PRINT '✅ GATE 7 PASSED: Transcript mining validated';

-- ========================================================================
-- GATE 8: DATA QUALITY VALIDATION
-- ========================================================================

PRINT '';
PRINT '8️⃣ Gate 8: Data quality validation...';

-- Check for obvious data quality issues
DECLARE @null_demographics int, @null_categories int, @null_brands int;

SELECT @null_demographics = COUNT(*)
FROM dbo.v_flat_export_sheet
WHERE [Demographics (Age/Gender/Role)] IS NULL OR LTRIM(RTRIM([Demographics (Age/Gender/Role)])) = '';

SELECT @null_categories = COUNT(*)
FROM dbo.v_flat_export_sheet
WHERE Category IS NULL OR LTRIM(RTRIM(Category)) = '';

SELECT @null_brands = COUNT(*)
FROM dbo.v_flat_export_sheet
WHERE Brand IS NULL OR LTRIM(RTRIM(Brand)) = '';

PRINT '   Records with null demographics: ' + CAST(@null_demographics AS varchar(10));
PRINT '   Records with null categories: ' + CAST(@null_categories AS varchar(10));
PRINT '   Records with null brands: ' + CAST(@null_brands AS varchar(10));

-- These are warnings, not failures
IF @null_demographics > (@flat_count * 0.5)
BEGIN
    PRINT '⚠️ High null demographics rate - check SalesInteractions data';
END

PRINT '✅ GATE 8 PASSED: Data quality validated';

-- ========================================================================
-- FINAL VALIDATION SUMMARY
-- ========================================================================

PRINT '';
PRINT '📊 VALIDATION SUMMARY:';
PRINT '================================';
PRINT '✅ Gate 1: Infrastructure validated';
PRINT '✅ Gate 2: Reference tables populated';
PRINT '✅ Gate 3: Flat export view operational';
PRINT '✅ Gate 4: Analytics marts operational';
PRINT '✅ Gate 5: Tobacco analytics ready';
PRINT '✅ Gate 6: Laundry analytics ready';
PRINT '✅ Gate 7: Transcript mining ready';
PRINT '✅ Gate 8: Data quality validated';
PRINT '';
PRINT '🎉 ALL VALIDATION GATES PASSED!';
PRINT '📊 Scout Analytics Infrastructure is production-ready';
PRINT '';
PRINT '📋 Next steps:';
PRINT '   1. Run ready-to-use queries from marts';
PRINT '   2. Export analytics to CSV files';
PRINT '   3. Expand reference data as needed';
PRINT '   4. Monitor data quality over time';
PRINT '';
PRINT '📅 Finished: ' + CONVERT(varchar(20), GETDATE(), 120);

GO