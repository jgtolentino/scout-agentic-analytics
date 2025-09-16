{{ config(
    materialized='incremental',
    unique_key='file_id',
    on_schema_change='fail',
    pre_hook="CALL metadata.validate_silver_dependencies('silver_drive_intelligence')",
    post_hook=[
        "CALL metadata.record_lineage_event('{{ this }}', 'silver_drive_intelligence', 'COMPLETE')",
        "CALL metadata.update_medallion_health('silver', '{{ this }}', 'drive_intelligence')"
    ],
    tags=['silver', 'drive', 'intelligence', 'analytics']
) }}

/*
    Silver layer for comprehensive Google Drive intelligence
    Enriched document analytics for TBWA creative intelligence, financial analysis, research insights
    Supports: Content analysis, business entity extraction, sentiment analysis, relationship mapping
*/

WITH bronze_documents AS (
    SELECT 
        file_id,
        standardized_filename,
        original_filename,
        folder_id,
        folder_path,
        file_category,
        document_type,
        business_domain,
        mime_type,
        file_size_bytes,
        size_category,
        safe_extracted_text,
        safe_content_summary,
        safe_key_entities,
        quality_score,
        content_completeness,
        contains_pii,
        risk_level,
        business_priority,
        confidentiality_level,
        content_freshness,
        processing_complexity,
        file_created_at,
        file_modified_at,
        last_synced,
        processed_at,
        bronze_processed_at,
        job_run_id,
        dbt_run_id
    FROM {{ ref('bronze_drive_intelligence') }}
    
    {% if is_incremental() %}
        WHERE last_synced > (SELECT COALESCE(MAX(last_synced), '1900-01-01'::timestamp) FROM {{ this }})
    {% endif %}
),

-- Enhanced content analysis with business intelligence
content_intelligence AS (
    SELECT 
        *,
        
        -- Document metadata extraction
        SPLIT_PART(original_filename, '.', 1) as document_title,
        CASE 
            WHEN safe_extracted_text ~* '\b(author|created by|prepared by)\s*:?\s*([a-zA-Z\s]+)' THEN
                SUBSTRING(safe_extracted_text FROM '\b(?:author|created by|prepared by)\s*:?\s*([a-zA-Z\s]+)')
            WHEN safe_extracted_text ~* '\b([A-Z][a-z]+\s+[A-Z][a-z]+)\b.*(?:wrote|authored|prepared)' THEN
                SUBSTRING(safe_extracted_text FROM '\b([A-Z][a-z]+\s+[A-Z][a-z]+)\b.*(?:wrote|authored|prepared)')
            ELSE 'Unknown'
        END as extracted_author,
        
        -- Language detection (simplified)
        CASE 
            WHEN safe_extracted_text ~* '\b(ang|sa|ng|mga|para|hindi|ito|ako)\b' THEN 'fil'
            WHEN safe_extracted_text ~* '\b(the|and|or|but|with|from|this|that)\b' THEN 'en'
            WHEN safe_extracted_text ~* '\b(和|的|是|在|有|不|了|人)\b' THEN 'zh'
            ELSE 'en'
        END as detected_language,
        
        -- Word count estimation
        CASE 
            WHEN safe_extracted_text IS NOT NULL THEN
                ARRAY_LENGTH(STRING_TO_ARRAY(TRIM(safe_extracted_text), ' '), 1)
            ELSE 0
        END as estimated_word_count,
        
        -- Sentiment analysis (rule-based)
        CASE 
            WHEN safe_extracted_text ~* '\b(excellent|outstanding|exceptional|successful|profitable|growth|positive|increase|improve|win|achievement)\b' THEN 0.8
            WHEN safe_extracted_text ~* '\b(good|satisfactory|acceptable|stable|maintain|steady)\b' THEN 0.4
            WHEN safe_extracted_text ~* '\b(poor|decline|decrease|loss|negative|failed|challenge|issue|problem|risk)\b' THEN -0.6
            WHEN safe_extracted_text ~* '\b(crisis|disaster|terrible|awful|catastrophic|devastating)\b' THEN -0.9
            ELSE 0.0
        END as computed_sentiment_score,
        
        -- Urgency detection
        CASE 
            WHEN original_filename ~* '\b(urgent|asap|immediate|critical|emergency)\b' OR
                 safe_extracted_text ~* '\b(urgent|asap|immediate|critical|emergency|deadline|rush)\b' THEN 'critical'
            WHEN original_filename ~* '\b(priority|important|soon)\b' OR
                 safe_extracted_text ~* '\b(priority|important|soon|time.sensitive)\b' THEN 'high'
            WHEN safe_extracted_text ~* '\b(when convenient|no rush|flexible|optional)\b' THEN 'low'
            ELSE 'medium'
        END as urgency_level
        
    FROM bronze_documents
),

