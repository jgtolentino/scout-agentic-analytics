import { NextResponse } from 'next/server';
import { parse } from 'csv-parse/sync';
import fs from 'node:fs';
import path from 'node:path';

const MODE = (process.env.NEXT_PUBLIC_DATA_MODE || 'mock_csv').toLowerCase();

function summarize(rows: any[]) {
  const unique = (arr: any[], key: string) => new Set(arr.map(r => r?.[key]).filter(Boolean)).size;
  const parseNum = (v: any) => (v === null || v === undefined || v === '' ? 0 : Number(v));
  const totalRevenue = rows.reduce((s, r) => s + parseNum(r.total_price), 0);
  const minTs = rows.map(r => r.transactiondate || r.ts_ph || r.date_ph).filter(Boolean).sort()[0] || null;
  const maxTs = rows.map(r => r.transactiondate || r.ts_ph || r.date_ph).filter(Boolean).sort().slice(-1)[0] || null;

  return {
    totalRows: rows.length,
    uniqueStores: unique(rows, 'store') || unique(rows, 'storeid'),
    uniqueDevices: unique(rows, 'device') || unique(rows, 'deviceid'),
    uniqueBrands: unique(rows, 'brand'),
    totalRevenue,
    dateMin: minTs,
    dateMax: maxTs,
  };
}

export async function GET() {
  if (MODE === 'mock_csv') {
    const csvPath = path.join(process.cwd(), 'public', 'data', 'full_flat.csv');
    if (!fs.existsSync(csvPath)) {
      return NextResponse.json({ totalRows: 0, uniqueStores: 0, uniqueDevices: 0, uniqueBrands: 0, totalRevenue: 0, dateMin: null, dateMax: null });
    }
    const buf = fs.readFileSync(csvPath);
    const rows = parse(buf, { columns: true, skip_empty_lines: true }) as any[];
    return NextResponse.json(summarize(rows));
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

  // Aggregate in SQL if a materialized summary exists; else brute force (bounded).
  const resp = await fetch(`${url}/rest/v1/scout_gold_transactions_flat?select=brand,store,storeid,device,deviceid,total_price,transactiondate,ts_ph,date_ph&limit=200000`, {
    headers: { apikey: anon, Authorization: `Bearer ${anon}` },
    cache: 'no-store',
  });
  const rows = resp.ok ? await resp.json() as any[] : [];
  return NextResponse.json(summarize(rows));
}