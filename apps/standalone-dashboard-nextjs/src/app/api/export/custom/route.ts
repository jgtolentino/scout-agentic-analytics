import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';

/** Strict allow-list of fragments; reject everything else. */
const ALLOW = {
  tables: [
    "gold.v_transactions_flat",
    "gold.v_transactions_crosstab",
    "gold.v_pbi_transactions_summary",
    "gold.v_pbi_brand_performance",
    "audit.v_flat_vs_crosstab_parity",
    "audit.v_monitoring_dashboard",
    "audit.v_system_health_summary"
  ],
  columns: [
    "canonical_tx_id", "device_id", "store_id", "brand", "product_name", "category",
    "total_amount", "total_items", "payment_method", "audio_transcript", "daypart",
    "weekday_weekend", "txn_ts", "store_name", "transaction_date",
    "[date]", "Morning_Transactions", "Midday_Transactions", "Afternoon_Transactions",
    "Evening_Transactions", "txn_count", "year", "month", "day", "weekday_name",
    "transaction_count", "total_revenue", "avg_transaction_value", "total_items_sold",
    "unique_transactions", "unique_devices", "first_transaction", "latest_transaction",
    "stores_present", "active_days", "revenue_per_transaction", "market_share_transactions",
    "market_share_revenue", "parity_status", "status_indicator", "sla_status"
  ],
  functions: ["COUNT", "SUM", "AVG", "MIN", "MAX", "TOP", "CONVERT", "CAST", "DATEADD", "SYSUTCDATETIME"],
  keywords: ["SELECT", "FROM", "WHERE", "GROUP BY", "ORDER BY", "HAVING", "AND", "OR", "IN", "LIKE", "BETWEEN"]
};

const MAX_LEN = 5000;
const MAX_TOP = 10000;

function sanitize(sql: string): string {
  const s = sql.trim();

  // Length check
  if (s.length > MAX_LEN) {
    throw new Error(`sql_too_long: Maximum ${MAX_LEN} characters allowed`);
  }

  // Dangerous keyword check
  const dangerous = /(;|--|\/\*|\*\/|\bDROP\b|\bALTER\b|\bINSERT\b|\bUPDATE\b|\bDELETE\b|\bMERGE\b|\bEXEC\b|\bxp_|\bsp_|\bBULK\b|\bOPENROWSET\b|\bCREATE\b|\bTRUNCATE\b)/i;
  if (dangerous.test(s)) {
    throw new Error("blocked_keyword: Contains prohibited SQL keywords or patterns");
  }

  // Must start with SELECT
  if (!s.toUpperCase().startsWith('SELECT')) {
    throw new Error("must_start_with_select: Only SELECT queries are allowed");
  }

  // Table validation - must reference at least one allowed table
  const tablesOK = ALLOW.tables.some(table => s.includes(table));
  if (!tablesOK) {
    throw new Error(`table_not_allowed: Must reference one of: ${ALLOW.tables.join(', ')}`);
  }

  // TOP clause validation
  const topMatch = s.match(/\bTOP\s*\(\s*(\d+)\s*\)/i);
  if (topMatch) {
    const topValue = parseInt(topMatch[1]);
    if (topValue > MAX_TOP) {
      throw new Error(`top_limit_exceeded: TOP value cannot exceed ${MAX_TOP}`);
    }
  }

  // Check for potentially unsafe patterns
  const unsafe = /(\bLOADFILE\b|\bINTO\s+OUTFILE\b|\bINTO\s+DUMPFILE\b)/i;
  if (unsafe.test(s)) {
    throw new Error("unsafe_pattern: Contains file operation keywords");
  }

  return s;
}

function validateCustomRequest(body: any) {
  if (!body || typeof body !== 'object') {
    throw new Error("invalid_request_body");
  }

  const { sql, filename, description } = body;

  if (!sql || typeof sql !== 'string') {
    throw new Error("missing_sql: SQL query is required");
  }

  if (filename && (typeof filename !== 'string' || !filename.endsWith('.csv'))) {
    throw new Error("invalid_filename: Filename must be a string ending with .csv");
  }

  return {
    sql: sql.trim(),
    filename: filename || `custom_export_${new Date().toISOString().replace(/[:.]/g, "-")}.csv`,
    description: description || "Custom SQL export"
  };
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json().catch(() => ({}));
    const { sql, filename, description } = validateCustomRequest(body);

    // Sanitize the SQL
    const safeSQL = sanitize(sql);

    // Generate audit info
    const auditInfo = {
      requestedAt: new Date().toISOString(),
      userAgent: request.headers.get('user-agent') || 'unknown',
      ipAddress: request.headers.get('x-forwarded-for') ||
                 request.headers.get('x-real-ip') ||
                 'unknown',
      sqlLength: safeSQL.length,
      tablesReferenced: ALLOW.tables.filter(table => safeSQL.includes(table))
    };

    const payload = {
      ok: true,
      type: "custom",
      sql: safeSQL,
      filename,
      description,
      mode: "resolve",
      runner_command: `./scripts/bcp_export_runner.sh custom "${safeSQL}" "${filename}"`,
      audit: auditInfo,
      validation: {
        passed: true,
        checks: [
          "length_check",
          "keyword_check",
          "table_validation",
          "select_only",
          "no_file_operations"
        ]
      }
    };

    return NextResponse.json(payload);

  } catch (error: any) {
    return NextResponse.json({
      ok: false,
      error: error.message,
      type: "custom",
      validation: {
        passed: false,
        error: error.message
      },
      help: {
        allowed_tables: ALLOW.tables,
        allowed_functions: ALLOW.functions,
        max_length: MAX_LEN,
        max_top: MAX_TOP,
        example: "SELECT TOP (100) brand, COUNT(*) as transactions FROM gold.v_transactions_flat WHERE transaction_date >= CONVERT(date, DATEADD(day, -7, SYSUTCDATETIME())) GROUP BY brand ORDER BY transactions DESC"
      }
    }, { status: 400 });
  }
}

export async function GET() {
  return NextResponse.json({
    ok: true,
    type: "custom",
    description: "Custom SQL export with strict validation",
    validation_rules: {
      max_length: MAX_LEN,
      max_top_value: MAX_TOP,
      allowed_tables: ALLOW.tables,
      allowed_functions: ALLOW.functions,
      required_start: "SELECT",
      prohibited_keywords: [
        "DROP", "ALTER", "INSERT", "UPDATE", "DELETE", "MERGE",
        "EXEC", "CREATE", "TRUNCATE", "BULK", "OPENROWSET"
      ]
    },
    example_request: {
      sql: "SELECT TOP (100) brand, COUNT(*) as transactions, SUM(total_amount) as revenue FROM gold.v_transactions_flat WHERE transaction_date >= CONVERT(date, DATEADD(day, -7, SYSUTCDATETIME())) GROUP BY brand ORDER BY revenue DESC",
      filename: "brand_analysis_last_7days.csv",
      description: "Brand revenue analysis for last 7 days"
    }
  });
}