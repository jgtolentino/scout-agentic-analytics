'use client';

import React, { useState, useEffect } from 'react';
import { useFilterBus } from '@/lib/store';
import { useDebounce } from '@/lib/performance';
import { dimensionAPI } from '@/lib/api/dimensions';
import clsx from 'clsx';

const DATE_OPTIONS = [
  { value: 'last_7d', label: 'Last 7 Days' },
  { value: 'last_30d', label: 'Last 30 Days' },
  { value: 'this_month', label: 'This Month' },
  { value: 'last_quarter', label: 'Last Quarter' }
];

const REGION_OPTIONS = [
  { value: 'ALL', label: 'All Regions' },
  { value: 'NCR', label: 'NCR' },
  { value: 'Luzon', label: 'Luzon' },
  { value: 'Visayas', label: 'Visayas' },
  { value: 'Mindanao', label: 'Mindanao' }
];

const CATEGORY_OPTIONS = [
  { value: 'ALL', label: 'All Categories' },
  { value: 'Beverages', label: 'Beverages' },
  { value: 'Snacks', label: 'Snacks' },
  { value: 'Household', label: 'Household' },
  { value: 'Personal Care', label: 'Personal Care' },
  { value: 'Tobacco', label: 'Tobacco' }
];

const SEGMENT_OPTIONS = [
  { value: '', label: 'All Customers' },
  { value: 'new', label: 'New Customers' },
  { value: 'returning', label: 'Returning Customers' },
  { value: 'loyal', label: 'Loyal Customers' }
];

const LOYALTY_TIER_OPTIONS = [
  { value: '', label: 'All Tiers' },
  { value: 'bronze', label: 'Bronze' },
  { value: 'silver', label: 'Silver' },
  { value: 'gold', label: 'Gold' },
  { value: 'platinum', label: 'Platinum' }
];

interface CollapsibleFilterPanelProps {
  isCollapsed: boolean;
  onToggle: () => void;
}

