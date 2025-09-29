export const API_BASE =
  (typeof window !== "undefined" && (window as any).__NEXT_PUBLIC_API_BASE) ||
  process.env.NEXT_PUBLIC_API_BASE ||
  "/api";

export async function fetchJSON<T=unknown>(path: string, init?: RequestInit): Promise<T> {
  const url = path.startsWith("http") ? path : `${API_BASE}${path}`;
  const res = await fetch(url, { ...init, headers: { Accept: "application/json", ...(init?.headers||{}) } });
  const ct = res.headers.get("content-type") || "";
  const text = await res.text();
  if (!res.ok) throw new Error(`HTTP ${res.status} ${res.statusText} @ ${url} :: ${text.slice(0,200)}`);
  if (!/application\/json/i.test(ct)) throw new Error(`Non-JSON @ ${url} :: ${text.slice(0,200)}`);
  return JSON.parse(text) as T;
}

export const safeStr = (v:any) => (v==null ? "" : String(v));
export const safeDate = (v:any) => {
  if (!v) return "";
  const d = v instanceof Date ? v : new Date(v);
  return isNaN(+d) ? "" : d.toLocaleString();
};
