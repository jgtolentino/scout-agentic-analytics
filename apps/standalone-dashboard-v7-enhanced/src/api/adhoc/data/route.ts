import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import { QuickSpec } from '@/components/AiAssistantFab';

// Initialize Supabase client
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

// Rate limiting (simple in-memory store for demo)
const rateLimitStore = new Map<string, { count: number; resetTime: number }>();
const RATE_LIMIT = 10; // requests per minute
const RATE_WINDOW = 60 * 1000; // 1 minute

function checkRateLimit(clientId: string): boolean {
  const now = Date.now();
  const clientData = rateLimitStore.get(clientId);
  
  if (!clientData || now > clientData.resetTime) {
    rateLimitStore.set(clientId, { count: 1, resetTime: now + RATE_WINDOW });
    return true;
  }
  
  if (clientData.count >= RATE_LIMIT) {
    return false;
  }
  
  clientData.count++;
  return true;
}

// SQL sanitization - basic protection
function sanitizeSQL(sql: string): string {
  // Remove dangerous keywords and patterns
  const dangerous = [
    /\b(insert|update|delete|drop|create|alter|truncate|exec|execute|sp_|xp_)\b/gi,
    /--/g,
    /\/\*.*\*\//g,
    /;\s*$/g  // Remove trailing semicolons
  ];
  
  let sanitized = sql;
  dangerous.forEach(pattern => {
    sanitized = sanitized.replace(pattern, '');
  });
  
  return sanitized.trim();
}

// Validate SQL structure
function validateSQL(sql: string): { valid: boolean; error?: string } {
  const upperSQL = sql.toUpperCase().trim();
  
  // Must start with SELECT
  if (!upperSQL.startsWith('SELECT')) {
    return { valid: false, error: 'Query must start with SELECT' };
  }
  
  // Must contain FROM scout.*
  if (!upperSQL.includes('FROM SCOUT.')) {
    return { valid: false, error: 'Query must select from scout schema' };
  }
  
  // Check for potentially dangerous patterns
  const forbidden = [
    'INFORMATION_SCHEMA',
    'PG_',
    'CURRENT_USER',
    'SESSION_USER',
    'COPY',
    'LOAD',
    'INTO OUTFILE',
    'DUMPFILE'
  ];
  
  for (const pattern of forbidden) {
    if (upperSQL.includes(pattern)) {
      return { valid: false, error: `Forbidden pattern: ${pattern}` };
    }
  }
  
  return { valid: true };
}

// Add safety limits to SQL
function addSafetyLimits(sql: string): string {
  const upperSQL = sql.toUpperCase();
  
  // Add LIMIT if not present
  if (!upperSQL.includes('LIMIT')) {
    sql += ' LIMIT 1000';
  } else {
    // Ensure LIMIT is reasonable
    const limitMatch = sql.match(/LIMIT\s+(\d+)/i);
    if (limitMatch) {
      const limit = parseInt(limitMatch[1]);
      if (limit > 1000) {
        sql = sql.replace(/LIMIT\s+\d+/i, 'LIMIT 1000');
      }
    }
  }
  
  return sql;
}

export async function POST(request: NextRequest) {
  try {
    // Get client IP for rate limiting
    const clientIP = request.headers.get('x-forwarded-for') || 
                     request.headers.get('x-real-ip') || 
                     'unknown';
    
    // Check rate limit
    if (!checkRateLimit(clientIP)) {
      return NextResponse.json(
        { error: 'Rate limit exceeded. Please try again later.' },
        { status: 429 }
      );
    }
    
    const body = await request.json();
    const { sql, spec } = body;
    
    if (!sql || typeof sql !== 'string') {
      return NextResponse.json(
        { error: 'SQL query is required' },
        { status: 400 }
      );
    }
    
    // Sanitize SQL
    const sanitizedSQL = sanitizeSQL(sql);
    
    // Validate SQL structure
    const validation = validateSQL(sanitizedSQL);
    if (!validation.valid) {
      return NextResponse.json(
        { error: 'Invalid SQL query', details: validation.error },
        { status: 400 }
      );
    }
    
    // Add safety limits
    const safeSQL = addSafetyLimits(sanitizedSQL);
    
    console.log('Executing ad-hoc query:', safeSQL);
    
    // Execute query with timeout
    const queryStart = Date.now();
    const { data, error } = await supabase
      .rpc('execute_adhoc_query', { query_sql: safeSQL })
      .timeout(30000); // 30 second timeout
    
    const queryTime = Date.now() - queryStart;
    
    if (error) {
      console.error('Supabase query error:', error);
      return NextResponse.json(
        { 
          error: 'Database query failed', 
          details: error.message,
          sql: safeSQL
        },
        { status: 500 }
      );
    }
    
    // Process and return results
    const response = {
      rows: data || [],
      rowCount: data?.length || 0,
      executionTime: queryTime,
      spec: spec || null,
      sql: safeSQL
    };
    
    return NextResponse.json(response);
    
  } catch (error) {
    console.error('Ad-hoc data API error:', error);
    
    return NextResponse.json(
      { 
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error'
      },
      { status: 500 }
    );
  }
}

// Health check endpoint
export async function GET() {
  return NextResponse.json({ 
    status: 'ok', 
    service: 'adhoc-data-api',
    timestamp: new Date().toISOString()
  });
}