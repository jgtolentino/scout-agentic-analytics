-- ===================================================================
-- Suqi Analytics Intelligence Tables Migration
-- Date: September 26, 2025
-- Purpose: Add STT processing and persona inference capabilities
-- Compatible with: Azure SQL Database
-- ===================================================================

-- Create intelligence schema
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'intel')
    EXEC('CREATE SCHEMA intel AUTHORIZATION dbo');
GO

-- ===================================================================
-- 1. STT Job Control & Artifacts
-- ===================================================================

-- STT job queue and status tracking
CREATE TABLE intel.stt_jobs (
    job_id           UNIQUEIDENTIFIER  NOT NULL DEFAULT NEWID() PRIMARY KEY,
    source_uri       NVARCHAR(400)     NOT NULL,   -- blob path or local file path
    store_id         NVARCHAR(64)      NULL,       -- store identifier
    txn_ts_hint      DATETIME2(3)      NULL,       -- optional transaction timestamp hint
    lang             NVARCHAR(16)      NULL,       -- language code (e.g., 'fil', 'en')
    status           NVARCHAR(24)      NOT NULL DEFAULT N'queued', -- queued|running|done|error
    error_message    NVARCHAR(4000)    NULL,       -- error details if status = 'error'
    created_utc      DATETIME2(3)      NOT NULL DEFAULT SYSUTCDATETIME(),
    started_utc      DATETIME2(3)      NULL,       -- when processing started
    finished_utc     DATETIME2(3)      NULL,       -- when processing completed/failed

    -- Performance tracking
    processing_time_ms INT             NULL,       -- total processing time
    audio_duration_ms  INT             NULL,       -- original audio duration

    -- Metadata
    metadata         NVARCHAR(MAX)     NULL,       -- JSON metadata (file size, format, etc.)

    CONSTRAINT CK_stt_jobs_status CHECK (status IN ('queued', 'running', 'done', 'error'))
);
GO

-- Indexes for STT jobs
CREATE INDEX IX_stt_jobs_status_created ON intel.stt_jobs (status, created_utc);
CREATE INDEX IX_stt_jobs_store_id ON intel.stt_jobs (store_id) WHERE store_id IS NOT NULL;
CREATE INDEX IX_stt_jobs_finished ON intel.stt_jobs (finished_utc) WHERE finished_utc IS NOT NULL;
GO

-- ===================================================================
-- 2. Transcription Results
-- ===================================================================

-- Master transcript table
CREATE TABLE intel.transcripts (
    transcript_id    UNIQUEIDENTIFIER  NOT NULL DEFAULT NEWID() PRIMARY KEY,
    job_id           UNIQUEIDENTIFIER  NOT NULL,
    store_id         NVARCHAR(64)      NULL,       -- copied from job for faster queries
    txn_ts           DATETIME2(3)      NULL,       -- inferred/provided transaction timestamp
    duration_ms      INT               NULL,       -- transcript duration in milliseconds
    text_clean       NVARCHAR(MAX)     NULL,       -- sanitized transcript text
    text_raw         NVARCHAR(MAX)     NULL,       -- original transcript (optional)
    lang             NVARCHAR(16)      NULL,       -- detected/specified language
    confidence       DECIMAL(4,3)      NULL,       -- overall transcription confidence (0-1)

    -- Analysis flags
    has_segments     BIT               NOT NULL DEFAULT 0,
    has_brands       BIT               NOT NULL DEFAULT 0,
    has_personas     BIT               NOT NULL DEFAULT 0,

    -- Timestamps
    created_utc      DATETIME2(3)      NOT NULL DEFAULT SYSUTCDATETIME(),
    analyzed_utc     DATETIME2(3)      NULL,       -- when analysis was completed

    CONSTRAINT FK_transcripts_jobs FOREIGN KEY (job_id) REFERENCES intel.stt_jobs(job_id) ON DELETE CASCADE
);
GO

-- Indexes for transcripts
CREATE INDEX IX_transcripts_job_id ON intel.transcripts (job_id);
CREATE INDEX IX_transcripts_store_txn ON intel.transcripts (store_id, txn_ts) WHERE store_id IS NOT NULL AND txn_ts IS NOT NULL;
CREATE INDEX IX_transcripts_created ON intel.transcripts (created_utc);
CREATE INDEX IX_transcripts_analysis_flags ON intel.transcripts (has_segments, has_brands, has_personas);
GO

-- ===================================================================
-- 3. Conversation Segmentation
-- ===================================================================

