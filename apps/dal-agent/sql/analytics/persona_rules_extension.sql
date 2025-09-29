-- =====================================================
-- PERSONA RULES EXTENSION FOR COMPLETE FLATTENED DATASET
-- Integrates ref.persona_rules sophisticated AI system
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Create enhanced persona inference function
CREATE OR ALTER FUNCTION dbo.fn_infer_persona_from_rules(
    @transcription_text NVARCHAR(MAX),
    @age TINYINT,
    @gender NVARCHAR(10),
    @hour_of_day TINYINT,
    @categories_purchased NVARCHAR(500),
    @brands_purchased NVARCHAR(500)
)
RETURNS TABLE
AS
RETURN (
    SELECT TOP 1
        pr.role_name AS inferred_persona,
        pr.priority AS confidence_priority,
        pr.notes AS persona_description,
        -- Calculate match score based on multiple criteria
        (
            -- Terms match (40% weight)
            CASE
                WHEN @transcription_text IS NOT NULL AND pr.include_terms IS NOT NULL
                     AND EXISTS (
                         SELECT 1 FROM STRING_SPLIT(pr.include_terms, '|') terms
                         WHERE @transcription_text LIKE '%' + TRIM(terms.value) + '%'
                     )
                THEN 0.4
                ELSE 0.0
            END +

            -- Age match (15% weight)
            CASE
                WHEN @age BETWEEN ISNULL(pr.min_age, 0) AND ISNULL(pr.max_age, 120)
                THEN 0.15
                ELSE 0.0
            END +

            -- Gender match (10% weight)
            CASE
                WHEN pr.gender_in IS NULL OR pr.gender_in LIKE '%' + @gender + '%'
                THEN 0.1
                ELSE 0.0
            END +

            -- Time match (15% weight)
            CASE
                WHEN pr.hour_min IS NULL OR @hour_of_day BETWEEN pr.hour_min AND pr.hour_max
                THEN 0.15
                WHEN pr.daypart_in IS NULL
                THEN 0.15
                WHEN pr.daypart_in = 'Morning' AND @hour_of_day BETWEEN 6 AND 11
                THEN 0.15
                WHEN pr.daypart_in = 'Afternoon' AND @hour_of_day BETWEEN 12 AND 17
                THEN 0.15
                WHEN pr.daypart_in = 'Evening' AND @hour_of_day BETWEEN 18 AND 22
                THEN 0.15
                WHEN pr.daypart_in = 'Night' AND (@hour_of_day >= 23 OR @hour_of_day <= 5)
                THEN 0.15
                ELSE 0.0
            END +

            -- Category match (20% weight)
            CASE
                WHEN pr.must_have_categories IS NOT NULL AND @categories_purchased IS NOT NULL
                     AND EXISTS (
                         SELECT 1 FROM STRING_SPLIT(pr.must_have_categories, '|') cats
                         WHERE @categories_purchased LIKE '%' + TRIM(cats.value) + '%'
                     )
                THEN 0.2
                WHEN pr.must_have_categories IS NULL
                THEN 0.1
                ELSE 0.0
            END
        ) AS match_score

    FROM ref.persona_rules pr
    WHERE pr.is_active = 1
      AND (
          -- Must have at least one match criteria
          (@transcription_text IS NOT NULL AND pr.include_terms IS NOT NULL
           AND EXISTS (
               SELECT 1 FROM STRING_SPLIT(pr.include_terms, '|') terms
               WHERE @transcription_text LIKE '%' + TRIM(terms.value) + '%'
           ))
          OR
          (@age BETWEEN ISNULL(pr.min_age, 0) AND ISNULL(pr.max_age, 120))
          OR
          (pr.must_have_categories IS NOT NULL AND @categories_purchased IS NOT NULL
           AND EXISTS (
               SELECT 1 FROM STRING_SPLIT(pr.must_have_categories, '|') cats
               WHERE @categories_purchased LIKE '%' + TRIM(cats.value) + '%'
           ))
      )
    ORDER BY
        -- Priority first (lower number = higher priority)
        pr.priority ASC,
        -- Then by match score (higher = better)
        (
            CASE
                WHEN @transcription_text IS NOT NULL AND pr.include_terms IS NOT NULL
                     AND EXISTS (
                         SELECT 1 FROM STRING_SPLIT(pr.include_terms, '|') terms
                         WHERE @transcription_text LIKE '%' + TRIM(terms.value) + '%'
                     )
                THEN 0.4 ELSE 0.0 END +
            CASE
                WHEN @age BETWEEN ISNULL(pr.min_age, 0) AND ISNULL(pr.max_age, 120)
                THEN 0.15 ELSE 0.0 END +
            CASE
                WHEN pr.gender_in IS NULL OR pr.gender_in LIKE '%' + @gender + '%'
                THEN 0.1 ELSE 0.0 END +
            CASE
                WHEN pr.hour_min IS NULL OR @hour_of_day BETWEEN pr.hour_min AND pr.hour_max
                THEN 0.15
                WHEN pr.daypart_in IS NULL THEN 0.15
                WHEN pr.daypart_in = 'Morning' AND @hour_of_day BETWEEN 6 AND 11 THEN 0.15
                WHEN pr.daypart_in = 'Afternoon' AND @hour_of_day BETWEEN 12 AND 17 THEN 0.15
                WHEN pr.daypart_in = 'Evening' AND @hour_of_day BETWEEN 18 AND 22 THEN 0.15
                WHEN pr.daypart_in = 'Night' AND (@hour_of_day >= 23 OR @hour_of_day <= 5) THEN 0.15
                ELSE 0.0 END +
            CASE
                WHEN pr.must_have_categories IS NOT NULL AND @categories_purchased IS NOT NULL
                     AND EXISTS (
                         SELECT 1 FROM STRING_SPLIT(pr.must_have_categories, '|') cats
                         WHERE @categories_purchased LIKE '%' + TRIM(cats.value) + '%'
                     )
                THEN 0.2
                WHEN pr.must_have_categories IS NULL THEN 0.1
                ELSE 0.0 END
        ) DESC
);
GO

