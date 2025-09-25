import { getPool, withTenantContext } from "./sql";
import type { SectionKey } from "../types";
import sql from "mssql";

// Helpers
const safeDate = (v?: string) => (v ? new Date(v) : undefined);
const firstDay = (dt = new Date()) => new Date(dt.getFullYear(), dt.getMonth(), 1);
const nowIso = () => new Date().toISOString();

type CommonParams = {
  from?: string;
  to?: string;
  brands?: string;     // CSV
  stores?: string;     // CSV of store_id
  page?: string;       // for transactions
  pageSize?: string;
  category?: string;   // Category filter
  age_group?: string;  // Demographics filter
  gender?: string;     // Demographics filter
  region?: string;     // Geographic filter
  payment_method?: string; // Payment filter
  product_id?: string; // For basket recommendations
  level?: string;      // Geographic level: region, province, city, barangay
};

export async function resolveSection(section: SectionKey, params: CommonParams) {
  switch (section) {
    case "kpis": return kpis(params);
    case "brands": return brands(params);
    case "compare": return compare(params);
    case "transactions": return transactions(params);
    case "storesGeo": return storesGeo(params);
    case "health": return health();

    // Enhanced Analytics Endpoints
    case "demographics": return demographics(params);
    case "tobacco": return tobaccoAnalytics(params);
    case "laundry": return laundryAnalytics(params);
    case "substitutions": return substitutionAnalytics(params);
    case "basket": return basketAnalytics(params);
    case "completion": return completionFunnel(params);
    case "geographic": return geographicAnalytics(params);
    case "pecha": return pechaAnalysis(params);
    case "dayparting": return daypartingAnalysis(params);
    case "recommendations": return frequentlyBoughtTogether(params);
    case "storeProfiles": return storeProfiles(params);
  }
}

// ---- Sections ----

async function kpis(q: CommonParams) {
  if (process.env.DAL_MODE === "mock") {
    return [
      { label: "Revenue", value: 12500000, fmt: "currency" },
      { label: "Transactions", value: 18234, fmt: "int" },
      { label: "Avg Basket", value: 2.7, fmt: "decimal" }
    ];
  }
  const pool = await getPool()!;
  await withTenantContext(pool, process.env.TENANT_CODE);

  const from = safeDate(q.from) ?? firstDay();
  const to = safeDate(q.to) ?? new Date();

  const res = await pool.request()
    .input("from", sql.DateTime2, from)
    .input("to", sql.DateTime2, to)
    .query(`
      SELECT
        SUM(peso_value) as revenue,
        COUNT(*) as txns,
        AVG(peso_value*1.0) as avg_basket
      FROM gold.scout_dashboard_transactions
      WHERE timestamp BETWEEN @from AND @to;
    `);

  const row = res.recordset[0] || {};
  return [
    { label: "Revenue", value: Number(row.revenue || 0), fmt: "currency" },
    { label: "Transactions", value: Number(row.txns || 0), fmt: "int" },
    { label: "Avg Basket", value: Number(row.avg_basket || 0), fmt: "decimal" }
  ];
}