-- Individual conversation segments with speaker roles
CREATE TABLE intel.conversation_segments (
    segment_id       BIGINT IDENTITY(1,1) PRIMARY KEY,
    transcript_id    UNIQUEIDENTIFIER NOT NULL,
    speaker_role     NVARCHAR(16)     NULL,       -- customer|staff|owner|unknown
    start_ms         INT              NULL,       -- segment start time in milliseconds
    end_ms           INT              NULL,       -- segment end time in milliseconds
    text             NVARCHAR(MAX)    NULL,       -- segment text content
    confidence       DECIMAL(4,3)     NULL,       -- segment confidence (0-1)

    -- Quick brand mentions (denormalized for performance)
    brand_mentions   NVARCHAR(1000)   NULL,       -- comma-separated brand list
    brand_count      SMALLINT         NOT NULL DEFAULT 0,

    -- Analysis metadata
    sentiment        NVARCHAR(16)     NULL,       -- positive|negative|neutral
    intent           NVARCHAR(32)     NULL,       -- inquiry|complaint|purchase|etc

    created_utc      DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_segments_transcripts FOREIGN KEY (transcript_id) REFERENCES intel.transcripts(transcript_id) ON DELETE CASCADE,
    CONSTRAINT CK_segment_times CHECK (start_ms IS NULL OR end_ms IS NULL OR start_ms <= end_ms),
    CONSTRAINT CK_speaker_role CHECK (speaker_role IS NULL OR speaker_role IN ('customer', 'staff', 'owner', 'unknown'))
);
GO

-- Indexes for conversation segments
CREATE INDEX IX_segments_transcript_id ON intel.conversation_segments (transcript_id);
CREATE INDEX IX_segments_speaker_role ON intel.conversation_segments (speaker_role) WHERE speaker_role IS NOT NULL;
CREATE INDEX IX_segments_brand_count ON intel.conversation_segments (brand_count) WHERE brand_count > 0;
CREATE INDEX IX_segments_sentiment ON intel.conversation_segments (sentiment) WHERE sentiment IS NOT NULL;
GO

-- ===================================================================
-- 4. Brand Mention Tracking (Normalized)
-- ===================================================================

-- Normalized brand mentions with context
CREATE TABLE intel.segment_brands (
    segment_id       BIGINT NOT NULL,
    brand            NVARCHAR(128) NOT NULL,
    context          NVARCHAR(64)  NULL,       -- request|suggestion|switch|complaint|praise
    confidence       DECIMAL(4,3)  NULL,      -- brand detection confidence (0-1)
    position_start   SMALLINT      NULL,      -- character position in segment text
    position_end     SMALLINT      NULL,      -- end position

    PRIMARY KEY (segment_id, brand),
    CONSTRAINT FK_segbrands_segments FOREIGN KEY (segment_id) REFERENCES intel.conversation_segments(segment_id) ON DELETE CASCADE,
    CONSTRAINT CK_brand_positions CHECK (position_start IS NULL OR position_end IS NULL OR position_start <= position_end)
);
GO

-- Indexes for brand mentions
CREATE INDEX IX_segment_brands_brand ON intel.segment_brands (brand);
CREATE INDEX IX_segment_brands_context ON intel.segment_brands (context) WHERE context IS NOT NULL;
CREATE INDEX IX_segment_brands_confidence ON intel.segment_brands (confidence DESC) WHERE confidence IS NOT NULL;
GO

-- ===================================================================
-- 5. Multi-Signal Persona Inference
-- ===================================================================

-- Persona signals extracted from conversations and transactions
CREATE TABLE intel.persona_signals (
    signal_id        BIGINT IDENTITY(1,1) PRIMARY KEY,
    transcript_id    UNIQUEIDENTIFIER NOT NULL,
    transaction_id   NVARCHAR(64)     NULL,       -- linked transaction if available

    -- Signal identification
    signal_key       NVARCHAR(64)     NOT NULL,   -- e.g., 'token:gatas', 'hour:late', 'brand:tide'
    signal_value     NVARCHAR(256)    NULL,       -- signal value/context
    signal_type      NVARCHAR(32)     NOT NULL,   -- token|temporal|brand|behavioral|demographic

    -- Signal scoring
    weight           DECIMAL(5,2)     NOT NULL DEFAULT 1.0,
    confidence       DECIMAL(4,3)     NULL,      -- signal extraction confidence

    -- Metadata
    extraction_method NVARCHAR(32)    NULL,      -- whisper|regex|ml_model|etc
    created_utc      DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_ps_transcripts FOREIGN KEY (transcript_id) REFERENCES intel.transcripts(transcript_id) ON DELETE CASCADE,
    CONSTRAINT CK_signal_type CHECK (signal_type IN ('token', 'temporal', 'brand', 'behavioral', 'demographic', 'contextual'))
);
GO

