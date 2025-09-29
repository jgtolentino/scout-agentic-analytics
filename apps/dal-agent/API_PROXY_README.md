# Scout Dashboard API Proxy Configuration

This document explains how the API proxy is configured to route requests from the Azure Static Web App to the existing Azure Function App.

## Architecture Overview

```
User Browser
    ↓
Azure Static Web App (Frontend)
    ↓ /api/* requests
Azure Functions (scout-func-prod)
    ↓
Azure SQL Database
```

## Configuration Files

### 1. `staticwebapp.config.json`
- **Purpose**: Azure Static Web Apps configuration
- **Key Features**:
  - Routes all `/api/*` requests to the Function App
  - Configures CORS headers
  - Sets up authentication with Azure AD
  - Defines navigation fallback for SPA routing

### 2. `next.config.js`
- **Purpose**: Next.js build configuration for static export
- **Key Features**:
  - Enables static export mode (`output: 'export'`)
  - Configures API rewrites to Function App
  - Sets security headers
  - Optimizes build for Azure Static Web Apps

### 3. `api-proxy.config.js`
- **Purpose**: Development proxy configuration
- **Key Features**:
  - Maps frontend API calls to Function App endpoints
  - Provides error handling and logging
  - Documents available API endpoints

## API Endpoints

The following endpoints are proxied from the Static Web App to the Function App:

| Frontend Route | Function App Route | Methods | Description |
|---------------|-------------------|---------|-------------|
| `/api/health` | `/api/health` | GET | Health check |
| `/api/query` | `/api/query` | POST | SQL analytics |
| `/api/analyze` | `/api/analyze` | POST | Data analysis |
| `/api/insights` | `/api/insights` | GET, POST | Dashboard data |
| `/api/search` | `/api/search` | POST | AI search |
| `/api/etl-trigger` | `/api/etl-trigger` | POST | ETL operations |

## Environment Configuration

### Production (Azure Static Web App)
- API proxy configured via `staticwebapp.config.json`
- Function App URL: `https://scout-func-prod.azurewebsites.net`
- Authentication: Azure AD integration
- CORS: Configured for cross-origin requests

### Development (Local)
- API proxy configured via `next.config.js` rewrites
- Function App URL: Set via `FUNCTIONS_API_URL` environment variable
- Authentication: Mock/bypass for development
- CORS: Development-friendly configuration

## Security Features

### Headers
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Content-Security-Policy`: Restrictive CSP with Function App allowlist
- `Access-Control-Allow-Origin`: Controlled CORS

### Authentication
- Azure AD integration via Static Web Apps auth
- Role-based access control (currently set to anonymous for dashboard access)
- JWT token validation handled by Azure Static Web Apps

### Network Security
- Allowed hosts configuration
- Request/response validation
- Timeout configurations

## Deployment

### 1. Build Dashboard
```bash
npm run build:swa
```

### 2. Deploy Infrastructure
```bash
./scripts/deploy_dashboard.sh
```

### 3. Validate Deployment
```bash
# Test Static Web App
curl https://swa-scout-dashboard-prod.azurestaticapps.net

# Test API proxy
curl https://swa-scout-dashboard-prod.azurestaticapps.net/api/health
```

## Troubleshooting

### Common Issues

1. **API requests failing**
   - Check Function App is running: `curl https://scout-func-prod.azurewebsites.net/api/health`
   - Verify CORS configuration in `staticwebapp.config.json`
   - Check Azure Static Web App logs

2. **Authentication issues**
   - Verify Azure AD configuration in Azure Portal
   - Check client ID and secret in Key Vault
   - Validate token in browser developer tools

3. **Routing issues**
   - Verify `navigationFallback` configuration
   - Check route patterns in `staticwebapp.config.json`
   - Ensure Next.js build completed successfully

### Monitoring

- Azure Static Web App logs: Available in Azure Portal
- Function App logs: Monitor via Application Insights
- Network requests: Browser developer tools
- API performance: Function App metrics

## Development Workflow

1. **Local Development**
   ```bash
   npm run dev
   # API calls automatically proxy to Function App
   ```

2. **Build and Test**
   ```bash
   npm run build:swa
   # Test static build locally
   ```

3. **Deploy**
   ```bash
   npm run azure:deploy
   # Deploy to Azure Static Web Apps
   ```

## Configuration Updates

When updating the API proxy configuration:

1. Update `staticwebapp.config.json` for production routing
2. Update `next.config.js` for development proxy
3. Update `api-proxy.config.js` documentation
4. Test locally with `npm run dev`
5. Deploy with `npm run azure:deploy`

## Security Considerations

- Function App CORS must allow Static Web App domain
- API keys managed via Azure Key Vault
- Authentication tokens validated by Azure Static Web Apps
- Network access restricted to allowed hosts only