async function brands(q: CommonParams) {
  if (process.env.DAL_MODE === "mock") {
    return {
      items: [
        { brand_name: "Alaska", is_owned: 1, revenue: 1000000, transactions: 1200, market_share: 0.18 },
        { brand_name: "Coca-Cola", is_owned: 0, revenue: 850000, transactions: 980, market_share: 0.15 }
      ],
      summary: { total_revenue: 5500000 }
    };
  }
  const pool = await getPool()!;
  await withTenantContext(pool, process.env.TENANT_CODE);

  const from = safeDate(q.from) ?? firstDay();
  const to = safeDate(q.to) ?? new Date();

  const res = await pool.request()
    .input("from", sql.DateTime2, from)
    .input("to", sql.DateTime2, to)
    .query(`
      ;WITH brand_agg AS (
        SELECT
          COALESCE(brand_name, 'Unknown') AS brand_name,
          SUM(peso_value) AS revenue,
          COUNT(*) AS transactions
        FROM gold.scout_dashboard_transactions
        WHERE timestamp BETWEEN @from AND @to
          AND brand_name IS NOT NULL
        GROUP BY brand_name
      )
      SELECT
        b.brand_name,
        CAST(CASE WHEN br.is_owned = 1 THEN 1 ELSE 0 END AS bit) AS is_owned,
        b.revenue,
        b.transactions,
        CAST(b.revenue / NULLIF(SUM(b.revenue) OVER(),0) AS float) AS market_share
      FROM brand_agg b
      LEFT JOIN dbo.brands_ref br ON br.brand_name = b.brand_name
      ORDER BY b.revenue DESC;
    `);

  const items = res.recordset;
  const total_revenue = items.reduce((s: number, r: any) => s + Number(r.revenue || 0), 0);
  return { items, summary: { total_revenue } };
}

async function compare(q: CommonParams) {
  if (process.env.DAL_MODE === "mock") {
    return {
      pairs: [
        { brand: "Alaska", revenue: 1000000, txns: 1200 },
        { brand: "Coca-Cola", revenue: 850000, txns: 980 }
      ],
      insights: ["Alaska leads revenue by 17.6% over Coca-Cola in the selected period."]
    };
  }
  const pool = await getPool()!;
  await withTenantContext(pool, process.env.TENANT_CODE);

  const from = safeDate(q.from) ?? firstDay();
  const to = safeDate(q.to) ?? new Date();
  const brandList = (q.brands || "").split(",").map(s => s.trim()).filter(Boolean);

  if (brandList.length === 0) {
    return { pairs: [], insights: ["No brands specified. Add ?brands=BrandA,BrandB"] };
  }

  const table = brandList.map((b, i) => `SELECT ${i} ord, @from as f, @to as t, @b${i} as brand`).join(" UNION ALL ");
  const req = pool.request().input("from", sql.DateTime2, from).input("to", sql.DateTime2, to);
  brandList.forEach((b, i) => req.input(`b${i}`, sql.NVarChar(200), b));

  const res = await req.query(`
    WITH sel AS (${table})
    SELECT s.brand,
           SUM(t.peso_value) as revenue,
           COUNT(*) as txns
    FROM sel s
    LEFT JOIN gold.scout_dashboard_transactions t
      ON t.timestamp BETWEEN s.f AND s.t
     AND t.brand_name = s.brand
    GROUP BY s.brand
    ORDER BY MIN(s.ord);
  `);

  const pairs = res.recordset;
  const insights: string[] = [];
  if (pairs.length >= 2) {
    const [a, b] = pairs;
    const diff = Number(a.revenue || 0) - Number(b.revenue || 0);
    if (!isNaN(diff)) insights.push(`${a.brand} ${(diff>=0) ? "leads" : "trails"} ${b.brand} by ${Math.abs(diff).toLocaleString()} in revenue.`);
  }
  return { pairs, insights };
}

async function transactions(q: CommonParams) {
  if (process.env.DAL_MODE === "mock") {
    return { items: [{ canonical_tx_id: "abc", amount: 99.5 }], page: 1, pageSize: 50, total: 1 };
  }
  const pool = await getPool()!;
  await withTenantContext(pool, process.env.TENANT_CODE);

  const page = Math.max(1, parseInt(q.page || "1", 10));
  const pageSize = Math.min(200, Math.max(1, parseInt(q.pageSize || "50", 10)));
  const offset = (page - 1) * pageSize;

  const res = await pool.request()
    .input("from", sql.DateTime2, safeDate(q.from) ?? firstDay())
    .input("to", sql.DateTime2, safeDate(q.to) ?? new Date())
    .input("offset", sql.Int, offset)
    .input("limit", sql.Int, pageSize)
    .query(`
      WITH base AS (
        SELECT t.id as canonical_tx_id, t.peso_value as amount, t.timestamp as transaction_timestamp,
               t.store_id, t.brand_name, t.product_category,
               ROW_NUMBER() OVER (ORDER BY t.timestamp DESC) rn
        FROM gold.scout_dashboard_transactions t
        WHERE t.timestamp BETWEEN @from AND @to
      )
      SELECT * FROM base WHERE rn BETWEEN @offset+1 AND @offset+@limit
      ORDER BY rn;
    `);

  return { items: res.recordset, page, pageSize };
}

