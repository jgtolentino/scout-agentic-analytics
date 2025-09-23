#!/usr/bin/env python3
"""
Scout Store Geospatial Enrichment Script
Enriches store data with PSGC codes and GeoJSON polygons for choropleth mapping.
"""

import pandas as pd
import json
import math
from typing import Dict, List, Optional, Tuple
from datetime import datetime

# PSGC Reference Data for NCR
PSGC_NCR_REFERENCE = {
    'regions': {
        'NCR': {
            'code': '130000000',
            'name': 'National Capital Region',
            'region_code': '13'
        }
    },
    'provinces': {
        'Metro Manila': {
            'code': '137400000',
            'name': 'Metro Manila',
            'region_code': '130000000'
        }
    },
    'cities': {
        'Manila': {'code': '137401000', 'name': 'City of Manila'},
        'City of Manila': {'code': '137401000', 'name': 'City of Manila'},
        'Quezon City': {'code': '137402000', 'name': 'Quezon City'},
        'Caloocan': {'code': '137403000', 'name': 'Caloocan City'},
        'Las Piñas': {'code': '137404000', 'name': 'Las Piñas City'},
        'Makati': {'code': '137405000', 'name': 'Makati City'},
        'Makati City': {'code': '137405000', 'name': 'Makati City'},
        'Malabon': {'code': '137406000', 'name': 'Malabon City'},
        'Mandaluyong': {'code': '137407000', 'name': 'Mandaluyong City'},
        'Mandaluyong City': {'code': '137407000', 'name': 'Mandaluyong City'},
        'Marikina': {'code': '137408000', 'name': 'Marikina City'},
        'Muntinlupa': {'code': '137409000', 'name': 'Muntinlupa City'},
        'Navotas': {'code': '137410000', 'name': 'Navotas City'},
        'Parañaque': {'code': '137411000', 'name': 'Parañaque City'},
        'Pasay': {'code': '137412000', 'name': 'Pasay City'},
        'Pasig': {'code': '137413000', 'name': 'Pasig City'},
        'Pateros': {'code': '137414000', 'name': 'Pateros'},
        'San Juan': {'code': '137415000', 'name': 'San Juan City'},
        'Taguig': {'code': '137416000', 'name': 'Taguig City'},
        'Valenzuela': {'code': '137417000', 'name': 'Valenzuela City'}
    }
}

# Central coordinates for each city/municipality (approximate)
CITY_CENTROIDS = {
    'City of Manila': (14.5995, 120.9842),
    'Quezon City': (14.6760, 121.0437),
    'Makati City': (14.5547, 121.0244),
    'Pateros': (14.5764, 121.0851),
    'Mandaluyong City': (14.5794, 121.0359),
    'Caloocan': (14.6507, 120.9672),
    'Las Piñas': (14.4378, 120.9761),
    'Malabon': (14.6598, 120.9581),
    'Marikina': (14.6507, 121.1029),
    'Muntinlupa': (14.3831, 121.0363),
    'Navotas': (14.6696, 120.9467),
    'Parañaque': (14.4793, 121.0198),
    'Pasay': (14.5378, 120.9896),
    'Pasig': (14.5764, 121.0851),
    'San Juan': (14.6019, 121.0355),
    'Taguig': (14.5176, 121.0509),
    'Valenzuela': (14.7011, 120.9831)
}

