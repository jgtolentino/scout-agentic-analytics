-- ==========================================
-- Unified Validation Runner for Scout Edge Data
-- Compares Azure SQL vs Supabase PostgreSQL implementations
-- ==========================================

-- ===========================================
-- CROSS-PLATFORM VALIDATION FRAMEWORK
-- ===========================================

-- This script provides a unified framework for validating Scout Edge data
-- across both Azure SQL Server and Supabase PostgreSQL platforms.
-- It identifies platform-specific differences and ensures data consistency.

-- Usage Instructions:
-- 1. Run azure_validation_suite.sql on Azure SQL Server
-- 2. Run supabase_validation_suite.sql on Supabase PostgreSQL
-- 3. Use this script to compare results and identify discrepancies
-- 4. Export results for cross-platform analysis

-- ===========================================
-- PLATFORM DETECTION UTILITIES
-- ===========================================

-- Detect current platform (Azure SQL vs PostgreSQL)
-- This enables platform-specific validation logic

/*
-- Azure SQL Server Detection
SELECT
    'Azure SQL Server' as platform,
    @@VERSION as version_info,
    SERVERPROPERTY('ProductVersion') as product_version,
    SERVERPROPERTY('Edition') as edition
WHERE @@VERSION LIKE '%Azure%'

UNION ALL

-- PostgreSQL/Supabase Detection
SELECT
    'PostgreSQL/Supabase' as platform,
    version() as version_info,
    split_part(version(), ' ', 2) as product_version,
    CASE
        WHEN version() LIKE '%supabase%' THEN 'Supabase'
        ELSE 'Standard PostgreSQL'
    END as edition
WHERE version() LIKE '%PostgreSQL%';
*/

-- ===========================================
-- UNIFIED DATA QUALITY COMPARISON
-- ===========================================

-- Compare basic data metrics across platforms
-- Expected: Both platforms should have identical core metrics

/*
Cross-Platform Comparison Query Template:

-- Azure SQL Version:
SELECT
    'Azure SQL' as platform,
    COUNT(*) as total_transactions,
    COUNT(DISTINCT store_id) as unique_stores,
    COUNT(*) FILTER (WHERE substitution_detected = 1) as substitutions,
    AVG(CAST(total_amount AS DECIMAL(10,2))) as avg_transaction_value,
    MIN(transaction_timestamp) as earliest_transaction,
    MAX(transaction_timestamp) as latest_transaction
FROM fact_transactions_location;

-- PostgreSQL Version:
SELECT
    'PostgreSQL' as platform,
    COUNT(*) as total_transactions,
    COUNT(DISTINCT store_id) as unique_stores,
    COUNT(*) FILTER (WHERE substitution_detected = TRUE) as substitutions,
    AVG(total_amount) as avg_transaction_value,
    MIN(transaction_timestamp) as earliest_transaction,
    MAX(transaction_timestamp) as latest_transaction
FROM fact_transactions_location;
*/

-- ===========================================
-- PRIVACY COMPLIANCE COMPARISON
-- ===========================================

-- Validate privacy settings consistency across platforms
-- Critical: Scout Edge must maintain audio_stored = FALSE across all platforms

/*
-- Azure SQL Privacy Check:
SELECT
    'Azure SQL' as platform,
    COUNT(*) as total_records,
    COUNT(*) FILTER (WHERE audio_stored = 0) as audio_not_stored,
    COUNT(*) FILTER (WHERE facial_recognition = 0) as no_facial_recognition,
    COUNT(*) FILTER (WHERE anonymization_level = 'high') as high_anonymization,
    CAST(COUNT(*) FILTER (WHERE audio_stored = 0) AS DECIMAL(10,2)) / COUNT(*) * 100 as privacy_compliance_pct
FROM fact_transactions_location;

-- PostgreSQL Privacy Check:
SELECT
    'PostgreSQL' as platform,
    COUNT(*) as total_records,
    COUNT(*) FILTER (WHERE audio_stored = FALSE) as audio_not_stored,
    COUNT(*) FILTER (WHERE facial_recognition = FALSE) as no_facial_recognition,
    COUNT(*) FILTER (WHERE anonymization_level = 'high') as high_anonymization,
    ROUND((COUNT(*) FILTER (WHERE audio_stored = FALSE)::DECIMAL / COUNT(*)) * 100, 2) as privacy_compliance_pct
FROM fact_transactions_location;
*/

-- ===========================================
-- SUBSTITUTION DETECTION COMPARISON
-- ===========================================

