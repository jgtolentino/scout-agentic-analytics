-- Test that all coordinates are within NCR bounds
SELECT
    COUNT(*) as failures
FROM {{ ref('silver_location_verified') }}
WHERE coordinates_valid = FALSE
    AND geo_latitude IS NOT NULL
    AND geo_longitude IS NOT NULL
HAVING COUNT(*) > 0
