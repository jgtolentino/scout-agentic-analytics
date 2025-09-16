{{ config(
    materialized='incremental',
    unique_key='transaction_id',
    on_schema_change='fail',
    pre_hook="CALL metadata.validate_silver_dependencies('bronze_scout_edge_transactions')",
    post_hook=[
        "CALL metadata.record_lineage_event('{{ this }}', 'bronze_scout_edge_transactions', 'COMPLETE')",
        "CALL metadata.update_medallion_health('bronze', '{{ this }}', 'scout_edge')"
    ],
    tags=['bronze', 'scout', 'edge', 'transactions', 'retail'],
    cluster_by=['device_id', 'store_id', 'transaction_date']
) }}

/*
    Bronze layer for Scout Edge IoT transaction data
    Ingests real-time retail transactions from Scout Edge devices via bucket storage
    Supports: Brand detection, transaction analytics, store intelligence
    Source: Google Drive → Supabase bucket → Bronze processing
*/

WITH bucket_source AS (
    SELECT 
        -- File metadata from bucket storage
        bf.id as bucket_file_id,
        bf.file_path,
        bf.file_name,
        bf.source_id as drive_file_id,
        bf.device_id as detected_device_id,
        bf.store_id as detected_store_id,
        bf.scout_metadata,
        bf.validation_status,
        bf.quality_score as file_quality_score,
        bf.processed_at as file_processed_at,
        bf.created_at as file_ingested_at,
        
        -- Raw transaction data (assuming JSON parsing)
        (bf.scout_metadata->>'transaction_id')::text as raw_transaction_id,
        (bf.scout_metadata->>'store_id')::text as raw_store_id,
        (bf.scout_metadata->>'device_id')::text as raw_device_id,
        (bf.scout_metadata->'items')::jsonb as raw_items,
        (bf.scout_metadata->'totals')::jsonb as raw_totals,
        (bf.scout_metadata->'brandDetection')::jsonb as raw_brand_detection,
        (bf.scout_metadata->'transactionContext')::jsonb as raw_transaction_context,
        (bf.scout_metadata->>'transactionTimestamp')::text as raw_timestamp,
        (bf.scout_metadata->>'edgeVersion')::text as edge_version,
        (bf.scout_metadata->'privacy')::jsonb as privacy_settings
        
    FROM metadata.scout_bucket_files bf
    
    WHERE bf.processing_status = 'completed'
    AND bf.source_type = 'google_drive'
    AND bf.validation_status = 'valid'
    AND bf.scout_metadata IS NOT NULL
    
    {% if is_incremental() %}
        -- Incremental processing: only new processed files
        AND bf.processed_at > (SELECT COALESCE(MAX(file_processed_at), '1900-01-01'::timestamp) FROM {{ this }})
    {% endif %}
),

