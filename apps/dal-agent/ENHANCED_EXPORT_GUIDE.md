# Enhanced Canonical Export with Brand Switching & Co-Purchase Analysis

**Advanced analytics export featuring brand switching patterns and frequently sold together analysis**

## 🚀 New Enhanced One-Liner

```bash
./scripts/sql.sh -Q "EXEC canonical.sp_export_enhanced @DateFrom='2025-09-01', @DateTo='2025-09-23'" > export_enhanced.csv
```

## 📊 Enhanced Export Schema (18 Columns)

### Core Transaction Data (10 columns)
1. `canonical_tx_id` - Unique transaction identifier
2. `transaction_date` - Date from DimDate join
3. `amount` - Transaction value (decimal)
4. `basket_size` - Items in basket
5. `store_id` - Store identifier
6. `age` - Customer age
7. `gender` - Customer gender
8. `weekday_vs_weekend` - Weekday/Weekend classification
9. `day_name` - Day of week (Monday, Tuesday, etc.)
10. `substitution_flag` - Whether substitution occurred (0/1)

### Brand Switching Analysis (4 columns)
11. `primary_brand` - Highest confidence brand mentioned
12. `secondary_brand` - Second highest confidence brand (switching candidate)
13. `primary_brand_confidence` - Confidence score (0.0-1.0)
14. `all_brands_mentioned` - All brands with confidence >0.5 (semicolon-separated)

### Transaction Pattern Analysis (3 columns)
15. `transaction_type` - "Single-Item" or "Multi-Item"
16. `brand_switching_indicator` - "Single-Brand" or "Brand-Switch-Considered"
17. `copurchase_patterns` - Detected purchase patterns for multi-item transactions

### Export Metadata (1 column)
18. `export_timestamp` - Export generation time

## 🔄 Brand Switching Analysis Features

### Primary vs Secondary Brand Detection
- **Primary Brand**: Highest confidence brand mentioned in transaction
- **Secondary Brand**: Second highest confidence brand (indicates consideration/switching)
- **Confidence Scores**: ML-based confidence levels for brand detection

### Brand Switching Indicators
- **Single-Brand**: Only one brand mentioned above confidence threshold
- **Brand-Switch-Considered**: Multiple brands mentioned (customer comparing options)

### Example Brand Switching Transaction
```csv
test123,2025-05-06,0.00,1,1,NULL,NULL,Weekday,Tuesday,0,Nike,Adidas,0.95,Nike;Adidas,Single-Item,Brand-Switch-Considered,NULL,2025-09-26T18:17:17
```
**Analysis**: Customer considered both Nike (95% confidence) and Adidas (88% confidence) - indicates brand switching behavior.

## 🛒 Co-Purchase Analysis Features

### Multi-Item Transaction Analysis
- **Transaction Type**: Automatically classifies single vs multi-item purchases
- **Co-Purchase Patterns**: Detects common product combinations
- **Brand Combinations**: All brands mentioned in multi-item transactions

### Pattern Detection Examples
- **Beverage+Snack**: Coca-Cola products with snack items
- **Personal-Care-Bundle**: Shampoo with soap purchases
- **Other-Combination**: Custom detected patterns

### Frequently Sold Together Analysis
Use the separate analytics query for detailed co-purchase insights:
```bash
./scripts/sql.sh -Q "
DECLARE @DateFrom DATE = '2025-09-01';
DECLARE @DateTo DATE = '2025-09-23';
$(cat sql/analytics/brand_switching_copurchase_analysis.sql)
" > brand_analytics_report.csv
```

## 📈 Analytics Use Cases

### 1. Brand Switching Detection
```sql
-- Find customers considering brand switches
SELECT primary_brand, secondary_brand, COUNT(*) as switch_instances
FROM export_enhanced
WHERE brand_switching_indicator = 'Brand-Switch-Considered'
GROUP BY primary_brand, secondary_brand
ORDER BY switch_instances DESC;
```

