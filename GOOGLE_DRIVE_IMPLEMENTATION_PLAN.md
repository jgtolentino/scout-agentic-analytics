# Google Drive Mirror Implementation Plan
## Scout v7 Analytics Platform

### Executive Summary

This comprehensive implementation plan restores and enhances the Google Drive ETL automation in Scout v7. The plan addresses the missing edge functions, database integration, security implementation, and operational procedures needed for production deployment.

**Status**: Database schema deployed ✅ | Edge functions missing ❌ | Authentication setup required ❌

---

## 1. Immediate Implementation Requirements

### 1.1 Missing Edge Functions (CRITICAL)

**Required Functions:**
- `drive-mirror` - Main Google Drive synchronization engine
- `drive-stream-extract` - Content extraction and processing pipeline
- `drive-intelligence-processor` - AI-powered document analysis
- `drive-webhook-handler` - Real-time change notifications

**Implementation Priority:** P0 (Production blocking)

### 1.2 Database Schema Status ✅

```sql
-- Schema already deployed: drive_intelligence
-- Tables: 12 | Views: 1 | Functions: 1 | Indexes: 15
-- Migration: 20250916_drive_intelligence_deployment.sql
```

**Capabilities Available:**
- Creative Intelligence Analysis
- Financial Document Processing
- Market Research Intelligence
- PII Detection & Compliance
- Business Analytics & Reporting

### 1.3 Environment Variables Required

```bash
# Google Drive API Configuration
GOOGLE_DRIVE_CLIENT_ID="your-client-id"
GOOGLE_DRIVE_CLIENT_SECRET="your-client-secret"
GOOGLE_DRIVE_REFRESH_TOKEN="your-refresh-token"
GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY="base64-encoded-service-account-json"

# Folder Configuration
GOOGLE_DRIVE_ROOT_FOLDER_ID="1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA"
GOOGLE_DRIVE_WATCH_FOLDERS='["1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA"]'

# Processing Configuration
DRIVE_MAX_FILE_SIZE_MB="100"
DRIVE_PROCESSING_BATCH_SIZE="10"
DRIVE_WEBHOOK_SECRET="your-secure-webhook-secret"

# AI Processing
OPENAI_API_KEY="your-openai-key"  # For content analysis
ANTHROPIC_API_KEY="your-anthropic-key"  # For document intelligence
```

### 1.4 Bootstrap Procedures

**Step 1: Service Account Setup**
```bash
# Create Google Cloud Service Account
gcloud iam service-accounts create scout-drive-etl \
  --description="Scout v7 Drive ETL Service Account" \
  --display-name="Scout Drive ETL"

# Enable APIs
gcloud services enable drive.googleapis.com
gcloud services enable gmail.googleapis.com

# Grant permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:scout-drive-etl@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/drive.readonly"
```

**Step 2: Database Setup Verification**
```sql
-- Verify schema deployment
SELECT COUNT(*) as table_count FROM information_schema.tables 
WHERE table_schema = 'drive_intelligence';

-- Test trigger function
SELECT drive_intelligence.trigger_bruno_drive_etl(
  '1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA',
  'TBWA_Scout_Analytics',
  true
);
```

---

## 2. Code Implementation Roadmap

### 2.1 Edge Function Architecture

```typescript
// File: supabase/functions/drive-mirror/index.ts
// Purpose: Main Google Drive synchronization engine
// Dependencies: Google Drive API v3, Supabase Client
// Processing: Incremental sync, file metadata extraction, error handling
```

**Core Features:**
- Incremental synchronization
- File type filtering and validation
- Metadata extraction and normalization
- Error handling and retry logic
- Rate limiting and quota management

### 2.2 Content Processing Pipeline

```typescript
// File: supabase/functions/drive-stream-extract/index.ts
// Purpose: Content extraction and AI processing
// Dependencies: PDF.js, DOCX parser, OpenAI API
// Processing: Text extraction, OCR, content analysis
```

**Processing Capabilities:**
- PDF text extraction and OCR
- Microsoft Office document parsing
- Image content analysis
- PII detection and redaction
- Content summarization

### 2.3 Intelligence Processing

