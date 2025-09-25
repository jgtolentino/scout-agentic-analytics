-- ========================================================================
-- Scout Analytics - Cross-Tab Views (Absolute Counts)
-- File: 006_create_crosstabs.sql
-- Purpose: Creates 16 cross-tabulation views for multi-dimensional analysis
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

SET NOCOUNT ON;

PRINT '📊 Creating cross-tab analytics views...';
PRINT '📅 Started: ' + CONVERT(varchar(20), GETDATE(), 120);
PRINT '';

-- ========================================================================
-- HELPER FUNCTION: BASKET SIZE BUCKETS
-- ========================================================================

PRINT '🧮 Creating basket bucket function...';

CREATE OR ALTER FUNCTION dbo.fn_basket_bucket(@n int)
RETURNS varchar(16) AS
BEGIN
  RETURN (CASE
            WHEN @n IS NULL THEN 'n/a'
            WHEN @n <= 2 THEN '1-2'
            WHEN @n <= 5 THEN '3-5'
            WHEN @n <= 8 THEN '6-8'
            ELSE '9+'
          END);
END;
GO

PRINT '✅ Created dbo.fn_basket_bucket';

-- ========================================================================
-- BASE CTE FOR ALL CROSS-TABS (Single-key join strategy)
-- ========================================================================

PRINT '';
PRINT '🔗 Establishing base data source with single-key joins...';

-- Note: We use a CTE pattern in each view for clarity and performance
-- Base pulls from v_transactions_flat_production with LEFT JOIN to SalesInteractions

-- ========================================================================
-- TIME-BASED CROSS-TABS (1-4)
-- ========================================================================

PRINT '';
PRINT '⏰ Creating time-based cross-tabs...';

-- 1) Time of Day × Category
CREATE OR ALTER VIEW ct_timeXcategory AS
WITH base AS (
  SELECT
    t.canonical_tx_id,
    COALESCE(si.Daypart, 'Unknown') AS Daypart,
    COALESCE(t.category, 'Unspecified') AS Category
  FROM dbo.v_transactions_flat_production t
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = t.canonical_tx_id
)
SELECT Daypart, Category, COUNT(DISTINCT canonical_tx_id) AS tx
FROM base
GROUP BY Daypart, Category;
GO

-- 2) Time of Day × Brand
CREATE OR ALTER VIEW ct_timeXbrand AS
WITH base AS (
  SELECT
    t.canonical_tx_id,
    COALESCE(si.Daypart, 'Unknown') AS Daypart,
    COALESCE(t.brand, 'Unspecified') AS Brand
  FROM dbo.v_transactions_flat_production t
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = t.canonical_tx_id
)
SELECT Daypart, Brand, COUNT(DISTINCT canonical_tx_id) AS tx
FROM base
GROUP BY Daypart, Brand;
GO

-- 3) Time of Day × Demographics
CREATE OR ALTER VIEW ct_timeXdemographics AS
WITH base AS (
  SELECT
    t.canonical_tx_id,
    COALESCE(si.Daypart, 'Unknown') AS Daypart,
    COALESCE(si.AgeBracket, 'Unknown') AS AgeBracket,
    COALESCE(si.Gender, 'Unknown') AS Gender,
    COALESCE(si.CustomerType, 'Unknown') AS CustomerType
  FROM dbo.v_transactions_flat_production t
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = t.canonical_tx_id
)
SELECT Daypart, AgeBracket, Gender, CustomerType, COUNT(DISTINCT canonical_tx_id) AS tx
FROM base
GROUP BY Daypart, AgeBracket, Gender, CustomerType;
GO

