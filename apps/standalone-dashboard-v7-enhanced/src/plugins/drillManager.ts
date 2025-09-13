import { useFilterBus } from '@/state/filterBus';

export interface DrillBehavior {
  sourcePanel: string;
  on: 'pointClick' | 'barClick' | 'regionClick' | 'cellClick';
  addFilters: Array<{
    dimension: string;
    from: string; // path in datum object
  }>;
  navigateTo?: string | null;
}

export interface DrillConfig {
  enabled: boolean;
  stackLimit: number;
  behaviors: DrillBehavior[];
}

// Apply drill filters from datum
export function applyDrill(
  addFilters: Array<{ dimension: string; from: string }>,
  datum: any
) {
  const { addDrill } = useFilterBus.getState();
  
  addFilters.forEach(filterConfig => {
    const value = getNestedValue(datum, filterConfig.from);
    if (value != null) {
      const label = generateDrillLabel(filterConfig.dimension, value, datum);
      addDrill(filterConfig.dimension, value, label);
    }
  });
}

// Helper to get nested values from datum (e.g., "datum.category_id")
function getNestedValue(obj: any, path: string): any {
  return path.split('.').reduce((current, key) => current?.[key], obj);
}

// Generate user-friendly label for drill breadcrumb
function generateDrillLabel(dimension: string, value: any, datum: any): string {
  // Try to find a human-readable label in the datum
  const labelMappings: Record<string, string[]> = {
    'time.date_day': ['date_label', 'bucket', 'time_bucket'],
    'location.region': ['region_name', 'region'],
    'location.city': ['city_name', 'city'],
    'location.barangay': ['barangay_name', 'barangay'],
    'product.category': ['category_name', 'category'],
    'product.brand': ['brand_name', 'brand'],
    'product.sku': ['sku_name', 'sku'],
    'consumer.gender': ['gender_label', 'gender'],
    'consumer.age_bracket': ['age_label', 'age_bracket']
  };
  
  const possibleLabels = labelMappings[dimension] || [];
  
  for (const labelKey of possibleLabels) {
    const label = getNestedValue(datum, labelKey);
    if (label && typeof label === 'string') {
      return label;
    }
  }
  
  // Fallback to the value itself
  return String(value);
}

// Hook to wire drill behavior to chart components
export function useDrillHandler(panelId: string, drillConfig: DrillConfig) {
  const behavior = drillConfig.behaviors.find(b => b.sourcePanel === panelId);
  
  if (!behavior || !drillConfig.enabled) {
    return null;
  }
  
  return (datum: any, navigate?: (path: string) => void) => {
    // Apply the drill filters
    applyDrill(behavior.addFilters, datum);
    
    // Navigate if specified
    if (behavior.navigateTo && navigate) {
      navigate(`/dash/${behavior.navigateTo}`);
    }
  };
}

// Breadcrumb component helpers
export function useDrillBreadcrumbs() {
  const { drillStack, removeDrill, clearDrills } = useFilterBus();
  
  return {
    breadcrumbs: drillStack,
    removeDrill,
    clearDrills,
    canDrill: drillStack.length < 6 // stackLimit from config
  };
}

// Drill validation
export function validateDrillAction(
  panelId: string,
  datum: any,
  drillConfig: DrillConfig
): { valid: boolean; reason?: string } {
  if (!drillConfig.enabled) {
    return { valid: false, reason: 'Drill-down is disabled' };
  }
  
  const behavior = drillConfig.behaviors.find(b => b.sourcePanel === panelId);
  if (!behavior) {
    return { valid: false, reason: 'No drill behavior configured for this panel' };
  }
  
  const { drillStack } = useFilterBus.getState();
  if (drillStack.length >= drillConfig.stackLimit) {
    return { valid: false, reason: 'Maximum drill depth reached' };
  }
  
  // Check if all required fields are present in datum
  for (const filter of behavior.addFilters) {
    const value = getNestedValue(datum, filter.from);
    if (value == null) {
      return { 
        valid: false, 
        reason: `Missing required field: ${filter.from}` 
      };
    }
  }
  
  return { valid: true };
}