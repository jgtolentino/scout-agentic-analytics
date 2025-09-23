

WITH monthly_metrics AS (
    SELECT
        store_id,
        store_name,
        municipality,
        CAST(transaction_date AS DATE) as performance_date,
        DATEFROMPARTS(YEAR(transaction_date), MONTH(transaction_date), 1) as performance_month,
        COUNT(DISTINCT transaction_id) as transaction_count,
        COUNT(DISTINCT CAST(transaction_date AS DATE)) as active_days,
        AVG(CASE WHEN location_verified =
            1
            THEN 1 ELSE 0 END) * 100 as verification_rate,
        COUNT(DISTINCT data_source) as source_diversity
    FROM "SQL-TBWA-ProjectScout-Reporting-Prod"."dbo"."silver_location_verified"
    GROUP BY store_id, store_name, municipality, CAST(transaction_date AS DATE), DATEFROMPARTS(YEAR(transaction_date), MONTH(transaction_date), 1)
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
    SYSDATETIMEOFFSET() as computed_at
FROM categorized