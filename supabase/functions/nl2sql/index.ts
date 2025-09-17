/**
 * Scout v7 NL→SQL Cross-Tab Analytics Engine
 * Safe SQL generation from validated plans and natural language
 * Never accepts raw SQL from LLM - builds from whitelisted catalog
 */

// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as z from "https://esm.sh/zod@3";
import yaml from "https://esm.sh/js-yaml@4";
import { encode as b64 } from "https://deno.land/std@0.223.0/encoding/base64.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { auth: { persistSession: false }});

// Load semantic catalog
const catalogText = await (await fetch(new URL("./catalog.yml", import.meta.url))).text();
const CATALOG = yaml.load(catalogText) as any;

// Plan validation schema
const Plan = z.object({
  intent: z.enum(["aggregate","crosstab"]),
  rows: z.array(z.string()).max(2).default([]),
  cols: z.array(z.string()).max(1).default([]),
  measures: z.array(z.object({ metric: z.string() })).min(1),
  filters: z.object({
    date_from: z.string().optional(),
    date_to:   z.string().optional(),
    brand_in:  z.array(z.string()).optional(),
    category_in: z.array(z.string()).optional(),
    is_weekend: z.boolean().optional()
  }).default({}),
  pivot: z.boolean().default(true),
  limit: z.number().int().min(1).max(10000).default(5000)
});

type ValidatedPlan = z.infer<typeof Plan>;

// Helper functions
function canonicalize(key: string): string {
  return CATALOG.synonyms?.[key?.toLowerCase?.()] ?? key;
}

function mapDimension(key: string): { key: string; expr: string } {
  const dimension = CATALOG.dimensions[key];
  if (!dimension) throw new Error(`Unknown dimension: ${key}`);
  return { key, expr: dimension.expr };
}

function mapMetric(key: string): { key: string; expr: string } {
  const metric = CATALOG.metrics[key];
  if (!metric) throw new Error(`Unknown metric: ${key}`);
  return { key, expr: metric.expr };
}

