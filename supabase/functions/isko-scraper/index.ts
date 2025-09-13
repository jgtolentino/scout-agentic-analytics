import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

type Result = { items: any[]; discovered: string[]; note: string };

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseKey);

async function fetchPage(url: string): Promise<string> {
  const r = await fetch(url, { redirect: "follow" });
  if (!r.ok) throw new Error(`fetch ${r.status}`);
  return await r.text();
}

function extractLinks(html: string, base: string): string[] {
  const re = /href="([^"#]+)"/gi;
  const out: string[] = [];
  let m: RegExpExecArray | null;
  while ((m = re.exec(html))) {
    const href = m[1];
    try {
      const abs = new URL(href, base).toString();
      if (abs.startsWith("http")) out.push(abs);
    } catch {}
  }
  return Array.from(new Set(out));
}

function extractItems(html: string, url: string, sourceId?: string): any[] {
  const items: any[] = [];
  
  // Basic product extraction pattern (enhance with selector packs later)
  // Look for common e-commerce patterns
  const productPattern = /<div[^>]*class="[^"]*product[^"]*"[^>]*>([\s\S]*?)<\/div>/gi;
  const pricePattern = /(?:₱|PHP|Php)\s*([\d,]+\.?\d*)/i;
  const titlePattern = /<h[1-6][^>]*>(.*?)<\/h[1-6]>/i;
  
  let match;
  while ((match = productPattern.exec(html)) !== null) {
    const productHtml = match[1];
    
    // Extract title
    const titleMatch = titlePattern.exec(productHtml);
    const title = titleMatch ? titleMatch[1].replace(/<[^>]*>/g, '').trim() : '';
    
    // Extract price
    const priceMatch = pricePattern.exec(productHtml);
    const price = priceMatch ? parseFloat(priceMatch[1].replace(/,/g, '')) : null;
    
    if (title && price) {
      // Basic brand extraction from title (first word often is brand)
      const words = title.split(' ');
      const brand = words[0].toUpperCase();
      
      items.push({
        source_id: sourceId,
        url: url,
        brand_name: brand,
        product_name: title,
        product_category: null,
        pack_size_value: null,
        pack_size_unit: null,
        price: price,
        currency: 'PHP',
        content_sha256: null
      });
    }
  }
  
  return items;
}

serve(async (req: Request) => {
  try {
    const { url, source_id } = await req.json();
    if (!url) return new Response(JSON.stringify({ error: "url required" }), { status: 400 });
    
    const html = await fetchPage(url);
    const items = extractItems(html, url, source_id);
    const discovered = extractLinks(html, url);
    
    // If items found, ingest them to master catalog
    if (items.length > 0 && source_id) {
      try {
        const { data, error } = await supabase.rpc('ingest_master_items', { 
          p_items: items 
        });
        if (error) console.error('Ingest error:', error);
      } catch (e) {
        console.error('Failed to ingest items:', e);
      }
    }
    
    const result: Result = { items, discovered, note: items.length ? "product" : "listing" };
    return new Response(JSON.stringify(result), { headers: { "content-type": "application/json" }});
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e?.message || e) }), { status: 500 });
  }
});
