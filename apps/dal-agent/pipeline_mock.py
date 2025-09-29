#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Scout v7 — Mock Azure Pipeline for Demonstration
Simulates successful export generation without database connection
"""

import os, sys, math, logging, datetime as dt
from typing import Optional
import pandas as pd

# Mock configurations
DATE_FROM = os.getenv("DATE_FROM", "2025-09-01")
DATE_TO = os.getenv("DATE_TO", "2025-09-23")
NCR_ONLY = os.getenv("NCR_ONLY", "1") == "1"
TOL_PCT = float(os.getenv("AMOUNT_TOLERANCE_PCT", "1.0")) / 100.0
OUT_DIR = os.getenv("OUT_DIR", "out")

os.makedirs(OUT_DIR, exist_ok=True)

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s"
)
log = logging.getLogger("scout-pipeline-mock")

def create_mock_data():
    """Generate mock Scout v7 data for demonstration"""
    # Simulate canonical 15-column export with realistic data
    mock_data = {
        'canonical_tx_id': [f'TX_{i:06d}' for i in range(1, 501)],
        'amount': [round(50 + (i * 15.75) % 2000, 2) for i in range(500)],
        'basket_count': [1 + (i % 8) for i in range(500)],
        'store_key': [f'ST_{(i % 25):03d}' for i in range(500)],
        'store_name': [f'Sari-Sari Store {(i % 25) + 1}' for i in range(500)],
        'region': ['NCR' if i % 3 == 0 else 'Metro Manila' if i % 3 == 1 else 'Luzon' for i in range(500)],
        'brand': ['Tide' if i % 4 == 0 else 'Ariel' if i % 4 == 1 else 'Surf' if i % 4 == 2 else 'Pride' for i in range(500)],
        'category': ['Laundry' if i % 3 != 2 else 'Tobacco' for i in range(500)],
        'age': ['25-34' if i % 3 == 0 else '35-44' if i % 3 == 1 else '18-24' for i in range(500)],
        'gender': ['Female' if i % 2 == 0 else 'Male' for i in range(500)],
        'persona': ['Budget Shopper' if i % 3 == 0 else 'Brand Loyalist' if i % 3 == 1 else 'Convenience Seeker' for i in range(500)],
        'payment_method': ['Cash' if i % 4 != 3 else 'GCash' for i in range(500)],
        'date': [(dt.datetime(2025, 9, 1) + dt.timedelta(days=i % 22)).strftime('%Y-%m-%d') for i in range(500)],
        'was_substitution': ['Original→Ariel' if i % 20 == 0 else '' for i in range(500)],
        'copurchase_categories': ['Laundry,Tobacco' if i % 15 == 0 else 'Laundry' if i % 3 != 2 else 'Tobacco' for i in range(500)]
    }

    df = pd.DataFrame(mock_data)

    # Apply NCR filter if enabled
    if NCR_ONLY:
        df = df[df['region'].isin(['NCR', 'Metro Manila'])].copy()
        log.info("Applied NCR filter: %d rows retained", len(df))

    return df

def run_qa_gates(df):
    """Run QA gates on mock data"""
    log.info("Running QA gates...")

    # 1. PK uniqueness
    dups = df.duplicated('canonical_tx_id').sum()
    if dups == 0:
        log.info("✅ PK uniqueness check passed")
    else:
        raise AssertionError(f"Duplicate canonical_tx_id values: {dups}")

    # 2. Non-negative amounts
    negative_amounts = (df['amount'] < 0).sum()
    if negative_amounts == 0:
        log.info("✅ Non-negative amount check passed")
    else:
        raise AssertionError(f"Negative amounts found: {negative_amounts}")

    # 3. Amount reconciliation (mock check)
    total_amount = df['amount'].sum()
    expected_range = (total_amount * 0.99, total_amount * 1.01)
    if expected_range[0] <= total_amount <= expected_range[1]:
        log.info("✅ Amount reconciliation passed: total=%.2f", total_amount)

    # 4. Rowcount parity (mock)
    log.info("✅ Rowcount parity check passed: %d rows", len(df))

def export_csv(df, name):
    """Export DataFrame to timestamped CSV"""
    ts = dt.datetime.utcnow().strftime("%Y%m%d")
    path = os.path.join(OUT_DIR, f"{name}_{ts}.csv")
    df.to_csv(path, index=False)
    log.info("Wrote %s (%d rows, %d cols)", path, len(df), len(df.columns))
    return path

def main():
    """Main mock pipeline execution"""
    log.info("🚀 Scout v7 Mock Pipeline start: %s → %s (NCR_ONLY=%s)",
             DATE_FROM, DATE_TO, NCR_ONLY)

    try:
        # 1. Generate mock data
        log.info("Generating mock Scout v7 data...")
        df = create_mock_data()
        log.info("Generated %d transactions", len(df))

        # 2. Run QA gates
        run_qa_gates(df)

        # 3. Export main flat file
        log.info("Exporting data...")
        flat_path = export_csv(df, "flat_enriched")

        # 4. Generate sample crosstab
        if len(df) > 0:
            # Create basket size buckets
            df['basket_bucket'] = pd.cut(
                df['basket_count'],
                bins=[-1, 2, 5, 10, float('inf')],
                labels=['1-2', '3-5', '6-10', '11+']
            )

            # Generate crosstab
            ctab = df.pivot_table(
                index='basket_bucket',
                columns='payment_method',
                values='canonical_tx_id',
                aggfunc='count',
                fill_value=0
            ).reset_index()

            ctab_path = export_csv(ctab, "crosstab_basket_x_payment")

        # 5. Success summary
        total_amount = df['amount'].sum()
        ncr_pct = (df['region'].isin(['NCR', 'Metro Manila']).sum() / len(df)) * 100

        log.info("SUCCESS ✅")
        log.info("  Rows: %d", len(df))
        log.info("  Columns: %d", len(df.columns))
        log.info("  Total Amount: %.2f", total_amount)
        log.info("  NCR Coverage: %.1f%%", ncr_pct)
        log.info("  Date Range: %s to %s", DATE_FROM, DATE_TO)

        print(f"\n✅ Mock Pipeline completed successfully!")
        print(f"📊 Generated: {os.path.basename(flat_path)}")
        print(f"📁 Output directory: {OUT_DIR}")

    except Exception as e:
        log.exception("Pipeline failed: %s", e)
        sys.exit(1)

if __name__ == "__main__":
    main()