async function storesGeo(q: CommonParams) {
  if (process.env.DAL_MODE === "mock") {
    return { features: [{ type: "Feature", geometry: { type: "Point", coordinates: [121.0, 14.6] }, properties: { store_id: 101, revenue: 12345 } }], summary: { count: 1 } };
  }
  const pool = await getPool()!;
  await withTenantContext(pool, process.env.TENANT_CODE);

  const res = await pool.request().query(`
    SELECT t.store_id,
           AVG(CAST(t.longitude AS FLOAT)) as longitude,
           AVG(CAST(t.latitude AS FLOAT)) as latitude,
           t.location_city,
           SUM(t.peso_value) AS revenue,
           COUNT(*) as transaction_count
    FROM gold.scout_dashboard_transactions t
    WHERE t.longitude IS NOT NULL
      AND t.latitude IS NOT NULL
      AND t.store_id IS NOT NULL
      AND ISNUMERIC(t.longitude) = 1
      AND ISNUMERIC(t.latitude) = 1
      AND t.timestamp >= DATEADD(DAY,-30,GETDATE())
    GROUP BY t.store_id, t.location_city
    ORDER BY SUM(t.peso_value) DESC;
  `);

  const features = res.recordset
    .filter(r => r.longitude != null && r.latitude != null)
    .map(r => ({
      type: "Feature",
      geometry: { type: "Point", coordinates: [Number(r.longitude), Number(r.latitude)] },
      properties: {
        store_id: r.store_id,
        location_city: r.location_city,
        revenue: Number(r.revenue || 0),
        transaction_count: r.transaction_count
      }
    }));

  return { features, summary: { count: features.length } };
}

async function health() {
  if (process.env.DAL_MODE === "mock") {
    return { status: "ok-mock", time: new Date().toISOString() };
  }
  try {
    const pool = await getPool()!;
    await withTenantContext(pool, process.env.TENANT_CODE);
    await pool.request().query("SELECT TOP 1 1 as ok;");
    return { status: "ok", time: new Date().toISOString() };
  } catch (e: any) {
    return { status: "degraded", error: e?.message };
  }
}

// ==========================
// ENHANCED ANALYTICS ENDPOINTS
// ==========================

// Demographics Analysis
async function demographics(q: CommonParams) {
  if (process.env.DAL_MODE === "mock") {
    return {
      age_distribution: [
        { age_group: "18-24", count: 150, percentage: 25.5 },
        { age_group: "25-34", count: 200, percentage: 34.1 }
      ],
      gender_distribution: [
        { gender: "M", count: 280, percentage: 47.6 },
        { gender: "F", count: 308, percentage: 52.4 }
      ]
    };
  }

  const pool = await getPool()!;
  await withTenantContext(pool, process.env.TENANT_CODE);

  const from = safeDate(q.from) ?? firstDay();
  const to = safeDate(q.to) ?? new Date();

  const res = await pool.request()
    .input("from", sql.DateTime2, from)
    .input("to", sql.DateTime2, to)
    .query(`
      SELECT
        customer_gender,
        CASE
          WHEN customer_age < 25 THEN '18-24'
          WHEN customer_age BETWEEN 25 AND 34 THEN '25-34'
          WHEN customer_age BETWEEN 35 AND 44 THEN '35-44'
          WHEN customer_age >= 45 THEN '45+'
          ELSE 'Unknown'
        END as age_group,
        COUNT(*) as count,
        AVG(peso_value) as avg_spend,
        SUM(peso_value) as total_spend
      FROM gold.v_scout_transaction_intelligence
      WHERE interaction_timestamp BETWEEN @from AND @to
      GROUP BY customer_gender,
        CASE
          WHEN customer_age < 25 THEN '18-24'
          WHEN customer_age BETWEEN 25 AND 34 THEN '25-34'
          WHEN customer_age BETWEEN 35 AND 44 THEN '35-44'
          WHEN customer_age >= 45 THEN '45+'
          ELSE 'Unknown'
        END
      ORDER BY customer_gender, age_group;
    `);

  const items = res.recordset;
  const total = items.reduce((sum, item) => sum + item.count, 0);

  return {
    demographics: items.map(item => ({
      ...item,
      percentage: total > 0 ? (item.count / total * 100).toFixed(1) : 0
    })),
    summary: { total_customers: total }
  };
}

