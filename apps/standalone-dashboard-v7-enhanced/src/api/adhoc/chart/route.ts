import { NextRequest, NextResponse } from 'next/server';
import { QuickSpec, ChartResponse } from '@/components/AiAssistantFab';

// Whitelisted dimensions and measures for safety
const ALLOWED_DIMENSIONS = {
  'time': ['date_day', 'date_month', 'date_quarter', 'date_year', 'weekday', 'weekend_flag', 'tod_segment'],
  'location': ['region', 'province', 'city', 'barangay', 'region_name', 'province_name', 'city_name', 'barangay_name'],
  'product': ['category', 'brand', 'sku', 'category_name', 'brand_name', 'sku_name'],
  'consumer': ['gender', 'age_bracket', 'gender_code', 'age_code']
};

const ALLOWED_MEASURES = [
  'txn_count', 'peso_value', 'total_units', 'avg_basket_value', 
  'duration_seconds', 'units_per_txn', 'accept_suggestion_rate'
];

const CHART_TEMPLATES = {
  line: (spec: QuickSpec) => `
    SELECT 
      ${spec.x} as x_value,
      ${spec.series ? `${spec.series} as series_value,` : ''}
      ${spec.agg}(${spec.y}) as y_value
    FROM scout.fact_transactions t
    JOIN scout.dim_time tm ON tm.time_id = t.time_id
    JOIN scout.dim_location l ON l.location_id = t.location_id
    LEFT JOIN scout.dim_product p ON p.product_id = t.product_id
    LEFT JOIN scout.dim_consumer c ON c.consumer_id = t.consumer_id
    WHERE tm.date_day >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY ${spec.x}${spec.series ? `, ${spec.series}` : ''}
    ORDER BY ${spec.x}
    ${spec.topK ? `LIMIT ${spec.topK}` : ''}
  `,
  
  bar: (spec: QuickSpec) => `
    SELECT 
      ${spec.x} as x_value,
      ${spec.series ? `${spec.series} as series_value,` : ''}
      ${spec.agg}(${spec.y}) as y_value
    FROM scout.fact_transactions t
    JOIN scout.dim_time tm ON tm.time_id = t.time_id
    JOIN scout.dim_location l ON l.location_id = t.location_id
    LEFT JOIN scout.dim_product p ON p.product_id = t.product_id
    LEFT JOIN scout.dim_consumer c ON c.consumer_id = t.consumer_id
    WHERE tm.date_day >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY ${spec.x}${spec.series ? `, ${spec.series}` : ''}
    ORDER BY y_value DESC
    ${spec.topK ? `LIMIT ${spec.topK}` : ''}
  `,
  
  pie: (spec: QuickSpec) => `
    SELECT 
      ${spec.x} as x_value,
      ${spec.agg}(${spec.y}) as y_value
    FROM scout.fact_transactions t
    JOIN scout.dim_time tm ON tm.time_id = t.time_id
    JOIN scout.dim_location l ON l.location_id = t.location_id
    LEFT JOIN scout.dim_product p ON p.product_id = t.product_id
    LEFT JOIN scout.dim_consumer c ON c.consumer_id = t.consumer_id
    WHERE tm.date_day >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY ${spec.x}
    ORDER BY y_value DESC
    ${spec.topK ? `LIMIT ${spec.topK}` : ''}
  `,
  
  table: (spec: QuickSpec) => `
    SELECT 
      ${spec.x} as x_value,
      ${spec.y ? `${spec.agg}(${spec.y}) as y_value,` : ''}
      COUNT(*) as row_count
    FROM scout.fact_transactions t
    JOIN scout.dim_time tm ON tm.time_id = t.time_id
    JOIN scout.dim_location l ON l.location_id = t.location_id
    LEFT JOIN scout.dim_product p ON p.product_id = t.product_id
    LEFT JOIN scout.dim_consumer c ON c.consumer_id = t.consumer_id
    WHERE tm.date_day >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY ${spec.x}
    ORDER BY ${spec.y ? 'y_value' : 'row_count'} DESC
    ${spec.topK ? `LIMIT ${spec.topK}` : 'LIMIT 50'}
  `
};

