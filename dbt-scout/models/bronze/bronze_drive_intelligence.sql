{{ config(
    materialized='incremental',
    unique_key='file_id',
    on_schema_change='fail',
    pre_hook="CALL metadata.validate_silver_dependencies('bronze_drive_intelligence')",
    post_hook=[
        "CALL metadata.record_lineage_event('{{ this }}', 'bronze_drive_intelligence', 'COMPLETE')",
        "CALL metadata.update_medallion_health('bronze', '{{ this }}', 'drive_intelligence')"
    ],
    tags=['bronze', 'drive', 'intelligence', 'documents']
) }}

/*
    Bronze layer for comprehensive Google Drive intelligence
    Ingests documents, spreadsheets, presentations, creative assets, financial reports
    Supports: TBWA creative intelligence, financial management, market research
*/

WITH drive_source AS (
    SELECT 
        -- Primary identifiers
        file_id,
        file_name,
        folder_id,
        folder_path,
        
        -- File metadata
        mime_type,
        file_size_bytes,
        md5_checksum,
        created_time,
        modified_time,
        
        -- File content and processing
        file_content,
        extracted_text,
        content_summary,
        key_entities,
        
        -- Quality and compliance
        quality_score,
        contains_pii,
        pii_types,
        compliance_flags,
        
        -- Processing status
        processing_status,
        error_details,
        synced_at,
        processed_at,
        job_run_id,
        
        -- Business context
        business_value,
        confidentiality_level,
        version_number,
        
        -- Timestamps
        created_at,
        updated_at,
        ingested_at
        
    FROM {{ ref('drive_intelligence.bronze_files') }}
    
    {% if is_incremental() %}
        -- Incremental processing: only new or updated files
        WHERE synced_at > (SELECT COALESCE(MAX(synced_at), '1900-01-01'::timestamp) FROM {{ this }})
    {% endif %}
),

