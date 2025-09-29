# Scout Analytics API - Azure App Service

![Scout Analytics](https://img.shields.io/badge/Scout-v7%20Analytics-blue)
![Azure App Service](https://img.shields.io/badge/Azure-App%20Service-0078d4)
![Node.js](https://img.shields.io/badge/Node.js-18%20LTS-339933)
![Status](https://img.shields.io/badge/Status-Production%20Ready-green)

Enterprise-grade analytics API for Scout v7 platform with Filipino cultural intelligence and real-time operational insights.

## 🚀 Quick Deploy to Azure

Deploy the Scout Analytics API to Azure App Service with a single command:

```bash
# Set your Azure configuration
export AZURE_RESOURCE_GROUP="RG-TBWA-ProjectScout-Compute"
export AZURE_APP_NAME="scout-analytics-api"

# Run deployment script
./deploy-azure.sh
```

## 📊 Features

### Analytics Engine
- **Ultra-Enriched Dataset**: 150+ columns combining transaction data, cultural insights, and conversation intelligence
- **Filipino Cultural Analytics**: Authentic sari-sari store insights (suki relationships, tingi culture, payday patterns)
- **Conversation Intelligence**: NLP analysis of 131,606+ customer conversations
- **Real-Time Monitoring**: Live operational dashboards and alerting system

### Cultural Intelligence
- **12 Filipino Personas**: Kapitbahay-Suki, Nanay-Family-Provider, Payday-Bulk-Buyer, and more
- **Language Analysis**: Filipino/English/Mixed/Silent conversation patterns
- **Community Patterns**: Traditional suki loyalty measurement and optimization
- **Economic Cycles**: Payday correlation analysis (15th/30th patterns)

### Business Intelligence
- **Store Performance Analytics**: 6 operational views for store managers
- **Real-Time Monitoring**: 5 live monitoring dashboards
- **Automated Procedures**: 6 BI procedures for daily insights
- **Operational Alerts**: Priority-based issue detection and recommendations

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Azure SQL     │    │   App Service    │    │   Dashboards    │
│   Database      │◄──►│  Scout API       │◄──►│   & Clients     │
│                 │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌──────────────────┐             │
         └──────────────►│   Key Vault      │◄────────────┘
                        │   (Secrets)      │
                        └──────────────────┘
```

## 🔧 Environment Setup

### Prerequisites
- Node.js 18 LTS or later
- Azure CLI
- Access to Azure SQL Database
- Azure Key Vault configured

### Local Development

1. **Clone and install dependencies:**
```bash
git clone <repository-url>
cd apps/dal-agent
npm install
```

2. **Configure environment:**
```bash
cp .env.example .env
# Edit .env with your configuration
```

3. **Start development server:**
```bash
npm run dev
```

The API will be available at `http://localhost:8080`

### Environment Variables

```bash
# Database Configuration
AZURE_SQL_CONNECTION_STRING=your_connection_string

# Analytics Features
ENABLE_REAL_TIME_MONITORING=true
ENABLE_CULTURAL_ANALYTICS=true
ENABLE_CONVERSATION_INTELLIGENCE=true

# Performance Settings
CONNECTION_POOL_MAX=20
CACHE_TTL_SECONDS=300
```

## 📡 API Endpoints

### Health & System
- `GET /health` - Basic health check
- `GET /health/detailed` - Detailed system health
- `GET /health/ready` - Readiness probe
- `GET /health/live` - Liveness probe

### Analytics
- `GET /api/v1/analytics/ultra-enriched` - 150+ column enriched dataset
- `GET /api/v1/analytics/conversation-intelligence` - NLP conversation insights
- `GET /api/v1/analytics/cultural-patterns` - Filipino cultural analysis
- `GET /api/v1/analytics/store-rankings` - Store performance rankings
- `POST /api/v1/analytics/daily-report` - Generate daily analytics report

### Real-Time Monitoring
- `GET /api/v1/monitoring/live-dashboard` - Real-time system health
- `GET /api/v1/monitoring/store-activity` - Store activity monitoring
- `GET /api/v1/monitoring/customer-experience` - Live customer satisfaction
- `GET /api/v1/monitoring/activity-heatmap` - 24-hour activity visualization
- `GET /api/v1/monitoring/operational-alerts` - Current alerts and issues
- `GET /api/v1/monitoring/performance-kpi` - Platform KPIs
- `GET /api/v1/monitoring/system-status` - Overall system status

### Cultural Intelligence
- `GET /api/v1/cultural/store-patterns` - Store cultural classification
- `GET /api/v1/cultural/customer-personas` - Filipino customer personas
- `GET /api/v1/cultural/language-patterns` - Communication analysis
- `GET /api/v1/cultural/suki-relationships` - Customer loyalty analysis
- `POST /api/v1/cultural/analysis` - Generate cultural insights report

## 🔒 Security

### Authentication & Authorization
- **Managed Identity**: Azure App Service uses system-assigned managed identity
- **Key Vault Integration**: All secrets stored in Azure Key Vault
- **CORS Configuration**: Restricted to allowed origins only
- **Rate Limiting**: 1000 requests per 15 minutes per IP

### Security Headers
- Helmet.js for security headers
- HTTPS enforcement
- Request size limits
- SQL injection protection

### Data Privacy
- No PII storage in logs
- Cultural data handled with sensitivity
- GDPR compliance considerations
- Audit trail for all analytics queries

## 🚀 Deployment

### Azure App Service Deployment

#### Option 1: Automated Script
```bash
# Configure Azure settings
export AZURE_RESOURCE_GROUP="your-resource-group"
export AZURE_APP_NAME="your-app-name"

# Deploy
./deploy-azure.sh
```

#### Option 2: GitHub Actions CI/CD
Push to `main` branch triggers automatic deployment via GitHub Actions.

#### Option 3: Manual Azure CLI
```bash
# Create resources
az group create --name myResourceGroup --location "East US"
az appservice plan create --name myAppServicePlan --resource-group myResourceGroup --sku B1 --is-linux
az webapp create --resource-group myResourceGroup --plan myAppServicePlan --name myApp --runtime "NODE|18-lts"

# Deploy application
az webapp deployment source config-zip --resource-group myResourceGroup --name myApp --src deployment.zip
```

### Configuration Steps

1. **Resource Creation**: Resource group, App Service plan, Web App
2. **Managed Identity**: System-assigned identity for Key Vault access
3. **Key Vault Access**: Grant secrets read permissions
4. **Environment Variables**: Configure app settings
5. **CORS Setup**: Configure allowed origins
6. **Health Checks**: Enable health monitoring

## 🧪 Testing

### Local Testing
```bash
# Run health check
curl http://localhost:8080/health

# Test analytics endpoint
curl "http://localhost:8080/api/v1/analytics/ultra-enriched?limit=5"
```

### Deployment Validation
```bash
# Run comprehensive tests
node test-deployment.js https://your-app.azurewebsites.net

# Or test locally
node test-deployment.js http://localhost:8080
```

### Performance Testing
```bash
# Load testing with Apache Bench
ab -n 1000 -c 10 https://your-app.azurewebsites.net/health

# Monitor performance
curl https://your-app.azurewebsites.net/api/v1/monitoring/performance-kpi
```

## 📊 Monitoring & Observability

### Application Insights
- **Request Tracking**: API endpoint performance
- **Dependency Tracking**: SQL database queries
- **Error Logging**: Exception monitoring
- **Custom Metrics**: Business KPIs

### Health Monitoring
- **Liveness Probe**: `/health/live` - Basic service health
- **Readiness Probe**: `/health/ready` - Database connectivity
- **Detailed Health**: `/health/detailed` - Comprehensive system check

### Performance Metrics
- **Response Times**: Average <200ms for monitoring endpoints
- **Throughput**: 1000+ requests per minute
- **Database**: Connection pooling with 5-20 connections
- **Caching**: 300-second TTL for analytics data

### Alerting
- **Platform Health**: <90% overall health score
- **Database Issues**: Connection failures or timeouts
- **High Error Rates**: >5% error rate over 5 minutes
- **Performance Degradation**: >1000ms average response time

## 📈 Analytics Capabilities

### Data Processing
- **Transaction Volume**: 12,192+ canonical transactions
- **Conversation Analysis**: 131,606+ customer interactions
- **Real-Time Processing**: <100ms monitoring decisions
- **Cultural Insights**: 12 Filipino persona classifications

### Business Intelligence
- **Store Performance**: Revenue, satisfaction, loyalty rankings
- **Customer Segmentation**: Behavioral and cultural patterns
- **Operational Alerts**: Proactive issue detection
- **Trend Analysis**: Historical performance with predictions

### Cultural Intelligence
- **Suki Relationships**: Customer-store loyalty measurement
- **Tingi Culture**: Small quantity purchase preferences
- **Payday Patterns**: Economic cycle analysis
- **Language Preferences**: Communication style adaptation

## 🔧 Troubleshooting

### Common Issues

#### Database Connection
```bash
# Check connection
curl https://your-app.azurewebsites.net/health/detailed

# Verify Key Vault access
az keyvault secret show --vault-name your-vault --name azure-sql-conn-str
```

#### Performance Issues
```bash
# Check system health
curl https://your-app.azurewebsites.net/api/v1/monitoring/system-status

# Monitor KPIs
curl https://your-app.azurewebsites.net/api/v1/monitoring/performance-kpi
```

#### Authentication Errors
- Verify managed identity is enabled
- Check Key Vault access policies
- Validate connection string format

### Logs and Debugging
```bash
# Azure CLI logs
az webapp log tail --name your-app --resource-group your-rg

# Application logs in Azure portal
# Monitor → App Service logs → Application logs
```

## 🤝 Contributing

### Development Workflow
1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-analytics`
3. Make changes and test locally
4. Run deployment tests: `node test-deployment.js`
5. Submit pull request

### Code Standards
- ESLint configuration included
- Prettier for code formatting
- Security audit with `npm audit`
- Performance testing required

### Cultural Sensitivity
When working with Filipino cultural features:
- Respect traditional sari-sari store values
- Consult with Filipino team members
- Test with authentic use cases
- Avoid cultural assumptions or stereotypes

## 📚 Documentation

- [API Documentation](./docs/api.md)
- [Cultural Analytics Guide](./docs/cultural-analytics.md)
- [Deployment Guide](./docs/deployment.md)
- [Database Schema](./docs/database-schema.md)

## 🆘 Support

### Technical Support
- Create GitHub issue for bugs
- Use Discussions for questions
- Contact team leads for urgent issues

### Business Intelligence Support
- Analytics questions: Contact BI team
- Cultural insights: Filipino cultural consultants
- Performance issues: DevOps team

## 📄 License

Copyright (c) 2025 TBWA Project Scout Team. All rights reserved.

---

**Status**: ✅ Production Ready | **Version**: 1.0.0 | **Last Updated**: September 29, 2025