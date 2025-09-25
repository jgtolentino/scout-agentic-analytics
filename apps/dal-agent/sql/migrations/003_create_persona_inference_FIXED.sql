-- ========================================================================
-- Scout Analytics - Persona Role Inference System (FIXED)
-- Migration: 003_create_persona_inference_FIXED.sql
-- Purpose: Create persona inference view with actual schema
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- ========================================================================
-- CREATE SIMPLIFIED PERSONA INFERENCE VIEW
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
    -- Age from SalesInteractions.Age
    si.Age as age_numeric,
    si.Gender,
    -- Check for explicit role in EmotionalState field (repurposed)
    NULLIF(LTRIM(RTRIM(COALESCE(si.EmotionalState, ''))), '') AS role_explicit
  FROM dbo.v_transactions_flat_production p
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = p.canonical_tx_id
),

transcript AS (
  -- Get conversation text if available
  SELECT
    si.canonical_tx_id,
    LOWER(COALESCE(STRING_AGG(si.TranscriptionText, ' '), '')) AS text_blob
  FROM dbo.SalesInteractions si
  WHERE si.TranscriptionText IS NOT NULL AND si.TranscriptionText != ''
    AND si.canonical_tx_id IS NOT NULL
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
    b.item_count,
    b.age_numeric,
    b.Gender,
    b.role_explicit,
    COALESCE(t.text_blob, '') AS text_blob
  FROM base b
  LEFT JOIN transcript t ON t.canonical_tx_id = b.canonical_tx_id
),

persona_scoring AS (
  -- Rule-based persona inference
  SELECT
    canonical_tx_id,
    role_explicit,
    -- Student: young age + school hours + snacks/noodles
    CASE
      WHEN age_numeric BETWEEN 13 AND 25
           AND hour_of_day BETWEEN 6 AND 17
           AND (primary_category LIKE '%Noodles%' OR primary_category LIKE '%Snack%' OR primary_category LIKE '%Beverages%')
           THEN 80
      WHEN text_blob LIKE '%school%' OR text_blob LIKE '%class%' OR text_blob LIKE '%student%' OR text_blob LIKE '%eskwela%'
           THEN 90
      ELSE 0
    END AS student_score,

    -- Office Worker: work hours + beverages/coffee
    CASE
      WHEN hour_of_day BETWEEN 7 AND 18
           AND (primary_category LIKE '%Beverages%' OR primary_category LIKE '%Coffee%' OR primary_category LIKE '%Biscuits%')
           AND age_numeric BETWEEN 22 AND 65
           THEN 70
      WHEN text_blob LIKE '%office%' OR text_blob LIKE '%work%' OR text_blob LIKE '%meeting%' OR text_blob LIKE '%opisina%'
           THEN 85
      ELSE 0
    END AS office_worker_score,

    -- Delivery Rider: energy drinks + male + work hours
    CASE
      WHEN primary_category LIKE '%Energy%' OR primary_brand LIKE '%Red Bull%' OR primary_brand LIKE '%Monster%'
           THEN 75
      WHEN text_blob LIKE '%deliver%' OR text_blob LIKE '%rider%' OR text_blob LIKE '%grab%' OR text_blob LIKE '%foodpanda%'
           THEN 90
      WHEN Gender = 'Male' AND age_numeric BETWEEN 18 AND 50 AND primary_category LIKE '%Beverages%'
           THEN 40
      ELSE 0
    END AS rider_score,

    -- Parent: family items + milk/care products
    CASE
      WHEN primary_category LIKE '%Milk%' OR primary_category LIKE '%Personal Care%' OR primary_category LIKE '%Baby%'
           THEN 70
      WHEN text_blob LIKE '%anak%' OR text_blob LIKE '%baby%' OR text_blob LIKE '%nanay%' OR text_blob LIKE '%tatay%'
           THEN 85
      WHEN item_count >= 3 AND age_numeric BETWEEN 25 AND 65
           THEN 30
      ELSE 0
    END AS parent_score,

    -- Senior Citizen: age-based + health products
    CASE
      WHEN age_numeric >= 60 THEN 90
      WHEN text_blob LIKE '%lolo%' OR text_blob LIKE '%lola%' OR text_blob LIKE '%senior%' OR text_blob LIKE '%matanda%'
           THEN 85
      WHEN age_numeric >= 55 AND (primary_category LIKE '%Health%' OR primary_category LIKE '%Medicine%')
           THEN 60
      ELSE 0
    END AS senior_score,

    -- Reseller: high item count + variety
    CASE
      WHEN item_count >= 5 THEN 60
      WHEN text_blob LIKE '%paninda%' OR text_blob LIKE '%benta%' OR text_blob LIKE '%tingi%' OR text_blob LIKE '%sari%'
           THEN 85
      WHEN item_count >= 8 THEN 80
      ELSE 0
    END AS reseller_score,

    -- Teen Gamer: young + snacks + afternoon/evening
    CASE
      WHEN age_numeric BETWEEN 13 AND 21
           AND hour_of_day BETWEEN 15 AND 23
           AND (primary_category LIKE '%Soft Drinks%' OR primary_category LIKE '%Snack%' OR primary_category LIKE '%Chips%')
           THEN 70
      WHEN text_blob LIKE '%game%' OR text_blob LIKE '%gaming%' OR text_blob LIKE '%ml%' OR text_blob LIKE '%laro%'
           THEN 80
      ELSE 0
    END AS gamer_score,

    -- Night Shift: late hours + energy/coffee
    CASE
      WHEN (hour_of_day >= 22 OR hour_of_day <= 5)
           AND (primary_category LIKE '%Energy%' OR primary_category LIKE '%Coffee%' OR primary_category LIKE '%Noodles%')
           THEN 85
      WHEN text_blob LIKE '%shift%' OR text_blob LIKE '%night%' OR text_blob LIKE '%gabi%' OR text_blob LIKE '%graveyard%'
           THEN 90
      ELSE 0
    END AS night_shift_score
  FROM signals
),

