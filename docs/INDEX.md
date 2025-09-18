# 📚 Scout v7 Documentation Index
*SuperClaude Framework Integration | Complete System Reference*

## 🚀 Quick Navigation

**Core Systems** → [Architecture](#-architecture) | [ETL Pipeline](#-etl-pipeline) | [Analytics](#-analytics)
**Development** → [Setup](#-development-setup) | [Testing](#-testing) | [Deployment](#-deployment)
**Operations** → [Monitoring](#-monitoring) | [MCP Servers](#-mcp-integration) | [Troubleshooting](#-troubleshooting)

---

## 🏗️ Architecture

### System Design & Planning
- **[ARCHITECTURE.md](ARCHITECTURE.md)** → Core system architecture, medallion design
- **[AGENTIC-SEMANTIC-LAYER.md](AGENTIC-SEMANTIC-LAYER.md)** → AI-powered semantic layer
- **[ROUTER-ARCHITECTURE.md](ROUTER-ARCHITECTURE.md)** → Request routing and load balancing
- **[PRD.md](PRD.md)** → Product requirements document
- **[PRD-NEURAL-DATABANK.md](PRD-NEURAL-DATABANK.md)** → Neural databank specifications

### Edge Functions & APIs
- **[EDGE_FUNCTIONS_GUIDE.md](EDGE_FUNCTIONS_GUIDE.md)** → Complete edge functions reference
- **[API-VERSIONING.md](API-VERSIONING.md)** → API versioning strategy
- **[FULLY_CAPABILITIES_MATRIX.md](FULLY_CAPABILITIES_MATRIX.md)** → System capabilities overview

---

## ⚡ ETL Pipeline

### Data Processing Architecture
- **[ETL_Data_Flow_Architecture.md](ETL_Data_Flow_Architecture.md)** → Complete data flow diagrams ✨
- **[../ETL_ARCHITECTURE.md](../ETL_ARCHITECTURE.md)** → ETL system overview
- **[../supabase/MEDALLION_ARCHITECTURE.md](../supabase/MEDALLION_ARCHITECTURE.md)** → Bronze→Silver→Gold→Platinum layers

### Data Sources & Integration
- **[EDGE_ONLY_README.md](EDGE_ONLY_README.md)** → Scout Edge device integration
- **[ZIP_UPLOAD_INTEGRATION.md](ZIP_UPLOAD_INTEGRATION.md)** → Bulk upload processing
- **[DB_SYNC_SETUP.md](DB_SYNC_SETUP.md)** → Database synchronization

### Schema & Migrations
- **[MIGRATIONS_GOVERNANCE.md](MIGRATIONS_GOVERNANCE.md)** → Migration management
- **[../supabase/migrations/README_PATTERNS.md](../supabase/migrations/README_PATTERNS.md)** → Migration patterns
- **[../SCHEMA_COMPLIANCE_SUMMARY.md](../SCHEMA_COMPLIANCE_SUMMARY.md)** → Schema validation

---

## 📊 Analytics

### Natural Language to SQL
- **[AGENTIC_ANALYTICS_RUNBOOK.md](AGENTIC_ANALYTICS_RUNBOOK.md)** → NL2SQL operational guide
- **[AGENTIC_ANALYTICS_SUMMARY.md](AGENTIC_ANALYTICS_SUMMARY.md)** → Analytics platform overview
- **[AI-ASSISTANT-GUIDE.md](AI-ASSISTANT-GUIDE.md)** → AI assistant integration

### Dashboards & Visualization
- **[PRD/SCOUT_UI_BACKLOG.md](PRD/SCOUT_UI_BACKLOG.md)** → UI component backlog
- **[ces-architecture-guide.md](ces-architecture-guide.md)** → Consumer engagement system

---

## 💻 Development Setup

### Initial Setup
- **[../README.md](../README.md)** → Project overview and quick start
- **[CLAUDE.md](CLAUDE.md)** → Claude Code orchestration rules
- **[CLAUDE_CODE_SECURE_WORKFLOW.md](CLAUDE_CODE_SECURE_WORKFLOW.md)** → Secure development workflow

### Configuration
- **[../CLAUDE.md](../CLAUDE.md)** → Main configuration file
- **[../agents/production/SUPABASE_SETUP.md](../agents/production/SUPABASE_SETUP.md)** → Supabase configuration
- **[../agents/production/README_DATABASE_SETUP.md](../agents/production/README_DATABASE_SETUP.md)** → Database setup

---

## 🧪 Testing

### Test Strategy
- **[UAT.md](UAT.md)** → User acceptance testing
- **[../tests/visual-parity.spec.js](../tests/visual-parity.spec.js)** → Visual regression tests
- **[../tests/global-setup.js](../tests/global-setup.js)** → Test environment setup

### Quality Assurance
- **[LOCKFILE-INTEGRITY.md](LOCKFILE-INTEGRITY.md)** → Dependency integrity
- **[OPTIMIZATION_GUIDE.md](OPTIMIZATION_GUIDE.md)** → Performance optimization

---

## 🚀 Deployment

### Production Deployment
- **[DEPLOYMENT.md](DEPLOYMENT.md)** → Deployment guide
- **[../supabase/DEPLOY_RECOMMENDATIONS.md](../supabase/DEPLOY_RECOMMENDATIONS.md)** → Supabase deployment
- **[../scripts/DEPLOYMENT_RUNBOOK.md](../scripts/DEPLOYMENT_RUNBOOK.md)** → Deployment automation

### Environment Management
- **[../agents/production/DEPLOYMENT_CHECKLIST.md](../agents/production/DEPLOYMENT_CHECKLIST.md)** → Pre-deployment checklist
- **[../agents/production/FINAL_SETUP.md](../agents/production/FINAL_SETUP.md)** → Final setup steps
- **[../agents/production/IMPLEMENTATION_STATUS.md](../agents/production/IMPLEMENTATION_STATUS.md)** → Implementation status

---

## 📊 Monitoring

### System Monitoring
- **[MONITORING.md](MONITORING.md)** → Monitoring strategy
- **[DISASTER_RECOVERY_RUNBOOK.md](DISASTER_RECOVERY_RUNBOOK.md)** → Disaster recovery
- **[CACHE_STRATEGY.md](CACHE_STRATEGY.md)** → Caching optimization

### Error Tracking
- **[SENTRY_DEPLOYMENT_CHECKLIST.md](SENTRY_DEPLOYMENT_CHECKLIST.md)** → Error monitoring setup
- **[SENTRY_SETUP.md](SENTRY_SETUP.md)** → Sentry configuration

---

## 🔧 MCP Integration

### MCP Servers
- **[../tools/mcp-servers/mindsdb/README.md](../tools/mcp-servers/mindsdb/README.md)** → MindsDB MCP server 🤖
- **[../tools/js/mcp/computer-use/README.md](../tools/js/mcp/computer-use/README.md)** → Computer use MCP
- **[../tools/js/mcp/computer-use/PULSER_COMPUTER_USE_GUIDE.md](../tools/js/mcp/computer-use/PULSER_COMPUTER_USE_GUIDE.md)** → Pulser integration

### Agent Systems
- **[SOP_FULLY_AGENT.md](SOP_FULLY_AGENT.md)** → Agent operations manual
- **[../agents/production/PRODUCTION_AGENT_REGISTRY.md](../agents/production/PRODUCTION_AGENT_REGISTRY.md)** → Agent registry

---

## 🎯 Specialized Agents

### Data Processing Agents
- **[../agents/iska/README.md](../agents/iska/README.md)** → Iska data processor
- **[../agents/iska/SOP/iska_ingestion_sop.md](../agents/iska/SOP/iska_ingestion_sop.md)** → Iska SOP
- **[../agents/isko/README.md](../agents/isko/README.md)** → Isko data processor

### Specialized Tools
- **[../agents/savage/README.md](../agents/savage/README.md)** → Savage agent
- **[../agents/savage/ENHANCED_README.md](../agents/savage/ENHANCED_README.md)** → Enhanced Savage
- **[../agents/dataos-docs-extractor/README.md](../agents/dataos-docs-extractor/README.md)** → Documentation extractor

---

## 📈 Project Management

### Planning & Tasks
- **[PLANNING.md](PLANNING.md)** → Project planning
- **[TASKS.md](TASKS.md)** → Task management
- **[../TASKS.md](../TASKS.md)** → Root task list
- **[task-list.md](task-list.md)** → Detailed task list
- **[generate-tasks.md](generate-tasks.md)** → Task generation

### Status Reports
- **[../SCOUT-V7-DEPLOYMENT-STATUS.md](../SCOUT-V7-DEPLOYMENT-STATUS.md)** → Deployment status
- **[../FOUNDRY-STATUS.md](../FOUNDRY-STATUS.md)** → Foundry status
- **[../FEATURE-INVENTORY.md](../FEATURE-INVENTORY.md)** → Feature inventory
- **[../MCP_INVENTORY_REPORT.md](../MCP_INVENTORY_REPORT.md)** → MCP inventory

### Release Management
- **[../CHANGELOG.md](../CHANGELOG.md)** → Change log
- **[../RELEASE-NOTES.md](../RELEASE-NOTES.md)** → Release notes
- **[../REPOSITORY_OPTIMIZATION_COMPLETE.md](../REPOSITORY_OPTIMIZATION_COMPLETE.md)** → Optimization report

---

## 🔧 Troubleshooting

### Common Issues
| Issue | Documentation | Priority |
|-------|--------------|----------|
| Database sync | [DB_SYNC_SETUP.md](DB_SYNC_SETUP.md) | 🔴 Critical |
| ETL failures | [ETL_Data_Flow_Architecture.md](ETL_Data_Flow_Architecture.md) | 🔴 Critical |
| Edge function errors | [EDGE_FUNCTIONS_GUIDE.md](EDGE_FUNCTIONS_GUIDE.md) | 🟡 High |
| MindsDB connection | [../tools/mcp-servers/mindsdb/README.md](../tools/mcp-servers/mindsdb/README.md) | 🟡 High |
| Deployment issues | [DEPLOYMENT.md](DEPLOYMENT.md) | 🟢 Medium |

### Quick Commands
```bash
# Health check
npm run health:check

# Database status
supabase status

# MCP servers
npm run mcp:health

# Test suite
npm run test:all
```

---

## 🎯 SuperClaude Framework Integration

### Symbol Legend
- **→** Leads to, implies, references
- **⇒** Transforms to, processes into
- **✅** Completed, verified, operational
- **🔄** In progress, updating, processing
- **⚠️** Warning, attention needed
- **🔍** Investigate, analyze, review
- **⚡** Performance, optimization
- **🤖** AI/ML, automation, intelligence
- **✨** New feature, enhancement

### Documentation Standards
- **Evidence-based** → All claims supported by metrics
- **Quality-gated** → Validated through testing
- **Performance-focused** → <100ms response targets
- **Security-first** → Zero-trust architecture

---

## 📞 Support & Contact

For technical support or documentation updates:
- **GitHub Issues** → [scout-v7/issues](https://github.com/tbwa/scout-v7/issues)
- **Documentation Team** → Update via Claude Code SuperClaude
- **Emergency** → Use disaster recovery runbook

---

*Last Updated: 2025-09-17 | SuperClaude Framework v3.0 | Scout v7.1*