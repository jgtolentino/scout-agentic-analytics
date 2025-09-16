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

const DAYPART_OPTIONS = [
  { value: '', label: 'All Day' },
  { value: 'morning', label: 'Morning (6-12)' },
  { value: 'afternoon', label: 'Afternoon (12-18)' },
  { value: 'evening', label: 'Evening (18-24)' },
  { value: 'night', label: 'Night (0-6)' }
];

const DOW_OPTIONS = [
  { value: '', label: 'All Week' },
  { value: 'weekday', label: 'Weekdays' },
  { value: 'weekend', label: 'Weekends' }
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

const COMPARE_MODE_OPTIONS = [
  { value: 'none', label: 'No Comparison' },
  { value: 'period', label: 'Compare Periods' },
  { value: 'brand', label: 'Compare Brands' },
  { value: 'region', label: 'Compare Regions' }
];

export default function FilterBar() {
  const { 
    filters, 
    set: setFilters, 
    reset, 
    enableCompare,
    setCompareEntities,
    disableCompare,
    setHierarchicalFilter
  } = useFilterBus();

  // State for dynamic options
  const [cohortOptions, setCohortOptions] = useState([]);
  const [brandOptions, setBrandOptions] = useState([]);
  const [provinceOptions, setProvinceOptions] = useState([]);
  const [cityOptions, setCityOptions] = useState([]);
  const [showAdvanced, setShowAdvanced] = useState(false);

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

  const handleCompareMode = (mode: string) => {
    if (mode === 'none') {
      disableCompare();
    } else {
      enableCompare(mode as 'period' | 'brand' | 'region');
    }
  };

  return (
    <div className="bg-white border-b border-gray-200">
      {/* Main Filter Row */}
      <div className="px-6 py-4">
        <div className="flex flex-wrap items-center gap-4">
          <div className="flex items-center gap-2">
            <span className="text-sm font-medium text-gray-700">Filters:</span>
          </div>
          
          {/* Date Range */}
          <div className="flex items-center gap-2">
            <label htmlFor="date-filter" className="text-xs text-gray-600">Date:</label>
            <select
              id="date-filter"
              value={filters.date}
              onChange={(e) => handleFilterChange('date', e.target.value)}
              className="text-sm border border-gray-300 rounded px-2 py-1 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
            >
              {DATE_OPTIONS.map(option => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </div>

          {/* Region Hierarchy */}
          <div className="flex items-center gap-2">
            <label htmlFor="region-filter" className="text-xs text-gray-600">Region:</label>
            <select
              id="region-filter"
              value={filters.region}
              onChange={(e) => handleFilterChange('region', e.target.value)}
              className="text-sm border border-gray-300 rounded px-2 py-1 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
            >
              {REGION_OPTIONS.map(option => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </div>

          {/* Province (if region selected) */}
          {provinceOptions.length > 0 && (
            <div className="flex items-center gap-2">
              <label className="text-xs text-gray-600">Province:</label>
              <select
                value={filters.province || ''}
                onChange={(e) => handleFilterChange('province', e.target.value)}
                className="text-sm border border-gray-300 rounded px-2 py-1 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
              >
                <option value="">All Provinces</option>
                {provinceOptions.map(option => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>
          )}

          {/* City (if province selected) */}
          {cityOptions.length > 0 && (
            <div className="flex items-center gap-2">
              <label className="text-xs text-gray-600">City:</label>
              <select
                value={filters.city || ''}
                onChange={(e) => handleFilterChange('city', e.target.value)}
                className="text-sm border border-gray-300 rounded px-2 py-1 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
              >
                <option value="">All Cities</option>
                {cityOptions.map(option => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>
          )}

          {/* Category */}
          <div className="flex items-center gap-2">
            <label htmlFor="category-filter" className="text-xs text-gray-600">Category:</label>
            <select
              id="category-filter"
              value={filters.category}
              onChange={(e) => handleFilterChange('category', e.target.value)}
              className="text-sm border border-gray-300 rounded px-2 py-1 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
            >
              {CATEGORY_OPTIONS.map(option => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </div>

          {/* Brand (if category selected) */}
          {brandOptions.length > 0 && (
            <div className="flex items-center gap-2">
              <label className="text-xs text-gray-600">Brand:</label>
              <select
                value={filters.brand || ''}
                onChange={(e) => handleFilterChange('brand', e.target.value)}
                className="text-sm border border-gray-300 rounded px-2 py-1 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
              >
                <option value="">All Brands</option>
                {brandOptions.map(option => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>
          )}

          {/* Compare Mode Toggle */}
          <div className="flex items-center gap-2">
            <label className="text-xs text-gray-600">Compare:</label>
            <select
              value={filters.compareMode || 'none'}
              onChange={(e) => handleCompareMode(e.target.value)}
              className="text-sm border border-gray-300 rounded px-2 py-1 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
            >
              {COMPARE_MODE_OPTIONS.map(option => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </div>

          {/* Advanced Filters Toggle */}
          <button
            onClick={() => setShowAdvanced(!showAdvanced)}
            className="flex items-center gap-1 text-xs text-orange-600 hover:text-orange-800 px-2 py-1 rounded focus:outline-none focus:ring-2 focus:ring-orange-500"
            type="button"
          >
            <span>Advanced</span>
            <svg
              className={clsx("w-3 h-3 transition-transform", showAdvanced && "rotate-180")}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
            </svg>
          </button>

          {/* Reset Button */}
          <button
            onClick={reset}
            className="text-xs text-orange-600 hover:text-orange-800 underline ml-auto focus:outline-none focus:ring-2 focus:ring-orange-500 rounded px-2 py-1"
            type="button"
          >
            Reset All
          </button>
        </div>
      </div>

      {/* Advanced Filters Row */}
      {showAdvanced && (
        <div className="px-6 pb-4 border-t border-gray-100 pt-4">
          <div className="flex flex-wrap items-center gap-4">
            <div className="flex items-center gap-2">
              <span className="text-sm font-medium text-gray-700">Advanced:</span>
            </div>

            {/* Cohort Selection */}
            {cohortOptions.length > 0 && (
              <div className="flex items-center gap-2">
                <label className="text-xs text-gray-600">Cohort:</label>
                <select
                  value={filters.cohort || ''}
                  onChange={(e) => handleFilterChange('cohort', e.target.value)}
                  className="text-sm border border-gray-300 rounded px-2 py-1 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
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

            {/* Customer Segment */}
            <div className="flex items-center gap-2">
              <label className="text-xs text-gray-600">Segment:</label>
              <select
                value={filters.segment || ''}
                onChange={(e) => handleFilterChange('segment', e.target.value)}
                className="text-sm border border-gray-300 rounded px-2 py-1 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
              >
                {SEGMENT_OPTIONS.map(option => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>

            {/* Loyalty Tier */}
            <div className="flex items-center gap-2">
              <label className="text-xs text-gray-600">Loyalty:</label>
              <select
                value={filters.loyaltyTier || ''}
                onChange={(e) => handleFilterChange('loyaltyTier', e.target.value)}
                className="text-sm border border-gray-300 rounded px-2 py-1 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
              >
                {LOYALTY_TIER_OPTIONS.map(option => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>

            {/* Time Filters */}
            <div className="flex items-center gap-2">
              <label className="text-xs text-gray-600">Time:</label>
              <select
                value={filters.daypart || ''}
                onChange={(e) => handleFilterChange('daypart', e.target.value)}
                className="text-sm border border-gray-300 rounded px-2 py-1 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
              >
                {DAYPART_OPTIONS.map(option => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>

            <div className="flex items-center gap-2">
              <label className="text-xs text-gray-600">Days:</label>
              <select
                value={filters.dow || ''}
                onChange={(e) => handleFilterChange('dow', e.target.value)}
                className="text-sm border border-gray-300 rounded px-2 py-1 focus:outline-none focus:ring-2 focus:ring-orange-500 bg-white"
              >
                {DOW_OPTIONS.map(option => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>
          </div>
        </div>
      )}

      {/* Comparison Panel (when compare mode is active) */}
      {filters.compareMode && filters.compareMode !== 'none' && (
        <div className="px-6 pb-4 bg-orange-50 border-t border-orange-200">
          <div className="flex items-center gap-4 py-3">
            <span className="text-sm font-medium text-orange-800">
              Comparing {filters.compareMode === 'brand' ? 'Brands' : filters.compareMode === 'region' ? 'Regions' : 'Periods'}:
            </span>
            
            {filters.compareMode === 'brand' && (
              <>
                <select
                  value={filters.compareBrandA || ''}
                  onChange={(e) => handleFilterChange('compareBrandA', e.target.value)}
                  className="text-sm border border-orange-300 rounded px-2 py-1 bg-white focus:outline-none focus:ring-2 focus:ring-orange-500"
                >
                  <option value="">Select Brand A</option>
                  {brandOptions.map(option => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
                <span className="text-orange-600">vs</span>
                <select
                  value={filters.compareBrandB || ''}
                  onChange={(e) => handleFilterChange('compareBrandB', e.target.value)}
                  className="text-sm border border-orange-300 rounded px-2 py-1 bg-white focus:outline-none focus:ring-2 focus:ring-orange-500"
                >
                  <option value="">Select Brand B</option>
                  {brandOptions.map(option => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </>
            )}

            {filters.compareMode === 'region' && (
              <>
                <select
                  value={filters.compareRegionA || ''}
                  onChange={(e) => handleFilterChange('compareRegionA', e.target.value)}
                  className="text-sm border border-orange-300 rounded px-2 py-1 bg-white focus:outline-none focus:ring-2 focus:ring-orange-500"
                >
                  <option value="">Select Region A</option>
                  {REGION_OPTIONS.map(option => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
                <span className="text-orange-600">vs</span>
                <select
                  value={filters.compareRegionB || ''}
                  onChange={(e) => handleFilterChange('compareRegionB', e.target.value)}
                  className="text-sm border border-orange-300 rounded px-2 py-1 bg-white focus:outline-none focus:ring-2 focus:ring-orange-500"
                >
                  <option value="">Select Region B</option>
                  {REGION_OPTIONS.map(option => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </>
            )}

            {filters.compareMode === 'period' && (
              <div className="text-sm text-orange-700">
                Comparing current period vs previous period
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}