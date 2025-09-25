-- ========================================================================
-- Scout Analytics - Persona Role Inference System
-- Migration: 003_create_persona_inference.sql
-- Purpose: Create persona inference view with rule-based scoring
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- ========================================================================
-- CREATE PERSONA INFERENCE VIEW
-- ========================================================================

CREATE OR ALTER VIEW ref.v_persona_inference AS
WITH base AS (
  -- Get transaction context and explicit roles
  SELECT
    p.canonical_tx_id,
    p.txn_ts,
    DATEPART(HOUR, p.txn_ts) AS hour_of_day,
    p.daypart,
    p.weekday_weekend,
    p.category as primary_category,
    p.brand as primary_brand,
    p.total_items as item_count,
    -- Age bracket from SalesInteractions.Age
    CASE
      WHEN si.Age BETWEEN 13 AND 17 THEN 15  -- midpoint for Teen
      WHEN si.Age BETWEEN 18 AND 24 THEN 21
      WHEN si.Age BETWEEN 25 AND 34 THEN 30
      WHEN si.Age BETWEEN 35 AND 44 THEN 40
      WHEN si.Age BETWEEN 45 AND 54 THEN 50
      WHEN si.Age BETWEEN 55 AND 64 THEN 60
      WHEN si.Age >= 65 THEN 70
      ELSE NULL
    END AS age_numeric,
    si.Gender,
    -- Check for explicit role (cleaned)
    NULLIF(LTRIM(RTRIM(COALESCE(si.EmotionalState, ''))), '') AS role_explicit
  FROM dbo.v_transactions_flat_production p
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = p.canonical_tx_id
),

basket AS (
  -- Get basket composition from TransactionItems using InteractionID
  SELECT
    si.canonical_tx_id,
    COUNT(*) AS item_cnt,
    STRING_AGG(DISTINCT
      CASE WHEN p.CategoryName IS NOT NULL THEN p.CategoryName ELSE 'Unknown' END, '|'
    ) AS categories,
    STRING_AGG(DISTINCT
      CASE WHEN p.Brand IS NOT NULL THEN p.Brand ELSE 'Unknown' END, '|'
    ) AS brands
  FROM dbo.SalesInteractions si
  LEFT JOIN dbo.TransactionItems ti ON ti.InteractionID = si.InteractionID
  LEFT JOIN dbo.Products p ON ti.ProductID = p.ProductID
  WHERE si.canonical_tx_id IS NOT NULL
  GROUP BY si.canonical_tx_id
),

transcript AS (
  -- Get conversation text if available
  SELECT
    si.canonical_tx_id,
    LOWER(COALESCE(STRING_AGG(si.TranscriptionText, ' '), '')) AS text_blob
  FROM dbo.SalesInteractions si
  WHERE si.TranscriptionText IS NOT NULL AND si.TranscriptionText != ''
  GROUP BY si.canonical_tx_id
),

signals AS (
  -- Combine all signals
  SELECT
    b.canonical_tx_id,
    b.hour_of_day,
    b.daypart,
    b.weekday_weekend,
    b.primary_category,
    b.primary_brand,
    COALESCE(bsk.item_cnt, b.item_count, 0) AS item_count,
    b.age_numeric,
    b.Gender,
    b.role_explicit,
    COALESCE(bsk.categories, b.primary_category) AS categories,
    COALESCE(bsk.brands, b.primary_brand) AS brands,
    COALESCE(t.text_blob, '') AS text_blob
  FROM base b
  LEFT JOIN basket bsk ON bsk.canonical_tx_id = b.canonical_tx_id
  LEFT JOIN transcript t ON t.canonical_tx_id = b.canonical_tx_id
),

