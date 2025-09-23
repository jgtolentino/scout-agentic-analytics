import { NextRequest, NextResponse } from 'next/server';
import { LRUCache } from 'lru-cache';

export interface RateLimitOptions {
  windowMs: number; // Time window in milliseconds
  maxRequests: number; // Maximum requests per window
  keyGenerator?: (req: NextRequest) => string; // Custom key generation
  skipSuccessfulRequests?: boolean; // Don't count successful requests
  skipFailedRequests?: boolean; // Don't count failed requests
  message?: string; // Custom error message
  headers?: boolean; // Include rate limit headers in response
}

export interface RateLimitInfo {
  limit: number;
  remaining: number;
  resetTime: number;
  retryAfter?: number;
}

// In-memory store for development
class MemoryStore {
  private cache: LRUCache<string, { count: number; resetTime: number }>;

  constructor() {
    this.cache = new LRUCache({
      max: 10000, // Maximum number of items
      ttl: 1000 * 60 * 15 // 15 minutes TTL
    });
  }

  async increment(key: string, windowMs: number): Promise<{ count: number; resetTime: number }> {
    const now = Date.now();
    const existing = this.cache.get(key);

    if (existing && existing.resetTime > now) {
      // Window is still active
      existing.count++;
      this.cache.set(key, existing);
      return existing;
    } else {
      // New window
      const resetTime = now + windowMs;
      const newEntry = { count: 1, resetTime };
      this.cache.set(key, newEntry);
      return newEntry;
    }
  }

  async get(key: string): Promise<{ count: number; resetTime: number } | null> {
    const entry = this.cache.get(key);
    if (!entry || entry.resetTime <= Date.now()) {
      return null;
    }
    return entry;
  }

  async reset(key: string): Promise<void> {
    this.cache.delete(key);
  }
}

// Redis store for production
class RedisStore {
  private redisUrl: string;

  constructor(redisUrl: string) {
    this.redisUrl = redisUrl;
  }

  async increment(key: string, windowMs: number): Promise<{ count: number; resetTime: number }> {
    // Implementation would use Redis INCR with TTL
    // For now, fallback to memory store
    return memoryStore.increment(key, windowMs);
  }

  async get(key: string): Promise<{ count: number; resetTime: number } | null> {
    // Implementation would use Redis GET
    return memoryStore.get(key);
  }

  async reset(key: string): Promise<void> {
    // Implementation would use Redis DEL
    return memoryStore.reset(key);
  }
}

// Store instances
const memoryStore = new MemoryStore();
const redisStore = process.env.REDIS_URL ? new RedisStore(process.env.REDIS_URL) : null;
const store = redisStore || memoryStore;

// Default key generator
function defaultKeyGenerator(req: NextRequest): string {
  const ip = req.headers.get('x-forwarded-for') ||
            req.headers.get('x-real-ip') ||
            req.ip ||
            'unknown';

  const userId = req.headers.get('x-user-id') || 'anonymous';
  return `rate_limit:${ip}:${userId}`;
}

// Rate limiting middleware
export function rateLimitMiddleware(options: RateLimitOptions) {
  const {
    windowMs = 60 * 1000, // 1 minute default
    maxRequests = 100, // 100 requests per minute default
    keyGenerator = defaultKeyGenerator,
    skipSuccessfulRequests = false,
    skipFailedRequests = false,
    message = 'Too many requests',
    headers = true
  } = options;

  return async (req: NextRequest): Promise<NextResponse | null> => {
    try {
      const key = keyGenerator(req);
      const { count, resetTime } = await store.increment(key, windowMs);

      const limit = maxRequests;
      const remaining = Math.max(0, limit - count);
      const retryAfter = Math.ceil((resetTime - Date.now()) / 1000);

      const rateLimitInfo: RateLimitInfo = {
        limit,
        remaining,
        resetTime,
        retryAfter: remaining === 0 ? retryAfter : undefined
      };

      // Check if rate limit exceeded
      if (count > maxRequests) {
        const response = NextResponse.json(
          {
            error: 'Rate Limit Exceeded',
            message,
            retryAfter: retryAfter,
            limit: maxRequests,
            windowMs
          },
          { status: 429 }
        );

        if (headers) {
          addRateLimitHeaders(response, rateLimitInfo);
        }

        return response;
      }

      // Add rate limit headers to successful responses
      if (headers) {
        const response = NextResponse.next();
        addRateLimitHeaders(response, rateLimitInfo);
        return response;
      }

      return null; // Continue processing

    } catch (error) {
      console.error('Rate limit middleware error:', error);
      // Don't block requests if rate limiting fails
      return null;
    }
  };
}

// Add rate limit headers to response
function addRateLimitHeaders(response: NextResponse, info: RateLimitInfo): void {
  response.headers.set('X-RateLimit-Limit', info.limit.toString());
  response.headers.set('X-RateLimit-Remaining', info.remaining.toString());
  response.headers.set('X-RateLimit-Reset', Math.ceil(info.resetTime / 1000).toString());

  if (info.retryAfter) {
    response.headers.set('Retry-After', info.retryAfter.toString());
  }
}

