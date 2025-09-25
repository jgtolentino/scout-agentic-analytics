#!/usr/bin/env python3
"""
Complete Brand-SKU Category Mapping with Units Sold
Maps all 113 brands to correct categories with transaction volumes
"""

import csv
from collections import defaultdict
import json

def map_all_brands_skus():
    """Generate complete brand-SKU mapping with correct categories and units."""

    csv_file = "out/catalog/brands_categories_live.csv"

    try:
        with open(csv_file, 'r') as file:
            reader = csv.reader(file)
            brand_data = defaultdict(lambda: {
                'categories': [],
                'total_transactions': 0,
                'total_sales': 0.0,
                'correct_category': None
            })

            # Read all data
            for row in reader:
                if len(row) >= 4:
                    brand, category, count, sales = row
                    count = int(count)
                    sales = float(sales)

                    brand_data[brand]['categories'].append({
                        'category': category,
                        'transactions': count,
                        'sales': sales
                    })
                    brand_data[brand]['total_transactions'] += count
                    brand_data[brand]['total_sales'] += sales

    except FileNotFoundError:
        print(f"❌ File not found: {csv_file}")
        return

    # Process each brand to determine correct category
    all_brands = []

    for brand, data in brand_data.items():
        categories = data['categories']

        # Find the correct category (non-unspecified with highest volume)
        correct_category = None
        for cat in sorted(categories, key=lambda x: x['transactions'], reverse=True):
            if cat['category'] != 'unspecified':
                correct_category = cat['category']
                break

        # If no correct category found, use the most frequent one
        if not correct_category:
            correct_category = max(categories, key=lambda x: x['transactions'])['category']

        brand_info = {
            'brand': brand,
            'correct_category': correct_category,
            'total_transactions': data['total_transactions'],
            'total_sales': data['total_sales'],
            'has_unspecified': any(c['category'] == 'unspecified' for c in categories),
            'categories_breakdown': categories
        }

        all_brands.append(brand_info)

    # Sort by transaction volume
    all_brands.sort(key=lambda x: x['total_transactions'], reverse=True)

    # Generate comprehensive mapping
    print("🗺️  COMPLETE BRAND-CATEGORY MAPPING")
    print("=" * 80)
    print(f"Total Brands: {len(all_brands)}")
    print()

    # Group by category
    category_groups = defaultdict(list)
    for brand in all_brands:
        category_groups[brand['correct_category']].append(brand)

    # Display by category
    total_txns = 0
    total_sales = 0.0
    problematic_count = 0

    for category in sorted(category_groups.keys()):
        brands_in_category = category_groups[category]
        cat_txns = sum(b['total_transactions'] for b in brands_in_category)
        cat_sales = sum(b['total_sales'] for b in brands_in_category)

        total_txns += cat_txns
        total_sales += cat_sales

        print(f"\n📦 {category.upper()}")
        print(f"   Brands: {len(brands_in_category)} | Transactions: {cat_txns:,} | Sales: ₱{cat_sales:,.0f}")
        print("   " + "-" * 70)

        for brand in sorted(brands_in_category, key=lambda x: x['total_transactions'], reverse=True):
            status = "❌" if brand['has_unspecified'] else "✅"
            unspec_note = " (HAS UNSPECIFIED)" if brand['has_unspecified'] else ""

            if brand['has_unspecified']:
                problematic_count += 1

            print(f"   {status} {brand['brand']:<20} "
                  f"{brand['total_transactions']:>4,} txns  "
                  f"₱{brand['total_sales']:>8,.0f}{unspec_note}")

    # Summary statistics
    print("\n" + "=" * 80)
    print("📊 SUMMARY STATISTICS:")
    print(f"   • Total Brands: {len(all_brands)}")
    print(f"   • Total Transactions: {total_txns:,}")
    print(f"   • Total Sales: ₱{total_sales:,.0f}")
    print(f"   • Categories: {len(category_groups)}")
    print(f"   • Problematic Brands: {problematic_count} ({problematic_count/len(all_brands)*100:.1f}%)")

    # Generate JSON export for systems integration
    json_export = {
        'metadata': {
            'total_brands': len(all_brands),
            'total_transactions': total_txns,
            'total_sales': total_sales,
            'categories_count': len(category_groups),
            'problematic_brands': problematic_count
        },
        'categories': {}
    }

    for category, brands_in_category in category_groups.items():
        json_export['categories'][category] = {
            'brand_count': len(brands_in_category),
            'total_transactions': sum(b['total_transactions'] for b in brands_in_category),
            'total_sales': sum(b['total_sales'] for b in brands_in_category),
            'brands': [
                {
                    'name': b['brand'],
                    'transactions': b['total_transactions'],
                    'sales': b['total_sales'],
                    'has_data_issues': b['has_unspecified']
                }
                for b in sorted(brands_in_category, key=lambda x: x['total_transactions'], reverse=True)
            ]
        }

    # Export JSON
    with open('out/catalog/complete_brand_mapping.json', 'w') as f:
        json.dump(json_export, f, indent=2)

    # Export CSV for spreadsheet use
    with open('out/catalog/complete_brand_mapping.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['Brand', 'Category', 'Transactions', 'Sales', 'Data_Issues'])

        for brand in all_brands:
            writer.writerow([
                brand['brand'],
                brand['correct_category'],
                brand['total_transactions'],
                f"{brand['total_sales']:.2f}",
                'YES' if brand['has_unspecified'] else 'NO'
            ])

    print(f"\n✅ EXPORTS CREATED:")
    print(f"   • out/catalog/complete_brand_mapping.json")
    print(f"   • out/catalog/complete_brand_mapping.csv")
    print(f"\n🎯 NEXT: Run SQL fix script to eliminate {problematic_count} data issues")

if __name__ == "__main__":
    map_all_brands_skus()