-- Compare substitution detection logic across platforms
-- Expected: Identical substitution rates and reasoning

/*
-- Azure SQL Substitution Analysis:
SELECT
    'Azure SQL' as platform,
    substitution_reason,
    COUNT(*) as occurrence_count,
    AVG(CAST(brand_switching_score AS DECIMAL(5,2))) as avg_switching_score,
    CAST(COUNT(*) AS DECIMAL(10,2)) / SUM(COUNT(*)) OVER () * 100 as percentage
FROM fact_transactions_location
WHERE substitution_detected = 1
GROUP BY substitution_reason
ORDER BY occurrence_count DESC;

-- PostgreSQL Substitution Analysis:
SELECT
    'PostgreSQL' as platform,
    substitution_reason,
    COUNT(*) as occurrence_count,
    AVG(brand_switching_score) as avg_switching_score,
    ROUND((COUNT(*)::DECIMAL / SUM(COUNT(*)) OVER ()) * 100, 2) as percentage
FROM fact_transactions_location
WHERE substitution_detected = TRUE
GROUP BY substitution_reason
ORDER BY occurrence_count DESC;
*/

-- ===========================================
-- GEOGRAPHIC DATA CONSISTENCY
-- ===========================================

-- Validate NCR location mappings are identical across platforms
-- Critical: Store locations must be consistent for analytics

/*
-- Cross-Platform Store Location Validation:

-- Azure SQL Store Mapping:
SELECT
    'Azure SQL' as platform,
    store_id,
    municipality_name,
    province_name,
    region,
    latitude,
    longitude,
    COUNT(*) as transaction_count
FROM fact_transactions_location
GROUP BY store_id, municipality_name, province_name, region, latitude, longitude
ORDER BY store_id;

-- PostgreSQL Store Mapping:
SELECT
    'PostgreSQL' as platform,
    store_id,
    municipality_name,
    province_name,
    region,
    latitude,
    longitude,
    COUNT(*) as transaction_count
FROM fact_transactions_location
GROUP BY store_id, municipality_name, province_name, region, latitude, longitude
ORDER BY store_id;
*/

-- ===========================================
-- PERFORMANCE BENCHMARKING QUERIES
-- ===========================================

-- Standardized performance tests for cross-platform comparison
-- These queries should be executed with timing enabled

/*
-- Performance Test 1: Store Aggregation
-- Azure SQL:
SET STATISTICS TIME ON;
SELECT
    store_id,
    municipality_name,
    COUNT(*) as transactions,
    AVG(CAST(total_amount AS DECIMAL(10,2))) as avg_amount,
    COUNT(*) FILTER (WHERE substitution_detected = 1) as substitutions
FROM fact_transactions_location
GROUP BY store_id, municipality_name
ORDER BY transactions DESC;
SET STATISTICS TIME OFF;

-- PostgreSQL:
\timing on
SELECT
    store_id,
    municipality_name,
    COUNT(*) as transactions,
    AVG(total_amount) as avg_amount,
    COUNT(*) FILTER (WHERE substitution_detected = TRUE) as substitutions
FROM fact_transactions_location
GROUP BY store_id, municipality_name
ORDER BY transactions DESC;
\timing off
*/

/*
-- Performance Test 2: Substitution Analysis
-- Azure SQL:
SET STATISTICS TIME ON;
SELECT
    municipality_name,
    substitution_reason,
    COUNT(*) as events,
    AVG(CAST(brand_switching_score AS DECIMAL(5,2))) as avg_score
FROM fact_transactions_location
WHERE substitution_detected = 1
GROUP BY municipality_name, substitution_reason
ORDER BY municipality_name, events DESC;
SET STATISTICS TIME OFF;

-- PostgreSQL:
\timing on
SELECT
    municipality_name,
    substitution_reason,
    COUNT(*) as events,
    AVG(brand_switching_score) as avg_score
FROM fact_transactions_location
WHERE substitution_detected = TRUE
GROUP BY municipality_name, substitution_reason
ORDER BY municipality_name, events DESC;
\timing off
*/

-- ===========================================
-- DATA INTEGRITY CROSS-VALIDATION
-- ===========================================

-- Validate canonical transaction IDs are consistent
-- Critical: Same transaction should have same canonical ID on both platforms

