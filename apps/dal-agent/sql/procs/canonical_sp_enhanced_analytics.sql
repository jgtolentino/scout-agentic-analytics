-- =====================================================
-- Enhanced Canonical Export with Brand Switching & Co-Purchase Analysis
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Drop existing procedure if it exists
IF OBJECT_ID('canonical.sp_export_enhanced') IS NOT NULL
    DROP PROCEDURE canonical.sp_export_enhanced;
GO

CREATE PROCEDURE canonical.sp_export_enhanced
    @DateFrom DATE,
    @DateTo   DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Enhanced export with brand switching and co-purchase analysis
    SELECT
        f.canonical_tx_id,
        dd.full_date AS transaction_date,
        f.transaction_value AS amount,
        f.basket_size,
        f.store_id,
        f.age,
        f.gender,
        dd.weekday_vs_weekend,
        dd.day_name,
        CAST(f.was_substitution AS INT) AS substitution_flag,

        -- Brand switching analysis: primary brand mentioned
        (
            SELECT TOP 1 sib.BrandName
            FROM SalesInteractionBrands sib
            JOIN SalesInteractions si ON sib.InteractionID = si.InteractionID
            WHERE si.canonical_tx_id = f.canonical_tx_id
            ORDER BY sib.Confidence DESC
        ) AS primary_brand,

        -- Brand switching analysis: secondary brand (potential switch from/to)
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
        ) AS secondary_brand,

        -- Brand confidence scores
        (
            SELECT TOP 1 sib.Confidence
            FROM SalesInteractionBrands sib
            JOIN SalesInteractions si ON sib.InteractionID = si.InteractionID
            WHERE si.canonical_tx_id = f.canonical_tx_id
            ORDER BY sib.Confidence DESC
        ) AS primary_brand_confidence,

        -- Co-purchase analysis: all brands mentioned in transaction
        (
            SELECT STRING_AGG(sib.BrandName, ';')
            FROM SalesInteractionBrands sib
            JOIN SalesInteractions si ON sib.InteractionID = si.InteractionID
            WHERE si.canonical_tx_id = f.canonical_tx_id
            AND sib.Confidence > 0.5
        ) AS all_brands_mentioned,

        -- Multi-item transaction indicator
        CASE
            WHEN f.basket_size > 1 THEN 'Multi-Item'
            ELSE 'Single-Item'
        END AS transaction_type,

        -- Brand switching indicator
        CASE
            WHEN (
                SELECT COUNT(DISTINCT sib.BrandName)
                FROM SalesInteractionBrands sib
                JOIN SalesInteractions si ON sib.InteractionID = si.InteractionID
                WHERE si.canonical_tx_id = f.canonical_tx_id
                AND sib.Confidence > 0.5
            ) > 1 THEN 'Brand-Switch-Considered'
            ELSE 'Single-Brand'
        END AS brand_switching_indicator,

        -- Frequent co-purchase patterns (for multi-item transactions)
        CASE
            WHEN f.basket_size > 1 THEN
                (
                    SELECT STRING_AGG(pattern, ';')
                    FROM (
                        SELECT DISTINCT
                            CASE
                                WHEN sib.BrandName LIKE '%Coca%' AND EXISTS (
                                    SELECT 1 FROM SalesInteractionBrands sib2
                                    JOIN SalesInteractions si2 ON sib2.InteractionID = si2.InteractionID
                                    WHERE si2.canonical_tx_id = f.canonical_tx_id
                                    AND sib2.BrandName LIKE '%Snack%'
                                ) THEN 'Beverage+Snack'
                                WHEN sib.BrandName LIKE '%Shampoo%' AND EXISTS (
                                    SELECT 1 FROM SalesInteractionBrands sib2
                                    JOIN SalesInteractions si2 ON sib2.InteractionID = si2.InteractionID
                                    WHERE si2.canonical_tx_id = f.canonical_tx_id
                                    AND sib2.BrandName LIKE '%Soap%'
                                ) THEN 'Personal-Care-Bundle'
                                ELSE 'Other-Combination'
                            END as pattern
                        FROM SalesInteractionBrands sib
                        JOIN SalesInteractions si ON sib.InteractionID = si.InteractionID
                        WHERE si.canonical_tx_id = f.canonical_tx_id
                        AND sib.Confidence > 0.5
                    ) patterns
                    WHERE pattern IS NOT NULL
                )
            ELSE NULL
        END AS copurchase_patterns,

        FORMAT(GETDATE(), 'yyyy-MM-ddTHH:mm:ss') AS export_timestamp

    FROM canonical.SalesInteractionFact f
        LEFT JOIN DimDate dd ON dd.date_key = f.date_key

    WHERE dd.full_date BETWEEN @DateFrom AND @DateTo
        AND f.canonical_tx_id IS NOT NULL

    ORDER BY dd.full_date, f.canonical_tx_id;

END
GO

PRINT 'Enhanced canonical export with brand switching and co-purchase analysis created';
PRINT 'Usage: EXEC canonical.sp_export_enhanced @DateFrom=''2025-09-01'', @DateTo=''2025-09-23''';