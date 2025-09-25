#!/usr/bin/env bash
set -euo pipefail
OUT="${OUT:-out/surveys}"
mkdir -p "$OUT"

# Write CSV header
echo "Transaction_ID,Transaction_Value,Basket_Size,Category,Brand,Daypart,Demographics_Age_Gender_Role,Emotions,Weekday_vs_Weekend,Time_of_transaction,Location,Were_there_other_product_bought_with_it,Was_there_substitution" > "$OUT/sari_sample.csv"

# Export data and append to CSV
./scripts/sql.sh -Q "
  SELECT TOP 20 *
  FROM gold.v_sample_sari_transactions
  ORDER BY Transaction_Value DESC, Transaction_ID DESC;
" -s "," -W -h -1 >> "$OUT/sari_sample.csv"

echo "Wrote $OUT/sari_sample.csv"