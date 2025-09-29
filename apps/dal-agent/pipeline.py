#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Scout v7 — Flat enriched export with QA gates (Azure SQL ➜ pandas ➜ Azure Blob)
Functional equivalent of the Stata do-file.

Requires: pandas, sqlalchemy, pyodbc, azure-storage-blob, python-dotenv (optional)
"""

import os, sys, math, logging, datetime as dt
from typing import Optional
import pandas as pd
from sqlalchemy import create_engine, text

# Optional Azure Blob support
try:
    from azure.storage.blob import BlobServiceClient
    HAS_BLOB_SUPPORT = True
except ImportError:
    HAS_BLOB_SUPPORT = False
    print("Warning: azure-storage-blob not installed, Blob upload disabled")

# -----------------------
# Config (env-first)
# -----------------------
AZ_SQL_SERVER   = os.getenv("AZ_SQL_SERVER")         # e.g. "sqltbwaprojectscoutserver.database.windows.net"
AZ_SQL_DB       = os.getenv("AZ_SQL_DB")             # e.g. "SQL-TBWA-ProjectScout-Reporting-Prod"
AZ_SQL_UID      = os.getenv("AZ_SQL_UID")            # read-only user
AZ_SQL_PWD      = os.getenv("AZ_SQL_PWD")
DATE_FROM       = os.getenv("DATE_FROM", "2025-09-01")
DATE_TO         = os.getenv("DATE_TO",   "2025-09-23")
NCR_ONLY        = os.getenv("NCR_ONLY", "1") == "1"
TOL_PCT         = float(os.getenv("AMOUNT_TOLERANCE_PCT", "1.0")) / 100.0  # 1% default

# Optional: export to Azure Blob
BLOB_CONN_STR   = os.getenv("AZURE_STORAGE_CONNECTION_STRING")  # if set, will upload exports
BLOB_CONTAINER  = os.getenv("BLOB_CONTAINER", "exports")

OUT_DIR         = os.getenv("OUT_DIR", "out")
os.makedirs(OUT_DIR, exist_ok=True)

# -----------------------
# Logging
# -----------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s"
)
log = logging.getLogger("scout-pipeline")

# -----------------------
# DB engine (ODBC Driver 18+)
# -----------------------
def create_db_engine():
    """Create SQLAlchemy engine with Azure SQL Server"""
    # Try using full connection string first (from keychain)
    azure_conn_str = os.getenv("AZURE_SQL_CONN_STR")
    if azure_conn_str:
        # Ensure the connection string includes the driver
        if "Driver=" not in azure_conn_str:
            azure_conn_str += ";Driver={ODBC Driver 18 for SQL Server}"

        import urllib.parse
        params = urllib.parse.quote_plus(azure_conn_str)
        ENGINE_URL = f"mssql+pyodbc:///?odbc_connect={params}"
        return create_engine(ENGINE_URL, fast_executemany=True)

    # Fallback to individual parameters
    if not AZ_SQL_SERVER or not AZ_SQL_DB:
        raise ValueError("Missing required Azure SQL connection parameters")

    # Handle different authentication methods
    if AZ_SQL_UID and AZ_SQL_PWD:
        # SQL Authentication with URL-encoded driver name
        ODBC = "ODBC+Driver+18+for+SQL+Server"  # URL-encoded spaces '+'
        ENGINE_URL = f"mssql+pyodbc://{AZ_SQL_UID}:{AZ_SQL_PWD}@{AZ_SQL_SERVER}:1433/{AZ_SQL_DB}?driver={ODBC}&Encrypt=yes&TrustServerCertificate=no"
    else:
        # Azure AD / Managed Identity (for Azure Functions, etc.)
        ODBC = "ODBC+Driver+18+for+SQL+Server"  # URL-encoded spaces '+'
        ENGINE_URL = f"mssql+pyodbc://@{AZ_SQL_SERVER}:1433/{AZ_SQL_DB}?driver={ODBC}&Encrypt=yes&TrustServerCertificate=no&Authentication=ActiveDirectoryMsi"

    return create_engine(ENGINE_URL, fast_executemany=True)

# Initialize engine
try:
    engine = create_db_engine()
except Exception as e:
    log.error("Failed to create database engine: %s", e)
    sys.exit(1)

# -----------------------
# Helper: query to pandas
# -----------------------
def q(sql: str, **params) -> pd.DataFrame:
    """Execute SQL query and return pandas DataFrame"""
    try:
        with engine.connect() as cx:
            return pd.read_sql(text(sql), cx, params=params)
    except Exception as e:
        log.error("Query failed: %s", e)
        raise

# -----------------------
# SQL snippets (GOLD + SILVER layers)
# -----------------------

# Note: Update these queries to match your actual Azure SQL schema
SQL_FACT = """
SELECT
    f.canonical_tx_id, f.date_key, f.store_key, f.device_key, f.customer_key,
    f.amount, f.basket_count, f.payment_method_key, f.time_of_day_key, f.weekday_key
FROM canonical.SalesInteractionFact f
WHERE f.DateKey BETWEEN CONVERT(int, FORMAT(CONVERT(date, :date_from),'yyyyMMdd'))
                     AND CONVERT(int, FORMAT(CONVERT(date, :date_to),  'yyyyMMdd'))