// Safe SQL builder (never accepts raw SQL)
function buildSQL(plan: ValidatedPlan): { sql: string; params: string[] } {
  const rows = plan.rows.map(canonicalize).map(mapDimension);
  const cols = plan.cols.map(canonicalize).map(mapDimension);
  const metrics = plan.measures.map(m => mapMetric(canonicalize(m.metric)));

  if (rows.length + cols.length < 1) {
    throw new Error("At least one dimension required");
  }

  const allDims = [...rows, ...cols];

  // Build WHERE clause with parameterized queries
  const whereConditions: string[] = [];
  const params: string[] = [];
  let paramIndex = 1;

  if (plan.filters.date_from) {
    whereConditions.push(`sut.ts >= $${paramIndex++}`);
    params.push(plan.filters.date_from);
  }
  if (plan.filters.date_to) {
    whereConditions.push(`sut.ts < $${paramIndex++}`);
    params.push(plan.filters.date_to);
  }
  if (plan.filters.is_weekend !== undefined) {
    whereConditions.push(`${CATALOG.dimensions.is_weekend.expr} = $${paramIndex++}`);
    params.push(String(plan.filters.is_weekend));
  }
  if (plan.filters.brand_in?.length) {
    whereConditions.push(`sut.brand = ANY($${paramIndex++})`);
    params.push(`{${plan.filters.brand_in.map(v => `"${v.replaceAll('"','""')}"`).join(',')}}`);
  }
  if (plan.filters.category_in?.length) {
    whereConditions.push(`sut.product_category = ANY($${paramIndex++})`);
    params.push(`{${plan.filters.category_in.map(v => `"${v.replaceAll('"','""')}"`).join(',')}}`);
  }

  const whereClause = whereConditions.length ? `WHERE ${whereConditions.join(" AND ")}` : "";

  // Build SELECT clause
  const selectDims = allDims.map(d => `${d.expr} AS "${d.key}"`).join(", ");
  const groupDims = allDims.map((_, i) => i + 1).join(", ");
  const selectMetrics = metrics.map(m => `${m.expr} AS "${m.key}"`).join(", ");

  // Base SQL (long format)
  const baseSQL = `
    SELECT ${selectDims}, ${selectMetrics}
    FROM ${Object.keys(CATALOG.tables)[0]} sut
    ${whereClause}
    GROUP BY ${groupDims}
    ORDER BY ${groupDims}
    LIMIT ${plan.limit}
  `.trim();

  // Optional pivot for single column dimension
  let finalSQL = baseSQL;
  if (plan.pivot && cols.length === 1 && rows.length > 0) {
    const colKey = cols[0].key;
    const firstMetric = metrics[0].key;
    finalSQL = `
      WITH base AS (${baseSQL})
      SELECT ${rows.map(r => `"${r.key}"`).join(", ")},
             json_object_agg("${colKey}", "${firstMetric}") AS "_pivot"
      FROM base
      GROUP BY ${rows.map(r => `"${r.key}"`).join(", ")}
      ORDER BY ${rows.map(r => `"${r.key}"`).join(", ")}
    `.trim();
  }

  return { sql: finalSQL, params };
}

// Cache key generation
function generateCacheKey(plan: ValidatedPlan, params: string[]): string {
  const payload = { plan, params, version: "v1" };
  return b64(new TextEncoder().encode(JSON.stringify(payload))).slice(0, 64);
}

// Execute SQL via safe RPC
async function executeSQL(sql: string, params: string[]): Promise<any[]> {
  const { data, error } = await sb.rpc("exec_readonly_sql", {
    sql_text: sql,
    params
  });

  if (error) {
    throw new Error(`SQL execution failed: ${error.message}`);
  }

  return data || [];
}

// Simple NL → Plan mapping (extend with LLM integration)
function parseNaturalLanguage(question: string): ValidatedPlan {
  const q = question.toLowerCase();

  // Common patterns
  if (q.includes("time") && q.includes("category")) {
    return Plan.parse({
      intent: "crosstab",
      rows: ["daypart"],
      cols: ["product_category"],
      measures: [{ metric: "txn_count" }],
      filters: {},
      pivot: true
    });
  }

  if (q.includes("basket") && q.includes("payment")) {
    return Plan.parse({
      intent: "aggregate",
      rows: ["payment_method"],
      cols: [],
      measures: [{ metric: "avg_basket" }],
      filters: {},
      pivot: false
    });
  }

  if (q.includes("brand") && q.includes("weekend")) {
    return Plan.parse({
      intent: "aggregate",
      rows: ["brand", "is_weekend"],
      cols: [],
      measures: [{ metric: "revenue" }],
      filters: {},
      pivot: false
    });
  }

  // Default fallback
  return Plan.parse({
    intent: "aggregate",
    rows: ["brand"],
    cols: [],
    measures: [{ metric: "revenue" }],
    filters: {},
    pivot: false
  });
}

// Main Edge Function handler
Deno.serve(async (req) => {
  const startTime = performance.now();
  let cacheHit = false;
  let rowCount = 0;
  let sql = "";
  let plan: ValidatedPlan | null = null;
  let question = "";
  let error: string | null = null;

  try {
    // Parse request
    const body = await req.json();
    question = body.question ?? "";

    // Generate or validate plan
    if (body.plan) {
      plan = Plan.parse(body.plan);
    } else if (question) {
      plan = parseNaturalLanguage(question);
    } else {
      throw new Error("Either 'question' or 'plan' is required");
    }

    // Build SQL from validated plan
    const { sql: generatedSQL, params } = buildSQL(plan);
    sql = generatedSQL;

    // Check cache first
    const cacheKey = generateCacheKey(plan, params);
    const cached = await sb.rpc("cache_get", { p_hash: cacheKey }).catch(() => ({ data: null }));

    let rows = cached?.data;
    if (rows) {
      cacheHit = true;
      rowCount = Array.isArray(rows) ? rows.length : 0;
    } else {
      // Execute query
      rows = await executeSQL(sql, params);
      rowCount = Array.isArray(rows) ? rows.length : 0;

      // Cache result (300 seconds for Silver data)
      await sb.rpc("cache_put", {
        p_hash: cacheKey,
        p_payload: rows,
        p_ttl_seconds: 300
      }).catch(() => {}); // Ignore cache errors
    }

    // Return successful response
    return new Response(JSON.stringify({
      plan,
      sql,
      rows,
      cache_hit: cacheHit
    }), {
      headers: { "content-type": "application/json" },
      status: 200
    });

  } catch (e) {
    error = String(e?.message ?? e);
    return new Response(JSON.stringify({
      error,
      plan,
      sql,
      cache_hit: cacheHit
    }), {
      headers: { "content-type": "application/json" },
      status: 400
    });

  } finally {
    // Audit logging (fire and forget)
    const duration = Math.round(performance.now() - startTime);
    sb.from("ai_sql_audit").insert({
      question,
      plan,
      sql_text: sql,
      duration_ms: duration,
      row_count: rowCount,
      cache_hit: cacheHit,
      error,
      function_version: "v2_crosstab"
    }).catch(() => {}); // Ignore audit errors
  }
});