// Tobacco Category Analytics
async function tobaccoAnalytics(q: CommonParams) {
  if (process.env.DAL_MODE === "mock") {
    return {
      demographics: [
        { brand_name: "Marlboro", age_group: "25-34", gender: "M", purchase_count: 45 },
        { brand_name: "Fortune", age_group: "18-24", gender: "M", purchase_count: 32 }
      ],
      patterns: { avg_sticks_per_visit: 2.3, payday_boost: 1.4 }
    };
  }

  const pool = await getPool()!;
  await withTenantContext(pool, process.env.TENANT_CODE);

  const from = safeDate(q.from) ?? firstDay();
  const to = safeDate(q.to) ?? new Date();

  const res = await pool.request()
    .input("from", sql.DateTime2, from)
    .input("to", sql.DateTime2, to)
    .query(`
      SELECT
        customer_gender,
        CASE
          WHEN customer_age < 25 THEN '18-24'
          WHEN customer_age BETWEEN 25 AND 34 THEN '25-34'
          WHEN customer_age BETWEEN 35 AND 44 THEN '35-44'
          ELSE '45+'
        END as age_group,
        brand_name,
        COUNT(*) as purchase_count,
        SUM(peso_value) as total_spent,
        AVG(peso_value) as avg_purchase_value,
        SUM(quantity) as total_sticks,
        AVG(quantity) as avg_sticks_per_purchase,

        -- Payday analysis
        AVG(CASE WHEN is_payday_period = 1 THEN peso_value END) as avg_payday_spend,
        AVG(CASE WHEN is_payday_period = 0 THEN peso_value END) as avg_regular_spend,

        -- Day parting
        SUM(CASE WHEN day_part = 'Morning' THEN 1 ELSE 0 END) as morning_purchases,
        SUM(CASE WHEN day_part = 'Afternoon' THEN 1 ELSE 0 END) as afternoon_purchases,
        SUM(CASE WHEN day_part = 'Evening' THEN 1 ELSE 0 END) as evening_purchases

      FROM gold.v_scout_transaction_intelligence
      WHERE interaction_timestamp BETWEEN @from AND @to
        AND category IN ('Tobacco', 'Cigarettes', 'Smoking')
      GROUP BY customer_gender, age_group, brand_name
      ORDER BY purchase_count DESC;
    `);

  return { demographics: res.recordset };
}

