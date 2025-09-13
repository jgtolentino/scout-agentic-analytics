# AI Assistant User Guide

## Overview

The Scout AI Assistant provides natural language access to your data through an intelligent translation system. Ask questions in plain English and receive charts, visualizations, and insights automatically.

## Quick Start

### Activation
- **Keyboard Shortcuts**: Press `/` or `Cmd+K` to open
- **Click**: Use the floating 🤖 button (bottom-right corner)
- **Voice**: "AI Assistant" in supported browsers

### Basic Usage
```
# Natural Language Examples
"Show brand performance in NCR last 28 days"
"Compare Alaska vs Oishi market share"
"Top categories by region this month"
"What's trending in snacks?"
"Revenue breakdown by channel"
```

### QuickSpec Translation
The AI Assistant translates natural language into **QuickSpec** format, our structured chart specification:

```typescript
interface QuickSpec {
  schema: 'QuickSpec@1';
  x?: string;           // X-axis dimension
  y?: string;           // Y-axis dimension
  series?: string;      // Series grouping
  agg: 'sum' | 'count' | 'avg' | 'min' | 'max';
  splitBy?: string;     // Split/group by
  chart: 'line' | 'bar' | 'stacked_bar' | 'pie' | 'scatter' | 'heatmap' | 'table';
  filters?: Record<string, any>;
  timeGrain?: 'hour' | 'day' | 'week' | 'month' | 'quarter' | 'year';
  normalize?: 'none' | 'share_category' | 'share_geo' | 'index_100';
  topK?: number;
}
```

## Intelligence Features

### Context Awareness
The assistant understands:
- **Current Page**: Adapts suggestions to your current dashboard
- **Active Filters**: Respects filters you've already applied
- **Time Context**: Infers relevant time ranges
- **Brand Context**: Knows your brand catalog and categories

### Smart Routing
Our **Intelligent Router** uses multiple AI techniques:

#### 1. Intent Classification
```typescript
// Natural language → business intent
"Show Alaska performance" → { 
  intent: 'brand_analysis',
  entities: { brand: 'Alaska' },
  confidence: 0.95 
}
```

#### 2. Embedding-Based Matching
- Converts queries to vector embeddings
- Finds similar historical queries
- Learns from successful patterns

#### 3. Fallback Chains
- **Primary**: AI model classification
- **Secondary**: Keyword matching
- **Tertiary**: Template suggestions
- **Fallback**: Generic exploratory charts

### Safety & Whitelisting

#### Approved Operations
✅ **Safe Operations**:
- Standard aggregations (sum, count, avg, min, max)
- Approved dimensions and measures
- Time-based filtering and grouping
- Geographic and demographic analysis

#### Security Boundaries
🚫 **Restricted Operations**:
- Raw SQL execution
- Administrative functions
- Data modification
- External system access

#### Validation Pipeline
1. **Intent Validation**: Verify business purpose
2. **SQL Review**: Check generated queries
3. **Data Access**: Validate permissions
4. **Result Filtering**: Apply privacy controls

## Advanced Features

### Multi-Language Support
```
# English (default)
"Show sales by region"

# Spanish
"Muestra las ventas por región"

# Filipino
"Ipakita ang benta sa bawat rehiyon"
```

### Complex Queries
```
# Comparative Analysis
"Compare Q4 2024 vs Q4 2023 performance by brand"

# Trend Analysis
"Show weekly growth rate for beverages last 3 months"

# Cohort Analysis
"New customer acquisition by month with retention rates"

# Geographic Patterns
"Heat map of sales density across Metro Manila"
```

### Chart Type Guidance

#### **Line Charts** - Time trends
```
"Weekly sales trend for Alaska milk"
"Monthly growth rate comparison"
```

#### **Bar Charts** - Category comparisons
```
"Top 10 products by revenue"
"Brand performance ranking"
```

#### **Pie Charts** - Share analysis
```
"Market share by category"
"Channel distribution breakdown"
```

#### **Heatmaps** - Geographic/temporal patterns
```
"Sales by region and time"
"Product performance matrix"
```

#### **Tables** - Detailed data
```
"Full breakdown with metrics"
"Detailed performance report"
```

## Neural DataBank Integration

### 4-Layer Intelligence

#### **Bronze Layer** - Raw Data Access
- Direct access to transaction-level data
- Real-time event streams
- Unprocessed metrics

#### **Silver Layer** - Business Ready
- Cleaned and validated data
- Standardized dimensions
- Quality-assured metrics

