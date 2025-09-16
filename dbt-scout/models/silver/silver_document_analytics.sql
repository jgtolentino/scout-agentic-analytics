{{ config(
    materialized='incremental',
    unique_key='document_id',
    on_schema_change='fail',
    pre_hook="CALL metadata.validate_silver_dependencies('silver_document_analytics')",
    post_hook=[
        "CALL metadata.record_lineage_event('{{ this }}', 'silver_document_analytics', 'COMPLETE')",
        "CALL metadata.update_medallion_health('silver', '{{ this }}', 'document_analytics')"
    ]
) }}

/*
    Silver layer for document analytics
    Standardized and enriched document metadata with content analysis
*/

WITH bronze_documents AS (
    SELECT 
        file_id,
        file_name,
        folder_id,
        folder_name,
        mime_type,
        file_category,
        file_size_bytes,
        file_content,
        file_metadata,
        created_time,
        modified_time,
        created_by,
        version_number,
        quality_score,
        contains_potential_pii,
        synced_at,
        ingested_at,
        job_run_id
    FROM {{ ref('bronze_drive_files') }}
    
    {% if is_incremental() %}
        WHERE synced_at > (SELECT COALESCE(MAX(last_modified), '1900-01-01'::timestamp) FROM {{ this }})
    {% endif %}
),

-- Content analysis and text extraction
content_analysis AS (
    SELECT 
        *,
        -- Document classification
        CASE 
            WHEN file_name ~* '(proposal|brief|strategy|plan)' THEN 'strategy_document'
            WHEN file_name ~* '(report|analysis|insight|research)' THEN 'analytics_report'
            WHEN file_name ~* '(presentation|slide|deck)' THEN 'presentation'
            WHEN file_name ~* '(contract|agreement|legal)' THEN 'legal_document'
            WHEN file_name ~* '(budget|financial|cost|invoice)' THEN 'financial_document'
            WHEN file_name ~* '(creative|design|visual|brand)' THEN 'creative_asset'
            ELSE 'general_document'
        END as document_type,
        
        -- Extract text content for analysis (if not PII)
        CASE 
            WHEN NOT contains_potential_pii 
            AND mime_type IN ('application/pdf', 'text/plain')
            THEN COALESCE(
                file_metadata->>'extracted_text',
                LEFT(CONVERT_FROM(file_content, 'UTF8'), 1000)
            )
            ELSE NULL
        END as text_preview,
        
        -- File size categorization
        CASE 
            WHEN file_size_bytes < 1024 THEN 'tiny'
            WHEN file_size_bytes < 1024*1024 THEN 'small'
            WHEN file_size_bytes < 10*1024*1024 THEN 'medium'
            WHEN file_size_bytes < 100*1024*1024 THEN 'large'
            ELSE 'very_large'
        END as size_category,
        
        -- Collaboration indicators
        CASE 
            WHEN file_metadata ? 'shared_with' THEN true
            WHEN file_metadata ? 'permissions' THEN true
            ELSE false
        END as is_collaborative,
        
        -- Update frequency analysis
        CASE 
            WHEN version_number > 5 THEN 'frequently_updated'
            WHEN version_number > 2 THEN 'occasionally_updated'
            ELSE 'static'
        END as update_pattern
        
    FROM bronze_documents
),

-- Standardization and enrichment
standardized AS (
    SELECT 
        -- Primary identifiers
        file_id as document_id,
        TRIM(LOWER(file_name)) as standardized_filename,
        file_name as original_filename,
        folder_id,
        folder_name,
        
        -- Document classification
        document_type,
        file_category,
        mime_type,
        size_category,
        
        -- Content metadata
        file_size_bytes,
        text_preview,
        contains_potential_pii,
        is_collaborative,
        update_pattern,
        
        -- Version and quality tracking
        version_number,
        quality_score,
        CASE 
            WHEN quality_score >= 0.8 THEN 'high_quality'
            WHEN quality_score >= 0.6 THEN 'medium_quality'
            ELSE 'low_quality'
        END as quality_tier,
        
        -- Author and ownership
        COALESCE(
            NULLIF(TRIM(created_by), ''),
            'unknown'
        ) as document_author,
        
        -- Temporal fields
        created_time::timestamp as document_created_at,
        modified_time::timestamp as last_modified,
        synced_at as last_synced,
        
        -- Business context enrichment
        CASE 
            WHEN folder_name ~* '(client|account)' THEN 'client_work'
            WHEN folder_name ~* '(internal|admin|hr)' THEN 'internal_operations'
            WHEN folder_name ~* '(creative|campaign|brand)' THEN 'creative_work'
            WHEN folder_name ~* '(research|insight|data)' THEN 'research_analytics'
            ELSE 'general'
        END as business_category,
        
        -- Compliance and governance
        CASE 
            WHEN contains_potential_pii OR document_type = 'legal_document' 
            THEN 'restricted'
            WHEN is_collaborative 
            THEN 'shared'
            ELSE 'standard'
        END as access_classification,
        
        -- Analytics dimensions
        DATE_TRUNC('month', created_time) as creation_month,
        DATE_TRUNC('week', modified_time) as modification_week,
        EXTRACT(YEAR FROM created_time) as creation_year,
        EXTRACT(DOW FROM created_time) as creation_day_of_week,
        
        -- Audit fields
        ingested_at as bronze_ingested_at,
        CURRENT_TIMESTAMP as silver_processed_at,
        job_run_id as source_job_run_id,
        '{{ invocation_id }}' as dbt_run_id
        
    FROM content_analysis
),

-- Final validation and business rules
final AS (
    SELECT 
        document_id,
        standardized_filename,
        original_filename,
        folder_id,
        folder_name,
        document_type,
        file_category,
        mime_type,
        size_category,
        file_size_bytes,
        
        -- Apply content masking for PII documents
        CASE 
            WHEN contains_potential_pii 
            THEN '[CONTENT MASKED FOR PRIVACY]'
            ELSE text_preview
        END as content_preview,
        
        contains_potential_pii as has_pii_risk,
        is_collaborative,
        update_pattern,
        version_number,
        quality_score,
        quality_tier,
        document_author,
        business_category,
        access_classification,
        
        -- Calculated metrics
        CASE 
            WHEN last_modified > document_created_at 
            THEN EXTRACT(DAYS FROM (last_modified - document_created_at))
            ELSE 0
        END as days_since_creation,
        
        CASE 
            WHEN last_synced > last_modified 
            THEN EXTRACT(HOURS FROM (last_synced - last_modified))
            ELSE 0
        END as sync_lag_hours,
        
        -- Temporal dimensions
        document_created_at,
        last_modified,
        last_synced,
        creation_month,
        modification_week,
        creation_year,
        creation_day_of_week,
        
        -- Audit trail
        bronze_ingested_at,
        silver_processed_at,
        source_job_run_id,
        dbt_run_id,
        
        -- Data lineage
        'bronze_drive_files' as source_table,
        'silver' as processing_layer
        
    FROM standardized
    
    -- Quality filters
    WHERE document_id IS NOT NULL
    AND standardized_filename IS NOT NULL
    AND file_size_bytes >= 0
    AND quality_score >= 0.3  -- Minimum quality threshold
)

SELECT * FROM final