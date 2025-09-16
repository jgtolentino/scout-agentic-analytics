{{ config(
    materialized='incremental',
    unique_key=['source_system', 'primary_id'],
    on_schema_change='fail',
    pre_hook="CALL metadata.validate_silver_dependencies('silver_unified_scout_analytics')",
    post_hook=[
        "CALL metadata.record_lineage_event('{{ this }}', 'silver_unified_scout_analytics', 'COMPLETE')",
        "CALL metadata.update_medallion_health('silver', '{{ this }}', 'unified_scout')"
    ],
    tags=['silver', 'unified', 'scout', 'analytics', 'retail', 'creative'],
    cluster_by=['source_system', 'business_domain', 'event_date']
) }}

/*
    Silver layer for unified Scout Analytics 
    Combines Scout Edge retail transactions with Drive Intelligence creative assets
    Enables comprehensive brand performance analysis across physical retail and creative campaigns
    Supports: Brand ROI analysis, campaign effectiveness, store performance, creative intelligence
*/

-- Scout Edge retail transaction data
WITH scout_edge_transactions AS (
    SELECT 
        -- Standardized identifiers for unified analytics
        'scout_edge' as source_system,
        transaction_id as primary_id,
        device_id as secondary_id,
        store_id as location_id,
        
        -- Core business dimensions
        'retail_transaction' as content_type,
        'point_of_sale' as business_domain,
        transaction_category as subcategory,
        
        -- Brand and product intelligence
        detected_brands_count as brand_engagement_count,
        detected_brands as brand_entities,
        brand_detection_confidence,
        brand_confidence_level as confidence_tier,
        brand_diversity as engagement_diversity,
        
        -- Financial metrics
        total_amount as revenue_amount,
        subtotal,
        tax_amount,
        discount_amount,
        currency_code,
        
        -- Transaction context
        item_count as content_volume,
        basket_size_category as volume_category,
        time_period as temporal_segment,
        day_type as temporal_category,
        
        -- Quality and business value
        quality_score,
        business_value,
        anomaly_flag as quality_flag,
        
        -- Geographic and operational context
        CASE 
            WHEN device_id = 'SCOUTPI-0002' THEN 'Store_Manila_North'
            WHEN device_id = 'SCOUTPI-0003' THEN 'Store_Manila_South' 
            WHEN device_id = 'SCOUTPI-0004' THEN 'Store_Cebu_Central'
            WHEN device_id = 'SCOUTPI-0005' THEN 'Store_Davao_East'
            WHEN device_id = 'SCOUTPI-0006' THEN 'Store_Quezon_City'
            WHEN device_id = 'SCOUTPI-0007' THEN 'Store_Makati_CBD'
            WHEN device_id = 'SCOUTPI-0012' THEN 'Store_BGC_Premium'
            ELSE 'Store_Unknown'
        END as geographic_segment,
        
        CASE 
            WHEN store_id ~* 'premium|luxury|high.end' THEN 'premium'
            WHEN store_id ~* 'supermarket|grocery|retail' THEN 'mass_market'
            WHEN store_id ~* 'convenience|mini|express' THEN 'convenience'
            ELSE 'general_retail'
        END as retail_format,
        
        -- Temporal dimensions
        transaction_timestamp::date as event_date,
        transaction_timestamp as event_timestamp,
        transaction_hour as event_hour,
        day_of_week as event_day_of_week,
        transaction_month as event_month,
        recency_category as temporal_freshness,
        
        -- Privacy and compliance
        privacy_risk_level as compliance_risk,
        pii_detected as has_sensitive_data,
        
        -- Processing metadata
        scout_edge_version as system_version,
        processing_quality,
        data_quality_flag,
        
        -- Lineage
        bronze_processed_at as source_processed_at,
        file_name as source_reference,
        bucket_file_id as source_file_id,
        
        -- Scout Edge specific metrics
        has_audio_transcript as has_rich_context,
        brand_processing_time_ms as processing_time_ms,
        valid_device_format as valid_source_format,
        items_detail as raw_content,
        
        -- Aggregation helpers
        1 as transaction_count,
        CASE WHEN total_amount > 0 THEN 1 ELSE 0 END as revenue_transaction_count,
        CASE WHEN detected_brands_count > 0 THEN 1 ELSE 0 END as brand_transaction_count
        
    FROM {{ ref('bronze_scout_edge_transactions') }}
    
    {% if is_incremental() %}
        WHERE bronze_processed_at > (
            SELECT COALESCE(MAX(source_processed_at), '1900-01-01'::timestamp) 
            FROM {{ this }} 
            WHERE source_system = 'scout_edge'
        )
    {% endif %}
),

