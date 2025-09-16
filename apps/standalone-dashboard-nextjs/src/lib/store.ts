'use client';

import { create } from 'zustand';
import { persist, subscribeWithSelector } from 'zustand/middleware';

export type Filters = {
  date: 'last_7d' | 'last_30d' | 'this_month' | 'last_quarter' | 'custom';
  region: string;
  category: string;
  brand?: string;
  daypart?: 'morning' | 'afternoon' | 'evening' | 'night';
  dow?: 'weekday' | 'weekend';
  // Hierarchical place filters
  province?: string;
  city?: string;
  store?: string;
  // Product hierarchy
  sku?: string;
  // Customer segmentation
  cohort?: string; // 'july_2024', 'aug_2024', etc.
  segment?: 'new' | 'returning' | 'loyal';
  loyaltyTier?: 'bronze' | 'silver' | 'gold' | 'platinum';
  // Comparison mode
  compareMode?: 'none' | 'period' | 'brand' | 'region';
  compareBrandA?: string;
  compareBrandB?: string;
  compareRegionA?: string;
  compareRegionB?: string;
};

export type Breadcrumb = {
  label: string;
  filters: Partial<Filters>;
  path: string;
};

type FilterStore = {
  filters: Filters;
  breadcrumbs: Breadcrumb[];
  set: (updates: Partial<Filters>) => void;
  pushCrumb: (crumb: Breadcrumb) => void;
  reset: () => void;
  goToCrumb: (index: number) => void;
  // Comparison utilities
  enableCompare: (mode: 'period' | 'brand' | 'region') => void;
  setCompareEntities: (a: string, b: string, mode: 'brand' | 'region') => void;
  disableCompare: () => void;
  // Hierarchical filter helpers
  clearHierarchy: (type: 'place' | 'product') => void;
  setHierarchicalFilter: (type: 'place' | 'product', level: string, value: string) => void;
};

const DEFAULT_FILTERS: Filters = {
  date: 'last_30d',
  region: 'ALL',
  category: 'ALL'
};

// URL sync helpers
const getFiltersFromURL = (): Partial<Filters> => {
  if (typeof window === 'undefined') return {};
  const params = new URLSearchParams(window.location.search);
  const urlFilters: Partial<Filters> = {};
  
  // Basic filters
  if (params.get('date')) urlFilters.date = params.get('date') as Filters['date'];
  if (params.get('region')) urlFilters.region = params.get('region');
  if (params.get('category')) urlFilters.category = params.get('category');
  if (params.get('brand')) urlFilters.brand = params.get('brand');
  if (params.get('daypart')) urlFilters.daypart = params.get('daypart') as Filters['daypart'];
  if (params.get('dow')) urlFilters.dow = params.get('dow') as Filters['dow'];
  
  // Hierarchical filters
  if (params.get('province')) urlFilters.province = params.get('province');
  if (params.get('city')) urlFilters.city = params.get('city');
  if (params.get('store')) urlFilters.store = params.get('store');
  if (params.get('sku')) urlFilters.sku = params.get('sku');
  
  // Customer segmentation
  if (params.get('cohort')) urlFilters.cohort = params.get('cohort');
  if (params.get('segment')) urlFilters.segment = params.get('segment') as Filters['segment'];
  if (params.get('loyaltyTier')) urlFilters.loyaltyTier = params.get('loyaltyTier') as Filters['loyaltyTier'];
  
  // Comparison mode
  if (params.get('compareMode')) urlFilters.compareMode = params.get('compareMode') as Filters['compareMode'];
  if (params.get('compareBrandA')) urlFilters.compareBrandA = params.get('compareBrandA');
  if (params.get('compareBrandB')) urlFilters.compareBrandB = params.get('compareBrandB');
  if (params.get('compareRegionA')) urlFilters.compareRegionA = params.get('compareRegionA');
  if (params.get('compareRegionB')) urlFilters.compareRegionB = params.get('compareRegionB');
  
  return urlFilters;
};