function parseNaturalLanguageQuery(prompt: string): Partial<QuickSpec> {
  const spec: Partial<QuickSpec> = {
    schema: 'QuickSpec@1',
    agg: 'sum',
    chart: 'bar',
    topK: 10
  };
  
  const lowerPrompt = prompt.toLowerCase();
  
  // Chart type detection
  if (lowerPrompt.includes('trend') || lowerPrompt.includes('over time') || lowerPrompt.includes('timeline')) {
    spec.chart = 'line';
    spec.x = 'tm.date_day';
  } else if (lowerPrompt.includes('share') || lowerPrompt.includes('distribution') || lowerPrompt.includes('breakdown')) {
    spec.chart = 'pie';
  } else if (lowerPrompt.includes('table') || lowerPrompt.includes('list')) {
    spec.chart = 'table';
  }
  
  // Dimension detection
  if (lowerPrompt.includes('brand')) {
    spec.x = 'b.brand_name';
  } else if (lowerPrompt.includes('category')) {
    spec.x = 'c.category_name';
  } else if (lowerPrompt.includes('region')) {
    spec.x = 'l.region_name';
  } else if (lowerPrompt.includes('city')) {
    spec.x = 'l.city_name';
  } else if (lowerPrompt.includes('province')) {
    spec.x = 'l.province_name';
  } else if (lowerPrompt.includes('gender')) {
    spec.x = 'cons.gender_code';
  } else if (lowerPrompt.includes('age')) {
    spec.x = 'cons.age_code';
  } else if (lowerPrompt.includes('day') || lowerPrompt.includes('date')) {
    spec.x = 'tm.date_day';
  }
  
  // Measure detection
  if (lowerPrompt.includes('revenue') || lowerPrompt.includes('peso') || lowerPrompt.includes('sales') || lowerPrompt.includes('value')) {
    spec.y = 't.peso_value';
  } else if (lowerPrompt.includes('units') || lowerPrompt.includes('quantity')) {
    spec.y = 't.total_units';
  } else if (lowerPrompt.includes('transactions') || lowerPrompt.includes('count')) {
    spec.y = '*';
    spec.agg = 'count';
  } else {
    spec.y = 't.peso_value'; // default
  }
  
  // Aggregation detection
  if (lowerPrompt.includes('average') || lowerPrompt.includes('avg')) {
    spec.agg = 'avg';
  } else if (lowerPrompt.includes('count') || lowerPrompt.includes('number of')) {
    spec.agg = 'count';
  } else if (lowerPrompt.includes('max') || lowerPrompt.includes('maximum')) {
    spec.agg = 'max';
  } else if (lowerPrompt.includes('min') || lowerPrompt.includes('minimum')) {
    spec.agg = 'min';
  }
  
  // Time period detection
  if (lowerPrompt.includes('last 7 days') || lowerPrompt.includes('past week')) {
    // Will be handled in SQL generation
  } else if (lowerPrompt.includes('last 28 days') || lowerPrompt.includes('past month')) {
    // Default is already 30 days
  } else if (lowerPrompt.includes('yesterday')) {
    // Custom time filter
  }
  
  // Top K detection
  const topMatch = lowerPrompt.match(/top (\d+)/);
  if (topMatch) {
    spec.topK = parseInt(topMatch[1]);
  }
  
  return spec;
}

function validateSpec(spec: QuickSpec): { valid: boolean; errors: string[] } {
  const errors: string[] = [];
  
  // Validate chart type
  if (!Object.keys(CHART_TEMPLATES).includes(spec.chart)) {
    errors.push(`Unsupported chart type: ${spec.chart}`);
  }
  
  // Validate aggregation
  if (!['sum', 'count', 'avg', 'min', 'max'].includes(spec.agg)) {
    errors.push(`Unsupported aggregation: ${spec.agg}`);
  }
  
  // Basic SQL injection protection
  const sqlPattern = /(\b(select|insert|update|delete|drop|create|alter|exec|union|script)\b)/i;
  if (spec.x && sqlPattern.test(spec.x)) {
    errors.push('Invalid characters in x dimension');
  }
  if (spec.y && sqlPattern.test(spec.y)) {
    errors.push('Invalid characters in y dimension');
  }
  
  return {
    valid: errors.length === 0,
    errors
  };
}

function generateSQL(spec: QuickSpec): string {
  const template = CHART_TEMPLATES[spec.chart as keyof typeof CHART_TEMPLATES];
  if (!template) {
    throw new Error(`No template for chart type: ${spec.chart}`);
  }
  
  return template(spec).trim();
}

function generateExplanation(spec: QuickSpec, prompt: string): string {
  const chartType = spec.chart.charAt(0).toUpperCase() + spec.chart.slice(1);
  const agg = spec.agg.toUpperCase();
  
  let explanation = `${chartType} chart showing ${agg}(${spec.y || 'records'})`;
  
  if (spec.x) {
    explanation += ` by ${spec.x}`;
  }
  
  if (spec.series) {
    explanation += `, split by ${spec.series}`;
  }
  
  if (spec.topK) {
    explanation += `, limited to top ${spec.topK} results`;
  }
  
  explanation += '. Based on Scout transaction data from the last 30 days.';
  
  return explanation;
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { prompt, filters = {}, context = {} } = body;
    
    if (!prompt || typeof prompt !== 'string') {
      return NextResponse.json(
        { error: 'Prompt is required and must be a string' },
        { status: 400 }
      );
    }
    
    // Parse natural language to spec
    const parsedSpec = parseNaturalLanguageQuery(prompt);
    
    // Complete the spec with defaults
    const spec: QuickSpec = {
      schema: 'QuickSpec@1',
      chart: 'bar',
      agg: 'sum',
      topK: 10,
      ...parsedSpec
    };
    
    // Validate the spec
    const validation = validateSpec(spec);
    if (!validation.valid) {
      return NextResponse.json(
        { error: 'Invalid chart specification', details: validation.errors },
        { status: 400 }
      );
    }
    
    // Generate SQL
    const sql = generateSQL(spec);
    
    // Generate explanation
    const explain = generateExplanation(spec, prompt);
    
    const response: ChartResponse = {
      spec,
      sql,
      explain
    };
    
    return NextResponse.json(response);
    
  } catch (error) {
    console.error('Ad-hoc chart generation error:', error);
    
    return NextResponse.json(
      { 
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error'
      },
      { status: 500 }
    );
  }
}