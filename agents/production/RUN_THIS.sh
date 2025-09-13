#!/bin/bash

# IMMEDIATE DEPLOYMENT SCRIPT - NO BULLSHIT
# Run this after setting your Supabase service role key

echo "Setting up Supabase environment..."
export SUPABASE_URL="https://cxzllzyxwpyptfretryc.supabase.co"

# YOU NEED TO SET THIS - Get from Supabase Dashboard > Settings > API
if [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    echo "ERROR: Set SUPABASE_SERVICE_ROLE_KEY environment variable"
    echo "Get it from: https://supabase.com/dashboard/project/cxzllzyxwpyptfretryc/settings/api"
    exit 1
fi

echo "Running agent discovery and migration..."
cd /Users/tbwa/agents/production/scripts

# Run the migration
python3 migrate_agents_to_registry.py \
    --supabase-url "$SUPABASE_URL" \
    --supabase-key "$SUPABASE_SERVICE_ROLE_KEY"

echo "Migration complete!"
echo "Check the migration report at: /Users/tbwa/agents/production/migration_report.txt"