// Laundry Category Analytics
async function laundryAnalytics(q: CommonParams) {
  if (process.env.DAL_MODE === "mock") {
    return {
      demographics: [
        { brand_name: "Tide", product_type: "Powder", gender: "F", age_group: "25-34", purchase_count: 28 }
      ],
      co_purchase: { detergent_with_fabcon_rate: 65.2 }
    };
  }

  const pool = await getPool()!;
  await withTenantContext(pool, process.env.TENANT_CODE);

  const from = safeDate(q.from) ?? firstDay();
  const to = safeDate(q.to) ?? new Date();

  const res = await pool.request()
    .input("from", sql.DateTime2, from)
    .input("to", sql.DateTime2, to)
    .query(`
      SELECT
        customer_gender,
        CASE
          WHEN customer_age < 25 THEN '18-24'
          WHEN customer_age BETWEEN 25 AND 34 THEN '25-34'
          WHEN customer_age BETWEEN 35 AND 44 THEN '35-44'
          ELSE '45+'
        END as age_group,
        brand_name,
        CASE
          WHEN product_name LIKE '%bar%' OR local_name LIKE '%baro%' THEN 'Bar Soap'
          WHEN product_name LIKE '%powder%' OR product_name LIKE '%pulbos%' THEN 'Powder'
          WHEN product_name LIKE '%liquid%' THEN 'Liquid'
          WHEN product_name LIKE '%fabric%' OR product_name LIKE '%fabcon%' THEN 'Fabric Softener'
          ELSE 'Other'
        END as product_type,
        COUNT(*) as purchase_count,
        SUM(peso_value) as total_spent,
        AVG(peso_value) as avg_purchase_value

      FROM gold.v_scout_transaction_intelligence
      WHERE interaction_timestamp BETWEEN @from AND @to
        AND category IN ('Laundry', 'Detergent', 'Home Care', 'Cleaning')
      GROUP BY customer_gender, age_group, brand_name, product_type
      ORDER BY purchase_count DESC;
    `);

  return { demographics: res.recordset };
}

// Brand Substitution Analytics
async function substitutionAnalytics(q: CommonParams) {
  if (process.env.DAL_MODE === "mock") {
    return {
      substitutions: [
        { original_brand: "Marlboro", substituted_brand: "Fortune", count: 15, acceptance_rate: 73.3 }
      ]
    };
  }

  const pool = await getPool()!;
  await withTenantContext(pool, process.env.TENANT_CODE);

  const from = safeDate(q.from) ?? firstDay();
  const to = safeDate(q.to) ?? new Date();

  const res = await pool.request()
    .input("from", sql.DateTime2, from)
    .input("to", sql.DateTime2, to)
    .query(`
      SELECT
        original_brand,
        substituted_brand,
        COUNT(*) as substitution_count,
        SUM(CASE WHEN suggestion_accepted = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as acceptance_rate,
        AVG(price_difference) as avg_price_impact,
        STRING_AGG(substitution_reason, ', ') as common_reasons
      FROM dbo.BrandSubstitutions
      WHERE detection_timestamp BETWEEN @from AND @to
      GROUP BY original_brand, substituted_brand
      ORDER BY substitution_count DESC;
    `);

  return { substitutions: res.recordset };
}

// Market Basket Analytics
async function basketAnalytics(q: CommonParams) {
  if (process.env.DAL_MODE === "mock") {
    return {
      recommended_products: [
        { product: "Fabric Softener", probability: 0.68, lift: 2.3 }
      ]
    };
  }

  const pool = await getPool()!;
  await withTenantContext(pool, process.env.TENANT_CODE);

  const productId = q.product_id;
  if (!productId) {
    return { error: "product_id parameter required" };
  }

  const res = await pool.request()
    .input("product_id", sql.NVarChar(200), productId)
    .query(`
      SELECT TOP 10
        product_b as recommended_product,
        brand_b as brand,
        confidence as probability,
        lift,
        transactions_together as co_purchase_count
      FROM dbo.ProductAssociations
      WHERE product_a = @product_id
        AND lift > 1.5
      ORDER BY lift DESC;
    `);

  return { recommended_products: res.recordset };
}

