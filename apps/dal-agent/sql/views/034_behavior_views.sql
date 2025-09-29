-- =============================================================================
-- Consumer Behavior Analysis Views
-- Request patterns, acceptance rates, and purchase behavior analysis
-- Created: 2025-09-28
-- =============================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

PRINT 'Creating consumer behavior analysis views...';

-- =============================================================================
-- GOLD · Request type classification
-- =============================================================================
CREATE OR ALTER VIEW gold.v_request_types AS
SELECT
    CONVERT(date, si.TransactionDate) AS d,
    CASE
        WHEN si.TranscriptionText LIKE '%pabili%' OR si.TranscriptionText LIKE '%gusto ko%' OR si.TranscriptionText LIKE '%want%' THEN 'purchase_request'
        WHEN si.TranscriptionText LIKE '%magkano%' OR si.TranscriptionText LIKE '%how much%' OR si.TranscriptionText LIKE '%price%' THEN 'price_check'
        WHEN si.TranscriptionText LIKE '%meron%' OR si.TranscriptionText LIKE '%available%' OR si.TranscriptionText LIKE '%stock%' THEN 'availability_check'
        WHEN si.TranscriptionText LIKE '%recommendation%' OR si.TranscriptionText LIKE '%suggest%' OR si.TranscriptionText LIKE '%ano ang%' THEN 'recommendation_request'
        ELSE 'other'
    END AS request_type,
    COUNT_BIG(*) AS occurrences,
    AVG(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS avg_transaction_value
FROM dbo.SalesInteractions si
LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = si.canonical_tx_id
WHERE si.TranscriptionText IS NOT NULL
GROUP BY CONVERT(date, si.TransactionDate),
    CASE
        WHEN si.TranscriptionText LIKE '%pabili%' OR si.TranscriptionText LIKE '%gusto ko%' OR si.TranscriptionText LIKE '%want%' THEN 'purchase_request'
        WHEN si.TranscriptionText LIKE '%magkano%' OR si.TranscriptionText LIKE '%how much%' OR si.TranscriptionText LIKE '%price%' THEN 'price_check'
        WHEN si.TranscriptionText LIKE '%meron%' OR si.TranscriptionText LIKE '%available%' OR si.TranscriptionText LIKE '%stock%' THEN 'availability_check'
        WHEN si.TranscriptionText LIKE '%recommendation%' OR si.TranscriptionText LIKE '%suggest%' OR si.TranscriptionText LIKE '%ano ang%' THEN 'recommendation_request'
        ELSE 'other'
    END;
GO

-- =============================================================================
-- GOLD · Acceptance rates (successful vs attempted interactions)
-- =============================================================================
CREATE OR ALTER VIEW gold.v_acceptance_rates AS
SELECT
    CONVERT(date, si.TransactionDate) AS d,
    CASE WHEN EXISTS (
        SELECT 1 FROM dbo.SalesInteractionBrands b
        WHERE b.InteractionID = si.InteractionID
        AND b.Confidence > 0.5
    ) THEN 1 ELSE 0 END AS accepted_flag,
    COUNT_BIG(*) AS interaction_count,
    AVG(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS avg_value
FROM dbo.SalesInteractions si
LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = si.canonical_tx_id
GROUP BY CONVERT(date, si.TransactionDate),
    CASE WHEN EXISTS (
        SELECT 1 FROM dbo.SalesInteractionBrands b
        WHERE b.InteractionID = si.InteractionID
        AND b.Confidence > 0.5
    ) THEN 1 ELSE 0 END;
GO

-- =============================================================================
-- GOLD · Purchase journey funnel analysis
-- =============================================================================
CREATE OR ALTER VIEW gold.v_purchase_funnel AS
WITH funnel_stages AS (
    SELECT
        CONVERT(date, si.TransactionDate) AS d,
        COUNT_BIG(*) AS total_interactions,
        COUNT_BIG(CASE WHEN si.TranscriptionText IS NOT NULL THEN 1 END) AS with_transcription,
        COUNT_BIG(CASE WHEN EXISTS (
            SELECT 1 FROM dbo.SalesInteractionBrands b
            WHERE b.InteractionID = si.InteractionID
        ) THEN 1 END) AS brand_identified,
        COUNT_BIG(CASE WHEN EXISTS (
            SELECT 1 FROM dbo.SalesInteractionBrands b
            WHERE b.InteractionID = si.InteractionID
            AND b.Confidence > 0.7
        ) THEN 1 END) AS high_confidence_brand,
        COUNT_BIG(CASE WHEN f.transaction_value > 0 THEN 1 END) AS completed_purchase
    FROM dbo.SalesInteractions si
    LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = si.canonical_tx_id
    GROUP BY CONVERT(date, si.TransactionDate)
)
SELECT
    d,
    total_interactions,
    with_transcription,
    brand_identified,
    high_confidence_brand,
    completed_purchase,
    -- Conversion rates
    CASE WHEN total_interactions > 0 THEN
        CAST(with_transcription AS decimal(10,4)) / total_interactions
    ELSE 0 END AS transcription_rate,
    CASE WHEN with_transcription > 0 THEN
        CAST(brand_identified AS decimal(10,4)) / with_transcription
    ELSE 0 END AS brand_identification_rate,
    CASE WHEN brand_identified > 0 THEN
        CAST(high_confidence_brand AS decimal(10,4)) / brand_identified
    ELSE 0 END AS confidence_rate,
    CASE WHEN high_confidence_brand > 0 THEN
        CAST(completed_purchase AS decimal(10,4)) / high_confidence_brand
    ELSE 0 END AS purchase_completion_rate
FROM funnel_stages;
GO

-- =============================================================================
-- GOLD · Time-based behavior patterns
-- =============================================================================
CREATE OR ALTER VIEW gold.v_temporal_behavior AS
SELECT
    CONVERT(date, si.TransactionDate) AS d,
    DATEPART(HOUR, si.TransactionDate) AS hour_of_day,
    DATENAME(WEEKDAY, si.TransactionDate) AS day_of_week,
    COUNT_BIG(*) AS interaction_count,
    COUNT_BIG(CASE WHEN EXISTS (
        SELECT 1 FROM dbo.SalesInteractionBrands b
        WHERE b.InteractionID = si.InteractionID
    ) THEN 1 END) AS successful_interactions,
    AVG(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS avg_transaction_value
FROM dbo.SalesInteractions si
LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = si.canonical_tx_id
GROUP BY CONVERT(date, si.TransactionDate),
         DATEPART(HOUR, si.TransactionDate),
         DATENAME(WEEKDAY, si.TransactionDate);
GO

PRINT 'Consumer behavior analysis views created successfully.';