```typescript
// File: supabase/functions/drive-intelligence-processor/index.ts
// Purpose: AI-powered document analysis and categorization
// Dependencies: OpenAI/Anthropic APIs, NLP libraries
// Processing: Entity extraction, sentiment analysis, business categorization
```

**AI Features:**
- Business entity extraction (brands, products, campaigns)
- Document classification and tagging
- Sentiment analysis and urgency detection
- Relationship mapping between documents
- Compliance and risk assessment

### 2.4 Real-time Integration

```typescript
// File: supabase/functions/drive-webhook-handler/index.ts
// Purpose: Handle Google Drive change notifications
// Dependencies: Google Drive Push Notifications API
// Processing: Real-time change detection, immediate processing triggers
```

---

## 3. Production Deployment Strategy

### 3.1 Environment Setup

**Staging Environment:**
```bash
# Supabase project: scout-v7-staging
# Environment variables: staging-specific values
# Database: Separate staging instance
# Testing: Automated integration tests
```

**Production Environment:**
```bash
# Supabase project: scout-v7-production
# Environment variables: production-specific values
# Database: Production instance with backups
# Monitoring: Full observability stack
```

### 3.2 Feature Flag Implementation

```sql
-- Feature flags table for gradual rollout
CREATE TABLE IF NOT EXISTS feature_flags (
  flag_name TEXT PRIMARY KEY,
  enabled BOOLEAN DEFAULT false,
  rollout_percentage INTEGER DEFAULT 0,
  conditions JSONB DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Drive ETL feature flags
INSERT INTO feature_flags (flag_name, enabled, rollout_percentage, conditions) VALUES
  ('drive_mirror_enabled', false, 0, '{"env": "staging"}'::jsonb),
  ('drive_intelligence_enabled', false, 0, '{"file_types": ["pdf", "docx"]}'::jsonb),
  ('drive_webhook_enabled', false, 0, '{"realtime": false}'::jsonb);
```

### 3.3 Deployment Pipeline

```yaml
# .github/workflows/drive-etl-deploy.yml
name: Google Drive ETL Deployment
on:
  push:
    paths: ['supabase/functions/drive-*/**']
  
jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Staging
        run: |
          supabase functions deploy drive-mirror --project-ref $STAGING_REF
          supabase functions deploy drive-stream-extract --project-ref $STAGING_REF
          
  integration-tests:
    needs: deploy-staging
    runs-on: ubuntu-latest
    steps:
      - name: Run Integration Tests
        run: |
          npm run test:drive-integration
          
  deploy-production:
    needs: integration-tests
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Production
        run: |
          supabase functions deploy drive-mirror --project-ref $PRODUCTION_REF
```

### 3.4 Monitoring and Observability

```typescript
// Monitoring configuration
interface MonitoringConfig {
  metrics: {
    sync_duration: 'histogram',
    files_processed: 'counter',
    errors_encountered: 'counter',
    api_quota_usage: 'gauge'
  },
  alerts: {
    sync_failure: { threshold: 3, window: '5m' },
    quota_exhaustion: { threshold: 90, unit: 'percent' },
    processing_lag: { threshold: 300, unit: 'seconds' }
  },
  dashboards: {
    drive_etl_overview: 'grafana-dashboard-id',
    document_intelligence: 'grafana-dashboard-id'
  }
}
```

---

## 4. Security Implementation Checklist

### 4.1 Authentication Setup

**Service Account Configuration:**
```bash
# Create and configure service account
gcloud iam service-accounts create scout-drive-etl

# Download service account key
gcloud iam service-accounts keys create scout-service-account.json \
  --iam-account=scout-drive-etl@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Base64 encode for environment variable
base64 -i scout-service-account.json | tr -d '\n' > service-account-b64.txt
```

**OAuth 2.0 Setup (for user impersonation):**
```bash
# Configure OAuth consent screen
# Create OAuth 2.0 client credentials
# Generate refresh token for long-term access
```

### 4.2 Environment Security