-- Indexes for persona signals
CREATE INDEX IX_persona_signals_transcript ON intel.persona_signals (transcript_id);
CREATE INDEX IX_persona_signals_transaction ON intel.persona_signals (transaction_id) WHERE transaction_id IS NOT NULL;
CREATE INDEX IX_persona_signals_key_type ON intel.persona_signals (signal_key, signal_type);
CREATE INDEX IX_persona_signals_weight ON intel.persona_signals (weight DESC);
GO

-- ===================================================================
-- 6. Persona Inference Results
-- ===================================================================

-- Final persona inference results with confidence scoring
CREATE TABLE intel.persona_inference (
    inference_id     BIGINT IDENTITY(1,1) PRIMARY KEY,
    transcript_id    UNIQUEIDENTIFIER NOT NULL,
    transaction_id   NVARCHAR(64)     NULL,       -- linked transaction if matched

    -- Persona classification
    inferred_role    NVARCHAR(64)     NOT NULL,   -- customer_regular|customer_new|owner|staff|competitor
    confidence       DECIMAL(4,2)     NOT NULL,   -- inference confidence (0-100)
    alternative_roles NVARCHAR(256)   NULL,       -- JSON array of alternative roles with scores

    -- Supporting evidence
    signal_count     SMALLINT         NOT NULL DEFAULT 0,
    key_signals      NVARCHAR(512)    NULL,      -- comma-separated key signals

    -- Model version and metadata
    rule_version     NVARCHAR(16)     NOT NULL,   -- inference rule version (e.g., 'v2.1')
    model_metadata   NVARCHAR(MAX)    NULL,       -- JSON model parameters and thresholds

    -- Timestamps
    created_utc      DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
    validated_utc    DATETIME2(3)     NULL,       -- manual validation timestamp
    validator        NVARCHAR(64)     NULL,       -- who validated this inference

    CONSTRAINT FK_pi_transcripts FOREIGN KEY (transcript_id) REFERENCES intel.transcripts(transcript_id) ON DELETE CASCADE,
    CONSTRAINT CK_confidence_range CHECK (confidence >= 0 AND confidence <= 100)
);
GO

-- Indexes for persona inference
CREATE INDEX IX_persona_inference_transcript ON intel.persona_inference (transcript_id);
CREATE INDEX IX_persona_inference_transaction ON intel.persona_inference (transaction_id) WHERE transaction_id IS NOT NULL;
CREATE INDEX IX_persona_inference_role ON intel.persona_inference (inferred_role);
CREATE INDEX IX_persona_inference_confidence ON intel.persona_inference (confidence DESC);
CREATE INDEX IX_persona_inference_version ON intel.persona_inference (rule_version);
GO

-- ===================================================================
-- 7. Analytics and Export Views
-- ===================================================================

-- Comprehensive conversation segments view for analytics
CREATE OR ALTER VIEW gold.v_conversation_segments AS
SELECT
    s.segment_id,
    s.transcript_id,
    t.job_id,
    t.store_id,
    t.txn_ts,
    s.speaker_role,
    s.start_ms,
    s.end_ms,
    s.text,
    s.confidence as segment_confidence,
    s.brand_mentions,
    s.brand_count,
    s.sentiment,
    s.intent,
    t.lang,
    t.duration_ms as total_duration_ms,
    s.created_utc
FROM intel.conversation_segments s
JOIN intel.transcripts t ON t.transcript_id = s.transcript_id;
GO

-- Persona inference analytics view
CREATE OR ALTER VIEW gold.v_persona_inference AS
SELECT
    i.inference_id,
    i.transcript_id,
    i.transaction_id,
    i.inferred_role,
    i.confidence,
    i.signal_count,
    i.key_signals,
    i.rule_version,
    t.store_id,
    t.txn_ts,
    t.text_clean,
    t.lang,
    i.created_utc,
    i.validated_utc,
    i.validator
FROM intel.persona_inference i
JOIN intel.transcripts t ON t.transcript_id = i.transcript_id;
GO

-- Brand analytics view with conversation context
CREATE OR ALTER VIEW gold.v_brand_conversation_analytics AS
SELECT
    sb.brand,
    sb.context,
    COUNT(*) as mention_count,
    AVG(sb.confidence) as avg_confidence,
    COUNT(DISTINCT s.transcript_id) as transcript_count,
    COUNT(DISTINCT t.store_id) as store_count,
    MIN(s.created_utc) as first_mention,
    MAX(s.created_utc) as latest_mention
FROM intel.segment_brands sb
JOIN intel.conversation_segments s ON s.segment_id = sb.segment_id
JOIN intel.transcripts t ON t.transcript_id = s.transcript_id
GROUP BY sb.brand, sb.context;
GO

