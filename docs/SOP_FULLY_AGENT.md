# Standard Operating Procedure: Fully Agent

**Agent**: Fully (Fullstack Backend Engineering Agent)  
**Version**: 1.0.0  
**Last Updated**: 2025-01-17  
**Author**: InsightPulseAI Team

## Purpose

The Fully agent automates backend generation from structured JSON data. It provides a complete pipeline for:
- Schema inference and SQL generation
- Data seeding and migration
- API model generation (Pydantic, Prisma, Drizzle)
- UI component scaffolding
- Direct Supabase deployment

## Prerequisites

### Required Dependencies
```bash
pip install supabase-py psycopg2 typer pydantic jinja2
npm install -g @supabase/mcp-server-supabase@latest
```

### Environment Setup
- Supabase project with service role key
- Python 3.8+ environment
- Node.js 16+ (for UI generation)
- Bash shell (for deployment scripts)

## Configuration

### MCP Context Setup
Create `.mcp/context.json`:
```json
{
  "project": {
    "ref": "your-project-ref",
    "rest_url": "https://xxx.supabase.co"
  },
  "tokens": {
    "service_role": "your-service-role-key",
    "anon": "your-anon-key"
  },
  "branch": {
    "name": "main"
  }
}
```

### Environment Variables (Fallback)
```bash
export SUPABASE_URL=https://xxx.supabase.co
export SUPABASE_KEY=your-service-role-key
export SUPABASE_PROJECT_REF=your-project-ref
```

## Core Operations

### 1. Schema Generation from JSON

**Command**: `:fully infer-schema <json_file> [options]`

**Process**:
1. Load JSON data from specified file
2. Analyze data structure and types
3. Generate PostgreSQL DDL with:
   - Appropriate data types
   - Primary keys (auto-generated if missing)
   - Timestamps (created_at, updated_at)
   - Update triggers
4. Optionally deploy to Supabase

**Example**:
```bash
# Basic generation
:fully infer-schema ./data/products.json

# With auto-deployment
:fully infer-schema ./data/products.json --deploy
```

### 2. Data Seeding

**Command**: `:fully seed <json_file> [options]`

**Process**:
1. Load JSON seed data
2. Infer or use specified table name
3. Generate SQL INSERT/UPSERT statements
4. Apply batching for large datasets
5. Optionally execute on Supabase

**Options**:
- `--table`: Target table name
- `--upsert`: Use UPSERT instead of INSERT
- `--batch`: Batch size (default: 100)
- `--execute`: Execute directly on Supabase

**Example**:
```bash
# Generate SQL file
:fully seed ./data/users.json --table customers

# Direct execution with UPSERT
:fully seed ./data/users.json --upsert --execute
```

### 3. API Model Generation

**Command**: `:fully generate-api <schema_file> [options]`

**Process**:
1. Parse SQL schema file
2. Extract table definitions
3. Generate model files for selected frameworks
4. Include type mappings and relationships

**Supported Formats**:
- Pydantic (Python)
- Prisma (Node.js)
- Drizzle (TypeScript)

**Example**:
```bash
# Generate all formats
:fully generate-api ./out/schema.sql

# Specific format only
:fully generate-api ./out/schema.sql --format pydantic
```

### 4. Schema Deployment

**Command**: `:fully deploy <schema_file>`

**Process**:
1. Load MCP context or environment credentials
2. Validate schema file
3. Execute DDL on Supabase
4. Verify deployment status

**Example**:
```bash
:fully deploy ./out/schema.sql
```

### 5. UI Component Generation

**Command**: `:fully generate-ui <component_name> [type]`

**Types**: form, table, card, list

**Example**:
```bash
:fully generate-ui UserForm form
:fully generate-ui ProductTable table
```

### 6. Schema Analysis

**Command**: `:fully summarize-schema <file>`

**Process**:
1. Analyze JSON or SQL file
2. Generate detailed report with:
   - Field types and completeness
   - Data distributions
   - Potential relationships
   - Schema recommendations

**Example**:
```bash
:fully summarize-schema ./data/analytics.json
```

## Workflow Examples

### Complete JSON to Backend Pipeline
```bash
# 1. Analyze data structure
:fully summarize-schema ./data/inventory.json

# 2. Generate and deploy schema
:fully infer-schema ./data/inventory.json --deploy

# 3. Seed initial data
:fully seed ./data/inventory.json --execute

# 4. Generate API models
:fully generate-api ./out/schema.sql

# 5. Create UI components
:fully generate-ui InventoryForm form
:fully generate-ui InventoryList table
```

### MCP-Enabled Workflow
```bash
# Run via Supabase MCP
npx @supabase/mcp-server-supabase@latest \
  run --agent fully \
  --task json_to_supabase \
  --input ./data/orders.json
```

## Troubleshooting

### Common Issues

1. **MCP Context Not Found**
   - Check context file locations
   - Validate JSON syntax
   - Ensure proper permissions

2. **Schema Generation Errors**
   - Verify JSON structure (must be object or array)
   - Check for mixed data types
   - Review field naming conventions

3. **Deployment Failures**
   - Confirm Supabase credentials
   - Check network connectivity
   - Verify SQL syntax compatibility

### Debug Commands
```bash
# Validate MCP context
python utils/load_supabase_context.py validate

# Show current context
python utils/load_supabase_context.py show

# Test schema generation without deployment
:fully infer-schema ./data/test.json --output ./debug/schema.sql
```

## Best Practices

1. **Data Preparation**
   - Use consistent field naming
   - Avoid deeply nested structures
   - Include sample data for all fields

2. **Schema Design**
   - Let Fully infer initial schema
   - Review and adjust generated DDL
   - Add custom constraints post-generation

3. **Deployment Safety**
   - Test on development branch first
   - Review generated SQL before deployment
   - Use transactions for data seeding

4. **Performance Optimization**
   - Adjust batch sizes for large datasets
   - Use UPSERT for idempotent operations
   - Monitor Supabase rate limits

## Integration with Other Agents

### Devstral (Orchestration)
```bash
:devstral orchestrate backend-pipeline --agent fully
```

### Dash (Visualization)
```bash
:dash visualize-schema ./out/schema.sql
```

### Basher (System Operations)
```bash
:basher backup-before-deploy ./out/schema.sql
```

### LearnBot (Documentation)
```bash
:learnbot document-api ./out/models/
```

## Maintenance

### Regular Tasks
1. Update dependencies monthly
2. Validate MCP context weekly
3. Archive generated schemas
4. Monitor error logs

### Version Updates
```bash
# Update Fully agent
git pull origin main
pip install -r requirements.txt

# Update MCP server
npm update @supabase/mcp-server-supabase
```

## Support

For issues or enhancements:
1. Check agent logs in `.pulser/logs/`
2. Review MCP context validation
3. Contact InsightPulseAI team
4. Submit issues to agent repository