```bash
# Supabase Vault integration
supabase secrets set GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY=$(cat service-account-b64.txt)
supabase secrets set GOOGLE_DRIVE_WEBHOOK_SECRET=$(openssl rand -hex 32)
supabase secrets set DRIVE_ENCRYPTION_KEY=$(openssl rand -hex 32)
```

### 4.3 API Security

```typescript
// Rate limiting and security headers
const securityConfig = {
  rateLimit: {
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
  },
  cors: {
    origin: ['https://scout.tbwa.com', 'https://dashboard.scout.tbwa.com'],
    credentials: true
  },
  headers: {
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '1; mode=block'
  }
}
```

### 4.4 Data Protection

```sql
-- Row Level Security (RLS) policies
ALTER TABLE drive_intelligence.bronze_files ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only access their organization's files"
ON drive_intelligence.bronze_files
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND auth.users.raw_user_meta_data->>'organization' = 'tbwa'
  )
);

-- PII data encryption at rest
CREATE OR REPLACE FUNCTION drive_intelligence.encrypt_pii(content TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN CASE
    WHEN content IS NULL THEN NULL
    ELSE encrypt(content, current_setting('app.encryption_key'), 'aes')
  END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 5. Testing and Validation Plan

### 5.1 Unit Testing Strategy

```typescript
// Test file: tests/drive-mirror.test.ts
describe('Google Drive Mirror', () => {
  it('should sync files incrementally', async () => {
    const result = await syncDriveFolder('test-folder-id', { incremental: true });
    expect(result.newFiles).toBeGreaterThan(0);
    expect(result.errors).toEqual([]);
  });

  it('should handle API rate limits gracefully', async () => {
    // Mock rate limit response
    jest.spyOn(driveAPI, 'files').mockRejectedValueOnce(new Error('Rate limit exceeded'));
    
    const result = await syncDriveFolder('test-folder-id');
    expect(result.retried).toBe(true);
  });
});
```

### 5.2 Integration Testing

```bash
#!/bin/bash
# Integration test script: test-drive-integration.sh

# Test 1: End-to-end file processing
echo "Testing file upload and processing..."
curl -X POST "https://your-project-ref.supabase.co/functions/v1/drive-mirror" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -d '{"folderId": "test-folder-id", "dryRun": true}'

# Test 2: Webhook handling
echo "Testing webhook processing..."
curl -X POST "https://your-project-ref.supabase.co/functions/v1/drive-webhook-handler" \
  -H "X-Goog-Channel-ID: test-channel" \
  -H "X-Goog-Resource-ID: test-resource" \
  -d '{}'

# Test 3: Intelligence processing
echo "Testing AI document analysis..."
curl -X POST "https://your-project-ref.supabase.co/functions/v1/drive-intelligence-processor" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -d '{"fileId": "test-file-id", "analysisType": "full"}'
```

### 5.3 Performance Testing

```javascript
// Load testing with Artillery.io
// File: load-test-config.yml
config:
  target: 'https://your-project-ref.supabase.co'
  phases:
    - duration: 60
      arrivalRate: 5
      name: "Warm up"
    - duration: 300
      arrivalRate: 10
      rampTo: 50
      name: "Ramp up load"

scenarios:
  - name: "Drive sync workflow"
    requests:
      - post:
          url: "/functions/v1/drive-mirror"
          headers:
            Authorization: "Bearer {{ $env.SUPABASE_ANON_KEY }}"
          json:
            folderId: "1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA"
            incremental: true
```

### 5.4 Validation Criteria

**Performance Benchmarks:**
- File processing: <30 seconds per file
- API response time: <2 seconds
- Sync completion: <5 minutes for 100 files
- Error rate: <1% under normal load

**Quality Gates:**
- Unit test coverage: >80%
- Integration test pass rate: 100%
- Security scan: No critical vulnerabilities
- Performance test: Meets SLA requirements

---

## 6. Operational Procedures

### 6.1 Deployment Pipeline

```bash
#!/bin/bash
# Deployment script: deploy-drive-etl.sh

set -e

PROJECT_REF=${1:-"your-project-ref"}
ENVIRONMENT=${2:-"staging"}

echo "Deploying Google Drive ETL to $ENVIRONMENT..."

