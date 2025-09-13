# Scout v7.1 Deployment Guide

**Scout v7.1 Agentic Analytics Platform** - Complete deployment and operations guide for transforming Scout Dashboard from basic ETL/BI to comprehensive agentic analytics platform.

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Environment Setup](#environment-setup)
- [Database Setup](#database-setup)
- [Edge Functions Deployment](#edge-functions-deployment)
- [Agent System Deployment](#agent-system-deployment)
- [MCP Server Setup](#mcp-server-setup)
- [Verification & Testing](#verification--testing)
- [Monitoring & Maintenance](#monitoring--maintenance)
- [Troubleshooting](#troubleshooting)

## Quick Start

Deploy the complete Scout v7.1 Agentic Analytics Platform:

```bash
# 1. Complete setup and deployment
make v7-setup

# 2. Deploy to production
make v7-deploy

# 3. Verify deployment
make v7-test

# 4. Check system status
make status
```

## Prerequisites

### Required Tools
- **Supabase CLI**: Latest version (`supabase --version`)
- **Node.js**: v18+ for MCP server (`node --version`)
- **Deno**: Latest for Edge Functions (`deno --version`)
- **Python**: 3.8+ for validation scripts (`python3 --version`)
- **jq**: JSON processing (`jq --version`)

### Required Accounts & Services
- **Supabase Project**: Database and Edge Functions hosting
- **OpenAI Account**: API key for LLM inference and embeddings
- **MindsDB Cloud**: Account for predictive analytics (optional)

### Environment Variables
Create `.env` file with required variables:

```bash
# Supabase Configuration
SUPABASE_PROJECT_REF=your-project-ref
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
DATABASE_URL=postgresql://user:pass@host:port/db

# OpenAI Configuration
OPENAI_API_KEY=sk-your-openai-key

# MindsDB Configuration (Optional)
MINDSDB_HOST=cloud.mindsdb.com
MINDSDB_PORT=3306
MINDSDB_USER=your-username
MINDSDB_PASSWORD=your-password
MINDSDB_DATABASE=mindsdb
MINDSDB_TIMEOUT=30000
```

## Environment Setup

### 1. Install Dependencies

```bash
# Check system requirements
make check

# Install Supabase CLI (if not installed)
npm install -g supabase

# Install Deno (if not installed)
curl -fsSL https://deno.land/install.sh | sh

# Install Node.js dependencies for MCP server
cd tools/mcp-servers/mindsdb
npm install
cd ../../..
```

### 2. Configure Supabase

```bash
# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref $SUPABASE_PROJECT_REF

# Verify connection
supabase status
```

### 3. Load Environment Variables

```bash
# Load environment (creates .env from secrets)
make env

# Verify environment variables are loaded
echo $SUPABASE_URL
echo $OPENAI_API_KEY
```

## Database Setup

### 1. Run Migrations

Deploy the complete v7.1 schema including Bronze → Silver → Gold → Platinum layers:

```bash
# Reset database and apply all migrations
make v7-migrate
```

This creates:
- **Platinum Schema**: RAG chunks, knowledge graph, CAG tables
- **Audit System**: Comprehensive audit ledger and job tracking
- **Vector Extensions**: pgvector for similarity search
- **RLS Policies**: Tenant isolation and role-based access

### 2. Verify Database Schema

```bash
# Check platinum schema tables
supabase db diff --schema=platinum

# Verify vector extension
psql $DATABASE_URL -c "SELECT * FROM pg_extension WHERE extname = 'vector';"

# Test RLS policies
psql $DATABASE_URL -c "SELECT * FROM platinum.rag_chunks LIMIT 1;"
```

### 3. Initialize Sample Data (Optional)

```bash
# If you have sample data initialization script
python3 scripts/init_sample_data.py

# Verify data
psql $DATABASE_URL -c "SELECT COUNT(*) FROM scout.fact_transaction_item;"
```

## Edge Functions Deployment

Deploy all 5 Edge Functions for the agentic analytics pipeline:

### 1. Deploy Core Functions

```bash
# Deploy all Edge Functions
make edge-functions
```

This deploys:
- **nl2sql**: Natural language to SQL conversion with semantic awareness
- **rag-retrieve**: Hybrid search with vector similarity + BM25 + knowledge graph
- **sql-exec**: Secure SQL execution with RLS and role-based limits
- **mindsdb-proxy**: MindsDB integration for predictive analytics
- **audit-ledger**: Comprehensive audit logging and activity tracking

### 2. Verify Edge Functions

```bash
# List deployed functions
supabase functions list

# Test function endpoints
curl -X POST "$SUPABASE_URL/functions/v1/nl2sql" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"natural_language_query": "test", "user_context": {"tenant_id": "test", "role": "analyst"}}'
```

### 3. Monitor Function Logs

```bash
# Monitor function logs in real-time
supabase functions logs nl2sql --follow
supabase functions logs rag-retrieve --follow
```

## Agent System Deployment

Deploy the 4-agent system for intelligent analytics orchestration:

### 1. Build Agent System

```bash
# Validate and build all agents
make agents-build
```

This validates:
- **QueryAgent**: NL→SQL with Filipino language support
- **RetrieverAgent**: RAG + competitive intelligence
- **ChartVisionAgent**: Intelligent visualization with accessibility
- **NarrativeAgent**: Executive summaries and recommendations
- **AgentOrchestrator**: Multi-agent workflow coordination

### 2. Deploy Agents as Edge Functions

```bash
# Deploy agent implementations
make agents-deploy
```

Creates Edge Functions:
- `agents-query`: QueryAgent endpoint
- `agents-retriever`: RetrieverAgent endpoint  
- `agents-chart`: ChartVisionAgent endpoint
- `agents-narrative`: NarrativeAgent endpoint
- `agents-orchestrator`: Orchestration coordinator

### 3. Test Agent System

```bash
# Run agent integration tests
make agents-test

# Test orchestration endpoint
curl -X POST "$SUPABASE_URL/functions/v1/agents-orchestrator" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language_query": "Show me revenue trends by brand this month",
    "user_context": {"tenant_id": "demo", "role": "executive"},
    "narrative_preferences": {"audience": "executive", "tone": "formal", "length": "brief", "language": "en"}
  }'
```

## MCP Server Setup

### 1. Build MindsDB MCP Server

```bash
# Build MCP server
make mcp-build

# Test MCP server locally
make mcp-test
```

### 2. Configure MindsDB Integration

```bash
# Set MindsDB environment variables
export MINDSDB_HOST=cloud.mindsdb.com
export MINDSDB_USER=your_username
export MINDSDB_PASSWORD=your_password

# Test MindsDB connection
cd tools/mcp-servers/mindsdb
npm start
```

### 3. Deploy MCP Integration

The MCP server integrates with Edge Functions automatically through the `mindsdb-proxy` function. No separate deployment needed.

## Verification & Testing

### 1. Comprehensive Test Suite

```bash
# Run all v7.1 tests
make v7-test
```

### 2. End-to-End Integration Test

```bash
# Test complete agentic analytics flow
python3 tests/integration/test_e2e_agentic_flow.py
```

### 3. Performance Validation

```bash
# Test system performance under load
python3 tests/performance/test_agent_latency.py
```

### 4. Security Validation

```bash
# Verify RLS and security policies
python3 tests/security/test_rls_compliance.py
```

## System Status & Monitoring

### 1. Check System Status

```bash
# Comprehensive system status
make status
```

Expected output:
```
📊 Scout v7.1 Agentic Analytics Platform Status
==============================================
Database: ✅ Connected
Edge Functions: 10 deployed
Agent System: ✅ Configured
MCP Server: ✅ Available
Semantic Layer: ✅ Configured
```

### 2. Monitor System Health

```bash
# Monitor database performance
psql $DATABASE_URL -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"

# Monitor Edge Function performance
supabase functions logs --follow

# Check audit trail
psql $DATABASE_URL -c "SELECT * FROM platinum.audit_ledger ORDER BY created_at DESC LIMIT 10;"
```

### 3. Performance Metrics

Key metrics to monitor:
- **Query Response Time**: < 5s end-to-end
- **Agent Latency**: < 2s per agent
- **Database Queries**: < 200ms average
- **Vector Search**: < 1.5s retrieval
- **Memory Usage**: < 512MB per function

## Development Workflow

### 1. Local Development

```bash
# Start development server
make dev

# Clean build artifacts
make clean

# Rebuild everything
make v7-setup
```

### 2. Database Development

```bash
# Create new migration
supabase migration new your_migration_name

# Apply migration locally
supabase db reset

# Generate types
supabase gen types typescript --local
```

### 3. Function Development

```bash
# Serve functions locally
supabase functions serve

# Deploy specific function
supabase functions deploy function-name
```

## Production Deployment

### 1. Pre-deployment Checklist

- [ ] Environment variables configured
- [ ] Database migrations tested
- [ ] All tests passing (`make v7-test`)
- [ ] Performance benchmarks met
- [ ] Security review completed
- [ ] Backup strategy confirmed

### 2. Production Deployment

```bash
# Deploy to production
make v7-deploy

# Verify production deployment
make status

# Run production smoke tests
python3 tests/production/smoke_tests.py
```

### 3. Post-deployment Verification

```bash
# Verify all components
curl -f "$SUPABASE_URL/functions/v1/agents-orchestrator/health"

# Check production metrics
python3 scripts/check_production_metrics.py

# Verify data integrity
python3 scripts/verify_data_integrity.py
```

## Troubleshooting

### Common Issues

#### Database Connection Issues
```bash
# Check database connectivity
psql $DATABASE_URL -c "SELECT 1;"

# Verify environment variables
echo $DATABASE_URL
echo $SUPABASE_URL
```

#### Edge Function Deployment Failures
```bash
# Check function logs
supabase functions logs function-name

# Redeploy specific function
supabase functions deploy function-name --project-ref $SUPABASE_PROJECT_REF

# Verify function permissions
supabase functions list
```

#### Agent System Issues
```bash
# Validate agent contracts
yamllint agents/contracts.yaml

# Test individual agents
curl -X POST "$SUPABASE_URL/functions/v1/agents-query" -d '{"test": true}'

# Check orchestrator logs
supabase functions logs agents-orchestrator
```

#### MCP Server Issues
```bash
# Test MCP server locally
cd tools/mcp-servers/mindsdb
npm run dev

# Check MindsDB connection
python3 -c "import mysql.connector; mysql.connector.connect(host='cloud.mindsdb.com')"
```

### Performance Issues

#### Slow Query Performance
```bash
# Enable query logging
psql $DATABASE_URL -c "SET log_statement = 'all';"

# Analyze slow queries
psql $DATABASE_URL -c "SELECT query, mean_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"
```

#### High Memory Usage
```bash
# Monitor function memory
supabase functions logs --filter memory

# Optimize function configuration
# Edit supabase/functions/function-name/index.ts
# Add memory limits and optimization
```

### Security Issues

#### RLS Policy Violations
```bash
# Test RLS policies
psql $DATABASE_URL -c "SET ROLE authenticated; SELECT * FROM scout.fact_transaction_item LIMIT 1;"

# Verify tenant isolation
python3 tests/security/test_tenant_isolation.py
```

#### API Key Issues
```bash
# Verify API keys
curl -H "Authorization: Bearer $SUPABASE_ANON_KEY" "$SUPABASE_URL/rest/v1/"

# Test service role key
curl -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" "$SUPABASE_URL/rest/v1/"
```

## Maintenance

### Regular Maintenance Tasks

#### Daily
- Monitor system status (`make status`)
- Check error logs
- Verify performance metrics

#### Weekly
- Review audit logs
- Update dependencies
- Performance optimization

#### Monthly
- Security review
- Backup verification
- Capacity planning

### Backup & Recovery

```bash
# Database backup
pg_dump $DATABASE_URL > scout_v7_backup_$(date +%Y%m%d).sql

# Function backup
supabase functions download

# Configuration backup
tar -czf config_backup_$(date +%Y%m%d).tar.gz .env supabase/ agents/ semantic/
```

### Updates & Upgrades

```bash
# Update Supabase CLI
npm update -g supabase

# Update dependencies
cd tools/mcp-servers/mindsdb && npm update

# Apply new migrations
make v7-migrate

# Redeploy functions
make v7-deploy
```

## Support & Resources

### Documentation
- [Scout v7.1 PRD](./PRD.md) - Product requirements and specifications
- [Agent Contracts](../agents/contracts.yaml) - Agent system specifications
- [Semantic Model](../semantic/model.yaml) - Data model and metrics

### Monitoring Tools
- **Supabase Dashboard**: Database and function monitoring
- **Edge Function Logs**: Real-time function logging
- **Audit Ledger**: Complete system audit trail

### Getting Help
- Check [Troubleshooting](#troubleshooting) section
- Review system logs: `supabase functions logs`
- Verify system status: `make status`
- Run diagnostic tests: `make v7-test`

---

**Scout v7.1 Agentic Analytics Platform** transforms traditional BI dashboards into intelligent, conversational analytics experiences with natural language queries, predictive insights, and automated narrative generation.