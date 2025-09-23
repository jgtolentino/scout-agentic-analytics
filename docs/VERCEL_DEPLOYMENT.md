# Vercel Deployment Guide - Scout Export API

## Environment Variables Required

Set these in Vercel dashboard under Settings → Environment Variables:

### Required for Export API
```bash
# Export API Configuration
EXPORT_DELEGATION_MODE=resolve

# Azure SQL Database (Reader Access)
AZSQL_HOST=sqltbwaprojectscoutserver.database.windows.net
AZSQL_DB=flat_scratch
AZSQL_USER=scout_reader
AZSQL_PASS=*** # Secure password from Bruno vault

# Optional: Bruno Webhook (for delegate mode)
BRUNO_WEBHOOK_URL=https://bruno.local/export
BRUNO_WEBHOOK_SECRET=*** # HMAC secret for webhook validation
```

### Deployment Configuration

The `vercel.json` configuration:
- **Build Command**: `npm run build` (explicit Next.js build)
- **Runtime**: Node.js 20.x (locked for consistency)
- **Memory**: 512MB for export API functions
- **Timeout**: 10 seconds for SQL query execution
- **Security Headers**: XSS protection, content type validation, frame denial

### Export API Endpoints

Once deployed, available at:
- `GET /api/export/list` - List available export types
- `POST /api/export/{type}` - Execute predefined export (crosstab_14d, brands_summary, etc.)
- `POST /api/export/custom` - Execute custom SQL with validation

### Security Features

1. **SQL Injection Prevention**: Strict allow-listing of tables, functions, keywords
2. **Zero-Credential Architecture**: Database passwords never in application code
3. **Privacy Protection**: Transcript-free export variants available
4. **Bruno Integration**: Copy-paste commands for secure execution
5. **Request Validation**: 5000-character limit, SELECT-only queries

### Testing Deployment

```bash
# Test export list
curl https://your-vercel-domain.vercel.app/api/export/list

# Test predefined export
curl -X POST https://your-vercel-domain.vercel.app/api/export/crosstab_14d

# Test custom export
curl -X POST https://your-vercel-domain.vercel.app/api/export/custom \
  -H 'Content-Type: application/json' \
  -d '{"sql":"SELECT TOP (10) * FROM gold.v_transactions_flat ORDER BY txn_ts DESC"}'
```

## Deployment Steps

1. **Set Environment Variables** in Vercel dashboard
2. **Git Commit** changes with vercel.json
3. **Push to main** branch for automatic deployment
4. **Verify** API endpoints are accessible
5. **Test** export functionality with Bruno integration

The system is now production-ready with comprehensive security controls and monitoring.