-- Drive Intelligence creative and campaign data  
drive_intelligence_content AS (
    SELECT 
        -- Standardized identifiers for unified analytics
        'drive_intelligence' as source_system,
        file_id as primary_id,
        folder_id as secondary_id,
        folder_path as location_id,
        
        -- Core business dimensions
        CASE 
            WHEN file_category IN ('document', 'pdf', 'google_workspace') THEN 'creative_document'
            WHEN file_category IN ('presentation') THEN 'campaign_presentation'
            WHEN file_category IN ('spreadsheet') THEN 'analytics_report'
            WHEN file_category IN ('image', 'video') THEN 'creative_asset'
            ELSE 'business_content'
        END as content_type,
        
        business_domain,
        document_type as subcategory,
        
        -- Brand and content intelligence
        ARRAY_LENGTH(mentioned_brands, 1) as brand_engagement_count,
        mentioned_brands as brand_entities,
        business_relevance_score as brand_detection_confidence,
        CASE 
            WHEN business_relevance_score >= 0.8 THEN 'high_confidence'
            WHEN business_relevance_score >= 0.6 THEN 'medium_confidence'
            WHEN business_relevance_score >= 0.4 THEN 'low_confidence'
            ELSE 'very_low_confidence'
        END as confidence_tier,
        
        CASE 
            WHEN ARRAY_LENGTH(mentioned_brands, 1) = 0 THEN 'no_brands'
            WHEN ARRAY_LENGTH(mentioned_brands, 1) = 1 THEN 'single_brand'
            WHEN ARRAY_LENGTH(mentioned_brands, 1) BETWEEN 2 AND 5 THEN 'multi_brand'
            WHEN ARRAY_LENGTH(mentioned_brands, 1) > 5 THEN 'diverse_brands'
            ELSE 'unknown_brands'
        END as engagement_diversity,
        
        -- Financial metrics (extracted from content)
        CASE 
            WHEN ARRAY_LENGTH(financial_figures, 1) > 0 THEN
                COALESCE(
                    REPLACE(REPLACE(financial_figures[1], ',', ''), '₱', '')::numeric, 
                    0
                )
            ELSE 0
        END as revenue_amount,
        
        NULL::numeric as subtotal,
        NULL::numeric as tax_amount, 
        NULL::numeric as discount_amount,
        CASE 
            WHEN financial_figures[1] ~ '₱|PHP' THEN 'PHP'
            WHEN financial_figures[1] ~ '\$|USD' THEN 'USD'
            ELSE 'PHP'
        END as currency_code,
        
        -- Content context
        estimated_word_count as content_volume,
        CASE 
            WHEN estimated_word_count = 0 THEN 'no_content'
            WHEN estimated_word_count BETWEEN 1 AND 100 THEN 'brief_content'
            WHEN estimated_word_count BETWEEN 101 AND 500 THEN 'moderate_content'
            WHEN estimated_word_count BETWEEN 501 AND 2000 THEN 'detailed_content'
            WHEN estimated_word_count > 2000 THEN 'comprehensive_content'
            ELSE 'unknown_content'
        END as volume_category,
        
        CASE 
            WHEN urgency_level = 'critical' THEN 'urgent'
            WHEN urgency_level = 'high' THEN 'priority'
            WHEN urgency_level = 'medium' THEN 'standard'
            ELSE 'routine'
        END as temporal_segment,
        
        CASE 
            WHEN content_freshness IN ('very_fresh', 'fresh') THEN 'current'
            WHEN content_freshness = 'moderate' THEN 'recent'
            ELSE 'historical'
        END as temporal_category,
        
        -- Quality and business value
        quality_score,
        business_priority as business_value,
        CASE 
            WHEN has_pii_risk THEN 'privacy_risk'
            WHEN risk_level = 'high_risk' THEN 'high_risk'
            ELSE 'normal'
        END as quality_flag,
        
        -- Geographic and operational context
        CASE 
            WHEN folder_path ~* 'global|international|worldwide' THEN 'Global_Campaign'
            WHEN folder_path ~* 'philippines|ph|manila|cebu|davao' THEN 'Philippines_Campaign'
            WHEN folder_path ~* 'regional|asia|southeast' THEN 'Regional_Campaign'
            ELSE 'Local_Campaign'
        END as geographic_segment,
        
        CASE 
            WHEN business_domain = 'creative_intelligence' THEN 'creative_campaign'
            WHEN business_domain = 'financial_management' THEN 'business_operations'
            WHEN business_domain = 'market_research' THEN 'market_intelligence'
            WHEN business_domain = 'strategic_planning' THEN 'strategic_planning'
            ELSE 'general_business'
        END as retail_format,
        
        -- Temporal dimensions
        last_modified::date as event_date,
        last_modified as event_timestamp,
        EXTRACT(hour FROM last_modified) as event_hour,
        EXTRACT(dow FROM last_modified) as event_day_of_week,
        DATE_TRUNC('month', last_modified) as event_month,
        content_freshness as temporal_freshness,
        
        -- Privacy and compliance
        CASE 
            WHEN has_pii_risk THEN 'high_privacy_risk'
            WHEN confidentiality_level = 'confidential' THEN 'medium_privacy_risk'
            ELSE 'low_privacy_risk'
        END as compliance_risk,
        
        has_pii_risk as has_sensitive_data,
        
        -- Processing metadata
        detected_language as system_version,
        content_completeness as processing_quality,
        CASE 
            WHEN content_completeness = 'complete' THEN 'valid'
            WHEN content_completeness = 'partial' THEN 'partial_data'
            ELSE 'incomplete_data'
        END as data_quality_flag,
        
        -- Lineage
        silver_processed_at as source_processed_at,
        original_filename as source_reference,
        file_id as source_file_id,
        
        -- Drive Intelligence specific metrics
        content_density_score > 0.5 as has_rich_context,
        NULL::integer as processing_time_ms,
        quality_score >= 0.4 as valid_source_format,
        key_topics as raw_content,
        
        -- Aggregation helpers
        1 as transaction_count,
        CASE WHEN ARRAY_LENGTH(financial_figures, 1) > 0 THEN 1 ELSE 0 END as revenue_transaction_count,
        CASE WHEN ARRAY_LENGTH(mentioned_brands, 1) > 0 THEN 1 ELSE 0 END as brand_transaction_count
        
    FROM {{ ref('silver_drive_intelligence') }}
    
    {% if is_incremental() %}
        WHERE silver_processed_at > (
            SELECT COALESCE(MAX(source_processed_at), '1900-01-01'::timestamp) 
            FROM {{ this }} 
            WHERE source_system = 'drive_intelligence'
        )
    {% endif %}
),

