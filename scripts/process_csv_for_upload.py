#!/usr/bin/env python3
"""
Process CSV for SQL Server upload - handles local file conversion
"""
import csv
import sys
import os

def process_csv(input_path, output_path):
    """Convert CSV to SQL-compatible format"""

    if not os.path.exists(input_path):
        print(f"❌ ERROR: Input file not found: {input_path}")
        sys.exit(1)

    print(f"📂 Processing: {input_path}")
    print(f"📤 Output: {output_path}")

    row_count = 0

    with open(input_path, 'r', encoding='utf-8') as infile, \
         open(output_path, 'w', encoding='utf-8', newline='') as outfile:

        reader = csv.reader(infile)
        writer = csv.writer(outfile, quoting=csv.QUOTE_ALL)

        # Skip header
        header = next(reader)
        print(f"📋 Header: {header}")

        # Process data rows
        for row in reader:
            if len(row) >= 5:  # Ensure all required columns
                # Clean and validate row
                source_path, txn_id, device_id, store_id, payload = row[:5]

                # Basic validation
                if txn_id and payload:
                    writer.writerow([source_path, txn_id, device_id, store_id, payload])
                    row_count += 1

                    if row_count % 1000 == 0:
                        print(f"📊 Processed {row_count} records...")

    print(f"✅ Processed {row_count} total records")
    return row_count

if __name__ == "__main__":
    input_file = sys.argv[1] if len(sys.argv) > 1 else "/Users/tbwa/Downloads/transactions_flat_no_ts.csv"
    output_file = sys.argv[2] if len(sys.argv) > 2 else "exports/processed_payload_data.csv"

    process_csv(input_file, output_file)