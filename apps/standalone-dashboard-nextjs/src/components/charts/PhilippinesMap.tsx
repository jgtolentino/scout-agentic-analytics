'use client';

import { useMemo, useRef, useCallback, useState } from 'react';
import Map, { Source, Layer, MapRef } from 'react-map-gl';
import { useDrillHandler } from '@/lib/hooks';
import type { GeoMetric } from '@/lib/supabase/types';

interface PhilippinesMapProps {
  data: GeoMetric[];
  level: 'region' | 'province' | 'city';
  parentCode?: string;
  title?: string;
  height?: number;
  loading?: boolean;
  error?: string;
  metric?: 'value' | 'share';
  onDrill?: (level: string, code: string, name: string) => void;
  onLevelChange?: (level: string, parentCode?: string) => void;
}

const MAPBOX_TOKEN = process.env.NEXT_PUBLIC_MAPBOX_TOKEN || '';

// Simplified GeoJSON data for Philippines regions (you would load this from a file)
const PHILIPPINES_REGIONS = {
  type: 'FeatureCollection' as const,
  features: [
    {
      type: 'Feature' as const,
      properties: { code: 'NCR', name: 'National Capital Region' },
      geometry: {
        type: 'Polygon' as const,
        coordinates: [[[120.90, 14.52], [120.90, 14.76], [121.11, 14.76], [121.11, 14.52], [120.90, 14.52]]]
      }
    },
    {
      type: 'Feature' as const,
      properties: { code: 'CAR', name: 'Cordillera Administrative Region' },
      geometry: {
        type: 'Polygon' as const,
        coordinates: [[[120.40, 16.00], [120.40, 17.80], [121.50, 17.80], [121.50, 16.00], [120.40, 16.00]]]
      }
    },
    {
      type: 'Feature' as const,
      properties: { code: 'R01', name: 'Region I - Ilocos Region' },
      geometry: {
        type: 'Polygon' as const,
        coordinates: [[[119.90, 15.58], [119.90, 18.50], [120.80, 18.50], [120.80, 15.58], [119.90, 15.58]]]
      }
    },
    {
      type: 'Feature' as const,
      properties: { code: 'R02', name: 'Region II - Cagayan Valley' },
      geometry: {
        type: 'Polygon' as const,
        coordinates: [[[121.00, 16.50], [121.00, 18.80], [122.50, 18.80], [122.50, 16.50], [121.00, 16.50]]]
      }
    },
    {
      type: 'Feature' as const,
      properties: { code: 'R03', name: 'Region III - Central Luzon' },
      geometry: {
        type: 'Polygon' as const,
        coordinates: [[[119.80, 14.50], [119.80, 16.50], [121.20, 16.50], [121.20, 14.50], [119.80, 14.50]]]
      }
    },
  ]
};

