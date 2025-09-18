import { NextRequest, NextResponse } from 'next/server';
import { parse } from 'csv-parse/sync';
import fs from 'node:fs';
import path from 'node:path';
import type { FlatTxn, Paged } from '@/src/data/types';

const MODE = (process.env.NEXT_PUBLIC_DATA_MODE || 'mock_csv').toLowerCase();

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const page = Math.max(1, Number(searchParams.get('page') ?? '1'));
  const pageSize = Math.min(500, Math.max(1, Number(searchParams.get('pageSize') ?? '50')));

  if (MODE === 'mock_csv') {
    const csvPath = path.join(process.cwd(), 'public', 'data', 'full_flat.csv');
    if (!fs.existsSync(csvPath)) {
      return NextResponse.json({ rows: [], total: 0, page, pageSize, error: 'CSV not found at public/data/full_flat.csv' }, { status: 200 });
    }
    const buf = fs.readFileSync(csvPath);
    const records = parse(buf, { columns: true, skip_empty_lines: true }) as any[];
    const total = records.length;
    const start = (page - 1) * pageSize;
    const slice = records.slice(start, start + pageSize) as FlatTxn[];
    return NextResponse.json({ rows: slice, total, page, pageSize } satisfies Paged<FlatTxn>);
  }

  // Supabase (read-only)
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !anon) {
    return NextResponse.json({ error: 'Supabase env missing', rows: [], total: 0, page, pageSize }, { status: 200 });
  }

  // Prefer calling a paginated RPC to avoid large scans.
  // Fallback: view with range().
  const qPage = page - 1;
  const rangeFrom = qPage * pageSize;
  const rangeTo = rangeFrom + pageSize - 1;

  const resp = await fetch(`${url}/rest/v1/scout_gold_transactions_flat?select=*&offset=${rangeFrom}&limit=${pageSize}`, {
    headers: { apikey: anon, Authorization: `Bearer ${anon}` },
    cache: 'no-store',
  });
  if (!resp.ok) {
    const text = await resp.text();
    return NextResponse.json({ error: `Supabase error: ${text}`, rows: [], total: 0, page, pageSize }, { status: 200 });
  }
  const rows = await resp.json() as FlatTxn[];

  // total count: use HEAD request with Prefer: count=exact header for PostgREST
  const totalHeadUrl = `${url}/rest/v1/scout_gold_transactions_flat?select=transaction_id`;
  const totalResp = await fetch(totalHeadUrl, {
    method: 'HEAD',
    headers: { apikey: anon, Authorization: `Bearer ${anon}`, Prefer: 'count=exact' },
    cache: 'no-store',
  });
  const cr = totalResp.headers.get('content-range') || '';
  const total = Number((cr.includes('/') ? cr.split('/')[1] : '') || rows.length);
  return NextResponse.json({ rows, total, page, pageSize } satisfies Paged<FlatTxn>);
}