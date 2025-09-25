#!/usr/bin/env python3
"""
Comprehensive Schema Analysis - Full database schema, tables, views, stored procedures
and ETL flow mapping for Scout production database
"""

import pandas as pd
import sqlalchemy as sa
from datetime import datetime
import urllib.parse
import json

def comprehensive_schema_analysis():
    """Complete analysis of Scout production database structure"""

    print("🔍 Connecting to Scout production database for comprehensive analysis...")

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

        print("\n" + "="*100)
        print("🗄️ COMPLETE SCOUT DATABASE SCHEMA ANALYSIS")
        print("="*100)

        # === 1. ALL SCHEMAS ===
        print(f"\n📂 DATABASE SCHEMAS:")
        schemas = pd.read_sql("""
            SELECT
                SCHEMA_NAME as schema_name
            FROM INFORMATION_SCHEMA.SCHEMATA
            ORDER BY SCHEMA_NAME
        """, engine)

        for _, row in schemas.iterrows():
            print(f"   📁 {row['schema_name']}")

        # === 2. ALL TABLES BY SCHEMA ===
        print(f"\n📋 ALL TABLES BY SCHEMA:")
        tables = pd.read_sql("""
            SELECT
                TABLE_SCHEMA as schema_name,
                TABLE_NAME as table_name,
                TABLE_TYPE as table_type
            FROM INFORMATION_SCHEMA.TABLES
            WHERE TABLE_TYPE = 'BASE TABLE'
            ORDER BY TABLE_SCHEMA, TABLE_NAME
        """, engine)

        current_schema = None
        for _, row in tables.iterrows():
            if row['schema_name'] != current_schema:
                current_schema = row['schema_name']
                print(f"\n   📂 {current_schema}:")
            print(f"      🗃️  {row['table_name']}")

        # === 3. ALL VIEWS BY SCHEMA ===
        print(f"\n👀 ALL VIEWS BY SCHEMA:")
        views = pd.read_sql("""
            SELECT
                TABLE_SCHEMA as schema_name,
                TABLE_NAME as view_name
            FROM INFORMATION_SCHEMA.VIEWS
            ORDER BY TABLE_SCHEMA, TABLE_NAME
        """, engine)

        current_schema = None
        for _, row in views.iterrows():
            if row['schema_name'] != current_schema:
                current_schema = row['schema_name']
                print(f"\n   📂 {current_schema}:")
            print(f"      👁️  {row['view_name']}")

        # === 4. ALL STORED PROCEDURES ===
        print(f"\n⚙️ ALL STORED PROCEDURES:")
        procedures = pd.read_sql("""
            SELECT
                ROUTINE_SCHEMA as schema_name,
                ROUTINE_NAME as procedure_name,
                CREATED as created_date,
                LAST_ALTERED as modified_date
            FROM INFORMATION_SCHEMA.ROUTINES
            WHERE ROUTINE_TYPE = 'PROCEDURE'
            ORDER BY ROUTINE_SCHEMA, ROUTINE_NAME
        """, engine)

        current_schema = None
        for _, row in procedures.iterrows():
            if row['schema_name'] != current_schema:
                current_schema = row['schema_name']
                print(f"\n   📂 {current_schema}:")
            print(f"      ⚙️  {row['procedure_name']} (Created: {row['created_date']}, Modified: {row['modified_date']})")

        # === 5. ALL FUNCTIONS ===
        print(f"\n🔧 ALL FUNCTIONS:")
        functions = pd.read_sql("""
            SELECT
                ROUTINE_SCHEMA as schema_name,
                ROUTINE_NAME as function_name,
                CREATED as created_date,
                LAST_ALTERED as modified_date
            FROM INFORMATION_SCHEMA.ROUTINES
            WHERE ROUTINE_TYPE = 'FUNCTION'
            ORDER BY ROUTINE_SCHEMA, ROUTINE_NAME
        """, engine)

        if not functions.empty:
            current_schema = None
            for _, row in functions.iterrows():
                if row['schema_name'] != current_schema:
                    current_schema = row['schema_name']
                    print(f"\n   📂 {current_schema}:")
                print(f"      🔧 {row['function_name']} (Created: {row['created_date']}, Modified: {row['modified_date']})")
        else:
            print("   ❌ No user-defined functions found")

        # === 6. TABLE RELATIONSHIPS AND CONSTRAINTS ===
        print(f"\n🔗 FOREIGN KEY RELATIONSHIPS:")
        fkeys = pd.read_sql("""
            SELECT
                fk.name as constraint_name,
                tp.name as parent_table,
                sp.name as parent_schema,
                cp.name as parent_column,
                tr.name as referenced_table,
                sr.name as referenced_schema,
                cr.name as referenced_column
            FROM sys.foreign_keys fk
            INNER JOIN sys.tables tp ON fk.parent_object_id = tp.object_id
            INNER JOIN sys.schemas sp ON tp.schema_id = sp.schema_id
            INNER JOIN sys.tables tr ON fk.referenced_object_id = tr.object_id
            INNER JOIN sys.schemas sr ON tr.schema_id = sr.schema_id
            INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
            INNER JOIN sys.columns cp ON fkc.parent_column_id = cp.column_id AND fkc.parent_object_id = cp.object_id
            INNER JOIN sys.columns cr ON fkc.referenced_column_id = cr.column_id AND fkc.referenced_object_id = cr.object_id
            ORDER BY sp.name, tp.name, fk.name
        """, engine)

        if not fkeys.empty:
            for _, row in fkeys.iterrows():
                print(f"   🔗 {row['parent_schema']}.{row['parent_table']}.{row['parent_column']} → {row['referenced_schema']}.{row['referenced_table']}.{row['referenced_column']}")
        else:
            print("   ❌ No foreign key constraints found")

        # === 7. KEY TABLE RECORD COUNTS ===
        print(f"\n📊 TABLE RECORD COUNTS (Key Tables):")

        key_tables = [
            'bronze.transactions', 'bronze.bronze_transactions',
            'dbo.PayloadTransactions', 'dbo.SalesInteractions', 'dbo.TransactionItems',
            'dbo.Stores', 'dbo.Products', 'dbo.Customers',
            'silver.silver_txn_items',
            'gold.scout_dashboard_transactions',
            'dbo.v_transactions_flat_production', 'dbo.v_transactions_flat_v24',
            'poc.transactions', 'scout.transactions'
        ]

        record_counts = {}
        for table in key_tables:
            try:
                count_result = pd.read_sql(f"SELECT COUNT(*) as count FROM {table}", engine)
                count = count_result['count'].iloc[0]
                record_counts[table] = count
                print(f"   📈 {table}: {count:,} records")
            except Exception as e:
                print(f"   ❌ {table}: Error - {str(e)[:50]}...")

        # === 8. ETL FLOW ANALYSIS ===
        print(f"\n🔄 ETL FLOW ANALYSIS:")

        # Check for ETL-related tables
        etl_tables = [
            'bronze.bronze_transactions', 'bronze.transactions',
            'silver.silver_txn_items',
            'gold.scout_dashboard_transactions',
            'dbo.PayloadTransactions', 'dbo.SalesInteractions',
            'staging.StoreLocationImport', 'dbo.PayloadTransactionsStaging_csv'
        ]

        print(f"\n   📊 ETL Layer Analysis:")
        for table in etl_tables:
            if table in record_counts:
                layer = table.split('.')[0].upper()
                print(f"   🏗️  {layer} → {table}: {record_counts[table]:,} records")

        # === 9. COLUMN ANALYSIS FOR KEY TABLES ===
        print(f"\n🔍 DETAILED COLUMN ANALYSIS:")

        key_analysis_tables = [
            'dbo.PayloadTransactions',
            'dbo.SalesInteractions',
            'gold.scout_dashboard_transactions',
            'dbo.v_transactions_flat_v24'
        ]

        for table in key_analysis_tables:
            try:
                columns = pd.read_sql(f"""
                    SELECT
                        COLUMN_NAME,
                        DATA_TYPE,
                        IS_NULLABLE,
                        COLUMN_DEFAULT,
                        CHARACTER_MAXIMUM_LENGTH
                    FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_SCHEMA = '{table.split('.')[0]}'
                    AND TABLE_NAME = '{table.split('.')[1]}'
                    ORDER BY ORDINAL_POSITION
                """, engine)

                if not columns.empty:
                    print(f"\n   🗃️  {table}:")
                    for _, col in columns.iterrows():
                        nullable = "NULL" if col['IS_NULLABLE'] == 'YES' else "NOT NULL"
                        max_len = f"({col['CHARACTER_MAXIMUM_LENGTH']})" if col['CHARACTER_MAXIMUM_LENGTH'] else ""
                        default = f" DEFAULT {col['COLUMN_DEFAULT']}" if col['COLUMN_DEFAULT'] else ""
                        print(f"      📋 {col['COLUMN_NAME']}: {col['DATA_TYPE']}{max_len} {nullable}{default}")

            except Exception as e:
                print(f"   ❌ {table}: Error getting columns - {str(e)[:50]}...")

        # === 10. SAVE COMPREHENSIVE SCHEMA ===
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        # Save all data to files
        schema_data = {
            'schemas': schemas.to_dict('records'),
            'tables': tables.to_dict('records'),
            'views': views.to_dict('records'),
            'procedures': procedures.to_dict('records'),
            'functions': functions.to_dict('records'),
            'foreign_keys': fkeys.to_dict('records'),
            'record_counts': record_counts
        }

        with open(f'scout_complete_schema_{timestamp}.json', 'w') as f:
            json.dump(schema_data, f, indent=2, default=str)

        print(f"\n✅ Complete schema analysis saved to: scout_complete_schema_{timestamp}.json")

        return schema_data

    except Exception as e:
        print(f"❌ Schema analysis failed: {e}")
        return None

    finally:
        engine.dispose()

if __name__ == "__main__":
    schema_data = comprehensive_schema_analysis()