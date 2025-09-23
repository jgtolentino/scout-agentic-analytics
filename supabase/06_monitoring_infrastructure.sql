-- ==========================================
-- Zero-Trust Location System: Monitoring Infrastructure
-- SLO tracking, history tables, and alerting
-- ==========================================

-- This script creates comprehensive monitoring infrastructure for production
-- SLO tracking, automated alerting, and operational metrics collection.

-- ==========================================
-- 1. OPERATIONAL SCHEMA FOR MONITORING
-- ==========================================

-- Create dedicated schema for operational monitoring
CREATE SCHEMA IF NOT EXISTS ops;

COMMENT ON SCHEMA ops IS
'Operational monitoring schema for zero-trust location system SLOs and metrics';

-- ==========================================
-- 2. LOCATION VERIFICATION HISTORY TABLE
-- ==========================================

-- Historical tracking of verification rates and system health
CREATE TABLE IF NOT EXISTS ops.location_verification_history (
    captured_at         TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_transactions  INTEGER NOT NULL CHECK (total_transactions >= 0),
    verified_transactions INTEGER NOT NULL CHECK (verified_transactions >= 0),
    unknown_transactions INTEGER NOT NULL CHECK (unknown_transactions >= 0),
    verification_rate   NUMERIC(6,2) NOT NULL CHECK (verification_rate BETWEEN 0 AND 100),
    unique_stores       INTEGER NOT NULL CHECK (unique_stores >= 0),
    stores_in_dimension INTEGER NOT NULL CHECK (stores_in_dimension >= 0),
    integrity_violations INTEGER NOT NULL DEFAULT 0 CHECK (integrity_violations >= 0),
    payload_violations  INTEGER NOT NULL DEFAULT 0 CHECK (payload_violations >= 0),
    coordinate_violations INTEGER NOT NULL DEFAULT 0 CHECK (coordinate_violations >= 0),
    system_status       TEXT NOT NULL CHECK (system_status IN ('HEALTHY', 'DEGRADED', 'CRITICAL')),
    slo_status          JSONB NOT NULL DEFAULT '{}',
    metadata            JSONB DEFAULT '{}',

    CONSTRAINT pk_verification_history PRIMARY KEY (captured_at),
    CONSTRAINT chk_verification_consistency
        CHECK (verified_transactions + unknown_transactions <= total_transactions)
);

-- Index for time-based queries
CREATE INDEX IF NOT EXISTS idx_verification_history_time
    ON ops.location_verification_history (captured_at DESC);

-- Index for status monitoring
CREATE INDEX IF NOT EXISTS idx_verification_history_status
    ON ops.location_verification_history (system_status, captured_at DESC);

COMMENT ON TABLE ops.location_verification_history IS
'Historical tracking of zero-trust location system metrics and SLO compliance';

-- ==========================================
-- 3. SLO DEFINITIONS AND TRACKING
-- ==========================================