-- Parse and validate Scout Edge transaction structure
parsed_transactions AS (
    SELECT 
        *,
        
        -- Transaction identifiers
        COALESCE(raw_transaction_id, 'MISSING_TXN_' || bucket_file_id::text) as transaction_id,
        COALESCE(raw_device_id, detected_device_id, 'UNKNOWN_DEVICE') as device_id,
        COALESCE(raw_store_id, detected_store_id, 'UNKNOWN_STORE') as store_id,
        
        -- Parse transaction timestamp
        CASE 
            WHEN raw_timestamp IS NOT NULL 
            THEN COALESCE(
                TRY_CAST(raw_timestamp as timestamptz),
                TRY_CAST(raw_timestamp::bigint / 1000 as timestamp), -- Unix milliseconds
                TRY_CAST(raw_timestamp::bigint as timestamp), -- Unix seconds
                file_processed_at
            )
            ELSE file_processed_at
        END as transaction_timestamp,
        
        -- Extract item count and totals
        COALESCE(jsonb_array_length(raw_items), 0) as item_count,
        COALESCE((raw_totals->>'totalAmount')::decimal, 0) as total_amount,
        COALESCE((raw_totals->>'subtotal')::decimal, 0) as subtotal,
        COALESCE((raw_totals->>'tax')::decimal, 0) as tax_amount,
        COALESCE((raw_totals->>'discount')::decimal, 0) as discount_amount,
        (raw_totals->>'currency')::text as currency_code,
        
        -- Brand detection results
        CASE 
            WHEN raw_brand_detection IS NOT NULL 
            AND raw_brand_detection ? 'detectedBrands'
            THEN jsonb_object_keys_count(raw_brand_detection->'detectedBrands')
            ELSE 0
        END as detected_brands_count,
        
        CASE 
            WHEN raw_brand_detection IS NOT NULL 
            AND raw_brand_detection ? 'detectedBrands'
            THEN (raw_brand_detection->'detectedBrands')::jsonb
            ELSE '{}'::jsonb
        END as detected_brands,
        
        COALESCE((raw_brand_detection->>'confidence')::decimal, 0) as brand_detection_confidence,
        COALESCE((raw_brand_detection->>'processingTime')::integer, 0) as brand_processing_time_ms,
        
        -- Transaction context and metadata
        CASE 
            WHEN raw_transaction_context IS NOT NULL 
            AND raw_transaction_context ? 'audioTranscript'
            THEN LENGTH(raw_transaction_context->>'audioTranscript') > 10
            ELSE false
        END as has_audio_transcript,
        
        CASE 
            WHEN raw_transaction_context IS NOT NULL 
            AND raw_transaction_context ? 'processingMethods'
            THEN (raw_transaction_context->'processingMethods')::jsonb
            ELSE '[]'::jsonb
        END as processing_methods,
        
        -- Privacy compliance
        CASE 
            WHEN privacy_settings IS NOT NULL 
            AND privacy_settings ? 'audioStored'
            THEN COALESCE((privacy_settings->>'audioStored')::boolean, false)
            ELSE false
        END as audio_stored,
        
        CASE 
            WHEN privacy_settings IS NOT NULL 
            AND privacy_settings ? 'piiDetected'
            THEN COALESCE((privacy_settings->>'piiDetected')::boolean, false)
            ELSE false
        END as pii_detected,
        
        -- Device and version metadata
        COALESCE(edge_version, 'unknown') as scout_edge_version,
        
        -- Validate device ID format (SCOUTPI-XXXX)
        CASE 
            WHEN COALESCE(raw_device_id, detected_device_id) ~ '^SCOUTPI-\d+$' 
            THEN true
            ELSE false
        END as valid_device_format
        
    FROM bucket_source
),

