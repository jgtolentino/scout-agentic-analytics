import { NextRequest, NextResponse } from 'next/server';
import { getScoutCache, generateQueryHash, ScoutCache } from './redis';

export interface CacheMiddlewareOptions {
  ttl: number; // Time to live in seconds
  keyGenerator?: (req: NextRequest) => string;
  condition?: (req: NextRequest) => boolean;
  invalidateOn?: string[]; // HTTP methods that should invalidate cache
  tags?: string[];
  skipCache?: (req: NextRequest) => boolean;
  onHit?: (key: string) => void;
  onMiss?: (key: string) => void;
}

export function createCacheMiddleware(options: CacheMiddlewareOptions) {
  const {
    ttl,
    keyGenerator = defaultKeyGenerator,
    condition = () => true,
    invalidateOn = ['POST', 'PUT', 'DELETE', 'PATCH'],
    tags = [],
    skipCache = () => false,
    onHit = () => {},
    onMiss = () => {}
  } = options;

  return async function cacheMiddleware(
    req: NextRequest,
    handler: (req: NextRequest) => Promise<NextResponse>
  ): Promise<NextResponse> {
    const cache = getScoutCache();

    // Skip caching if condition not met
    if (!condition(req) || skipCache(req)) {
      return handler(req);
    }

    const method = req.method;
    const cacheKey = keyGenerator(req);

    // Handle cache invalidation
    if (invalidateOn.includes(method)) {
      await invalidateCache(cache, cacheKey, tags);
      return handler(req);
    }

    // Only cache GET requests by default
    if (method !== 'GET') {
      return handler(req);
    }

    try {
      // Try to get from cache
      const cachedResponse = await cache.redis.get(cacheKey);

      if (cachedResponse) {
        onHit(cacheKey);

        // Return cached response
        return NextResponse.json(cachedResponse, {
          headers: {
            'X-Cache': 'HIT',
            'X-Cache-Key': cacheKey,
            'X-Cache-TTL': ttl.toString()
          }
        });
      }

      onMiss(cacheKey);

      // Execute handler
      const response = await handler(req);

      // Cache successful responses
      if (response.status === 200) {
        const responseData = await response.json();

        await cache.redis.set(cacheKey, responseData, {
          ttl,
          tags: [...tags, 'api-response']
        });

        // Return response with cache headers
        return NextResponse.json(responseData, {
          status: 200,
          headers: {
            'X-Cache': 'MISS',
            'X-Cache-Key': cacheKey,
            'X-Cache-TTL': ttl.toString()
          }
        });
      }

      return response;

    } catch (error) {
      console.error('Cache middleware error:', error);
      // Don't let cache errors break the API
      return handler(req);
    }
  };
}

function defaultKeyGenerator(req: NextRequest): string {
  const { pathname, searchParams } = req.nextUrl;
  const userId = req.headers.get('x-user-id') || 'anonymous';
  const tenantId = req.headers.get('x-tenant-id') || 'default';

  // Sort search params for consistent key generation
  const sortedParams = Array.from(searchParams.entries())
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => `${key}=${value}`)
    .join('&');

  const keyContent = `${pathname}?${sortedParams}:${tenantId}:${userId}`;
  return generateQueryHash(keyContent);
}

async function invalidateCache(cache: ScoutCache, key: string, tags: string[]): Promise<void> {
  // Delete specific key
  await cache.redis.delete(key);

  // Invalidate by tags
  for (const tag of tags) {
    await cache.redis.invalidateByTag(tag);
  }
}

// Predefined cache middleware configurations
export const semanticQueryCache = createCacheMiddleware({
  ttl: 300, // 5 minutes
  tags: ['semantic', 'query'],
  keyGenerator: (req) => {
    const body = req.body;
    const tenantId = req.headers.get('x-tenant-id') || 'default';
    return generateQueryHash(JSON.stringify({ body, tenantId }));
  },
  condition: (req) => req.method === 'POST' && req.url.includes('/api/semantic'),
  skipCache: (req) => req.headers.get('x-skip-cache') === 'true'
});

export const geoExportCache = createCacheMiddleware({
  ttl: 1800, // 30 minutes
  tags: ['geo', 'export'],
  keyGenerator: (req) => {
    const { searchParams } = req.nextUrl;
    const level = searchParams.get('level') || 'region';
    const tenantId = req.headers.get('x-tenant-id') || 'default';
    return generateQueryHash(`geo:${level}:${tenantId}`);
  },
  condition: (req) => req.url.includes('/api/geo'),
  invalidateOn: ['POST', 'PUT', 'DELETE'] // Don't invalidate on GET
});

export const parityCheckCache = createCacheMiddleware({
  ttl: 600, // 10 minutes
  tags: ['parity', 'check'],
  keyGenerator: (req) => {
    const { searchParams } = req.nextUrl;
    const days = searchParams.get('days') || '30';
    const tenantId = req.headers.get('x-tenant-id') || 'default';
    return generateQueryHash(`parity:${days}:${tenantId}`);
  },
  condition: (req) => req.url.includes('/api/parity')
});

