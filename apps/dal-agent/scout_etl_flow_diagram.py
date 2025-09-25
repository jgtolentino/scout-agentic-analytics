#!/usr/bin/env python3
"""
Scout ETL Flow Diagram Generator
Creates visual representation of Scout's data pipeline architecture
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, ConnectionPatch
import numpy as np

def create_scout_etl_diagram():
    """Create comprehensive ETL flow diagram for Scout platform"""

    fig, ax = plt.subplots(1, 1, figsize=(20, 14))
    ax.set_xlim(0, 20)
    ax.set_ylim(0, 14)
    ax.axis('off')

    # Color scheme
    colors = {
        'source': '#FF6B6B',      # Red
        'staging': '#4ECDC4',     # Teal
        'bronze': '#45B7D1',      # Blue
        'silver': '#96CEB4',      # Green
        'gold': '#FFEAA7',        # Yellow
        'platinum': '#DDA0DD',     # Purple
        'views': '#FFB347',       # Orange
        'api': '#98D8C8',         # Mint
        'cdc': '#F7DC6F'          # Light Yellow
    }

    # Title
    ax.text(10, 13.5, 'SCOUT ANALYTICS PLATFORM - ETL ARCHITECTURE',
            fontsize=20, fontweight='bold', ha='center')

    # === DATA SOURCES (Top) ===
    ax.text(10, 12.8, 'DATA SOURCES', fontsize=14, fontweight='bold', ha='center')

    # Source systems
    sources = [
        ('Retail Stores\n(POS Systems)', 2, 12),
        ('IoT Devices\n(Sensors)', 6, 12),
        ('Vision AI\n(Cameras)', 10, 12),
        ('Audio AI\n(Microphones)', 14, 12),
        ('External APIs\n(Third Party)', 18, 12)
    ]

    for source, x, y in sources:
        box = FancyBboxPatch((x-0.8, y-0.3), 1.6, 0.6,
                            boxstyle="round,pad=0.1",
                            facecolor=colors['source'],
                            edgecolor='black', linewidth=1)
        ax.add_patch(box)
        ax.text(x, y, source, ha='center', va='center', fontsize=8, fontweight='bold')

    # === STAGING LAYER ===
    ax.text(3, 10.8, 'STAGING', fontsize=12, fontweight='bold', ha='center')

    staging_tables = [
        ('staging.StoreLocationImport', 1, 10.2),
        ('dbo.PayloadTransactionsStaging_csv', 5, 10.2)
    ]

    for table, x, y in staging_tables:
        box = FancyBboxPatch((x-1, y-0.2), 2, 0.4,
                            boxstyle="round,pad=0.05",
                            facecolor=colors['staging'],
                            edgecolor='black', linewidth=1)
        ax.add_patch(box)
        ax.text(x, y, table, ha='center', va='center', fontsize=7)

    # === BRONZE LAYER (Raw Data) ===
    ax.text(3, 9.5, 'BRONZE LAYER (Raw Data)', fontsize=12, fontweight='bold', ha='center')

    bronze_tables = [
        ('bronze.transactions\n(3 records)', 1, 8.8),
        ('bronze.bronze_transactions\n(3 records)', 3.5, 8.8),
        ('bronze.dim_stores_ncr', 6, 8.8),
        ('dbo.PayloadTransactions\n(12,192 records)', 9, 8.8),
        ('dbo.SalesInteractions\n(165,485 records)', 12.5, 8.8),
        ('dbo.bronze_device_logs', 16, 8.8),
        ('dbo.bronze_transcriptions', 18.5, 8.8)
    ]

    for table, x, y in bronze_tables:
        box = FancyBboxPatch((x-0.7, y-0.25), 1.4, 0.5,
                            boxstyle="round,pad=0.05",
                            facecolor=colors['bronze'],
                            edgecolor='black', linewidth=1)
        ax.add_patch(box)
        ax.text(x, y, table, ha='center', va='center', fontsize=6)

    # === CDC LAYER (Change Data Capture) ===
    ax.text(17, 9.5, 'CDC LAYER', fontsize=10, fontweight='bold', ha='center')

    cdc_note = """CDC Schema:
    • cdc.dbo_SalesInteractions_CT
    • cdc.dbo_Stores_CT
    • cdc.poc_transactions_CT
    • 35+ CDC stored procedures
    • Real-time change tracking"""

    box = FancyBboxPatch((15.5, 7.8), 3, 1.4,
                        boxstyle="round,pad=0.1",
                        facecolor=colors['cdc'],
                        edgecolor='black', linewidth=1)
    ax.add_patch(box)
    ax.text(17, 8.5, cdc_note, ha='center', va='center', fontsize=7)

    # === SILVER LAYER (Cleaned & Validated) ===
    ax.text(3, 7.5, 'SILVER LAYER (Cleaned & Validated)', fontsize=12, fontweight='bold', ha='center')

    silver_tables = [
        ('dbo.silver_location_verified', 2, 6.8),
        ('dbo.silver_txn_items', 5, 6.8),
        ('dbo.silver_transcripts (VIEW)', 8, 6.8),
        ('dbo.silver_vision_detections (VIEW)', 11.5, 6.8)
    ]

    for table, x, y in silver_tables:
        box = FancyBboxPatch((x-1, y-0.2), 2, 0.4,
                            boxstyle="round,pad=0.05",
                            facecolor=colors['silver'],
                            edgecolor='black', linewidth=1)
        ax.add_patch(box)
        ax.text(x, y, table, ha='center', va='center', fontsize=6)

    # === GOLD LAYER (Business Ready) ===
    ax.text(6, 5.8, 'GOLD LAYER (Business Ready)', fontsize=12, fontweight='bold', ha='center')

    gold_tables = [
        ('gold.scout_dashboard_transactions\n(12,101 records)', 4, 5.1),
        ('gold.tbwa_client_brands', 8, 5.1),
        ('gold.v_transactions_crosstab (VIEW)', 12, 5.1)
    ]

    for table, x, y in gold_tables:
        box = FancyBboxPatch((x-1.2, y-0.25), 2.4, 0.5,
                            boxstyle="round,pad=0.05",
                            facecolor=colors['gold'],
                            edgecolor='black', linewidth=1)
        ax.add_patch(box)
        ax.text(x, y, table, ha='center', va='center', fontsize=6, fontweight='bold')

    # === ANALYTICAL VIEWS & STORED PROCEDURES ===
    ax.text(10, 4.2, 'ANALYTICAL VIEWS & PROCEDURES', fontsize=12, fontweight='bold', ha='center')

    views_section = """PRODUCTION VIEWS:
    • dbo.v_transactions_flat_production (12,192 records)
    • dbo.v_transactions_flat_v24 (12,192 records)
    • dbo.v_SalesInteractionsComplete
    • dbo.v_store_health_dashboard
    • gold.v_transactions_flat_v24

    KEY STORED PROCEDURES:
    • gold.sp_extract_scout_dashboard_data
    • dbo.sp_refresh_analytics_views
    • dbo.sp_scout_health_check"""

    box = FancyBboxPatch((6, 3.2), 8, 0.8,
                        boxstyle="round,pad=0.1",
                        facecolor=colors['views'],
                        edgecolor='black', linewidth=2)
    ax.add_patch(box)
    ax.text(10, 3.6, views_section, ha='center', va='center', fontsize=7)

    # === API LAYER ===
    ax.text(10, 2.7, 'API LAYER', fontsize=12, fontweight='bold', ha='center')

    api_info = """Scout DAL Agent (/api/dash)
    Single Endpoint Bundle API
    • KPIs • Brands • Transactions
    • Store Geo • Comparisons
    Deployed: scout-dashboard-xi.vercel.app"""

    box = FancyBboxPatch((7, 2), 6, 0.6,
                        boxstyle="round,pad=0.1",
                        facecolor=colors['api'],
                        edgecolor='black', linewidth=2)
    ax.add_patch(box)
    ax.text(10, 2.3, api_info, ha='center', va='center', fontsize=8, fontweight='bold')

    # === DATA VOLUMES ===
    ax.text(1.5, 1.5, 'PRODUCTION DATA VOLUMES', fontsize=10, fontweight='bold')

    volumes_text = """📊 REAL PRODUCTION SCALE:
    • SalesInteractions: 165,485 records (6 months)
    • PayloadTransactions: 12,192 records
    • Active Stores: 13 locations
    • Device Coverage: 15 IoT devices
    • Facial Recognition: 91.7% coverage
    • Audio Transcription: 44.2% coverage
    • Date Range: Apr 2025 - Sep 2025"""

    ax.text(1.5, 0.8, volumes_text, fontsize=7, va='top')

    # === TECHNICAL ARCHITECTURE ===
    ax.text(12, 1.5, 'TECHNICAL STACK', fontsize=10, fontweight='bold')

    tech_text = """🏗️ ARCHITECTURE:
    • Database: Azure SQL Server
    • ETL: Medallion Architecture (Bronze→Silver→Gold)
    • CDC: Real-time change data capture
    • API: Next.js 14 serverless functions
    • Frontend: React with TypeScript
    • Deployment: Vercel Edge Functions
    • Authentication: Bearer token"""

    ax.text(12, 0.8, tech_text, fontsize=7, va='top')

    # === FLOW ARROWS ===
    # Sources to Staging
    for i in range(5):
        x_start = 2 + i * 4
        arrow = ConnectionPatch((x_start, 11.7), (3 + i*2, 10.4), "data", "data",
                              arrowstyle="->", shrinkA=5, shrinkB=5, mutation_scale=20, fc="black")
        ax.add_patch(arrow)

    # Staging to Bronze
    arrow1 = ConnectionPatch((3, 10), (6, 9.1), "data", "data",
                           arrowstyle="->", shrinkA=5, shrinkB=5, mutation_scale=20, fc="black")
    ax.add_patch(arrow1)

    # Bronze to Silver
    arrow2 = ConnectionPatch((6, 8.5), (6, 7.1), "data", "data",
                           arrowstyle="->", shrinkA=5, shrinkB=5, mutation_scale=20, fc="black")
    ax.add_patch(arrow2)

    # Silver to Gold
    arrow3 = ConnectionPatch((6, 6.5), (6, 5.6), "data", "data",
                           arrowstyle="->", shrinkA=5, shrinkB=5, mutation_scale=20, fc="black")
    ax.add_patch(arrow3)

    # Gold to Views
    arrow4 = ConnectionPatch((8, 4.9), (10, 4.2), "data", "data",
                           arrowstyle="->", shrinkA=5, shrinkB=5, mutation_scale=20, fc="black")
    ax.add_patch(arrow4)

    # Views to API
    arrow5 = ConnectionPatch((10, 3.2), (10, 2.8), "data", "data",
                           arrowstyle="->", shrinkA=5, shrinkB=5, mutation_scale=20, fc="black")
    ax.add_patch(arrow5)

    # === LEGEND ===
    legend_elements = [
        mpatches.Patch(color=colors['source'], label='Data Sources'),
        mpatches.Patch(color=colors['staging'], label='Staging Layer'),
        mpatches.Patch(color=colors['bronze'], label='Bronze Layer (Raw)'),
        mpatches.Patch(color=colors['silver'], label='Silver Layer (Cleaned)'),
        mpatches.Patch(color=colors['gold'], label='Gold Layer (Business Ready)'),
        mpatches.Patch(color=colors['views'], label='Views & Procedures'),
        mpatches.Patch(color=colors['api'], label='API Layer'),
        mpatches.Patch(color=colors['cdc'], label='CDC (Change Data Capture)')
    ]

    ax.legend(handles=legend_elements, loc='upper right', bbox_to_anchor=(0.98, 0.98), fontsize=8)

    plt.tight_layout()
    plt.savefig('scout_etl_flow_diagram.png', dpi=300, bbox_inches='tight')
    plt.savefig('scout_etl_flow_diagram.pdf', bbox_inches='tight')

    print("✅ Scout ETL Flow Diagram saved as:")
    print("   📊 scout_etl_flow_diagram.png")
    print("   📄 scout_etl_flow_diagram.pdf")

    plt.show()

if __name__ == "__main__":
    create_scout_etl_diagram()