best_persona AS (
  SELECT
    canonical_tx_id,
    role_explicit,
    CASE
      -- Explicit role takes precedence
      WHEN role_explicit IS NOT NULL THEN role_explicit
      -- Otherwise, pick highest scoring persona
      WHEN student_score >= GREATEST(office_worker_score, rider_score, parent_score, senior_score, reseller_score, gamer_score, night_shift_score) AND student_score > 50 THEN 'Student'
      WHEN office_worker_score >= GREATEST(student_score, rider_score, parent_score, senior_score, reseller_score, gamer_score, night_shift_score) AND office_worker_score > 50 THEN 'Office Worker'
      WHEN rider_score >= GREATEST(student_score, office_worker_score, parent_score, senior_score, reseller_score, gamer_score, night_shift_score) AND rider_score > 50 THEN 'Delivery Rider'
      WHEN parent_score >= GREATEST(student_score, office_worker_score, rider_score, senior_score, reseller_score, gamer_score, night_shift_score) AND parent_score > 50 THEN 'Parent'
      WHEN senior_score >= GREATEST(student_score, office_worker_score, rider_score, parent_score, reseller_score, gamer_score, night_shift_score) AND senior_score > 50 THEN 'Senior Citizen'
      WHEN reseller_score >= GREATEST(student_score, office_worker_score, rider_score, parent_score, senior_score, gamer_score, night_shift_score) AND reseller_score > 50 THEN 'Reseller'
      WHEN gamer_score >= GREATEST(student_score, office_worker_score, rider_score, parent_score, senior_score, reseller_score, night_shift_score) AND gamer_score > 50 THEN 'Teen Gamer'
      WHEN night_shift_score >= GREATEST(student_score, office_worker_score, rider_score, parent_score, senior_score, reseller_score, gamer_score) AND night_shift_score > 50 THEN 'Night-Shift Worker'
      ELSE 'Regular'
    END AS role_inferred
  FROM persona_scoring
)

-- Final output: one role per transaction
SELECT
  canonical_tx_id,
  role_inferred AS role
FROM best_persona;

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

    -- Test persona distribution
    SELECT TOP 8
        role,
        COUNT(*) as count,
        CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as decimal(5,1)) as percentage
    FROM ref.v_persona_inference
    GROUP BY role
    ORDER BY COUNT(*) DESC;
END
ELSE
BEGIN
    PRINT '❌ Failed to create ref.v_persona_inference view';
END

PRINT '✅ Migration 003_create_persona_inference_FIXED completed successfully';
GO