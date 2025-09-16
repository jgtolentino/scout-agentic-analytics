# Comprehensive Authentication and Permissions Strategy for Google Drive to Supabase Storage Mirroring

## Executive Summary

This document provides enterprise-grade authentication and authorization strategies for implementing secure Google Drive to Supabase Storage mirroring. Based on 2024 security best practices, this analysis covers authentication methods, permission models, security patterns, and implementation recommendations for production deployments.

## 1. Google Drive Authentication Options

### 1.1 Service Account Authentication

**Overview**: Service accounts are non-human accounts that belong to your application rather than individual users. They enable server-to-server authentication without user interaction.

**Implementation Pattern**:
```typescript
// Service Account with JWT Authentication
import { GoogleAuth } from 'google-auth-library';

const auth = new GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/drive.file'],
  credentials: {
    type: 'service_account',
    project_id: process.env.GOOGLE_PROJECT_ID,
    private_key: process.env.GOOGLE_PRIVATE_KEY.replace(/\\n/g, '\n'),
    client_email: process.env.GOOGLE_CLIENT_EMAIL,
  }
});

// Generate short-lived access tokens (recommended)
const accessToken = await auth.getAccessToken();
```

**Security Considerations**:
- ✅ Bypasses user consent flow
- ✅ Ideal for automated processes
- ⚠️ Requires careful private key management
- ⚠️ Cannot access user-owned files unless explicitly shared

**Best Practices**:
- Use short-lived OAuth 2.0 access tokens (1-hour expiry)
- Avoid service account keys when possible
- Implement domain-wide delegation for enterprise scenarios
- Store private keys in secure secret management systems

### 1.2 OAuth 2.0 User Authentication

**Overview**: OAuth 2.0 flow enables user-authorized access to Google Drive files with explicit consent.

**Implementation Pattern**:
```typescript
// OAuth 2.0 Flow Implementation
import { OAuth2Client } from 'google-auth-library';

const oauth2Client = new OAuth2Client({
  clientId: process.env.GOOGLE_CLIENT_ID,
  clientSecret: process.env.GOOGLE_CLIENT_SECRET,
  redirectUri: process.env.GOOGLE_REDIRECT_URI
});

// Authorization URL with minimal scopes
const authUrl = oauth2Client.generateAuthUrl({
  access_type: 'offline',
  scope: ['https://www.googleapis.com/auth/drive.file'],
  prompt: 'consent'
});

// Exchange authorization code for tokens
const { tokens } = await oauth2Client.getToken(authorizationCode);
oauth2Client.setCredentials(tokens);
```

**Security Considerations**:
- ✅ User explicit consent required
- ✅ Granular file access control
- ✅ Refresh token for long-term access
- ⚠️ Requires HTTPS redirect URIs
- ⚠️ More complex token management

### 1.3 Application Default Credentials (ADC)

**Overview**: Simplified authentication pattern that automatically discovers credentials based on environment.

**Implementation Pattern**:
```typescript
// ADC Implementation
import { GoogleAuth } from 'google-auth-library';

const auth = new GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/drive.file']
});

// Automatically discovers credentials from:
// 1. GOOGLE_APPLICATION_CREDENTIALS environment variable
// 2. Google Cloud SDK default credentials
// 3. Compute Engine metadata service
```

### 1.4 Workload Identity Federation

**Overview**: Keyless authentication for cloud workloads using external identity providers.

**Implementation Pattern**:
```typescript
// Workload Identity Federation Setup
const auth = new GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/drive.file'],
  projectId: process.env.GOOGLE_PROJECT_ID,
  // Automatically uses federated credentials
});

// For Supabase Edge Functions integration
export default async function handler(req: Request) {
  const auth = new GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/drive.file']
  });
  
  const authClient = await auth.getClient();
  const accessToken = await authClient.getAccessToken();
  
  // Use federated token for Drive API calls
}
```

**Benefits**:
- ✅ No service account keys to manage
- ✅ Automatic credential rotation
- ✅ Integration with cloud-native identity systems
- ✅ Enhanced security posture

## 2. Service Account vs OAuth Decision Matrix

### 2.1 Decision Framework

| Factor | Service Account | OAuth 2.0 | Recommendation |
|--------|----------------|-----------|----------------|
| **Use Case** | Automated processes | User-owned files | Context-dependent |
| **File Access** | App-created only | User-authorized | OAuth for user files |
| **Consent Flow** | None required | User consent | OAuth for transparency |
| **Key Management** | Complex | Moderate | Service Account with WIF |
| **Enterprise Scale** | Domain delegation | Per-user tokens | Service Account |
| **Security Posture** | High (if managed) | High | Equal with proper impl |

### 2.2 Hybrid Architecture Pattern

