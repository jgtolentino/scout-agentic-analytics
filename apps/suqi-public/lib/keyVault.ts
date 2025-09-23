import { DefaultAzureCredential, ManagedIdentityCredential } from '@azure/identity';
import { SecretClient } from '@azure/keyvault-secrets';

export interface SecretConfig {
  name: string;
  value?: string;
  version?: string;
  contentType?: string;
  tags?: Record<string, string>;
}

export class AzureKeyVaultClient {
  private client: SecretClient;
  private credential: DefaultAzureCredential | ManagedIdentityCredential;
  private vaultUrl: string;
  private cache: Map<string, { value: string; expiry: number }> = new Map();
  private cacheTimeoutMs: number = 5 * 60 * 1000; // 5 minutes

  constructor(
    vaultUrl?: string,
    useManagedIdentity: boolean = true,
    clientId?: string
  ) {
    this.vaultUrl = vaultUrl || process.env.AZURE_KEY_VAULT_URL || '';

    if (!this.vaultUrl) {
      throw new Error('Azure Key Vault URL is required');
    }

    // Use managed identity in production, default credential in development
    if (useManagedIdentity && process.env.NODE_ENV === 'production') {
      this.credential = new ManagedIdentityCredential(clientId);
    } else {
      this.credential = new DefaultAzureCredential();
    }

    this.client = new SecretClient(this.vaultUrl, this.credential);
  }

  /**
   * Get a secret from Azure Key Vault with caching
   */
  async getSecret(secretName: string, version?: string): Promise<string | null> {
    try {
      // Check cache first
      const cacheKey = `${secretName}:${version || 'latest'}`;
      const cached = this.cache.get(cacheKey);

      if (cached && cached.expiry > Date.now()) {
        return cached.value;
      }

      // Fetch from Key Vault
      const secret = await this.client.getSecret(secretName, { version });

      if (!secret.value) {
        console.warn(`Secret '${secretName}' has no value`);
        return null;
      }

      // Cache the result
      this.cache.set(cacheKey, {
        value: secret.value,
        expiry: Date.now() + this.cacheTimeoutMs
      });

      return secret.value;

    } catch (error) {
      console.error(`Failed to get secret '${secretName}':`, error);
      return null;
    }
  }

  /**
   * Get multiple secrets in parallel
   */
  async getSecrets(secretNames: string[]): Promise<Record<string, string | null>> {
    const promises = secretNames.map(async (name) => {
      const value = await this.getSecret(name);
      return { name, value };
    });

    const results = await Promise.all(promises);
    return results.reduce((acc, { name, value }) => {
      acc[name] = value;
      return acc;
    }, {} as Record<string, string | null>);
  }

  /**
   * Set a secret in Azure Key Vault
   */
  async setSecret(config: SecretConfig): Promise<boolean> {
    try {
      if (!config.value) {
        throw new Error('Secret value is required');
      }

      await this.client.setSecret(config.name, config.value, {
        contentType: config.contentType,
        tags: config.tags
      });

      // Update cache
      const cacheKey = `${config.name}:latest`;
      this.cache.set(cacheKey, {
        value: config.value,
        expiry: Date.now() + this.cacheTimeoutMs
      });

      return true;

    } catch (error) {
      console.error(`Failed to set secret '${config.name}':`, error);
      return false;
    }
  }

  /**
   * Delete a secret from Azure Key Vault
   */
  async deleteSecret(secretName: string): Promise<boolean> {
    try {
      await this.client.beginDeleteSecret(secretName);

      // Remove from cache
      const cacheKeys = Array.from(this.cache.keys()).filter(key =>
        key.startsWith(`${secretName}:`)
      );
      cacheKeys.forEach(key => this.cache.delete(key));

      return true;

    } catch (error) {
      console.error(`Failed to delete secret '${secretName}':`, error);
      return false;
    }
  }

  /**
   * List all secrets (metadata only)
   */
  async listSecrets(): Promise<string[]> {
    try {
      const secrets: string[] = [];

      for await (const secret of this.client.listPropertiesOfSecrets()) {
        if (secret.name) {
          secrets.push(secret.name);
        }
      }

      return secrets;

    } catch (error) {
      console.error('Failed to list secrets:', error);
      return [];
    }
  }

  /**
   * Clear the local cache
   */
  clearCache(): void {
    this.cache.clear();
  }

  /**
   * Test connection to Key Vault
   */
  async testConnection(): Promise<boolean> {
    try {
      // Try to list secrets to test connection
      const iterator = this.client.listPropertiesOfSecrets();
      await iterator.next();
      return true;

    } catch (error) {
      console.error('Key Vault connection test failed:', error);
      return false;
    }
  }
}

