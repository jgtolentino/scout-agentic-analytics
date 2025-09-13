# Claude Code Secure Workflow for React/Next.js

## Overview
This document outlines the secure development workflow for using Claude Code with React/Next.js applications in the TBWA Scout Dashboard v5.0 project.

## Security Principles

### 1. Environment Isolation
```yaml
development:
  - Use local environment variables
  - Never commit .env files
  - Use .env.example for templates
  
staging:
  - Separate staging credentials
  - Limited production data access
  - Automated security scanning
  
production:
  - Production secrets in Vercel
  - Environment-specific configs
  - Audit logging enabled
```

### 2. Code Review Workflow

#### Pre-commit Checks
```json
{
  "husky": {
    "hooks": {
      "pre-commit": "npm run lint && npm run type-check && npm run security:check",
      "pre-push": "npm test && npm run build"
    }
  }
}
```

#### Claude Code Integration
```bash
# .claude-code/config.json
{
  "security": {
    "scanOnSave": true,
    "blockInsecurePatterns": true,
    "requireApproval": [
      "env-changes",
      "auth-changes",
      "api-endpoints"
    ]
  },
  "react": {
    "enforceHooks": true,
    "requirePropTypes": false,
    "preferFunctionalComponents": true
  },
  "nextjs": {
    "enforceAppRouter": true,
    "requireServerComponents": true,
    "validateMetadata": true
  }
}
```

### 3. Secure Component Development

#### Component Template
```typescript
// components/SecureComponent.tsx
'use client';

import { useState, useEffect } from 'react';
import { useAuth } from '@/hooks/useAuth';
import { validateInput } from '@/lib/validation';
import { sanitizeHtml } from '@/lib/sanitize';

interface SecureComponentProps {
  data: unknown;
  onAction: (value: string) => void;
}

export function SecureComponent({ data, onAction }: SecureComponentProps) {
  const { user, isAuthenticated } = useAuth();
  const [input, setInput] = useState('');
  const [error, setError] = useState<string | null>(null);

  // Validate props
  useEffect(() => {
    if (!validateInput(data)) {
      throw new Error('Invalid data provided to SecureComponent');
    }
  }, [data]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      // Input validation
      const validatedInput = validateInput(input);
      
      // CSRF protection
      const csrfToken = await fetch('/api/csrf').then(r => r.json());
      
      // Sanitize input
      const sanitized = sanitizeHtml(validatedInput);
      
      // Call action with validated input
      await onAction(sanitized);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    }
  };

  if (!isAuthenticated) {
    return <div>Please login to continue</div>;
  }

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="text"
        value={input}
        onChange={(e) => setInput(e.target.value)}
        maxLength={100}
        pattern="[a-zA-Z0-9\s]+"
        required
      />
      {error && <div role="alert">{error}</div>}
      <button type="submit">Submit</button>
    </form>
  );
}
```

### 4. API Route Security

#### Secure API Route Template
```typescript
// app/api/secure-endpoint/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { verifyAuth } from '@/lib/auth';
import { rateLimiter } from '@/lib/rate-limit';
import { validateRequest } from '@/lib/validation';
import { auditLog } from '@/lib/audit';
import { z } from 'zod';

const requestSchema = z.object({
  action: z.enum(['create', 'update', 'delete']),
  data: z.object({
    id: z.string().uuid(),
    value: z.string().max(1000)
  })
});

export async function POST(request: NextRequest) {
  try {
    // Rate limiting
    const rateLimitResult = await rateLimiter.check(request);
    if (!rateLimitResult.success) {
      return NextResponse.json(
        { error: 'Too many requests' },
        { status: 429 }
      );
    }

    // Authentication
    const auth = await verifyAuth(request);
    if (!auth.authenticated) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    // CSRF validation
    const csrfToken = request.headers.get('x-csrf-token');
    if (!validateCSRF(csrfToken, auth.session)) {
      return NextResponse.json(
        { error: 'Invalid CSRF token' },
        { status: 403 }
      );
    }

    // Request validation
    const body = await request.json();
    const validated = requestSchema.parse(body);

    // Authorization
    if (!auth.user.permissions.includes(validated.action)) {
      await auditLog.unauthorized(auth.user, validated.action);
      return NextResponse.json(
        { error: 'Forbidden' },
        { status: 403 }
      );
    }

    // Process request
    const result = await processSecureAction(validated, auth.user);

    // Audit logging
    await auditLog.action(auth.user, validated.action, result);

    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { error: 'Invalid request', details: error.errors },
        { status: 400 }
      );
    }

    // Log error securely (no sensitive data)
    console.error('API Error:', error.message);
    
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
```