// Transaction Completion Funnel
async function completionFunnel(q: CommonParams) {
  if (process.env.DAL_MODE === "mock") {
    return {
      funnel: {
        interactions: 1000,
        initiated: 850,
        completed: 720,
        abandoned: 130
      }
    };
  }

  const pool = await getPool()!;
  await withTenantContext(pool, process.env.TENANT_CODE);

  const from = safeDate(q.from) ?? firstDay();
  const to = safeDate(q.to) ?? new Date();

  const res = await pool.request()
    .input("from", sql.DateTime2, from)
    .input("to", sql.DateTime2, to)
    .query(`
      SELECT
        COUNT(*) as total_interactions,
        SUM(interaction_started) as interactions_started,
        SUM(transaction_completed) as transactions_completed,
        SUM(transaction_abandoned) as transactions_abandoned,

        SUM(interaction_started) * 100.0 / COUNT(*) as initiation_rate,
        SUM(transaction_completed) * 100.0 / NULLIF(SUM(interaction_started), 0) as completion_rate,
        SUM(transaction_abandoned) * 100.0 / NULLIF(SUM(interaction_started), 0) as abandonment_rate,

        SUM(potential_revenue_lost) as total_revenue_lost,
        STRING_AGG(abandonment_reason, ', ') as top_abandonment_reasons
      FROM dbo.TransactionCompletionStatus
      WHERE interaction_timestamp BETWEEN @from AND @to;
    `);

  return { funnel: res.recordset[0] };
}

// Geographic Analytics
async function geographicAnalytics(q: CommonParams) {
  const level = q.level || 'region';

  if (process.env.DAL_MODE === "mock") {
    return {
      geographic: [
        { location: "NCR", store_count: 25, revenue: 1250000 }
      ]
    };
  }

  const pool = await getPool()!;
  await withTenantContext(pool, process.env.TENANT_CODE);

  const from = safeDate(q.from) ?? firstDay();
  const to = safeDate(q.to) ?? new Date();

  // Validate level parameter
  const validLevels = ['region', 'province', 'city', 'barangay'];
  const safeLevel = validLevels.includes(level) ? level : 'region';

  const res = await pool.request()
    .input("from", sql.DateTime2, from)
    .input("to", sql.DateTime2, to)
    .query(`
      SELECT
        ${safeLevel} as location,
        COUNT(DISTINCT store_id) as store_count,
        COUNT(DISTINCT interaction_id) as customer_count,
        SUM(peso_value) as total_revenue,
        AVG(peso_value) as avg_transaction,

        SUM(CASE WHEN payment_method = 'cash' THEN peso_value ELSE 0 END) as cash_revenue,
        SUM(CASE WHEN payment_method = 'gcash' THEN peso_value ELSE 0 END) as gcash_revenue,

        AVG(customer_age) as avg_age,
        SUM(CASE WHEN customer_gender = 'M' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as male_percent
      FROM gold.v_scout_transaction_intelligence
      WHERE interaction_timestamp BETWEEN @from AND @to
      GROUP BY ${safeLevel}
      ORDER BY total_revenue DESC;
    `);

  return { geographic: res.recordset };
}

// Pecha de Peligro Analysis
async function pechaAnalysis(q: CommonParams) {
  if (process.env.DAL_MODE === "mock") {
    return {
      periods: [
        { period: "Payday", avg_transaction: 125.50, transaction_count: 450 }
      ]
    };
  }

  const pool = await getPool()!;
  await withTenantContext(pool, process.env.TENANT_CODE);

  const from = safeDate(q.from) ?? firstDay();
  const to = safeDate(q.to) ?? new Date();

  const res = await pool.request()
    .input("from", sql.DateTime2, from)
    .input("to", sql.DateTime2, to)
    .query(`
      SELECT
        salary_period,
        COUNT(*) as transaction_count,
        SUM(peso_value) as total_sales,
        AVG(peso_value) as avg_transaction_value,
        COUNT(DISTINCT brand_name) as unique_brands
      FROM gold.v_scout_transaction_intelligence
      WHERE interaction_timestamp BETWEEN @from AND @to
      GROUP BY salary_period
      ORDER BY avg_transaction_value DESC;
    `);

  return { periods: res.recordset };
}

