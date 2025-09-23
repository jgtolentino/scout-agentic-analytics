-- Monitoring dashboard view
CREATE OR ALTER VIEW audit.v_monitoring_dashboard
AS
SELECT
    check_timestamp,
    check_type,
    status,
    alert_level,
    metric_value,
    threshold_value,
    CASE
        WHEN alert_level = 'CRITICAL' THEN '🔴'
        WHEN alert_level = 'WARNING' THEN '🟡'
        ELSE '🟢'
    END as status_indicator,
    details,

    -- SLA calculations
    CASE check_type
        WHEN 'PARITY_CHECK' THEN
            CASE WHEN metric_value >= 100.0 THEN 'SLA_MET' ELSE 'SLA_BREACH' END
        WHEN 'FRESHNESS_CHECK' THEN
            CASE WHEN metric_value <= 12.0 THEN 'SLA_MET' ELSE 'SLA_BREACH' END
        WHEN 'RECORD_COUNT_CHECK' THEN
            CASE WHEN status = 'PASS' THEN 'SLA_MET' ELSE 'SLA_BREACH' END
        ELSE 'UNKNOWN'
    END as sla_status

FROM audit.monitoring_log
WHERE check_timestamp >= CAST(DATEADD(day, -7, GETUTCDATE()) AS DATE);