### 2. Co-Purchase Pattern Analysis
```sql
-- Analyze multi-item transaction patterns
SELECT copurchase_patterns, COUNT(*) as frequency
FROM export_enhanced
WHERE transaction_type = 'Multi-Item'
AND copurchase_patterns IS NOT NULL
GROUP BY copurchase_patterns
ORDER BY frequency DESC;
```

### 3. Brand Confidence Analysis
```sql
-- Analyze brand detection confidence
SELECT
    primary_brand,
    AVG(primary_brand_confidence) as avg_confidence,
    COUNT(*) as mentions
FROM export_enhanced
WHERE primary_brand IS NOT NULL
GROUP BY primary_brand
ORDER BY avg_confidence DESC;
```

## 🎯 Quick Validation Commands

### Check Enhanced Features
```bash
# Count brand switching instances
grep "Brand-Switch-Considered" export_enhanced.csv | wc -l

# Count multi-item transactions
grep "Multi-Item" export_enhanced.csv | wc -l

# Show sample brand switching data
grep "Brand-Switch-Considered" export_enhanced.csv | head -5
```

### Verify Data Quality
```bash
# Check column count (should be 18)
head -1 export_enhanced.csv | tr ',' '\n' | wc -l

# Check for brand data
grep -v "NULL,NULL,NULL,NULL" export_enhanced.csv | wc -l

# Sample high-confidence brand detections
awk -F',' '$13 > 0.8 {print}' export_enhanced.csv | head -5
```

## 📊 Expected Results

### Sample Enhanced Export
```csv
canonical_tx_id,transaction_date,amount,basket_size,store_id,age,gender,weekday_vs_weekend,day_name,substitution_flag,primary_brand,secondary_brand,primary_brand_confidence,all_brands_mentioned,transaction_type,brand_switching_indicator,copurchase_patterns,export_timestamp
test123,2025-05-06,0.00,1,1,NULL,NULL,Weekday,Tuesday,0,Nike,Adidas,0.95,Nike;Adidas,Single-Item,Brand-Switch-Considered,NULL,2025-09-26T18:17:17
```

### Performance Metrics
- **File Size**: ~2MB for date range (vs 836KB basic export)
- **Processing Time**: ~45 seconds (vs 30 seconds basic export)
- **Brand Coverage**: Depends on available SalesInteractionBrands data
- **Pattern Detection**: Automatic identification of switching and co-purchase behaviors

## 🔧 Advanced Usage

### Custom Brand Analysis Period
```bash
# Last 7 days with enhanced analytics
DATE_FROM=$(date -d '7 days ago' +%Y-%m-%d)
DATE_TO=$(date +%Y-%m-%d)
./scripts/sql.sh -Q "EXEC canonical.sp_export_enhanced @DateFrom='$DATE_FROM', @DateTo='$DATE_TO'" > enhanced_last7days.csv
```

### Combined Basic + Enhanced Export
```bash
# Generate both exports for comparison
./scripts/sql.sh -Q "EXEC canonical.sp_export_flat @DateFrom='2025-09-01', @DateTo='2025-09-23'" > basic_export.csv
./scripts/sql.sh -Q "EXEC canonical.sp_export_enhanced @DateFrom='2025-09-01', @DateTo='2025-09-23'" > enhanced_export.csv

echo "Basic export: $(wc -l < basic_export.csv) rows, $(du -h basic_export.csv | cut -f1)"
echo "Enhanced export: $(wc -l < enhanced_export.csv) rows, $(du -h enhanced_export.csv | cut -f1)"
```

### Brand Analytics Deep Dive
```bash
# Generate comprehensive brand analytics report
./scripts/sql.sh -i sql/analytics/brand_switching_copurchase_analysis.sql \
  -v DATE_FROM='2025-09-01' -v DATE_TO='2025-09-23' \
  > brand_analytics_comprehensive.csv
```

---

**💡 Pro Tip**: The enhanced export provides deep insights into customer brand preferences and purchasing patterns. Use the basic export for operational reporting and the enhanced export for marketing analytics and customer behavior analysis.