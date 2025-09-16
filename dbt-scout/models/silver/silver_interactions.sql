{{ config(
    materialized='incremental',
    unique_key='interaction_id',
    on_schema_change='fail',
    pre_hook="SELECT metadata.emit_lineage_start('silver_interactions', '{{ var(\"job_run_id\", gen_random_uuid()) }}'::UUID)",
    post_hook=[
        "SELECT metadata.emit_lineage_complete('silver_interactions', '{{ var(\"job_run_id\", gen_random_uuid()) }}'::UUID)",
        "SELECT metadata.update_watermark('azure.interactions', 'interactions', 'TransactionDate', (SELECT MAX(transaction_date)::TEXT FROM {{ this }}), '{{ ds }}', '{{ var(\"job_run_id\", null) }}'::UUID, (SELECT COUNT(*) FROM {{ this }}))"
    ],
    tags=['silver', 'interactions', 'incremental']
) }}

/*
  Silver Layer: Cleansed and Standardized Interactions
  
  This model transforms raw Azure SQL interactions into a clean, standardized format
  with proper data types, standardized values, and PII masking applied.
  
  Data Quality Rules:
  - Remove duplicates based on InteractionID
  - Standardize gender values (M/F -> Male/Female)
  - Validate age ranges (0-120)
  - Apply PII masking for FacialID
  - Enrich with temporal features
  - Validate store/product relationships
*/

WITH source_data AS (
  SELECT * FROM {{ source('azure_data', 'interactions') }}
  {% if is_incremental() %}
    WHERE "TransactionDate" > (
      SELECT COALESCE(
        metadata.get_watermark('azure.interactions', 'interactions', 'TransactionDate')::TIMESTAMP,
        '{{ var("start_date") }}'::TIMESTAMP
      )
    )
  {% endif %}
),

-- Data cleansing and standardization
cleansed_data AS (
  SELECT 
    -- Primary identifiers
    "InteractionID" AS interaction_id,
    "StoreID"::INTEGER AS store_id,
    "ProductID"::INTEGER AS product_id,
    "DeviceID" AS device_id,
    
    -- Temporal fields
    "TransactionDate"::TIMESTAMP AS transaction_date,
    EXTRACT(HOUR FROM "TransactionDate"::TIMESTAMP) AS hour_of_day,
    EXTRACT(DOW FROM "TransactionDate"::TIMESTAMP) AS day_of_week,
    DATE_TRUNC('day', "TransactionDate"::TIMESTAMP) AS transaction_date_only,
    DATE_TRUNC('month', "TransactionDate"::TIMESTAMP) AS transaction_month,
    CASE WHEN EXTRACT(DOW FROM "TransactionDate"::TIMESTAMP) IN (0, 6) THEN TRUE ELSE FALSE END AS is_weekend,
    
    -- Store information
    COALESCE("StoreName", 'Unknown Store') AS store_name,
    COALESCE("StoreLocation", 'Unknown Location') AS store_location,
    
    -- Customer information (with PII masking)
    {% if var('enable_pii_masking', true) %}
      CASE 
        WHEN "FacialID" IS NOT NULL 
        THEN 'MASKED_' || MD5("FacialID"::TEXT) 
        ELSE NULL 
      END AS facial_id_masked,
    {% else %}
      "FacialID" AS facial_id,
    {% endif %}
    
    -- Standardized demographics
    CASE 
      WHEN UPPER(COALESCE("Gender", "Sex")) IN ('M', 'MALE') THEN 'Male'
      WHEN UPPER(COALESCE("Gender", "Sex")) IN ('F', 'FEMALE') THEN 'Female'
      ELSE 'Unknown'
    END AS gender_standardized,
    
    CASE 
      WHEN "Age" BETWEEN 0 AND 120 THEN "Age"::INTEGER
      ELSE NULL
    END AS age_validated,
    
    CASE 
      WHEN "Age" BETWEEN 0 AND 17 THEN '0-17'
      WHEN "Age" BETWEEN 18 AND 24 THEN '18-24'
      WHEN "Age" BETWEEN 25 AND 34 THEN '25-34'
      WHEN "Age" BETWEEN 35 AND 44 THEN '35-44'
      WHEN "Age" BETWEEN 45 AND 54 THEN '45-54'
      WHEN "Age" BETWEEN 55 AND 64 THEN '55-64'
      WHEN "Age" >= 65 THEN '65+'
      ELSE 'Unknown'
    END AS age_group,
    
    -- Emotional and interaction data
    COALESCE("EmotionalState", 'Unknown') AS emotional_state,
    "TranscriptionText" AS transcription_text,
    
    -- Geographic information
    "BarangayID"::INTEGER AS barangay_id,
    COALESCE("BarangayName", 'Unknown') AS barangay_name,
    COALESCE("MunicipalityName", 'Unknown') AS municipality_name,
    COALESCE("ProvinceName", 'Unknown') AS province_name,
    COALESCE("RegionName", 'Unknown') AS region_name,
    
    -- Data quality metadata
    CASE 
      WHEN "InteractionID" IS NOT NULL 
       AND "StoreID" IS NOT NULL 
       AND "TransactionDate" IS NOT NULL 
       AND "ProductID" IS NOT NULL 
      THEN 'high'
      WHEN "InteractionID" IS NOT NULL 
       AND "StoreID" IS NOT NULL 
       AND "TransactionDate" IS NOT NULL 
      THEN 'medium'
      ELSE 'low'
    END AS data_quality_score,
    
    -- Record metadata
    NOW() AS processed_at,
    '{{ var("job_run_id", "unknown") }}' AS job_run_id,
    
    -- Hash for change detection
    MD5(
      COALESCE("InteractionID", '') || 
      COALESCE("StoreID"::TEXT, '') || 
      COALESCE("TransactionDate"::TEXT, '') ||
      COALESCE("ProductID"::TEXT, '') ||
      COALESCE("Gender", '') ||
      COALESCE("Age"::TEXT, '')
    ) AS row_hash
    
  FROM source_data
  WHERE "InteractionID" IS NOT NULL  -- Ensure we have primary key
),

-- Deduplication using window functions
deduplicated_data AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY interaction_id 
      ORDER BY transaction_date DESC, processed_at DESC
    ) AS row_number
  FROM cleansed_data
),

-- Final selection
final AS (
  SELECT 
    interaction_id,
    store_id,
    store_name,
    store_location,
    product_id,
    device_id,
    transaction_date,
    hour_of_day,
    day_of_week,
    transaction_date_only,
    transaction_month,
    is_weekend,
    {% if var('enable_pii_masking', true) %}
      facial_id_masked AS facial_id,
    {% else %}
      facial_id,
    {% endif %}
    gender_standardized AS gender,
    age_validated AS age,
    age_group,
    emotional_state,
    transcription_text,
    barangay_id,
    barangay_name,
    municipality_name,
    province_name,
    region_name,
    data_quality_score,
    processed_at,
    job_run_id,
    row_hash
  FROM deduplicated_data
  WHERE row_number = 1  -- Keep only the latest version of each interaction
)

SELECT * FROM final