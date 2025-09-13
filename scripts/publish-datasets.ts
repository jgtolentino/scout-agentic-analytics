import { createClient } from "@supabase/supabase-js";
import { Client } from "pg";
import fs from "node:fs";
import path from "node:path";

const url = process.env.SUPABASE_URL!;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;
const supa = createClient(url, serviceKey);

const pgc = new Client({
  connectionString: process.env.DATABASE_URL
});

async function toCSV(rows: any[]) {
  if (!rows.length) return "";
  const headers = Object.keys(rows[0]);
  const lines = [headers.join(",")];
  for (const r of rows) {
    lines.push(headers.map(h => {
      const v = r[h];
      if (v == null) return "";
      const s = typeof v === "object" ? JSON.stringify(v) : String(v);
      return /[",\n]/.test(s) ? `"${s.replace(/"/g,'""')}"` : s;
    }).join(","));
  }
  return lines.join("\n");
}

(async () => {
  await pgc.connect();

  const genDate = new Date().toISOString().slice(0,10);
  const outdir = "/tmp/publish";
  fs.mkdirSync(outdir, { recursive: true });

  const datasets = {
    gold: {
      revenue_trend: "select date, revenue from scout_gold.revenue_trend"
    }
  };

  const manifest:any = { generated_at: new Date().toISOString(), gold: {}, platinum: {} };

  for (const [group, defs] of Object.entries(datasets)) {
    for (const [name, sql] of Object.entries(defs as any)) {
      const { rows } = await pgc.query(sql);
      const csv = await toCSV(rows);
      const rel = `${group}/${name}_${genDate}.csv`;
      const full = path.join(outdir, `${name}.csv`);
      fs.writeFileSync(full, csv);
      const { error } = await supa.storage.from("sample").upload(`scout/v1/${rel}`, new Blob([csv]), { upsert: true, contentType: "text/csv" });
      if (error) throw error;
      manifest[group] ||= {};
      manifest[group][name] = rel;
    }
  }

  const manifestBlob = new Blob([JSON.stringify(manifest, null, 2)], { type: "application/json" });
  const { error: mErr } = await supa.storage.from("sample").upload(`scout/v1/manifests/latest.json`, manifestBlob, { upsert: true, contentType: "application/json" });
  if (mErr) throw mErr;

  console.log("Published:", JSON.stringify(manifest, null, 2));
  await pgc.end();
})();