```typescript
// Hybrid Authentication Strategy
class DriveAuthManager {
  private serviceAuth: GoogleAuth;
  private oauthClient: OAuth2Client;
  
  constructor() {
    // Service account for system operations
    this.serviceAuth = new GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/drive.file'],
      // Use Workload Identity Federation
    });
    
    // OAuth for user file access
    this.oauthClient = new OAuth2Client({
      clientId: process.env.GOOGLE_CLIENT_ID,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    });
  }
  
  async getAuthClient(context: 'system' | 'user', userTokens?: any) {
    switch (context) {
      case 'system':
        return await this.serviceAuth.getClient();
      case 'user':
        this.oauthClient.setCredentials(userTokens);
        return this.oauthClient;
    }
  }
}
```

### 2.3 Security Implementation Comparison

**Service Account Security Pattern**:
```typescript
// Secure Service Account Implementation
const getSecureServiceAccount = async () => {
  // 1. Use secret manager for credentials
  const credentials = await getFromSecretManager('google-service-account');
  
  // 2. Short-lived token generation
  const auth = new GoogleAuth({
    credentials: JSON.parse(credentials),
    scopes: ['https://www.googleapis.com/auth/drive.file']
  });
  
  // 3. Token caching with expiration
  const token = await auth.getAccessToken();
  await cacheToken(token, 3600); // 1-hour cache
  
  return auth;
};
```

**OAuth Security Pattern**:
```typescript
// Secure OAuth Implementation
const getSecureOAuthClient = async (userId: string) => {
  // 1. Retrieve encrypted tokens
  const encryptedTokens = await getUserTokens(userId);
  const tokens = await decrypt(encryptedTokens);
  
  // 2. Token validation and refresh
  oauth2Client.setCredentials(tokens);
  
  try {
    // 3. Validate token and refresh if needed
    const tokenInfo = await oauth2Client.getTokenInfo(tokens.access_token);
    if (tokenInfo.expiry_date < Date.now()) {
      const { credentials } = await oauth2Client.refreshAccessToken();
      await storeEncryptedTokens(userId, credentials);
    }
  } catch (error) {
    // Token refresh or re-authorization needed
    throw new Error('Token refresh required');
  }
  
  return oauth2Client;
};
```

## 3. Supabase Authentication Integration

### 3.1 Service Role vs JWT Architecture

**Service Role Pattern (Backend Operations)**:
```typescript
// Service Role for Administrative Operations
import { createClient } from '@supabase/supabase-js';

const supabaseAdmin = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!, // Never expose client-side
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  }
);

// Bypasses RLS - use for system operations only
const { data, error } = await supabaseAdmin
  .storage
  .from('drive-mirror')
  .upload(`${userId}/${fileId}`, fileBuffer, {
    cacheControl: '3600',
    upsert: false
  });
```

**JWT Pattern (User Operations)**:
```typescript
// JWT-based User Authentication
import { createClient } from '@supabase/supabase-js';

const supabaseClient = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY! // Safe for client-side
);

// User authentication
const { data: { user }, error } = await supabaseClient.auth.signInWithOAuth({
  provider: 'google',
  options: {
    scopes: 'openid email profile',
    redirectTo: `${process.env.SITE_URL}/auth/callback`
  }
});

// RLS-protected operations
const { data, error } = await supabaseClient
  .storage
  .from('drive-mirror')
  .upload(`files/${fileId}`, fileBuffer);
```

### 3.2 Row Level Security (RLS) Policy Design

**Multi-tenant File Access Policies**:
```sql
-- Enable RLS on storage objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- User can only access their own files
CREATE POLICY "Users can access own files" ON storage.objects
  FOR ALL USING (
    bucket_id = 'drive-mirror' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Admin service role bypass (automatic with service_role)
-- No explicit policy needed - service_role has BYPASSRLS

-- Shared file access policy
CREATE POLICY "Shared file access" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'drive-mirror' AND
    EXISTS (
      SELECT 1 FROM public.file_shares
      WHERE file_path = storage.objects.name
      AND shared_with_user_id = auth.uid()
    )
  );
```

**Custom Claims for Role-Based Access**:
```typescript
// Edge Function: Custom Claims Hook
export default async function handler(req: Request) {
  const { user, claims } = await req.json();
  
  // Add custom claims based on user role
  const customClaims = {
    ...claims,
    app_role: await getUserRole(user.id),
    organization_id: await getUserOrganization(user.id),
    drive_permissions: await getDrivePermissions(user.id)
  };
  
  return new Response(JSON.stringify({ claims: customClaims }), {
    headers: { 'Content-Type': 'application/json' }
  });
}
```

### 3.3 Multi-tenancy Patterns

**Organization-based Isolation**:
```sql
-- Organization-based RLS policy
CREATE POLICY "Organization file access" ON storage.objects
  FOR ALL USING (
    bucket_id = 'drive-mirror' AND
    (storage.foldername(name))[1] = (auth.jwt() ->> 'organization_id')
  );

-- Cross-organization sharing
CREATE POLICY "Cross-org shared access" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'drive-mirror' AND
    EXISTS (
      SELECT 1 FROM public.organization_shares
      WHERE source_org_id = (storage.foldername(name))[1]
      AND target_org_id = (auth.jwt() ->> 'organization_id')
      AND file_pattern = storage.objects.name
    )
  );
```