-- Business entity extraction and analysis
entity_analysis AS (
    SELECT 
        *,
        
        -- Brand mention extraction (Philippine and international brands)
        CASE 
            WHEN safe_extracted_text IS NOT NULL THEN
                ARRAY(
                    SELECT DISTINCT brand_name 
                    FROM (
                        SELECT unnest(regexp_split_to_array(
                            regexp_replace(safe_extracted_text, 
                                '\b(Coca.Cola|Pepsi|Nestle|Unilever|P&G|Jollibee|SM|Ayala|BDO|Globe|Smart|PLDT|ABS.CBN|GMA|San Miguel|Emperador|Del Monte|Century Tuna|Alaska|Magnolia|Selecta)\b', 
                                '\1', 'gi'
                            ), 
                            '\s+'
                        )) as brand_name
                    ) brands 
                    WHERE brand_name ~* '\b(Coca.Cola|Pepsi|Nestle|Unilever|P&G|Jollibee|SM|Ayala|BDO|Globe|Smart|PLDT|ABS.CBN|GMA|San Miguel|Emperador|Del Monte|Century Tuna|Alaska|Magnolia|Selecta)\b'
                    LIMIT 10
                )
            ELSE ARRAY[]::text[]
        END as mentioned_brands,
        
        -- Financial figure extraction
        CASE 
            WHEN safe_extracted_text IS NOT NULL THEN
                ARRAY(
                    SELECT DISTINCT amount 
                    FROM (
                        SELECT unnest(regexp_split_to_array(
                            safe_extracted_text, 
                            '\b(?:PHP|₱|USD|\$)\s*([0-9,]+(?:\.[0-9]{2})?)\b'
                        )) as amount
                    ) amounts 
                    WHERE amount ~ '^[0-9,]+(?:\.[0-9]{2})?$'
                    LIMIT 5
                )
            ELSE ARRAY[]::text[]
        END as financial_figures,
        
        -- Date extraction
        CASE 
            WHEN safe_extracted_text IS NOT NULL THEN
                ARRAY(
                    SELECT DISTINCT date_val 
                    FROM (
                        SELECT unnest(regexp_split_to_array(
                            safe_extracted_text, 
                            '\b(\d{1,2}[/-]\d{1,2}[/-]\d{4}|\d{4}[/-]\d{1,2}[/-]\d{1,2}|(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4})\b'
                        )) as date_val
                    ) dates 
                    WHERE date_val ~ '\d{1,2}[/-]\d{1,2}[/-]\d{4}|\d{4}[/-]\d{1,2}[/-]\d{1,2}|(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4}'
                    LIMIT 5
                )
            ELSE ARRAY[]::text[]
        END as mentioned_dates,
        
        -- Key topic extraction based on document type
        CASE 
            WHEN document_type = 'creative_brief' AND safe_extracted_text IS NOT NULL THEN
                ARRAY(
                    SELECT DISTINCT topic 
                    FROM (
                        SELECT unnest(ARRAY['brand positioning', 'target audience', 'key message', 'creative concept', 'campaign objective']) as topic
                    ) topics
                    WHERE safe_extracted_text ~* topic
                    LIMIT 5
                )
            WHEN document_type = 'financial_report' AND safe_extracted_text IS NOT NULL THEN
                ARRAY(
                    SELECT DISTINCT topic 
                    FROM (
                        SELECT unnest(ARRAY['revenue', 'profit', 'expenses', 'budget', 'cost analysis', 'roi', 'financial performance']) as topic
                    ) topics
                    WHERE safe_extracted_text ~* topic
                    LIMIT 5
                )
            WHEN document_type = 'market_research' AND safe_extracted_text IS NOT NULL THEN
                ARRAY(
                    SELECT DISTINCT topic 
                    FROM (
                        SELECT unnest(ARRAY['market trends', 'consumer behavior', 'competitive analysis', 'market share', 'demographics', 'insights']) as topic
                    ) topics
                    WHERE safe_extracted_text ~* topic
                    LIMIT 5
                )
            ELSE ARRAY[]::text[]
        END as key_topics,
        
        -- Competitor mention detection
        CASE 
            WHEN safe_extracted_text IS NOT NULL THEN
                ARRAY(
                    SELECT DISTINCT competitor 
                    FROM (
                        SELECT unnest(regexp_split_to_array(
                            safe_extracted_text, 
                            '\b(competitor|rival|competition|vs|versus|against)\s+([A-Z][a-zA-Z\s&]+)'
                        )) as competitor
                    ) competitors 
                    WHERE competitor ~ '^[A-Z][a-zA-Z\s&]+$'
                    AND LENGTH(competitor) BETWEEN 3 AND 50
                    LIMIT 5
                )
            ELSE ARRAY[]::text[]
        END as mentioned_competitors
        
    FROM content_intelligence
),

