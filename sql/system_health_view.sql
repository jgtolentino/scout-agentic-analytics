-- System health summary view
CREATE OR ALTER VIEW audit.v_system_health_summary
AS
WITH latest_checks AS (
    SELECT
        check_type,
        status,
        alert_level,
        metric_value,
        details,
        ROW_NUMBER() OVER (PARTITION BY check_type ORDER BY check_timestamp DESC) as rn
    FROM audit.monitoring_log
    WHERE check_timestamp >= CAST(DATEADD(day, -1, GETUTCDATE()) AS DATE)
)
SELECT
    check_type,
    status,
    alert_level,
    metric_value,
    details,
    CASE
        WHEN alert_level = 'CRITICAL' THEN 1
        WHEN alert_level = 'WARNING' THEN 2
        WHEN alert_level = 'INFO' THEN 3
        ELSE 4
    END as priority_order
FROM latest_checks
WHERE rn = 1;