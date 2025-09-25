#!/usr/bin/env python3
"""
Analyze Brand Categories Issue
Based on brands_categories_live.csv export data

This script analyzes the brand categorization issue where brands have
both correct and "unspecified" categories in the same dataset.
"""

import csv
from collections import defaultdict
import sys

def analyze_brand_categories():
    """Analyze the brand category data to quantify the issue."""

    csv_file = "out/catalog/brands_categories_live.csv"

    try:
        with open(csv_file, 'r') as file:
            # Read CSV data
            reader = csv.reader(file)
            brand_data = defaultdict(list)

            for row in reader:
                if len(row) >= 4:
                    brand, category, count, sales = row
                    brand_data[brand].append({
                        'category': category,
                        'transactions': int(count),
                        'sales': float(sales)
                    })

    except FileNotFoundError:
        print(f"❌ File not found: {csv_file}")
        print("Run the export script first to generate the data.")
        return

    # Analyze brands with multiple categories
    problematic_brands = []
    total_unspecified_transactions = 0
    total_unspecified_sales = 0

    print("🔍 BRAND CATEGORIZATION ANALYSIS")
    print("=" * 60)
    print()

    for brand, categories in brand_data.items():
        if len(categories) > 1:  # Brand has multiple categories
            has_unspecified = any(cat['category'] == 'unspecified' for cat in categories)
            if has_unspecified:
                correct_categories = [cat for cat in categories if cat['category'] != 'unspecified']
                unspecified_cats = [cat for cat in categories if cat['category'] == 'unspecified']

                if correct_categories:  # Has both correct and unspecified
                    problematic_brands.append({
                        'brand': brand,
                        'correct': correct_categories,
                        'unspecified': unspecified_cats[0]  # Should only be one
                    })

    # Sort by unspecified transaction volume
    problematic_brands.sort(key=lambda x: x['unspecified']['transactions'], reverse=True)

    print("❌ BRANDS WITH BOTH CORRECT AND UNSPECIFIED CATEGORIES:")
    print()
    print(f"{'BRAND':<15} {'CORRECT CATEGORY':<25} {'WRONG TXN':<10} {'WRONG SALES':<12} {'IMPACT'}")
    print("-" * 85)

    for brand_info in problematic_brands:
        brand = brand_info['brand']
        correct = brand_info['correct'][0]  # Use first correct category
        unspec = brand_info['unspecified']

        total_unspecified_transactions += unspec['transactions']
        total_unspecified_sales += unspec['sales']

        impact = "🔥 HIGH" if unspec['transactions'] > 100 else "⚠️  MED" if unspec['transactions'] > 50 else "⚡ LOW"

        print(f"{brand:<15} {correct['category']:<25} {unspec['transactions']:<10} "
              f"₱{unspec['sales']:<11,.0f} {impact}")

    print("-" * 85)
    print(f"{'TOTAL IMPACT':<15} {'':<25} {total_unspecified_transactions:<10} "
          f"₱{total_unspecified_sales:<11,.0f}")
    print()

    # Summary statistics
    total_brands = len(brand_data)
    problematic_count = len(problematic_brands)

    print("📊 IMPACT SUMMARY:")
    print(f"   • Total brands: {total_brands}")
    print(f"   • Problematic brands: {problematic_count} ({problematic_count/total_brands*100:.1f}%)")
    print(f"   • Unspecified transactions: {total_unspecified_transactions:,}")
    print(f"   • Unspecified sales: ₱{total_unspecified_sales:,.0f}")
    print()

    # Generate fix mapping
    print("🔧 RECOMMENDED FIXES:")
    print()
    fix_map = {}
    for brand_info in problematic_brands[:10]:  # Top 10 by volume
        brand = brand_info['brand']
        correct_category = brand_info['correct'][0]['category']
        unspec_count = brand_info['unspecified']['transactions']

        fix_map[brand] = correct_category
        print(f"   UPDATE: {brand} → {correct_category} ({unspec_count:,} transactions)")

    if len(problematic_brands) > 10:
        print(f"   ... and {len(problematic_brands) - 10} more brands")

    print()
    print("✅ NEXT STEPS:")
    print("   1. Connect to database")
    print("   2. Run sql/analytics/002_fix_brand_categories.sql")
    print("   3. Verify fixes with re-export")
    print(f"   4. Expected reduction: {total_unspecified_transactions:,} transactions properly categorized")

if __name__ == "__main__":
    analyze_brand_categories()