# Production Agent Registry Database Setup Guide

## Overview
This guide walks through setting up the unified agent registry in Supabase for the TBWA Enterprise Platform.

## Prerequisites
- Access to Supabase project dashboard
- Service role key configured in environment variables
- Python 3.8+ with required packages installed

## Step 1: Execute Database Schema

### Option A: Via Supabase SQL Editor (Recommended)
1. Log into your Supabase project dashboard
2. Navigate to SQL Editor
3. Create a new query
4. Copy the entire contents of `/Users/tbwa/agents/production/unified-agent-registry-schema.sql`
5. Execute the query

The schema will create:
- `agent_registry` schema
- 15+ tables for agent management
- Row Level Security policies
- Performance indexes
- Helper functions and triggers
- Initial seed data for core agents

### Option B: Via Supabase CLI
```bash
cd /Users/tbwa/agents/production
supabase db push --db-url $DATABASE_URL < unified-agent-registry-schema.sql
```

## Step 2: Verify Schema Creation

Run this query in SQL Editor to verify:
```sql
-- Check tables created
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'agent_registry'
ORDER BY table_name;

-- Check initial agents
SELECT agent_name, agent_type, version, status 
FROM agent_registry.agents
ORDER BY agent_name;
```

Expected results:
- 10+ tables in agent_registry schema
- 4 initial agents (Orchestrator, Lyra-Primary, Lyra-Secondary, Master-Toggle, Iska)

## Step 3: Run Agent Migration

### Dry Run First
```bash
cd /Users/tbwa/agents/production/scripts
python migrate_agents_to_registry.py --dry-run
```

This will:
- Discover all agent files in the repository
- Validate production readiness
- Generate a migration report
- Show what would be migrated (without changes)

### Execute Migration
```bash
python migrate_agents_to_registry.py
```

This will:
- Insert/update all discovered agents
- Set appropriate status (active/inactive)
- Create audit log entries
- Generate migration report at `/Users/tbwa/agents/production/migration_report.txt`

## Step 4: Deploy AI Agent Auditor

The AI Agent Auditor will continuously monitor all agents for OATH compliance:

```bash
cd /Users/tbwa/agents/production/ai-agent-auditor/scripts

# Run initial audit
python audit_agent.py

# Check results
cat audit/audit_report_latest.json
```

## Step 5: Deploy Production Agents

Deploy key agents using the deployment script:

```bash
cd /Users/tbwa/agents/production/scripts

# Deploy Lyra Primary
./deploy_agent.sh Lyra-Primary

# Deploy Master Toggle
./deploy_agent.sh Master-Toggle

# Deploy Iska
./deploy_agent.sh Iska
```

## Database Tables Overview

### Core Tables
- `agents` - Main agent registry
- `agent_health` - Health monitoring data
- `agent_messages` - Inter-agent communication
- `audit_log` - Comprehensive audit trail

### Lyra-Specific Tables
- `pull_queue` - Pull-based job queue
- `lyra_audit` - Lyra-specific audit events

### Master Toggle Tables
- `master_data_registry` - Dimension value registry
- `toggle_config` - Filter/toggle configuration

### Supporting Tables
- `agent_capabilities` - Capability mappings
- `agent_endpoints` - API endpoint registry
- `oath_profiles` - OATH compliance profiles

## Security Considerations

1. **Row Level Security (RLS)** is enabled on all tables
2. **Service role** has full access
3. **Authenticated users** have read-only access to core tables
4. All sensitive operations require service_role key

## Monitoring & Maintenance

### Health Check Query
```sql
-- Check agent health status
SELECT * FROM agent_registry.active_agents
ORDER BY last_health_check DESC;
```

### Performance Metrics
```sql
-- View agent performance
SELECT * FROM agent_registry.agent_performance
WHERE last_activity > NOW() - INTERVAL '1 hour';
```

### Master Data Freshness
```sql
-- Check master data status
SELECT * FROM agent_registry.master_data_freshness;
```

## Troubleshooting

### Common Issues

1. **Schema creation fails**
   - Check for existing objects: `DROP SCHEMA agent_registry CASCADE;`
   - Ensure extensions are enabled
   - Verify service_role permissions

2. **Migration errors**
   - Check Supabase credentials in environment
   - Verify network connectivity
   - Review agent YAML files for syntax errors

3. **Agent deployment fails**
   - Check Kubernetes cluster connection
   - Verify Docker registry access
   - Review deployment logs

## Next Steps

1. Configure monitoring dashboards
2. Set up alerting for agent failures
3. Schedule regular OATH compliance audits
4. Implement agent-specific health checks
5. Configure production backup strategy

## Support

For issues or questions:
- Check audit logs: `SELECT * FROM agent_registry.audit_log ORDER BY event_time DESC LIMIT 50;`
- Review agent health: `SELECT * FROM agent_registry.agent_health WHERE status != 'healthy';`
- Contact: Data Platform Lead

---

Last Updated: 2025-07-18
Version: 2.0.0