-- Enhanced file categorization and business classification
classified_files AS (
    SELECT 
        *,
        
        -- Smart file categorization based on mime type and name patterns
        CASE 
            WHEN mime_type LIKE 'application/pdf' THEN 'pdf'
            WHEN mime_type LIKE 'application/vnd.openxmlformats-officedocument.wordprocessingml%' THEN 'document'
            WHEN mime_type LIKE 'application/vnd.openxmlformats-officedocument.spreadsheetml%' THEN 'spreadsheet'
            WHEN mime_type LIKE 'application/vnd.openxmlformats-officedocument.presentationml%' THEN 'presentation'
            WHEN mime_type LIKE 'application/vnd.google-apps.document%' THEN 'google_workspace'
            WHEN mime_type LIKE 'application/vnd.google-apps.spreadsheet%' THEN 'google_workspace'
            WHEN mime_type LIKE 'application/vnd.google-apps.presentation%' THEN 'google_workspace'
            WHEN mime_type LIKE 'image/%' THEN 'image'
            WHEN mime_type LIKE 'video/%' THEN 'video'
            WHEN mime_type LIKE 'audio/%' THEN 'audio'
            WHEN mime_type LIKE 'application/zip%' OR mime_type LIKE 'application/x-rar%' THEN 'archive'
            ELSE 'other'
        END as file_category,
        
        -- Document type classification based on filename patterns
        CASE 
            WHEN file_name ~* '(brief|creative|campaign|brand.*guide)' THEN 'creative_brief'
            WHEN file_name ~* '(budget|financial|expense|cost|invoice|payment)' THEN 'financial_report'
            WHEN file_name ~* '(research|analysis|survey|insights|market|competitive)' THEN 'market_research'
            WHEN file_name ~* '(strategy|strategic|plan|planning|roadmap)' THEN 'strategy_document'
            WHEN file_name ~* '(presentation|pitch|deck|slides)' THEN 'client_presentation'
            WHEN file_name ~* '(memo|internal|meeting|notes)' THEN 'internal_memo'
            WHEN file_name ~* '(legal|contract|agreement|compliance)' THEN 'legal_document'
            WHEN file_name ~* '(performance|dashboard|metrics|kpi|report)' THEN 'performance_dashboard'
            WHEN file_name ~* '(campaign.*analysis|effectiveness|impact)' THEN 'campaign_analysis'
            ELSE 'other_document'
        END as document_type,
        
        -- Business domain classification
        CASE 
            WHEN file_name ~* '(creative|brand|campaign|advertising|marketing)' THEN 'creative_intelligence'
            WHEN file_name ~* '(budget|financial|cost|expense|invoice|accounting)' THEN 'financial_management'
            WHEN file_name ~* '(research|market|consumer|insights|competitive|analysis)' THEN 'market_research'
            WHEN file_name ~* '(strategy|strategic|planning|roadmap|vision)' THEN 'strategic_planning'
            WHEN file_name ~* '(client|customer|account|proposal)' THEN 'client_assets'
            WHEN file_name ~* '(performance|metrics|kpi|dashboard|report)' THEN 'performance_reports'
            WHEN file_name ~* '(legal|compliance|contract|agreement)' THEN 'compliance_legal'
            ELSE 'internal_operations'
        END as business_domain,
        
        -- Enhanced PII detection with Philippine context
        CASE 
            WHEN file_name ~* '(confidential|private|personal|restricted)' THEN true
            WHEN extracted_text ~* '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b' THEN true -- Email
            WHEN extracted_text ~* '\b(09|639)\d{9}\b' THEN true -- Philippine mobile
            WHEN extracted_text ~* '\b\d{2}-\d{7}-\d{1}\b' THEN true -- SSS number
            WHEN extracted_text ~* '\b\d{3}-\d{3}-\d{3}-\d{3}\b' THEN true -- TIN number
            WHEN extracted_text ~* '\b\d{4}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4}\b' THEN true -- Credit card
            ELSE contains_pii
        END as enhanced_pii_detection,
        
        -- Content freshness analysis
        CASE 
            WHEN modified_time >= CURRENT_DATE - INTERVAL '7 days' THEN 'very_fresh'
            WHEN modified_time >= CURRENT_DATE - INTERVAL '30 days' THEN 'fresh'
            WHEN modified_time >= CURRENT_DATE - INTERVAL '90 days' THEN 'moderate'
            WHEN modified_time >= CURRENT_DATE - INTERVAL '365 days' THEN 'aging'
            ELSE 'stale'
        END as content_freshness,
        
        -- Business priority scoring
        CASE 
            WHEN file_name ~* '(urgent|critical|immediate|asap)' THEN 'critical'
            WHEN file_name ~* '(important|priority|high)' OR business_value = 'high' THEN 'high'
            WHEN file_name ~* '(medium|normal|standard)' OR business_value = 'medium' THEN 'medium'
            ELSE 'low'
        END as computed_business_priority,
        
        -- File size categorization for processing optimization
        CASE 
            WHEN file_size_bytes < 1024 * 1024 THEN 'small'        -- < 1MB
            WHEN file_size_bytes < 10 * 1024 * 1024 THEN 'medium'  -- < 10MB
            WHEN file_size_bytes < 100 * 1024 * 1024 THEN 'large'  -- < 100MB
            ELSE 'very_large'
        END as size_category,
        
        -- Processing complexity assessment
        CASE 
            WHEN mime_type LIKE 'text/%' OR mime_type LIKE 'application/pdf' THEN 'simple'
            WHEN mime_type LIKE 'application/vnd.openxml%' THEN 'moderate'
            WHEN mime_type LIKE 'application/vnd.google-apps%' THEN 'complex'
            WHEN mime_type LIKE 'image/%' OR mime_type LIKE 'video/%' THEN 'media_processing'
            ELSE 'unknown'
        END as processing_complexity
        
    FROM drive_source
),

