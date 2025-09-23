import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';

/** ---------- Config ---------- */
const EXPORTS: Record<string, { sql: string; filename: (p: any) => string; redact?: boolean }> = {
  // Clean export outputs (contract-compliant)
  'flat-actual': {
    sql: `
      SELECT canonical_tx_id, device_id, store_id, brand, product_name, category,
             total_amount, total_items, payment_method, audio_transcript, txn_ts,
             daypart, weekday_weekend, transaction_date, store_name
      FROM gold.v_transactions_flat
      ORDER BY txn_ts DESC;
    `,
    filename: () => `scout_flat_complete_actual_columns_clean.csv`,
  },
  'flat-v24': {
    sql: `
      SELECT CanonicalTxID, TransactionID, DeviceID, StoreID, StoreName, Region,
             ProvinceName, MunicipalityName, BarangayName, psgc_region, psgc_citymun,
             psgc_barangay, GeoLatitude, GeoLongitude, StorePolygon, Amount,
             Basket_Item_Count, WeekdayOrWeekend, TimeOfDay, AgeBracket, Gender,
             Role, Substitution_Flag, Txn_TS
      FROM gold.v_transactions_flat_v24
      ORDER BY Txn_TS DESC;
    `,
    filename: () => `scout_flat_complete_24col_contract_clean.csv`,
  },
  'crosstab-v10': {
    sql: `
      SELECT [date], store_id, store_name, municipality_name, daypart, brand,
             txn_count, total_amount, avg_basket_amount, substitution_events
      FROM gold.v_transactions_crosstab_v10
      ORDER BY [date] DESC, store_id, daypart, brand;
    `,
    filename: () => `scout_crosstab_complete_v10.csv`,
  },
  crosstab_14d: {
    sql: `
      SELECT [date], store_name, Morning_Transactions, Midday_Transactions,
             Afternoon_Transactions, Evening_Transactions, txn_count, total_amount
      FROM gold.v_transactions_crosstab
      WHERE [date] >= CONVERT(date, DATEADD(day,-14, SYSUTCDATETIME()))
      ORDER BY [date], store_name;
    `,
    filename: () => `scout_crosstab_14d_${new Date().toISOString().slice(0,10)}.csv`,
  },
  brands_summary: {
    sql: `
      SELECT brand, category, COUNT(*) as total_transactions, SUM(total_amount) as total_revenue,
             AVG(total_amount) as avg_transaction_value, MIN(txn_ts) as first_transaction,
             MAX(txn_ts) as latest_transaction, COUNT(DISTINCT store_id) as stores_present
      FROM gold.v_transactions_flat
      WHERE transaction_date >= CONVERT(date, DATEADD(day,-7, SYSUTCDATETIME()))
      GROUP BY brand, category
      ORDER BY total_revenue DESC;
    `,
    filename: () => `scout_brands_summary_${new Date().toISOString().slice(0,10)}.csv`,
  },
  flat_latest: {
    sql: `
      SELECT TOP (1000) canonical_tx_id, device_id, store_id, brand, product_name, category,
             total_amount, total_items, payment_method, audio_transcript, daypart,
             weekday_weekend, txn_ts, store_name, transaction_date
      FROM gold.v_transactions_flat
      ORDER BY txn_ts DESC;
    `,
    filename: () => `scout_flat_latest_${new Date().toISOString().slice(0,10)}.csv`,
  },
  // Privacy-safe export (no transcripts)
  flat_today_no_transcripts: {
    sql: `
      SELECT canonical_tx_id, device_id, store_id, brand, product_name, category,
             total_amount, total_items, payment_method, daypart, weekday_weekend,
             txn_ts, store_name, transaction_date
      FROM gold.v_transactions_flat
      WHERE transaction_date = CONVERT(date, SYSUTCDATETIME())
      ORDER BY txn_ts DESC;
    `,
    filename: () => `scout_flat_today_no_transcripts_${new Date().toISOString().slice(0,10)}.csv`,
    redact: true,
  },
  // Current day full data
  flat_today_full: {
    sql: `
      SELECT canonical_tx_id, device_id, store_id, brand, product_name, category,
             total_amount, total_items, payment_method, audio_transcript, daypart,
             weekday_weekend, txn_ts, store_name, transaction_date
      FROM gold.v_transactions_flat
      WHERE transaction_date = CONVERT(date, SYSUTCDATETIME())
      ORDER BY txn_ts DESC;
    `,
    filename: () => `scout_flat_today_full_${new Date().toISOString().slice(0,10)}.csv`,
  },
  // Power BI optimized export
  pbi_transactions_summary: {
    sql: `
      SELECT transaction_date, year, month, day, weekday_name, daypart, weekday_weekend,
             store_id, store_name, brand, category, transaction_count, total_revenue,
             avg_transaction_value, total_items_sold, unique_transactions, unique_devices
      FROM gold.v_pbi_transactions_summary
      WHERE transaction_date >= CONVERT(date, DATEADD(day,-30, SYSUTCDATETIME()))
      ORDER BY transaction_date DESC, brand;
    `,
    filename: () => `scout_pbi_transactions_${new Date().toISOString().slice(0,10)}.csv`,
  },
};

