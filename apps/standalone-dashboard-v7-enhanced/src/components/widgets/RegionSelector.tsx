/**
 * Scout v7 Region Selector Widget
 * Interactive region selector for geographical filtering
 */
import React, { useState } from 'react';

export interface RegionSelectorProps {
  title?: string;
  regions?: Array<{
    id: string;
    name: string;
    code: string;
    population?: number;
    area?: number;
    isActive?: boolean;
  }>;
  selectedRegions?: string[];
  onRegionChange?: (selectedRegions: string[]) => void;
  multiSelect?: boolean;
  isLoading?: boolean;
  className?: string;
}

export const RegionSelector: React.FC<RegionSelectorProps> = ({
  title = "Select Regions",
  regions = [],
  selectedRegions = [],
  onRegionChange,
  multiSelect = true,
  isLoading,
  className,
}) => {
  const [localSelection, setLocalSelection] = useState<string[]>(selectedRegions);

  const handleRegionToggle = (regionId: string) => {
    let newSelection: string[];
    
    if (multiSelect) {
      newSelection = localSelection.includes(regionId)
        ? localSelection.filter(id => id !== regionId)
        : [...localSelection, regionId];
    } else {
      newSelection = localSelection.includes(regionId) ? [] : [regionId];
    }
    
    setLocalSelection(newSelection);
    onRegionChange?.(newSelection);
  };

  if (isLoading) {
    return (
      <div className={`bg-white rounded-lg border shadow-sm ${className}`}>
        {title && (
          <div className="p-4 border-b">
            <div className="h-5 bg-gray-200 rounded w-1/3 animate-pulse"></div>
          </div>
        )}
        <div className="p-4 space-y-2">
          {[...Array(5)].map((_, i) => (
            <div key={i} className="flex items-center space-x-3">
              <div className="w-4 h-4 bg-gray-200 rounded animate-pulse"></div>
              <div className="h-4 bg-gray-200 rounded w-24 animate-pulse"></div>
              <div className="h-3 bg-gray-200 rounded w-16 animate-pulse"></div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className={`bg-white rounded-lg border shadow-sm ${className}`}>
      {title && (
        <div className="p-4 border-b">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-semibold text-gray-900">
              {title}
            </h3>
            {multiSelect && localSelection.length > 0 && (
              <span className="text-sm text-gray-600">
                {localSelection.length} selected
              </span>
            )}
          </div>
        </div>
      )}
      
      <div className="p-4">
        {regions.length === 0 ? (
          <div className="text-center py-8 text-gray-500">
            No regions available
          </div>
        ) : (
          <div className="space-y-2">
            {multiSelect && (
              <div className="flex items-center justify-between mb-4 pb-2 border-b">
                <button
                  onClick={() => {
                    const allRegionIds = regions.filter(r => r.isActive !== false).map(r => r.id);
                    setLocalSelection(allRegionIds);
                    onRegionChange?.(allRegionIds);
                  }}
                  className="text-sm text-blue-600 hover:text-blue-800"
                >
                  Select All
                </button>
                <button
                  onClick={() => {
                    setLocalSelection([]);
                    onRegionChange?.([]);
                  }}
                  className="text-sm text-blue-600 hover:text-blue-800"
                >
                  Clear All
                </button>
              </div>
            )}
            
            {regions.map((region) => {
              const isSelected = localSelection.includes(region.id);
              const isDisabled = region.isActive === false;
              
              return (
                <label
                  key={region.id}
                  className={`flex items-center space-x-3 p-2 rounded cursor-pointer transition-colors ${
                    isDisabled 
                      ? 'opacity-50 cursor-not-allowed' 
                      : 'hover:bg-gray-50'
                  }`}
                >
                  <input
                    type={multiSelect ? "checkbox" : "radio"}
                    name="region-selector"
                    checked={isSelected}
                    disabled={isDisabled}
                    onChange={() => !isDisabled && handleRegionToggle(region.id)}
                    className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                  />
                  
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center space-x-2">
                      <span className={`text-sm font-medium ${
                        isSelected ? 'text-gray-900' : 'text-gray-900'
                      }`}>
                        {region.name}
                      </span>
                      <span className="text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded">
                        {region.code}
                      </span>
                    </div>
                    
                    {(region.population || region.area) && (
                      <div className="text-xs text-gray-500 mt-1">
                        {region.population && (
                          <span className="mr-4">
                            Pop: {region.population.toLocaleString()}
                          </span>
                        )}
                        {region.area && (
                          <span>
                            Area: {region.area.toLocaleString()} km²
                          </span>
                        )}
                      </div>
                    )}
                  </div>
                </label>
              );
            })}
          </div>
        )}
        
        {localSelection.length > 0 && (
          <div className="mt-4 pt-4 border-t">
            <div className="text-sm text-gray-600">
              <span className="font-medium">Selected:</span> {' '}
              {regions
                .filter(r => localSelection.includes(r.id))
                .map(r => r.name)
                .join(', ')
              }
            </div>
          </div>
        )}
      </div>
    </div>
  );
};