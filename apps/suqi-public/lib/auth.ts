import jwt from 'jsonwebtoken';
import { PublicClientApplication, AccountInfo } from '@azure/msal-node';
import { azureADConfig } from '@/middleware/auth';

export interface User {
  id: string;
  email: string;
  name: string;
  tenantId: string;
  roles: string[];
  permissions: string[];
}

// JWT token verification
export async function verifyJWT(token: string): Promise<User | null> {
  try {
    const secret = process.env.JWT_SECRET!;
    const decoded = jwt.verify(token, secret) as any;

    // Validate token structure
    if (!decoded.sub || !decoded.email || !decoded.tenant_id) {
      throw new Error('Invalid token structure');
    }

    // Check token expiration
    if (decoded.exp && Date.now() >= decoded.exp * 1000) {
      throw new Error('Token expired');
    }

    // Map roles to permissions
    const permissions = mapRolesToPermissions(decoded.roles || []);

    return {
      id: decoded.sub,
      email: decoded.email,
      name: decoded.name || decoded.email,
      tenantId: decoded.tenant_id,
      roles: decoded.roles || [],
      permissions
    };

  } catch (error) {
    console.error('JWT verification failed:', error);
    return null;
  }
}

// Generate JWT token
export function generateJWT(user: Partial<User>, expiresIn: string = '24h'): string {
  const secret = process.env.JWT_SECRET!;

  const payload = {
    sub: user.id,
    email: user.email,
    name: user.name,
    tenant_id: user.tenantId,
    roles: user.roles || [],
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + (24 * 60 * 60) // 24 hours
  };

  return jwt.sign(payload, secret);
}

// Azure AD B2C integration
export class AzureAuthProvider {
  private msalInstance: PublicClientApplication;

  constructor() {
    this.msalInstance = new PublicClientApplication({
      auth: {
        clientId: azureADConfig.clientId,
        authority: azureADConfig.authority,
        redirectUri: azureADConfig.redirectUri
      },
      cache: {
        cacheLocation: 'sessionStorage'
      }
    });
  }

  async login(email: string, password: string): Promise<User | null> {
    try {
      // For production, integrate with Azure AD B2C
      // This is a simplified implementation
      const account = await this.authenticateWithAzure(email, password);

      if (!account) {
        return null;
      }

      // Map Azure AD account to our User interface
      return {
        id: account.homeAccountId,
        email: account.username,
        name: account.name || account.username,
        tenantId: this.extractTenantId(account),
        roles: this.extractRoles(account),
        permissions: []
      };

    } catch (error) {
      console.error('Azure AD authentication failed:', error);
      return null;
    }
  }

  private async authenticateWithAzure(email: string, password: string): Promise<AccountInfo | null> {
    // Implementation would use MSAL for actual Azure AD authentication
    // For now, return mock data for development
    if (process.env.NODE_ENV === 'development') {
      return {
        homeAccountId: 'dev-user-123',
        username: email,
        name: 'Development User',
        localAccountId: 'dev-local-123',
        environment: 'dev',
        tenantId: 'tbwa'
      } as AccountInfo;
    }

    // Production Azure AD integration would go here
    throw new Error('Azure AD integration not configured for production');
  }

  private extractTenantId(account: AccountInfo): string {
    // Extract tenant from Azure AD claims or use default
    return account.tenantId || 'tbwa';
  }

  private extractRoles(account: AccountInfo): string[] {
    // Extract roles from Azure AD group membership
    // This would come from Azure AD claims in production
    return ['analyst']; // Default role
  }
}

// Role to permission mapping
function mapRolesToPermissions(roles: string[]): string[] {
  const permissionMap = {
    admin: ['read', 'write', 'delete', 'manage_users', 'manage_tenants'],
    analyst: ['read', 'write', 'export_data'],
    viewer: ['read'],
    api_user: ['read', 'write']
  };

  const permissions = new Set<string>();

  roles.forEach(role => {
    const rolePermissions = permissionMap[role as keyof typeof permissionMap];
    if (rolePermissions) {
      rolePermissions.forEach(permission => permissions.add(permission));
    }
  });

  return Array.from(permissions);
}

// Development authentication for testing
export function createDevUser(email: string = 'dev@tbwa.com'): User {
  return {
    id: 'dev-user-123',
    email,
    name: 'Development User',
    tenantId: 'tbwa',
    roles: ['analyst'],
    permissions: ['read', 'write', 'export_data']
  };
}

// Validate user permissions
export function hasPermission(user: User, requiredPermission: string): boolean {
  return user.permissions.includes(requiredPermission);
}

export function hasRole(user: User, requiredRole: string): boolean {
  return user.roles.includes(requiredRole);
}

// Session management
export interface Session {
  id: string;
  userId: string;
  tenantId: string;
  createdAt: Date;
  expiresAt: Date;
  isActive: boolean;
}

export class SessionManager {
  private sessions = new Map<string, Session>();

  createSession(user: User): Session {
    const sessionId = this.generateSessionId();
    const session: Session = {
      id: sessionId,
      userId: user.id,
      tenantId: user.tenantId,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
      isActive: true
    };

    this.sessions.set(sessionId, session);
    return session;
  }

  getSession(sessionId: string): Session | null {
    const session = this.sessions.get(sessionId);

    if (!session) {
      return null;
    }

    // Check if session is expired
    if (!session.isActive || session.expiresAt < new Date()) {
      this.sessions.delete(sessionId);
      return null;
    }

    return session;
  }

  destroySession(sessionId: string): void {
    this.sessions.delete(sessionId);
  }

  private generateSessionId(): string {
    return `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}

// Global session manager instance
export const sessionManager = new SessionManager();