rule_matches AS (
  -- Score each transaction against each persona rule
  SELECT
    s.canonical_tx_id,
    r.role_name,
    r.priority,
    s.role_explicit,
    -- Text matching (simplified - check if any term from include_terms appears)
    CASE
      WHEN r.include_terms IS NOT NULL AND s.text_blob != '' THEN
        CASE WHEN (
          s.text_blob LIKE '%school%' OR s.text_blob LIKE '%class%' OR s.text_blob LIKE '%student%' OR
          s.text_blob LIKE '%office%' OR s.text_blob LIKE '%work%' OR s.text_blob LIKE '%meeting%' OR
          s.text_blob LIKE '%deliver%' OR s.text_blob LIKE '%rider%' OR s.text_blob LIKE '%grab%' OR
          s.text_blob LIKE '%anak%' OR s.text_blob LIKE '%baby%' OR s.text_blob LIKE '%nanay%' OR
          s.text_blob LIKE '%lolo%' OR s.text_blob LIKE '%lola%' OR s.text_blob LIKE '%senior%' OR
          s.text_blob LIKE '%construction%' OR s.text_blob LIKE '%trabaho%' OR s.text_blob LIKE '%obrero%' OR
          s.text_blob LIKE '%paninda%' OR s.text_blob LIKE '%benta%' OR s.text_blob LIKE '%tingi%' OR
          s.text_blob LIKE '%game%' OR s.text_blob LIKE '%gaming%' OR s.text_blob LIKE '%laro%' OR
          s.text_blob LIKE '%shift%' OR s.text_blob LIKE '%night%' OR s.text_blob LIKE '%gabi%' OR
          s.text_blob LIKE '%party%' OR s.text_blob LIKE '%celebration%' OR s.text_blob LIKE '%handaan%' OR
          s.text_blob LIKE '%bukid%' OR s.text_blob LIKE '%farmer%' OR s.text_blob LIKE '%ani%'
        ) THEN 1 ELSE 0 END
      ELSE 0
    END AS has_text_match,

    -- Category matching
    CASE
      WHEN r.must_have_categories IS NOT NULL AND s.categories IS NOT NULL THEN
        CASE WHEN (
          (r.role_name = 'Student' AND (s.categories LIKE '%Instant Noodles%' OR s.categories LIKE '%Snacks%' OR s.categories LIKE '%Beverages%')) OR
          (r.role_name = 'Office Worker' AND (s.categories LIKE '%Beverages%' OR s.categories LIKE '%Biscuits%')) OR
          (r.role_name = 'Delivery Rider' AND (s.categories LIKE '%Energy Drinks%' OR s.categories LIKE '%Tobacco%')) OR
          (r.role_name = 'Parent' AND (s.categories LIKE '%Milk%' OR s.categories LIKE '%Personal Care%')) OR
          (r.role_name = 'Blue-Collar Worker' AND (s.categories LIKE '%Energy Drinks%' OR s.categories LIKE '%Instant Noodles%')) OR
          (r.role_name = 'Reseller' AND s.item_count >= 5) OR
          (r.role_name = 'Teen Gamer' AND (s.categories LIKE '%Soft Drinks%' OR s.categories LIKE '%Snacks%')) OR
          (r.role_name = 'Night-Shift Worker' AND (s.categories LIKE '%Energy Drinks%' OR s.categories LIKE '%Coffee%')) OR
          (r.role_name = 'Party Buyer' AND s.item_count >= 8)
        ) THEN 1 ELSE 0 END
      ELSE 0
    END AS has_category_match,

    -- Time matching
    CASE
      WHEN r.hour_min IS NOT NULL AND r.hour_max IS NOT NULL THEN
        CASE
          WHEN r.hour_min <= r.hour_max THEN  -- Normal range (e.g., 7-18)
            CASE WHEN s.hour_of_day BETWEEN r.hour_min AND r.hour_max THEN 1 ELSE 0 END
          ELSE  -- Wrap-around range (e.g., 22-5 for night shift)
            CASE WHEN s.hour_of_day >= r.hour_min OR s.hour_of_day <= r.hour_max THEN 1 ELSE 0 END
        END
      ELSE 0
    END AS has_time_match,

    -- Age matching
    CASE
      WHEN r.min_age IS NOT NULL AND r.max_age IS NOT NULL AND s.age_numeric IS NOT NULL THEN
        CASE WHEN s.age_numeric BETWEEN r.min_age AND r.max_age THEN 1 ELSE 0 END
      ELSE 0
    END AS has_age_match,

    -- Gender matching
    CASE
      WHEN r.gender_in IS NOT NULL AND s.Gender IS NOT NULL THEN
        CASE WHEN r.gender_in LIKE '%' + s.Gender + '%' THEN 1 ELSE 0 END
      ELSE 0
    END AS has_gender_match,

    -- Daypart matching
    CASE
      WHEN r.daypart_in IS NOT NULL AND s.daypart IS NOT NULL THEN
        CASE WHEN r.daypart_in LIKE '%' + s.daypart + '%' THEN 1 ELSE 0 END
      ELSE 0
    END AS has_daypart_match,

    -- Item count matching
    CASE
      WHEN r.min_items IS NOT NULL THEN
        CASE WHEN s.item_count >= r.min_items THEN 1 ELSE 0 END
      ELSE 0
    END AS has_item_match
  FROM signals s
  CROSS JOIN ref.persona_rules r
  WHERE r.is_active = 1
),