-- 4) Time of Day × Emotions
CREATE OR ALTER VIEW ct_timeXemotions AS
WITH base AS (
  SELECT
    t.canonical_tx_id,
    COALESCE(si.Daypart, 'Unknown') AS Daypart,
    COALESCE(si.EmotionalState, 'Unknown') AS Emotions
  FROM dbo.v_transactions_flat_production t
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = t.canonical_tx_id
)
SELECT Daypart, Emotions, COUNT(DISTINCT canonical_tx_id) AS tx
FROM base
GROUP BY Daypart, Emotions;
GO

PRINT '✅ Created time-based cross-tabs (4 views)';

-- ========================================================================
-- BASKET SIZE CROSS-TABS (5-8)
-- ========================================================================

PRINT '';
PRINT '🛒 Creating basket size cross-tabs...';

-- 5) Basket Size × Category
CREATE OR ALTER VIEW ct_basketsizeXcategory AS
WITH base AS (
  SELECT
    t.canonical_tx_id,
    dbo.fn_basket_bucket(t.total_items) AS Basket_Size_Bucket,
    COALESCE(t.category, 'Unspecified') AS Category
  FROM dbo.v_transactions_flat_production t
)
SELECT Basket_Size_Bucket, Category, COUNT(DISTINCT canonical_tx_id) AS tx
FROM base
GROUP BY Basket_Size_Bucket, Category;
GO

-- 6) Basket Size × Payment Method
CREATE OR ALTER VIEW ct_basketsizeXpayment AS
WITH base AS (
  SELECT
    t.canonical_tx_id,
    dbo.fn_basket_bucket(t.total_items) AS Basket_Size_Bucket,
    COALESCE(si.PaymentMethod, 'Unknown') AS PaymentMethod
  FROM dbo.v_transactions_flat_production t
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = t.canonical_tx_id
)
SELECT Basket_Size_Bucket, PaymentMethod, COUNT(DISTINCT canonical_tx_id) AS tx
FROM base
GROUP BY Basket_Size_Bucket, PaymentMethod;
GO

-- 7) Basket Size × Customer Type
CREATE OR ALTER VIEW ct_basketsizeXcustomer AS
WITH base AS (
  SELECT
    t.canonical_tx_id,
    dbo.fn_basket_bucket(t.total_items) AS Basket_Size_Bucket,
    COALESCE(si.CustomerType, 'Unknown') AS CustomerType
  FROM dbo.v_transactions_flat_production t
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = t.canonical_tx_id
)
SELECT Basket_Size_Bucket, CustomerType, COUNT(DISTINCT canonical_tx_id) AS tx
FROM base
GROUP BY Basket_Size_Bucket, CustomerType;
GO

-- 8) Basket Size × Emotions
CREATE OR ALTER VIEW ct_basketsizeXemotions AS
WITH base AS (
  SELECT
    t.canonical_tx_id,
    dbo.fn_basket_bucket(t.total_items) AS Basket_Size_Bucket,
    COALESCE(si.EmotionalState, 'Unknown') AS Emotions
  FROM dbo.v_transactions_flat_production t
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = t.canonical_tx_id
)
SELECT Basket_Size_Bucket, Emotions, COUNT(DISTINCT canonical_tx_id) AS tx
FROM base
GROUP BY Basket_Size_Bucket, Emotions;
GO

PRINT '✅ Created basket size cross-tabs (4 views)';

-- ========================================================================
-- SUBSTITUTION/SUGGESTION CROSS-TABS (9-11)
-- ========================================================================

PRINT '';
PRINT '🔄 Creating substitution/suggestion cross-tabs...';

-- 9) Substitution Event × Category
CREATE OR ALTER VIEW ct_substitutionXcategory AS
WITH base AS (
  SELECT
    t.canonical_tx_id,
    COALESCE(t.category, 'Unspecified') AS Category,
    CASE
      WHEN TRY_CAST(v.substitution_event AS int) = 1 THEN 1
      WHEN v.substitution_event = '1' THEN 1
      ELSE 0
    END AS substitution_occurred
  FROM dbo.v_transactions_flat_production t
  LEFT JOIN dbo.v_insight_base v ON COALESCE(v.canonical_tx_id, v.sessionId) = t.canonical_tx_id
)
SELECT
  Category,
  SUM(substitution_occurred) AS subs,
  COUNT(DISTINCT canonical_tx_id) AS tx
