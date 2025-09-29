#!/usr/bin/env bash
#
# Generate ERD (Entity Relationship Diagram) from Scout v7 database
# Automatically creates Graphviz DOT file and renders to PNG
# Created: 2025-09-26
#

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/out/erd"

# Color output functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create output directory
create_output_dir() {
    mkdir -p "$OUTPUT_DIR"
    log_info "Output directory: $OUTPUT_DIR"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check for Graphviz
    if ! command -v dot &> /dev/null; then
        log_error "Graphviz not found. Please install:"
        echo "  macOS: brew install graphviz"
        echo "  Ubuntu: sudo apt-get install graphviz"
        echo "  Windows: choco install graphviz"
        exit 1
    fi

    # Check for database connection
    if ! ./scripts/sql.sh -Q "SELECT 1" > /dev/null 2>&1; then
        log_error "Database connection failed. Check your connection settings."
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Generate ERD DOT file
generate_dot_file() {
    log_info "Generating ERD DOT file from database schema..."

    local dot_file="$OUTPUT_DIR/scout_v7_erd.dot"

    # Create DOT file header
    cat > "$dot_file" << 'EOF'
digraph "Scout_v7_ERD" {
    // Graph configuration
    rankdir=LR;
    concentrate=true;
    overlap=false;
    splines=true;
    nodesep=0.6;
    ranksep=1.2;

    // Node styling
    node [
        shape=box,
        style="rounded,filled",
        fontname="Helvetica",
        fontsize=10,
        margin=0.1
    ];

    // Edge styling
    edge [
        fontname="Helvetica",
        fontsize=8,
        color="#666666",
        arrowhead=open
    ];

    // Schema clusters
    subgraph cluster_canonical {
        label="canonical";
        style=filled;
        color="#E8F4FD";
        fontsize=12;
        fontname="Helvetica-Bold";
    }

    subgraph cluster_dbo {
        label="dbo (Dimensions)";
        style=filled;
        color="#FFF2E8";
        fontsize=12;
        fontname="Helvetica-Bold";
    }

    subgraph cluster_intel {
        label="intel (Analytics)";
        style=filled;
        color="#F0FFF0";
        fontsize=12;
        fontname="Helvetica-Bold";
    }

    subgraph cluster_mart {
        label="mart (Views)";
        style=filled;
        color="#FFF8DC";
        fontsize=12;
        fontname="Helvetica-Bold";
    }

    subgraph cluster_dim {
        label="dim";
        style=filled;
        color="#F5F5F5";
        fontsize=12;
        fontname="Helvetica-Bold";
    }

    // Node color coding by schema
EOF

    # Get schema-based node colors
    ./scripts/sql.sh -Q "
        SELECT DISTINCT
            CONCAT('    \"', s.name, '.', o.name, '\" [fillcolor=\"',
                CASE s.name
                    WHEN 'canonical' THEN '#B3D9FF'
                    WHEN 'dbo' THEN '#FFD4B3'
                    WHEN 'intel' THEN '#C8E6C8'
                    WHEN 'mart' THEN '#FFFACD'
                    WHEN 'dim' THEN '#E8E8E8'
                    ELSE '#F0F0F0'
                END,
                '\"];') AS node_definition
        FROM sys.objects o
        JOIN sys.schemas s ON s.schema_id = o.schema_id
        WHERE o.type IN ('U','V')
            AND s.name NOT IN ('sys', 'INFORMATION_SCHEMA')
        ORDER BY s.name, o.name;
    " >> "$dot_file"

    echo "" >> "$dot_file"
    echo "    // Foreign key relationships" >> "$dot_file"

    # Get foreign key relationships for edges
    ./scripts/sql.sh -Q "
        WITH fk_relationships AS (
            SELECT
                pk_schema = sch1.name,
                pk_table = t1.name,
                pk_column = c1.name,
                fk_schema = sch2.name,
                fk_table = t2.name,
                fk_column = c2.name,
                fk_name = f.name
            FROM sys.foreign_keys f
            JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = f.object_id
            JOIN sys.tables t1 ON t1.object_id = f.referenced_object_id
            JOIN sys.schemas sch1 ON sch1.schema_id = t1.schema_id
            JOIN sys.columns c1 ON c1.object_id = t1.object_id AND c1.column_id = fkc.referenced_column_id
            JOIN sys.tables t2 ON t2.object_id = f.parent_object_id
            JOIN sys.schemas sch2 ON sch2.schema_id = t2.schema_id
            JOIN sys.columns c2 ON c2.object_id = t2.object_id AND c2.column_id = fkc.parent_column_id
        )
        SELECT
            CONCAT('    \"', pk_schema, '.', pk_table, '\" -> \"', fk_schema, '.', fk_table, '\" [label=\"', LEFT(fk_name, 15), '\"];') AS erd_edge
        FROM fk_relationships
        ORDER BY pk_schema, pk_table, fk_schema, fk_table;
    " >> "$dot_file"

    # Close DOT file
    echo "}" >> "$dot_file"

    log_success "DOT file generated: $dot_file"
}

# Render ERD to various formats
render_erd() {
    log_info "Rendering ERD to multiple formats..."

    local dot_file="$OUTPUT_DIR/scout_v7_erd.dot"

    # PNG (high quality)
    if dot -Tpng "$dot_file" -o "$OUTPUT_DIR/scout_v7_erd.png" 2>/dev/null; then
        log_success "PNG rendered: $OUTPUT_DIR/scout_v7_erd.png"
    else
        log_warning "PNG rendering failed"
    fi

    # SVG (scalable)
    if dot -Tsvg "$dot_file" -o "$OUTPUT_DIR/scout_v7_erd.svg" 2>/dev/null; then
        log_success "SVG rendered: $OUTPUT_DIR/scout_v7_erd.svg"
    else
        log_warning "SVG rendering failed"
    fi

    # PDF (print quality)
    if dot -Tpdf "$dot_file" -o "$OUTPUT_DIR/scout_v7_erd.pdf" 2>/dev/null; then
        log_success "PDF rendered: $OUTPUT_DIR/scout_v7_erd.pdf"
    else
        log_warning "PDF rendering failed"
    fi

    # Large PNG for complex diagrams
    if dot -Tpng -Gdpi=300 "$dot_file" -o "$OUTPUT_DIR/scout_v7_erd_hires.png" 2>/dev/null; then
        log_success "High-res PNG rendered: $OUTPUT_DIR/scout_v7_erd_hires.png"
    else
        log_warning "High-res PNG rendering failed"
    fi
}

# Generate simplified ERD (core tables only)
generate_simplified_erd() {
    log_info "Generating simplified ERD (core tables only)..."

    local simplified_dot="$OUTPUT_DIR/scout_v7_erd_simplified.dot"

    # Create simplified DOT file header
    cat > "$simplified_dot" << 'EOF'
digraph "Scout_v7_ERD_Simplified" {
    rankdir=LR;
    node [shape=box, style="rounded,filled", fontname="Helvetica", fontsize=10];
    edge [fontname="Helvetica", fontsize=8, color="#666666"];

EOF

    # Get only core tables (fact tables, main dimensions)
    ./scripts/sql.sh -Q "
        WITH core_tables AS (
            SELECT s.name AS schema_name, o.name AS table_name
            FROM sys.objects o
            JOIN sys.schemas s ON s.schema_id = o.schema_id
            WHERE o.type = 'U'
                AND (
                    o.name LIKE '%Fact' OR
                    o.name LIKE '%transaction%' OR
                    o.name LIKE '%sales%' OR
                    o.name IN ('Stores', 'Brands', 'Products', 'Region', 'Province') OR
                    s.name = 'canonical'
                )
                AND s.name NOT IN ('sys', 'INFORMATION_SCHEMA')
        )
        SELECT DISTINCT
            CONCAT('    \"', schema_name, '.', table_name, '\" [fillcolor=\"',
                CASE schema_name
                    WHEN 'canonical' THEN '#B3D9FF'
                    WHEN 'dbo' THEN '#FFD4B3'
                    ELSE '#F0F0F0'
                END,
                '\"];') AS node_definition
        FROM core_tables
        ORDER BY schema_name, table_name;
    " >> "$simplified_dot"

    echo "" >> "$simplified_dot"

    # Get FKs for core tables only
    ./scripts/sql.sh -Q "
        WITH core_tables AS (
            SELECT o.object_id, s.name AS schema_name, o.name AS table_name
            FROM sys.objects o
            JOIN sys.schemas s ON s.schema_id = o.schema_id
            WHERE o.type = 'U'
                AND (
                    o.name LIKE '%Fact' OR
                    o.name LIKE '%transaction%' OR
                    o.name LIKE '%sales%' OR
                    o.name IN ('Stores', 'Brands', 'Products', 'Region', 'Province') OR
                    s.name = 'canonical'
                )
        ),
        core_fks AS (
            SELECT
                pk_schema = sch1.name,
                pk_table = t1.name,
                fk_schema = sch2.name,
                fk_table = t2.name,
                fk_name = f.name
            FROM sys.foreign_keys f
            JOIN sys.tables t1 ON t1.object_id = f.referenced_object_id
            JOIN sys.schemas sch1 ON sch1.schema_id = t1.schema_id
            JOIN sys.tables t2 ON t2.object_id = f.parent_object_id
            JOIN sys.schemas sch2 ON sch2.schema_id = t2.schema_id
            WHERE EXISTS (SELECT 1 FROM core_tables ct1 WHERE ct1.object_id = t1.object_id)
                AND EXISTS (SELECT 1 FROM core_tables ct2 WHERE ct2.object_id = t2.object_id)
        )
        SELECT
            CONCAT('    \"', pk_schema, '.', pk_table, '\" -> \"', fk_schema, '.', fk_table, '\" [label=\"', LEFT(fk_name, 10), '\"];') AS erd_edge
        FROM core_fks
        ORDER BY pk_schema, pk_table, fk_schema, fk_table;
    " >> "$simplified_dot"

    echo "}" >> "$simplified_dot"

    # Render simplified ERD
    if dot -Tpng "$simplified_dot" -o "$OUTPUT_DIR/scout_v7_erd_simplified.png" 2>/dev/null; then
        log_success "Simplified ERD rendered: $OUTPUT_DIR/scout_v7_erd_simplified.png"
    else
        log_warning "Simplified ERD rendering failed"
    fi
}

# Generate statistics
generate_statistics() {
    log_info "Generating ERD statistics..."

    local stats_file="$OUTPUT_DIR/erd_statistics.txt"

    cat > "$stats_file" << EOF
Scout v7 Database ERD Statistics
Generated: $(date)
================================

EOF

    # Get schema counts
    ./scripts/sql.sh -Q "
        SELECT
            'Schema: ' + s.name + ' - Tables: ' + CAST(COUNT(*) AS VARCHAR) AS summary
        FROM sys.tables t
        JOIN sys.schemas s ON s.schema_id = t.schema_id
        WHERE s.name NOT IN ('sys', 'INFORMATION_SCHEMA')
        GROUP BY s.name
        ORDER BY s.name;
    " >> "$stats_file"

    echo "" >> "$stats_file"

    # Get FK count
    ./scripts/sql.sh -Q "
        SELECT 'Total Foreign Keys: ' + CAST(COUNT(*) AS VARCHAR) AS fk_count
        FROM sys.foreign_keys;
    " >> "$stats_file"

    echo "" >> "$stats_file"
    echo "Files generated:" >> "$stats_file"
    echo "- scout_v7_erd.png (full ERD)" >> "$stats_file"
    echo "- scout_v7_erd.svg (scalable)" >> "$stats_file"
    echo "- scout_v7_erd.pdf (print)" >> "$stats_file"
    echo "- scout_v7_erd_simplified.png (core tables)" >> "$stats_file"
    echo "- scout_v7_erd.dot (source)" >> "$stats_file"

    log_success "Statistics saved: $stats_file"
}

# Main execution
main() {
    log_info "Starting Scout v7 ERD generation..."

    create_output_dir
    check_prerequisites
    generate_dot_file
    render_erd
    generate_simplified_erd
    generate_statistics

    log_success "ERD generation completed!"
    echo ""
    echo "Generated files:"
    ls -la "$OUTPUT_DIR"
    echo ""
    echo "View the ERD:"
    echo "  Full ERD: open $OUTPUT_DIR/scout_v7_erd.png"
    echo "  Core ERD: open $OUTPUT_DIR/scout_v7_erd_simplified.png"
}

# Help function
show_help() {
    cat << EOF
Scout v7 ERD Generator

Usage: $0 [OPTIONS]

Options:
    -h, --help          Show this help message
    --simplified-only   Generate only simplified ERD
    --full-only         Generate only full ERD

Output:
    All files are created in: $OUTPUT_DIR/

Files generated:
    - scout_v7_erd.png          Full ERD diagram (PNG)
    - scout_v7_erd.svg          Full ERD diagram (SVG)
    - scout_v7_erd.pdf          Full ERD diagram (PDF)
    - scout_v7_erd_simplified.png   Core tables only (PNG)
    - scout_v7_erd.dot          Graphviz DOT source
    - erd_statistics.txt        Generation statistics

Prerequisites:
    - Graphviz (dot command)
    - Database connection via scripts/sql.sh

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --simplified-only)
            SIMPLIFIED_ONLY=1
            shift
            ;;
        --full-only)
            FULL_ONLY=1
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Execute main function
main "$@"