## 4. Permission Scopes and Access Control

### 4.1 Minimum Required Google Drive API Scopes

**2024 Recommended Scopes**:
```typescript
// Minimal scope configuration
const RECOMMENDED_SCOPES = [
  'https://www.googleapis.com/auth/drive.file', // Per-file access (recommended)
  'https://www.googleapis.com/auth/drive.appdata' // Application data folder
];

// Alternative scopes (requires additional verification)
const RESTRICTED_SCOPES = [
  'https://www.googleapis.com/auth/drive.readonly', // Read-only access
  'https://www.googleapis.com/auth/drive' // Full access (requires CASA assessment)
];
```

**Scope Selection Strategy**:
```typescript
class ScopeManager {
  static selectScopes(useCase: string): string[] {
    switch (useCase) {
      case 'user-selective-sync':
        return ['https://www.googleapis.com/auth/drive.file'];
      
      case 'backup-service':
        return [
          'https://www.googleapis.com/auth/drive.file',
          'https://www.googleapis.com/auth/drive.appdata'
        ];
      
      case 'migration-tool':
        // Requires additional verification
        return ['https://www.googleapis.com/auth/drive.readonly'];
      
      default:
        return ['https://www.googleapis.com/auth/drive.file'];
    }
  }
}
```

### 4.2 Supabase Bucket Policies

**Granular Bucket Configuration**:
```typescript
// Bucket policy setup
const createSecureBucket = async () => {
  const { data, error } = await supabaseAdmin.storage.createBucket('drive-mirror', {
    public: false,
    allowedMimeTypes: [
      'image/*',
      'application/pdf',
      'text/*',
      'application/vnd.google-apps.*'
    ],
    fileSizeLimit: 104857600, // 100MB
    transformations: {
      allowedTransforms: ['resize', 'format']
    }
  });
  
  // Set bucket policies via SQL
  await supabaseAdmin.rpc('create_bucket_policies', {
    bucket_name: 'drive-mirror'
  });
};
```

### 4.3 Cross-platform Permission Mapping

**Permission Translation Layer**:
```typescript
// Google Drive to Supabase permission mapping
class PermissionMapper {
  static mapDriveToSupabase(drivePermission: string): string[] {
    const mapping = {
      'owner': ['read', 'write', 'delete', 'share'],
      'organizer': ['read', 'write', 'delete', 'share'],
      'fileOrganizer': ['read', 'write', 'delete'],
      'writer': ['read', 'write'],
      'commenter': ['read', 'comment'],
      'reader': ['read']
    };
    
    return mapping[drivePermission] || ['read'];
  }
  
  static createRLSPolicy(fileId: string, permissions: string[]): string {
    const conditions = permissions.map(perm => {
      switch (perm) {
        case 'read':
          return `auth.uid() IN (SELECT user_id FROM file_permissions WHERE file_id = '${fileId}' AND permission >= 'read')`;
        case 'write':
          return `auth.uid() IN (SELECT user_id FROM file_permissions WHERE file_id = '${fileId}' AND permission >= 'write')`;
        case 'delete':
          return `auth.uid() IN (SELECT user_id FROM file_permissions WHERE file_id = '${fileId}' AND permission = 'owner')`;
        default:
          return 'false';
      }
    });
    
    return conditions.join(' OR ');
  }
}
```

## 5. Production Security Patterns

### 5.1 Credential Rotation Strategies

**Automated Rotation Implementation**:
```typescript
// Credential rotation service
class CredentialRotationService {
  private rotationSchedule = {
    'service-account-keys': 90, // days
    'oauth-refresh-tokens': 180, // days
    'api-keys': 30, // days
    'session-tokens': 1 // day
  };
  
  async rotateCredentials(credentialType: string): Promise<void> {
    switch (credentialType) {
      case 'service-account-keys':
        await this.rotateServiceAccountKey();
        break;
      case 'oauth-refresh-tokens':
        await this.rotateOAuthTokens();
        break;
      case 'api-keys':
        await this.rotateApiKeys();
        break;
    }
  }
  
  private async rotateServiceAccountKey(): Promise<void> {
    // 1. Generate new service account key
    const newKey = await this.generateServiceAccountKey();
    
    // 2. Update secret manager
    await this.updateSecretManager('google-service-account-new', newKey);
    
    // 3. Deploy with new key
    await this.deployWithNewCredentials();
    
    // 4. Verify functionality
    await this.verifyCredentials();
    
    // 5. Deactivate old key
    await this.deactivateOldKey();
    
    // 6. Update active credential reference
    await this.updateSecretManager('google-service-account', newKey);
  }
  
  private async rotateOAuthTokens(): Promise<void> {
    const users = await this.getActiveUsers();
    
    for (const user of users) {
      try {
        // Refresh OAuth tokens
        const newTokens = await this.refreshUserTokens(user.id);
        await this.storeEncryptedTokens(user.id, newTokens);
      } catch (error) {
        // Mark for re-authorization
        await this.markForReauth(user.id);
      }
    }
  }
}
```

