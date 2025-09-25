#!/usr/bin/env bash
set -euo pipefail
DB="${DB:?Set DB}"
ROOT="out/inquiries"
mkdir -p "$ROOT/overall" "$ROOT/tobacco" "$ROOT/laundry"

sql(){ ./scripts/sql.sh -d "$DB" -Q "$1" -o "$2"; }

echo "📊 Exporting Overall demographics and sales patterns..."
# Overall - Store profiles
sql "SELECT Store_ID,Store_Name,Location_Region,Location_Province,Location_City,COUNT(*) AS Transactions,SUM(Transaction_Value) AS GMV,AVG(Basket_Size) AS Avg_Basket_Size FROM dbo.v_transactions_flat_production GROUP BY Store_ID,Store_Name,Location_Region,Location_Province,Location_City ORDER BY GMV DESC;" "$ROOT/overall/store_profiles.csv"

# Overall - Demographics
sql "SELECT Gender,Age_Bracket,Customer_Type,COUNT(*) AS Transactions,SUM(Transaction_Value) AS GMV,AVG(Basket_Size) AS Avg_Basket FROM dbo.v_transactions_flat_production GROUP BY Gender,Age_Bracket,Customer_Type ORDER BY Transactions DESC;" "$ROOT/overall/demographics.csv"

# Overall - Sales by weekday
sql "SELECT DATENAME(weekday,Txn_Timestamp) AS Weekday,COUNT(*) AS Txns,SUM(Transaction_Value) AS GMV FROM dbo.v_transactions_flat_production GROUP BY DATENAME(weekday,Txn_Timestamp) ORDER BY (DATEPART(weekday,MIN(Txn_Timestamp)));" "$ROOT/overall/sales_by_weekday.csv"

# Overall - Sales by month day
sql "SELECT FORMAT(Txn_Timestamp,'yyyy-MM') AS YearMonth,DAY(Txn_Timestamp) AS DayOfMonth,COUNT(*) AS Txns,SUM(Transaction_Value) AS GMV FROM dbo.v_transactions_flat_production GROUP BY FORMAT(Txn_Timestamp,'yyyy-MM'),DAY(Txn_Timestamp) ORDER BY YearMonth,DayOfMonth;" "$ROOT/overall/sales_by_monthday.csv"

# Overall - Daypart x Category crosstab
sql "SELECT * FROM dbo.v_xtab_time_category_abs ORDER BY Daypart,Category;" "$ROOT/overall/daypart_x_category.csv"

echo "🚬 Exporting Tobacco analytics..."
# Tobacco - Demographics (gender x age x brand)
sql "SELECT Gender,Age_Bracket,Brand,COUNT(*) AS Transactions,SUM(Transaction_Value) AS GMV FROM dbo.v_transactions_flat_production WHERE Category LIKE '%Tobacco%' GROUP BY Gender,Age_Bracket,Brand ORDER BY Transactions DESC;" "$ROOT/tobacco/demo_gender_age_brand.csv"

# Tobacco - Purchase profile with pecha de peligro
sql "WITH base AS (SELECT Txn_Timestamp,CASE WHEN DAY(Txn_Timestamp) BETWEEN 23 AND 30 THEN 1 ELSE 0 END AS PDP,Transaction_Value FROM dbo.v_transactions_flat_production WHERE Category LIKE '%Tobacco%') SELECT FORMAT(Txn_Timestamp,'yyyy-MM') AS YearMonth,DAY(Txn_Timestamp) AS Day,SUM(CASE WHEN PDP=1 THEN 1 ELSE 0 END) AS Txns_PDP,SUM(1) AS Txns_All,SUM(CASE WHEN PDP=1 THEN Transaction_Value ELSE 0 END) AS GMV_PDP,SUM(Transaction_Value) AS GMV_All FROM base GROUP BY FORMAT(Txn_Timestamp,'yyyy-MM'),DAY(Txn_Timestamp) ORDER BY YearMonth,Day;" "$ROOT/tobacco/purchase_profile_pdp.csv"

