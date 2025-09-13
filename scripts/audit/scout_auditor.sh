#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?missing}"; : "${SUPABASE_URL:?missing}"; : "${SUPABASE_SERVICE_ROLE_KEY:?missing}"; : "${MINDSDB_URL:?missing}"
RED=$(tput setaf 1 || true); GRN=$(tput setaf 2 || true); YLW=$(tput setaf 3 || true); NC=$(tput sgr0 || true)
ok(){ printf "%b✔%b %s\n" "$GRN" "$NC" "$1"; } bad(){ printf "%b✖%b %s\n" "$RED" "$NC" "$1"; FAIL=1; } warn(){ printf "%b!%b %s\n" "$YLW" "$NC" "$1"; }
psqlq(){ psql "$SUPABASE_DB_URL" -Atc "$1" 2>/dev/null || true; } exists(){ [ "$(psqlq "select to_regclass('$1') is not null")" = "t" ]; }
FAIL=0; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

echo "== Scout v7 Auditor (CI) =="

# DB reachability
psqlq "select now()" >/dev/null && ok "DB reachable" || bad "DB unreachable"

# ETL/timestamps
for obj in "staging.drive_skus" "staging.azure_products" "ops.brand_merge_summary" "masterdata.brands" "masterdata.brand_aliases"; do
  exists "$obj" && ok "exists: $obj" || warn "missing: $obj"
done
colcheck=$(psqlq "select count(*) from information_schema.columns
  where table_schema='staging' and table_name='drive_skus'
  and column_name in ('resolution_attempts','resolution_last_status','resolution_last_method','resolution_last_at')")
[ "${colcheck:-0}" -ge 4 ] && ok "brand-resolution cols present on staging.drive_skus" || warn "missing brand-resolution cols"

# Pipeline diagnostics
for obj in "ops.source_inventory" "public.v_pipeline_gaps" "public.v_pipeline_summary"; do
  exists "$obj" && ok "exists: $obj" || bad "missing: $obj (Pipeline Diagnostics)"
done

# Brand resolution metrics
for obj in "ops.brand_resolution_log" "public.v_brand_resolution_metrics" "public.v_unknown_brands_daily"; do
  exists "$obj" && ok "exists: $obj" || bad "missing: $obj (Brand Resolution)"
done

# DQ unmatched
for obj in "staging.azure_inferences" "staging.google_payloads" "ops.unmatched_inference_log" "ops.unmatched_payload_log" "public.v_dq_unmatched" "public.v_dq_unmatched_daily"; do
  exists "$obj" && ok "exists: $obj" || bad "missing: $obj (DQ flags)"
done

# Recommendations + task_id
exists "scout.recommendations" && ok "exists: scout.recommendations" || bad "missing: scout.recommendations"
tidcol=$(psqlq "select count(*) from information_schema.columns where table_schema='scout' and table_name='recommendations' and column_name='task_id'")
[ "${tidcol:-0}" -eq 1 ] && ok "task_id column present" || bad "task_id column missing"
nulltid=$(psqlq "select count(*) from scout.recommendations where coalesce(task_id,'')=''")
[ "${nulltid:-0}" -eq 0 ] && ok "all recommendations have task_id" || bad "recommendations missing task_id: ${nulltid:-?}"

# Forecasts (platinum)
exists "scout.platinum_predictions_revenue_14d" && ok "exists: scout.platinum_predictions_revenue_14d" || bad "missing: platinum predictions table"
fcnt=$(psqlq "select count(*) from scout.platinum_predictions_revenue_14d where day>=current_date and day<current_date+15")
[ "${fcnt:-0}" -gt 0 ] && ok "forecasts present next 14d ($fcnt rows)" || warn "no forecasts next 14d (run forecast-refresh)"

# Edge Functions probe (401/405/200 all prove deploy)
probe(){ url="$SUPABASE_URL/functions/v1/$1"; code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$url" -H 'Content-Type: application/json' || echo "000"); 
  if [[ "$code" =~ ^(200|401|405)$ ]]; then ok "Edge function deployed: $1 ($code)"; else bad "Edge function not reachable: $1 ($code)"; fi; }
for fn in inventory-report ingest-azure-infer ingest-google-json mindsdb-query forecast-refresh; do probe "$fn"; done

# MindsDB up
code=$(curl -s -o "$tmp/mdb.json" -w "%{http_code}" -X POST "$MINDSDB_URL/api/sql/query" -H 'Content-Type: application/json' --data-binary '{"query":"SHOW DATABASES;"}' || echo "000")
[ "$code" = "200" ] && ok "MindsDB SQL endpoint OK" || bad "MindsDB endpoint failed ($code)"

# UI files present (best-effort)
for f in "PipelineDiagnostics.tsx" "BrandResolutionCard.tsx" "DataQualityFlags.tsx" "ForecastCard.tsx" "MindsDBInsights.tsx"; do
  [ -f "src/components/$f" ] && ok "UI: $f" || warn "UI missing: src/components/$f"
done

if [ "$FAIL" = "1" ]; then echo -e "${RED}✖ FAIL${NC} — critical gaps found"; exit 1; else echo -e "${GRN}✔ PASS${NC} — core checks passed"; fi
