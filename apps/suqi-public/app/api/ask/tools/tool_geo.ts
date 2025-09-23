// Tool adapter for geo export API
export async function runGeo(params: any) {
  const apiBase = process.env.API_BASE || 'http://localhost:3001';

  // Validate required parameters
  if (!params.level) {
    throw new Error("GEO_EXPORT requires 'level' parameter (region, city, barangay, store)");
  }

  // Set defaults for geo export
  const payload = {
    level: params.level,
    metric: params.metric || "revenue",
    filters: params.filters || {},
    timeRange: params.timeRange || {
      from: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0], // 30 days ago
      to: new Date().toISOString().split('T')[0] // today
    },
    quantiles: params.quantiles || 5,
    format: params.format || "geojson",
    ...params
  };

  try {
    // Try the geo choropleth endpoint first
    const res = await fetch(`${apiBase}/api/geo/choropleth`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-source": "ask-suqi"
      },
      body: JSON.stringify(payload)
    });

    if (!res.ok) {
      const errorText = await res.text();
      throw new Error(`GEO_EXPORT failed ${res.status}: ${errorText}`);
    }

    const result = await res.json();

    // Add metadata for chat display
    return {
      ...result,
      type: "map",
      export_params: payload,
      feature_count: result.features?.length || 0,
      bounds: calculateBounds(result.features),
      summary: generateGeoSummary(result, payload)
    };
  } catch (error) {
    console.error('Geo export error:', error);

    // Fallback: try to generate a simple response
    return {
      type: "map",
      error: error instanceof Error ? error.message : 'Unknown error',
      export_params: payload,
      feature_count: 0,
      summary: `Failed to generate ${payload.level} map for ${payload.metric}`,
      fallback: true
    };
  }
}

function calculateBounds(features: any[]): any {
  if (!features || features.length === 0) {
    return null;
  }

  let minLng = Infinity, minLat = Infinity;
  let maxLng = -Infinity, maxLat = -Infinity;

  for (const feature of features) {
    if (feature.geometry && feature.geometry.coordinates) {
      const coords = flattenCoordinates(feature.geometry.coordinates);
      for (const [lng, lat] of coords) {
        minLng = Math.min(minLng, lng);
        minLat = Math.min(minLat, lat);
        maxLng = Math.max(maxLng, lng);
        maxLat = Math.max(maxLat, lat);
      }
    }
  }

  return {
    southwest: [minLng, minLat],
    northeast: [maxLng, maxLat]
  };
}

function flattenCoordinates(coords: any[]): number[][] {
  const result: number[][] = [];

  function traverse(arr: any) {
    if (Array.isArray(arr)) {
      if (arr.length === 2 && typeof arr[0] === 'number' && typeof arr[1] === 'number') {
        result.push(arr as number[]);
      } else {
        for (const item of arr) {
          traverse(item);
        }
      }
    }
  }

  traverse(coords);
  return result;
}

function generateGeoSummary(result: any, params: any): string {
  const featureCount = result.features?.length || 0;
  const level = params.level;
  const metric = params.metric;

  if (featureCount === 0) {
    return `No ${level} boundaries found for ${metric} in the specified filters`;
  }

  const timeDesc = params.timeRange ?
    `from ${params.timeRange.from} to ${params.timeRange.to}` :
    'for the selected period';

  return `Generated ${level} choropleth with ${featureCount} boundaries showing ${metric} ${timeDesc}`;
}