#!/usr/bin/env python3
import sys, os, glob, json
from pathlib import Path
import pandas as pd

# Hard schemas per file: column order + dtype hints (pandas/pyarrow-friendly)
SCHEMAS = {
    "overall/store_profiles.csv": {
        "order": ["store_id","store_name","region","transactions","total_items","total_amount"],
        "dtypes": {"store_id":"string","store_name":"string","region":"string",
                   "transactions":"Int64","total_items":"Int64","total_amount":"float64"}
    },
    "overall/sales_by_week.csv": {
        "order": ["iso_week","week_start","transactions","total_amount"],
        "dtypes": {"iso_week":"Int64","week_start":"string","transactions":"Int64","total_amount":"float64"}
    },
    "overall/daypart_by_category.csv": {
        "order": ["daypart","category","transactions","share_pct"],
        "dtypes": {"daypart":"string","category":"string","transactions":"Int64","share_pct":"float64"}
    },
    "tobacco/demo_gender_age_brand.csv": {
        "order": ["gender","age_band","brand","transactions","share_pct"],
        "dtypes": {"gender":"string","age_band":"string","brand":"string","transactions":"Int64","share_pct":"float64"}
    },
    "tobacco/purchase_profile_pdp.csv": {
        "order": ["dom_bucket","transactions","share_pct"],
        "dtypes": {"dom_bucket":"string","transactions":"Int64","share_pct":"float64"}
    },
    "tobacco/sales_by_day_daypart.csv": {
        "order": ["date","daypart","transactions","share_pct"],
        "dtypes": {"date":"string","daypart":"string","transactions":"Int64","share_pct":"float64"}
    },
    "tobacco/sticks_per_visit.csv": {
        "order": ["transaction_id","brand","items","sticks_per_pack","estimated_sticks"],
        "dtypes": {"transaction_id":"string","brand":"string","items":"Int64","sticks_per_pack":"Int64","estimated_sticks":"Int64"}
    },
    "tobacco/copurchase_categories.csv": {
        "order": ["category","co_category","txn_cocount","confidence","lift"],
        "dtypes": {"category":"string","co_category":"string","txn_cocount":"Int64","confidence":"float64","lift":"float64"}
    },
    "laundry/detergent_type.csv": {
        "order": ["detergent_type","with_fabcon","transactions","share_pct"],
        "dtypes": {"detergent_type":"string","with_fabcon":"Int64","transactions":"Int64","share_pct":"float64"}
    },
}

def to_parquet(csv_path: Path, out_root: Path):
    rel = csv_path.relative_to(out_root)
    # expected structure: out/inquiries_filtered/<subdir>/<file>.csv
    key = "/".join(rel.parts[-2:])  # "<subdir>/<file>"
    schema = SCHEMAS.get(key)
    if not schema:
        print(f"[SKIP] No schema for {key}", file=sys.stderr)
        return

    # read csv with explicit dtype fallbacks; let pandas parse, then cast per schema
    df = pd.read_csv(csv_path)
    # re-order columns, fill missing
    missing = [c for c in schema["order"] if c not in df.columns]
    if missing:
        raise SystemExit(f"[ERROR] {key} missing columns: {missing}")

    df = df[schema["order"]]

    # cast dtypes gently (Int64 allows NA), strings as pandas string dtype
    for col, dt in schema["dtypes"].items():
        if dt == "string":
            df[col] = df[col].astype("string")
        elif dt == "Int64":
            # tolerant integer
            df[col] = pd.to_numeric(df[col], errors="coerce").astype("Int64")
        elif dt == "float64":
            df[col] = pd.to_numeric(df[col], errors="coerce").astype("float64")
        else:
            # default fallback
            pass

    # write parquet (Snappy)
    pq_path = csv_path.with_suffix(".parquet")
    df.to_parquet(pq_path, index=False)
    print(f"[OK] {pq_path}")

def main():
    out_root = Path("out/inquiries_filtered").resolve()
    if not out_root.exists():
        print("[ERROR] out/inquiries_filtered not found", file=sys.stderr)
        sys.exit(2)

    for subdir in ["overall","tobacco","laundry"]:
        for csv_path in sorted((out_root/subdir).glob("*.csv")):
            to_parquet(csv_path, out_root)

if __name__ == "__main__":
    main()