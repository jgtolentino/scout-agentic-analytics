SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ========================================================================
 * Scout Analytics - Transcript Parser with Speaker Separation
 * Migration: 20250926_16_transcript_parser_procs.sql
 * Purpose: Parse transcripts into segments and extract conversation signals
 * ======================================================================== */

CREATE OR ALTER PROCEDURE etl.sp_parse_transcripts_basic
AS
BEGIN
    SET NOCOUNT ON;

    /* Clear & rebuild segments for transactions with transcripts */
    DELETE s
    FROM etl.conversation_segments s
    WHERE EXISTS (
        SELECT 1 FROM dbo.v_transactions_flat_production t
        WHERE t.canonical_tx_id = s.canonical_tx_id
        AND t.audio_transcript IS NOT NULL
    );

    /* Parse transcripts into conversation segments */
    ;WITH src AS (
        SELECT
            t.canonical_tx_id,
            -- Normalize separators: treat ., ?, ! and ' | ' as boundaries
            REPLACE(REPLACE(REPLACE(REPLACE(
                COALESCE(t.audio_transcript,''),
                CHAR(10),' '), CHAR(13),' '), '|', '. '), ';', '. ') AS norm
        FROM dbo.v_transactions_flat_production t
        WHERE t.audio_transcript IS NOT NULL AND LEN(t.audio_transcript) > 0
    ),
    exploded AS (
        SELECT canonical_tx_id, value AS piece
        FROM src
        CROSS APPLY STRING_SPLIT(norm, '.')
    ),
    cleaned AS (
        SELECT canonical_tx_id,
               LTRIM(RTRIM(piece)) AS utt
        FROM exploded
        WHERE LTRIM(RTRIM(piece)) <> ''
    )
    INSERT INTO etl.conversation_segments(canonical_tx_id, seg_id, speaker, utterance)
    SELECT c.canonical_tx_id,
           ROW_NUMBER() OVER (PARTITION BY c.canonical_tx_id ORDER BY (SELECT 1)) AS seg_id,
           CASE
             -- Customer patterns (requests, greetings, decisions)
             WHEN c.utt LIKE '%pabili%' OR c.utt LIKE '%gusto ko%' OR c.utt LIKE '%kuha ako%' THEN 'customer'
             WHEN c.utt LIKE '%magkano%' OR c.utt LIKE '%how much%' OR c.utt LIKE '%presyo%' THEN 'customer'
             WHEN c.utt LIKE '%salamat%' OR c.utt LIKE '%thank you%' OR c.utt LIKE '%bye%' THEN 'customer'
             WHEN c.utt LIKE '%hello po%' OR c.utt LIKE '%kuya%' OR c.utt LIKE '%ate%' THEN 'customer'
             WHEN c.utt LIKE '%may %' OR c.utt LIKE '%meron bang%' OR c.utt LIKE '%available%' THEN 'customer'

             -- Owner patterns (availability, pricing, suggestions)
             WHEN c.utt LIKE '%meron po%' OR c.utt LIKE '%wala na%' OR c.utt LIKE '%ubos%' THEN 'owner'
             WHEN c.utt LIKE '%try mo%' OR c.utt LIKE '%mas okay%' OR c.utt LIKE '%promo%' THEN 'owner'
             WHEN c.utt LIKE '%total%' OR c.utt LIKE '%sukli%' OR c.utt LIKE '%bayad%' THEN 'owner'
             WHEN c.utt LIKE '%yes po%' OR c.utt LIKE '%ano po%' OR c.utt LIKE '%welcome%' THEN 'owner'
             WHEN c.utt LIKE '%fixed price%' OR c.utt LIKE '%discount%' OR c.utt LIKE '%package%' THEN 'owner'

             -- Default to NULL if unclear
             ELSE NULL
           END AS speaker,
           c.utt
    FROM cleaned c;

    /* Seed hour bucket signals */
    MERGE etl.persona_signal_facts AS tgt
    USING (
        SELECT
            t.canonical_tx_id,
            'hour' AS signal_type,
            CASE
                WHEN DATEPART(HOUR, t.txn_ts) BETWEEN 5 AND 10  THEN 'morning'
                WHEN DATEPART(HOUR, t.txn_ts) BETWEEN 11 AND 15 THEN 'afternoon'
                WHEN DATEPART(HOUR, t.txn_ts) BETWEEN 16 AND 20 THEN 'evening'
                ELSE 'night'
            END AS signal_value,
            CAST(1.00 AS decimal(5,2)) AS weight
        FROM dbo.v_transactions_flat_production t
    ) s
    ON (tgt.canonical_tx_id = s.canonical_tx_id AND tgt.signal_type='hour')
    WHEN MATCHED THEN UPDATE SET
        signal_value=s.signal_value, weight=s.weight, ts_inferred=SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT (canonical_tx_id, signal_type, signal_value, weight)
        VALUES (s.canonical_tx_id, s.signal_type, s.signal_value, s.weight);

    /* Seed basket size signals */
    MERGE etl.persona_signal_facts AS tgt
    USING (
        SELECT t.canonical_tx_id,
               'basket_size' AS signal_type,
               CASE
                   WHEN t.total_items >= 8 THEN 'bulk'
                   WHEN t.total_items BETWEEN 4 AND 7 THEN 'medium'
                   ELSE 'small'
               END AS signal_value,
               CAST(1.00 AS decimal(5,2)) AS weight
        FROM dbo.v_transactions_flat_production t
    ) s
    ON (tgt.canonical_tx_id = s.canonical_tx_id AND tgt.signal_type='basket_size')
    WHEN MATCHED THEN UPDATE SET
        signal_value=s.signal_value, weight=s.weight, ts_inferred=SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT (canonical_tx_id, signal_type, signal_value, weight)
        VALUES (s.canonical_tx_id, s.signal_type, s.signal_value, s.weight);

    /* Seed dominant Nielsen group signals */
    MERGE etl.persona_signal_facts AS tgt
    USING (
        SELECT DISTINCT
            t.canonical_tx_id,
            'nielsen_group' AS signal_type,
            CASE
                -- Extract Nielsen group from category or use existing logic
                WHEN t.category LIKE '%Beverages%' THEN 'Beverages'
                WHEN t.category LIKE '%Tobacco%' THEN 'Tobacco Products'
                WHEN t.category LIKE '%Instant%' AND t.category LIKE '%Coffee%' THEN 'Instant Coffee'
                WHEN t.category LIKE '%Instant%' AND t.category LIKE '%Noodles%' THEN 'Instant Noodles'
                WHEN t.category LIKE '%Personal Care%' THEN 'Personal Care'
                WHEN t.category LIKE '%Snacks%' THEN 'Snacks'
                WHEN t.category LIKE '%Milk%' THEN 'Milk'
                WHEN t.category LIKE '%Energy%' THEN 'Energy Drinks'
                WHEN t.category LIKE '%Soap%' OR t.category LIKE '%Shampoo%' THEN 'Personal Care'
                WHEN t.category LIKE '%Condiments%' THEN 'Condiments'
                ELSE 'Mixed'
            END AS signal_value,
            CAST(1.00 AS decimal(5,2)) AS weight
        FROM dbo.v_transactions_flat_production t
        WHERE t.category IS NOT NULL
    ) s
    ON (tgt.canonical_tx_id = s.canonical_tx_id AND tgt.signal_type='nielsen_group')
    WHEN MATCHED THEN UPDATE SET
        signal_value=s.signal_value, weight=s.weight, ts_inferred=SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT (canonical_tx_id, signal_type, signal_value, weight)
        VALUES (s.canonical_tx_id, s.signal_type, s.signal_value, s.weight);

    /* Summary of parsing results */
    DECLARE @segments_count int, @signals_count int;
    SELECT @segments_count = COUNT(*) FROM etl.conversation_segments;
    SELECT @signals_count = COUNT(*) FROM etl.persona_signal_facts;

    PRINT '✅ Transcript parsing completed';
    PRINT CONCAT('📝 Conversation segments created: ', @segments_count);
    PRINT CONCAT('🔍 Signal facts extracted: ', @signals_count);
END
GO

PRINT '✅ Transcript parser with speaker separation created successfully';
PRINT '🎤 Ready to parse conversations and extract multi-dimensional signals';
GO