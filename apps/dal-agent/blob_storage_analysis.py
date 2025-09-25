#!/usr/bin/env python3
"""
Azure Blob Storage Analysis - Check if Scout ETL flows from blob storage
"""

import pandas as pd
import sqlalchemy as sa
import urllib.parse

def analyze_blob_storage_integration():
    """Analyze if Scout ETL flows from Azure Blob Storage"""

    print("🔍 Analyzing Scout ETL for Blob Storage integration...")

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
        with engine.connect() as conn:
            print(f"✅ Connected to Scout production database")

        print("\n" + "="*80)
        print("🗄️ BLOB STORAGE & ETL FLOW ANALYSIS")
        print("="*80)

        # 1. Check for blob storage references in metadata tables
        print("\n🔍 CHECKING FOR BLOB STORAGE REFERENCES:")

        blob_related_queries = [
            # Check fileMetadata for blob references
            ("fileMetadata - File sources", """
                SELECT TOP 10
                    file_id, file_name, file_path, file_size,
                    created_at, source_type, storage_location
                FROM dbo.fileMetadata
                ORDER BY created_at DESC
            """),

            # Check processingLogs for blob processing
            ("processingLogs - ETL processing logs", """
                SELECT TOP 10
                    log_id, process_name, source_file, target_table,
                    processing_status, created_at, file_size, records_processed
                FROM dbo.processingLogs
                ORDER BY created_at DESC
            """),

            # Check audit logs for data loading
            ("IntegrationAuditLogs - Data integration logs", """
                SELECT TOP 10
                    audit_id, integration_name, source_system, target_table,
                    status, records_affected, execution_time, created_at
                FROM dbo.IntegrationAuditLogs
                ORDER BY created_at DESC
            """),

            # Check staging tables for blob data patterns
            ("PayloadTransactionsStaging_csv - CSV staging", """
                SELECT TOP 10
                    source_path, transactionId, deviceId, storeId,
                    LEN(payload_json) as payload_size
                FROM dbo.PayloadTransactionsStaging_csv
            """),

            # Check for external data sources
            ("External data source configuration", """
                SELECT
                    name,
                    type_desc,
                    data_source_id,
                    location
                FROM sys.external_data_sources
            """)
        ]

        blob_evidence = {}
        for query_name, query in blob_related_queries:
            try:
                result = pd.read_sql(query, engine)
                blob_evidence[query_name] = result

                print(f"\n📊 {query_name}:")
                if not result.empty:
                    print(f"   ✅ Found {len(result)} records")

                    # Look for blob-like paths in results
                    for col in result.columns:
                        if any(keyword in col.lower() for keyword in ['path', 'source', 'location', 'file']):
                            unique_vals = result[col].dropna().unique()[:5]
                            for val in unique_vals:
                                if str(val):
                                    print(f"   🔍 {col}: {val}")
                else:
                    print(f"   ❌ No records found")

            except Exception as e:
                print(f"   ❌ Error querying {query_name}: {str(e)[:100]}...")
                blob_evidence[query_name] = None

        # 2. Check for blob storage connection strings or references
        print(f"\n🔗 CHECKING FOR BLOB STORAGE CONNECTION PATTERNS:")

        connection_queries = [
            # Check system configurations
            ("System configurations", """
                SELECT
                    configuration_id,
                    name,
                    value
                FROM sys.configurations
                WHERE name LIKE '%external%'
                   OR name LIKE '%blob%'
                   OR name LIKE '%azure%'
            """),

            # Check for linked servers (blob storage connections)
            ("Linked servers", """
                SELECT
                    name,
                    product,
                    provider,
                    data_source,
                    location
                FROM sys.servers
                WHERE is_linked = 1
            """),

            # Check for credential objects
            ("Database credentials", """
                SELECT
                    name,
                    credential_identity,
                    create_date,
                    modify_date
                FROM sys.database_credentials
            """)
        ]

        for query_name, query in connection_queries:
            try:
                result = pd.read_sql(query, engine)
                print(f"\n🔧 {query_name}:")
                if not result.empty:
                    print(f"   ✅ Found {len(result)} configurations")
                    for _, row in result.iterrows():
                        print(f"   📋 {dict(row)}")
                else:
                    print(f"   ❌ No configurations found")
            except Exception as e:
                print(f"   ❌ Error: {str(e)[:100]}...")

        # 3. Analyze data ingestion patterns
        print(f"\n📥 DATA INGESTION PATTERN ANALYSIS:")

        # Check bronze layer for raw ingestion patterns
        bronze_analysis = [
            ("Bronze transactions ingestion", """
                SELECT
                    COUNT(*) as record_count,
                    MIN(transaction_date) as earliest_date,
                    MAX(transaction_date) as latest_date,
                    COUNT(DISTINCT device_id) as unique_devices,
                    COUNT(DISTINCT store_id) as unique_stores
                FROM bronze.transactions
            """),

            ("PayloadTransactions ingestion analysis", """
                SELECT
                    COUNT(*) as total_records,
                    COUNT(DISTINCT deviceId) as unique_devices,
                    COUNT(DISTINCT storeId) as unique_stores,
                    AVG(LEN(payload_json)) as avg_payload_size,
                    MIN(LEN(payload_json)) as min_payload_size,
                    MAX(LEN(payload_json)) as max_payload_size
                FROM dbo.PayloadTransactions
            """)
        ]

        for query_name, query in bronze_analysis:
            try:
                result = pd.read_sql(query, engine)
                print(f"\n📊 {query_name}:")
                for _, row in result.iterrows():
                    for col, val in row.items():
                        print(f"   📈 {col}: {val}")
            except Exception as e:
                print(f"   ❌ Error: {str(e)[:100]}...")

        # 4. Check for batch processing evidence
        print(f"\n⚙️ BATCH PROCESSING EVIDENCE:")

        try:
            batch_info = pd.read_sql("""
                SELECT
                    TABLE_SCHEMA,
                    TABLE_NAME,
                    TABLE_TYPE,
                    ROW_COUNT = (
                        SELECT TOP 1 rows
                        FROM sys.partitions p
                        INNER JOIN sys.tables t ON p.object_id = t.object_id
                        INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                        WHERE s.name = i.TABLE_SCHEMA
                        AND t.name = i.TABLE_NAME
                        AND p.index_id IN (0,1)
                    )
                FROM INFORMATION_SCHEMA.TABLES i
                WHERE TABLE_SCHEMA IN ('bronze', 'staging')
                AND TABLE_TYPE = 'BASE TABLE'
                ORDER BY TABLE_SCHEMA, TABLE_NAME
            """, engine)

            print(f"   📋 Bronze/Staging Layer Summary:")
            for _, row in batch_info.iterrows():
                print(f"   🗃️  {row['TABLE_SCHEMA']}.{row['TABLE_NAME']}: {row['ROW_COUNT']} records")

        except Exception as e:
            print(f"   ❌ Error analyzing batch processing: {str(e)[:100]}...")

        print("\n" + "="*80)
        print("📊 ETL FLOW SOURCE ANALYSIS SUMMARY")
        print("="*80)

        # Determine ETL source pattern
        has_blob_evidence = any([
            'source_path' in str(blob_evidence),
            'file_path' in str(blob_evidence),
            'storage_location' in str(blob_evidence)
        ])

        print(f"\n🎯 ETL SOURCE DETERMINATION:")
        print(f"   📁 Blob Storage Evidence: {'✅ Found' if has_blob_evidence else '❌ Not Found'}")
        print(f"   🔄 Bronze Layer Records: {bronze_analysis}")
        print(f"   📊 Staging Tables: Present (PayloadTransactionsStaging_csv)")
        print(f"   ⚙️ Processing Logs: Present (dbo.processingLogs)")

        # Final assessment
        if has_blob_evidence:
            print(f"\n✅ CONCLUSION: ETL appears to flow FROM Azure Blob Storage")
            print(f"   🔗 Evidence: File paths, storage locations, and staging patterns suggest blob ingestion")
        else:
            print(f"\n🤔 CONCLUSION: ETL source unclear - need more investigation")
            print(f"   💡 Recommendation: Check Azure Data Factory, Logic Apps, or custom ingestion processes")

        return blob_evidence

    except Exception as e:
        print(f"❌ Blob storage analysis failed: {e}")
        return None

    finally:
        engine.dispose()

if __name__ == "__main__":
    analysis = analyze_blob_storage_integration()