/** ---------- Helpers ---------- */
function hmac(payload: string, secret?: string) {
  if (!secret) return "";
  return crypto.createHmac("sha256", secret).update(payload).digest("hex");
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ type: string }> }
) {
  const { type: rawType } = await params;
  const type = rawType?.trim();
  const mode = (process.env.EXPORT_DELEGATION_MODE || "resolve") as "resolve" | "delegate";
  const webhook = process.env.BRUNO_WEBHOOK_URL || "";
  const webhookSecret = process.env.BRUNO_WEBHOOK_SECRET || "";

  const spec = EXPORTS[type];
  if (!spec) {
    return NextResponse.json({
      ok: false,
      error: "unknown_export_type",
      available_types: Object.keys(EXPORTS)
    }, { status: 404 });
  }

  // Optional parameterization (safe allow-list only)
  const params_body = await request.json().catch(() => ({}));
  const params_obj = typeof params_body === "object" ? params_body : {};

  // Always return the resolved SQL + filename (client can call runner directly)
  const payload = {
    ok: true,
    type,
    sql: spec.sql.trim(),
    filename: spec.filename(params_obj),
    redact: !!spec.redact,
    mode,
    runner_command: `./scripts/bcp_export_runner.sh custom "${spec.sql.trim()}" "${spec.filename(params_obj)}"`,
  };

  if (mode === "delegate") {
    if (!webhook) {
      return NextResponse.json({
        ok: false,
        error: "missing_webhook",
        detail: "BRUNO_WEBHOOK_URL not configured"
      }, { status: 500 });
    }

    const body = JSON.stringify({
      ...payload,
      requestedAt: new Date().toISOString(),
      requestedBy: request.headers.get('user-agent') || 'unknown'
    });
    const sig = hmac(body, webhookSecret);

    try {
      const r = await fetch(webhook, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-bruno-signature": sig,
          "x-scout-export": "true"
        },
        body,
      });
      const jr = await r.json().catch(() => ({}));

      return NextResponse.json({
        ...payload,
        delegated: true,
        bruno: jr,
        webhook_status: r.status
      });
    } catch (e: any) {
      return NextResponse.json({
        ...payload,
        delegated: false,
        error: "webhook_failed",
        detail: String(e)
      }, { status: 502 });
    }
  }

  // resolve mode - return SQL + command for Bruno execution
  return NextResponse.json(payload);
}

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ type: string }> }
) {
  const { type: rawType } = await params;
  const type = rawType?.trim();

  if (type === 'list') {
    return NextResponse.json({
      ok: true,
      available_exports: Object.keys(EXPORTS).map(key => ({
        type: key,
        redact: !!EXPORTS[key].redact,
        description: getExportDescription(key)
      }))
    });
  }

  const spec = EXPORTS[type];
  if (!spec) {
    return NextResponse.json({
      ok: false,
      error: "unknown_export_type",
      available_types: Object.keys(EXPORTS)
    }, { status: 404 });
  }

  return NextResponse.json({
    ok: true,
    type,
    filename: spec.filename({}),
    redact: !!spec.redact,
    description: getExportDescription(type),
    runner_command: `./scripts/bcp_export_runner.sh ${type}`
  });
}

function getExportDescription(type: string): string {
  const descriptions: Record<string, string> = {
    'flat-actual': "Complete flat dataframe with actual 15-column schema (10 records)",
    'flat-v24': "Complete flat dataframe with 24-column contract compatibility (10 records)",
    'crosstab-v10': "Canonical long-form crosstab with 10 columns (5 records)",
    crosstab_14d: "14-day crosstab analysis with time period breakdown",
    brands_summary: "Brand performance summary with revenue metrics",
    flat_latest: "Latest 1000 transactions with full details including transcripts",
    flat_today_no_transcripts: "Today's transactions without audio transcripts (privacy-safe)",
    flat_today_full: "Today's transactions with full details including transcripts",
    pbi_transactions_summary: "Power BI optimized transaction summary (last 30 days)"
  };
  return descriptions[type] || "Custom export query";
}