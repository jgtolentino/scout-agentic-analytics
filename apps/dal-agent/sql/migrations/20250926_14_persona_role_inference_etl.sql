SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ETL Procedure: Apply persona role inference to all transactions */
CREATE OR ALTER PROCEDURE etl.sp_update_persona_roles
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @rows_updated INT = 0;
    DECLARE @start_time DATETIME2 = GETUTCDATE();

    PRINT 'Starting persona role inference ETL...';

    -- Create temporary mapping table with role assignments
    CREATE TABLE #persona_mappings (
        canonical_tx_id NVARCHAR(64) PRIMARY KEY,
        inferred_role NVARCHAR(100),
        confidence_score DECIMAL(3,2),
        rule_source NVARCHAR(100)
    );

    -- Apply persona rules to demographics + audio transcripts from flat production view
    INSERT INTO #persona_mappings (canonical_tx_id, inferred_role, confidence_score, rule_source)
    SELECT DISTINCT
        vt.canonical_tx_id,
        pr.role_name AS inferred_role,
        CASE
            WHEN pr.priority = 1 THEN 0.95  -- High confidence for priority 1 rules
            WHEN pr.priority = 2 THEN 0.85  -- Medium-high confidence
            WHEN pr.priority = 3 THEN 0.75  -- Medium confidence
            ELSE 0.60                       -- Lower confidence for other rules
        END AS confidence_score,
        CONCAT('rule_', pr.rule_id, '_prio_', pr.priority) AS rule_source
    FROM dbo.v_transactions_flat_production vt
    INNER JOIN dbo.SalesInteractions si ON si.canonical_tx_id = vt.canonical_tx_id
    CROSS JOIN ref.persona_rules pr
    WHERE vt.canonical_tx_id IS NOT NULL
      AND (
        -- Check include terms in combined text (demographics + audio transcript)
        pr.include_terms IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM STRING_SPLIT(pr.include_terms, '|') AS terms
          WHERE LOWER(CONCAT(
            COALESCE(si.Gender,''), ' ',
            COALESCE(CAST(si.Age AS VARCHAR(10)),''), ' ',
            COALESCE(si.EmotionalState,''), ' ',
            COALESCE(vt.audio_transcript,'')
          )) LIKE '%' + LOWER(LTRIM(RTRIM(terms.value))) + '%'
        )
      )
      AND (
        -- Exclude terms check
        pr.exclude_terms IS NULL
        OR NOT EXISTS (
          SELECT 1 FROM STRING_SPLIT(pr.exclude_terms, '|') AS terms
          WHERE LOWER(CONCAT(
            COALESCE(si.Gender,''), ' ',
            COALESCE(CAST(si.Age AS VARCHAR(10)),''), ' ',
            COALESCE(si.EmotionalState,''), ' ',
            COALESCE(vt.audio_transcript,'')
          )) LIKE '%' + LOWER(LTRIM(RTRIM(terms.value))) + '%'
        )
      );

    -- For transactions with multiple possible role assignments, keep the highest priority (lowest priority number)
    WITH ranked_mappings AS (
        SELECT
            canonical_tx_id,
            inferred_role,
            confidence_score,
            rule_source,
            ROW_NUMBER() OVER (
                PARTITION BY canonical_tx_id
                ORDER BY confidence_score DESC, rule_source ASC
            ) AS rn
        FROM #persona_mappings
    )
    DELETE FROM #persona_mappings
    WHERE canonical_tx_id IN (
        SELECT canonical_tx_id
        FROM ranked_mappings
        WHERE rn > 1
    )
    AND NOT EXISTS (
        SELECT 1
        FROM ranked_mappings r
        WHERE r.canonical_tx_id = #persona_mappings.canonical_tx_id
          AND r.rn = 1
          AND r.rule_source = #persona_mappings.rule_source
    );

    -- Update existing persona inference view/table if it exists
    -- First check if v_persona_inference exists and has the right structure
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_NAME = 'v_persona_inference')
    BEGIN
        PRINT 'Found existing v_persona_inference view - persona data will be available via view';
    END

    -- Create/update a materialized persona mapping table for performance
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'persona_inference_cache' AND TABLE_SCHEMA = 'etl')
    BEGIN
        CREATE TABLE etl.persona_inference_cache (
            canonical_tx_id NVARCHAR(64) PRIMARY KEY,
            inferred_role NVARCHAR(100),
            confidence_score DECIMAL(3,2),
            rule_source NVARCHAR(100),
            created_at DATETIME2 DEFAULT GETUTCDATE(),
            updated_at DATETIME2 DEFAULT GETUTCDATE()
        );
        PRINT 'Created etl.persona_inference_cache table';
    END

    -- Upsert into cache table
    MERGE etl.persona_inference_cache AS target
    USING #persona_mappings AS source
    ON target.canonical_tx_id = source.canonical_tx_id
    WHEN MATCHED THEN
        UPDATE SET
            inferred_role = source.inferred_role,
            confidence_score = source.confidence_score,
            rule_source = source.rule_source,
            updated_at = GETUTCDATE()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (canonical_tx_id, inferred_role, confidence_score, rule_source)
        VALUES (source.canonical_tx_id, source.inferred_role, source.confidence_score, source.rule_source);

    SET @rows_updated = @@ROWCOUNT;

    -- Create/update enhanced flat export view with persona roles
    IF NOT EXISTS (SELECT 1 FROM sys.views WHERE name = 'v_flat_export_with_roles')
    BEGIN
        EXEC('
        CREATE VIEW dbo.v_flat_export_with_roles
        AS
        SELECT
            vf.*,
            pic.inferred_role,
            pic.confidence_score AS role_confidence
        FROM dbo.v_flat_export_sheet vf
        LEFT JOIN etl.persona_inference_cache pic ON pic.canonical_tx_id = vf.Transaction_ID
        ');
        PRINT 'Created dbo.v_flat_export_with_roles view';
    END
    ELSE
    BEGIN
        EXEC('
        ALTER VIEW dbo.v_flat_export_with_roles
        AS
        SELECT
            vf.*,
            pic.inferred_role,
            pic.confidence_score AS role_confidence
        FROM dbo.v_flat_export_sheet vf
        LEFT JOIN etl.persona_inference_cache pic ON pic.canonical_tx_id = vf.Transaction_ID
        ');
        PRINT 'Updated dbo.v_flat_export_with_roles view';
    END

    -- Summary statistics
    DECLARE @total_transactions INT;
    DECLARE @roles_assigned INT;
    DECLARE @coverage_pct DECIMAL(5,2);

    SELECT @total_transactions = COUNT(*) FROM dbo.v_flat_export_sheet;
    SELECT @roles_assigned = COUNT(*) FROM etl.persona_inference_cache;
    SET @coverage_pct = CASE WHEN @total_transactions > 0 THEN (@roles_assigned * 100.0 / @total_transactions) ELSE 0 END;

    DECLARE @end_time DATETIME2 = GETUTCDATE();
    DECLARE @duration_ms INT = DATEDIFF(MILLISECOND, @start_time, @end_time);

    PRINT CONCAT('Persona role inference completed in ', @duration_ms, 'ms');
    PRINT CONCAT('Total transactions: ', @total_transactions);
    PRINT CONCAT('Roles assigned: ', @roles_assigned);
    PRINT CONCAT('Coverage: ', @coverage_pct, '%');
    PRINT CONCAT('Cache table updated: ', @rows_updated, ' records');

    -- Show sample of assigned roles
    SELECT TOP 10
        canonical_tx_id,
        inferred_role,
        confidence_score,
        rule_source
    FROM etl.persona_inference_cache
    ORDER BY confidence_score DESC;

    DROP TABLE #persona_mappings;
END
GO

/* Helper view to see persona rule application results */
CREATE OR ALTER VIEW etl.v_persona_coverage_summary
AS
SELECT
    pic.inferred_role,
    COUNT(*) AS transaction_count,
    AVG(pic.confidence_score) AS avg_confidence,
    MIN(pic.confidence_score) AS min_confidence,
    MAX(pic.confidence_score) AS max_confidence
FROM etl.persona_inference_cache pic
GROUP BY pic.inferred_role

UNION ALL

SELECT
    'TOTAL' AS inferred_role,
    COUNT(*) AS transaction_count,
    AVG(pic.confidence_score) AS avg_confidence,
    MIN(pic.confidence_score) AS min_confidence,
    MAX(pic.confidence_score) AS max_confidence
FROM etl.persona_inference_cache pic
GO

PRINT 'Persona role inference ETL procedures created successfully';
PRINT 'Usage: EXEC etl.sp_update_persona_roles';
PRINT 'Validation: SELECT * FROM etl.v_persona_coverage_summary';
PRINT 'Enhanced export: SELECT TOP 10 * FROM dbo.v_flat_export_with_roles WHERE inferred_role IS NOT NULL';