-- Enhanced view with persona rules integration
CREATE OR ALTER VIEW dbo.v_complete_flattened_dataset_with_persona_rules AS
WITH sku_items AS (
    -- Extract SKU-level data from JSON payload
    SELECT
        pt.canonical_tx_id,
        JSON_VALUE(item.value, '$.sku') AS sku_code,
        JSON_VALUE(item.value, '$.brand') AS item_brand,
        JSON_VALUE(item.value, '$.category') AS item_category,
        TRY_CONVERT(INT, JSON_VALUE(item.value, '$.quantity')) AS item_quantity,
        TRY_CONVERT(DECIMAL(10,2), JSON_VALUE(item.value, '$.unitPrice')) AS item_unit_price,
        TRY_CONVERT(DECIMAL(10,2), JSON_VALUE(item.value, '$.total')) AS item_total,
        ROW_NUMBER() OVER (PARTITION BY pt.canonical_tx_id ORDER BY JSON_VALUE(item.value, '$.total') DESC) AS item_rank
    FROM dbo.PayloadTransactions pt
    CROSS APPLY OPENJSON(pt.payload_json, '$.items') AS item
    WHERE pt.payload_json IS NOT NULL
      AND ISJSON(pt.payload_json) = 1
),
persona_inference AS (
    -- Apply persona rules to each transaction
    SELECT
        si.canonical_tx_id,
        p.inferred_persona,
        p.confidence_priority,
        p.persona_description,
        p.match_score
    FROM dbo.SalesInteractions si
    CROSS APPLY dbo.fn_infer_persona_from_rules(
        si.TranscriptionText,
        si.Age,
        si.Gender,
        DATEPART(hour, si.CreatedDate),
        (SELECT STUFF((
            SELECT '; ' + sku_items.item_category
            FROM sku_items
            WHERE sku_items.canonical_tx_id = si.canonical_tx_id
            FOR XML PATH('')
        ), 1, 2, '')),
        (SELECT STUFF((
            SELECT '; ' + sku_items.item_brand
            FROM sku_items
            WHERE sku_items.canonical_tx_id = si.canonical_tx_id
            FOR XML PATH('')
        ), 1, 2, ''))
    ) p
)
SELECT
    -- Core transaction data (same as before)
    si.canonical_tx_id AS transaction_id,
    si.InteractionID AS interaction_id,
    si.FacialID AS facial_id,
    si.Age AS customer_age,
    si.Gender AS customer_gender,
    si.TransactionDate AS transaction_date,
    si.StoreID AS store_id,
    COALESCE(si.TransactionValue, pt.amount) AS transaction_value,

    -- =====================================================
    -- ENHANCED PERSONA INFERENCE (Using ref.persona_rules)
    -- =====================================================

    -- Primary persona from AI rules engine
    pi.inferred_persona AS ai_inferred_persona,
    pi.match_score AS persona_confidence_score,
    pi.persona_description AS persona_details,
    pi.confidence_priority AS persona_priority,

    -- Persona category classification
    CASE
        WHEN pi.inferred_persona IN ('Delivery Rider', 'Blue-Collar Worker', 'Farmer', 'Night-Shift Worker')
        THEN 'Working-Class'
        WHEN pi.inferred_persona IN ('Office Worker', 'Health-Conscious')
        THEN 'Professional'
        WHEN pi.inferred_persona IN ('Parent', 'Senior Citizen')
        THEN 'Family-Oriented'
        WHEN pi.inferred_persona IN ('Student', 'Teen Gamer')
        THEN 'Youth'
        WHEN pi.inferred_persona IN ('Reseller', 'Party Buyer')
        THEN 'Business-Social'
        WHEN pi.inferred_persona IN ('Coffee Drinker', 'Smoker')
        THEN 'Lifestyle-Driven'
        ELSE 'General-Consumer'
    END AS persona_category,

    -- Persona behavioral indicators
    CASE
        WHEN pi.inferred_persona = 'Delivery Rider' THEN 'High-Energy-Mobile'
        WHEN pi.inferred_persona = 'Night-Shift Worker' THEN 'Energy-Sustenance'
        WHEN pi.inferred_persona = 'Parent' THEN 'Family-Care-Focused'
        WHEN pi.inferred_persona = 'Reseller' THEN 'Bulk-Business-Buyer'
        WHEN pi.inferred_persona = 'Senior Citizen' THEN 'Health-Value-Conscious'
        WHEN pi.inferred_persona = 'Student' THEN 'Quick-Affordable-Snacks'
        WHEN pi.inferred_persona = 'Blue-Collar Worker' THEN 'Energy-Convenience'
        WHEN pi.inferred_persona = 'Office Worker' THEN 'Productivity-Focused'
        WHEN pi.inferred_persona = 'Teen Gamer' THEN 'Entertainment-Fuel'
        WHEN pi.inferred_persona = 'Health-Conscious' THEN 'Wellness-Oriented'
        ELSE 'Standard-Shopping'
    END AS shopping_motivation,

    -- Persona risk/opportunity indicators
    CASE
        WHEN pi.inferred_persona IN ('Reseller', 'Parent') THEN 'High-Volume-Potential'
        WHEN pi.inferred_persona IN ('Office Worker', 'Health-Conscious') THEN 'Premium-Product-Opportunity'
        WHEN pi.inferred_persona IN ('Teen Gamer', 'Student') THEN 'Brand-Switching-Risk'
        WHEN pi.inferred_persona IN ('Senior Citizen', 'Blue-Collar Worker') THEN 'Price-Sensitive'
        WHEN pi.inferred_persona = 'Delivery Rider' THEN 'Time-Sensitive-High-Frequency'
        ELSE 'Standard-Risk-Profile'
    END AS business_opportunity_indicator,

    -- Multi-persona detection (if multiple rules match)
    CASE
        WHEN EXISTS (
            SELECT 1 FROM ref.persona_rules pr2
            WHERE pr2.is_active = 1
              AND pr2.role_name != pi.inferred_persona
              AND pr2.include_terms IS NOT NULL
              AND si.TranscriptionText LIKE '%' + (SELECT TOP 1 value FROM STRING_SPLIT(pr2.include_terms, '|')) + '%'
        ) THEN 'Multi-Persona-Match'
        ELSE 'Single-Persona'
    END AS persona_complexity,

    -- Time-persona alignment check
    CASE
        WHEN pi.inferred_persona = 'Night-Shift Worker' AND DATEPART(hour, si.CreatedDate) BETWEEN 22 AND 6
        THEN 'Time-Persona-Aligned'
        WHEN pi.inferred_persona = 'Office Worker' AND DATEPART(hour, si.CreatedDate) BETWEEN 9 AND 17
        THEN 'Time-Persona-Aligned'
        WHEN pi.inferred_persona = 'Senior Citizen' AND DATEPART(hour, si.CreatedDate) BETWEEN 8 AND 16
        THEN 'Time-Persona-Aligned'
        ELSE 'Time-Persona-Neutral'
    END AS temporal_persona_alignment,

    -- All other existing dimensions from the original view...
    -- (Include all the market basket, substitution, time hierarchy, store hierarchy columns)

    -- =====================================================
    -- ORIGINAL DATASET COLUMNS (maintained for backward compatibility)
    -- =====================================================
    si.TranscriptionText AS conversation_text,
    si.BasketSize AS basket_size,
    si.WasSubstitution AS substitution_occurred