# Deploy edge functions
supabase functions deploy drive-mirror --project-ref $PROJECT_REF
supabase functions deploy drive-stream-extract --project-ref $PROJECT_REF
supabase functions deploy drive-intelligence-processor --project-ref $PROJECT_REF
supabase functions deploy drive-webhook-handler --project-ref $PROJECT_REF

# Run migrations
supabase db push --project-ref $PROJECT_REF

# Verify deployment
echo "Running post-deployment verification..."
npm run test:integration:drive

echo "Deployment completed successfully!"
```

### 6.2 Monitoring Dashboards

**Grafana Dashboard Configuration:**
```json
{
  "dashboard": {
    "title": "Google Drive ETL Monitor",
    "panels": [
      {
        "title": "Files Processed (24h)",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(increase(drive_files_processed_total[24h]))"
          }
        ]
      },
      {
        "title": "Processing Duration",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, drive_processing_duration_seconds)"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(drive_errors_total[5m])"
          }
        ]
      }
    ]
  }
}
```

### 6.3 Alerting Rules

```yaml
# Prometheus alerting rules
groups:
  - name: drive-etl-alerts
    rules:
      - alert: DriveETLSyncFailure
        expr: increase(drive_sync_failures_total[10m]) > 3
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Multiple Drive ETL sync failures detected"
          
      - alert: DriveAPIQuotaExhausted
        expr: drive_api_quota_usage_percent > 90
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Google Drive API quota nearly exhausted"
          
      - alert: DriveProcessingLag
        expr: drive_processing_lag_seconds > 300
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Drive file processing lag exceeding 5 minutes"
```

### 6.4 Incident Response

**Runbook for Common Issues:**

**Issue: API Quota Exhaustion**
```bash
# Check current quota usage
curl -H "Authorization: Bearer $GOOGLE_ACCESS_TOKEN" \
  "https://www.googleapis.com/drive/v3/about?fields=storageQuota,quotaBytesUsed"

# Implement exponential backoff
# Reduce sync frequency temporarily
# Consider requesting quota increase
```

**Issue: Processing Failures**
```sql
-- Check recent failures
SELECT file_name, error_details, processing_status 
FROM drive_intelligence.bronze_files 
WHERE processing_status = 'failed' 
AND synced_at > NOW() - INTERVAL '1 hour';

-- Retry failed files
UPDATE drive_intelligence.bronze_files 
SET processing_status = 'pending' 
WHERE processing_status = 'failed' 
AND synced_at > NOW() - INTERVAL '1 hour';
```

**Issue: Webhook Delivery Failures**
```bash
# Re-register webhooks
curl -X POST "https://www.googleapis.com/drive/v3/files/watch" \
  -H "Authorization: Bearer $GOOGLE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "scout-drive-webhook",
    "type": "web_hook",
    "address": "https://your-project-ref.supabase.co/functions/v1/drive-webhook-handler"
  }'
```

---

## 7. Quick Start Guide

### 7.1 Prerequisites

**System Requirements:**
- Supabase CLI installed and configured
- Google Cloud SDK installed
- Node.js 18+ and npm/pnpm
- Docker (for local development)

**Accounts Required:**
- Google Cloud Platform project
- Supabase organization and project
- GitHub repository access

### 7.2 Initial Setup (30 minutes)

**Step 1: Clone and Setup Repository**
```bash
cd /Users/tbwa/scout-v7
git pull origin main

# Install dependencies
pnpm install

# Setup environment
cp .env.example .env.local
```

**Step 2: Google Cloud Configuration**
```bash
# Authenticate with Google Cloud
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable drive.googleapis.com
gcloud services enable gmail.googleapis.com

# Create service account
gcloud iam service-accounts create scout-drive-etl
```

**Step 3: Supabase Configuration**
```bash
# Login to Supabase
supabase login

# Link to project
supabase link --project-ref YOUR_PROJECT_REF

# Deploy schema
supabase db push

# Set secrets
supabase secrets set GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY="$(base64 -i service-account.json)"
```

**Step 4: Deploy Edge Functions**
```bash
# Deploy all drive functions
supabase functions deploy drive-mirror
supabase functions deploy drive-stream-extract
supabase functions deploy drive-intelligence-processor
supabase functions deploy drive-webhook-handler