# Tobacco - Daypart patterns
sql "SELECT CASE WHEN DATEPART(HOUR,Txn_Timestamp) BETWEEN 5 AND 10 THEN 'morning' WHEN DATEPART(HOUR,Txn_Timestamp) BETWEEN 11 AND 15 THEN 'afternoon' WHEN DATEPART(HOUR,Txn_Timestamp) BETWEEN 16 AND 20 THEN 'evening' ELSE 'night' END AS Daypart,COUNT(*) AS Txns,SUM(Transaction_Value) AS GMV FROM dbo.v_transactions_flat_production WHERE Category LIKE '%Tobacco%' GROUP BY CASE WHEN DATEPART(HOUR,Txn_Timestamp) BETWEEN 5 AND 10 THEN 'morning' WHEN DATEPART(HOUR,Txn_Timestamp) BETWEEN 11 AND 15 THEN 'afternoon' WHEN DATEPART(HOUR,Txn_Timestamp) BETWEEN 16 AND 20 THEN 'evening' ELSE 'night' END ORDER BY Txns DESC;" "$ROOT/tobacco/daypart_patterns.csv"

# Tobacco - Sales x daypart x weektype
sql "SELECT * FROM dbo.v_xtab_daypart_weektype_abs WHERE Category LIKE '%Tobacco%' ORDER BY WeekType,Daypart,Category;" "$ROOT/tobacco/sales_daypart_weektype.csv"

# Tobacco - Co-purchase analysis
sql "WITH tob_tx AS (SELECT DISTINCT Transaction_ID FROM dbo.v_transactions_flat_production WHERE Category LIKE '%Tobacco%') SELECT f.Category,COUNT(*) AS Lines FROM dbo.v_transactions_flat_production f JOIN tob_tx t ON t.Transaction_ID=f.Transaction_ID WHERE f.Category NOT LIKE '%Tobacco%' GROUP BY f.Category ORDER BY Lines DESC;" "$ROOT/tobacco/copurchase_categories.csv"

# Tobacco - Frequent terms from transcripts
sql "WITH tok AS (SELECT LOWER(value) AS term FROM dbo.v_transactions_flat_production CROSS APPLY STRING_SPLIT(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(COALESCE(Audio_Transcript,''),'.',' '),',',' '),';',' '),':',' '),'''',' '),' ') WHERE Category LIKE '%Tobacco%' AND LEN(TRIM(value)) BETWEEN 3 AND 20) SELECT TOP 200 term,COUNT(*) AS freq FROM tok WHERE term NOT IN ('para','pang','lang','naman','yung','yong','ako','sir','maam','isa','dalawa','tatlo','yosi','cigs','cig','apo') GROUP BY term ORDER BY freq DESC,term;" "$ROOT/tobacco/frequent_terms.csv"

echo "🧽 Exporting Laundry/Detergent analytics..."
# Laundry - Demographics (gender x age x brand)
sql "SELECT Gender,Age_Bracket,Brand,COUNT(*) AS Transactions,SUM(Transaction_Value) AS GMV FROM dbo.v_transactions_flat_production WHERE Category LIKE '%Laundry%' OR Category LIKE '%Detergent%' GROUP BY Gender,Age_Bracket,Brand ORDER BY Transactions DESC;" "$ROOT/laundry/demo_gender_age_brand.csv"

# Laundry - Purchase profile with pecha de peligro
sql "WITH base AS (SELECT Txn_Timestamp,CASE WHEN DAY(Txn_Timestamp) BETWEEN 23 AND 30 THEN 1 ELSE 0 END AS PDP,Transaction_Value FROM dbo.v_transactions_flat_production WHERE Category LIKE '%Laundry%' OR Category LIKE '%Detergent%') SELECT FORMAT(Txn_Timestamp,'yyyy-MM') AS YearMonth,DAY(Txn_Timestamp) AS Day,SUM(CASE WHEN PDP=1 THEN 1 ELSE 0 END) AS Txns_PDP,SUM(1) AS Txns_All,SUM(CASE WHEN PDP=1 THEN Transaction_Value ELSE 0 END) AS GMV_PDP,SUM(Transaction_Value) AS GMV_All FROM base GROUP BY FORMAT(Txn_Timestamp,'yyyy-MM'),DAY(Txn_Timestamp) ORDER BY YearMonth,Day;" "$ROOT/laundry/purchase_profile_pdp.csv"