-- SLO configuration table
CREATE TABLE IF NOT EXISTS ops.slo_definitions (
    slo_name            TEXT PRIMARY KEY,
    slo_description     TEXT NOT NULL,
    target_value        NUMERIC NOT NULL,
    operator            TEXT NOT NULL CHECK (operator IN ('=', '>=', '<=', '>', '<', '!=')),
    severity            TEXT NOT NULL CHECK (severity IN ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW')),
    enabled             BOOLEAN NOT NULL DEFAULT TRUE,
    grace_period_minutes INTEGER DEFAULT 5 CHECK (grace_period_minutes >= 0),
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Insert SLO definitions
INSERT INTO ops.slo_definitions (slo_name, slo_description, target_value, operator, severity) VALUES
    ('verification_rate', 'Location verification rate must be 100%', 100.0, '=', 'CRITICAL'),
    ('integrity_violations', 'Zero integrity violations allowed', 0, '=', 'CRITICAL'),
    ('payload_violations', 'Zero payload structure violations allowed', 0, '=', 'HIGH'),
    ('coordinate_violations', 'Zero coordinate bound violations allowed', 0, '=', 'MEDIUM'),
    ('store_coverage', 'All transaction stores must be in dimension', 100.0, '>=', 'HIGH'),
    ('runner_freshness_hours', 'Runner report must be < 24 hours old', 24, '<', 'MEDIUM')
ON CONFLICT (slo_name) DO UPDATE SET
    slo_description = EXCLUDED.slo_description,
    target_value = EXCLUDED.target_value,
    updated_at = CURRENT_TIMESTAMP;

-- ==========================================
-- 4. METRICS COLLECTION FUNCTIONS
-- ==========================================

-- Comprehensive metrics collection function
CREATE OR REPLACE FUNCTION ops.collect_system_metrics()
RETURNS TABLE (
    metric_name TEXT,
    metric_value NUMERIC,
    metric_unit TEXT,
    threshold_status TEXT
)
LANGUAGE sql AS $$
    WITH current_metrics AS (
        SELECT
            COUNT(*) as total_tx,
            COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE) as verified_tx,
            COUNT(*) FILTER (WHERE payload_json -> 'location' ->> 'municipality' = 'Unknown') as unknown_tx,
            COUNT(DISTINCT store_id) as unique_stores
        FROM public.fact_transactions_location
    ),
    dimension_metrics AS (
        SELECT COUNT(*) as stores_in_dim
        FROM public.dim_stores_ncr
    ),
    violation_metrics AS (
        SELECT
            COUNT(*) FILTER (WHERE status = 'FAIL' AND check_category = 'Core Integrity') as integrity_violations,
            COUNT(*) FILTER (WHERE status = 'FAIL' AND check_category = 'Payload Structure') as payload_violations,
            COUNT(*) FILTER (WHERE status = 'FAIL' AND check_category = 'Geographic Bounds') as coordinate_violations
        FROM comprehensive_zero_trust_validation()
    )
    SELECT 'total_transactions', cm.total_tx::numeric, 'count', 'INFO' FROM current_metrics cm
    UNION ALL
    SELECT 'verified_transactions', cm.verified_tx::numeric, 'count',
           CASE WHEN cm.verified_tx = cm.total_tx THEN 'PASS' ELSE 'FAIL' END
    FROM current_metrics cm
    UNION ALL
    SELECT 'verification_rate',
           ROUND((cm.verified_tx * 100.0 / NULLIF(cm.total_tx, 0)), 2),
           'percentage',
           CASE WHEN cm.verified_tx = cm.total_tx THEN 'PASS' ELSE 'FAIL' END
    FROM current_metrics cm
    UNION ALL
    SELECT 'unknown_transactions', cm.unknown_tx::numeric, 'count',
           CASE WHEN cm.unknown_tx = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM current_metrics cm
    UNION ALL
    SELECT 'store_coverage_pct',
           ROUND((dm.stores_in_dim * 100.0 / NULLIF(cm.unique_stores, 0)), 2),
           'percentage',
           CASE WHEN dm.stores_in_dim >= cm.unique_stores THEN 'PASS' ELSE 'FAIL' END
    FROM current_metrics cm, dimension_metrics dm
    UNION ALL
    SELECT 'integrity_violations', vm.integrity_violations::numeric, 'count',
           CASE WHEN vm.integrity_violations = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM violation_metrics vm
    UNION ALL
    SELECT 'payload_violations', vm.payload_violations::numeric, 'count',
           CASE WHEN vm.payload_violations = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM violation_metrics vm
    UNION ALL
    SELECT 'coordinate_violations', vm.coordinate_violations::numeric, 'count',
           CASE WHEN vm.coordinate_violations = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM violation_metrics vm;
$$;

-- SLO evaluation function
CREATE OR REPLACE FUNCTION ops.evaluate_slos()
RETURNS TABLE (
    slo_name TEXT,
    current_value NUMERIC,
    target_value NUMERIC,
    operator TEXT,
    slo_status TEXT,
    severity TEXT,
    last_checked TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql AS $$
DECLARE
    _metric_row RECORD;
    _slo_row RECORD;
    _current_value NUMERIC;
    _slo_met BOOLEAN;
BEGIN
    -- Get current metrics
    CREATE TEMP TABLE temp_metrics AS
    SELECT metric_name, metric_value
    FROM ops.collect_system_metrics();

    -- Evaluate each SLO
    FOR _slo_row IN
        SELECT * FROM ops.slo_definitions WHERE enabled = TRUE
    LOOP
        -- Get current value for this SLO
        SELECT metric_value INTO _current_value
        FROM temp_metrics
        WHERE metric_name = _slo_row.slo_name;

        IF _current_value IS NULL THEN
            -- Handle special cases
            CASE _slo_row.slo_name
                WHEN 'runner_freshness_hours' THEN
                    -- Check when runner last ran (placeholder - would check actual runner logs)
                    _current_value := EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP -
                        (SELECT MAX(captured_at) FROM ops.location_verification_history))) / 3600;
                ELSE
                    _current_value := -999; -- Error indicator
            END CASE;
        END IF;

        -- Evaluate SLO condition
        _slo_met := CASE _slo_row.operator
            WHEN '=' THEN _current_value = _slo_row.target_value
            WHEN '>=' THEN _current_value >= _slo_row.target_value
            WHEN '<=' THEN _current_value <= _slo_row.target_value
            WHEN '>' THEN _current_value > _slo_row.target_value
            WHEN '<' THEN _current_value < _slo_row.target_value
            WHEN '!=' THEN _current_value != _slo_row.target_value
            ELSE FALSE
        END;

        RETURN QUERY VALUES (
            _slo_row.slo_name,
            _current_value,
            _slo_row.target_value,
            _slo_row.operator,
            CASE WHEN _slo_met THEN 'PASS' ELSE 'FAIL' END,
            _slo_row.severity,
            CURRENT_TIMESTAMP
        );
    END LOOP;

    DROP TABLE temp_metrics;
