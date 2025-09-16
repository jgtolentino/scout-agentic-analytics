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
Claude Code MCP integration for TBWA Project Scout:

### MindsDB MCP Server (Local Installation)
- **Purpose**: Local AI-powered predictive modeling and automated ML pipelines
- **Capabilities**: 
  - Predictive analytics (sales forecasting, customer behavior, market trends)
  - Real-time ML model training and deployment
  - Automated feature engineering and model optimization
  - Direct integration with Scout's Azure SQL database via Supabase connection
- **Setup**: Local MindsDB installation running on localhost:47334
- **Authentication**: No API keys needed for local installation
- **Environment Variables**:
  - `MINDSDB_LOCAL_URL` - Local MindsDB server (http://localhost:47334)
  - `POSTGRES_PASSWORD` - Database password (Postgres_26) for ML data access

### Context7 MCP Server (SuperClaude Framework)
- **Purpose**: Official documentation lookup and framework pattern guidance
- **Capabilities**:
  - Official library documentation and code examples
  - Framework-specific best practices and patterns  
  - Version-aware compatibility checking
  - Curated code pattern recommendations
- **Authentication**: No external credentials required
- **Integration**: Native SuperClaude framework component

## MCP Integration Pattern
Bruno orchestration ensures secure credential management:
1. Claude requests MCP operations using environment variable names only
2. Bruno injects actual credentials from secure vault at runtime
3. MCP servers authenticate and execute operations
4. Results returned to Claude Code for analysis and action

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