-- Document relationship and hierarchy analysis
relationship_analysis AS (
    SELECT 
        *,
        
        -- Document series detection (v1, v2, draft, final, etc.)
        CASE 
            WHEN original_filename ~* '\b(v|version)\s*[0-9]+\b' THEN
                REGEXP_REPLACE(original_filename, '\b(v|version)\s*[0-9]+\b.*$', '', 'i')
            WHEN original_filename ~* '\b(draft|final|revised|updated)\b' THEN
                REGEXP_REPLACE(original_filename, '\b(draft|final|revised|updated).*$', '', 'i')
            ELSE original_filename
        END as document_series_root,
        
        -- Version detection
        CASE 
            WHEN original_filename ~* '\bv\s*([0-9]+(?:\.[0-9]+)?)\b' THEN
                SUBSTRING(original_filename FROM '\bv\s*([0-9]+(?:\.[0-9]+)?)\b')
            WHEN original_filename ~* '\bversion\s*([0-9]+(?:\.[0-9]+)?)\b' THEN
                SUBSTRING(original_filename FROM '\bversion\s*([0-9]+(?:\.[0-9]+)?)\b')
            WHEN original_filename ~* '\b(draft)\b' THEN '0.1'
            WHEN original_filename ~* '\b(final)\b' THEN '1.0'
            ELSE '1.0'
        END as document_version,
        
        -- Document freshness calculation
        EXTRACT(DAYS FROM (CURRENT_DATE - file_modified_at::date)) as days_since_modified,
        
        -- Content density score (content richness)
        CASE 
            WHEN estimated_word_count > 0 AND file_size_bytes > 0 THEN
                LEAST(1.0, (estimated_word_count::numeric / (file_size_bytes::numeric / 1024)) * 10)
            ELSE 0.0
        END as content_density_score,
        
        -- Business relevance score
        CASE 
            WHEN business_priority = 'critical' THEN 1.0
            WHEN business_priority = 'high' THEN 0.8
            WHEN business_priority = 'medium' THEN 0.6
            WHEN business_priority = 'low' THEN 0.4
            ELSE 0.5
        END * 
        CASE 
            WHEN content_freshness = 'very_fresh' THEN 1.0
            WHEN content_freshness = 'fresh' THEN 0.8
            WHEN content_freshness = 'moderate' THEN 0.6
            WHEN content_freshness = 'aging' THEN 0.4
            ELSE 0.2
        END as business_relevance_score
        
    FROM entity_analysis
),

-- Final standardization and quality assessment
final_standardized AS (
    SELECT 
        -- Primary identifiers
        file_id,
        standardized_filename,
        original_filename,
        folder_id,
        folder_path,
        
        -- Enhanced document metadata
        document_title,
        extracted_author as author_name,
        file_created_at::date as creation_date,
        detected_language,
        estimated_word_count,
        
        -- Document classification
        file_category,
        document_type,
        business_domain,
        document_version,
        document_series_root,
        
        -- Semantic analysis
        key_topics,
        computed_sentiment_score as sentiment_score,
        urgency_level,
        
        -- Business entity extraction
        mentioned_brands,
        mentioned_competitors,
        financial_figures,
        mentioned_dates,
        
        -- Quality and content metrics
        quality_score,
        content_completeness,
        content_density_score,
        business_relevance_score,
        
        -- Document relationships and context
        days_since_modified as document_freshness_days,
        content_freshness,
        business_priority,
        
        -- Compliance and security
        contains_pii as has_pii_risk,
        risk_level,
        confidentiality_level,
        
        -- Processing metadata
        processing_complexity,
        mime_type,
        file_size_bytes,
        size_category,
        
        -- Temporal dimensions for analytics
        file_created_at as document_created_at,
        file_modified_at as last_modified,
        last_synced,
        DATE_TRUNC('month', file_created_at) as creation_month,
        DATE_TRUNC('week', file_modified_at) as modification_week,
        EXTRACT(YEAR FROM file_created_at) as creation_year,
        EXTRACT(DOW FROM file_created_at) as creation_day_of_week,
        
        -- Audit fields
        bronze_processed_at,
        CURRENT_TIMESTAMP as silver_processed_at,
        job_run_id,
        dbt_run_id,
        
        -- Data lineage
        'bronze_drive_intelligence' as source_table,
        'silver' as processing_layer
        
    FROM relationship_analysis
    
    -- Quality filters for Silver layer
    WHERE quality_score >= 0.4  -- Higher quality threshold for Silver
    AND estimated_word_count >= 10  -- Must have some meaningful content
    AND business_relevance_score >= 0.3  -- Must have business relevance
)

SELECT * FROM final_standardized