END;
$$;

-- ==========================================
-- 5. AUTOMATED SNAPSHOT CAPTURE
-- ==========================================

-- Capture current system state and store in history
CREATE OR REPLACE FUNCTION ops.capture_verification_snapshot()
RETURNS TABLE (
    snapshot_time TIMESTAMP WITH TIME ZONE,
    system_health TEXT,
    verification_rate NUMERIC,
    total_violations INTEGER
)
LANGUAGE plpgsql AS $$
DECLARE
    _total_tx INTEGER;
    _verified_tx INTEGER;
    _unknown_tx INTEGER;
    _unique_stores INTEGER;
    _stores_in_dim INTEGER;
    _verification_rate NUMERIC(6,2);
    _integrity_violations INTEGER := 0;
    _payload_violations INTEGER := 0;
    _coordinate_violations INTEGER := 0;
    _system_status TEXT;
    _slo_status JSONB := '{}';
    _slo_row RECORD;
BEGIN
    -- Collect current metrics
    SELECT
        metric_value INTO _total_tx
    FROM ops.collect_system_metrics() WHERE metric_name = 'total_transactions';

    SELECT
        metric_value INTO _verified_tx
    FROM ops.collect_system_metrics() WHERE metric_name = 'verified_transactions';

    SELECT
        metric_value INTO _unknown_tx
    FROM ops.collect_system_metrics() WHERE metric_name = 'unknown_transactions';

    SELECT
        COUNT(DISTINCT store_id) INTO _unique_stores
    FROM public.fact_transactions_location;

    SELECT
        COUNT(*) INTO _stores_in_dim
    FROM public.dim_stores_ncr;

    -- Calculate verification rate
    _verification_rate := ROUND((_verified_tx * 100.0 / NULLIF(_total_tx, 0)), 2);

    -- Get violation counts
    SELECT
        metric_value INTO _integrity_violations
    FROM ops.collect_system_metrics() WHERE metric_name = 'integrity_violations';

    SELECT
        metric_value INTO _payload_violations
    FROM ops.collect_system_metrics() WHERE metric_name = 'payload_violations';

    SELECT
        metric_value INTO _coordinate_violations
    FROM ops.collect_system_metrics() WHERE metric_name = 'coordinate_violations';

    -- Determine system status
    IF (_integrity_violations + _payload_violations + _coordinate_violations) = 0
       AND _verification_rate = 100.0 THEN
        _system_status := 'HEALTHY';
    ELSIF (_integrity_violations > 0) OR (_verification_rate < 95.0) THEN
        _system_status := 'CRITICAL';
    ELSE
        _system_status := 'DEGRADED';
    END IF;

    -- Build SLO status JSON
    FOR _slo_row IN SELECT * FROM ops.evaluate_slos() LOOP
        _slo_status := _slo_status || jsonb_build_object(_slo_row.slo_name, _slo_row.slo_status);
    END LOOP;

    -- Insert snapshot
    INSERT INTO ops.location_verification_history (
        captured_at, total_transactions, verified_transactions, unknown_transactions,
        verification_rate, unique_stores, stores_in_dimension,
        integrity_violations, payload_violations, coordinate_violations,
        system_status, slo_status,
        metadata
    ) VALUES (
        CURRENT_TIMESTAMP, _total_tx, _verified_tx, _unknown_tx,
        _verification_rate, _unique_stores, _stores_in_dim,
        _integrity_violations, _payload_violations, _coordinate_violations,
        _system_status, _slo_status,
        jsonb_build_object(
            'runner_version', '1.0',
            'capture_method', 'automated',
            'data_freshness_minutes', 0
        )
    );

    RETURN QUERY VALUES (
        CURRENT_TIMESTAMP,
        _system_status,
        _verification_rate,
        (_integrity_violations + _payload_violations + _coordinate_violations)
    );