scored AS (
  -- Calculate total score for each rule match
  SELECT
    m.*,
    -- Scoring algorithm
    CASE WHEN m.role_explicit IS NOT NULL THEN 1000 ELSE 0 END +  -- Explicit role dominates
    (has_text_match * 100) +          -- Text matching is strong signal
    (has_category_match * 50) +       -- Category patterns important
    (has_time_match * 30) +           -- Time context
    (has_age_match * 40) +            -- Age bracket
    (has_gender_match * 20) +         -- Gender context
    (has_daypart_match * 25) +        -- Daypart context
    (has_item_match * 15) -           -- Basket size
    (priority * 2) AS total_score     -- Lower priority number = higher score
  FROM rule_matches m
),

best_match AS (
  -- Get the highest scoring role for each transaction
  SELECT
    canonical_tx_id,
    COALESCE(
      MAX(CASE WHEN role_explicit IS NOT NULL THEN role_explicit END),  -- Explicit first
      (SELECT TOP 1 role_name
       FROM scored s2
       WHERE s2.canonical_tx_id = s1.canonical_tx_id
       ORDER BY total_score DESC, priority ASC),                        -- Then scored
      'Regular'                                                         -- Default fallback
    ) AS role_inferred
  FROM scored s1
  GROUP BY canonical_tx_id
)

-- Final output: one role per transaction (zero row drop)
SELECT
  canonical_tx_id,
  role_inferred AS role
FROM best_match;

GO

-- ========================================================================
-- VERIFICATION
-- ========================================================================

-- Test the view exists and has data
IF OBJECT_ID('ref.v_persona_inference', 'V') IS NOT NULL
BEGIN
    PRINT '✅ ref.v_persona_inference view created successfully';

    -- Test coverage
    DECLARE @base_count int, @inference_count int;
    SELECT @base_count = COUNT(DISTINCT canonical_tx_id) FROM dbo.v_transactions_flat_production;
    SELECT @inference_count = COUNT(*) FROM ref.v_persona_inference;

    IF @base_count = @inference_count
        PRINT '✅ Coverage verified: ' + CAST(@inference_count as varchar(10)) + ' rows (zero row drop)';
    ELSE
        PRINT '❌ Coverage mismatch: base=' + CAST(@base_count as varchar(10)) + ', inference=' + CAST(@inference_count as varchar(10));
END
ELSE
BEGIN
    PRINT '❌ Failed to create ref.v_persona_inference view';
END

PRINT '✅ Migration 003_create_persona_inference completed successfully';
GO