# Laundry - Sales x daypart x weektype
sql "SELECT * FROM dbo.v_xtab_daypart_weektype_abs WHERE Category LIKE '%Laundry%' OR Category LIKE '%Detergent%' ORDER BY WeekType,Daypart,Category;" "$ROOT/laundry/sales_daypart_weektype.csv"

# Laundry - Detergent type (bar vs powder)
sql "SELECT CASE WHEN Product_Form IN ('Bar','BAR') THEN 'Bar' WHEN Product_Form IN ('Powder','POWDER') THEN 'Powder' WHEN Product_Name LIKE '%bar%' THEN 'Bar' WHEN Product_Name LIKE '%powder%' OR Product_Name LIKE '%pulbos%' THEN 'Powder' ELSE 'Other/Unknown' END AS Detergent_Type, COUNT(*) AS Lines, SUM(Line_Amount) AS Line_GMV FROM dbo.v_transactions_flat_production WHERE Category LIKE '%Laundry%' OR Category LIKE '%Detergent%' GROUP BY CASE WHEN Product_Form IN ('Bar','BAR') THEN 'Bar' WHEN Product_Form IN ('Powder','POWDER') THEN 'Powder' WHEN Product_Name LIKE '%bar%' THEN 'Bar' WHEN Product_Name LIKE '%powder%' OR Product_Name LIKE '%pulbos%' THEN 'Powder' ELSE 'Other/Unknown' END ORDER BY Lines DESC;" "$ROOT/laundry/detergent_type.csv"

# Laundry - Fabcon co-purchase rate
sql "WITH laundry_tx AS (SELECT DISTINCT Transaction_ID FROM dbo.v_transactions_flat_production WHERE Category LIKE '%Laundry%' OR Category LIKE '%Detergent%'), basket AS (SELECT f.Transaction_ID,f.Category,f.Brand,f.Product_Name FROM dbo.v_transactions_flat_production f JOIN laundry_tx t ON t.Transaction_ID=f.Transaction_ID) SELECT SUM(CASE WHEN Category LIKE '%Fabric Conditioner%' OR Product_Name LIKE '%fabcon%' THEN 1 ELSE 0 END) AS Has_Fabcon_Lines, COUNT(*) AS Total_Lines, CAST(100.0*SUM(CASE WHEN Category LIKE '%Fabric Conditioner%' OR Product_Name LIKE '%fabcon%' THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0) AS decimal(5,2)) AS Fabcon_Line_Pct FROM basket;" "$ROOT/laundry/fabcon_copurchase.csv"

# Laundry - Co-purchase categories
sql "WITH laundry_tx AS (SELECT DISTINCT Transaction_ID FROM dbo.v_transactions_flat_production WHERE Category LIKE '%Laundry%' OR Category LIKE '%Detergent%') SELECT f.Category,COUNT(*) AS Lines FROM dbo.v_transactions_flat_production f JOIN laundry_tx t ON t.Transaction_ID=f.Transaction_ID WHERE f.Category NOT LIKE '%Laundry%' AND f.Category NOT LIKE '%Detergent%' GROUP BY f.Category ORDER BY Lines DESC;" "$ROOT/laundry/copurchase_categories.csv"

# Laundry - Frequent terms from transcripts
sql "WITH tok AS (SELECT LOWER(value) AS term FROM dbo.v_transactions_flat_production CROSS APPLY STRING_SPLIT(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(COALESCE(Audio_Transcript,''),'.',' '),',',' '),';',' '),':',' '),'''',' '),' ') WHERE (Category LIKE '%Laundry%' OR Category LIKE '%Detergent%') AND LEN(TRIM(value)) BETWEEN 3 AND 20) SELECT TOP 200 term,COUNT(*) AS freq FROM tok WHERE term NOT IN ('para','pang','lang','naman','yung','yong','ako','sir','maam','isa','dalawa','tatlo') GROUP BY term ORDER BY freq DESC,term;" "$ROOT/laundry/frequent_terms.csv"

echo "✅ Inquiry analytics export completed!"
echo "📁 Files created under out/inquiries/"
find "$ROOT" -name "*.csv" | sort