FROM base
GROUP BY Category;
GO

-- 10) Substitution Event × Reason
CREATE OR ALTER VIEW ct_substitutionXreason AS
SELECT
  COALESCE(NULLIF(LTRIM(RTRIM(substitution_reason)), ''), '(unknown)') AS reason,
  COUNT(*) AS subs
FROM dbo.v_insight_base
WHERE TRY_CAST(substitution_event AS int) = 1 OR substitution_event = '1'
GROUP BY COALESCE(NULLIF(LTRIM(RTRIM(substitution_reason)), ''), '(unknown)');
GO

-- 11) Suggestion Accepted × Brand
CREATE OR ALTER VIEW ct_suggestionAcceptedXbrand AS
WITH base AS (
  SELECT
    t.canonical_tx_id,
    COALESCE(t.brand, 'Unspecified') AS Brand,
    CASE
      WHEN TRY_CAST(v.suggestion_accepted AS int) = 1 THEN 1
      WHEN v.suggestion_accepted = '1' THEN 1
      ELSE 0
    END AS suggestion_accepted
  FROM dbo.v_transactions_flat_production t
  LEFT JOIN dbo.v_insight_base v ON COALESCE(v.canonical_tx_id, v.sessionId) = t.canonical_tx_id
)
SELECT
  Brand,
  SUM(suggestion_accepted) AS accepted,
  COUNT(DISTINCT canonical_tx_id) AS tx
FROM base
GROUP BY Brand;
GO

PRINT '✅ Created substitution/suggestion cross-tabs (3 views)';

-- ========================================================================
-- DEMOGRAPHIC CROSS-TABS (12-16)
-- ========================================================================

PRINT '';
PRINT '👥 Creating demographic cross-tabs...';

-- 12) Age Bracket × Category
CREATE OR ALTER VIEW ct_ageXcategory AS
WITH base AS (
  SELECT
    t.canonical_tx_id,
    COALESCE(si.AgeBracket, 'Unknown') AS AgeBracket,
    COALESCE(t.category, 'Unspecified') AS Category
  FROM dbo.v_transactions_flat_production t
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = t.canonical_tx_id
)
SELECT AgeBracket, Category, COUNT(DISTINCT canonical_tx_id) AS tx
FROM base
GROUP BY AgeBracket, Category;
GO

-- 13) Age Bracket × Brand
CREATE OR ALTER VIEW ct_ageXbrand AS
WITH base AS (
  SELECT
    t.canonical_tx_id,
    COALESCE(si.AgeBracket, 'Unknown') AS AgeBracket,
    COALESCE(t.brand, 'Unspecified') AS Brand
  FROM dbo.v_transactions_flat_production t
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = t.canonical_tx_id
)
SELECT AgeBracket, Brand, COUNT(DISTINCT canonical_tx_id) AS tx
FROM base
GROUP BY AgeBracket, Brand;
GO

-- 14) Age Bracket × Pack Size
CREATE OR ALTER VIEW ct_ageXpacksize AS
WITH base AS (
  SELECT DISTINCT
    t.canonical_tx_id,
    COALESCE(si.AgeBracket, 'Unknown') AS AgeBracket,
    COALESCE(ti.pack_size, 'regular') AS PackSize
  FROM dbo.v_transactions_flat_production t
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = t.canonical_tx_id
  LEFT JOIN dbo.TransactionItems ti ON ti.canonical_tx_id = t.canonical_tx_id
)
SELECT AgeBracket, PackSize, COUNT(DISTINCT canonical_tx_id) AS tx
FROM base
GROUP BY AgeBracket, PackSize;
GO

