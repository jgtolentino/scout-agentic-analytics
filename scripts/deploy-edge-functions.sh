#!/bin/bash
# ============================================================================
# Deploy Scout Edge Functions
# 
# This script deploys all edge functions for the scout data pipeline
# Uses Supabase CLI or MCP if available
# ============================================================================
set -euo pipefail

# Load environment
if [ -f scripts/secrets.sh ]; then
  source scripts/secrets.sh
fi

# Check for required env vars
REQUIRED_VARS=(
  "SUPABASE_PROJECT_REF"
  "SUPABASE_ACCESS_TOKEN"
)

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "❌ Missing required environment variable: $var"
    exit 1
  fi
done

echo "🚀 Deploying Scout Edge Functions..."

# Function to deploy with Supabase CLI
deploy_function() {
  local func_name=$1
  local env_vars=$2
  
  echo "📦 Deploying $func_name..."
  
  if [ -n "$env_vars" ]; then
    supabase functions deploy "$func_name" \
      --project-ref "$SUPABASE_PROJECT_REF" \
      --no-verify-jwt \
      $env_vars
  else
    supabase functions deploy "$func_name" \
      --project-ref "$SUPABASE_PROJECT_REF" \
      --no-verify-jwt
  fi
}

# Deploy scout-ingest function
deploy_function "scout-ingest" ""

# Deploy storage-webhook function
deploy_function "storage-webhook" ""

# Deploy edge-monitor function
MONITOR_ENV=""
if [ -n "${ALERT_WEBHOOK_URL:-}" ]; then
  MONITOR_ENV="--env-file <(echo ALERT_WEBHOOK_URL=$ALERT_WEBHOOK_URL)"
fi
deploy_function "edge-monitor" "$MONITOR_ENV"

echo "✅ Edge Functions deployed successfully!"

# Set up database webhooks
echo "📝 Setting up database webhooks..."

cat << EOF
To complete the setup, configure a Database Webhook in Supabase Dashboard:

1. Go to: https://supabase.com/dashboard/project/$SUPABASE_PROJECT_REF/database/webhooks
2. Click "Create a new webhook"
3. Configure:
   - Name: storage-upload-trigger
   - Table: storage.objects
   - Events: INSERT
   - Type: HTTP Request
   - URL: https://$SUPABASE_PROJECT_REF.functions.supabase.co/storage-webhook
   - HTTP Headers:
     Content-Type: application/json
     Authorization: Bearer [your-service-role-key]

Alternatively, run the SQL trigger setup:
psql \$PGURI < scripts/setup-storage-triggers.sql
EOF

# Create cron job for monitoring
echo "⏰ Setting up monitoring schedule..."

cat > supabase/functions/edge-monitor/cron.yaml << EOF
schedule: "*/15 * * * *"  # Every 15 minutes
timezone: "UTC"
EOF

echo "🎯 Next steps:"
echo "1. Test upload: curl -X POST your-edge-function-url/scout-ingest"
echo "2. Monitor health: curl your-edge-function-url/edge-monitor"
echo "3. Check logs: supabase functions logs scout-ingest --project-ref $SUPABASE_PROJECT_REF"