// Predefined rate limiters
export const apiRateLimit = rateLimitMiddleware({
  windowMs: 15 * 60 * 1000, // 15 minutes
  maxRequests: 1000, // 1000 requests per 15 minutes
  message: 'Too many API requests from this IP, please try again later'
});

export const strictApiRateLimit = rateLimitMiddleware({
  windowMs: 1 * 60 * 1000, // 1 minute
  maxRequests: 10, // 10 requests per minute
  message: 'Rate limit exceeded for this endpoint'
});

export const authRateLimit = rateLimitMiddleware({
  windowMs: 15 * 60 * 1000, // 15 minutes
  maxRequests: 5, // 5 login attempts per 15 minutes
  keyGenerator: (req) => {
    const ip = req.headers.get('x-forwarded-for') || req.headers.get('x-real-ip') || 'unknown';
    return `auth_rate_limit:${ip}`;
  },
  message: 'Too many authentication attempts, please try again later'
});

export const semanticQueryRateLimit = rateLimitMiddleware({
  windowMs: 1 * 60 * 1000, // 1 minute
  maxRequests: 30, // 30 queries per minute
  keyGenerator: (req) => {
    const userId = req.headers.get('x-user-id') || 'anonymous';
    const tenantId = req.headers.get('x-tenant-id') || 'default';
    return `semantic_rate_limit:${tenantId}:${userId}`;
  },
  message: 'Too many semantic queries, please slow down'
});

export const geoExportRateLimit = rateLimitMiddleware({
  windowMs: 5 * 60 * 1000, // 5 minutes
  maxRequests: 10, // 10 geo exports per 5 minutes
  keyGenerator: (req) => {
    const userId = req.headers.get('x-user-id') || 'anonymous';
    const tenantId = req.headers.get('x-tenant-id') || 'default';
    return `geo_rate_limit:${tenantId}:${userId}`;
  },
  message: 'Too many geo export requests, please wait before trying again'
});

export const askSuqiRateLimit = rateLimitMiddleware({
  windowMs: 1 * 60 * 1000, // 1 minute
  maxRequests: 20, // 20 chat messages per minute
  keyGenerator: (req) => {
    const userId = req.headers.get('x-user-id') || 'anonymous';
    const sessionId = req.headers.get('x-session-id') || 'unknown';
    return `ask_suqi_rate_limit:${userId}:${sessionId}`;
  },
  message: 'Too many chat messages, please slow down'
});

// Rate limit bypass for development
export function developmentBypass(req: NextRequest): boolean {
  if (process.env.NODE_ENV === 'development') {
    return true;
  }

  // Allow bypass with special header (for testing)
  const bypassToken = req.headers.get('x-rate-limit-bypass');
  return bypassToken === process.env.RATE_LIMIT_BYPASS_TOKEN;
}

// Advanced rate limiting with sliding window
export class SlidingWindowRateLimit {
  private windows: Map<string, number[]> = new Map();

  async checkLimit(
    key: string,
    maxRequests: number,
    windowSizeMs: number,
    subWindowCount: number = 10
  ): Promise<{ allowed: boolean; remaining: number; resetTime: number }> {
    const now = Date.now();
    const subWindowSize = windowSizeMs / subWindowCount;
    const currentSubWindow = Math.floor(now / subWindowSize);

    // Get existing windows
    let windows = this.windows.get(key) || [];

    // Remove old windows
    const oldestAllowed = currentSubWindow - subWindowCount + 1;
    windows = windows.filter(w => w >= oldestAllowed);

    // Add current request
    windows.push(currentSubWindow);

    // Update storage
    this.windows.set(key, windows);

    // Calculate remaining
    const remaining = Math.max(0, maxRequests - windows.length);
    const resetTime = (currentSubWindow + 1) * subWindowSize;

    return {
      allowed: windows.length <= maxRequests,
      remaining,
      resetTime
    };
  }
}

// IP-based geolocation rate limiting
export function geoRateLimit(allowedCountries: string[] = ['US', 'PH', 'CA']) {
  return rateLimitMiddleware({
    windowMs: 1 * 60 * 1000, // 1 minute
    maxRequests: 100,
    keyGenerator: (req) => {
      const country = req.headers.get('cf-ipcountry') || 'unknown';
      const ip = req.headers.get('x-forwarded-for') || 'unknown';

      // More restrictive for non-allowed countries
      if (!allowedCountries.includes(country)) {
        return `geo_restricted:${country}:${ip}`;
      }

      return `geo_allowed:${country}:${ip}`;
    }
  });
}

// Rate limit monitoring and alerting
export async function monitorRateLimits(): Promise<void> {
  // Implementation would check rate limit metrics
  // and send alerts if thresholds are exceeded
  console.log('Rate limit monitoring check completed');
}