-- Unified data with enhanced business intelligence
unified_scout_data AS (
    SELECT * FROM scout_edge_transactions
    UNION ALL
    SELECT * FROM drive_intelligence_content
),

-- Brand intelligence analysis across systems
brand_intelligence AS (
    SELECT 
        *,
        
        -- Cross-system brand analysis
        CASE 
            WHEN source_system = 'scout_edge' THEN 'retail_touchpoint'
            WHEN source_system = 'drive_intelligence' AND content_type LIKE '%creative%' THEN 'creative_touchpoint'
            WHEN source_system = 'drive_intelligence' AND content_type LIKE '%analytics%' THEN 'analytics_touchpoint'
            ELSE 'business_touchpoint'
        END as brand_touchpoint_type,
        
        -- Unified brand scoring
        CASE 
            WHEN source_system = 'scout_edge' THEN 
                CASE 
                    WHEN brand_engagement_count >= 5 AND confidence_tier = 'high_confidence' THEN 'high_impact'
                    WHEN brand_engagement_count >= 2 AND confidence_tier IN ('high_confidence', 'medium_confidence') THEN 'medium_impact'
                    WHEN brand_engagement_count >= 1 THEN 'low_impact'
                    ELSE 'no_impact'
                END
            WHEN source_system = 'drive_intelligence' THEN
                CASE 
                    WHEN brand_engagement_count >= 3 AND business_value IN ('critical', 'high_value') THEN 'high_impact'
                    WHEN brand_engagement_count >= 1 AND business_value IN ('critical', 'high_value', 'medium_value') THEN 'medium_impact'
                    WHEN brand_engagement_count >= 1 THEN 'low_impact'
                    ELSE 'no_impact'
                END
            ELSE 'no_impact'
        END as unified_brand_impact,
        
        -- Revenue attribution (actual for Scout Edge, estimated for Drive Intelligence)
        CASE 
            WHEN source_system = 'scout_edge' THEN 'actual_revenue'
            WHEN source_system = 'drive_intelligence' AND revenue_amount > 0 THEN 'estimated_revenue'
            ELSE 'no_revenue_data'
        END as revenue_attribution_type,
        
        -- Cross-system quality scoring
        CASE 
            WHEN source_system = 'scout_edge' THEN
                LEAST(1.0,
                    (quality_score * 0.4) +
                    (CASE WHEN brand_engagement_count > 0 THEN 0.3 ELSE 0 END) +
                    (CASE WHEN revenue_amount > 0 THEN 0.2 ELSE 0 END) +
                    (CASE WHEN has_rich_context THEN 0.1 ELSE 0 END)
                )
            WHEN source_system = 'drive_intelligence' THEN
                LEAST(1.0,
                    (quality_score * 0.5) +
                    (CASE WHEN brand_engagement_count > 0 THEN 0.2 ELSE 0 END) +
                    (CASE WHEN content_volume > 100 THEN 0.2 ELSE 0 END) +
                    (CASE WHEN has_rich_context THEN 0.1 ELSE 0 END)
                )
            ELSE quality_score
        END as unified_quality_score,
        
        -- Business alignment scoring
        CASE 
            WHEN source_system = 'scout_edge' AND business_value IN ('high_value', 'medium_value') THEN 0.8
            WHEN source_system = 'scout_edge' AND business_value = 'standard_value' THEN 0.6
            WHEN source_system = 'drive_intelligence' AND business_domain = 'creative_intelligence' THEN 0.9
            WHEN source_system = 'drive_intelligence' AND business_domain = 'market_research' THEN 0.8
            WHEN source_system = 'drive_intelligence' AND business_domain = 'strategic_planning' THEN 0.7
            ELSE 0.5
        END as business_alignment_score
        
    FROM unified_scout_data
),

