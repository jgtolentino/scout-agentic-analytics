-- Silver Unified Transactions Model
-- Combines Scout Edge IoT data with existing Azure transaction data
-- Maps fields between different data sources for unified analytics

{{ config(
    materialized='table',
    indexes=[
        {'columns': ['transaction_source', 'transaction_date'], 'type': 'btree'},
        {'columns': ['store_id'], 'type': 'btree'},
        {'columns': ['brand_name'], 'type': 'btree'},
        {'columns': ['device_id'], 'type': 'btree'}
    ]
) }}

WITH scout_edge_mapped AS (
    SELECT 
        -- Core Transaction Identity
        transaction_id as unified_transaction_id,
        'scout_edge' as transaction_source,
        store_id,
        device_id,
        
        -- Temporal Information
        COALESCE(
            CAST(timestamp AS timestamp), 
            created_at
        ) as transaction_timestamp,
        transaction_date,
        time_of_day,
        day_type as is_weekend_derived,
        
        -- Product & Brand Information
        brand_name,
        product_name,
        sku,
        category as product_category,
        
        -- Financial Metrics
        unit_price as peso_value_per_unit,
        total_price as peso_value,
        quantity as units_per_transaction,
        
        -- Basket Analytics
        total_items as basket_size,
        unique_brands_count,
        branded_count,
        unbranded_count,
        
        -- Customer Behavior
        payment_method,
        duration_seconds,
        customer_request_type as request_type,
        detection_method,
        confidence_score,
        
        -- Data Quality
        quality_score as data_quality_score,
        processing_time,
        edge_version,
        
        -- Scout Edge Specific Fields
        audio_transcript,
        brand_confidence,
        detection_type,
        is_unbranded,
        is_bulk,
        
        -- Placeholder mappings for Azure fields
        NULL::text as gender,
        NULL::text as age_bracket,
        NULL::boolean as campaign_influenced,
        NULL::numeric as handshake_score,
        NULL::boolean as is_tbwa_client,
        NULL::text as customer_type,
        NULL::text as store_type,
        NULL::text as economic_class,
        NULL::jsonb as location,
        NULL::jsonb as substitution_event,
        NULL::text[] as combo_basket,
        NULL::boolean as suggestion_accepted
        
    FROM {{ ref('bronze_scout_edge_transactions') }}
    WHERE processing_status = 'completed'
      AND quality_score >= 0.8
),

azure_mapped AS (
    SELECT 
        -- Core Transaction Identity  
        id as unified_transaction_id,
        'azure_legacy' as transaction_source,
        store_id,
        NULL::text as device_id, -- Azure doesn't have device_id
        
        -- Temporal Information
        timestamp as transaction_timestamp,
        transaction_date,
        time_of_day,
        is_weekend as is_weekend_derived,
        
        -- Product & Brand Information
        brand_name,
        NULL::text as product_name, -- Not in Azure schema
        sku,
        COALESCE(product_category, category) as product_category,
        
        -- Financial Metrics
        peso_value / NULLIF(units_per_transaction, 0) as peso_value_per_unit,
        peso_value,
        units_per_transaction,
        
        -- Basket Analytics
        basket_size,
        NULL::integer as unique_brands_count, -- Calculate from combo_basket
        NULL::integer as branded_count,
        NULL::integer as unbranded_count,
        
        -- Customer Behavior
        payment_method,
        duration_seconds,
        request_type,
        NULL::text as detection_method,
        handshake_score as confidence_score,
        
        -- Data Quality
        data_quality_score,
        NULL::numeric as processing_time,
        NULL::text as edge_version,
        
        -- Scout Edge Specific Fields (NULL for Azure)
        NULL::text as audio_transcript,
        NULL::numeric as brand_confidence,
        NULL::text as detection_type,
        NULL::boolean as is_unbranded,
        NULL::boolean as is_bulk,
        
        -- Azure Specific Fields
        gender,
        age_bracket,
        campaign_influenced,
        handshake_score,
        is_tbwa_client,
        customer_type,
        store_type,
        economic_class,
        location,
        substitution_event,
        combo_basket,
        suggestion_accepted
        
    FROM {{ source('silver', 'transactions_cleaned') }}
    WHERE data_quality_score >= 0.8
)

-- Union both data sources
SELECT 
    unified_transaction_id,
    transaction_source,
    store_id,
    device_id,
    transaction_timestamp,
    transaction_date,
    time_of_day,
    is_weekend_derived,
    brand_name,
    product_name,
    sku,
    product_category,
    peso_value_per_unit,
    peso_value,
    units_per_transaction,
    basket_size,
    unique_brands_count,
    branded_count,
    unbranded_count,
    payment_method,
    duration_seconds,
    request_type,
    detection_method,
    confidence_score,
    data_quality_score,
    processing_time,
    edge_version,
    
    -- Scout Edge Analytics Fields
    audio_transcript,
    brand_confidence,
    detection_type,
    is_unbranded,
    is_bulk,
    
    -- Azure Demographics & Context
    gender,
    age_bracket,
    campaign_influenced,
    handshake_score,
    is_tbwa_client,
    customer_type,
    store_type,
    economic_class,
    location,
    substitution_event,
    combo_basket,
    suggestion_accepted,
    
    -- Computed Analytics
    CASE 
        WHEN transaction_source = 'scout_edge' THEN 'IoT Real-time'
        WHEN transaction_source = 'azure_legacy' THEN 'Historical Survey'
        ELSE 'Unknown'
    END as data_collection_method,
    
    EXTRACT(hour FROM transaction_timestamp) as hour_of_day,
    EXTRACT(dow FROM transaction_timestamp) as day_of_week,
    
    -- Data Completeness Score
    (
        CASE WHEN brand_name IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN peso_value > 0 THEN 1 ELSE 0 END +
        CASE WHEN units_per_transaction > 0 THEN 1 ELSE 0 END +
        CASE WHEN duration_seconds > 0 THEN 1 ELSE 0 END +
        CASE WHEN data_quality_score >= 0.8 THEN 1 ELSE 0 END
    ) / 5.0 as completeness_score,
    
    current_timestamp as unified_at
    
FROM (
    SELECT * FROM scout_edge_mapped
    UNION ALL
    SELECT * FROM azure_mapped
) combined

-- Quality filters
WHERE peso_value > 0
  AND units_per_transaction > 0
  AND data_quality_score >= 0.8
  AND transaction_timestamp >= '2024-01-01'
  
ORDER BY transaction_timestamp DESC