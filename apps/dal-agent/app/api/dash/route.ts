import { NextRequest, NextResponse } from "next/server";
import { resolveSection } from "../../../lib/dal";
import type { SectionKey, BundleResponse } from "../../../types";

const DEFAULT_SECTIONS: SectionKey[] = ["kpis","brands","storesGeo"];

export async function GET(req: NextRequest) {
  // simple bearer check (optional in your setup)
  const wantAuth = process.env.SC_OUTBOUND_TOKEN;
  if (wantAuth) {
    const hdr = req.headers.get("authorization") || "";
    const ok = hdr.startsWith("Bearer ") && hdr.split(" ")[1] === wantAuth;
    if (!ok) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const url = new URL(req.url);
  const sections = (url.searchParams.get("sections") || "")
    .split(",")
    .map(s => s.trim())
    .filter(Boolean) as SectionKey[];

  const selected = sections.length ? sections : DEFAULT_SECTIONS;

  const commonParams = {
    from: url.searchParams.get("from") || undefined,
    to: url.searchParams.get("to") || undefined,
    brands: url.searchParams.get("brands") || undefined,
    stores: url.searchParams.get("stores") || undefined,
    page: url.searchParams.get("page") || undefined,
    pageSize: url.searchParams.get("pageSize") || undefined
  };

  const entries = await Promise.all(selected.map(async (key) => {
    try {
      const data = await resolveSection(key, commonParams as any);
      return [key, { ok: true, data }] as const;
    } catch (e: any) {
      return [key, { ok: false, error: e?.message || "failed" }] as const;
    }
  }));

  const bundle: BundleResponse["bundle"] = {};
  const errors: NonNullable<BundleResponse["errors"]> = {};

  for (const [key, res] of entries) {
    if (res.ok) (bundle as any)[key] = (res as any).data;
    else errors[key] = { message: (res as any).error };
  }

  const body: BundleResponse = { bundle, timestamp: new Date().toISOString() };
  const status = Object.keys(errors).length ? 207 : 200;
  if (status === 207) (body as any).errors = errors;

  return NextResponse.json(body, { status });
}