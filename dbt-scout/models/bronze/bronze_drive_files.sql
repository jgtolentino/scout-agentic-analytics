{{ config(
    materialized='incremental',
    unique_key='file_id',
    on_schema_change='fail',
    pre_hook="CALL contracts.validate_bronze_batch('drive_files', '{{ this }}'::text)",
    post_hook=[
        "CALL metadata.record_lineage_event('{{ this }}', 'bronze_drive_files', 'COMPLETE')",
        "CALL metadata.update_medallion_health('bronze', '{{ this }}', 'drive_files')"
    ]
) }}

/*
    Bronze layer for Google Drive files
    Raw file ingestion with metadata preservation and quality validation
*/

WITH drive_source AS (
    SELECT 
        file_id,
        file_name,
        folder_id,
        folder_name,
        mime_type,
        file_size_bytes,
        md5_checksum,
        file_content,
        file_metadata,
        created_time,
        modified_time,
        synced_at,
        job_run_id,
        -- Quality indicators
        CASE 
            WHEN file_content IS NOT NULL 
            AND file_size_bytes > 0 
            AND md5_checksum IS NOT NULL 
            THEN 1.0 
            ELSE 0.5 
        END as quality_score,
        
        -- File type classification
        CASE 
            WHEN mime_type LIKE 'application/pdf' THEN 'document'
            WHEN mime_type LIKE 'application/vnd.openxmlformats-officedocument%' THEN 'document'
            WHEN mime_type LIKE 'application/vnd.google-apps%' THEN 'google_workspace'
            WHEN mime_type LIKE 'image/%' THEN 'image'
            WHEN mime_type LIKE 'video/%' THEN 'video'
            WHEN mime_type LIKE 'audio/%' THEN 'audio'
            ELSE 'other'
        END as file_category,
        
        -- Metadata extraction
        CASE 
            WHEN file_metadata ? 'createdBy' 
            THEN file_metadata->>'createdBy'
            ELSE 'unknown'
        END as created_by,
        
        CASE 
            WHEN file_metadata ? 'version' 
            THEN (file_metadata->>'version')::int
            ELSE 1
        END as version_number,
        
        -- PII detection flags
        CASE 
            WHEN file_name ~* '(confidential|private|personal|ssn|tax|financial)' 
            OR file_content::text ~* '(ssn|social security|tax id|confidential)'
            THEN true
            ELSE false
        END as contains_potential_pii,
        
        -- Audit fields
        CURRENT_TIMESTAMP as ingested_at,
        '{{ invocation_id }}' as dbt_run_id
        
    FROM {{ ref('edge.bronze_drive_imports') }}
    
    {% if is_incremental() %}
        -- Incremental processing: only new or updated files
        WHERE synced_at > (SELECT MAX(synced_at) FROM {{ this }})
    {% endif %}
),

-- Data quality validation
quality_validated AS (
    SELECT *,
        -- Overall quality score
        CASE 
            WHEN quality_score >= 0.8 AND NOT contains_potential_pii THEN 'high'
            WHEN quality_score >= 0.6 THEN 'medium'
            ELSE 'low'
        END as quality_tier,
        
        -- File integrity validation
        CASE 
            WHEN file_size_bytes > 0 
            AND md5_checksum IS NOT NULL 
            AND LENGTH(md5_checksum) = 32
            THEN true
            ELSE false
        END as integrity_validated
        
    FROM drive_source
),

-- Apply business rules and transformations
final AS (
    SELECT 
        file_id,
        file_name,
        folder_id,
        folder_name,
        mime_type,
        file_category,
        file_size_bytes,
        md5_checksum,
        
        -- Conditionally mask PII content
        CASE 
            WHEN contains_potential_pii 
            THEN '[CONTENT MASKED - PII DETECTED]'::bytea
            ELSE file_content
        END as file_content,
        
        -- Sanitized metadata
        CASE 
            WHEN contains_potential_pii 
            THEN jsonb_build_object(
                'category', file_category,
                'pii_detected', true,
                'original_size', file_size_bytes
            )
            ELSE file_metadata
        END as file_metadata,
        
        created_time,
        modified_time,
        created_by,
        version_number,
        quality_score,
        quality_tier,
        integrity_validated,
        contains_potential_pii,
        synced_at,
        ingested_at,
        job_run_id,
        dbt_run_id,
        
        -- Lineage tracking
        'drive_api' as source_system,
        CURRENT_TIMESTAMP as processed_at
        
    FROM quality_validated
    
    -- Filter out corrupted or invalid files
    WHERE file_size_bytes >= 0 
    AND file_name IS NOT NULL
    AND file_id IS NOT NULL
)

SELECT * FROM final