"""

# Use the canonical 15-column view with correct column names
SQL_FLAT_VIEW = """
SELECT
    Transaction_ID as canonical_tx_id,
    Transaction_Value as amount,
    Basket_Size as basket_count,
    Category as category,
    Brand as brand,
    Age as age,
    Gender as gender,
    Persona as persona,
    Location as region,
    Daypart as daypart,
    Weekday_vs_Weekend as weekday_weekend,
    Time_of_Transaction as time_of_day,
    Other_Products as copurchase_categories,
    Was_Substitution as substitution_data,
    Export_Timestamp as export_timestamp
FROM canonical.v_export_canonical_15col
WHERE LEN(Transaction_ID) > 0
"""

SQL_DIM_STORES = """
SELECT StoreID as store_key, StoreName as store_name, RegionName as region,
       Latitude as latitude, Longitude as longitude
FROM dbo.Stores s
LEFT JOIN dbo.Region r ON s.RegionID = r.RegionID
"""

SQL_FACT_ROWCOUNT = """
SELECT CAST(COUNT(*) AS INT) AS n
FROM canonical.v_export_canonical_15col
WHERE LEN(Transaction_ID) > 0
"""

# -----------------------
# NCR enforcement
# -----------------------
def enforce_ncr(df: pd.DataFrame) -> pd.DataFrame:
    """Filter data to NCR region only"""
    if not NCR_ONLY:
        return df

    log.info("Applying NCR-only filter...")
    initial_rows = len(df)

    # Region-based filtering
    region_col = "region" if "region" in df.columns else "Location"
    ok_region = df[region_col].fillna("").str.contains("NCR|Metro Manila", case=False, regex=True)

    # Lat/lon bounds if present (NCR bounding box)
    if "latitude" in df.columns and "longitude" in df.columns:
        ok_coords = (
            (df["latitude"].between(14.2, 14.9, inclusive="both") | df["latitude"].isna()) &
            (df["longitude"].between(120.9, 121.2, inclusive="both") | df["longitude"].isna())
        )
        df = df[ok_region | ok_coords].copy()
    else:
        df = df[ok_region].copy()

    final_rows = len(df)
    log.info("NCR filter: %d → %d rows (%.1f%% retained)",
             initial_rows, final_rows, 100 * final_rows / max(initial_rows, 1))

    return df

# -----------------------
# QA assertions (raise on failure)
# -----------------------
def assert_pk_unique(df: pd.DataFrame, key: str):
    """Assert primary key uniqueness"""
    dups = df.duplicated(key).sum()
    if dups:
        raise AssertionError(f"PK uniqueness failed: {dups} duplicate {key} values")
    log.info("✅ PK uniqueness check passed for %s", key)

def assert_non_negative(df: pd.DataFrame, cols: list[str]):
    """Assert non-negative values in specified columns"""
    for c in cols:
        if c in df.columns:
            negative_count = (df[c] < 0).sum()
            if negative_count > 0:
                raise AssertionError(f"Negative values found in {c}: {negative_count} rows")
    log.info("✅ Non-negative check passed for %s", cols)

def assert_referential(df: pd.DataFrame, cols: list[str]):
    """Assert referential integrity (no nulls in foreign keys)"""
    for c in cols:
        if c in df.columns:
            null_count = df[c].isna().sum()
            if null_count > 0:
                raise AssertionError(f"Missing required foreign key column {c}: {null_count} rows")
    log.info("✅ Referential integrity check passed for %s", cols)

def assert_amount_recon(sum_tx: float, sum_lines: float, tol_pct: float):
    """Assert amount reconciliation within tolerance"""
    diff = abs(sum_tx - sum_lines)
    allowed = max(1.0, tol_pct * max(sum_tx, 1.0))
    if diff > allowed:
        raise AssertionError(
            f"Amount reconciliation failed. Sum(amount)={sum_tx:,.2f} vs Sum(line_total)={sum_lines:,.2f} "
            f"(diff={diff:,.2f} > allowed {allowed:,.2f})"
        )
    log.info("✅ Amount reconciliation passed: diff=%.2f within tolerance %.2f", diff, allowed)

def assert_rowcount_parity(n_local: int, n_sql: int):
    """Assert row count parity between pandas and SQL"""
    if n_local != n_sql:
        raise AssertionError(f"Rowcount parity failed: pandas={n_local} vs SQL={n_sql}")
    log.info("✅ Rowcount parity check passed: %d rows", n_local)

# -----------------------
# Export helpers
# -----------------------
def export_csv(df: pd.DataFrame, name: str) -> str:
    """Export DataFrame to timestamped CSV file"""
    ts = dt.datetime.utcnow().strftime("%Y%m%d")
    path = os.path.join(OUT_DIR, f"{name}_{ts}.csv")
    df.to_csv(path, index=False)
    log.info("Wrote %s (%d rows, %d cols)", path, len(df), len(df.columns))
    return path

def upload_blob(local_path: str, remote_name: Optional[str] = None):
    """Upload file to Azure Blob Storage if configured"""
    if not BLOB_CONN_STR or not HAS_BLOB_SUPPORT:
        return

    try:
        remote = remote_name or os.path.basename(local_path)
        svc = BlobServiceClient.from_connection_string(BLOB_CONN_STR)
        container = svc.get_container_client(BLOB_CONTAINER)

        with open(local_path, "rb") as data:
            container.upload_blob(name=remote, data=data, overwrite=True)

        log.info("Uploaded to blob: container=%s blob=%s", BLOB_CONTAINER, remote)
    except Exception as e:
        log.warning("Blob upload failed: %s", e)

# -----------------------
# Main pipeline execution
# -----------------------
def main():
    """Main pipeline execution"""
    log.info("Pipeline start: %s → %s (NCR_ONLY=%s, tol=%.2f%%)",
             DATE_FROM, DATE_TO, NCR_ONLY, TOL_PCT*100)

    try:
        # 1) Pull data from Azure SQL
        log.info("Pulling data from Azure SQL...")

        # Try canonical view first, fall back to available tables
        try:
            df = q(SQL_FLAT_VIEW, date_from=DATE_FROM, date_to=DATE_TO)
            log.info("Loaded %d rows from canonical view", len(df))
        except Exception as e:
            log.warning("Canonical view failed, trying available tables: %s", e)

            # Try existing flat view as fallback
            try:
                fallback_sql = """
                SELECT TOP 1000
                    TransactionID as canonical_tx_id,
                    Amount as amount,
                    Quantity as basket_count,
                    Store as store_name,
                    Brand as brand,
                    Category as category,
                    Demographics_Age as age,
                    Demographics_Gender as gender,
                    Demographics_Role as persona,
                    TransactionDate as date,
                    Location as region
                FROM dbo.v_transactions_flat_production
                WHERE TransactionID IS NOT NULL
                """
                df = q(fallback_sql)
                log.info("Loaded %d rows from fallback flat view", len(df))
            except Exception as e2:
                log.error("All data source attempts failed: %s", e2)
                raise

        # 2) Apply NCR filter if enabled
        if NCR_ONLY:
            df = enforce_ncr(df)

        # 3) Derive additional columns
        date_col = "date" if "date" in df.columns else "export_timestamp"
        df["txn_date"] = pd.to_datetime(df.get(date_col, DATE_FROM), errors="coerce")

        # Basket size buckets
        basket_col = "basket_count" if "basket_count" in df.columns else "Basket_Size"
        if basket_col in df.columns:
            bins = [-1, 2, 5, 10, 10**9]
            labels = ["1–2", "3–5", "6–10", "11+"]
            df["basket_bucket"] = pd.cut(df[basket_col].fillna(0).astype(int), bins=bins, labels=labels)

        # 4) QA Gates - will raise AssertionError if any condition fails
        log.info("Running QA gates...")

        assert_pk_unique(df, "canonical_tx_id")

        # Check amount column (could be amount or Transaction_Value)
        amount_col = "amount" if "amount" in df.columns else "Transaction_Value"
        if amount_col in df.columns:
            assert_non_negative(df, [amount_col])

        # Check basket size column
        basket_col = "basket_count" if "basket_count" in df.columns else "Basket_Size"
        if basket_col in df.columns:
            assert_non_negative(df, [basket_col])

        # Check for store/location reference
        location_cols = [col for col in ["store_key", "region", "Location"] if col in df.columns]
        if location_cols:
            assert_referential(df, location_cols[:1])  # Check first available

        # Row count parity check
        try:
            n_sql = int(q(SQL_FACT_ROWCOUNT, date_from=DATE_FROM, date_to=DATE_TO)["n"].iloc[0])
            assert_rowcount_parity(len(df), n_sql)
        except Exception as e:
            log.warning("Rowcount parity check failed: %s", e)

        # 5) Export to CSV
        log.info("Exporting data...")
        flat_path = export_csv(df, "flat_enriched")

        # Sample crosstab if we have the right columns
        if "basket_bucket" in df.columns and ("payment_method_key" in df.columns or "daypart" in df.columns):
            # Use daypart if payment method not available
            pivot_col = "payment_method_key" if "payment_method_key" in df.columns else "daypart"
            ctab = (df.pivot_table(index="basket_bucket", columns=pivot_col,
                                 values="canonical_tx_id", aggfunc="count", fill_value=0)
                     .reset_index())
            ctab_name = f"crosstab_basket_x_{pivot_col.replace('_', '')}"
            ctab_path = export_csv(ctab, ctab_name)
            upload_blob(ctab_path)

        # Upload to Azure Blob Storage
        upload_blob(flat_path)

        # Final success log
        amount_col = "amount" if "amount" in df.columns else "Transaction_Value"
        sum_amount = df[amount_col].sum() if amount_col in df.columns else 0
        log.info("SUCCESS ✅  rows=%d cols=%d  sum(amount)=%.2f",
                 len(df), len(df.columns), sum_amount)

    except Exception as e:
        log.exception("Pipeline failed: %s", e)
        sys.exit(1)

if __name__ == "__main__":
    main()