### 5.2 Environment Variable Management

**Secure Environment Configuration**:
```typescript
// Environment variable security layer
class SecureEnvironment {
  private static requiredVars = [
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'SUPABASE_SERVICE_ROLE_KEY',
    'GOOGLE_CLIENT_ID',
    'GOOGLE_CLIENT_SECRET',
    'ENCRYPTION_KEY'
  ];
  
  static validate(): void {
    const missing = this.requiredVars.filter(
      varName => !process.env[varName]
    );
    
    if (missing.length > 0) {
      throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
    }
  }
  
  static getSecure(key: string): string {
    const value = process.env[key];
    if (!value) {
      throw new Error(`Environment variable ${key} not found`);
    }
    
    // Decrypt if encrypted
    if (key.includes('SECRET') || key.includes('KEY')) {
      return this.decrypt(value);
    }
    
    return value;
  }
  
  private static decrypt(encryptedValue: string): string {
    // Implementation depends on your encryption strategy
    // Example using Node.js crypto
    const crypto = require('crypto');
    const algorithm = 'aes-256-gcm';
    const key = Buffer.from(process.env.ENCRYPTION_KEY!, 'hex');
    
    const [ivHex, authTagHex, encryptedHex] = encryptedValue.split(':');
    const iv = Buffer.from(ivHex, 'hex');
    const authTag = Buffer.from(authTagHex, 'hex');
    const encrypted = Buffer.from(encryptedHex, 'hex');
    
    const decipher = crypto.createDecipherGCM(algorithm, key);
    decipher.setIV(iv);
    decipher.setAuthTag(authTag);
    
    let decrypted = decipher.update(encrypted, null, 'utf8');
    decrypted += decipher.final('utf8');
    
    return decrypted;
  }
}
```

### 5.3 Secret Management Systems

**Integration with Cloud Secret Managers**:
```typescript
// Multi-cloud secret management
abstract class SecretManager {
  abstract getSecret(secretName: string): Promise<string>;
  abstract setSecret(secretName: string, value: string): Promise<void>;
  abstract rotateSecret(secretName: string): Promise<void>;
}

class GoogleSecretManager extends SecretManager {
  private client = new SecretManagerServiceClient();
  
  async getSecret(secretName: string): Promise<string> {
    const [version] = await this.client.accessSecretVersion({
      name: `projects/${process.env.GOOGLE_PROJECT_ID}/secrets/${secretName}/versions/latest`
    });
    
    return version.payload?.data?.toString() || '';
  }
  
  async setSecret(secretName: string, value: string): Promise<void> {
    await this.client.addSecretVersion({
      parent: `projects/${process.env.GOOGLE_PROJECT_ID}/secrets/${secretName}`,
      payload: { data: Buffer.from(value) }
    });
  }
}

class AWSSecretManager extends SecretManager {
  private client = new SecretsManagerClient({});
  
  async getSecret(secretName: string): Promise<string> {
    const command = new GetSecretValueCommand({ SecretId: secretName });
    const response = await this.client.send(command);
    return response.SecretString || '';
  }
}

// Factory pattern for multi-cloud support
class SecretManagerFactory {
  static create(provider: 'gcp' | 'aws' | 'azure'): SecretManager {
    switch (provider) {
      case 'gcp': return new GoogleSecretManager();
      case 'aws': return new AWSSecretManager();
      default: throw new Error(`Unsupported provider: ${provider}`);
    }
  }
}
```

### 5.4 Security Monitoring and Alerts

