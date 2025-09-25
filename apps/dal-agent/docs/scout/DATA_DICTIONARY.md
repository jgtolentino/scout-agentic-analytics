# Scout Analytics Platform - Flat Export Data Dictionary

**Version**: 1.0
**View**: `dbo.v_flat_export_sheet`
**Database**: SQL-TBWA-ProjectScout-Reporting-Prod
**Updated**: September 2025

---

## Overview

This data dictionary documents the **Scout Analytics Flat Export View**, a production-ready dataframe that provides a flattened, merged, and enriched view of Scout transaction data. The view contains exactly **12 columns** in a fixed order, designed for analytics, reporting, and data science workflows.

### Key Features
- **Zero Row Drop**: Uses LEFT JOINs exclusively to preserve all base transactions
- **Fixed Schema**: Exactly 12 columns in specified order for consistent exports
- **Enriched Data**: Combines transaction, demographic, and behavioral data
- **Production Safe**: Includes comprehensive validation gates and error handling
- **Analytics Ready**: Optimized for market basket analysis, customer segmentation, and business intelligence

---

## Column Specifications

| # | Column Name | Data Type | Nullable | Description |
|---|-------------|-----------|----------|-------------|
| 1 | [Transaction_ID](#1-transaction_id) | varchar(64) | No | Canonical transaction identifier |
| 2 | [Transaction_Value](#2-transaction_value) | decimal(18,2) | Yes | Total transaction amount (currency) |
| 3 | [Basket_Size](#3-basket_size) | int | Yes | Number of items in transaction |
| 4 | [Category](#4-category) | varchar | Yes | Primary product category |
| 5 | [Brand](#5-brand) | varchar | Yes | Primary product brand |
| 6 | [Daypart](#6-daypart) | varchar | Yes | Time period of transaction |
| 7 | [Demographics (Age/Gender/Role)](#7-demographics-agegenderrole) | varchar | Yes | Concatenated customer demographics |
| 8 | [Weekday_vs_Weekend](#8-weekday_vs_weekend) | varchar | Yes | Day type classification |
| 9 | [Time of transaction](#9-time-of-transaction) | varchar | Yes | Formatted transaction hour |
| 10 | [Location](#10-location) | varchar | Yes | Store or geographic location |
| 11 | [Other_Products](#11-other_products) | varchar | Yes | Co-purchased products (excluding primary) |
| 12 | [Was_Substitution](#12-was_substitution) | varchar | Yes | Product substitution indicator |

---

## Column Details

### 1. Transaction_ID
- **Type**: `varchar(64)`
- **Source**: `dbo.v_transactions_flat_production.canonical_tx_id`
- **Description**: Unique identifier for each transaction across all Scout systems
- **Usage**: Primary key for joining with other Scout tables and views
- **Allowed Values**: Alphanumeric string, typically 32-64 characters
- **Data Quality**: Required field, should never be null
- **Example**: `TX_20250925_ABC123DEF456`

### 2. Transaction_Value
- **Type**: `decimal(18,2)`
- **Source**: `dbo.v_transactions_flat_production.total_amount`
- **Description**: Total monetary value of the transaction in local currency
- **Usage**: Revenue analysis, transaction size segmentation, financial reporting
- **Allowed Values**: Positive decimal values (currency format)
- **Data Quality**: Core business metric, should be populated for completed transactions
- **Example**: `125.75`, `89.00`, `1245.50`

### 3. Basket_Size
- **Type**: `int`
- **Source**: `dbo.v_transactions_flat_production.total_items`
- **Description**: Count of distinct items purchased in the transaction
- **Usage**: Market basket analysis, customer behavior insights, cross-selling analysis
- **Allowed Values**: Positive integers (1 or greater for valid transactions)
- **Data Quality**: Important for behavioral analysis, should align with item-level data
- **Example**: `1`, `3`, `7`, `12`

### 4. Category
- **Type**: `varchar`
- **Source**: `dbo.v_transactions_flat_production.category`
- **Description**: Primary product category for the transaction (Nielsen/Kantar aligned)
- **Usage**: Category performance analysis, product mix insights, competitive analysis
- **Allowed Values**: Standardized category names, may be empty for unclassified items
- **Data Quality**: High priority for business analysis, ~85-90% completion expected
- **Example**: `"Beverages"`, `"Snacks"`, `"Personal Care"`, `"Instant Noodles"`

### 5. Brand
- **Type**: `varchar`
- **Source**: `dbo.v_transactions_flat_production.brand`
- **Description**: Primary brand name for the transaction (Nielsen/Kantar aligned)
- **Usage**: Brand performance analysis, market share calculation, competitive intelligence
- **Allowed Values**: Standardized brand names, may be empty for unrecognized brands
- **Data Quality**: High priority for business analysis, ~80-85% completion expected
- **Example**: `"Coca-Cola"`, `"Lucky Me!"`, `"Nestle"`, `"Unilever"`

### 6. Daypart
- **Type**: `varchar`
- **Source**: `dbo.v_transactions_flat_production.daypart`
- **Description**: Time period classification derived from transaction timestamp
- **Usage**: Temporal analysis, peak hour identification, staffing optimization
- **Allowed Values**: `"Morning"`, `"Afternoon"`, `"Evening"`, `"Night"`, or empty
- **Data Quality**: Derived field, completion depends on timestamp availability
- **Example**: `"Morning"`, `"Afternoon"`, `"Evening"`

### 7. Demographics (Age/Gender/Role)
- **Type**: `varchar`
- **Source**: `dbo.SalesInteractions` (concatenated: `age_bracket + gender + customer_type`)
- **Description**: Customer demographic information as space-separated string
- **Usage**: Customer segmentation, demographic analysis, targeted marketing
- **Allowed Values**: Space-separated combination of age bracket, gender, and customer type
- **Data Quality**: Optional field, ~40-60% completion expected based on data collection
- **Example**: `"25-34 Male Regular"`, `"45-54 Female Premium"`, `"18-24 Male"`, `""`

### 8. Weekday_vs_Weekend
- **Type**: `varchar`
- **Source**: `dbo.v_transactions_flat_production.weekday_weekend`
- **Description**: Classification of transaction day as weekday or weekend
- **Usage**: Temporal pattern analysis, day-of-week behavior, promotional planning
- **Allowed Values**: `"Weekday"`, `"Weekend"`, or empty
- **Data Quality**: Derived field, should have high completion rate
- **Example**: `"Weekday"`, `"Weekend"`

### 9. Time of transaction
- **Type**: `varchar`
- **Source**: `FORMAT(dbo.v_transactions_flat_production.txn_ts, 'htt', 'en-US')`
- **Description**: Formatted hour of transaction in 12-hour format with AM/PM
- **Usage**: Hourly traffic analysis, peak hour identification, operational planning
- **Allowed Values**: 12-hour format (e.g., `"2PM"`, `"8AM"`, `"11PM"`)
- **Data Quality**: Formatted field with en-US locale for consistency
- **Example**: `"8AM"`, `"2PM"`, `"11PM"`, `"12AM"`

### 10. Location
- **Type**: `varchar`
- **Source**: `dbo.v_transactions_flat_production.store_name`
- **Description**: Store name or geographic location where transaction occurred
- **Usage**: Geographic analysis, store performance comparison, regional insights
- **Allowed Values**: Store names, city names, or geographic identifiers
- **Data Quality**: Important for geographic analysis, should have high completion
- **Example**: `"SM Mall of Asia"`, `"Makati CBD"`, `"Quezon City"`

### 11. Other_Products
- **Type**: `varchar`
- **Source**: `STRING_AGG` from `dbo.TransactionItems` (excluding primary brand/category)
- **Description**: Comma-separated list of co-purchased products excluding the primary brand/category
- **Usage**: Market basket analysis, cross-selling opportunities, product association rules
- **Allowed Values**: Comma-separated product names/brands, empty if no co-purchases
- **Data Quality**: Complex derived field, empty for single-item transactions
- **Example**: `"Sprite, Pringles, Marlboro"`, `"Nescafe (Beverages), Skyflakes (Biscuits)"`, `""`

### 12. Was_Substitution
- **Type**: `varchar`
- **Source**: `dbo.v_insight_base.substitution_event` (mapped to true/false/empty)
- **Description**: Indicates whether product substitution occurred in the transaction
- **Usage**: Substitution analysis, brand switching behavior, out-of-stock impact
- **Allowed Values**: `"true"`, `"false"`, `""` (empty when substitution data unavailable)
- **Data Quality**: Advanced analytics field, lower completion rate expected
- **Example**: `"true"`, `"false"`, `""`

---

## Data Sources & Relationships

### Primary Tables/Views
- **`dbo.v_transactions_flat_production`**: Base transaction view (1:1 relationship)
- **`dbo.SalesInteractions`**: Customer demographic data (LEFT JOIN on `canonical_tx_id`)
- **`dbo.v_insight_base`**: Substitution and behavioral signals (LEFT JOIN on `canonical_tx_id`)
- **`dbo.TransactionItems`**: Item-level transaction details (1:many via `canonical_tx_id`)

### Join Strategy
- **Primary Key**: `canonical_tx_id` used across all sources
- **Join Type**: LEFT JOIN exclusively to ensure zero row drop
- **Data Preservation**: All base transactions preserved regardless of data availability in secondary sources

---

## Data Quality Guidelines

### Core Business Fields (High Priority)
- **Transaction_ID**: 100% completion required
- **Transaction_Value**: 95%+ for completed transactions
- **Category**: 85-90% completion target
- **Brand**: 80-85% completion target
- **Location**: 90%+ completion target

### Dimensional Fields (Medium Priority)
- **Demographics**: 40-60% completion (depends on collection)
- **Daypart/Time**: 90%+ completion (derived from timestamp)
- **Weekday_vs_Weekend**: 95%+ completion (derived)

### Advanced Analytics Fields (Lower Priority)
- **Other_Products**: Variable (empty for single-item transactions)
- **Was_Substitution**: 20-40% completion (advanced feature)

---

## Usage Examples

### Basic Analytics Query
```sql
-- Transaction summary by category
SELECT
    Category,
    COUNT(*) as transaction_count,
    AVG(Transaction_Value) as avg_value,
    AVG(Basket_Size) as avg_basket_size
FROM dbo.v_flat_export_sheet
WHERE Category IS NOT NULL AND Category != ''
GROUP BY Category
ORDER BY transaction_count DESC;
```

### Temporal Analysis
```sql
-- Peak hours analysis
SELECT
    [Time of transaction],
    Weekday_vs_Weekend,
    COUNT(*) as transaction_count,
    AVG(Transaction_Value) as avg_value
FROM dbo.v_flat_export_sheet
WHERE [Time of transaction] IS NOT NULL
GROUP BY [Time of transaction], Weekday_vs_Weekend
ORDER BY transaction_count DESC;
```

### Market Basket Analysis
```sql
-- Co-purchase analysis
SELECT
    Brand,
    Other_Products,
    COUNT(*) as frequency
FROM dbo.v_flat_export_sheet
WHERE Brand IS NOT NULL
    AND Other_Products IS NOT NULL
    AND Other_Products != ''
GROUP BY Brand, Other_Products
HAVING COUNT(*) >= 5
ORDER BY frequency DESC;
```

---

## Python Export Example

```python
import pandas as pd
import pyodbc

# Use the extraction script
python scripts/extract_flat_dataframe.py --out flat_dataframe.csv

# Or direct pandas usage
conn_str = "your_connection_string"
df = pd.read_sql("SELECT * FROM dbo.v_flat_export_sheet", pyodbc.connect(conn_str))
df.to_csv("flat_dataframe.csv", index=False)
```

---

## Bruno Workflow Execution

To execute the complete workflow securely using Bruno:

1. Set the `AZURE_SQL_CONN_STR` environment variable in your Bruno vault
2. Run the Bruno workflow: `bruno run bruno/flat_export.yml`

The workflow will:
1. Run preflight validation checks
2. Create/update the flat export view
3. Validate coverage and column contracts
4. Export codebook and coverage data to CSV
5. Extract the complete flat dataframe to CSV

---

## Performance Notes

- **Query Performance**: Optimized with recommended indexes on join columns
- **Export Size**: Typical exports range from 10K-1M+ rows depending on date range
- **Processing Time**: Full dataset export typically completes in 30-120 seconds
- **Resource Usage**: Moderate memory usage for large datasets, consider streaming for very large exports

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | September 2025 | Initial production release with 12-column specification |

---

**Generated by Scout Analytics Platform**
**Documentation Version**: 1.0
**Last Updated**: September 25, 2025