-- Final standardization with comprehensive analytics dimensions
final_unified_analytics AS (
    SELECT 
        -- Primary identifiers
        source_system,
        primary_id,
        secondary_id,
        location_id,
        
        -- Business dimensions
        content_type,
        business_domain,
        subcategory,
        brand_touchpoint_type,
        
        -- Brand intelligence
        brand_engagement_count,
        brand_entities,
        confidence_tier,
        engagement_diversity,
        unified_brand_impact,
        
        -- Financial metrics
        revenue_amount,
        subtotal,
        tax_amount,
        discount_amount,
        currency_code,
        revenue_attribution_type,
        
        -- Content and volume metrics
        content_volume,
        volume_category,
        temporal_segment,
        temporal_category,
        
        -- Quality and compliance
        unified_quality_score as quality_score,
        business_value,
        quality_flag,
        compliance_risk,
        has_sensitive_data,
        business_alignment_score,
        
        -- Geographic and operational
        geographic_segment,
        retail_format,
        
        -- Temporal dimensions
        event_date,
        event_timestamp,
        event_hour,
        event_day_of_week,
        event_month,
        temporal_freshness,
        
        -- Aggregation metrics
        transaction_count,
        revenue_transaction_count,
        brand_transaction_count,
        
        -- System metadata
        system_version,
        processing_quality,
        data_quality_flag,
        has_rich_context,
        processing_time_ms,
        valid_source_format,
        
        -- Lineage and audit
        source_processed_at,
        source_reference,
        source_file_id,
        CURRENT_TIMESTAMP as silver_processed_at,
        '{{ invocation_id }}' as dbt_run_id,
        
        -- Data lineage
        CASE 
            WHEN source_system = 'scout_edge' THEN 'bronze_scout_edge_transactions'
            WHEN source_system = 'drive_intelligence' THEN 'silver_drive_intelligence'
            ELSE 'unknown_source'
        END as source_table,
        
        'silver_unified' as processing_layer,
        
        -- Raw content for detailed analysis
        raw_content
        
    FROM brand_intelligence
    
    -- Quality filters for unified analytics
    WHERE unified_quality_score >= 0.3  -- Minimum quality for unified analytics
    AND source_system IS NOT NULL
    AND primary_id IS NOT NULL
    AND event_date >= CURRENT_DATE - INTERVAL '2 years'  -- Focus on recent data
),

-- Add row-level clustering hints for performance
clustered_final AS (
    SELECT 
        *,
        -- Create composite clustering key for better query performance
        source_system || '|' || business_domain || '|' || event_date::text as cluster_key
        
    FROM final_unified_analytics
)

SELECT * FROM clustered_final