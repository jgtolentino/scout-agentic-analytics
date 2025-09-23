# Scout Analytics Power BI Template

## Overview
This Power BI template provides comprehensive analytics dashboards for Scout transaction data with both flat dataframe views and cross-tabulated analysis.

## Features

### 📊 Dashboard Pages

1. **Transaction Details (Flat Dataframe)**
   - Detailed transaction-level data
   - Interactive filtering by date, store, category, payment method
   - Summary cards for key metrics
   - Export capabilities for CSV/Excel

2. **Cross-tab Analytics**
   - Daypart × Category matrix
   - Brand performance by time periods
   - Store × Hour heatmap
   - Payment method distribution

3. **Customer Demographics**
   - Age bracket × Brand preferences
   - Gender distribution analysis
   - Hourly shopping patterns by gender
   - Demographics summary table

4. **Store Performance**
   - Geographic store map with performance indicators
   - Revenue waterfall by store
   - Performance gauge
   - Store KPI comparison table

### 🔗 Data Sources

**Primary:** PostgreSQL (Supabase)
- Server: `aws-0-ap-southeast-1.pooler.supabase.com:6543`
- Database: `postgres`
- Schema: `public`
- Main Table: `scout_gold_transactions_flat`

**Secondary:** Azure SQL (Fallback)
- Server: `sql-tbwa-projectscout-reporting-prod.database.windows.net`
- Database: `SQL-TBWA-ProjectScout-Reporting-Prod`
- User: `scout_reader`

### 📈 Key Measures

- **Total Transactions**: Count of all transactions
- **Total Revenue**: Sum of transaction amounts (₱)
- **Average Transaction**: Mean transaction value
- **Unique Stores**: Distinct store count
- **Unique Products**: Distinct product count
- **Performance Score**: Composite KPI (0-100)
- **Growth Rate**: Period-over-period growth %

## Setup Instructions

### 1. Power BI Desktop Setup

1. Download and install Power BI Desktop
2. Open Power BI Desktop
3. Go to **File** → **Import** → **Power BI Template**
4. Select `scout_analytics_template.json`

### 2. Data Source Configuration

#### PostgreSQL Connection
1. In Power BI Desktop, go to **Home** → **Get Data** → **PostgreSQL database**
2. Enter connection details:
   ```
   Server: aws-0-ap-southeast-1.pooler.supabase.com
   Port: 6543
   Database: postgres
   ```
3. Authentication: **Database**
   - Username: `postgres.cxzllzyxwpyptfretryc`
   - Password: `Postgres_26`

#### Azure SQL Connection (Fallback)
1. Go to **Home** → **Get Data** → **Azure SQL database**
2. Enter connection details:
   ```
   Server: sql-tbwa-projectscout-reporting-prod.database.windows.net
   Database: SQL-TBWA-ProjectScout-Reporting-Prod
   ```
3. Authentication: **Database**
   - Username: `scout_reader`
   - Password: `Scout_Analytics_2025!`

### 3. Table Selection

Select these tables/views:
- ✅ `public.scout_gold_transactions_flat`
- ✅ `analytics.v_transactions_crosstab` (if available)
- ✅ `dbo.Stores`

### 4. Data Model Setup

The template will automatically:
- Create relationships between tables
- Set up calculated measures
- Configure filters and slicers
- Apply Scout theme and formatting

### 5. Refresh Configuration

1. Go to **Home** → **Transform data** → **Data source settings**
2. Set up refresh schedule:
   - **Frequency**: Daily at 6:00 AM (Asia/Manila)
   - **Incremental refresh**: Last 30 days
   - **Historical data**: 2 years

## Usage Guide

### 🎯 Key Filters

**Global Filters (Apply to all pages):**
- **Date Range**: Select analysis period
- **Store Selection**: Choose specific stores
- **Location Filter**: NCR bounds (auto-applied)

**Page-Specific Filters:**
- **Categories**: Product category selection
- **Payment Methods**: Filter by payment type
- **Demographics**: Age/gender filters
- **Time Periods**: Daypart/hour selection

### 📊 Interactive Features

1. **Cross-Filtering**: Click on any visual to filter others
2. **Drill-Down**: Right-click on categories to drill into details
3. **Export Data**: Click "..." on any visual to export data
4. **Tooltips**: Hover for additional context and metrics

### 🔍 Analysis Patterns

**Time-Based Analysis:**
- Peak hours identification
- Daypart performance patterns
- Day-of-week trends
- Seasonal variations

**Customer Segmentation:**
- Age bracket preferences
- Gender shopping patterns
- Payment method correlations
- Basket size analysis

**Store Performance:**
- Revenue comparison
- Transaction volume ranking
- Geographic performance mapping
- Category mix analysis

## Troubleshooting

### Connection Issues

**PostgreSQL Connection Failed:**
1. Check network connectivity
2. Verify credentials in environment
3. Ensure Supabase is accessible
4. Fall back to Azure SQL connection

**Azure SQL Connection Failed:**
1. Verify `scout_reader` user exists
2. Check password in Bruno vault
3. Confirm security group access
4. Test connection from Azure Data Studio

### Data Issues

**No Data Visible:**
1. Check date filter range
2. Verify NCR location filter
3. Confirm table permissions
4. Refresh data source

**Performance Issues:**
1. Reduce date range for testing
2. Limit visual row counts
3. Enable query caching
4. Use DirectQuery for large datasets

### Visual Issues

**Incorrect Formatting:**
1. Check regional settings (Philippines)
2. Verify currency format (PHP)
3. Confirm timezone (Asia/Manila)
4. Reset theme if needed

## Customization

### Adding New Visuals

1. Go to **Visualizations** pane
2. Select desired chart type
3. Drag fields from **Fields** pane
4. Configure formatting and filters

### Creating Custom Measures

1. Go to **Modeling** → **New measure**
2. Use DAX syntax for calculations
3. Example measures:
   ```dax
   Weekly Growth =
   VAR CurrentWeek = [Total Revenue]
   VAR LastWeek = CALCULATE([Total Revenue], DATEADD('Date'[Date], -7, DAY))
   RETURN DIVIDE(CurrentWeek - LastWeek, LastWeek, 0)

   Top Categories =
   CALCULATE([Total Transactions],
             TOPN(5, VALUES(scout_gold_transactions_flat[category]), [Total Transactions]))
   ```

### Theme Customization

1. Go to **View** → **Themes** → **Browse for themes**
2. Modify Scout color palette:
   - Primary: `#0078D4` (Scout Blue)
   - Secondary: `#005A9F` (Dark Blue)
   - Accent: `#40E0D0` (Turquoise)
   - Success: `#107C10` (Green)

## Integration with RAG-CAG

This Power BI template integrates with the RAG-CAG analytics system:

1. **Template Alignment**: Charts use same SQL templates as RAG-CAG
2. **Parameter Mapping**: Filters match RAG-CAG query parameters
3. **Validation**: Same data quality checks applied
4. **Evidence Trail**: Matching metrics and calculations

## Support

For technical support:
1. Check connection status in Power BI
2. Verify data source health using `system_health.sql`
3. Review Bruno execution logs
4. Contact analytics team for template updates

## Version History

- **v1.0** (2025-09-22): Initial template with 4 dashboard pages
- **Future**: Planned features include predictive analytics, real-time streaming, and mobile optimization