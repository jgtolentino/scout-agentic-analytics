# Production Deployment Checklist

## ✅ Completed Preparation

### 1. Agent Discovery Complete
- **Found**: 25 total agents across all repositories
- **Production-Ready**: 10 agents ready for deployment
- **Report**: `/Users/tbwa/agents/production/agent_discovery_report.txt`

### 2. Database Schema Ready
- **File**: `/Users/tbwa/agents/production/unified-agent-registry-schema.sql`
- **Size**: 613 lines of enterprise-grade SQL
- **Features**: 15+ tables, RLS policies, indexes, functions, triggers

### 3. Migration Scripts Ready
- **Discovery**: `/Users/tbwa/agents/production/scripts/discover_agents.py`
- **Migration**: `/Users/tbwa/agents/production/scripts/migrate_agents_to_registry.py`
- **Deployment**: `/Users/tbwa/agents/production/scripts/deploy_agent.sh`

### 4. AI Agent Auditor Ready
- **Configuration**: `/Users/tbwa/agents/production/ai-agent-auditor/agents/auditor.yaml`
- **Script**: `/Users/tbwa/agents/production/ai-agent-auditor/scripts/audit_agent.py`
- **Schema**: `/Users/tbwa/agents/production/ai-agent-auditor/settings/oath_profile_schema.json`

## 🔄 Next Steps (Manual Execution Required)

### Step 1: Execute Database Schema
```bash
# In Supabase Dashboard > SQL Editor
# Copy and paste the entire contents of:
# /Users/tbwa/agents/production/unified-agent-registry-schema.sql
# Then click "Run"
```

**Expected Results:**
- Schema `agent_registry` created
- 15+ tables with proper relationships
- RLS policies enabled
- Initial agents (Orchestrator, Lyra-Primary, Lyra-Secondary, Master-Toggle, Iska) inserted

### Step 2: Set Environment Variables
```bash
# Set these in your shell or .env file
export SUPABASE_URL="https://your-project-ref.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
export SUPABASE_ANON_KEY="your-anon-key"
```

### Step 3: Run Migration (After Database Setup)
```bash
cd /Users/tbwa/agents/production/scripts

# Test migration first
python3 migrate_agents_to_registry.py --dry-run \
  --supabase-url "$SUPABASE_URL" \
  --supabase-key "$SUPABASE_SERVICE_ROLE_KEY"

# Execute migration
python3 migrate_agents_to_registry.py \
  --supabase-url "$SUPABASE_URL" \
  --supabase-key "$SUPABASE_SERVICE_ROLE_KEY"
```

### Step 4: Deploy Core Agents
```bash
# Deploy high-availability Lyra agents
./deploy_agent.sh Lyra-Primary

# Deploy filter management
./deploy_agent.sh Master-Toggle

# Deploy documentation intelligence
./deploy_agent.sh Iska
```

### Step 5: Start AI Agent Auditor
```bash
cd ../ai-agent-auditor/scripts
python3 audit_agent.py \
  --supabase-url "$SUPABASE_URL" \
  --supabase-key "$SUPABASE_SERVICE_ROLE_KEY"
```

## 🎯 Production Agents Ready for Deployment

### Tier 1 (Core Platform)
1. **Orchestrator** - Master coordination
2. **Lyra-Primary** - Schema inference (active)
3. **Lyra-Secondary** - Schema inference (failover)
4. **Master-Toggle** - Filter management
5. **Iska** - Documentation intelligence

### Tier 2 (Specialized)
1. **Stacey** - Analytics specialist
2. **Dash** - Dashboard engineer
3. **Fully** - Fullstack engineer
4. **KeyKey** - Environment sync
5. **Doer** - Task executor

## 📊 Expected Deployment Metrics

### Database Tables Created
- `agent_registry.agents` - Main registry
- `agent_registry.agent_health` - Health monitoring
- `agent_registry.agent_messages` - Inter-agent communication
- `agent_registry.audit_log` - Audit trail
- `agent_registry.pull_queue` - Job queue (Lyra)
- `agent_registry.master_data_registry` - Dimension registry
- `agent_registry.toggle_config` - Filter configuration
- `agent_registry.oath_profiles` - OATH compliance

### Agent Capabilities
- **25 total agents** discovered
- **10 production-ready** agents
- **5 immediate deployment** candidates
- **OATH compliance** monitoring enabled
- **High availability** with failover support

## 🚨 Prerequisites Check

Before proceeding, ensure:
- [ ] Supabase project is accessible
- [ ] Service role key has proper permissions
- [ ] Kubernetes cluster is available (for deployment)
- [ ] Docker registry is accessible
- [ ] Network connectivity to all services

## 📋 Validation Steps

After deployment, verify:
1. Database schema created successfully
2. Initial agents visible in registry
3. Migration completed without errors
4. Health monitoring active
5. OATH auditor running
6. Agent endpoints responding

## 🆘 Troubleshooting

### Common Issues:
1. **Database connection failed**: Check credentials and network access
2. **Schema creation failed**: Ensure service_role permissions
3. **Migration errors**: Verify agent YAML files are valid
4. **Deployment failures**: Check Kubernetes cluster connectivity

### Debug Commands:
```sql
-- Check schema creation
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'agent_registry';

-- Check agent count
SELECT COUNT(*) FROM agent_registry.agents;

-- Check audit logs
SELECT * FROM agent_registry.audit_log 
ORDER BY event_time DESC LIMIT 10;
```

---

**Status**: Ready for manual execution
**Next Action**: Execute database schema in Supabase SQL Editor
**Documentation**: All files prepared in `/Users/tbwa/agents/production/`