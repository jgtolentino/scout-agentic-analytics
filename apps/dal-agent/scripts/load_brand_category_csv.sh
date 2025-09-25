#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
SQL="$ROOT/scripts/sql.sh"
CSV="${1:?usage: load_brand_category_csv.sh path/to/brand_category_map.csv}"

# Expected header: BrandName,CategoryCode[,DepartmentCode]
# Load CSV into staging table via temp table + BULK INSERT fallback.

# Ensure staging exists
$SQL -Q "IF OBJECT_ID('ref.stg_BrandCategoryMap','U') IS NULL
BEGIN
  CREATE TABLE ref.stg_BrandCategoryMap(
    BrandName nvarchar(255) NOT NULL,
    CategoryCode nvarchar(100) NOT NULL,
    DepartmentCode nvarchar(50) NULL
  );
END;"

# Truncate before load
$SQL -Q "TRUNCATE TABLE ref.stg_BrandCategoryMap;"

# Portable CSV ingest (sqlcmd var table-valued parsing)
python3 - <<'PY' "$CSV"
import csv, sys
csv_path = sys.argv[1]
rows=[]
with open(csv_path, newline='', encoding='utf-8') as f:
    r=csv.DictReader(f)
    for i,row in enumerate(r,1):
        bn = row.get('BrandName','').strip()
        cc = row.get('CategoryCode','').strip()
        dc = (row.get('DepartmentCode','') or '').strip()
        if not bn or not cc:
            continue
        # escape single quotes
        bn = bn.replace("'", "''")
        cc = cc.replace("'", "''")
        dc = dc.replace("'", "''")
        rows.append(f"INSERT INTO ref.stg_BrandCategoryMap(BrandName,CategoryCode,DepartmentCode) VALUES(N'{bn}',N'{cc}',NULLIF(N'{dc}',''));")

print("\\n".join(rows))
PY | $SQL -i -

echo "✅ Loaded CSV into ref.stg_BrandCategoryMap"