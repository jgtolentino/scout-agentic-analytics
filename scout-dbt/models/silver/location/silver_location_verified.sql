{{ config(
    materialized='incremental',
    unique_key='transaction_id',
    on_schema_change='fail'
) }}

WITH source_data AS (
    SELECT
        canonical_id as transaction_id,
        store_id,
        transaction_date,
        municipality,
        barangay,
        CAST(latitude AS DECIMAL(10,7)) as geo_latitude,
        CAST(longitude AS DECIMAL(10,7)) as geo_longitude,
        {{ validate_coordinates('latitude', 'longitude') }} as coordinates_valid,
        data_source,
        loaded_at
    FROM {{ ref('bronze_transactions') }}

    {% if is_incremental() %}
    WHERE loaded_at > (SELECT MAX(loaded_at) FROM {{ this }})
    {% endif %}
),

verified AS (
    SELECT
        s.*,
        d.store_name,
        d.region,
        d.province,
        d.psgc_region,
        d.psgc_citymun,
        d.psgc_barangay,
        CASE
            WHEN d.store_id IS NOT NULL THEN
                {% if target.type == 'sqlserver' %}1{% else %}TRUE{% endif %}
            ELSE
                {% if target.type == 'sqlserver' %}0{% else %}FALSE{% endif %}
        END as location_verified
    FROM source_data s
    LEFT JOIN {{ ref('dim_stores_ncr') }} d
        ON s.store_id = d.store_id
)

SELECT
    transaction_id,
    store_id,
    store_name,
    transaction_date,
    municipality,
    barangay,
    geo_latitude,
    geo_longitude,
    coordinates_valid,
    location_verified,
    region,
    province,
    psgc_region,
    psgc_citymun,
    psgc_barangay,
    data_source,
    {{ current_timestamp_tz() }} as processed_at
FROM verified