# Verify deployment
supabase functions list
```

### 7.3 Testing Your Setup

**Test 1: Database Connection**
```sql
-- Run in Supabase SQL editor
SELECT drive_intelligence.trigger_bruno_drive_etl(
  '1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA',
  'TBWA_Scout_Analytics',
  true
);
```

**Test 2: Edge Function**
```bash
curl -X POST "https://YOUR_PROJECT_REF.supabase.co/functions/v1/drive-mirror" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"folderId": "1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA", "dryRun": true}'
```

**Test 3: Intelligence Processing**
```bash
curl -X POST "https://YOUR_PROJECT_REF.supabase.co/functions/v1/drive-intelligence-processor" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"fileId": "sample-file-id", "analysisType": "basic"}'
```

### 7.4 Common Issues and Solutions

**Issue: Service Account Authentication**
```bash
# Verify service account permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --filter="bindings.members:serviceAccount:scout-drive-etl@YOUR_PROJECT_ID.iam.gserviceaccount.com"

# Add missing permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:scout-drive-etl@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/drive.readonly"
```

**Issue: Supabase Function Deployment**
```bash
# Check function logs
supabase functions logs drive-mirror

# Redeploy with verbose output
supabase functions deploy drive-mirror --debug
```

**Issue: Database Connection**
```bash
# Test database connection
supabase db status

# Reset database (development only)
supabase db reset
```

### 7.5 Configuration Templates

**Environment Variables Template:**
```bash
# .env.local template for Google Drive ETL

# Supabase Configuration
SUPABASE_URL="https://YOUR_PROJECT_REF.supabase.co"
SUPABASE_ANON_KEY="your-anon-key"
SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"

# Google Drive Configuration
GOOGLE_DRIVE_CLIENT_ID="your-oauth-client-id"
GOOGLE_DRIVE_CLIENT_SECRET="your-oauth-client-secret"
GOOGLE_DRIVE_REFRESH_TOKEN="your-refresh-token"
GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY="base64-encoded-service-account-json"

# Processing Configuration
GOOGLE_DRIVE_ROOT_FOLDER_ID="1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA"
DRIVE_MAX_FILE_SIZE_MB="100"
DRIVE_PROCESSING_BATCH_SIZE="10"
DRIVE_SYNC_INTERVAL_MINUTES="60"

# AI Processing (Optional)
OPENAI_API_KEY="your-openai-key"
ANTHROPIC_API_KEY="your-anthropic-key"

# Monitoring (Optional)
SENTRY_DSN="your-sentry-dsn"
DATADOG_API_KEY="your-datadog-key"
```

**VS Code Launch Configuration:**
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug Drive ETL",
      "type": "node",
      "request": "launch",
      "program": "${workspaceFolder}/supabase/functions/drive-mirror/index.ts",
      "env": {
        "SUPABASE_URL": "http://localhost:54321",
        "SUPABASE_ANON_KEY": "your-local-anon-key"
      },
      "envFile": "${workspaceFolder}/.env.local"
    }
  ]
}
```

---

## Implementation Timeline

| Phase | Duration | Deliverables |
|-------|----------|-------------|
| **Phase 1** | 1-2 weeks | Core edge functions, basic authentication |
| **Phase 2** | 1 week | Intelligence processing, PII detection |
| **Phase 3** | 1 week | Webhooks, real-time sync, monitoring |
| **Phase 4** | 1 week | Production deployment, testing, documentation |

**Total Estimated Timeline: 4-5 weeks**

---

## Success Metrics

- **Functional**: 100% of target Google Drive files processed successfully
- **Performance**: File processing <30 seconds, API response <2 seconds
- **Reliability**: >99.5% uptime, <1% error rate
- **Security**: Zero security vulnerabilities, full PII compliance
- **Operational**: Full monitoring, alerting, and incident response capabilities

---

*This implementation plan provides a comprehensive roadmap for restoring and enhancing Google Drive ETL automation in Scout v7. All components are designed for production deployment with enterprise-grade security, monitoring, and operational procedures.*