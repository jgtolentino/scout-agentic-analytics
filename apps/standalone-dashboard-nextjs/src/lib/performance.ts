/**
 * Performance optimization utilities
 * Implements caching, debouncing, and lazy loading strategies
 */

import { useCallback, useRef, useMemo } from 'react';

// Memory cache for API responses
class MemoryCache {
  private cache = new Map<string, { data: any; timestamp: number; ttl: number }>();
  
  set(key: string, data: any, ttl: number = 5 * 60 * 1000) { // 5 minutes default
    this.cache.set(key, {
      data,
      timestamp: Date.now(),
      ttl
    });
  }
  
  get(key: string): any | null {
    const entry = this.cache.get(key);
    if (!entry) return null;
    
    if (Date.now() - entry.timestamp > entry.ttl) {
      this.cache.delete(key);
      return null;
    }
    
    return entry.data;
  }
  
  clear() {
    this.cache.clear();
  }
  
  size() {
    return this.cache.size;
  }
}

export const memoryCache = new MemoryCache();

// Debounce hook for expensive operations
export function useDebounce<T extends (...args: any[]) => any>(
  callback: T,
  delay: number
): (...args: Parameters<T>) => void {
  const timeoutRef = useRef<NodeJS.Timeout>();
  
  return useCallback((...args: Parameters<T>) => {
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
    }
    
    timeoutRef.current = setTimeout(() => {
      callback(...args);
    }, delay);
  }, [callback, delay]);
}

// Throttle hook for rate limiting
export function useThrottle<T extends (...args: any[]) => any>(
  callback: T,
  limit: number
): (...args: Parameters<T>) => void {
  const inThrottle = useRef(false);
  
  return useCallback((...args: Parameters<T>) => {
    if (!inThrottle.current) {
      callback(...args);
      inThrottle.current = true;
      setTimeout(() => {
        inThrottle.current = false;
      }, limit);
    }
  }, [callback, limit]);
}

// Memoized chart data processor
export function useChartDataMemo(data: any[], processor?: (data: any[]) => any) {
  return useMemo(() => {
    if (!processor) return data;
    return processor(data);
  }, [data, processor]);
}

// Lazy loading utilities
export function createLazyComponent<P = {}>(
  importFunc: () => Promise<{ default: React.ComponentType<P> }>,
  fallback?: React.ComponentType
) {
  const LazyComponent = React.lazy(importFunc);
  
  return function LazyWrapper(props: P) {
    return React.createElement(
      React.Suspense,
      { 
        fallback: fallback 
          ? React.createElement(fallback) 
          : React.createElement('div', {}, 'Loading...') 
      },
      React.createElement(LazyComponent, props)
    );
  };
}

// Performance monitoring
export class PerformanceMonitor {
  private static instance: PerformanceMonitor;
  private metrics: Map<string, number[]> = new Map();
  
  static getInstance(): PerformanceMonitor {
    if (!PerformanceMonitor.instance) {
      PerformanceMonitor.instance = new PerformanceMonitor();
    }
    return PerformanceMonitor.instance;
  }
  
  startTimer(name: string): () => void {
    const startTime = performance.now();
    
    return () => {
      const endTime = performance.now();
      const duration = endTime - startTime;
      
      if (!this.metrics.has(name)) {
        this.metrics.set(name, []);
      }
      
      const times = this.metrics.get(name)!;
      times.push(duration);
      
      // Keep only last 100 measurements
      if (times.length > 100) {
        times.shift();
      }
      
      console.log(`⚡ ${name}: ${duration.toFixed(2)}ms`);
    };
  }
  
  getAverage(name: string): number {
    const times = this.metrics.get(name);
    if (!times || times.length === 0) return 0;
    
    return times.reduce((sum, time) => sum + time, 0) / times.length;
  }
  
  getAllMetrics(): Record<string, { average: number; count: number; latest: number }> {
    const result: Record<string, { average: number; count: number; latest: number }> = {};
    
    for (const [name, times] of this.metrics.entries()) {
      if (times.length > 0) {
        result[name] = {
          average: this.getAverage(name),
          count: times.length,
          latest: times[times.length - 1]
        };
      }
    }
    
    return result;
  }
}

// React import for lazy loading
import React from 'react';

// Performance hook for components
export function usePerformanceMonitor(componentName: string) {
  const monitor = PerformanceMonitor.getInstance();
  
  return useCallback((operationName: string) => {
    return monitor.startTimer(`${componentName}.${operationName}`);
  }, [componentName, monitor]);
}

// Cache management for API calls
export function createApiCache(defaultTTL: number = 5 * 60 * 1000) {
  return {
    get: (key: string) => memoryCache.get(`api:${key}`),
    set: (key: string, data: any, ttl?: number) => memoryCache.set(`api:${key}`, data, ttl || defaultTTL),
    invalidate: (pattern?: string) => {
      if (pattern) {
        // Clear keys matching pattern
        // For now, clear all - could be enhanced with pattern matching
        memoryCache.clear();
      } else {
        memoryCache.clear();
      }
    }
  };
}

// Image lazy loading utilities
export function useIntersectionObserver(
  ref: React.RefObject<Element>,
  options: IntersectionObserverInit = {}
) {
  const [isIntersecting, setIsIntersecting] = React.useState(false);
  
  React.useEffect(() => {
    if (!ref.current) return;
    
    const observer = new IntersectionObserver(([entry]) => {
      setIsIntersecting(entry.isIntersecting);
    }, options);
    
    observer.observe(ref.current);
    
    return () => observer.disconnect();
  }, [ref, options]);
  
  return isIntersecting;
}

// Bundle size optimization - code splitting utilities
export const splitChunks = {
  charts: () => import('@/components/charts/PlotlyAmazon'),
  ai: () => import('@/components/ai/FloatingAssistant'),
  export: () => import('@/lib/export'),
  forecast: () => import('@/components/ForecastCard'),
  insights: () => import('@/components/MindsDBInsights')
};

// Performance optimization flags
export const PERFORMANCE_CONFIG = {
  enableCaching: true,
  enableLazyLoading: true,
  enableDebouncing: true,
  enableMonitoring: process.env.NODE_ENV === 'development',
  cacheTimeout: 5 * 60 * 1000, // 5 minutes
  debounceDelay: 300, // 300ms
  throttleLimit: 100, // 100ms
};

// Component performance wrapper
export function withPerformanceMonitoring<P extends object>(
  Component: React.ComponentType<P>,
  componentName: string
) {
  return function PerformanceWrapper(props: P) {
    const startRender = React.useRef<() => void>();
    
    // Start monitoring on mount
    React.useEffect(() => {
      if (PERFORMANCE_CONFIG.enableMonitoring) {
        const monitor = PerformanceMonitor.getInstance();
        startRender.current = monitor.startTimer(`${componentName}.render`);
      }
    }, []);
    
    // End monitoring on render complete
    React.useLayoutEffect(() => {
      if (startRender.current) {
        startRender.current();
      }
    });
    
    return React.createElement(Component, props);
  };
}