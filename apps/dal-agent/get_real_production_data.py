#!/usr/bin/env python3
"""
Get Real Production Data - Check actual production volumes and date ranges
"""

import pandas as pd
import sqlalchemy as sa
from datetime import datetime
import urllib.parse

def get_real_production_stats():
    """Get stats from real production tables to see actual data volume"""

    print("🔍 Connecting to Scout production database...")

    # Production database credentials
    params = urllib.parse.quote_plus(
        "DRIVER={ODBC Driver 18 for SQL Server};"
        "SERVER=sqltbwaprojectscoutserver.database.windows.net;"
        "DATABASE=SQL-TBWA-ProjectScout-Reporting-Prod;"
        "UID=TBWA;"
        "PWD=R@nd0mPA$$2025!;"
        "Encrypt=yes;"
        "TrustServerCertificate=yes;"
        "Connection Timeout=30;"
    )

    engine = sa.create_engine(
        f"mssql+pyodbc:///?odbc_connect={params}",
        pool_pre_ping=True
    )

    try:
        # Test connection
        with engine.connect() as conn:
            test_result = conn.execute(sa.text("SELECT GETDATE() as server_time"))
            server_time = test_result.fetchone()[0]
            print(f"✅ Connected! Server time: {server_time}")

        print("\n🔍 Checking actual production data volumes...")

        # Check main transaction tables for real data volume
        tables_to_check = [
            ("dbo.PayloadTransactions", "Full payload transactions"),
            ("dbo.SalesInteractions", "Sales interaction records"),
            ("dbo.v_transactions_flat_production", "Production flat view"),
            ("dbo.v_transactions_flat_v24", "v24 flat view"),
            ("bronze.transactions", "Bronze layer transactions"),
            ("gold.scout_dashboard_transactions", "Gold dashboard data")
        ]

        for table_name, description in tables_to_check:
            try:
                # Get count and date range
                count_query = f"SELECT COUNT(*) as total_count FROM {table_name}"
                count_result = pd.read_sql(count_query, engine)
                total_count = count_result['total_count'].iloc[0]

                print(f"\n📊 {table_name} ({description})")
                print(f"   Total records: {total_count:,}")

                if total_count > 0:
                    # Try to get date range - try different date column names
                    date_columns = ['TransactionDate', 'transaction_date', 'timestamp', 'created_at', 'Txn_TS']
                    date_info = None

                    for date_col in date_columns:
                        try:
                            date_query = f"""
                                SELECT
                                    MIN({date_col}) as min_date,
                                    MAX({date_col}) as max_date,
                                    COUNT(DISTINCT CAST({date_col} as DATE)) as unique_dates
                                FROM {table_name}
                            """
                            date_result = pd.read_sql(date_query, engine)
                            date_info = date_result.iloc[0]
                            print(f"   Date range ({date_col}): {date_info['min_date']} to {date_info['max_date']}")
                            print(f"   Unique dates: {date_info['unique_dates']}")
                            break
                        except:
                            continue

                    if not date_info:
                        print("   Date range: Could not determine")

            except Exception as e:
                print(f"   ❌ Error checking {table_name}: {e}")

        # Get sample from largest real table
        print(f"\n🎯 Let's get a real sample from the largest production table...")

        # Check which table has the most recent and largest data
        largest_table = None
        largest_count = 0

        for table_name, _ in tables_to_check:
            try:
                count_query = f"SELECT COUNT(*) as total_count FROM {table_name}"
                count_result = pd.read_sql(count_query, engine)
                count = count_result['total_count'].iloc[0]

                if count > largest_count:
                    largest_count = count
                    largest_table = table_name
            except:
                continue

        if largest_table and largest_count > 5000:
            print(f"\n🏆 Largest table: {largest_table} with {largest_count:,} records")
            print("📈 Getting comprehensive sample...")

            # Get a larger, more representative sample
            sample_query = f"""
                SELECT TOP 10000 *
                FROM {largest_table}
                ORDER BY NEWID()
            """

            try:
                sample_data = pd.read_sql(sample_query, engine)

                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"real_production_data_{timestamp}.csv"
                sample_data.to_csv(filename, index=False)

                print(f"✅ Real production sample exported: {filename}")
                print(f"📊 Sample size: {len(sample_data):,} records")
                print(f"🔍 Columns: {list(sample_data.columns)}")

                return sample_data

            except Exception as e:
                print(f"❌ Error getting sample: {e}")

        return None

    except Exception as e:
        print(f"❌ Failed to check production data: {e}")
        return None

    finally:
        engine.dispose()

if __name__ == "__main__":
    df = get_real_production_stats()