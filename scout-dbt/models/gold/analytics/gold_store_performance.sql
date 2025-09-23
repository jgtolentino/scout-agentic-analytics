{{ config(
    materialized='table',
    indexes=[
        {'columns': ['store_id'], 'unique': false},
        {'columns': ['performance_month'], 'unique': false}
    ]
) }}

WITH monthly_metrics AS (
    SELECT
        store_id,
        store_name,
        municipality,
        {{ date_trunc_day('transaction_date') }} as performance_date,
        {{ date_trunc_month('transaction_date') }} as performance_month,
        COUNT(DISTINCT transaction_id) as transaction_count,
        COUNT(DISTINCT {{ date_trunc_day('transaction_date') }}) as active_days,
        AVG(CASE WHEN location_verified =
            {% if target.type == 'sqlserver' %}1{% else %}TRUE{% endif %}
            THEN 1 ELSE 0 END) * 100 as verification_rate,
        COUNT(DISTINCT data_source) as source_diversity
    FROM {{ ref('silver_location_verified') }}
    GROUP BY store_id, store_name, municipality, {{ date_trunc_day('transaction_date') }}, {{ date_trunc_month('transaction_date') }}
),

categorized AS (
    SELECT
        *,
        CASE
            WHEN transaction_count >= 1000 THEN 'HIGH'
            WHEN transaction_count >= 500 THEN 'MEDIUM'
            WHEN transaction_count >= 100 THEN 'LOW'
            ELSE 'MINIMAL'
        END as volume_category,
        CASE
            WHEN verification_rate = 100 THEN 'PERFECT'
            WHEN verification_rate >= 95 THEN 'EXCELLENT'
            WHEN verification_rate >= 90 THEN 'GOOD'
            ELSE 'NEEDS_ATTENTION'
        END as quality_category
    FROM monthly_metrics
)

SELECT
    store_id,
    store_name,
    municipality,
    performance_month,
    transaction_count,
    active_days,
    verification_rate,
    source_diversity,
    volume_category,
    quality_category,
    {{ current_timestamp_tz() }} as computed_at
FROM categorized