const updateURL = (filters: Filters) => {
  if (typeof window === 'undefined') return;
  const params = new URLSearchParams();
  
  Object.entries(filters).forEach(([key, value]) => {
    if (value && value !== 'ALL') {
      params.set(key, value);
    }
  });
  
  const newURL = params.toString() ? `?${params.toString()}` : window.location.pathname;
  window.history.replaceState(null, '', newURL);
};

export const useFilterBus = create<FilterStore>()(
  subscribeWithSelector(
    persist(
      (set, get) => ({
        filters: { ...DEFAULT_FILTERS, ...getFiltersFromURL() },
        breadcrumbs: [],
        
        set: (updates) => {
          const newFilters = { ...get().filters, ...updates };
          set({ filters: newFilters });
          updateURL(newFilters);
          
          // Emit custom event for cross-component reactivity
          if (typeof window !== 'undefined') {
            window.dispatchEvent(new CustomEvent('filtersChanged', { 
              detail: newFilters 
            }));
          }
        },
        
        pushCrumb: (crumb) => {
          const current = get().breadcrumbs;
          const newCrumbs = [...current, crumb].slice(-6); // Keep last 6
          set({ breadcrumbs: newCrumbs });
        },
        
        reset: () => {
          set({ 
            filters: DEFAULT_FILTERS, 
            breadcrumbs: [] 
          });
          updateURL(DEFAULT_FILTERS);
        },
        
        goToCrumb: (index) => {
          const crumbs = get().breadcrumbs;
          if (crumbs[index]) {
            const targetCrumb = crumbs[index];
            get().set(targetCrumb.filters);
            set({ breadcrumbs: crumbs.slice(0, index + 1) });
          }
        },
        
        // Comparison utilities
        enableCompare: (mode) => {
          get().set({ 
            compareMode: mode,
            // Clear existing compare values when switching modes
            compareBrandA: undefined,
            compareBrandB: undefined,
            compareRegionA: undefined,
            compareRegionB: undefined
          });
        },
        
        setCompareEntities: (a, b, mode) => {
          if (mode === 'brand') {
            get().set({ 
              compareMode: 'brand',
              compareBrandA: a,
              compareBrandB: b 
            });
          } else if (mode === 'region') {
            get().set({ 
              compareMode: 'region',
              compareRegionA: a,
              compareRegionB: b 
            });
          }
        },
        
        disableCompare: () => {
          get().set({ 
            compareMode: 'none',
            compareBrandA: undefined,
            compareBrandB: undefined,
            compareRegionA: undefined,
            compareRegionB: undefined
          });
        },
        
        // Hierarchical filter helpers
        clearHierarchy: (type) => {
          if (type === 'place') {
            get().set({ 
              province: undefined,
              city: undefined,
              store: undefined 
            });
          } else if (type === 'product') {
            get().set({ 
              brand: undefined,
              sku: undefined 
            });
          }
        },
        
        setHierarchicalFilter: (type, level, value) => {
          if (type === 'place') {
            if (level === 'region') {
              // Clear children when parent changes
              get().set({ 
                region: value,
                province: undefined,
                city: undefined,
                store: undefined 
              });
            } else if (level === 'province') {
              get().set({ 
                province: value,
                city: undefined,
                store: undefined 
              });
            } else if (level === 'city') {
              get().set({ 
                city: value,
                store: undefined 
              });
            } else if (level === 'store') {
              get().set({ store: value });
            }
          } else if (type === 'product') {
            if (level === 'category') {
              // Clear children when parent changes
              get().set({ 
                category: value,
                brand: undefined,
                sku: undefined 
              });
            } else if (level === 'brand') {
              get().set({ 
                brand: value,
                sku: undefined 
              });
            } else if (level === 'sku') {
              get().set({ sku: value });
            }
          }
        }
      }),
      { 
        name: 'scout-v71-filters',
        partialize: (state) => ({ filters: state.filters, breadcrumbs: state.breadcrumbs })
      }
    )
  )
);