export default function PhilippinesMap({
  data = [],
  level = 'region',
  parentCode,
  title = 'Geographic Distribution',
  height = 500,
  loading = false,
  error,
  metric = 'value',
  onDrill,
  onLevelChange,
}: PhilippinesMapProps) {
  const mapRef = useRef<MapRef>(null);
  const { handleDrillDown, breadcrumbs } = useDrillHandler();
  const [hoveredFeature, setHoveredFeature] = useState<string | null>(null);

  const mapData = useMemo(() => {
    if (!data?.length) return { geojson: PHILIPPINES_REGIONS, maxValue: 0, minValue: 0 };

    // Create a map of data by code
    const dataMap = data.reduce((acc, item) => {
      acc[item.code] = item;
      return acc;
    }, {} as Record<string, GeoMetric>);

    // Get value range for color scaling
    const values = data.map(item => item[metric]);
    const maxValue = Math.max(...values);
    const minValue = Math.min(...values);

    // Add data to features
    const enrichedFeatures = PHILIPPINES_REGIONS.features.map(feature => {
      const regionData = dataMap[feature.properties.code];
      return {
        ...feature,
        properties: {
          ...feature.properties,
          value: regionData?.[metric] || 0,
          share: regionData?.share || 0,
          rank: regionData?.rank || 0,
          hasData: !!regionData,
        }
      };
    });

    return {
      geojson: {
        ...PHILIPPINES_REGIONS,
        features: enrichedFeatures,
      },
      maxValue,
      minValue,
    };
  }, [data, metric]);

  const getColor = useCallback((value: number) => {
    if (mapData.maxValue === 0) return 'rgba(200, 200, 200, 0.6)';
    
    const intensity = value / mapData.maxValue;
    const red = Math.floor(255 * (1 - intensity));
    const green = Math.floor(255 * (1 - intensity * 0.5));
    const blue = 255;
    
    return `rgba(${red}, ${green}, ${blue}, 0.7)`;
  }, [mapData.maxValue]);

  const layerStyle: any = {
    id: 'regions',
    type: 'fill',
    paint: {
      'fill-color': [
        'case',
        ['==', ['get', 'hasData'], true],
        [
          'interpolate',
          ['linear'],
          ['get', metric],
          mapData.minValue, '#e3f2fd',
          mapData.maxValue, '#1976d2'
        ],
        'rgba(200, 200, 200, 0.3)'
      ],
      'fill-opacity': [
        'case',
        ['==', ['get', 'code'], hoveredFeature || ''],
        0.9,
        0.7
      ],
      'fill-outline-color': '#000000'
    }
  };

  const handleClick = useCallback((event: any) => {
    const features = event.features;
    if (features && features.length > 0) {
      const feature = features[0];
      const { code, name } = feature.properties;
      
      if (onDrill) {
        onDrill(level, code, name);
      } else {
        handleDrillDown(level, code, name);
      }
      
      // Pan to clicked feature
      if (feature.geometry && mapRef.current) {
        // Calculate bounds of the clicked feature (simplified)
        const coords = feature.geometry.coordinates[0];
        if (coords && coords.length > 0) {
          const lngs = coords.map((coord: number[]) => coord[0]);
          const lats = coords.map((coord: number[]) => coord[1]);
          const minLng = Math.min(...lngs);
          const maxLng = Math.max(...lngs);
          const minLat = Math.min(...lats);
          const maxLat = Math.max(...lats);
          
          mapRef.current.fitBounds(
            [[minLng, minLat], [maxLng, maxLat]],
            { padding: 50, duration: 1000 }
          );
        }
      }
    }
  }, [level, onDrill, handleDrillDown]);

  const handleMouseEnter = useCallback((event: any) => {
    if (event.features && event.features.length > 0) {
      setHoveredFeature(event.features[0].properties.code);
    }
  }, []);

  const handleMouseLeave = useCallback(() => {
    setHoveredFeature(null);
  }, []);

  const handleLevelUp = useCallback(() => {
    if (level === 'province' && onLevelChange) {
      onLevelChange('region');
    } else if (level === 'city' && onLevelChange) {
      onLevelChange('province', parentCode);
    }
  }, [level, parentCode, onLevelChange]);

  if (loading) {
    return (
      <div 
        className="flex items-center justify-center bg-white rounded-lg border border-gray-200"
        style={{ height }}
      >
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-500">Loading map data...</p>
        </div>
      </div>
    );
  }

  if (error || !MAPBOX_TOKEN) {
    return (
      <div 
        className="flex items-center justify-center bg-white rounded-lg border border-red-200"
        style={{ height }}
      >
        <div className="text-center text-red-600">
          <p className="font-medium">Failed to load map</p>
          <p className="text-sm mt-1">
            {error || 'Mapbox token not configured'}
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
      {/* Header with title and controls */}
      <div className="p-4 border-b border-gray-200 flex justify-between items-center">
        <div>
          <h3 className="text-lg font-medium text-gray-900">{title}</h3>
          <p className="text-sm text-gray-500 capitalize">
            {level} level {parentCode ? `(${parentCode})` : ''}
          </p>
        </div>
        
        <div className="flex items-center gap-2">
          {/* Drill up button */}
          {(level === 'province' || level === 'city') && (
            <button
              onClick={handleLevelUp}
              className="px-3 py-1 text-xs bg-blue-100 text-blue-700 rounded-md hover:bg-blue-200 transition-colors"
            >
              ← Back to {level === 'province' ? 'Regions' : 'Provinces'}
            </button>
          )}
          
          {/* Legend */}
          <div className="flex items-center gap-2 text-xs text-gray-600">
            <div className="flex items-center gap-1">
              <div className="w-3 h-3 bg-blue-200 border border-gray-300"></div>
              <span>Low</span>
            </div>
            <div className="flex items-center gap-1">
              <div className="w-3 h-3 bg-blue-700 border border-gray-300"></div>
              <span>High</span>
            </div>
          </div>
        </div>
      </div>

      {/* Map */}
      <div style={{ height: height - 80 }}>
        <Map
          ref={mapRef}
          mapboxAccessToken={MAPBOX_TOKEN}
          initialViewState={{
            longitude: 122.0,
            latitude: 13.0,
            zoom: 5.5
          }}
          style={{ width: '100%', height: '100%' }}
          mapStyle="mapbox://styles/mapbox/light-v11"
          interactiveLayerIds={['regions']}
          onClick={handleClick}
          onMouseEnter={handleMouseEnter}
          onMouseLeave={handleMouseLeave}
          cursor="pointer"
        >
          <Source id="philippines-data" type="geojson" data={mapData.geojson}>
            <Layer {...layerStyle} />
          </Source>
        </Map>
      </div>

      {/* Stats */}
      {data?.length > 0 && (
        <div className="p-4 border-t border-gray-200 bg-gray-50">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 text-sm">
            <div>
              <span className="font-medium text-gray-700">Total Areas:</span>
              <span className="ml-2 text-gray-900">{data.length}</span>
            </div>
            <div>
              <span className="font-medium text-gray-700">Highest Value:</span>
              <span className="ml-2 text-gray-900">
                {metric === 'value' 
                  ? data.reduce((max, item) => item.value > max ? item.value : max, 0).toLocaleString()
                  : `${(data.reduce((max, item) => item.share > max ? item.share : max, 0) * 100).toFixed(1)}%`
                }
              </span>
            </div>
            <div>
              <span className="font-medium text-gray-700">Top Area:</span>
              <span className="ml-2 text-gray-900">
                {data.find(item => item.rank === 1)?.name || 'N/A'}
              </span>
            </div>
            <div className="text-xs text-gray-500">
              Click on areas to drill down
            </div>
          </div>
        </div>
      )}
    </div>
  );
}