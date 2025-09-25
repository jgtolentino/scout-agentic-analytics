#!/usr/bin/env python3
"""
Check substitution events in Scout Analytics database
"""
import pyodbc
import os

def main():
    # Try to connect using the same pattern as our extraction script
    conn_str = os.getenv('AZURE_SQL_CONN_STR')
    if not conn_str:
        conn_str = (
            'Driver={ODBC Driver 18 for SQL Server};'
            'Server=scout-analytics-server.database.windows.net;'
            'Database=SQL-TBWA-ProjectScout-Reporting-Prod;'
            'UID=sqladmin;'
            'PWD=Azure_pw26;'
            'Encrypt=yes;'
            'TrustServerCertificate=no;'
            'Connection Timeout=30;'
        )

    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()

        # Query substitution events from v_insight_base
        print('📊 Substitution Event Analysis:')
        print('=' * 40)

        # Total rows in v_insight_base
        cursor.execute('SELECT COUNT(*) FROM dbo.v_insight_base')
        total_insights = cursor.fetchone()[0]
        print(f'Total rows in v_insight_base: {total_insights:,}')

        # Substitution event breakdown
        cursor.execute('''
        SELECT
            substitution_event,
            COUNT(*) as count,
            CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as decimal(5,2)) as percentage
        FROM dbo.v_insight_base
        WHERE substitution_event IS NOT NULL
        GROUP BY substitution_event
        ORDER BY substitution_event
        ''')

        print('\nSubstitution Event Breakdown:')
        rows = cursor.fetchall()
        for row in rows:
            event_type = 'TRUE' if row[0] == '1' else 'FALSE' if row[0] == '0' else f'"{row[0]}"'
            print(f'  {event_type}: {row[1]:,} ({row[2]}%)')

        # Check NULL values
        cursor.execute('SELECT COUNT(*) FROM dbo.v_insight_base WHERE substitution_event IS NULL')
        null_count = cursor.fetchone()[0]
        if null_count > 0:
            null_pct = (null_count / total_insights) * 100
            print(f'  NULL: {null_count:,} ({null_pct:.2f}%)')

        # Check unique sessions with substitution data
        cursor.execute('''
        SELECT COUNT(DISTINCT sessionId)
        FROM dbo.v_insight_base
        WHERE substitution_event IN ('0', '1')
        ''')
        unique_sessions_result = cursor.fetchone()
        if unique_sessions_result:
            unique_sessions = unique_sessions_result[0]
            print(f'\nUnique sessions with substitution data: {unique_sessions:,}')

        # Check coverage against flat export (if view exists)
        try:
            cursor.execute('SELECT COUNT(DISTINCT Transaction_ID) FROM dbo.v_flat_export_sheet')
            total_transactions = cursor.fetchone()[0]

            cursor.execute('''
            SELECT COUNT(*)
            FROM dbo.v_flat_export_sheet
            WHERE Was_Substitution IN ('true', 'false')
            ''')
            transactions_with_sub_data = cursor.fetchone()[0]

            coverage_pct = (transactions_with_sub_data / total_transactions) * 100 if total_transactions > 0 else 0
            print(f'\nCoverage in flat export:')
            print(f'  Total transactions: {total_transactions:,}')
            print(f'  With substitution data: {transactions_with_sub_data:,} ({coverage_pct:.1f}%)')

        except Exception as e:
            print(f'\n⚠️ Could not check flat export coverage: {e}')

        conn.close()

    except Exception as e:
        print(f'❌ Database query failed: {e}')
        print('Database may be unavailable or credentials need updating')

if __name__ == "__main__":
    main()