FROM dbo.SalesInteractions si
LEFT JOIN dbo.PayloadTransactions pt ON si.canonical_tx_id = pt.canonical_tx_id
LEFT JOIN persona_inference pi ON si.canonical_tx_id = pi.canonical_tx_id
WHERE si.canonical_tx_id IS NOT NULL;

GO

-- Performance index for persona inference
CREATE NONCLUSTERED INDEX IX_SalesInteractions_PersonaInference
ON dbo.SalesInteractions (Age, Gender, TransactionDate)
INCLUDE (canonical_tx_id, TranscriptionText, BasketSize, WasSubstitution);

GO

-- Sample usage queries
/*
-- Query 1: High-confidence persona matches
SELECT ai_inferred_persona, COUNT(*) as transaction_count, AVG(persona_confidence_score) as avg_confidence
FROM dbo.v_complete_flattened_dataset_with_persona_rules
WHERE persona_confidence_score > 0.5
GROUP BY ai_inferred_persona
ORDER BY avg_confidence DESC;

-- Query 2: Time-aligned personas for targeted marketing
SELECT ai_inferred_persona, temporal_persona_alignment, shopping_motivation, COUNT(*) as occurrences
FROM dbo.v_complete_flattened_dataset_with_persona_rules
WHERE temporal_persona_alignment = 'Time-Persona-Aligned'
GROUP BY ai_inferred_persona, temporal_persona_alignment, shopping_motivation
ORDER BY occurrences DESC;

-- Query 3: Business opportunity analysis
SELECT business_opportunity_indicator, ai_inferred_persona,
       AVG(transaction_value) as avg_transaction_value,
       COUNT(*) as frequency
FROM dbo.v_complete_flattened_dataset_with_persona_rules
GROUP BY business_opportunity_indicator, ai_inferred_persona
ORDER BY avg_transaction_value DESC;
*/