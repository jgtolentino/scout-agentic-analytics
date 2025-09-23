-- Test that verification rate meets SLO
SELECT
    COUNT(*) as failures
FROM {{ ref('gold_store_performance') }}
WHERE verification_rate < {{ var('min_verification_rate') }}
HAVING COUNT(*) > 0
