#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
SQL="$ROOT/scripts/sql.sh"
DOC="$ROOT/docs"
SCHEMA_DIR="$DOC/SCHEMA"
DATE_UTC="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
ACTOR="${GIT_AUTHOR_NAME:-$(git config user.name 2>/dev/null || echo 'unknown')}"

mkdir -p "$SCHEMA_DIR"

echo "🔍 Syncing docs from live DB..."

# 1) Object inventory (tables/views/procs)
$SQL -Q "
SELECT s.name AS schema_name,o.name AS object_name,o.type_desc
FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
WHERE o.type IN ('U','V','P') AND s.name NOT IN ('sys','INFORMATION_SCHEMA')
ORDER BY s.name,o.type_desc,o.name;" -s "," -W -h -1 > "$SCHEMA_DIR/objects.csv"

# 2) Tables with columns/PK/FK
$SQL -Q "
SELECT s.name AS schema_name,t.name AS table_name,c.column_id,c.name AS column_name,TYPE_NAME(c.user_type_id) AS type_name,c.max_length,c.is_nullable
FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
JOIN sys.columns c ON c.object_id=t.object_id
ORDER BY s.name,t.name,c.column_id;" -s "," -W -h -1 > "$SCHEMA_DIR/tables.csv"

# 3) Views (definitions)
$SQL -Q "
SELECT s.name AS schema_name,v.name AS view_name, m.definition
FROM sys.views v JOIN sys.schemas s ON s.schema_id=v.schema_id
JOIN sys.sql_modules m ON m.object_id=v.object_id
ORDER BY s.name,v.name;" -s $'\t' -W -h -1 > "$SCHEMA_DIR/views.tsv"

# 4) Procs (signatures)
$SQL -Q "
SELECT s.name AS schema_name,p.name AS proc_name, m.definition
FROM sys.procedures p JOIN sys.schemas s ON s.schema_id=p.schema_id
JOIN sys.sql_modules m ON m.object_id=p.object_id
ORDER BY s.name,p.name;" -s $'\t' -W -h -1 > "$SCHEMA_DIR/procs.tsv"

# 5) Brand mapping health
$SQL -Q "SET NOCOUNT ON;
SELECT
  total_brands          = COUNT(*),
  missing_categorycode  = SUM(CASE WHEN CategoryCode IS NULL THEN 1 ELSE 0 END),
  nielsen_mapped        = SUM(CASE WHEN CategoryCode IS NOT NULL THEN 1 ELSE 0 END)
FROM dbo.BrandCategoryMapping;" -s "," -W -h -1 > "$SCHEMA_DIR/brand_mapping_stats.csv" || {
  # Fallback if BrandCategoryMapping doesn't have CategoryCode yet
  $SQL -Q "
  SELECT
    total_brands          = COUNT(*),
    missing_categorycode  = COUNT(*),
    nielsen_mapped        = 0
  FROM dbo.BrandCategoryMapping;" -s "," -W -h -1 > "$SCHEMA_DIR/brand_mapping_stats.csv"
}

# 6) Flat view rowcount (guard)
$SQL -Q "SET NOCOUNT ON; SELECT COUNT(*) AS flat_rows FROM dbo.v_flat_export_sheet;" -s "," -W -h -1 > "$SCHEMA_DIR/flat_rows.csv"

# 7) Turn inventories into human-readable MD
{
  echo "# Tables"
  echo ""
  echo "| schema | table | column_id | column | type | max_len | nullable |"
  echo "|---|---|---:|---|---|---:|:--:|"
  awk -F',' '{printf("| %s | %s | %s | %s | %s | %s | %s |\n",$1,$2,$3,$4,$5,$6,($7==1?"YES":"NO"))}' "$SCHEMA_DIR/tables.csv"
} > "$SCHEMA_DIR/tables.md"

{
  echo "# Views"
  echo ""
  while IFS=$'\t' read -r schema view def; do
    echo "## $schema.$view"
    echo
    echo '```sql'
    echo "$def"
    echo '```'
    echo
  done < "$SCHEMA_DIR/views.tsv"
} > "$SCHEMA_DIR/views.md"

{
  echo "# Stored Procedures"
  echo ""
  while IFS=$'\t' read -r schema proc def; do
    echo "## $schema.$proc"
    echo
    echo '```sql'
    echo "$def"
    echo '```'
    echo
  done < "$SCHEMA_DIR/procs.tsv"
} > "$SCHEMA_DIR/procs.md"

{
  echo "# Brand Category Mapping Health"
  echo ""
  echo "Current brand mapping statistics from live database:"
  echo ""
  echo "| Metric | Count |"
  echo "|---|---:|"
  while IFS=',' read -r total missing mapped; do
    echo "| Total Brands | $total |"
    echo "| Missing CategoryCode | $missing |"
    echo "| Nielsen Mapped | $mapped |"
  done < "$SCHEMA_DIR/brand_mapping_stats.csv"
} > "$SCHEMA_DIR/brand_category_mapping.md"

# 8) Append to DB_CHANGELOG.md
TOTAL_OBJS=$(wc -l < "$SCHEMA_DIR/objects.csv" | tr -d ' ')
TABLES=$(grep -c ",USER_TABLE" "$SCHEMA_DIR/objects.csv" || echo "0")
VIEWS=$(grep -c ",VIEW" "$SCHEMA_DIR/objects.csv" || echo "0")
PROCS=$(grep -c ",SQL_STORED_PROCEDURE" "$SCHEMA_DIR/objects.csv" || echo "0")
# sanitize any sqlcmd noise e.g. "(1 row affected)"
FLAT_ROWS_RAW=$(head -n1 "$SCHEMA_DIR/flat_rows.csv")
MISSING_RAW=$(head -n1 "$SCHEMA_DIR/brand_mapping_stats.csv" | cut -d"," -f2)
FLAT_ROWS=$(printf "%s" "$FLAT_ROWS_RAW" | sed -E 's/[^0-9-]//g')
MISSING=$(printf "%s" "$MISSING_RAW" | sed -E 's/[^0-9-]//g')
[ -z "$FLAT_ROWS" ] && FLAT_ROWS=0
[ -z "$MISSING" ] && MISSING=0
COVERAGE_OK=$([ "$FLAT_ROWS" -gt 0 ] && echo "true" || echo "false")
MIGRATION_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | grep -E '^sql/.+\.sql$' | paste -sd',' - || echo 'manual/unknown')

echo "" >> "$DOC/DB_CHANGELOG.md"
echo "## $DATE_UTC — $ACTOR" >> "$DOC/DB_CHANGELOG.md"
echo "- Migration(s): $MIGRATION_FILES" >> "$DOC/DB_CHANGELOG.md"
echo "- Objects: $TOTAL_OBJS (tables $TABLES, views $VIEWS, procs $PROCS)" >> "$DOC/DB_CHANGELOG.md"
echo "- Summary: auto-doc sync" >> "$DOC/DB_CHANGELOG.md"
echo "- Checks:" >> "$DOC/DB_CHANGELOG.md"
echo "  - Coverage OK: $COVERAGE_OK" >> "$DOC/DB_CHANGELOG.md"
echo "  - Flat view rows: $FLAT_ROWS" >> "$DOC/DB_CHANGELOG.md"
echo "  - Brands missing CategoryCode: ${MISSING:-0}" >> "$DOC/DB_CHANGELOG.md"

echo "✅ doc-sync complete - generated docs/SCHEMA/*.md and updated DB_CHANGELOG.md"