**Comprehensive Monitoring Implementation**:
```typescript
// Security monitoring service
class SecurityMonitor {
  private alertThresholds = {
    failedAuthAttempts: 5,
    unusualAPIUsage: 100,
    suspiciousFileAccess: 10,
    credentialRotationOverdue: 7 // days
  };
  
  async monitorAuthentication(): Promise<void> {
    // Monitor failed authentication attempts
    const failedAttempts = await this.getFailedAuthAttempts();
    if (failedAttempts > this.alertThresholds.failedAuthAttempts) {
      await this.sendAlert('HIGH', 'Multiple failed authentication attempts detected');
    }
    
    // Monitor token usage patterns
    const tokenUsage = await this.getTokenUsagePattern();
    if (this.isAnomalousUsage(tokenUsage)) {
      await this.sendAlert('MEDIUM', 'Anomalous token usage pattern detected');
    }
  }
  
  async monitorFileAccess(): Promise<void> {
    // Monitor file access patterns
    const accessLog = await this.getFileAccessLog();
    const suspiciousAccess = accessLog.filter(
      access => this.isSuspiciousAccess(access)
    );
    
    if (suspiciousAccess.length > this.alertThresholds.suspiciousFileAccess) {
      await this.sendAlert('HIGH', 'Suspicious file access pattern detected', {
        details: suspiciousAccess
      });
    }
  }
  
  async monitorCredentialHealth(): Promise<void> {
    const credentials = await this.getAllCredentials();
    
    for (const credential of credentials) {
      const daysSinceRotation = this.getDaysSinceRotation(credential);
      
      if (daysSinceRotation > this.alertThresholds.credentialRotationOverdue) {
        await this.sendAlert('MEDIUM', `Credential rotation overdue: ${credential.name}`);
      }
    }
  }
  
  private async sendAlert(severity: 'LOW' | 'MEDIUM' | 'HIGH', message: string, details?: any): Promise<void> {
    // Send to multiple channels based on severity
    const alert = {
      timestamp: new Date().toISOString(),
      severity,
      message,
      details,
      service: 'google-drive-supabase-mirror'
    };
    
    // Log to database
    await this.logAlert(alert);
    
    // Send notifications based on severity
    if (severity === 'HIGH') {
      await this.sendPagerDutyAlert(alert);
      await this.sendSlackAlert(alert);
    } else if (severity === 'MEDIUM') {
      await this.sendSlackAlert(alert);
    }
    
    // Always send to monitoring dashboard
    await this.sendToMonitoringDashboard(alert);
  }
}
```

## 6. Edge Function Security

### 6.1 Deno Environment Security

**Secure Edge Function Implementation**:
```typescript
// Secure Deno Edge Function with explicit permissions
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Input validation schemas
interface SyncRequest {
  fileId: string;
  userId: string;
  operation: 'upload' | 'download' | 'delete';
}

const validateSyncRequest = (data: any): data is SyncRequest => {
  return (
    typeof data.fileId === 'string' &&
    typeof data.userId === 'string' &&
    ['upload', 'download', 'delete'].includes(data.operation)
  );
};

serve(async (req: Request) => {
  // Security headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': process.env.ALLOWED_ORIGIN || 'https://yourdomain.com',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '1; mode=block',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
  };
  
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }
  
  try {
    // Rate limiting check
    const clientIP = req.headers.get('x-forwarded-for') || 'unknown';
    const rateLimitResult = await checkRateLimit(clientIP);
    
    if (!rateLimitResult.allowed) {
      return new Response(
        JSON.stringify({ error: 'Rate limit exceeded' }),
        { 
          status: 429, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }
    
    // JWT validation
    const authHeader = req.headers.get('authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      throw new Error('Missing or invalid authorization header');
    }
    
    const token = authHeader.replace('Bearer ', '');
    const user = await validateJWT(token);
    
    // Input validation
    const body = await req.json();
    if (!validateSyncRequest(body)) {
      throw new Error('Invalid request format');
    }
    
    // Authorization check
    const hasPermission = await checkUserPermission(user.id, body.fileId, body.operation);
    if (!hasPermission) {
      throw new Error('Insufficient permissions');
    }
    
    // Process request
    const result = await processSyncRequest(body, user);
    
    return new Response(
      JSON.stringify({ success: true, data: result }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
    
  } catch (error) {
    // Secure error handling - don't leak sensitive information
    console.error('Edge function error:', error);
    
    const errorMessage = error instanceof Error ? 
      (error.message.includes('permission') ? error.message : 'Internal server error') :
      'Internal server error';
    
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }
});

// Helper functions
async function checkRateLimit(clientIP: string) {
  // Implementation using Upstash Redis or similar
  const rateLimit = new RateLimit({
    redis: /* Redis client */,
    limiter: sliding(10, '10 s'), // 10 requests per 10 seconds
    analytics: true,
  });
  
  return await rateLimit.limit(clientIP);
}

async function validateJWT(token: string) {
  // Use Supabase's JWT validation
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!
  );
  
  const { data: { user }, error } = await supabase.auth.getUser(token);
  
  if (error || !user) {
    throw new Error('Invalid token');
  }
  
  return user;
}
```

### 6.2 HTTP Request Validation

