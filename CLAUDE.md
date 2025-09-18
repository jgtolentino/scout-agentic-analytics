# CLAUDE.md — Orchestration Rules

## Execution Model
- **Bruno** is the executor - handles environment, secrets, and deployment
- **Claude Code** orchestrates - plans, coordinates, and validates
- No secrets in prompts or repo; route via Bruno environment injection

## MCP Endpoints
Available in Dev Mode:
- **Supabase** - Database operations, Edge Functions, migrations
- **GitHub** - Repository management, issues, PRs
- **Figma** - Design system integration, component specs
- **Gmail** - Communication and notification workflows

## MCP AI Analytics Servers
Claude Code MCP integration for TBWA Project Scout with SuperClaude Framework:

### MindsDB MCP Server (Local Installation)
- **Purpose**: Local AI-powered predictive modeling and automated ML pipelines
- **Host**: `localhost:47334` (local Docker installation)
- **Capabilities**:
  - Predictive analytics (sales forecasting, customer behavior, market trends)
  - Real-time ML model training and deployment
  - Automated feature engineering and model optimization
  - Direct integration with Scout's Azure SQL database via Supabase connection
- **Setup Instructions**:
  ```bash
  # Install MindsDB locally
  docker pull mindsdb/mindsdb
  docker run -p 47334:47334 mindsdb/mindsdb

  # Verify installation
  curl http://localhost:47334/health
  ```
- **Environment Variables**:
  - `MINDSDB_HOST` - localhost (for local installation)
  - `MINDSDB_PORT` - 47334 (default MindsDB port)
  - `MINDSDB_USER` - mindsdb (default user)
  - `MINDSDB_PASSWORD` - (empty for local)
  - `MINDSDB_DATABASE` - mindsdb (default database)
  - `POSTGRES_PASSWORD` - Postgres_26 (for Scout data access)
- **Health Check**: `GET /health` → 200 OK
- **Status**: 🔴 Not Running (requires setup)

### Context7 MCP Server (SuperClaude Framework)
- **Purpose**: Official documentation lookup and framework pattern guidance
- **Host**: Native SuperClaude component (no external server)
- **Capabilities**:
  - Official library documentation and code examples
  - Framework-specific best practices and patterns
  - Version-aware compatibility checking
  - Curated code pattern recommendations
- **Authentication**: No external credentials required
- **Integration**: Native SuperClaude framework component
- **Health Check**: Internal framework validation
- **Status**: ✅ Operational (integrated)

### Sequential MCP Server (SuperClaude Framework)
- **Purpose**: Multi-step reasoning and complex analysis workflows
- **Host**: Native SuperClaude component
- **Capabilities**:
  - Structured multi-step problem solving
  - Complex debugging and root cause analysis
  - Systematic approach to large-scale operations
  - Cross-domain expertise coordination
- **Integration**: Auto-activated for complex operations
- **Status**: ✅ Operational (integrated)

### Magic MCP Server (SuperClaude Framework)
- **Purpose**: Modern UI component generation and design systems
- **Host**: Native SuperClaude component
- **Capabilities**:
  - React/Vue/Angular component generation
  - Design system integration (21st.dev patterns)
  - Responsive design implementation
  - Accessibility compliance (WCAG 2.1)
- **Integration**: Auto-activated for UI/UX tasks
- **Status**: ✅ Operational (integrated)

### Playwright MCP Server (SuperClaude Framework)
- **Purpose**: Cross-browser testing and automation
- **Host**: Local Playwright installation
- **Capabilities**:
  - End-to-end testing across browsers
  - Visual regression testing
  - Performance metrics collection
  - User interaction automation
- **Setup**: `npm install @playwright/test`
- **Status**: 🟡 Available (requires validation)

## MCP Server Health Monitoring

### Health Check Script
```typescript
// scripts/mcp-health.ts
const checkMCPServers = async () => {
  const servers = [
    { name: 'MindsDB', url: 'http://localhost:47334/health' },
    { name: 'Context7', check: () => true }, // Native
    { name: 'Sequential', check: () => true }, // Native
    { name: 'Magic', check: () => true }, // Native
    { name: 'Playwright', check: checkPlaywright }
  ];

  for (const server of servers) {
    const status = await checkServer(server);
    console.log(`${server.name}: ${status ? '✅' : '🔴'}`);
  }
};
```

### Troubleshooting Guide

#### MindsDB Connection Issues
```bash
# Check if MindsDB is running
curl -f http://localhost:47334/health || echo "MindsDB not running"

# Start MindsDB Docker container
docker run -d -p 47334:47334 --name mindsdb mindsdb/mindsdb

# Check container logs
docker logs mindsdb

# Test database connection
curl -X POST http://localhost:47334/query -H "Content-Type: application/json" -d '{"query": "SHOW DATABASES;"}'
```

#### SuperClaude Framework Issues
```bash
# Verify SuperClaude configuration
cat ~/.claude/CLAUDE.md | grep -A5 "MCP.md"

# Check framework integration
npm run framework:validate

# Reset framework state
rm -rf ~/.claude/cache && claude --reset-framework
```

#### Playwright Setup Issues
```bash
# Install Playwright with browsers
npx playwright install

# Verify browser installation
npx playwright --version

# Run test suite
npm run test:e2e
```

## MCP Integration Pattern
Bruno orchestration ensures secure credential management:
1. Claude requests MCP operations using environment variable names only
2. Bruno injects actual credentials from secure vault at runtime
3. MCP servers authenticate and execute operations
4. Results returned to Claude Code for analysis and action
5. Health monitoring validates server availability
6. Automatic fallback for failed operations

## MCP Server Priority Matrix
| Server | Priority | Auto-Activate | Fallback |
|--------|----------|---------------|----------|
| **Context7** | Critical | Documentation queries | WebSearch |
| **Sequential** | High | Complex analysis | Native reasoning |
| **MindsDB** | High | Predictive queries | Statistical analysis |
| **Magic** | Medium | UI generation | Manual coding |
| **Playwright** | Medium | E2E testing | Unit tests |

## Communication Style
- **Direct and critical** - produce runnable, actionable blocks
- **Evidence-based** - validate before execution
- **Quality-gated** - test, lint, and validate all changes
- **Documentation-first** - maintain clear project records

## Project Standards
- Follow medallion architecture (Bronze → Silver → Gold → Platinum)
- Implement proper error handling and logging
- Use TypeScript for type safety
- Maintain comprehensive test coverage