SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ========================================================================
 * Scout Analytics - Persona Validation Views & Coverage Gates
 * Migration: 20250926_19_persona_validation_views.sql
 * Purpose: Create validation views and quality assessment for personas
 * ======================================================================== */

-- View: Overall persona coverage summary
CREATE OR ALTER VIEW gold.v_persona_coverage_summary
AS
SELECT
    total_tx         = COUNT(*),
    assigned_tx      = SUM(CASE WHEN pic.inferred_role IS NOT NULL THEN 1 ELSE 0 END),
    coverage_pct     = CAST(100.0 * SUM(CASE WHEN pic.inferred_role IS NOT NULL THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0) AS decimal(5,2)),
    avg_confidence   = CAST(AVG(CASE WHEN pic.confidence_score IS NOT NULL THEN CAST(pic.confidence_score AS decimal(4,2)) END) AS decimal(4,2)),
    unique_personas  = COUNT(DISTINCT pic.inferred_role),
    high_confidence  = SUM(CASE WHEN pic.confidence_score >= 0.80 THEN 1 ELSE 0 END),
    med_confidence   = SUM(CASE WHEN pic.confidence_score >= 0.60 AND pic.confidence_score < 0.80 THEN 1 ELSE 0 END),
    low_confidence   = SUM(CASE WHEN pic.confidence_score < 0.60 THEN 1 ELSE 0 END)
FROM dbo.v_transactions_flat_production t
LEFT JOIN etl.persona_inference_cache pic ON pic.canonical_tx_id = t.canonical_tx_id;
GO

-- View: High-confidence persona examples for quality assessment
CREATE OR ALTER VIEW gold.v_persona_examples
AS
SELECT TOP 200
    pic.inferred_role,
    pic.canonical_tx_id,
    pic.confidence_score,
    pic.rule_source,
    LEFT(COALESCE(t.audio_transcript,''), 140) AS transcript_snippet,
    t.category,
    t.brand,
    t.daypart,
    DATENAME(hour, t.txn_ts) AS hour_of_day,
    t.total_items AS basket_size
FROM etl.persona_inference_cache pic
JOIN dbo.v_transactions_flat_production t ON t.canonical_tx_id = pic.canonical_tx_id
WHERE pic.inferred_role IS NOT NULL
ORDER BY pic.confidence_score DESC, pic.inferred_role, pic.canonical_tx_id;
GO

-- View: Persona distribution with role-level metrics
CREATE OR ALTER VIEW gold.v_persona_role_distribution
AS
SELECT
    pic.inferred_role,
    COUNT(*) AS transaction_count,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS decimal(5,2)) AS percentage,
    CAST(AVG(pic.confidence_score) AS decimal(4,2)) AS avg_confidence,
    MIN(pic.confidence_score) AS min_confidence,
    MAX(pic.confidence_score) AS max_confidence,
    COUNT(DISTINCT pic.rule_source) AS unique_rules_used
FROM etl.persona_inference_cache pic
WHERE pic.inferred_role IS NOT NULL
GROUP BY pic.inferred_role
UNION ALL
SELECT
    'Unassigned' AS inferred_role,
    COUNT(*) AS transaction_count,
    CAST(100.0 * COUNT(*) / (SELECT COUNT(*) FROM dbo.v_transactions_flat_production) AS decimal(5,2)) AS percentage,
    0.00 AS avg_confidence,
    0.00 AS min_confidence,
    0.00 AS max_confidence,
    0 AS unique_rules_used
FROM dbo.v_transactions_flat_production t
LEFT JOIN etl.persona_inference_cache pic ON pic.canonical_tx_id = t.canonical_tx_id
WHERE pic.inferred_role IS NULL;
GO