### 5. Data Fetching Security

#### Secure Data Fetching
```typescript
// lib/secure-fetch.ts
import { cache } from 'react';

interface FetchOptions extends RequestInit {
  requireAuth?: boolean;
  validateResponse?: boolean;
}

export const secureFetch = cache(async (
  url: string,
  options: FetchOptions = {}
) => {
  const { requireAuth = true, validateResponse = true, ...fetchOptions } = options;

  // Build headers
  const headers = new Headers(fetchOptions.headers);
  
  // Add auth token if required
  if (requireAuth) {
    const token = await getAuthToken();
    headers.set('Authorization', `Bearer ${token}`);
  }

  // Add security headers
  headers.set('X-Requested-With', 'XMLHttpRequest');
  headers.set('X-Content-Type-Options', 'nosniff');

  try {
    const response = await fetch(url, {
      ...fetchOptions,
      headers,
      credentials: 'same-origin'
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    // Validate content type
    const contentType = response.headers.get('content-type');
    if (validateResponse && !contentType?.includes('application/json')) {
      throw new Error('Invalid response type');
    }

    const data = await response.json();

    // Basic response validation
    if (validateResponse && !data || typeof data !== 'object') {
      throw new Error('Invalid response format');
    }

    return data;
  } catch (error) {
    // Log error without exposing sensitive data
    console.error('Fetch error:', error.message);
    throw error;
  }
});
```

### 6. State Management Security

#### Secure Store Setup
```typescript
// store/secure-store.ts
import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { encrypt, decrypt } from '@/lib/crypto';

interface SecureStore {
  // Public data
  theme: 'light' | 'dark';
  
  // Sensitive data (encrypted)
  _userData: string | null;
  
  // Actions
  setUserData: (data: UserData) => void;
  getUserData: () => UserData | null;
  clearSensitiveData: () => void;
}

export const useSecureStore = create<SecureStore>()(
  persist(
    (set, get) => ({
      theme: 'light',
      _userData: null,

      setUserData: (data: UserData) => {
        // Encrypt sensitive data before storing
        const encrypted = encrypt(JSON.stringify(data));
        set({ _userData: encrypted });
      },

      getUserData: () => {
        const encrypted = get()._userData;
        if (!encrypted) return null;
        
        try {
          const decrypted = decrypt(encrypted);
          return JSON.parse(decrypted);
        } catch {
          // Clear corrupted data
          set({ _userData: null });
          return null;
        }
      },

      clearSensitiveData: () => {
        set({ _userData: null });
      }
    }),
    {
      name: 'secure-store',
      // Only persist non-sensitive data
      partialize: (state) => ({ theme: state.theme })
    }
  )
);
```

### 7. Claude Code Security Directives

#### .claude-directives
```yaml
# Security directives for Claude Code

security:
  # Never generate or expose
  never_generate:
    - api_keys
    - passwords
    - secrets
    - private_keys
    - tokens
    
  # Always include
  always_include:
    - input_validation
    - error_boundaries
    - auth_checks
    - rate_limiting
    
  # Require review
  require_review:
    - database_queries
    - external_api_calls
    - file_operations
    - env_variable_usage

react_patterns:
  prefer:
    - functional_components
    - hooks
    - server_components
    - error_boundaries
    
  avoid:
    - class_components
    - direct_dom_manipulation
    - inline_styles
    - dangerouslySetInnerHTML

nextjs_patterns:
  enforce:
    - app_router
    - server_actions
    - metadata_api
    - image_optimization
    
  security:
    - csp_headers
    - secure_cookies
    - https_only
    - cors_configuration
```