#### **Gold Layer** - KPIs & Aggregations
- Pre-calculated business metrics
- Materialized view performance
- Executive dashboard data

#### **Platinum Layer** - AI Insights
- ML model predictions
- Anomaly detection
- Trend forecasting
- Recommendation engine

### ML Model Access
```
# Predictive Queries
"Forecast next month's Alaska sales"
"Predict which products will trend"
"Estimate customer lifetime value"

# Classification Queries  
"Classify customer segments"
"Identify high-risk accounts"
"Categorize product performance"

# Anomaly Detection
"Show unusual sales patterns"
"Detect inventory anomalies"
"Flag performance outliers"
```

## Performance & Optimization

### Response Times
- **Simple Queries**: <500ms
- **Complex Analytics**: <2s
- **ML Predictions**: <5s
- **Large Aggregations**: <10s

### Caching Strategy
- **Query Results**: 5-15 minute cache
- **ML Predictions**: 30 minute cache
- **Aggregations**: 1 hour cache
- **Base Data**: Real-time updates

### Rate Limits
- **Queries per minute**: 60
- **Complex operations per hour**: 100
- **ML model calls per day**: 1000

## Troubleshooting

### Common Issues

#### **"No data found"**
- Check your filter settings
- Verify date ranges are valid
- Ensure you have data access permissions

#### **"Query too complex"**
- Break down into simpler questions
- Use more specific filters
- Try different chart types

#### **"AI service unavailable"**
- Refresh the page
- Check your internet connection
- Try again in a few minutes

### Getting Help

#### **In-App Support**
- Use the help button in chat
- Check query suggestions
- Review example queries

#### **Feedback Loop**
- Rate responses (👍/👎)
- Report issues via chat
- Suggest improvements

## Best Practices

### Query Construction

#### ✅ **Effective Queries**
```
# Specific and actionable
"Alaska milk sales in Metro Manila last 30 days"

# Clear time context
"Monthly revenue trend Jan-Dec 2024"

# Focused scope
"Top 5 beverages by volume this quarter"
```

#### ❌ **Avoid These Patterns**
```
# Too vague
"Show me everything"

# Unclear context
"Sales" (which product? timeframe? region?)

# Too complex
"Multi-dimensional analysis across all variables"
```

### Iterative Exploration

#### **Start Broad, Then Focus**
```
1. "Show overall sales performance"
2. "Focus on beverage category"
3. "Compare Alaska vs competitors"
4. "Break down by region"
```

#### **Use Follow-Up Questions**
```
User: "Show brand performance"
AI: [Shows chart]
User: "Now filter to NCR only"
AI: [Updates chart with NCR filter]
```

### Context Building

#### **Build on Previous Queries**
- The AI remembers your conversation
- Reference previous charts: "Add a trendline to that"
- Modify existing views: "Change to weekly instead"

#### **Leverage Dashboard Context**
- AI knows your current page filters
- Will suggest relevant follow-ups
- Maintains consistency with dashboard state

## Integration Examples

### Dashboard Enhancement
```typescript
// Listen for AI-generated charts
window.addEventListener('adhoc:chart', (event) => {
  const { spec, sql, explain } = event.detail;
  // Render chart alongside dashboard
  renderAdhocChart(spec);
});
```

### Export & Sharing
```typescript
// Export AI-generated insights
const chartSpec = aiAssistant.getLastSpec();
const exportData = {
  query: userQuery,
  spec: chartSpec,
  sql: generatedSQL,
  timestamp: Date.now()
};
```

## Privacy & Security

### Data Access Controls
- **Role-Based Access**: Only see data you're authorized for
- **Field-Level Security**: Sensitive fields automatically filtered
- **Audit Logging**: All queries logged for compliance

### Privacy Protection
- **No PII Exposure**: Personal information automatically masked
- **Data Minimization**: Only required fields included in responses
- **Retention Limits**: Query history automatically expires

### Compliance Features
- **SOC 2 Type II**: Security controls certified
- **GDPR Compliant**: Privacy by design implementation
- **Industry Standards**: Follows Philippine data protection laws

## Updates & Roadmap

### Recent Enhancements
- **Natural Language Processing**: Improved Filipino language support
- **Chart Intelligence**: Better visualization selection
- **Performance**: 40% faster query response times

### Upcoming Features
- **Voice Commands**: "Hey Scout, show me..."
- **Collaborative Analysis**: Share AI conversations
- **Advanced ML**: Custom model training
- **Mobile Optimization**: Native mobile app support

---

**Need Help?** Contact support or use the in-app help feature. The AI Assistant learns from your feedback to provide better insights over time.