// Scout-specific secret names
export const SCOUT_SECRETS = {
  // Database connections
  SQL_CONNECTION_STRING: 'scout-sql-connection-string',
  SQL_PASSWORD: 'scout-sql-password',

  // Authentication
  JWT_SECRET: 'scout-jwt-secret',
  AZURE_AD_CLIENT_SECRET: 'scout-azure-ad-client-secret',

  // External services
  OPENAI_API_KEY: 'scout-openai-api-key',
  ANTHROPIC_API_KEY: 'scout-anthropic-api-key',

  // Redis
  REDIS_CONNECTION_STRING: 'scout-redis-connection-string',
  REDIS_PASSWORD: 'scout-redis-password',

  // Storage
  AZURE_STORAGE_CONNECTION_STRING: 'scout-storage-connection-string',

  // Monitoring
  APPLICATION_INSIGHTS_CONNECTION_STRING: 'scout-appinsights-connection-string',

  // Third-party integrations
  SENDGRID_API_KEY: 'scout-sendgrid-api-key',
  SLACK_WEBHOOK_URL: 'scout-slack-webhook-url'
} as const;

// Global Key Vault client instance
let keyVaultClient: AzureKeyVaultClient | null = null;

export function getKeyVaultClient(): AzureKeyVaultClient {
  if (!keyVaultClient) {
    keyVaultClient = new AzureKeyVaultClient(
      process.env.AZURE_KEY_VAULT_URL,
      process.env.NODE_ENV === 'production',
      process.env.AZURE_CLIENT_ID
    );
  }
  return keyVaultClient;
}

// Convenience functions for Scout secrets
export async function getScoutSecret(secretKey: keyof typeof SCOUT_SECRETS): Promise<string | null> {
  const client = getKeyVaultClient();
  return client.getSecret(SCOUT_SECRETS[secretKey]);
}

export async function getScoutSecrets(secretKeys: (keyof typeof SCOUT_SECRETS)[]): Promise<Record<string, string | null>> {
  const client = getKeyVaultClient();
  const secretNames = secretKeys.map(key => SCOUT_SECRETS[key]);
  return client.getSecrets(secretNames);
}

// Environment variable fallback for development
export async function getSecretOrEnv(
  secretKey: keyof typeof SCOUT_SECRETS,
  envVarName: string
): Promise<string | null> {
  // In development, prefer environment variables
  if (process.env.NODE_ENV === 'development') {
    const envValue = process.env[envVarName];
    if (envValue) {
      return envValue;
    }
  }

  // Fallback to Key Vault
  return getScoutSecret(secretKey);
}

// Secret rotation helper
export async function rotateSecret(
  secretKey: keyof typeof SCOUT_SECRETS,
  newValue: string,
  tags?: Record<string, string>
): Promise<boolean> {
  const client = getKeyVaultClient();
  return client.setSecret({
    name: SCOUT_SECRETS[secretKey],
    value: newValue,
    tags: {
      ...tags,
      rotatedAt: new Date().toISOString(),
      rotatedBy: 'scout-application'
    }
  });
}

// Development secret manager for local development
export class DevelopmentSecretManager {
  private secrets: Map<string, string> = new Map();

  constructor() {
    // Load from environment variables
    Object.entries(SCOUT_SECRETS).forEach(([key, secretName]) => {
      const envName = this.secretNameToEnvVar(secretName);
      const value = process.env[envName];
      if (value) {
        this.secrets.set(secretName, value);
      }
    });
  }

  async getSecret(secretName: string): Promise<string | null> {
    return this.secrets.get(secretName) || null;
  }

  async setSecret(secretName: string, value: string): Promise<boolean> {
    this.secrets.set(secretName, value);
    return true;
  }

  private secretNameToEnvVar(secretName: string): string {
    return secretName
      .replace(/^scout-/, '')
      .replace(/-/g, '_')
      .toUpperCase();
  }
}

// Factory function for secret manager
export function createSecretManager(): AzureKeyVaultClient | DevelopmentSecretManager {
  if (process.env.NODE_ENV === 'development' && !process.env.AZURE_KEY_VAULT_URL) {
    return new DevelopmentSecretManager();
  }
  return getKeyVaultClient();
}

// Health check for Key Vault connectivity
export async function healthCheckKeyVault(): Promise<{
  status: 'healthy' | 'unhealthy';
  message: string;
  responseTime?: number;
}> {
  try {
    const start = Date.now();
    const client = getKeyVaultClient();
    const isConnected = await client.testConnection();
    const responseTime = Date.now() - start;

    if (isConnected) {
      return {
        status: 'healthy',
        message: 'Key Vault connection successful',
        responseTime
      };
    } else {
      return {
        status: 'unhealthy',
        message: 'Key Vault connection failed'
      };
    }

  } catch (error) {
    return {
      status: 'unhealthy',
      message: `Key Vault health check failed: ${error instanceof Error ? error.message : 'Unknown error'}`
    };
  }
}