/*
-- Sample Canonical ID Comparison:
-- Export first 100 transactions from each platform and compare

-- Azure SQL Sample:
SELECT TOP 100
    transaction_id,
    canonical_tx_id,
    store_id,
    device_id,
    total_amount,
    transaction_timestamp
FROM fact_transactions_location
ORDER BY transaction_timestamp;

-- PostgreSQL Sample:
SELECT
    transaction_id,
    canonical_tx_id,
    store_id,
    device_id,
    total_amount,
    transaction_timestamp
FROM fact_transactions_location
ORDER BY transaction_timestamp
LIMIT 100;
*/

-- ===========================================
-- VALIDATION SUMMARY COMPARISON
-- ===========================================

-- Compare overall validation scores between platforms
-- Expected: Both platforms should achieve >95% data quality score

/*
-- Azure SQL Summary (run azure_validation_suite.sql first):
SELECT 'Azure SQL Validation Summary' as platform_summary;
EXEC sp_quick_data_quality_check;

-- PostgreSQL Summary (run supabase_validation_suite.sql first):
SELECT 'PostgreSQL Validation Summary' as platform_summary;
SELECT * FROM quick_data_quality_check();
*/

-- ===========================================
-- PRIVACY MODEL COMPARISON
-- ===========================================

-- Scout Edge vs Azure SQL privacy philosophy comparison
-- This highlights the fundamental difference in approaches

/*
Scout Edge Privacy Model (Audio-Only):
- ✅ audio_stored = FALSE (100% compliance)
- ✅ facial_recognition = FALSE (100% compliance)
- ✅ anonymization_level = 'high' (100% compliance)
- ✅ GDPR Article 9 compliant (no biometric data)
- ✅ Privacy by design architecture

Azure SQL Privacy Model (Facial Recognition):
- ❌ facial_recognition = TRUE (100% facial tracking)
- ❌ emotional_state captured (GDPR Article 9 sensitive data)
- ❌ biometric_features stored (privacy risk)
- ⚠️ Requires explicit consent under GDPR
- ⚠️ Higher privacy risk profile

Key Insight:
Scout Edge provides privacy-compliant behavioral analytics
Azure SQL provides surveillance-grade emotional analytics
Both approaches are complementary but serve different use cases
*/

-- ===========================================
-- EXPORT TEMPLATES FOR COMPARISON
-- ===========================================

-- Templates for exporting data to CSV for cross-platform analysis

/*
-- Azure SQL Export Template:
bcp "SELECT 'Azure' as platform, store_id, municipality_name, COUNT(*) as transactions, AVG(CAST(total_amount AS DECIMAL(10,2))) as avg_amount FROM scout_edge.dbo.fact_transactions_location GROUP BY store_id, municipality_name ORDER BY store_id" queryout azure_summary.csv -c -t, -S your_server -d your_database -T

-- PostgreSQL Export Template:
\copy (SELECT 'PostgreSQL' as platform, store_id, municipality_name, COUNT(*) as transactions, AVG(total_amount) as avg_amount FROM fact_transactions_location GROUP BY store_id, municipality_name ORDER BY store_id) TO 'postgresql_summary.csv' WITH CSV HEADER;
*/

-- ===========================================
-- AUTOMATED COMPARISON SCRIPT
-- ===========================================

-- Python script template for automated comparison
/*
#!/usr/bin/env python3
"""
Cross-Platform Validation Comparison Tool
Compares Azure SQL vs PostgreSQL Scout Edge implementations
"""

import pandas as pd
import sqlalchemy as sa
from sqlalchemy import create_engine
import numpy as np

def compare_platforms():
    # Azure SQL Connection
    azure_engine = create_engine(
        f"mssql+pyodbc://{user}:{password}@{server}/{database}?driver=ODBC+Driver+17+for+SQL+Server"
    )

    # PostgreSQL Connection
    pg_engine = create_engine(
        f"postgresql://{user}:{password}@{host}:{port}/{database}"
    )

    # Comparison queries
    queries = {
        'basic_stats': '''
            SELECT
                COUNT(*) as total_transactions,
                COUNT(DISTINCT store_id) as unique_stores,
                AVG(total_amount) as avg_amount
            FROM fact_transactions_location
        ''',
        'substitution_stats': '''
            SELECT
                COUNT(*) FILTER (WHERE substitution_detected = TRUE) as substitutions,
                COUNT(*) as total
            FROM fact_transactions_location
        '''
    }

    results = {}
    for query_name, sql in queries.items():
        results[query_name] = {
            'azure': pd.read_sql(sql.replace('TRUE', '1').replace('FALSE', '0'), azure_engine),
            'postgresql': pd.read_sql(sql, pg_engine)
        }

    # Compare results
    for query_name, data in results.items():
        print(f"\n{query_name.upper()} COMPARISON:")
        print("Azure SQL:", data['azure'].to_dict('records')[0])
        print("PostgreSQL:", data['postgresql'].to_dict('records')[0])

        # Calculate differences
        azure_vals = data['azure'].iloc[0]
        pg_vals = data['postgresql'].iloc[0]

        for col in azure_vals.index:
            if pd.api.types.is_numeric_dtype(azure_vals[col]):
                diff = abs(azure_vals[col] - pg_vals[col])
                pct_diff = (diff / azure_vals[col]) * 100 if azure_vals[col] != 0 else 0
                print(f"  {col}: {diff:.2f} difference ({pct_diff:.2f}%)")

if __name__ == "__main__":
    compare_platforms()
*/

