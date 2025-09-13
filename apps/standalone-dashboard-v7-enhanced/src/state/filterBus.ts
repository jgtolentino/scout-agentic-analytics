import { create } from 'zustand';
import { persist } from 'zustand/middleware';

type Filters = Record<string, unknown>;

function readFromUrl(): Filters {
  if (typeof window === 'undefined') return {};
  const p = new URLSearchParams(location.search);
  const obj: Filters = {};
  p.forEach((v, k) => {
    try {
      obj[k] = JSON.parse(decodeURIComponent(v));
    } catch {
      obj[k] = v; // fallback to string value
    }
  });
  return obj;
}

function writeToUrl(f: Filters) {
  if (typeof window === 'undefined') return;
  const p = new URLSearchParams();
  Object.entries(f).forEach(([k, v]) => {
    if (v != null && v !== '' && !(Array.isArray(v) && v.length === 0)) {
      p.set(k, encodeURIComponent(JSON.stringify(v)));
    }
  });
  const url = p.toString() ? `?${p.toString()}` : location.pathname;
  history.replaceState(null, '', url);
}

export const useFilterBus = create<{
  filters: Filters;
  drillStack: Array<{dimension: string; value: any; label: string}>;
  set: (patch: Partial<Filters>) => void;
  replace: (all: Filters) => void;
  reset: () => void;
  addDrill: (dimension: string, value: any, label: string) => void;
  removeDrill: (index: number) => void;
  clearDrills: () => void;
}>()(
  persist(
    (set, get) => ({
      filters: { ...readFromUrl() },
      drillStack: [],
      
      set: (patch) => {
        const next = { ...get().filters, ...patch };
        set({ filters: next });
        writeToUrl(next);
        
        // Broadcast filter change event
        if (typeof window !== 'undefined') {
          window.dispatchEvent(
            new CustomEvent('filters:update', { detail: next })
          );
        }
      },
      
      replace: (all) => {
        set({ filters: all });
        writeToUrl(all);
        
        if (typeof window !== 'undefined') {
          window.dispatchEvent(
            new CustomEvent('filters:update', { detail: all })
          );
        }
      },
      
      reset: () => {
        const empty = {};
        set({ filters: empty, drillStack: [] });
        writeToUrl(empty);
        
        if (typeof window !== 'undefined') {
          window.dispatchEvent(
            new CustomEvent('filters:update', { detail: empty })
          );
        }
      },
      
      addDrill: (dimension, value, label) => {
        const currentStack = get().drillStack;
        const newStack = [...currentStack, { dimension, value, label }];
        set({ drillStack: newStack });
        
        // Apply the drill as a filter
        const currentFilters = get().filters;
        const dimensionKey = dimension.replace('.', '_'); // time.date_day -> time_date_day
        const newFilters = { ...currentFilters, [dimensionKey]: [value] };
        get().set(newFilters);
      },
      
      removeDrill: (index) => {
        const currentStack = get().drillStack;
        if (index >= 0 && index < currentStack.length) {
          const newStack = currentStack.slice(0, index);
          set({ drillStack: newStack });
          
          // Remove filters that were added after this drill level
          const currentFilters = get().filters;
          const newFilters = { ...currentFilters };
          for (let i = index; i < currentStack.length; i++) {
            const dimensionKey = currentStack[i].dimension.replace('.', '_');
            delete newFilters[dimensionKey];
          }
          get().replace(newFilters);
        }
      },
      
      clearDrills: () => {
        const currentStack = get().drillStack;
        set({ drillStack: [] });
        
        // Remove all drill-added filters
        const currentFilters = get().filters;
        const newFilters = { ...currentFilters };
        currentStack.forEach(drill => {
          const dimensionKey = drill.dimension.replace('.', '_');
          delete newFilters[dimensionKey];
        });
        get().replace(newFilters);
      }
    }),
    {
      name: 'scout-v7-filters',
      partialize: (state) => ({ 
        filters: state.filters,
        drillStack: state.drillStack 
      })
    }
  )
);

// Hook for components to listen to filter changes
export function onGlobalFilterChange(cb: (filters: Filters) => void) {
  if (typeof window === 'undefined') return () => {};
  
  const handler = (e: any) => cb(e.detail);
  window.addEventListener('filters:update', handler);
  return () => window.removeEventListener('filters:update', handler);
}

// Utility to get current filter values for API calls
export function getFilterParams(): Record<string, any> {
  const { filters } = useFilterBus.getState();
  return filters;
}

// Utility to check if a filter is active
export function isFilterActive(key: string): boolean {
  const { filters } = useFilterBus.getState();
  const value = filters[key];
  return value != null && value !== '' && !(Array.isArray(value) && value.length === 0);
}