-- Enhanced categorization and business intelligence
categorized_transactions AS (
    SELECT 
        *,
        
        -- Transaction categorization
        CASE 
            WHEN total_amount = 0 THEN 'zero_amount'
            WHEN total_amount < 0 THEN 'refund'
            WHEN total_amount BETWEEN 0.01 AND 50 THEN 'small_ticket'
            WHEN total_amount BETWEEN 50.01 AND 200 THEN 'medium_ticket'
            WHEN total_amount BETWEEN 200.01 AND 500 THEN 'large_ticket'
            WHEN total_amount > 500 THEN 'premium_ticket'
            ELSE 'unknown_amount'
        END as transaction_category,
        
        -- Time-based categorization
        EXTRACT(hour FROM transaction_timestamp) as transaction_hour,
        EXTRACT(dow FROM transaction_timestamp) as day_of_week, -- 0=Sunday
        DATE_TRUNC('day', transaction_timestamp) as transaction_date,
        DATE_TRUNC('week', transaction_timestamp) as transaction_week,
        DATE_TRUNC('month', transaction_timestamp) as transaction_month,
        
        -- Business hours classification (Philippines context)
        CASE 
            WHEN EXTRACT(hour FROM transaction_timestamp) BETWEEN 6 AND 11 THEN 'morning'
            WHEN EXTRACT(hour FROM transaction_timestamp) BETWEEN 12 AND 17 THEN 'afternoon'
            WHEN EXTRACT(hour FROM transaction_timestamp) BETWEEN 18 AND 22 THEN 'evening'
            ELSE 'late_night'
        END as time_period,
        
        CASE 
            WHEN EXTRACT(dow FROM transaction_timestamp) IN (0, 6) THEN 'weekend'
            ELSE 'weekday'
        END as day_type,
        
        -- Store performance indicators
        CASE 
            WHEN item_count = 0 THEN 'no_items'
            WHEN item_count = 1 THEN 'single_item'
            WHEN item_count BETWEEN 2 AND 5 THEN 'few_items'
            WHEN item_count BETWEEN 6 AND 15 THEN 'multiple_items'
            WHEN item_count > 15 THEN 'bulk_purchase'
            ELSE 'unknown_items'
        END as basket_size_category,
        
        -- Brand engagement analysis
        CASE 
            WHEN detected_brands_count = 0 THEN 'no_brands'
            WHEN detected_brands_count = 1 THEN 'single_brand'
            WHEN detected_brands_count BETWEEN 2 AND 5 THEN 'multi_brand'
            WHEN detected_brands_count > 5 THEN 'diverse_brands'
            ELSE 'unknown_brands'
        END as brand_diversity,
        
        CASE 
            WHEN brand_detection_confidence >= 0.9 THEN 'high_confidence'
            WHEN brand_detection_confidence >= 0.7 THEN 'medium_confidence'
            WHEN brand_detection_confidence >= 0.5 THEN 'low_confidence'
            ELSE 'very_low_confidence'
        END as brand_confidence_level,
        
        -- Data quality assessment
        CASE 
            WHEN NOT valid_device_format THEN 'invalid_device'
            WHEN total_amount < 0 AND transaction_category != 'refund' THEN 'negative_amount'
            WHEN item_count = 0 AND total_amount > 0 THEN 'missing_items'
            WHEN detected_brands_count > item_count AND item_count > 0 THEN 'brand_item_mismatch'
            ELSE 'valid'
        END as data_quality_flag,
        
        -- Privacy and compliance flags
        CASE 
            WHEN audio_stored AND pii_detected THEN 'high_privacy_risk'
            WHEN audio_stored OR pii_detected THEN 'medium_privacy_risk'
            ELSE 'low_privacy_risk'
        END as privacy_risk_level,
        
        -- Processing quality assessment
        CASE 
            WHEN file_quality_score >= 0.9 THEN 'excellent'
            WHEN file_quality_score >= 0.7 THEN 'good'
            WHEN file_quality_score >= 0.5 THEN 'fair'
            ELSE 'poor'
        END as processing_quality,
        
        -- Store operational insights
        CASE 
            WHEN transaction_timestamp::date = CURRENT_DATE THEN 'today'
            WHEN transaction_timestamp::date = CURRENT_DATE - INTERVAL '1 day' THEN 'yesterday'
            WHEN transaction_timestamp::date >= CURRENT_DATE - INTERVAL '7 days' THEN 'this_week'
            WHEN transaction_timestamp::date >= CURRENT_DATE - INTERVAL '30 days' THEN 'this_month'
            ELSE 'historical'
        END as recency_category
        
    FROM parsed_transactions
),

