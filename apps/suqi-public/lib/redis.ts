import { Redis } from 'ioredis';
import { getSecretOrEnv, SCOUT_SECRETS } from './keyVault';

export interface CacheOptions {
  ttl?: number; // Time to live in seconds
  keyPrefix?: string; // Key prefix for organization
  tags?: string[]; // Tags for cache invalidation
  compress?: boolean; // Enable compression for large values
}

export interface CacheStats {
  hits: number;
  misses: number;
  sets: number;
  deletes: number;
  errors: number;
}

export class ScoutRedisClient {
  private client: Redis | null = null;
  private isConnected: boolean = false;
  private stats: CacheStats = {
    hits: 0,
    misses: 0,
    sets: 0,
    deletes: 0,
    errors: 0
  };

  constructor() {
    this.initialize();
  }

  private async initialize(): Promise<void> {
    try {
      // Get Redis connection details from Key Vault or environment
      const connectionString = await getSecretOrEnv(
        'REDIS_CONNECTION_STRING',
        'REDIS_CONNECTION_STRING'
      );

      const password = await getSecretOrEnv(
        'REDIS_PASSWORD',
        'REDIS_PASSWORD'
      );

      if (!connectionString && process.env.NODE_ENV === 'production') {
        throw new Error('Redis connection string is required in production');
      }

      // Use connection string if available, otherwise default config
      if (connectionString) {
        this.client = new Redis(connectionString, {
          retryDelayOnFailover: 100,
          enableReadyCheck: true,
          maxRetriesPerRequest: 3,
          lazyConnect: true,
          keepAlive: 30000,
          connectTimeout: 10000,
          commandTimeout: 5000
        });
      } else {
        // Development fallback
        this.client = new Redis({
          host: process.env.REDIS_HOST || 'localhost',
          port: parseInt(process.env.REDIS_PORT || '6379'),
          password: password || undefined,
          retryDelayOnFailover: 100,
          enableReadyCheck: true,
          maxRetriesPerRequest: 3,
          lazyConnect: true,
          keepAlive: 30000,
          connectTimeout: 10000,
          commandTimeout: 5000
        });
      }

      // Event handlers
      this.client.on('connect', () => {
        console.log('Redis connected');
        this.isConnected = true;
      });

      this.client.on('error', (error) => {
        console.error('Redis error:', error);
        this.stats.errors++;
        this.isConnected = false;
      });

      this.client.on('close', () => {
        console.log('Redis connection closed');
        this.isConnected = false;
      });

      // Test connection
      await this.testConnection();

    } catch (error) {
      console.error('Failed to initialize Redis client:', error);
      this.isConnected = false;
    }
  }

  async testConnection(): Promise<boolean> {
    try {
      if (!this.client) return false;

      await this.client.ping();
      this.isConnected = true;
      return true;
    } catch (error) {
      console.error('Redis connection test failed:', error);
      this.isConnected = false;
      return false;
    }
  }

  private buildKey(key: string, prefix?: string): string {
    const keyPrefix = prefix || 'scout';
    return `${keyPrefix}:${key}`;
  }

  async get<T = any>(key: string, options: CacheOptions = {}): Promise<T | null> {
    try {
      if (!this.client || !this.isConnected) {
        this.stats.misses++;
        return null;
      }

      const fullKey = this.buildKey(key, options.keyPrefix);
      const value = await this.client.get(fullKey);

      if (value === null) {
        this.stats.misses++;
        return null;
      }

      this.stats.hits++;

      // Try to parse as JSON, fallback to string
      try {
        return JSON.parse(value) as T;
      } catch {
        return value as unknown as T;
      }

    } catch (error) {
      console.error(`Redis GET error for key ${key}:`, error);
      this.stats.errors++;
      return null;
    }
  }

  async set<T = any>(
    key: string,
    value: T,
    options: CacheOptions = {}
  ): Promise<boolean> {
    try {
      if (!this.client || !this.isConnected) {
        return false;
      }

      const fullKey = this.buildKey(key, options.keyPrefix);
      const serializedValue = typeof value === 'string' ? value : JSON.stringify(value);

      if (options.ttl) {
        await this.client.setex(fullKey, options.ttl, serializedValue);
      } else {
        await this.client.set(fullKey, serializedValue);
      }

      // Add tags for cache invalidation
      if (options.tags && options.tags.length > 0) {
        await this.addTags(fullKey, options.tags);
      }

      this.stats.sets++;
      return true;

    } catch (error) {
      console.error(`Redis SET error for key ${key}:`, error);
      this.stats.errors++;
      return false;
    }
  }