**Comprehensive Input Validation**:
```typescript
// Input validation middleware
class RequestValidator {
  static validateHeaders(req: Request): void {
    const requiredHeaders = ['authorization', 'content-type'];
    
    for (const header of requiredHeaders) {
      if (!req.headers.get(header)) {
        throw new ValidationError(`Missing required header: ${header}`);
      }
    }
    
    // Validate content type
    const contentType = req.headers.get('content-type');
    if (contentType && !contentType.includes('application/json')) {
      throw new ValidationError('Invalid content type');
    }
  }
  
  static validateMethod(req: Request, allowedMethods: string[]): void {
    if (!allowedMethods.includes(req.method)) {
      throw new ValidationError(`Method ${req.method} not allowed`);
    }
  }
  
  static async validateBody(req: Request, schema: any): Promise<any> {
    if (!req.body) {
      throw new ValidationError('Request body required');
    }
    
    const body = await req.json();
    
    // Use a validation library like Zod
    const result = schema.safeParse(body);
    if (!result.success) {
      throw new ValidationError(`Invalid request body: ${result.error.message}`);
    }
    
    return result.data;
  }
  
  static validateFileUpload(file: File): void {
    const maxSize = 100 * 1024 * 1024; // 100MB
    const allowedTypes = [
      'image/jpeg', 'image/png', 'image/gif',
      'application/pdf', 'text/plain',
      'application/vnd.google-apps.document'
    ];
    
    if (file.size > maxSize) {
      throw new ValidationError('File size exceeds limit');
    }
    
    if (!allowedTypes.includes(file.type)) {
      throw new ValidationError('File type not allowed');
    }
  }
}

class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}
```

### 6.3 Rate Limiting and DDoS Protection

**Advanced Rate Limiting Implementation**:
```typescript
// Multi-tier rate limiting
class AdvancedRateLimit {
  private limits = {
    perIP: { requests: 100, window: 60 }, // 100 requests per minute per IP
    perUser: { requests: 1000, window: 3600 }, // 1000 requests per hour per user
    perAPI: { requests: 10000, window: 3600 }, // 10000 requests per hour total
    fileUpload: { requests: 10, window: 60 } // 10 file uploads per minute
  };
  
  async checkLimits(
    context: {
      ip: string;
      userId?: string;
      operation: string;
    }
  ): Promise<{ allowed: boolean; remainingRequests?: number }> {
    
    // Check IP-based rate limit
    const ipResult = await this.checkIPLimit(context.ip);
    if (!ipResult.allowed) {
      return ipResult;
    }
    
    // Check user-based rate limit
    if (context.userId) {
      const userResult = await this.checkUserLimit(context.userId);
      if (!userResult.allowed) {
        return userResult;
      }
    }
    
    // Check operation-specific limits
    if (context.operation === 'file-upload') {
      const uploadResult = await this.checkFileUploadLimit(context.ip);
      if (!uploadResult.allowed) {
        return uploadResult;
      }
    }
    
    // Check global API limits
    const globalResult = await this.checkGlobalLimit();
    return globalResult;
  }
  
  private async checkIPLimit(ip: string) {
    const key = `rate_limit:ip:${ip}`;
    const current = await this.redis.incr(key);
    
    if (current === 1) {
      await this.redis.expire(key, this.limits.perIP.window);
    }
    
    const allowed = current <= this.limits.perIP.requests;
    return {
      allowed,
      remainingRequests: Math.max(0, this.limits.perIP.requests - current)
    };
  }
  
  // Adaptive rate limiting based on system load
  async getAdaptiveLimit(baseLimit: number): Promise<number> {
    const systemLoad = await this.getSystemLoad();
    
    if (systemLoad > 0.8) {
      return Math.floor(baseLimit * 0.5); // Reduce by 50% under high load
    } else if (systemLoad > 0.6) {
      return Math.floor(baseLimit * 0.75); // Reduce by 25% under medium load
    }
    
    return baseLimit;
  }
}
```

## 7. Security Checklists and Architectural Recommendations

### 7.1 Pre-Production Security Checklist

**Authentication & Authorization**:
- [ ] Service account keys stored in secure secret manager
- [ ] OAuth 2.0 redirect URIs use HTTPS only
- [ ] Minimum required scopes implemented
- [ ] Token encryption at rest implemented
- [ ] JWT validation properly configured
- [ ] RLS policies enabled on all tables
- [ ] Custom claims validation implemented
- [ ] Cross-tenant isolation verified

**Network Security**:
- [ ] CORS policies properly configured
- [ ] Security headers implemented (CSP, HSTS, etc.)
- [ ] Rate limiting configured for all endpoints
- [ ] DDoS protection mechanisms in place
- [ ] Input validation on all user inputs
- [ ] File upload restrictions implemented
- [ ] API endpoints protected with authentication

**Credential Management**:
- [ ] Automated credential rotation implemented
- [ ] Environment variables encrypted
- [ ] Secret manager integration configured
- [ ] Credential expiration monitoring set up
- [ ] Emergency credential revocation procedures documented
- [ ] Audit logging for all credential access

**Monitoring & Alerting**:
- [ ] Security event logging implemented
- [ ] Failed authentication attempt monitoring
- [ ] Anomalous access pattern detection
- [ ] Real-time alerting configured
- [ ] Incident response procedures documented
- [ ] Regular security audit schedule established

### 7.2 Enterprise Architecture Recommendations

