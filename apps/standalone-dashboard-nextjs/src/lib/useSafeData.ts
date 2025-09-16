"use client";

import { useState, useEffect, useMemo } from 'react';
import { ENV } from './env';
import { createApiCache, usePerformanceMonitor, PERFORMANCE_CONFIG } from './performance';

export function useSafeData<T>(
  fetcher: () => Promise<T>,
  fallback: T,
  deps: any[] = [],
  cacheKey?: string
) {
  const [data, setData] = useState<T>(fallback);
  const [loading, setLoading] = useState(!ENV.USE_MOCK);
  const [error, setError] = useState<string | null>(null);
  
  const monitor = usePerformanceMonitor('useSafeData');
  const cache = useMemo(() => createApiCache(), []);
  const effectiveCacheKey = cacheKey || JSON.stringify(deps);

  useEffect(() => {
    // If using mock data, just return the fallback
    if (ENV.USE_MOCK) {
      setData(fallback);
      setLoading(false);
      setError(null);
      return;
    }

    // Check cache first if caching is enabled
    if (PERFORMANCE_CONFIG.enableCaching) {
      const cachedData = cache.get(effectiveCacheKey);
      if (cachedData) {
        setData(cachedData);
        setLoading(false);
        setError(null);
        return;
      }
    }

    let cancelled = false;
    
    const fetchData = async () => {
      const endTimer = monitor('fetch');
      
      try {
        setLoading(true);
        setError(null);
        const result = await fetcher();
        
        if (!cancelled) {
          setData(result);
          
          // Cache the result if caching is enabled
          if (PERFORMANCE_CONFIG.enableCaching) {
            cache.set(effectiveCacheKey, result);
          }
        }
      } catch (err) {
        if (!cancelled) {
          console.warn('Data fetch failed, using fallback:', err);
          setError(err instanceof Error ? err.message : 'Unknown error');
          setData(fallback); // Use fallback on error
        }
      } finally {
        endTimer();
        if (!cancelled) {
          setLoading(false);
        }
      }
    };

    fetchData();

    return () => {
      cancelled = true;
    };
  }, deps);

  return { data, loading, error };
}