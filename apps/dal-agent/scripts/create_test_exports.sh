#!/bin/bash
# Create complete test export structure with sample data

mkdir -p out/inquiries_filtered/overall out/inquiries_filtered/tobacco out/inquiries_filtered/laundry

# Overall exports with data
cat > out/inquiries_filtered/overall/store_profiles.csv << EOD
store_id,store_name,region,transactions,total_items,total_amount
store_001,Sari-Sari Store 1,NCR,145,432,12500.75
store_002,Sari-Sari Store 2,NCR,89,234,8900.25
EOD

cat > out/inquiries_filtered/overall/sales_by_week.csv << EOD
iso_week,week_start,transactions,total_amount
2025-W39,2025-09-22,145,12500.75
2025-W38,2025-09-15,132,11200.50
EOD

cat > out/inquiries_filtered/overall/daypart_by_category.csv << EOD
daypart,category,transactions,share_pct
Morning,Tobacco,58,35.2
Evening,Laundry,42,25.5
EOD

# Tobacco exports with data
cat > out/inquiries_filtered/tobacco/demo_gender_age_brand.csv << EOD
gender,age_band,brand,transactions,share_pct
Male,25-35,Marlboro,58,35.2
Female,18-25,Marlboro Light,34,20.6
EOD

cat > out/inquiries_filtered/tobacco/purchase_profile_pdp.csv << EOD
dom_bucket,transactions,share_pct
Regular,45,62.5
Premium,27,37.5
EOD

cat > out/inquiries_filtered/tobacco/sales_by_day_daypart.csv << EOD
date,daypart,transactions,share_pct
2025-09-25,Morning,12,42.8
2025-09-25,Evening,16,57.2
EOD

cat > out/inquiries_filtered/tobacco/sticks_per_visit.csv << EOD
transaction_id,brand,items,sticks_per_pack,estimated_sticks
TXN-001,Marlboro,1,20,20
TXN-002,Marlboro Light,2,20,40
EOD

cat > out/inquiries_filtered/tobacco/copurchase_categories.csv << EOD
category,co_category,txn_cocount,confidence,lift
Tobacco,Soft Drinks,145,0.85,2.4
Tobacco,Snacks,89,0.72,1.8
EOD

# Laundry exports with data
cat > out/inquiries_filtered/laundry/detergent_type.csv << EOD
detergent_type,with_fabcon,transactions,share_pct
Powder,Yes,89,42.8
Liquid,No,67,32.2
EOD

echo "✅ Complete test export structure with data created"