-- Quality scoring and validation
quality_assessed AS (
    SELECT 
        *,
        
        -- Comprehensive quality score calculation
        CASE 
            WHEN file_content IS NOT NULL 
            AND file_size_bytes > 0 
            AND md5_checksum IS NOT NULL 
            AND NOT enhanced_pii_detection
            AND processing_status = 'completed'
            THEN LEAST(1.0, 
                0.3 + -- Base score
                (CASE WHEN extracted_text IS NOT NULL THEN 0.2 ELSE 0 END) + -- Content extraction
                (CASE WHEN key_entities IS NOT NULL AND key_entities != '[]'::jsonb THEN 0.2 ELSE 0 END) + -- Entity extraction
                (CASE WHEN content_freshness IN ('very_fresh', 'fresh') THEN 0.2 ELSE 0.1 END) + -- Freshness
                (CASE WHEN file_size_bytes BETWEEN 1024 AND 50*1024*1024 THEN 0.1 ELSE 0 END) -- Optimal size
            )
            ELSE COALESCE(quality_score, 0.3)
        END as computed_quality_score,
        
        -- Content completeness indicator
        CASE 
            WHEN extracted_text IS NOT NULL 
            AND LENGTH(extracted_text) > 100 
            AND key_entities IS NOT NULL 
            AND content_summary IS NOT NULL 
            THEN 'complete'
            WHEN extracted_text IS NOT NULL 
            AND LENGTH(extracted_text) > 50 
            THEN 'partial'
            ELSE 'minimal'
        END as content_completeness,
        
        -- Risk assessment
        CASE 
            WHEN enhanced_pii_detection AND confidentiality_level IN ('confidential', 'restricted') THEN 'high_risk'
            WHEN enhanced_pii_detection OR confidentiality_level = 'confidential' THEN 'medium_risk'
            WHEN file_size_bytes > 100 * 1024 * 1024 THEN 'large_file_risk'
            ELSE 'low_risk'
        END as risk_level
        
    FROM classified_files
),

-- Final standardization and business rules
standardized AS (
    SELECT 
        -- Core identifiers
        file_id,
        TRIM(LOWER(file_name)) as standardized_filename,
        file_name as original_filename,
        folder_id,
        folder_path,
        
        -- Enhanced categorization
        file_category,
        document_type,
        business_domain,
        
        -- File metadata
        mime_type,
        file_size_bytes,
        size_category,
        md5_checksum,
        
        -- Content and intelligence
        CASE 
            WHEN enhanced_pii_detection 
            THEN '[CONTENT MASKED FOR PRIVACY - PII DETECTED]'
            ELSE extracted_text
        END as safe_extracted_text,
        
        CASE 
            WHEN enhanced_pii_detection 
            THEN '[SUMMARY MASKED FOR PRIVACY]'
            ELSE content_summary
        END as safe_content_summary,
        
        CASE 
            WHEN enhanced_pii_detection 
            THEN '[]'::jsonb
            ELSE key_entities
        END as safe_key_entities,
        
        -- Quality and compliance
        computed_quality_score as quality_score,
        content_completeness,
        enhanced_pii_detection as contains_pii,
        pii_types,
        compliance_flags,
        risk_level,
        
        -- Business context
        computed_business_priority as business_priority,
        confidentiality_level,
        content_freshness,
        processing_complexity,
        
        -- Processing metadata
        processing_status,
        error_details,
        version_number,
        
        -- Temporal fields
        created_time::timestamptz as file_created_at,
        modified_time::timestamptz as file_modified_at,
        synced_at as last_synced,
        processed_at,
        
        -- Audit fields
        ingested_at as bronze_ingested_at,
        CURRENT_TIMESTAMP as bronze_processed_at,
        job_run_id,
        '{{ invocation_id }}' as dbt_run_id,
        
        -- Data lineage
        'drive_intelligence.bronze_files' as source_table,
        'bronze' as processing_layer
        
    FROM quality_assessed
    
    -- Quality filters
    WHERE file_id IS NOT NULL
    AND standardized_filename IS NOT NULL
    AND file_size_bytes >= 0
    AND computed_quality_score >= 0.2  -- Minimum quality threshold
)

SELECT * FROM standardized