  async delete(key: string, prefix?: string): Promise<boolean> {
    try {
      if (!this.client || !this.isConnected) {
        return false;
      }

      const fullKey = this.buildKey(key, prefix);
      const result = await this.client.del(fullKey);

      this.stats.deletes++;
      return result > 0;

    } catch (error) {
      console.error(`Redis DELETE error for key ${key}:`, error);
      this.stats.errors++;
      return false;
    }
  }

  async invalidateByTag(tag: string): Promise<number> {
    try {
      if (!this.client || !this.isConnected) {
        return 0;
      }

      const tagKey = `tag:${tag}`;
      const keys = await this.client.smembers(tagKey);

      if (keys.length === 0) {
        return 0;
      }

      // Delete all keys with this tag
      const deleted = await this.client.del(...keys);

      // Delete the tag set itself
      await this.client.del(tagKey);

      return deleted;

    } catch (error) {
      console.error(`Redis invalidateByTag error for tag ${tag}:`, error);
      this.stats.errors++;
      return 0;
    }
  }

  private async addTags(key: string, tags: string[]): Promise<void> {
    const pipeline = this.client!.pipeline();

    tags.forEach(tag => {
      const tagKey = `tag:${tag}`;
      pipeline.sadd(tagKey, key);
      pipeline.expire(tagKey, 86400); // 24 hours
    });

    await pipeline.exec();
  }

  async getStats(): Promise<CacheStats> {
    return { ...this.stats };
  }

  async resetStats(): Promise<void> {
    this.stats = {
      hits: 0,
      misses: 0,
      sets: 0,
      deletes: 0,
      errors: 0
    };
  }

  async flush(): Promise<boolean> {
    try {
      if (!this.client || !this.isConnected) {
        return false;
      }

      await this.client.flushdb();
      return true;

    } catch (error) {
      console.error('Redis FLUSH error:', error);
      this.stats.errors++;
      return false;
    }
  }

  async disconnect(): Promise<void> {
    if (this.client) {
      await this.client.quit();
      this.isConnected = false;
    }
  }

  // Health check
  async healthCheck(): Promise<{
    status: 'healthy' | 'unhealthy';
    message: string;
    responseTime?: number;
    stats?: CacheStats;
  }> {
    try {
      const start = Date.now();
      const isConnected = await this.testConnection();
      const responseTime = Date.now() - start;

      if (isConnected) {
        return {
          status: 'healthy',
          message: 'Redis connection successful',
          responseTime,
          stats: this.stats
        };
      } else {
        return {
          status: 'unhealthy',
          message: 'Redis connection failed'
        };
      }

    } catch (error) {
      return {
        status: 'unhealthy',
        message: `Redis health check failed: ${error instanceof Error ? error.message : 'Unknown error'}`
      };
    }
  }
}

// Scout-specific cache patterns
export class ScoutCache {
  private redis: ScoutRedisClient;

  constructor() {
    this.redis = new ScoutRedisClient();
  }

  // Semantic query caching
  async getSemanticQuery(queryHash: string): Promise<any | null> {
    return this.redis.get(queryHash, {
      keyPrefix: 'semantic',
      ttl: 300 // 5 minutes
    });
  }

  async setSemanticQuery(queryHash: string, result: any): Promise<boolean> {
    return this.redis.set(queryHash, result, {
      keyPrefix: 'semantic',
      ttl: 300, // 5 minutes
      tags: ['semantic', 'query']
    });
  }

  // Geo export caching
  async getGeoExport(exportHash: string): Promise<any | null> {
    return this.redis.get(exportHash, {
      keyPrefix: 'geo',
      ttl: 1800 // 30 minutes
    });
  }

  async setGeoExport(exportHash: string, result: any): Promise<boolean> {
    return this.redis.set(exportHash, result, {
      keyPrefix: 'geo',
      ttl: 1800, // 30 minutes
      tags: ['geo', 'export']
    });
  }