// Day Parting Analysis
async function daypartingAnalysis(q: CommonParams) {
  if (process.env.DAL_MODE === "mock") {
    return {
      dayparts: [
        { day_part: "Morning", category: "Tobacco", transactions: 120, revenue: 15600 }
      ]
    };
  }

  const pool = await getPool()!;
  await withTenantContext(pool, process.env.TENANT_CODE);

  const from = safeDate(q.from) ?? firstDay();
  const to = safeDate(q.to) ?? new Date();
  const categoryFilter = q.category;

  let query = `
    SELECT
      day_part,
      ${categoryFilter ? 'category,' : ''}
      COUNT(*) as transaction_count,
      SUM(peso_value) as total_revenue,
      AVG(peso_value) as avg_transaction,
      COUNT(DISTINCT interaction_id) as unique_customers
    FROM gold.v_scout_transaction_intelligence
    WHERE interaction_timestamp BETWEEN @from AND @to
    ${categoryFilter ? 'AND category = @category' : ''}
    GROUP BY day_part${categoryFilter ? ', category' : ''}
    ORDER BY total_revenue DESC;
  `;

  const request = pool.request()
    .input("from", sql.DateTime2, from)
    .input("to", sql.DateTime2, to);

  if (categoryFilter) {
    request.input("category", sql.NVarChar(100), categoryFilter);
  }

  const res = await request.query(query);

  return { dayparts: res.recordset };
}

// Frequently Bought Together
async function frequentlyBoughtTogether(q: CommonParams) {
  if (process.env.DAL_MODE === "mock") {
    return {
      combinations: [
        { anchor_product: "Marlboro", frequently_bought_with: "Coca-Cola, Chips", avg_lift: 2.1 }
      ]
    };
  }

  const pool = await getPool()!;
  await withTenantContext(pool, process.env.TENANT_CODE);

  const res = await pool.request().query(`
    WITH ProductPairs AS (
      SELECT
        product_a,
        product_b,
        brand_a,
        brand_b,
        transactions_together,
        lift,
        confidence
      FROM dbo.ProductAssociations
      WHERE lift > 2.0
        AND transactions_together >= 5
    )
    SELECT
      product_a as anchor_product,
      STRING_AGG(CONCAT(product_b, ' (', brand_b, ')'), ', ') as frequently_bought_with,
      AVG(lift) as avg_lift,
      SUM(transactions_together) as total_co_purchases
    FROM ProductPairs
    GROUP BY product_a
    ORDER BY total_co_purchases DESC;
  `);

  return { combinations: res.recordset };
}

// Store Profiles
async function storeProfiles(q: CommonParams) {
  if (process.env.DAL_MODE === "mock") {
    return {
      stores: [
        { store_id: "101", store_name: "Sample Store", avg_customer_age: 32.5, revenue: 125000 }
      ]
    };
  }

  const pool = await getPool()!;
  await withTenantContext(pool, process.env.TENANT_CODE);

  const from = safeDate(q.from) ?? firstDay();
  const to = safeDate(q.to) ?? new Date();

  const res = await pool.request()
    .input("from", sql.DateTime2, from)
    .input("to", sql.DateTime2, to)
    .query(`
      SELECT
        store_id,
        store_name,
        store_type,
        city,
        province,
        region,

        COUNT(DISTINCT interaction_id) as unique_customers,
        AVG(customer_age) as avg_customer_age,
        SUM(CASE WHEN customer_gender = 'M' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as male_percentage,

        COUNT(*) as total_transactions,
        SUM(peso_value) as total_revenue,
        AVG(peso_value) as avg_transaction_value,
        COUNT(DISTINCT brand_name) as unique_brands,

        SUM(CASE WHEN payment_method = 'cash' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as cash_percentage,
        SUM(CASE WHEN payment_method = 'gcash' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as gcash_percentage

      FROM gold.v_scout_transaction_intelligence
      WHERE interaction_timestamp BETWEEN @from AND @to
      GROUP BY store_id, store_name, store_type, city, province, region
      ORDER BY total_revenue DESC;
    `);

  return { stores: res.recordset };
}