END;
$$;

-- ==========================================
-- 6. ALERTING INFRASTRUCTURE
-- ==========================================

-- Alert history table
CREATE TABLE IF NOT EXISTS ops.alert_history (
    alert_id            SERIAL PRIMARY KEY,
    triggered_at        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    alert_type          TEXT NOT NULL CHECK (alert_type IN ('SLO_VIOLATION', 'SYSTEM_DEGRADED', 'CRITICAL_ERROR')),
    severity            TEXT NOT NULL CHECK (severity IN ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW')),
    slo_name            TEXT,
    current_value       NUMERIC,
    target_value        NUMERIC,
    message             TEXT NOT NULL,
    acknowledged        BOOLEAN NOT NULL DEFAULT FALSE,
    acknowledged_at     TIMESTAMP WITH TIME ZONE,
    acknowledged_by     TEXT,
    resolved            BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_at         TIMESTAMP WITH TIME ZONE,
    metadata            JSONB DEFAULT '{}'
);

-- Index for alert queries
CREATE INDEX IF NOT EXISTS idx_alert_history_status
    ON ops.alert_history (triggered_at DESC, acknowledged, resolved);

-- Alert generation function
CREATE OR REPLACE FUNCTION ops.generate_alerts()
RETURNS TABLE (
    alert_created BOOLEAN,
    alert_message TEXT,
    alert_severity TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
    _slo_row RECORD;
    _alert_exists BOOLEAN;
BEGIN
    -- Check each SLO for violations
    FOR _slo_row IN SELECT * FROM ops.evaluate_slos() WHERE slo_status = 'FAIL' LOOP
        -- Check if alert already exists for this SLO (within grace period)
        SELECT EXISTS(
            SELECT 1 FROM ops.alert_history
            WHERE slo_name = _slo_row.slo_name
            AND NOT resolved
            AND triggered_at > CURRENT_TIMESTAMP - INTERVAL '1 hour'
        ) INTO _alert_exists;

        IF NOT _alert_exists THEN
            -- Create new alert
            INSERT INTO ops.alert_history (
                alert_type, severity, slo_name, current_value, target_value, message
            ) VALUES (
                'SLO_VIOLATION',
                _slo_row.severity,
                _slo_row.slo_name,
                _slo_row.current_value,
                _slo_row.target_value,
                format('SLO violation: %s = %s (target: %s %s)',
                       _slo_row.slo_name, _slo_row.current_value,
                       _slo_row.operator, _slo_row.target_value)
            );

            RETURN QUERY VALUES (
                TRUE,
                format('Alert created for SLO violation: %s', _slo_row.slo_name),
                _slo_row.severity
            );
        END IF;
    END LOOP;

    -- If no new alerts created
    IF NOT FOUND THEN
        RETURN QUERY VALUES (
            FALSE,
            'No new alerts required - all SLOs passing',
            'INFO'
        );
    END IF;
END;
$$;

-- ==========================================
-- 7. MONITORING DASHBOARD VIEWS
-- ==========================================

-- Real-time system dashboard
CREATE OR REPLACE VIEW ops.dashboard_real_time AS
SELECT
    'Zero-Trust Location System' as system_name,
    CURRENT_TIMESTAMP as dashboard_updated,
    (SELECT system_status FROM ops.location_verification_history ORDER BY captured_at DESC LIMIT 1) as current_status,
    (SELECT verification_rate FROM ops.location_verification_history ORDER BY captured_at DESC LIMIT 1) as current_verification_rate,
    (
        SELECT COUNT(*)
        FROM ops.evaluate_slos()
        WHERE slo_status = 'PASS'
    ) as slos_passing,
    (
        SELECT COUNT(*)
        FROM ops.evaluate_slos()
    ) as total_slos,
    (
        SELECT COUNT(*)
        FROM ops.alert_history
        WHERE NOT resolved AND triggered_at > CURRENT_TIMESTAMP - INTERVAL '24 hours'
    ) as active_alerts_24h,
    (
        SELECT jsonb_agg(
            jsonb_build_object(
                'slo_name', slo_name,
                'status', slo_status,
                'current', current_value,
                'target', target_value
            )
        )
        FROM ops.evaluate_slos()
    ) as slo_summary;

-- Historical trends view
CREATE OR REPLACE VIEW ops.dashboard_trends AS
SELECT
    DATE_TRUNC('day', captured_at) as date,
    AVG(verification_rate) as avg_verification_rate,
    MIN(verification_rate) as min_verification_rate,
    MAX(verification_rate) as max_verification_rate,
    COUNT(*) FILTER (WHERE system_status = 'HEALTHY') as healthy_snapshots,
    COUNT(*) FILTER (WHERE system_status = 'DEGRADED') as degraded_snapshots,
    COUNT(*) FILTER (WHERE system_status = 'CRITICAL') as critical_snapshots,
    COUNT(*) as total_snapshots
FROM ops.location_verification_history
WHERE captured_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE_TRUNC('day', captured_at)
ORDER BY date DESC;

-- ==========================================
-- 8. AUTOMATED MAINTENANCE FUNCTIONS
-- ==========================================

-- Cleanup old monitoring data
CREATE OR REPLACE FUNCTION ops.cleanup_monitoring_data(retention_days INTEGER DEFAULT 90)
RETURNS TABLE (
    cleanup_action TEXT,
    records_removed INTEGER
)
LANGUAGE plpgsql AS $$
DECLARE
    _history_removed INTEGER;
    _alerts_removed INTEGER;
BEGIN
    -- Clean up old verification history
    WITH deleted AS (
        DELETE FROM ops.location_verification_history
        WHERE captured_at < CURRENT_DATE - (retention_days || ' days')::INTERVAL
        RETURNING *
    )
    SELECT COUNT(*) INTO _history_removed FROM deleted;

    -- Clean up resolved alerts older than retention period
    WITH deleted AS (
        DELETE FROM ops.alert_history
        WHERE resolved = TRUE
        AND resolved_at < CURRENT_DATE - (retention_days || ' days')::INTERVAL
        RETURNING *
    )
    SELECT COUNT(*) INTO _alerts_removed FROM deleted;

    RETURN QUERY VALUES
        ('Verification history cleanup', _history_removed),
        ('Resolved alerts cleanup', _alerts_removed);
END;
$$;

-- ==========================================
-- 9. INITIALIZATION AND VALIDATION
-- ==========================================

-- Capture initial baseline snapshot
SELECT ops.capture_verification_snapshot();

-- Generate initial SLO evaluation
SELECT * FROM ops.evaluate_slos();

-- Validate monitoring infrastructure
DO $$
DECLARE
    _table_count INTEGER;
    _function_count INTEGER;
    _view_count INTEGER;
BEGIN
    -- Count monitoring objects
    SELECT COUNT(*) INTO _table_count
    FROM information_schema.tables
    WHERE table_schema = 'ops';

    SELECT COUNT(*) INTO _function_count
    FROM information_schema.routines
    WHERE routine_schema = 'ops';

    SELECT COUNT(*) INTO _view_count
    FROM information_schema.views
    WHERE table_schema = 'ops';

    RAISE NOTICE 'Monitoring Infrastructure Deployed Successfully:';
    RAISE NOTICE '- Monitoring tables: %', _table_count;
    RAISE NOTICE '- Monitoring functions: %', _function_count;
    RAISE NOTICE '- Dashboard views: %', _view_count;
    RAISE NOTICE '- Initial snapshot captured';
    RAISE NOTICE '- SLO monitoring active';
END $$;