-- STT job performance analytics
CREATE OR ALTER VIEW gold.v_stt_performance AS
SELECT
    j.status,
    COUNT(*) as job_count,
    AVG(j.processing_time_ms) as avg_processing_ms,
    AVG(CAST(j.audio_duration_ms AS FLOAT)) as avg_audio_duration_ms,
    AVG(CASE WHEN j.audio_duration_ms > 0 THEN
        CAST(j.processing_time_ms AS FLOAT) / CAST(j.audio_duration_ms AS FLOAT)
        ELSE NULL END) as processing_ratio,
    MIN(j.created_utc) as earliest_job,
    MAX(j.finished_utc) as latest_completion
FROM intel.stt_jobs j
GROUP BY j.status;
GO

-- ===================================================================
-- 8. Stored Procedures for ETL Operations
-- ===================================================================

-- Procedure to update transcript analysis flags
CREATE OR ALTER PROCEDURE intel.sp_update_transcript_flags
    @transcript_id UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE intel.transcripts
    SET
        has_segments = CASE WHEN EXISTS (
            SELECT 1 FROM intel.conversation_segments
            WHERE transcript_id = @transcript_id
        ) THEN 1 ELSE 0 END,

        has_brands = CASE WHEN EXISTS (
            SELECT 1 FROM intel.conversation_segments s
            JOIN intel.segment_brands sb ON sb.segment_id = s.segment_id
            WHERE s.transcript_id = @transcript_id
        ) THEN 1 ELSE 0 END,

        has_personas = CASE WHEN EXISTS (
            SELECT 1 FROM intel.persona_inference
            WHERE transcript_id = @transcript_id
        ) THEN 1 ELSE 0 END,

        analyzed_utc = SYSUTCDATETIME()
    WHERE transcript_id = @transcript_id;
END;
GO

-- Procedure to clean old STT jobs (for maintenance)
CREATE OR ALTER PROCEDURE intel.sp_cleanup_old_stt_jobs
    @retention_days INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @cutoff_date DATETIME2(3) = DATEADD(DAY, -@retention_days, SYSUTCDATETIME());

    -- Clean up completed/error jobs older than retention period
    DELETE FROM intel.stt_jobs
    WHERE status IN ('done', 'error')
      AND finished_utc < @cutoff_date;

    SELECT @@ROWCOUNT as deleted_jobs;
END;
GO

-- ===================================================================
-- 9. Sample Data Validation Queries
-- ===================================================================

-- Validation: Check all tables exist and are accessible
/*
SELECT
    'intel.stt_jobs' as table_name,
    COUNT(*) as row_count
FROM intel.stt_jobs

UNION ALL

SELECT
    'intel.transcripts',
    COUNT(*)
FROM intel.transcripts

UNION ALL

SELECT
    'intel.conversation_segments',
    COUNT(*)
FROM intel.conversation_segments

UNION ALL

SELECT
    'intel.segment_brands',
    COUNT(*)
FROM intel.segment_brands

UNION ALL

SELECT
    'intel.persona_signals',
    COUNT(*)
FROM intel.persona_signals

UNION ALL

SELECT
    'intel.persona_inference',
    COUNT(*)
FROM intel.persona_inference;
*/

-- ===================================================================
-- 10. Permissions and Security
-- ===================================================================

-- Grant permissions to existing roles (adjust as needed)
-- GRANT SELECT, INSERT, UPDATE ON SCHEMA::intel TO [scout_analytics_role];
-- GRANT EXECUTE ON intel.sp_update_transcript_flags TO [scout_analytics_role];
-- GRANT EXECUTE ON intel.sp_cleanup_old_stt_jobs TO [scout_analytics_role];

PRINT 'Suqi Analytics Intelligence Tables Migration completed successfully.';
PRINT 'Created schema: intel';
PRINT 'Created tables: stt_jobs, transcripts, conversation_segments, segment_brands, persona_signals, persona_inference';
PRINT 'Created views: gold.v_conversation_segments, gold.v_persona_inference, gold.v_brand_conversation_analytics, gold.v_stt_performance';
PRINT 'Created procedures: intel.sp_update_transcript_flags, intel.sp_cleanup_old_stt_jobs';

-- Show table sizes for verification
SELECT
    SCHEMA_NAME(t.schema_id) as schema_name,
    t.name as table_name,
    i.rows as row_count
FROM sys.tables t
JOIN sys.indexes i ON t.object_id = i.object_id
WHERE SCHEMA_NAME(t.schema_id) = 'intel'
  AND i.index_id IN (0, 1)  -- clustered index or heap
ORDER BY schema_name, table_name;

GO