export default function CollapsibleFilterPanel({ isCollapsed, onToggle }: CollapsibleFilterPanelProps) {
  const { 
    filters, 
    set: setFilters, 
    reset, 
    setHierarchicalFilter
  } = useFilterBus();

  // State for dynamic options
  const [cohortOptions, setCohortOptions] = useState([]);
  const [brandOptions, setBrandOptions] = useState([]);
  const [provinceOptions, setProvinceOptions] = useState([]);
  const [cityOptions, setCityOptions] = useState([]);

  // Debounced filter change for performance
  const debouncedSetFilters = useDebounce(setFilters, 150);

  // Load dynamic options on mount
  useEffect(() => {
    loadDynamicOptions();
  }, []);

  // Load province/city options when region changes
  useEffect(() => {
    if (filters.region && filters.region !== 'ALL') {
      loadProvinceOptions(filters.region);
    } else {
      setProvinceOptions([]);
      setCityOptions([]);
    }
  }, [filters.region]);

  // Load city options when province changes
  useEffect(() => {
    if (filters.province) {
      loadCityOptions(filters.province);
    } else {
      setCityOptions([]);
    }
  }, [filters.province]);

  // Load brand options when category changes
  useEffect(() => {
    if (filters.category && filters.category !== 'ALL') {
      loadBrandOptions(filters.category);
    } else {
      setBrandOptions([]);
    }
  }, [filters.category]);

  const loadDynamicOptions = async () => {
    try {
      // Load cohorts
      const cohorts = await dimensionAPI.getCohorts('monthly');
      setCohortOptions(cohorts.map(c => ({ value: c.id, label: c.label })));
    } catch (error) {
      console.warn('Failed to load dynamic options:', error);
    }
  };

  const loadProvinceOptions = async (region: string) => {
    try {
      const provinces = await dimensionAPI.getRegions('province', region);
      setProvinceOptions(provinces);
    } catch (error) {
      console.warn('Failed to load provinces:', error);
    }
  };

  const loadCityOptions = async (province: string) => {
    try {
      const cities = await dimensionAPI.getRegions('city', province);
      setCityOptions(cities);
    } catch (error) {
      console.warn('Failed to load cities:', error);
    }
  };

  const loadBrandOptions = async (category: string) => {
    try {
      const brands = await dimensionAPI.getBrands(category);
      setBrandOptions(brands);
    } catch (error) {
      console.warn('Failed to load brands:', error);
    }
  };

  const handleFilterChange = (key: string, value: string) => {
    // Use hierarchical filter helper for place and product filters
    if (key === 'region' || key === 'province' || key === 'city') {
      setHierarchicalFilter('place', key, value || undefined);
    } else if (key === 'category' || key === 'brand') {
      setHierarchicalFilter('product', key, value || undefined);
    } else {
      debouncedSetFilters({ [key]: value || undefined });
    }
  };

  const getActiveFiltersCount = () => {
    let count = 0;
    if (filters.region && filters.region !== 'ALL') count++;
    if (filters.province) count++;
    if (filters.city) count++;
    if (filters.category && filters.category !== 'ALL') count++;
    if (filters.brand) count++;
    if (filters.segment) count++;
    if (filters.loyaltyTier) count++;
    if (filters.cohort) count++;
    return count;
  };

  const activeCount = getActiveFiltersCount();

  return (
    <div className={clsx(
      "bg-white rounded-lg border border-gray-200 shadow-sm transition-all duration-300 relative flex flex-col",
      isCollapsed ? "w-16" : "w-80"
    )}>
      {/* Toggle Button */}
      <button
        onClick={onToggle}
        className="absolute -left-3 top-6 bg-white border border-gray-200 rounded-full w-6 h-6 flex items-center justify-center shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-orange-500 z-10"
        aria-label={isCollapsed ? "Expand filters" : "Collapse filters"}
      >
        <svg
          className={clsx("w-3 h-3 transition-transform text-gray-600", !isCollapsed && "rotate-180")}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
      </button>

      {/* Header */}
      <div className="p-4 border-b border-gray-200">
        {!isCollapsed ? (
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-lg font-semibold text-gray-900">Filters</h3>
              {activeCount > 0 && (
                <p className="text-sm text-orange-600">{activeCount} active</p>
              )}
            </div>
            <button
              onClick={reset}
              className="text-xs text-orange-600 hover:text-orange-800 underline focus:outline-none focus:ring-2 focus:ring-orange-500 rounded px-2 py-1"
              type="button"
            >
              Reset All
            </button>
          </div>
        ) : (
          <div className="text-center">
            <div className="relative">
              <svg className="w-6 h-6 mx-auto text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.707A1 1 0 013 7V4z" />
              </svg>
              {activeCount > 0 && (
                <span className="absolute -top-1 -right-1 bg-orange-500 text-white text-xs rounded-full w-4 h-4 flex items-center justify-center">
                  {activeCount}
                </span>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Filters Content */}
      {!isCollapsed && (
        <div className="flex-1 p-4 space-y-4 overflow-y-auto">
          {/* Date Range */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Date Range</label>
            <select
              value={filters.date}
              onChange={(e) => handleFilterChange('date', e.target.value)}
              className="w-full text-sm border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
            >
              {DATE_OPTIONS.map(option => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </div>

          {/* Location Filters */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Location</label>
            <div className="space-y-2">
              {/* Region */}
              <select
                value={filters.region}
                onChange={(e) => handleFilterChange('region', e.target.value)}
                className="w-full text-sm border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
              >
                {REGION_OPTIONS.map(option => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>

              {/* Province */}
              {provinceOptions.length > 0 && (
                <select
                  value={filters.province || ''}
                  onChange={(e) => handleFilterChange('province', e.target.value)}
                  className="w-full text-sm border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
                >
                  <option value="">All Provinces</option>
                  {provinceOptions.map(option => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              )}

              {/* City */}
              {cityOptions.length > 0 && (
                <select
                  value={filters.city || ''}
                  onChange={(e) => handleFilterChange('city', e.target.value)}
                  className="w-full text-sm border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
                >
                  <option value="">All Cities</option>
                  {cityOptions.map(option => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              )}
            </div>
          </div>

          {/* Product Filters */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Product</label>
            <div className="space-y-2">
              {/* Category */}
              <select
                value={filters.category}
                onChange={(e) => handleFilterChange('category', e.target.value)}
                className="w-full text-sm border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
              >
                {CATEGORY_OPTIONS.map(option => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>

              {/* Brand */}
              {brandOptions.length > 0 && (
                <select
                  value={filters.brand || ''}
                  onChange={(e) => handleFilterChange('brand', e.target.value)}
                  className="w-full text-sm border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
                >
                  <option value="">All Brands</option>
                  {brandOptions.map(option => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              )}
            </div>
          </div>

          {/* Customer Filters */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Customer</label>
            <div className="space-y-2">
              {/* Segment */}
              <select
                value={filters.segment || ''}
                onChange={(e) => handleFilterChange('segment', e.target.value)}
                className="w-full text-sm border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
              >
                {SEGMENT_OPTIONS.map(option => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>

              {/* Loyalty Tier */}
              <select
                value={filters.loyaltyTier || ''}
                onChange={(e) => handleFilterChange('loyaltyTier', e.target.value)}
                className="w-full text-sm border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
              >
                {LOYALTY_TIER_OPTIONS.map(option => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Cohort Selection */}
          {cohortOptions.length > 0 && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Cohort</label>
              <select
                value={filters.cohort || ''}
                onChange={(e) => handleFilterChange('cohort', e.target.value)}
                className="w-full text-sm border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
              >
                <option value="">All Periods</option>
                {cohortOptions.map(option => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>
          )}
        </div>
      )}
    </div>
  );
}