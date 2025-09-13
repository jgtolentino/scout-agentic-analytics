# Scout v7.1 MindsDB MCP Server

MCP (Model Context Protocol) server that provides predictive analytics capabilities through MindsDB Cloud integration for Scout Dashboard v7.1.

## Features

- **MindsDB Integration**: Direct connection to MindsDB Cloud for machine learning operations
- **Forecast Delegation**: Automatic handoff from NL→SQL pipeline for predictive queries
- **Model Management**: Complete lifecycle management (train, deploy, predict, monitor)
- **Time Series Forecasting**: Specialized support for revenue and demand forecasting
- **Fallback Handling**: Graceful degradation when MindsDB is unavailable

## Available Tools

### `mindsdb_query`
Execute general SQL queries on MindsDB for exploration and administration.

```typescript
{
  sql: string,           // SQL query to execute
  timeout?: number       // Query timeout in milliseconds
}
```

### `mindsdb_train_model`
Train a new ML model using Scout data for forecasting.

```typescript
{
  modelName: string,        // Name for the ML model
  integrationName: string,  // Data integration name
  selectQuery: string,      // SELECT query for training data
  predictColumn: string,    // Target column to predict
  timeColumn?: string,      // Time column for time series
  window?: number,          // Window size (default: 12)
  horizon?: number,         // Forecast horizon (default: 12)
  hyperparameters?: object  // Model hyperparameters
}
```

### `mindsdb_predict`
Make predictions using a trained model.

```typescript
{
  modelName: string,           // Name of trained model
  inputData: object | array,   // Input data for prediction
  horizon?: number,            // Forecast horizon
  explainability?: boolean     // Include explanations
}
```

### `mindsdb_model_status`
Get status and information about models.

```typescript
{
  modelName?: string,     // Specific model (optional)
  detailed?: boolean      // Include detailed info
}
```

### `mindsdb_deploy_model`
Deploy a model for production use with scheduling.

```typescript
{
  modelName: string,     // Model to deploy
  endpoint?: string,     // Endpoint configuration
  schedule?: string      // Retraining schedule (cron)
}
```

## Configuration

Configure via environment variables:

```bash
MINDSDB_HOST=cloud.mindsdb.com
MINDSDB_PORT=3306
MINDSDB_USER=your_username
MINDSDB_PASSWORD=your_password
MINDSDB_DATABASE=mindsdb
MINDSDB_TIMEOUT=30000
```

## Usage

### Installation

```bash
cd tools/mcp-servers/mindsdb
npm install
npm run build
```

### Running the Server

```bash
npm start
```

### Development

```bash
npm run dev
```

### Integration with Claude Code

The MCP server integrates with Claude Code's SuperClaude Framework through the forecast delegation pattern defined in the PRD:

1. **Intent Detection**: NL→SQL pipeline detects forecast keywords
2. **Delegation Check**: Uses confidence scoring (≥0.8) to delegate to MindsDB
3. **MCP Execution**: Claude Code calls appropriate MindsDB tools
4. **Fallback**: Falls back to SQL seasonal analysis if MindsDB unavailable

## Example Workflows

### Revenue Forecasting

```javascript
// Train a revenue forecast model
await mcp.call('mindsdb_train_model', {
  modelName: 'scout_revenue_forecast',
  integrationName: 'scout_postgres',
  selectQuery: `
    SELECT 
      date_trunc('month', dt.d) as month,
      SUM(t.peso_value) as revenue,
      b.brand_name,
      l.region
    FROM scout.fact_transaction_item t
    JOIN scout.dim_time dt ON t.date_id = dt.date_id
    JOIN scout.dim_brand b ON t.brand_id = b.brand_id
    JOIN scout.dim_location l ON t.location_id = l.location_id
    WHERE dt.d >= '2023-01-01'
    GROUP BY month, b.brand_name, l.region
    ORDER BY month
  `,
  predictColumn: 'revenue',
  timeColumn: 'month',
  window: 12,
  horizon: 6
});

// Make predictions
await mcp.call('mindsdb_predict', {
  modelName: 'scout_revenue_forecast',
  inputData: {
    brand_name: 'Alaska',
    region: 'NCR'
  },
  horizon: 12,
  explainability: true
});
```

### Model Deployment

```javascript
// Deploy model with automated retraining
await mcp.call('mindsdb_deploy_model', {
  modelName: 'scout_revenue_forecast',
  schedule: '0 2 * * 0', // Weekly retraining
  endpoint: 'REST'
});
```

## Integration Points

### Scout Dashboard v7.1
- **Agentic Playground**: Natural language forecast queries
- **Executive Overview**: Automated revenue forecasts
- **Competitive Analysis**: Brand performance predictions

### SuperClaude Framework
- **MCP Integration**: Follows MCP protocol standards
- **Persona Alignment**: Works with architect and analyzer personas
- **Wave Orchestration**: Supports multi-stage forecast workflows

### Edge Functions
- Integrates with `mindsdb_proxy` Edge Function
- Provides fallback mechanisms for reliability
- Maintains audit trail through `audit_ledger`

## Security & Governance

- **Credential Management**: Uses environment variables only
- **Query Validation**: Validates all SQL before execution
- **Tenant Isolation**: Respects RLS policies in training data
- **Audit Logging**: All operations logged for compliance

## Monitoring

The server provides detailed logging and error handling:
- Connection status monitoring
- Query execution metrics
- Model training progress
- Prediction accuracy tracking

## Troubleshooting

Common issues and solutions:

1. **Connection Failed**: Check MindsDB credentials and network access
2. **Model Training Timeout**: Increase timeout or check data volume
3. **Prediction Errors**: Verify model status and input data format
4. **Authentication Issues**: Confirm MindsDB user permissions

For support, refer to the Scout v7.1 documentation or MindsDB Cloud documentation.