class StoreGeospatialEnricher:
    """Enriches store data with PSGC codes and GeoJSON polygons."""

    def __init__(self, csv_path: str):
        """Initialize with path to stores CSV."""
        self.df = pd.read_csv(csv_path)
        self.enriched_df = None

    def normalize_municipality_name(self, municipality: str) -> str:
        """Normalize municipality names to match PSGC reference."""
        if pd.isna(municipality) or not municipality:
            return None

        normalized = municipality.strip()

        # Handle common variations
        name_mappings = {
            'QUEZON CITY': 'Quezon City',
            'QC': 'Quezon City',
            'MANILA': 'City of Manila',
            'City of Manila': 'City of Manila',
            'MAKATI': 'Makati City',
            'PATEROS': 'Pateros',
            'MANDALUYONG': 'Mandaluyong City',
            'Mandaluyong City': 'Mandaluyong City'
        }

        return name_mappings.get(normalized, normalized)

    def get_psgc_codes(self, municipality: str) -> Dict[str, str]:
        """Get PSGC codes for municipality."""
        normalized_muni = self.normalize_municipality_name(municipality)

        if not normalized_muni or normalized_muni not in PSGC_NCR_REFERENCE['cities']:
            return {
                'psgc_region': '130000000',
                'psgc_province': '137400000',
                'psgc_citymun': None
            }

        city_info = PSGC_NCR_REFERENCE['cities'][normalized_muni]
        return {
            'psgc_region': '130000000',
            'psgc_province': '137400000',
            'psgc_citymun': city_info['code']
        }

    def generate_circle_polygon(self, lat: float, lon: float, radius_km: float = 0.5) -> str:
        """Generate a circular polygon around a point."""
        if pd.isna(lat) or pd.isna(lon):
            return None

        # Convert radius from km to degrees (rough approximation)
        radius_deg = radius_km / 111.0  # 1 degree ≈ 111 km

        # Generate circle coordinates
        coordinates = []
        for i in range(36):  # 36 points for smooth circle
            angle = i * 10 * math.pi / 180  # 10 degrees per point
            point_lat = lat + radius_deg * math.cos(angle)
            point_lon = lon + radius_deg * math.sin(angle)
            coordinates.append([point_lon, point_lat])

        # Close the polygon
        coordinates.append(coordinates[0])

        # Create GeoJSON polygon
        polygon = {
            "type": "Polygon",
            "coordinates": [coordinates]
        }

        return json.dumps(polygon, separators=(',', ':'))

    def infer_coordinates(self, municipality: str) -> Tuple[Optional[float], Optional[float]]:
        """Infer coordinates from municipality centroid if not provided."""
        normalized_muni = self.normalize_municipality_name(municipality)

        if normalized_muni in CITY_CENTROIDS:
            return CITY_CENTROIDS[normalized_muni]

        return None, None

    def validate_ncr_bounds(self, lat: float, lon: float) -> bool:
        """Validate coordinates are within NCR bounds."""
        if pd.isna(lat) or pd.isna(lon):
            return False
        return 14.2 <= lat <= 14.9 and 120.9 <= lon <= 121.2

    def enrich_data(self) -> pd.DataFrame:
        """Main enrichment process."""
        enriched_rows = []

        for _, row in self.df.iterrows():
            # Start with original data
            enriched_row = row.to_dict()

            # Normalize municipality
            normalized_muni = self.normalize_municipality_name(row.get('city_municipality'))
            enriched_row['MunicipalityName'] = normalized_muni

            # Add PSGC codes
            psgc_codes = self.get_psgc_codes(normalized_muni)
            enriched_row.update(psgc_codes)

            # Handle coordinates
            lat = row.get('latitude')
            lon = row.get('longitude')

            # If coordinates missing, try to infer from municipality
            if pd.isna(lat) or pd.isna(lon):
                inferred_lat, inferred_lon = self.infer_coordinates(normalized_muni)
                lat = inferred_lat if pd.isna(lat) else lat
                lon = inferred_lon if pd.isna(lon) else lon

            # Validate NCR bounds
            if lat and lon and self.validate_ncr_bounds(lat, lon):
                enriched_row['GeoLatitude'] = lat
                enriched_row['GeoLongitude'] = lon

                # Generate polygon
                polygon = self.generate_circle_polygon(lat, lon)
                enriched_row['StorePolygon'] = polygon
            else:
                enriched_row['GeoLatitude'] = None
                enriched_row['GeoLongitude'] = None
                enriched_row['StorePolygon'] = None

            # Add metadata
            enriched_row['Region'] = 'NCR'
            enriched_row['ProvinceName'] = 'Metro Manila'
            enriched_row['EnrichedAt'] = datetime.utcnow().isoformat()

            # Rename columns to match Azure SQL schema
            column_mapping = {
                'store_id': 'StoreID',
                'store_name': 'StoreName',
                'original_location': 'AddressLine',
                'barangay': 'BarangayName'
            }

            for old_col, new_col in column_mapping.items():
                if old_col in enriched_row:
                    enriched_row[new_col] = enriched_row[old_col]

            enriched_rows.append(enriched_row)

        self.enriched_df = pd.DataFrame(enriched_rows)
        return self.enriched_df

    def save_enriched_csv(self, output_path: str):
        """Save enriched data to CSV."""
        if self.enriched_df is None:
            raise ValueError("Must call enrich_data() first")

        # Select columns for Azure SQL import
        output_columns = [
            'StoreID', 'StoreName', 'AddressLine', 'MunicipalityName',
            'BarangayName', 'Region', 'ProvinceName',
            'GeoLatitude', 'GeoLongitude', 'StorePolygon',
            'psgc_region', 'psgc_citymun', 'EnrichedAt'
        ]

        # Filter to only include valid store IDs (exclude test store)
        valid_stores = self.enriched_df[
            (self.enriched_df['StoreID'].notna()) &
            (self.enriched_df['StoreID'] != 1)  # Exclude test store
        ]

        output_df = valid_stores[output_columns].copy()
        output_df.to_csv(output_path, index=False)

        print(f"✅ Enriched {len(output_df)} stores saved to {output_path}")
        return output_path

    def print_summary(self):
        """Print enrichment summary."""
        if self.enriched_df is None:
            raise ValueError("Must call enrich_data() first")

        total_stores = len(self.enriched_df)
        valid_coords = len(self.enriched_df.dropna(subset=['GeoLatitude', 'GeoLongitude']))
        valid_polygons = len(self.enriched_df.dropna(subset=['StorePolygon']))
        valid_psgc = len(self.enriched_df.dropna(subset=['psgc_citymun']))

        print("\n📊 Enrichment Summary:")
        print(f"Total stores processed: {total_stores}")
        print(f"Stores with valid coordinates: {valid_coords}")
        print(f"Stores with polygons: {valid_polygons}")
        print(f"Stores with PSGC codes: {valid_psgc}")

        # Show municipality distribution
        muni_counts = self.enriched_df['MunicipalityName'].value_counts()
        print(f"\n🏙️ Municipality Distribution:")
        for muni, count in muni_counts.head(10).items():
            print(f"  {muni}: {count} stores")

def main():
    """Main execution function."""
    input_csv = "/Users/tbwa/Downloads/stores_with_parsed_locations.csv"
    output_csv = "/Users/tbwa/scout-v7/azure/stores_enriched_with_polygons.csv"

    print("🚀 Starting Scout Store Geospatial Enrichment...")

    # Initialize enricher
    enricher = StoreGeospatialEnricher(input_csv)

    # Enrich data
    enriched_df = enricher.enrich_data()

    # Save results
    enricher.save_enriched_csv(output_csv)

    # Print summary
    enricher.print_summary()

    print(f"\n✅ Enrichment complete! Output: {output_csv}")
    print(f"📁 Ready for Azure SQL import via blob storage")

if __name__ == "__main__":
    main()