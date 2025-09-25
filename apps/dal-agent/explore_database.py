#!/usr/bin/env python3
"""
Database Explorer - Check available tables and schemas
"""

import pandas as pd
import sqlalchemy as sa
import urllib.parse

def explore_database():
    """Explore the database structure to find available tables"""

    print("🔍 Exploring Scout production database structure...")

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
        # 1. List all schemas
        print("\n📂 Available Schemas:")
        schemas = pd.read_sql("""
            SELECT SCHEMA_NAME as schema_name
            FROM INFORMATION_SCHEMA.SCHEMATA
            ORDER BY SCHEMA_NAME
        """, engine)
        for schema in schemas['schema_name']:
            print(f"  - {schema}")

        # 2. List all tables with their schemas
        print("\n📋 Available Tables:")
        tables = pd.read_sql("""
            SELECT
                TABLE_SCHEMA as schema_name,
                TABLE_NAME as table_name,
                TABLE_TYPE as table_type
            FROM INFORMATION_SCHEMA.TABLES
            WHERE TABLE_TYPE IN ('BASE TABLE', 'VIEW')
            ORDER BY TABLE_SCHEMA, TABLE_NAME
        """, engine)

        for _, row in tables.iterrows():
            print(f"  - {row['schema_name']}.{row['table_name']} ({row['table_type']})")

        # 3. Look for transaction-related tables
        print("\n🔍 Transaction-related tables:")
        transaction_tables = tables[
            tables['table_name'].str.contains('transaction|payload|sales', case=False, na=False)
        ]

        if not transaction_tables.empty:
            for _, row in transaction_tables.iterrows():
                table_name = f"{row['schema_name']}.{row['table_name']}"
                print(f"  ✅ {table_name}")

                # Get column info for transaction tables
                try:
                    columns = pd.read_sql(f"""
                        SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
                        FROM INFORMATION_SCHEMA.COLUMNS
                        WHERE TABLE_SCHEMA = '{row['schema_name']}'
                        AND TABLE_NAME = '{row['table_name']}'
                        ORDER BY ORDINAL_POSITION
                    """, engine)

                    print(f"     Columns: {', '.join(columns['COLUMN_NAME'].head(10).tolist())}")
                    if len(columns) > 10:
                        print(f"     ... and {len(columns) - 10} more")

                except Exception as e:
                    print(f"     Could not retrieve columns: {e}")

        else:
            print("  ❌ No transaction-related tables found")

        # 4. Check gold layer specifically
        print("\n🏆 Gold Layer Tables:")
        gold_tables = tables[tables['schema_name'] == 'gold']

        if not gold_tables.empty:
            for _, row in gold_tables.iterrows():
                print(f"  ✅ gold.{row['table_name']}")

                # Sample data from gold tables
                try:
                    sample = pd.read_sql(f"""
                        SELECT TOP 3 * FROM gold.{row['table_name']}
                    """, engine)
                    print(f"     Sample columns: {', '.join(sample.columns.tolist())}")
                    print(f"     Row count sample: {len(sample)} rows")

                except Exception as e:
                    print(f"     Could not sample data: {e}")
        else:
            print("  ❌ No gold schema tables found")

        return tables

    except Exception as e:
        print(f"❌ Database exploration failed: {e}")
        return None

    finally:
        engine.dispose()

if __name__ == "__main__":
    tables_df = explore_database()