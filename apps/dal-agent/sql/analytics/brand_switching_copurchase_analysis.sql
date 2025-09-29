-- =====================================================
-- Brand Switching & Co-Purchase Analytics Query
-- =====================================================
-- File: sql/analytics/brand_switching_copurchase_analysis.sql
-- Purpose: Detailed brand switching and frequently sold together analysis

DECLARE @DateFrom DATE = '{{DATE_FROM}}';  -- Default: 2025-09-01
DECLARE @DateTo   DATE = '{{DATE_TO}}';    -- Default: 2025-09-23

-- =====================================================
-- 1. Brand Switching Analysis
-- =====================================================
SELECT
    'BRAND_SWITCHING_ANALYSIS' AS analysis_type,
    primary_brand,
    secondary_brand,
    COUNT(*) AS switch_frequency,
    AVG(amount) AS avg_transaction_value,
    STRING_AGG(CAST(canonical_tx_id AS VARCHAR(50)), ';') AS sample_transactions
FROM (
    SELECT
        f.canonical_tx_id,
        f.transaction_value AS amount,
        (
            SELECT TOP 1 sib.BrandName
            FROM SalesInteractionBrands sib
            JOIN SalesInteractions si ON sib.InteractionID = si.InteractionID
            WHERE si.canonical_tx_id = f.canonical_tx_id
            ORDER BY sib.Confidence DESC
        ) AS primary_brand,
        (
            SELECT TOP 1 sib.BrandName
            FROM SalesInteractionBrands sib
            JOIN SalesInteractions si ON sib.InteractionID = si.InteractionID
            WHERE si.canonical_tx_id = f.canonical_tx_id
            AND sib.BrandName != (
                SELECT TOP 1 sib2.BrandName
                FROM SalesInteractionBrands sib2
                JOIN SalesInteractions si2 ON sib2.InteractionID = si2.InteractionID
                WHERE si2.canonical_tx_id = f.canonical_tx_id
                ORDER BY sib2.Confidence DESC
            )
            ORDER BY sib.Confidence DESC
        ) AS secondary_brand
    FROM canonical.SalesInteractionFact f
        LEFT JOIN DimDate dd ON dd.date_key = f.date_key
    WHERE dd.full_date BETWEEN @DateFrom AND @DateTo
        AND f.canonical_tx_id IS NOT NULL
) brand_analysis
WHERE primary_brand IS NOT NULL AND secondary_brand IS NOT NULL
GROUP BY primary_brand, secondary_brand
ORDER BY switch_frequency DESC

UNION ALL

-- =====================================================
-- 2. Multi-Item Transaction Co-Purchase Analysis
-- =====================================================
SELECT
    'COPURCHASE_ANALYSIS',
    brand_combination,
    'N/A' AS secondary_brand,
    frequency,
    avg_basket_value,
    sample_transactions
FROM (
    SELECT
        all_brands_mentioned AS brand_combination,
        COUNT(*) AS frequency,
        AVG(amount) AS avg_basket_value,
        STRING_AGG(CAST(canonical_tx_id AS VARCHAR(50)), ';') AS sample_transactions
    FROM (
        SELECT
            f.canonical_tx_id,
            f.transaction_value AS amount,
            f.basket_size,
            (
                SELECT STRING_AGG(sib.BrandName, '+')
                FROM SalesInteractionBrands sib
                JOIN SalesInteractions si ON sib.InteractionID = si.InteractionID
                WHERE si.canonical_tx_id = f.canonical_tx_id
                AND sib.Confidence > 0.5
            ) AS all_brands_mentioned
        FROM canonical.SalesInteractionFact f
            LEFT JOIN DimDate dd ON dd.date_key = f.date_key
        WHERE dd.full_date BETWEEN @DateFrom AND @DateTo
            AND f.canonical_tx_id IS NOT NULL
            AND f.basket_size > 1
    ) multi_item
    WHERE all_brands_mentioned IS NOT NULL
        AND all_brands_mentioned LIKE '%+%'  -- Contains multiple brands
    GROUP BY all_brands_mentioned
    HAVING COUNT(*) >= 2  -- At least 2 occurrences
) copurchase
ORDER BY frequency DESC

UNION ALL

-- =====================================================
-- 3. Frequent Brand Pairs (Most Sold Together)
-- =====================================================
SELECT
    'FREQUENT_PAIRS',
    brand_pair,
    'N/A',
    pair_frequency,
    avg_transaction_value,
    sample_transactions
FROM (
    SELECT TOP 20
        CASE
            WHEN brand1 < brand2 THEN brand1 + ' + ' + brand2
            ELSE brand2 + ' + ' + brand1
        END AS brand_pair,
        COUNT(*) AS pair_frequency,
        AVG(transaction_value) AS avg_transaction_value,
        STRING_AGG(CAST(canonical_tx_id AS VARCHAR(50)), ';') AS sample_transactions
    FROM (
        SELECT DISTINCT
            f.canonical_tx_id,
            f.transaction_value,
            b1.BrandName AS brand1,
            b2.BrandName AS brand2
        FROM canonical.SalesInteractionFact f
            LEFT JOIN DimDate dd ON dd.date_key = f.date_key
            JOIN SalesInteractions si1 ON f.canonical_tx_id = si1.canonical_tx_id
            JOIN SalesInteractionBrands b1 ON si1.InteractionID = b1.InteractionID
            JOIN SalesInteractions si2 ON f.canonical_tx_id = si2.canonical_tx_id
            JOIN SalesInteractionBrands b2 ON si2.InteractionID = b2.InteractionID
        WHERE dd.full_date BETWEEN @DateFrom AND @DateTo
            AND b1.BrandName != b2.BrandName
            AND b1.Confidence > 0.7
            AND b2.Confidence > 0.7
    ) brand_pairs
    GROUP BY
        CASE
            WHEN brand1 < brand2 THEN brand1 + ' + ' + brand2
            ELSE brand2 + ' + ' + brand1
        END
    ORDER BY COUNT(*) DESC
) top_pairs

ORDER BY analysis_type, switch_frequency DESC;