# Supabase MCP Server Setup Fix

## Issue
The MCP Supabase server is configured but showing "read-only mode" or "unauthorized" errors.

## Root Cause
Environment variable `SUPABASE_ENTERPRISE_TOKEN` is not set or accessible to the MCP server.

## Quick Fix

### Step 1: Set Environment Variable
```bash
# Get your service role key from Supabase Dashboard > Settings > API
export SUPABASE_ENTERPRISE_TOKEN="your_actual_service_role_key_here"
```

### Step 2: Verify MCP Configuration
The current config in CLAUDE.md should work:
```json
{
  "mcpServers": {
    "supabase_enterprise": {
      "command": "npx",
      "args": ["@supabase/mcp-server-supabase@latest"],
      "env": {
        "SUPABASE_PROJECT_REF": "cxzllzyxwpyptfretryc",
        "SUPABASE_ACCESS_TOKEN": "${SUPABASE_ENTERPRISE_TOKEN}",
        "SUPABASE_ROLE": "service_role"
      }
    }
  }
}
```

### Step 3: Alternative Direct Setup
If environment variables aren't working, create a direct config:

```json
{
  "mcpServers": {
    "supabase_enterprise": {
      "command": "npx",
      "args": ["@supabase/mcp-server-supabase@latest"],
      "env": {
        "SUPABASE_PROJECT_REF": "cxzllzyxwpyptfretryc",
        "SUPABASE_ACCESS_TOKEN": "sbp_your_actual_service_role_key",
        "SUPABASE_ROLE": "service_role"
      }
    }
  }
}
```

## Now Execute Database Setup

Once the MCP server has proper access, run these commands:

### 1. Create Schema
```bash
# This should now work with proper permissions
```

### 2. Create Tables
```bash
# Execute the full schema creation
```

### 3. Run Migration
```bash
cd /Users/tbwa/agents/production/scripts
python3 migrate_agents_to_registry.py \
  --supabase-url "https://cxzllzyxwpyptfretryc.supabase.co" \
  --supabase-key "$SUPABASE_ENTERPRISE_TOKEN"
```

## Manual SQL Alternative

If MCP still doesn't work, go directly to Supabase Dashboard:
1. Open https://supabase.com/dashboard/project/cxzllzyxwpyptfretryc
2. Go to SQL Editor
3. Copy and paste `/Users/tbwa/agents/production/unified-agent-registry-schema.sql`
4. Click Run

This will create the entire agent registry database schema.