-- Quality validation and business rules
validated_transactions AS (
    SELECT 
        *,
        
        -- Comprehensive quality score calculation
        CASE 
            WHEN valid_device_format 
            AND data_quality_flag = 'valid'
            AND transaction_id IS NOT NULL
            AND total_amount >= 0
            AND file_quality_score >= 0.5
            THEN LEAST(1.0,
                0.2 + -- Base score
                (CASE WHEN item_count > 0 THEN 0.2 ELSE 0 END) + -- Has items
                (CASE WHEN detected_brands_count > 0 THEN 0.2 ELSE 0 END) + -- Brand detection
                (CASE WHEN brand_detection_confidence >= 0.7 THEN 0.2 ELSE 0.1 END) + -- Brand confidence
                (CASE WHEN has_audio_transcript THEN 0.1 ELSE 0 END) + -- Rich context
                (CASE WHEN privacy_risk_level = 'low_privacy_risk' THEN 0.1 ELSE 0 END) -- Privacy compliant
            )
            ELSE GREATEST(file_quality_score * 0.8, 0.1) -- Fallback to file quality
        END as computed_quality_score,
        
        -- Business value assessment
        CASE 
            WHEN detected_brands_count >= 3 
            AND brand_detection_confidence >= 0.8 
            AND total_amount >= 100 
            THEN 'high_value'
            WHEN detected_brands_count >= 1 
            AND brand_detection_confidence >= 0.6 
            AND total_amount >= 25
            THEN 'medium_value'
            WHEN total_amount > 0 
            AND item_count > 0
            THEN 'standard_value'
            ELSE 'low_value'
        END as business_value,
        
        -- Anomaly detection flags
        CASE 
            WHEN total_amount > 2000 THEN 'high_amount_anomaly'
            WHEN item_count > 50 THEN 'high_item_anomaly'
            WHEN detected_brands_count > 20 THEN 'high_brand_anomaly'
            WHEN total_amount > 0 AND item_count = 0 THEN 'missing_items_anomaly'
            WHEN total_amount = 0 AND item_count > 0 THEN 'zero_amount_anomaly'
            ELSE 'normal'
        END as anomaly_flag
        
    FROM categorized_transactions
),

-- Final standardization for Bronze layer
standardized_bronze AS (
    SELECT 
        -- Primary identifiers
        transaction_id,
        device_id,
        store_id,
        
        -- Transaction core data
        transaction_timestamp,
        transaction_date,
        transaction_hour,
        day_of_week,
        time_period,
        day_type,
        
        -- Financial metrics
        total_amount,
        subtotal,
        tax_amount,
        discount_amount,
        currency_code,
        transaction_category,
        
        -- Item and basket analytics
        item_count,
        basket_size_category,
        raw_items as items_detail,
        
        -- Brand intelligence
        detected_brands_count,
        detected_brands,
        brand_detection_confidence,
        brand_confidence_level,
        brand_diversity,
        brand_processing_time_ms,
        
        -- Transaction context
        has_audio_transcript,
        processing_methods,
        scout_edge_version,
        
        -- Privacy and compliance
        audio_stored,
        pii_detected,
        privacy_risk_level,
        
        -- Quality and validation
        computed_quality_score as quality_score,
        processing_quality,
        data_quality_flag,
        anomaly_flag,
        business_value,
        valid_device_format,
        
        -- Temporal categorization
        recency_category,
        transaction_week,
        transaction_month,
        
        -- File lineage and metadata
        bucket_file_id,
        file_path,
        file_name,
        drive_file_id,
        file_quality_score,
        validation_status as file_validation_status,
        
        -- Processing timestamps
        file_processed_at,
        file_ingested_at,
        CURRENT_TIMESTAMP as bronze_processed_at,
        '{{ invocation_id }}' as dbt_run_id,
        
        -- Data lineage
        'metadata.scout_bucket_files' as source_table,
        'bronze' as processing_layer,
        
        -- Raw data preservation (for debugging and reprocessing)
        scout_metadata as raw_scout_metadata,
        raw_transaction_context as raw_context,
        raw_totals,
        raw_brand_detection
        
    FROM validated_transactions
    
    -- Final quality filters
    WHERE transaction_id IS NOT NULL
    AND device_id IS NOT NULL
    AND computed_quality_score >= 0.1  -- Minimum quality threshold
    AND data_quality_flag IN ('valid', 'negative_amount') -- Allow refunds
)

SELECT * FROM standardized_bronze