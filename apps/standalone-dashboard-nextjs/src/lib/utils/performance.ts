'use client';

// Performance optimization utilities

// Debounce function for search inputs and filters
export function debounce<T extends (...args: any[]) => any>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void {
  let timeout: NodeJS.Timeout;
  
  return (...args: Parameters<T>) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), wait);
  };
}

// Throttle function for scroll and resize events
export function throttle<T extends (...args: any[]) => any>(
  func: T,
  limit: number
): (...args: Parameters<T>) => void {
  let inThrottle: boolean;
  
  return (...args: Parameters<T>) => {
    if (!inThrottle) {
      func(...args);
      inThrottle = true;
      setTimeout(() => inThrottle = false, limit);
    }
  };
}

// Lazy loading for images and components
export function createIntersectionObserver(
  callback: IntersectionObserverCallback,
  options?: IntersectionObserverInit
): IntersectionObserver {
  const defaultOptions: IntersectionObserverInit = {
    root: null,
    rootMargin: '50px',
    threshold: 0.1,
    ...options
  };

  return new IntersectionObserver(callback, defaultOptions);
}

// Memoization for expensive calculations
export function memoize<T extends (...args: any[]) => any>(
  fn: T,
  keyGenerator?: (...args: Parameters<T>) => string
): T {
  const cache = new Map<string, ReturnType<T>>();

  return ((...args: Parameters<T>) => {
    const key = keyGenerator ? keyGenerator(...args) : JSON.stringify(args);
    
    if (cache.has(key)) {
      return cache.get(key);
    }
    
    const result = fn(...args);
    cache.set(key, result);
    
    // Limit cache size to prevent memory leaks
    if (cache.size > 100) {
      const firstKey = cache.keys().next().value;
      cache.delete(firstKey);
    }
    
    return result;
  }) as T;
}

// Virtual scrolling for large lists
export interface VirtualScrollItem {
  id: string | number;
  height: number;
  data: any;
}

export class VirtualScroll {
  private container: HTMLElement;
  private items: VirtualScrollItem[];
  private visibleItems: VirtualScrollItem[] = [];
  private scrollTop: number = 0;
  private containerHeight: number = 0;
  private itemHeight: number = 50; // Default item height

  constructor(container: HTMLElement, items: VirtualScrollItem[]) {
    this.container = container;
    this.items = items;
    this.containerHeight = container.clientHeight;
    this.setupScrollListener();
  }

  private setupScrollListener() {
    const handleScroll = throttle(() => {
      this.scrollTop = this.container.scrollTop;
      this.updateVisibleItems();
    }, 16); // 60fps

    this.container.addEventListener('scroll', handleScroll);
  }

  private updateVisibleItems() {
    const startIndex = Math.floor(this.scrollTop / this.itemHeight);
    const endIndex = Math.min(
      startIndex + Math.ceil(this.containerHeight / this.itemHeight) + 1,
      this.items.length - 1
    );

    this.visibleItems = this.items.slice(startIndex, endIndex + 1);
  }

  getVisibleItems(): VirtualScrollItem[] {
    return this.visibleItems;
  }

  getTotalHeight(): number {
    return this.items.length * this.itemHeight;
  }
}

// Performance monitoring
export class PerformanceMonitor {
  private metrics: Map<string, number[]> = new Map();

  // Track component render time
  measureRender(componentName: string, renderFn: () => any): any {
    const start = performance.now();
    const result = renderFn();
    const end = performance.now();
    
    this.recordMetric(`render:${componentName}`, end - start);
    return result;
  }

  // Track API call time
  async measureApiCall<T>(name: string, apiCall: () => Promise<T>): Promise<T> {
    const start = performance.now();
    try {
      const result = await apiCall();
      const end = performance.now();
      this.recordMetric(`api:${name}`, end - start);
      return result;
    } catch (error) {
      const end = performance.now();
      this.recordMetric(`api:${name}:error`, end - start);
      throw error;
    }
  }

  private recordMetric(name: string, value: number) {
    if (!this.metrics.has(name)) {
      this.metrics.set(name, []);
    }
    
    const values = this.metrics.get(name)!;
    values.push(value);
    
    // Keep only last 100 measurements
    if (values.length > 100) {
      values.shift();
    }
  }

  // Get performance statistics
  getStats(name: string) {
    const values = this.metrics.get(name) || [];
    if (values.length === 0) return null;

    const avg = values.reduce((sum, val) => sum + val, 0) / values.length;
    const min = Math.min(...values);
    const max = Math.max(...values);
    const p95 = values.sort((a, b) => a - b)[Math.floor(values.length * 0.95)];

    return { avg, min, max, p95, count: values.length };
  }

  // Log all metrics
  logAllStats() {
    console.group('Performance Metrics');
    for (const [name] of this.metrics) {
      const stats = this.getStats(name);
      if (stats) {
        console.log(`${name}:`, {
          avg: `${stats.avg.toFixed(2)}ms`,
          p95: `${stats.p95.toFixed(2)}ms`,
          count: stats.count
        });
      }
    }
    console.groupEnd();
  }
}

// Global performance monitor instance
export const performanceMonitor = new PerformanceMonitor();

// Bundle size optimization helpers
export function dynamicImport<T>(importFn: () => Promise<T>): Promise<T> {
  return importFn().catch(error => {
    console.error('Dynamic import failed:', error);
    throw error;
  });
}

// Memory management
export function cleanupMemory() {
  // Clear any global caches
  if (global && global.gc) {
    global.gc();
  }
  
  // Clear console if in production
  if (process.env.NODE_ENV === 'production') {
    console.clear();
  }
}

// Image optimization
export function optimizeImage(src: string, width?: number, quality?: number): string {
  if (src.includes('unsplash.com')) {
    const params = new URLSearchParams();
    if (width) params.set('w', width.toString());
    if (quality) params.set('q', quality.toString());
    return `${src}&${params.toString()}`;
  }
  
  return src;
}

// Preload critical resources
export function preloadResource(href: string, as: string): void {
  const link = document.createElement('link');
  link.rel = 'preload';
  link.href = href;
  link.as = as;
  document.head.appendChild(link);
}

// Service Worker registration for caching
export async function registerServiceWorker(): Promise<void> {
  if ('serviceWorker' in navigator && process.env.NODE_ENV === 'production') {
    try {
      await navigator.serviceWorker.register('/sw.js');
      console.log('Service Worker registered successfully');
    } catch (error) {
      console.error('Service Worker registration failed:', error);
    }
  }
}