**Multi-Region Deployment**:
```typescript
// Multi-region architecture with failover
class MultiRegionAuth {
  private regions = [
    { name: 'us-east-1', primary: true, endpoint: 'https://api-us-east.example.com' },
    { name: 'eu-west-1', primary: false, endpoint: 'https://api-eu-west.example.com' },
    { name: 'ap-southeast-1', primary: false, endpoint: 'https://api-ap-southeast.example.com' }
  ];
  
  async getOptimalRegion(userLocation: string): Promise<string> {
    // Implement geo-location based routing
    const optimalRegion = this.calculateOptimalRegion(userLocation);
    
    // Check region health
    const isHealthy = await this.checkRegionHealth(optimalRegion);
    
    if (!isHealthy) {
      return this.getNextBestRegion(optimalRegion);
    }
    
    return optimalRegion;
  }
  
  async authenticateWithFailover(credentials: any, preferredRegion: string) {
    let currentRegion = preferredRegion;
    let attempts = 0;
    const maxAttempts = this.regions.length;
    
    while (attempts < maxAttempts) {
      try {
        return await this.authenticate(credentials, currentRegion);
      } catch (error) {
        attempts++;
        currentRegion = this.getNextBestRegion(currentRegion);
        
        if (attempts === maxAttempts) {
          throw new Error('Authentication failed in all regions');
        }
      }
    }
  }
}
```

**Zero-Trust Architecture**:
```typescript
// Zero-trust security implementation
class ZeroTrustGateway {
  async validateRequest(req: Request): Promise<ValidationResult> {
    const validations = await Promise.all([
      this.validateDevice(req),
      this.validateUser(req),
      this.validateNetwork(req),
      this.validateBehavior(req)
    ]);
    
    const riskScore = this.calculateRiskScore(validations);
    
    return {
      allowed: riskScore < 0.7,
      riskScore,
      requiredActions: this.getRequiredActions(riskScore),
      validations
    };
  }
  
  private async validateDevice(req: Request): Promise<DeviceValidation> {
    const deviceId = req.headers.get('x-device-id');
    const userAgent = req.headers.get('user-agent');
    
    return {
      isKnownDevice: await this.isKnownDevice(deviceId),
      isTrustedUserAgent: this.isTrustedUserAgent(userAgent),
      hasValidCertificate: await this.validateDeviceCertificate(req)
    };
  }
  
  private async validateBehavior(req: Request): Promise<BehaviorValidation> {
    const userId = await this.extractUserId(req);
    const currentBehavior = this.analyzeBehavior(req);
    const historicalBehavior = await this.getHistoricalBehavior(userId);
    
    return {
      isNormalAccessPattern: this.compareAccessPatterns(currentBehavior, historicalBehavior),
      isNormalLocation: this.validateLocation(req, historicalBehavior.locations),
      isNormalTimeFrame: this.validateTimeFrame(req, historicalBehavior.accessTimes)
    };
  }
}
```

### 7.3 Compliance and Audit Framework

**GDPR/CCPA Compliance**:
```typescript
// Privacy-compliant data handling
class PrivacyComplianceManager {
  async handleDataRequest(
    requestType: 'access' | 'delete' | 'portability',
    userId: string,
    verificationToken: string
  ): Promise<ComplianceResponse> {
    
    // Verify user identity
    const isVerified = await this.verifyUserIdentity(userId, verificationToken);
    if (!isVerified) {
      throw new Error('User identity verification failed');
    }
    
    switch (requestType) {
      case 'access':
        return await this.generateDataExport(userId);
      
      case 'delete':
        return await this.deleteUserData(userId);
      
      case 'portability':
        return await this.generatePortableData(userId);
      
      default:
        throw new Error('Invalid request type');
    }
  }
  
  private async deleteUserData(userId: string): Promise<ComplianceResponse> {
    const deletionPlan = await this.createDeletionPlan(userId);
    
    // Audit log before deletion
    await this.auditLog('USER_DATA_DELETION_INITIATED', {
      userId,
      timestamp: new Date().toISOString(),
      deletionPlan
    });
    
    // Execute deletion with verification
    const results = await Promise.allSettled([
      this.deleteSupabaseData(userId),
      this.deleteGoogleDriveReferences(userId),
      this.deleteAuditLogs(userId), // After retention period
      this.deleteBackups(userId) // After retention period
    ]);
    
    // Verify complete deletion
    const verificationResult = await this.verifyDeletion(userId);
    
    return {
      success: verificationResult.isComplete,
      details: results,
      verificationHash: verificationResult.hash
    };
  }
}
```

