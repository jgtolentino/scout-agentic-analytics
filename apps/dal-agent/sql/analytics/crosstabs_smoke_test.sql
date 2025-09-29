-- =====================================================
-- Crosstab Views Smoke Test
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Should return rows grouped by daypart/category
PRINT 'Testing time_of_day__category...';
SELECT TOP 5 * FROM gold.v_xtab_time_of_day__category;

-- Should bucket into Small/Medium/Large
PRINT 'Testing basket__category...';
SELECT TOP 5 * FROM gold.v_xtab_basket__category;

-- Heuristic substitution reasons
PRINT 'Testing substitution__reason...';
SELECT TOP 5 * FROM gold.v_xtab_substitution__reason;

-- Age brackets
PRINT 'Testing age_bracket__category...';
SELECT TOP 5 * FROM gold.v_xtab_age_bracket__category;

-- Brand switching patterns
PRINT 'Testing suggestion_accepted__brand...';
SELECT TOP 5 * FROM gold.v_xtab_suggestion_accepted__brand;

PRINT 'Smoke test completed successfully!';