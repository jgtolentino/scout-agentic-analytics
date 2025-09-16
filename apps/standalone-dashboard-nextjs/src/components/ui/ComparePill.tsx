'use client';

import { useState, useRef, useEffect } from 'react';
import { useCompareMode } from '@/lib/hooks';

interface ComparePillProps {
  entityType: 'brand' | 'category' | 'region' | 'store';
  className?: string;
}

interface CompareEntity {
  id: string;
  name: string;
  type: string;
  value?: number;
  color?: string;
}

export default function ComparePill({ entityType, className = '' }: ComparePillProps) {
  const {
    compareMode,
    compareEntities,
    toggleCompareMode,
    handleCompareEntity,
    clearCompareEntities,
    canAddMore,
  } = useCompareMode();
  
  const [showDropdown, setShowDropdown] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [availableEntities, setAvailableEntities] = useState<CompareEntity[]>([]);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Sample data - would come from API in real implementation
  useEffect(() => {
    const sampleData: Record<string, CompareEntity[]> = {
      brand: [
        { id: 'coca-cola', name: 'Coca-Cola', type: 'brand', value: 45.2, color: '#dc2626' },
        { id: 'pepsi', name: 'Pepsi', type: 'brand', value: 32.1, color: '#2563eb' },
        { id: 'sprite', name: 'Sprite', type: 'brand', value: 15.7, color: '#16a34a' },
        { id: '7up', name: '7UP', type: 'brand', value: 7.0, color: '#ca8a04' },
      ],
      category: [
        { id: 'beverages', name: 'Beverages', type: 'category', value: 38.5, color: '#3b82f6' },
        { id: 'snacks', name: 'Snacks', type: 'category', value: 25.3, color: '#f59e0b' },
        { id: 'dairy', name: 'Dairy', type: 'category', value: 18.7, color: '#10b981' },
        { id: 'confectionery', name: 'Confectionery', type: 'category', value: 17.5, color: '#f43f5e' },
      ],
      region: [
        { id: 'ncr', name: 'NCR', type: 'region', value: 42.3, color: '#6366f1' },
        { id: 'calabarzon', name: 'CALABARZON', type: 'region', value: 28.9, color: '#8b5cf6' },
        { id: 'central-luzon', name: 'Central Luzon', type: 'region', value: 15.2, color: '#06b6d4' },
        { id: 'western-visayas', name: 'Western Visayas', type: 'region', value: 13.6, color: '#84cc16' },
      ],
      store: [
        { id: 'sm-mall', name: 'SM Mall of Asia', type: 'store', value: 15.8, color: '#ef4444' },
        { id: 'ayala-makati', name: 'Ayala Makati', type: 'store', value: 12.3, color: '#3b82f6' },
        { id: 'robinsons-manila', name: 'Robinsons Manila', type: 'store', value: 9.7, color: '#10b981' },
        { id: 'gateway-mall', name: 'Gateway Mall', type: 'store', value: 8.4, color: '#f59e0b' },
      ],
    };
    
    setAvailableEntities(sampleData[entityType] || []);
  }, [entityType]);

  // Filter entities based on search query
  const filteredEntities = availableEntities.filter(entity =>
    entity.name.toLowerCase().includes(searchQuery.toLowerCase()) &&
    !compareEntities.includes(entity.id)
  );

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setShowDropdown(false);
        setSearchQuery('');
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleToggleCompare = () => {
    toggleCompareMode();
    if (!compareMode) {
      setShowDropdown(true);
      setTimeout(() => inputRef.current?.focus(), 100);
    }
  };

  const handleAddEntity = (entityId: string) => {
    handleCompareEntity(entityId);
    setSearchQuery('');
    setShowDropdown(false);
  };

  const handleRemoveEntity = (entityId: string) => {
    handleCompareEntity(entityId);
  };

  const getEntityInfo = (entityId: string) => {
    return availableEntities.find(e => e.id === entityId);
  };

  return (
    <div className={`relative ${className}`}>
      {/* Compare Mode Toggle */}
      <div className="flex items-center gap-2 mb-3">
        <button
          onClick={handleToggleCompare}
          className={`inline-flex items-center px-3 py-1.5 text-sm font-medium rounded-md transition-colors ${
            compareMode
              ? 'bg-blue-100 text-blue-700 border border-blue-200'
              : 'bg-gray-100 text-gray-700 border border-gray-200 hover:bg-gray-200'
          }`}
        >
          <svg
            className="w-4 h-4 mr-1.5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
            />
          </svg>
          Compare {entityType}s
        </button>

        {compareMode && (
          <span className="text-xs text-gray-500">
            {compareEntities.length}/5 selected
          </span>
        )}
      </div>

      {/* Compare Mode Interface */}
      {compareMode && (
        <div className="space-y-3">
          {/* Selected Entities Pills */}
          {compareEntities.length > 0 && (
            <div className="flex flex-wrap gap-2">
              {compareEntities.map(entityId => {
                const entity = getEntityInfo(entityId);
                return (
                  <div
                    key={entityId}
                    className="inline-flex items-center px-3 py-1 bg-blue-100 text-blue-800 rounded-full text-sm"
                    style={entity?.color ? { backgroundColor: `${entity.color}20`, color: entity.color } : {}}
                  >
                    <span className="font-medium">
                      {entity?.name || entityId}
                    </span>
                    {entity?.value && (
                      <span className="ml-1 text-xs opacity-75">
                        ({entity.value}%)
                      </span>
                    )}
                    <button
                      onClick={() => handleRemoveEntity(entityId)}
                      className="ml-2 hover:bg-black hover:bg-opacity-10 rounded-full p-0.5 transition-colors"
                      title="Remove"
                    >
                      <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                        <path
                          fillRule="evenodd"
                          d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                          clipRule="evenodd"
                        />
                      </svg>
                    </button>
                  </div>
                );
              })}
            </div>
          )}

          {/* Add Entity Input */}
          {canAddMore && (
            <div className="relative" ref={dropdownRef}>
              <input
                ref={inputRef}
                type="text"
                placeholder={`Search ${entityType}s to compare...`}
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onFocus={() => setShowDropdown(true)}
                className="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />

              {/* Dropdown */}
              {showDropdown && (
                <div className="absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg max-h-60 overflow-y-auto">
                  {filteredEntities.length > 0 ? (
                    filteredEntities.map(entity => (
                      <button
                        key={entity.id}
                        onClick={() => handleAddEntity(entity.id)}
                        className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 focus:bg-gray-50 focus:outline-none flex items-center justify-between"
                      >
                        <div className="flex items-center">
                          {entity.color && (
                            <div
                              className="w-3 h-3 rounded-full mr-2"
                              style={{ backgroundColor: entity.color }}
                            />
                          )}
                          <span className="font-medium">{entity.name}</span>
                        </div>
                        {entity.value && (
                          <span className="text-xs text-gray-500">
                            {entity.value}%
                          </span>
                        )}
                      </button>
                    ))
                  ) : (
                    <div className="px-3 py-2 text-sm text-gray-500">
                      {searchQuery ? `No ${entityType}s found matching "${searchQuery}"` : `No more ${entityType}s available`}
                    </div>
                  )}
                </div>
              )}
            </div>
          )}

          {/* Actions */}
          <div className="flex items-center justify-between pt-2 border-t border-gray-200">
            <button
              onClick={clearCompareEntities}
              className="text-xs text-red-600 hover:text-red-700 transition-colors"
              disabled={compareEntities.length === 0}
            >
              Clear all
            </button>

            <div className="flex items-center gap-2 text-xs text-gray-500">
              <span>Tip: Select 2-5 {entityType}s to compare</span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}