export const catalogQACache = createCacheMiddleware({
  ttl: 3600, // 1 hour
  tags: ['catalog', 'qa'],
  keyGenerator: (req) => {
    const body = req.body;
    return generateQueryHash(JSON.stringify(body));
  },
  condition: (req) => req.method === 'POST' && req.url.includes('/api/catalog/qa')
});

// Cache warming functions
export async function warmSemanticCache(): Promise<void> {
  const cache = getScoutCache();

  // Common semantic queries to pre-warm
  const commonQueries = [
    { dimensions: ['date'], measures: ['revenue'] },
    { dimensions: ['category'], measures: ['revenue', 'transactions'] },
    { dimensions: ['region'], measures: ['revenue'] },
    { dimensions: ['brand'], measures: ['revenue', 'basket_avg'] }
  ];

  for (const query of commonQueries) {
    const key = generateQueryHash(JSON.stringify(query));
    console.log(`Warming cache for semantic query: ${key}`);

    // You would call your actual semantic API here
    // For now, just mark the warming attempt
  }
}

export async function warmGeoCache(): Promise<void> {
  const cache = getScoutCache();

  const geoLevels = ['region', 'province', 'city'];

  for (const level of geoLevels) {
    const key = generateQueryHash(`geo:${level}:default`);
    console.log(`Warming cache for geo level: ${level}`);

    // You would call your actual geo API here
  }
}

// Cache analytics and monitoring
export interface CacheAnalytics {
  hitRate: number;
  totalRequests: number;
  totalHits: number;
  totalMisses: number;
  averageResponseTime: number;
  topKeys: Array<{ key: string; hits: number }>;
  tagStats: Record<string, { hits: number; misses: number }>;
}

export class CacheMonitor {
  private requests: Map<string, { hits: number; misses: number; responseTimes: number[] }> = new Map();
  private tagStats: Map<string, { hits: number; misses: number }> = new Map();

  recordHit(key: string, responseTime: number, tags: string[] = []): void {
    const stats = this.requests.get(key) || { hits: 0, misses: 0, responseTimes: [] };
    stats.hits++;
    stats.responseTimes.push(responseTime);
    this.requests.set(key, stats);

    // Update tag stats
    tags.forEach(tag => {
      const tagStat = this.tagStats.get(tag) || { hits: 0, misses: 0 };
      tagStat.hits++;
      this.tagStats.set(tag, tagStat);
    });
  }

  recordMiss(key: string, tags: string[] = []): void {
    const stats = this.requests.get(key) || { hits: 0, misses: 0, responseTimes: [] };
    stats.misses++;
    this.requests.set(key, stats);

    // Update tag stats
    tags.forEach(tag => {
      const tagStat = this.tagStats.get(tag) || { hits: 0, misses: 0 };
      tagStat.misses++;
      this.tagStats.set(tag, tagStat);
    });
  }

  getAnalytics(): CacheAnalytics {
    let totalHits = 0;
    let totalMisses = 0;
    let totalResponseTime = 0;
    let responseTimeCount = 0;

    const topKeys: Array<{ key: string; hits: number }> = [];

    for (const [key, stats] of this.requests.entries()) {
      totalHits += stats.hits;
      totalMisses += stats.misses;

      stats.responseTimes.forEach(time => {
        totalResponseTime += time;
        responseTimeCount++;
      });

      if (stats.hits > 0) {
        topKeys.push({ key, hits: stats.hits });
      }
    }

    topKeys.sort((a, b) => b.hits - a.hits);

    const totalRequests = totalHits + totalMisses;
    const hitRate = totalRequests > 0 ? (totalHits / totalRequests) * 100 : 0;
    const averageResponseTime = responseTimeCount > 0 ? totalResponseTime / responseTimeCount : 0;

    return {
      hitRate,
      totalRequests,
      totalHits,
      totalMisses,
      averageResponseTime,
      topKeys: topKeys.slice(0, 10),
      tagStats: Object.fromEntries(this.tagStats)
    };
  }

  reset(): void {
    this.requests.clear();
    this.tagStats.clear();
  }
}

// Global cache monitor
export const cacheMonitor = new CacheMonitor();

// Cache health check
export async function healthCheckCache(): Promise<{
  status: 'healthy' | 'unhealthy';
  message: string;
  analytics?: CacheAnalytics;
}> {
  try {
    const cache = getScoutCache();
    const health = await cache.healthCheck();

    if (health.status === 'healthy') {
      return {
        status: 'healthy',
        message: 'Cache is operational',
        analytics: cacheMonitor.getAnalytics()
      };
    } else {
      return {
        status: 'unhealthy',
        message: health.message
      };
    }

  } catch (error) {
    return {
      status: 'unhealthy',
      message: `Cache health check failed: ${error instanceof Error ? error.message : 'Unknown error'}`
    };
  }
}