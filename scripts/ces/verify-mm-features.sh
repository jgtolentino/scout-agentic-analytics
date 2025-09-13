#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_RO_URL:?Missing DATABASE_RO_URL (RO conn string)}"

echo "== Checking multimodal feature coverage =="

# SQL query to check distinct feature keys and campaign coverage
psql "$DATABASE_RO_URL" -v ON_ERROR_STOP=1 -At -F $'\t' <<'SQL' > docs/ces/verification/mm_status.tsv
with cf as (
  select cf.*, lower(coalesce(cf.extractor,'')) as ex
  from ces.creative_features cf
),
kv as (
  select (jsonb_each(feature)).key as k
  from cf
  where ex ~ '^(mm|kit|clip|librosa|whisper|opencv)'
),
feature_keys as (
  select distinct k as feature_key
  from kv
),
campaign_coverage as (
  select cf.campaign_id
  from cf
  where ex ~ '^(mm|kit|clip|librosa|whisper|opencv)'
  group by cf.campaign_id
  having count(distinct cf.asset_id) >= 1
)
select 
  'feature_keys' as metric,
  count(*)::text as value
from feature_keys
union all
select 
  'campaigns_with_mm' as metric,
  count(*)::text as value
from campaign_coverage;
SQL

# Read results from TSV file
FEATURE_KEYS=$(awk -F$'\t' '$1 == "feature_keys" {print $2}' docs/ces/verification/mm_status.tsv)
CAMPAIGNS_WITH_MM=$(awk -F$'\t' '$1 == "campaigns_with_mm" {print $2}' docs/ces/verification/mm_status.tsv)

# Validate results
if [[ -z "$FEATURE_KEYS" || -z "$CAMPAIGNS_WITH_MM" ]]; then
  echo "❌ ERROR: Failed to retrieve feature metrics"
  cat docs/ces/verification/mm_status.tsv
  exit 1
fi

echo "📊 Current Status:"
echo "   Feature Keys: $FEATURE_KEYS"
echo "   Campaigns with MM: $CAMPAIGNS_WITH_MM"

# Check gates
FEATURE_TARGET=135
CAMPAIGN_TARGET=37

FEATURE_PASS="false"
CAMPAIGN_PASS="false"

if [[ "$FEATURE_KEYS" -ge $FEATURE_TARGET ]]; then
  FEATURE_PASS="true"
  echo "✅ Feature keys: $FEATURE_KEYS >= $FEATURE_TARGET (PASS)"
else
  echo "❌ Feature keys: $FEATURE_KEYS < $FEATURE_TARGET (FAIL)"
fi

if [[ "$CAMPAIGNS_WITH_MM" -ge $CAMPAIGN_TARGET ]]; then
  CAMPAIGN_PASS="true"
  echo "✅ Campaign coverage: $CAMPAIGNS_WITH_MM >= $CAMPAIGN_TARGET (PASS)"
else
  echo "❌ Campaign coverage: $CAMPAIGNS_WITH_MM < $CAMPAIGN_TARGET (FAIL)"
fi

# Overall status
if [[ "$FEATURE_PASS" == "true" && "$CAMPAIGN_PASS" == "true" ]]; then
  echo ""
  echo "🎯 MULTIMODAL COVERAGE: ✅ PASS"
  echo "   Both feature extraction and campaign coverage meet targets"
else
  echo ""
  echo "🚨 MULTIMODAL COVERAGE: ❌ FAIL"
  echo "   Targets not met - consider re-extraction"
  
  # Check if re-extraction should be triggered
  if [[ "${RUN_REEXTRACT:-0}" == "1" ]]; then
    echo ""
    echo "🔄 TRIGGERING RE-EXTRACTION..."
    echo "   This would normally trigger the multimodal re-extraction pipeline"
    echo "   (Pipeline integration not implemented in this verification script)"
  fi
fi

echo ""
echo "📋 Verification complete - see docs/ces/verification/mm_status.tsv for raw data"