**SOC 2 Audit Trail**:
```typescript
// Comprehensive audit logging
class AuditLogger {
  async logSecurityEvent(event: SecurityEvent): Promise<void> {
    const auditEntry = {
      timestamp: new Date().toISOString(),
      eventType: event.type,
      userId: event.userId,
      ipAddress: event.ipAddress,
      userAgent: event.userAgent,
      resource: event.resource,
      action: event.action,
      outcome: event.outcome,
      riskScore: event.riskScore,
      metadata: event.metadata,
      hash: await this.calculateHash(event)
    };
    
    // Store in multiple locations for redundancy
    await Promise.all([
      this.storeInDatabase(auditEntry),
      this.storeInSecureStorage(auditEntry),
      this.sendToSIEM(auditEntry)
    ]);
    
    // Real-time monitoring for high-risk events
    if (event.riskScore > 0.8) {
      await this.triggerSecurityAlert(auditEntry);
    }
  }
  
  async generateComplianceReport(
    startDate: Date,
    endDate: Date,
    compliance: 'SOC2' | 'ISO27001' | 'PCI-DSS'
  ): Promise<ComplianceReport> {
    
    const auditTrail = await this.getAuditTrail(startDate, endDate);
    
    switch (compliance) {
      case 'SOC2':
        return this.generateSOC2Report(auditTrail);
      case 'ISO27001':
        return this.generateISO27001Report(auditTrail);
      case 'PCI-DSS':
        return this.generatePCIDSSReport(auditTrail);
    }
  }
}
```

## 8. Implementation Examples

### 8.1 Complete Authentication Flow

```typescript
// Complete end-to-end authentication implementation
export class GoogleDriveSupabaseMirror {
  private googleAuth: GoogleAuth;
  private supabaseClient: SupabaseClient;
  private securityMonitor: SecurityMonitor;
  
  constructor() {
    this.googleAuth = new GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/drive.file'],
      // Use Workload Identity Federation for production
    });
    
    this.supabaseClient = createClient(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_ANON_KEY!
    );
    
    this.securityMonitor = new SecurityMonitor();
  }
  
  async authenticateUser(authCode: string): Promise<AuthResult> {
    try {
      // Exchange authorization code for tokens
      const oauth2Client = new OAuth2Client({
        clientId: process.env.GOOGLE_CLIENT_ID,
        clientSecret: process.env.GOOGLE_CLIENT_SECRET,
        redirectUri: process.env.GOOGLE_REDIRECT_URI
      });
      
      const { tokens } = await oauth2Client.getToken(authCode);
      oauth2Client.setCredentials(tokens);
      
      // Get user info
      const oauth2 = google.oauth2({ version: 'v2', auth: oauth2Client });
      const { data: userInfo } = await oauth2.userinfo.get();
      
      // Create or update user in Supabase
      const { data: { user }, error } = await this.supabaseClient.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo: `${process.env.SITE_URL}/auth/callback`
        }
      });
      
      if (error) throw error;
      
      // Store encrypted Google tokens
      await this.storeEncryptedTokens(user!.id, tokens);
      
      // Log successful authentication
      await this.securityMonitor.logAuthenticationEvent({
        userId: user!.id,
        provider: 'google',
        outcome: 'success',
        metadata: { scopes: tokens.scope }
      });
      
      return {
        success: true,
        user: user!,
        permissions: await this.getUserPermissions(user!.id)
      };
      
    } catch (error) {
      await this.securityMonitor.logAuthenticationEvent({
        provider: 'google',
        outcome: 'failure',
        error: error.message
      });
      
      throw error;
    }
  }
  
  async syncFile(fileId: string, userId: string): Promise<SyncResult> {
    // Multi-step authentication and authorization
    const authResult = await this.authenticateForSync(userId);
    if (!authResult.success) {
      throw new Error('Authentication failed');
    }
    
    // Check permissions
    const hasPermission = await this.checkFilePermission(fileId, userId);
    if (!hasPermission) {
      throw new Error('Insufficient permissions');
    }
    
    // Rate limiting
    const rateLimitOk = await this.checkRateLimit(userId, 'file-sync');
    if (!rateLimitOk) {
      throw new Error('Rate limit exceeded');
    }
    
    try {
      // Download from Google Drive
      const fileData = await this.downloadFromDrive(fileId, authResult.driveAuth);
      
      // Upload to Supabase Storage
      const uploadResult = await this.uploadToSupabase(
        fileData,
        `${userId}/${fileId}`,
        authResult.supabaseAuth
      );
      
      // Update metadata
      await this.updateFileMetadata(fileId, userId, uploadResult);
      
      // Log successful sync
      await this.securityMonitor.logFileOperation({
        userId,
        fileId,
        operation: 'sync',
        outcome: 'success',
        size: fileData.size
      });
      
      return {
        success: true,
        supabaseUrl: uploadResult.publicUrl,
        metadata: uploadResult.metadata
      };
      
    } catch (error) {
      await this.securityMonitor.logFileOperation({
        userId,
        fileId,
        operation: 'sync',
        outcome: 'failure',
        error: error.message
      });
      
      throw error;
    }
  }
}
```

This comprehensive research document provides enterprise-grade authentication and authorization strategies for Google Drive to Supabase Storage mirroring, incorporating 2024 security best practices, detailed implementation examples, and production-ready security patterns.