  // Ask Suqi context caching
  async getAskSuqiContext(sessionId: string): Promise<any | null> {
    return this.redis.get(sessionId, {
      keyPrefix: 'suqi:context',
      ttl: 3600 // 1 hour
    });
  }

  async setAskSuqiContext(sessionId: string, context: any): Promise<boolean> {
    return this.redis.set(sessionId, context, {
      keyPrefix: 'suqi:context',
      ttl: 3600, // 1 hour
      tags: ['suqi', 'context']
    });
  }

  // Parity check results caching
  async getParityCheck(checkId: string): Promise<any | null> {
    return this.redis.get(checkId, {
      keyPrefix: 'parity',
      ttl: 600 // 10 minutes
    });
  }

  async setParityCheck(checkId: string, result: any): Promise<boolean> {
    return this.redis.set(checkId, result, {
      keyPrefix: 'parity',
      ttl: 600, // 10 minutes
      tags: ['parity', 'check']
    });
  }

  // User session caching
  async getUserSession(sessionId: string): Promise<any | null> {
    return this.redis.get(sessionId, {
      keyPrefix: 'session',
      ttl: 86400 // 24 hours
    });
  }

  async setUserSession(sessionId: string, session: any): Promise<boolean> {
    return this.redis.set(sessionId, session, {
      keyPrefix: 'session',
      ttl: 86400, // 24 hours
      tags: ['session', 'user']
    });
  }

  // Database result caching
  async getDatabaseQuery(queryHash: string): Promise<any | null> {
    return this.redis.get(queryHash, {
      keyPrefix: 'db',
      ttl: 900 // 15 minutes
    });
  }

  async setDatabaseQuery(queryHash: string, result: any): Promise<boolean> {
    return this.redis.set(queryHash, result, {
      keyPrefix: 'db',
      ttl: 900, // 15 minutes
      tags: ['database', 'query']
    });
  }

  // Cache invalidation helpers
  async invalidateSemanticQueries(): Promise<number> {
    return this.redis.invalidateByTag('semantic');
  }

  async invalidateGeoExports(): Promise<number> {
    return this.redis.invalidateByTag('geo');
  }

  async invalidateUserSessions(): Promise<number> {
    return this.redis.invalidateByTag('session');
  }

  async invalidateAllQueries(): Promise<number> {
    const semanticCount = await this.redis.invalidateByTag('semantic');
    const geoCount = await this.redis.invalidateByTag('geo');
    const dbCount = await this.redis.invalidateByTag('database');

    return semanticCount + geoCount + dbCount;
  }

  // Statistics
  async getStats(): Promise<CacheStats> {
    return this.redis.getStats();
  }

  // Health check
  async healthCheck(): Promise<any> {
    return this.redis.healthCheck();
  }
}

// Global cache instance
let scoutCache: ScoutCache | null = null;

export function getScoutCache(): ScoutCache {
  if (!scoutCache) {
    scoutCache = new ScoutCache();
  }
  return scoutCache;
}

// Cache key generation helpers
export function generateQueryHash(query: string, params: any = {}): string {
  const content = JSON.stringify({ query, params });
  return require('crypto')
    .createHash('sha256')
    .update(content)
    .digest('hex')
    .substring(0, 16);
}

export function generateCacheKey(prefix: string, ...parts: string[]): string {
  return `${prefix}:${parts.join(':')}`;
}

// Development fallback cache
export class MemoryCache {
  private cache: Map<string, { value: any; expiry: number }> = new Map();

  async get<T = any>(key: string): Promise<T | null> {
    const entry = this.cache.get(key);

    if (!entry || entry.expiry < Date.now()) {
      this.cache.delete(key);
      return null;
    }

    return entry.value;
  }

  async set<T = any>(key: string, value: T, ttlSeconds: number = 300): Promise<boolean> {
    this.cache.set(key, {
      value,
      expiry: Date.now() + (ttlSeconds * 1000)
    });
    return true;
  }

  async delete(key: string): Promise<boolean> {
    return this.cache.delete(key);
  }

  async flush(): Promise<boolean> {
    this.cache.clear();
    return true;
  }
}

// Factory function for cache
export function createCache(): ScoutCache | MemoryCache {
  if (process.env.NODE_ENV === 'development' && !process.env.REDIS_CONNECTION_STRING) {
    console.log('Using memory cache for development');
    return new MemoryCache() as any;
  }
  return getScoutCache();
}