-- View: Conversation intelligence quality metrics
CREATE OR ALTER VIEW gold.v_conversation_quality
AS
SELECT
    total_transactions = COUNT(DISTINCT t.canonical_tx_id),
    with_transcripts = SUM(CASE WHEN t.audio_transcript IS NOT NULL AND LEN(t.audio_transcript) > 0 THEN 1 ELSE 0 END),
    with_segments = COUNT(DISTINCT cs.canonical_tx_id),
    avg_segments_per_tx = CAST(AVG(CAST(seg_count.segments AS decimal(10,2))) AS decimal(5,2)),
    customer_segments = SUM(CASE WHEN cs.speaker = 'customer' THEN 1 ELSE 0 END),
    owner_segments = SUM(CASE WHEN cs.speaker = 'owner' THEN 1 ELSE 0 END),
    unattributed_segments = SUM(CASE WHEN cs.speaker IS NULL THEN 1 ELSE 0 END),
    speaker_attribution_pct = CAST(100.0 * SUM(CASE WHEN cs.speaker IS NOT NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS decimal(5,2)),
    signal_facts_generated = (SELECT COUNT(*) FROM etl.persona_signal_facts)
FROM dbo.v_transactions_flat_production t
LEFT JOIN etl.conversation_segments cs ON cs.canonical_tx_id = t.canonical_tx_id
LEFT JOIN (
    SELECT canonical_tx_id, COUNT(*) AS segments
    FROM etl.conversation_segments
    GROUP BY canonical_tx_id
) seg_count ON seg_count.canonical_tx_id = t.canonical_tx_id;
GO

-- View: Signal distribution for persona tuning
CREATE OR ALTER VIEW gold.v_persona_signals
AS
SELECT
    psf.signal_type,
    psf.signal_value,
    COUNT(*) AS occurrence_count,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY psf.signal_type) AS decimal(5,2)) AS percentage_within_type,
    COUNT(DISTINCT pic.inferred_role) AS personas_using_signal,
    CAST(AVG(psf.weight) AS decimal(4,2)) AS avg_weight
FROM etl.persona_signal_facts psf
LEFT JOIN etl.persona_inference_cache pic ON pic.canonical_tx_id = psf.canonical_tx_id
GROUP BY psf.signal_type, psf.signal_value;
GO

-- View: Unassigned transactions for analysis
CREATE OR ALTER VIEW gold.v_unassigned_analysis
AS
SELECT TOP 1000
    t.canonical_tx_id,
    LEFT(COALESCE(t.audio_transcript, ''), 160) AS transcript_snippet,
    t.category,
    t.brand,
    t.daypart,
    DATENAME(hour, t.txn_ts) AS hour_of_day,
    t.total_items AS basket_size,
    hs.signal_value AS hour_bucket,
    gs.signal_value AS nielsen_group,
    bs.signal_value AS basket_category
FROM dbo.v_transactions_flat_production t
LEFT JOIN etl.persona_inference_cache pic ON pic.canonical_tx_id = t.canonical_tx_id
LEFT JOIN etl.persona_signal_facts hs ON hs.canonical_tx_id = t.canonical_tx_id AND hs.signal_type = 'hour'
LEFT JOIN etl.persona_signal_facts gs ON gs.canonical_tx_id = t.canonical_tx_id AND gs.signal_type = 'nielsen_group'
LEFT JOIN etl.persona_signal_facts bs ON bs.canonical_tx_id = t.canonical_tx_id AND bs.signal_type = 'basket_size'
WHERE pic.inferred_role IS NULL
  AND t.audio_transcript IS NOT NULL
  AND LEN(t.audio_transcript) > 0
ORDER BY t.txn_ts DESC;
GO

PRINT '✅ Persona validation views created successfully';
PRINT '📊 Views available:';
PRINT '   - gold.v_persona_coverage_summary (overall metrics)';
PRINT '   - gold.v_persona_examples (high-confidence samples)';
PRINT '   - gold.v_persona_role_distribution (role-level stats)';
PRINT '   - gold.v_conversation_quality (parsing quality metrics)';
PRINT '   - gold.v_persona_signals (signal distribution analysis)';
PRINT '   - gold.v_unassigned_analysis (improvement opportunities)';
PRINT '🎯 Ready for coverage validation and quality assessment';
GO