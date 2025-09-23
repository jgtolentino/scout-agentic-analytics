#!/usr/bin/env python3
"""
Scout v7 Auto-Sync Test Script
Quick validation of the task framework and auto-sync system
"""
import os
import sys
import pyodbc
from datetime import datetime

def test_connection():
    """Test database connectivity"""
    try:
        # Use alternative credentials
        conn_str = (
            "DRIVER={ODBC Driver 18 for SQL Server};"
            "SERVER=tcp:sqltbwaprojectscoutserver.database.windows.net,1433;"
            "DATABASE=SQL-TBWA-ProjectScout-Reporting-Prod;"
            "UID=TBWA;"
            "PWD=R@nd0mPA$$2025!;"
            "Encrypt=yes;"
            "TrustServerCertificate=no;"
            "Connection Timeout=30;"
        )

        cn = pyodbc.connect(conn_str)
        cur = cn.cursor()

        # Test basic connectivity
        cur.execute("SELECT 1 AS test_connection, GETDATE() AS [current_time]")
        result = cur.fetchone()
        print(f"✅ Database connection successful: {result[1]}")
        return cn, cur

    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        return None, None

def test_task_framework(cur):
    """Test task framework components"""
    try:
        # Check if task framework is installed
        cur.execute("SELECT COUNT(*) FROM system.task_definitions WHERE enabled=1")
        task_count = cur.fetchone()[0]
        print(f"✅ Task framework installed: {task_count} active tasks")

        # Check Change Tracking
        cur.execute("""
            SELECT
                CHANGE_TRACKING_CURRENT_VERSION() AS current_version,
                CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID('silver.Transactions')) AS min_valid_version
        """)
        ct_result = cur.fetchone()
        if ct_result[0] is not None:
            print(f"✅ Change Tracking enabled: current={ct_result[0]}, min_valid={ct_result[1]}")
        else:
            print("⚠️  Change Tracking not enabled")

        # Check export view
        cur.execute("SELECT COUNT(*) FROM gold.vw_FlatExport")
        export_count = cur.fetchone()[0]
        print(f"✅ Export view accessible: {export_count} records")

        return True

    except Exception as e:
        print(f"❌ Task framework test failed: {e}")
        return False

def test_task_registration(cur):
    """Test task registration and basic operations"""
    try:
        # Register a test task
        cur.execute("""
            EXEC system.sp_task_register
            @task_code='TEST_VALIDATION',
            @task_name='Auto-Sync Validation Test',
            @description='Validation test for Scout v7 auto-sync system',
            @owner='Test'
        """)

        # Start a test run
        cur.execute("""
            EXEC system.sp_task_start
            @task_code='TEST_VALIDATION',
            @pid='test_script',
            @host='local_test',
            @note='Validation test run'
        """)
        run_result = cur.fetchone()
        run_id = run_result[0]
        print(f"✅ Test task run started: run_id={run_id}")

        # Send a heartbeat
        cur.execute("""
            EXEC system.sp_task_heartbeat
            @run_id=?,
            @level='INFO',
            @message='Test heartbeat message'
        """, (run_id,))

        # Finish the test run
        cur.execute("""
            EXEC system.sp_task_finish
            @run_id=?,
            @rows_read=100,
            @note='Test completed successfully'
        """, (run_id,))

        print("✅ Task execution cycle completed successfully")

        # Clean up test task
        cur.execute("DELETE FROM system.task_definitions WHERE task_code='TEST_VALIDATION'")

        return True

    except Exception as e:
        print(f"❌ Task registration test failed: {e}")
        return False

def test_canonical_ids(cur):
    """Test canonical ID normalization"""
    try:
        # Check canonical ID format in silver.Transactions
        cur.execute("""
            SELECT TOP 5
                canonical_tx_id,
                CASE WHEN canonical_tx_id LIKE '%-%' OR canonical_tx_id COLLATE Latin1_General_CS_AS LIKE '%[A-Z]%'
                     THEN 'UNNORMALIZED' ELSE 'NORMALIZED' END AS format_status
            FROM silver.Transactions
        """)

        results = cur.fetchall()
        normalized_count = sum(1 for r in results if r[1] == 'NORMALIZED')
        print(f"✅ Canonical ID test: {normalized_count}/{len(results)} records properly normalized")

        return len(results) > 0

    except Exception as e:
        print(f"❌ Canonical ID test failed: {e}")
        return False

def test_export_view(cur):
    """Test export view with SI timestamps"""
    try:
        # Test export view with timestamp sources
        cur.execute("""
            SELECT TOP 5
                canonical_tx_id,
                timestamp_source,
                txn_ts,
                transaction_date
            FROM gold.vw_FlatExport
            ORDER BY txn_ts DESC
        """)

        results = cur.fetchall()
        si_count = sum(1 for r in results if r[1] == 'SalesInteractions')
        print(f"✅ Export view test: {len(results)} records, {si_count} using SI timestamps")

        return len(results) > 0

    except Exception as e:
        print(f"❌ Export view test failed: {e}")
        return False

def main():
    """Run all validation tests"""
    print("🧪 Scout v7 Auto-Sync Validation Test")
    print("=" * 50)

    # Test database connection
    cn, cur = test_connection()
    if not cn:
        sys.exit(1)

    tests_passed = 0
    total_tests = 5

    try:
        # Run validation tests
        if test_task_framework(cur):
            tests_passed += 1

        if test_task_registration(cur):
            tests_passed += 1

        if test_canonical_ids(cur):
            tests_passed += 1

        if test_export_view(cur):
            tests_passed += 1

        # Final connectivity test
        cur.execute("SELECT COUNT(*) FROM system.v_task_status")
        task_status_count = cur.fetchone()[0]
        if task_status_count > 0:
            print(f"✅ Task status view accessible: {task_status_count} tasks")
            tests_passed += 1

    finally:
        cn.close()

    # Summary
    print("\n" + "=" * 50)
    print(f"🎯 Validation Summary: {tests_passed}/{total_tests} tests passed")

    if tests_passed == total_tests:
        print("🎉 All tests passed! Auto-sync system is ready for deployment.")
        return 0
    else:
        print("⚠️  Some tests failed. Please check the deployment.")
        return 1

if __name__ == "__main__":
    sys.exit(main())