-- 15) Gender × Daypart
CREATE OR ALTER VIEW ct_genderXdaypart AS
WITH base AS (
  SELECT
    t.canonical_tx_id,
    COALESCE(si.Gender, 'Unknown') AS Gender,
    COALESCE(si.Daypart, 'Unknown') AS Daypart
  FROM dbo.v_transactions_flat_production t
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = t.canonical_tx_id
)
SELECT Gender, Daypart, COUNT(DISTINCT canonical_tx_id) AS tx
FROM base
GROUP BY Gender, Daypart;
GO

-- 16) Payment Method × Demographics
CREATE OR ALTER VIEW ct_paymentXdemographics AS
WITH base AS (
  SELECT
    t.canonical_tx_id,
    COALESCE(si.PaymentMethod, 'Unknown') AS PaymentMethod,
    COALESCE(si.AgeBracket, 'Unknown') AS AgeBracket,
    COALESCE(si.Gender, 'Unknown') AS Gender,
    COALESCE(si.CustomerType, 'Unknown') AS CustomerType
  FROM dbo.v_transactions_flat_production t
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = t.canonical_tx_id
)
SELECT PaymentMethod, AgeBracket, Gender, CustomerType, COUNT(DISTINCT canonical_tx_id) AS tx
FROM base
GROUP BY PaymentMethod, AgeBracket, Gender, CustomerType;
GO

PRINT '✅ Created demographic cross-tabs (5 views)';

-- ========================================================================
-- GRANT PERMISSIONS
-- ========================================================================

PRINT '';
PRINT '🔐 Setting up permissions...';

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rpt_reader')
BEGIN
    DECLARE @view_name nvarchar(128);
    DECLARE view_cursor CURSOR FOR
        SELECT name FROM sys.views
        WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name LIKE 'ct_%';

    OPEN view_cursor;
    FETCH NEXT FROM view_cursor INTO @view_name;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC('GRANT SELECT ON dbo.' + @view_name + ' TO rpt_reader');
        FETCH NEXT FROM view_cursor INTO @view_name;
    END

    CLOSE view_cursor;
    DEALLOCATE view_cursor;

    PRINT '✅ Granted SELECT permissions to rpt_reader for all cross-tab views';
END
ELSE
BEGIN
    PRINT '⚠️ rpt_reader role not found - permissions not granted';
END

-- ========================================================================
-- VALIDATION
-- ========================================================================

PRINT '';
PRINT '🔍 Validating cross-tab view creation...';

DECLARE @ct_views_created int = 0;

SELECT @ct_views_created = COUNT(*)
FROM sys.views
WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name LIKE 'ct_%';

PRINT '📊 Cross-tab views created: ' + CAST(@ct_views_created AS varchar(10));

IF @ct_views_created >= 16
BEGIN
    PRINT '✅ All 16 cross-tab views created successfully';

    -- Sample data from a few views
    PRINT '';
    PRINT '📋 Sample cross-tab data:';

    IF EXISTS (SELECT 1 FROM ct_timeXcategory)
    BEGIN
        SELECT TOP 3 * FROM ct_timeXcategory ORDER BY tx DESC;
        PRINT '✅ ct_timeXcategory has data';
    END

    IF EXISTS (SELECT 1 FROM ct_basketsizeXcategory)
    BEGIN
        SELECT TOP 3 * FROM ct_basketsizeXcategory ORDER BY tx DESC;
        PRINT '✅ ct_basketsizeXcategory has data';
    END
END
ELSE
BEGIN
    PRINT '⚠️ Expected 16 cross-tab views, found ' + CAST(@ct_views_created AS varchar(10));
END

PRINT '';
PRINT '🎉 Cross-tab analytics infrastructure completed!';
PRINT '📊 16 cross-tabulation views ready for multi-dimensional analysis';
PRINT '📅 Finished: ' + CONVERT(varchar(20), GETDATE(), 120);

GO