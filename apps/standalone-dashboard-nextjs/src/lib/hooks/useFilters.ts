'use client';

import { create } from 'zustand';
import { subscribeWithSelector } from 'zustand/middleware';
import { useRouter, useSearchParams } from 'next/navigation';
import { useCallback, useEffect } from 'react';
import type { AnalyticsFilters } from '@/lib/supabase/types';

interface FilterStore {
  filters: AnalyticsFilters;
  breadcrumbs: Array<{ label: string; value: string; type: string }>;
  compareMode: boolean;
  compareEntities: string[];
  drillLevel: number;
  
  // Actions
  setFilter: (key: keyof AnalyticsFilters, value: string | string[] | undefined) => void;
  resetFilters: () => void;
  drillDown: (type: string, value: string, label: string) => void;
  drillUp: (targetLevel: number) => void;
  setCompareMode: (enabled: boolean) => void;
  addCompareEntity: (entity: string) => void;
  removeCompareEntity: (entity: string) => void;
  clearCompareEntities: () => void;
}

// Default filter values
const defaultFilters: AnalyticsFilters = {
  date_preset: '30d',
  date_start: undefined,
  date_end: undefined,
  region: undefined,
  province: undefined,
  city: undefined,
  store: undefined,
  category: undefined,
  brand: undefined,
  sku: undefined,
  cohort: undefined,
  segment: undefined,
  loyalty_tier: undefined,
  daypart: undefined,
  dow: undefined,
  compare_mode: undefined,
  compare_entities: undefined,
};

// Zustand store for filter state
export const useFilterStore = create<FilterStore>()(
  subscribeWithSelector((set, get) => ({
    filters: defaultFilters,
    breadcrumbs: [],
    compareMode: false,
    compareEntities: [],
    drillLevel: 0,

    setFilter: (key, value) => {
      set((state) => ({
        filters: {
          ...state.filters,
          [key]: value,
        },
      }));
    },

    resetFilters: () => {
      set({
        filters: defaultFilters,
        breadcrumbs: [],
        drillLevel: 0,
      });
    },

    drillDown: (type, value, label) => {
      set((state) => {
        const newBreadcrumbs = [
          ...state.breadcrumbs,
          { label, value, type },
        ];
        
        return {
          filters: {
            ...state.filters,
            [type]: value,
          },
          breadcrumbs: newBreadcrumbs,
          drillLevel: state.drillLevel + 1,
        };
      });
    },

    drillUp: (targetLevel) => {
      set((state) => {
        const newBreadcrumbs = state.breadcrumbs.slice(0, targetLevel);
        const newFilters = { ...state.filters };
        
        // Reset filters that are deeper than target level
        state.breadcrumbs.slice(targetLevel).forEach((crumb) => {
          newFilters[crumb.type as keyof AnalyticsFilters] = undefined;
        });
        
        return {
          filters: newFilters,
          breadcrumbs: newBreadcrumbs,
          drillLevel: targetLevel,
        };
      });
    },

    setCompareMode: (enabled) => {
      set((state) => ({
        compareMode: enabled,
        filters: {
          ...state.filters,
          compare_mode: enabled ? 'enabled' : undefined,
        },
      }));
    },

    addCompareEntity: (entity) => {
      set((state) => {
        if (state.compareEntities.includes(entity)) return state;
        
        const newEntities = [...state.compareEntities, entity];
        return {
          compareEntities: newEntities,
          filters: {
            ...state.filters,
            compare_entities: newEntities,
          },
        };
      });
    },

    removeCompareEntity: (entity) => {
      set((state) => {
        const newEntities = state.compareEntities.filter(e => e !== entity);
        return {
          compareEntities: newEntities,
          filters: {
            ...state.filters,
            compare_entities: newEntities.length > 0 ? newEntities : undefined,
          },
        };
      });
    },

    clearCompareEntities: () => {
      set((state) => ({
        compareEntities: [],
        filters: {
          ...state.filters,
          compare_entities: undefined,
        },
      }));
    },
  }))
);

// Hook for URL synchronization
export function useFilterSync() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { filters, setFilter } = useFilterStore();

  // Sync from URL to store on mount
  useEffect(() => {
    const urlFilters = Object.fromEntries(searchParams.entries());
    
    Object.entries(urlFilters).forEach(([key, value]) => {
      if (key in defaultFilters) {
        const filterKey = key as keyof AnalyticsFilters;
        const parsedValue = key === 'compare_entities' 
          ? value.split(',').filter(Boolean)
          : value || undefined;
        
        setFilter(filterKey, parsedValue);
      }
    });
  }, [searchParams, setFilter]);

  // Sync from store to URL
  useEffect(() => {
    const params = new URLSearchParams();
    
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined) {
        const stringValue = Array.isArray(value) ? value.join(',') : String(value);
        if (stringValue && stringValue !== 'undefined') {
          params.set(key, stringValue);
        }
      }
    });

    const newUrl = params.toString() ? `?${params.toString()}` : '';
    router.replace(newUrl, { scroll: false });
  }, [filters, router]);
}

// Hook for drill-down functionality
export function useDrillHandler() {
  const { drillDown, drillUp, breadcrumbs } = useFilterStore();

  const handleDrillDown = useCallback((type: string, value: string, label: string) => {
    // Hierarchical drill-down logic
    const hierarchies = {
      geography: ['region', 'province', 'city'],
      product: ['category', 'brand', 'sku'],
      customer: ['segment', 'cohort', 'loyalty_tier'],
    };

    // Determine which hierarchy this belongs to
    let hierarchy: string[] = [];
    for (const [, levels] of Object.entries(hierarchies)) {
      if (levels.includes(type)) {
        hierarchy = levels;
        break;
      }
    }

    // Clear deeper levels in the same hierarchy
    if (hierarchy.length > 0) {
      const currentIndex = hierarchy.indexOf(type);
      const deeperLevels = hierarchy.slice(currentIndex + 1);
      
      deeperLevels.forEach(level => {
        useFilterStore.getState().setFilter(level as keyof AnalyticsFilters, undefined);
      });
    }

    drillDown(type, value, label);
  }, [drillDown]);

  const handleBreadcrumbClick = useCallback((level: number) => {
    drillUp(level);
  }, [drillUp]);

  return {
    handleDrillDown,
    handleBreadcrumbClick,
    breadcrumbs,
  };
}

// Hook for compare mode functionality
export function useCompareMode() {
  const {
    compareMode,
    compareEntities,
    setCompareMode,
    addCompareEntity,
    removeCompareEntity,
    clearCompareEntities,
  } = useFilterStore();

  const toggleCompareMode = useCallback(() => {
    setCompareMode(!compareMode);
    if (!compareMode) {
      clearCompareEntities();
    }
  }, [compareMode, setCompareMode, clearCompareEntities]);

  const handleCompareEntity = useCallback((entity: string) => {
    if (compareEntities.includes(entity)) {
      removeCompareEntity(entity);
    } else if (compareEntities.length < 5) { // Max 5 entities
      addCompareEntity(entity);
    }
  }, [compareEntities, addCompareEntity, removeCompareEntity]);

  return {
    compareMode,
    compareEntities,
    toggleCompareMode,
    handleCompareEntity,
    clearCompareEntities,
    canAddMore: compareEntities.length < 5,
  };
}

// Main filter hook
export function useFilters() {
  const store = useFilterStore();
  
  return {
    filters: store.filters,
    setFilter: store.setFilter,
    resetFilters: store.resetFilters,
    breadcrumbs: store.breadcrumbs,
    drillLevel: store.drillLevel,
  };
}