### 8. Testing Security

#### Security Test Suite
```typescript
// tests/security/xss.test.tsx
import { render, screen } from '@testing-library/react';
import { SecureComponent } from '@/components/SecureComponent';

describe('XSS Prevention', () => {
  it('should sanitize user input', () => {
    const maliciousInput = '<script>alert("XSS")</script>';
    render(<SecureComponent data={maliciousInput} />);
    
    // Should not render script tag
    expect(screen.queryByText(/script/)).not.toBeInTheDocument();
  });

  it('should escape HTML entities', () => {
    const htmlInput = '<div>Test & "quotes"</div>';
    render(<SecureComponent data={htmlInput} />);
    
    // Should escape HTML
    expect(screen.getByText(/&lt;div&gt;/)).toBeInTheDocument();
  });
});

// tests/security/auth.test.ts
describe('Authentication', () => {
  it('should require authentication for protected routes', async () => {
    const response = await fetch('/api/protected', {
      method: 'GET'
    });
    
    expect(response.status).toBe(401);
  });

  it('should validate JWT tokens', async () => {
    const invalidToken = 'invalid.jwt.token';
    const response = await fetch('/api/protected', {
      headers: {
        'Authorization': `Bearer ${invalidToken}`
      }
    });
    
    expect(response.status).toBe(403);
  });
});
```

### 9. Deployment Security

#### Vercel Deployment Config
```json
{
  "functions": {
    "app/api/*": {
      "maxDuration": 10
    }
  },
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "X-Content-Type-Options",
          "value": "nosniff"
        },
        {
          "key": "X-Frame-Options",
          "value": "DENY"
        },
        {
          "key": "X-XSS-Protection",
          "value": "1; mode=block"
        }
      ]
    }
  ],
  "env": {
    "NEXT_PUBLIC_API_URL": "@api_url",
    "DATABASE_URL": "@database_url",
    "JWT_SECRET": "@jwt_secret"
  }
}
```

### 10. Monitoring & Alerts

#### Security Monitoring
```typescript
// lib/security-monitor.ts
import { Sentry } from '@sentry/nextjs';

export const securityMonitor = {
  suspiciousActivity: (userId: string, activity: string) => {
    Sentry.captureMessage(`Suspicious activity: ${activity}`, {
      level: 'warning',
      user: { id: userId },
      tags: { security: 'suspicious' }
    });
  },

  authFailure: (email: string, reason: string) => {
    Sentry.captureMessage(`Auth failure: ${reason}`, {
      level: 'error',
      extra: { email },
      tags: { security: 'auth' }
    });
  },

  rateLimitExceeded: (ip: string, endpoint: string) => {
    Sentry.captureMessage('Rate limit exceeded', {
      level: 'warning',
      extra: { ip, endpoint },
      tags: { security: 'rate-limit' }
    });
  }
};
```

## Best Practices Summary

1. **Always validate input** - Use Zod schemas for all user input
2. **Implement proper authentication** - JWT with refresh tokens
3. **Use HTTPS everywhere** - No exceptions
4. **Enable CSP headers** - Prevent XSS attacks
5. **Rate limit all endpoints** - Prevent abuse
6. **Audit log sensitive actions** - Track who did what
7. **Encrypt sensitive data** - At rest and in transit
8. **Regular security scans** - Automated and manual
9. **Keep dependencies updated** - Use Dependabot
10. **Follow least privilege** - Minimal permissions

## Resources

- [Next.js Security Checklist](https://nextjs.org/docs/security)
- [OWASP React Security](https://owasp.org/www-project-react-security/)
- [Claude Code Security Guide](https://claude.ai/security)
- [Vercel Security Best Practices](https://vercel.com/docs/security)