-- ===========================================
-- VALIDATION CHECKLIST
-- ===========================================

/*
Cross-Platform Validation Checklist:

□ Data Completeness
  □ Same number of transactions (13,149 expected)
  □ Same number of stores (7 expected: 102,103,104,108,109,110,112)
  □ Same date range coverage

□ Data Integrity
  □ Canonical transaction IDs match for same transactions
  □ No duplicate records on either platform
  □ All monetary amounts > 0

□ Privacy Compliance
  □ audio_stored = FALSE on both platforms
  □ facial_recognition = FALSE on both platforms
  □ anonymization_level = 'high' on both platforms

□ Geographic Consistency
  □ All stores mapped to correct NCR municipalities
  □ Latitude/longitude coordinates identical
  □ Province = 'Metro Manila', Region = 'NCR'

□ Substitution Logic
  □ Same substitution detection rate (~18%)
  □ Identical substitution reasons for same transactions
  □ Brand switching scores consistent

□ Performance
  □ Query response times documented
  □ Index usage optimized on both platforms
  □ Resource utilization acceptable

□ Schema Compatibility
  □ Data types functionally equivalent
  □ Constraints and indexes similar
  □ Functions produce same results

Success Criteria:
- <1% variance in numeric metrics
- 100% privacy compliance both platforms
- 0 schema compatibility issues
- Query performance within 2x of each other
*/

-- ===========================================
-- MIGRATION VALIDATION
-- ===========================================

-- Validate that data can be migrated between platforms without loss

/*
Migration Validation Process:

1. Export representative sample from Azure SQL
2. Import to PostgreSQL test instance
3. Run validation suite on both
4. Compare results for discrepancies
5. Document any data transformation requirements

Key Migration Considerations:
- Boolean: BIT (Azure) → BOOLEAN (PostgreSQL)
- Timestamps: DATETIMEOFFSET (Azure) → TIMESTAMPTZ (PostgreSQL)
- UUIDs: UNIQUEIDENTIFIER (Azure) → UUID (PostgreSQL)
- Strings: NVARCHAR (Azure) → TEXT (PostgreSQL)
- Decimals: DECIMAL (Azure) → NUMERIC (PostgreSQL)

Expected Migration Success Rate: >99.9%
Acceptable Data Loss: <0.1%
*/

-- ===========================================
-- REPORTING TEMPLATES
-- ===========================================

-- Templates for generating comparison reports

/*
Executive Summary Template:

SCOUT EDGE DATA VALIDATION - AZURE SQL VS POSTGRESQL COMPARISON

Date: {current_date}
Platforms Tested: Azure SQL Server, Supabase PostgreSQL
Data Volume: 13,149 transactions, 7 stores
Validation Scope: Data quality, privacy, performance

KEY FINDINGS:
✅ Data Completeness: {completeness_score}% match
✅ Privacy Compliance: {privacy_score}% compliance both platforms
✅ Geographic Accuracy: {geographic_score}% location data match
✅ Substitution Logic: {substitution_score}% detection consistency
⚡ Performance: Azure {azure_time}ms avg, PostgreSQL {pg_time}ms avg

PRIVACY MODEL COMPARISON:
Scout Edge: Audio-only, privacy-by-design (GDPR compliant)
Azure SQL: Facial recognition, emotional tracking (consent required)

RECOMMENDATION:
Both platforms suitable for production with 99%+ data quality score.
Scout Edge recommended for privacy-sensitive deployments.
Azure SQL provides enhanced emotional analytics capabilities.

Technical Validation: {validation_date}
Next Review: {next_review_date}
*/

-- END OF UNIFIED VALIDATION FRAMEWORK