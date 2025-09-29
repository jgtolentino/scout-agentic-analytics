// Fallback to working scout-dashboard API until Functions are ready
export const API_BASE = "https://scout-dashboard-xi.vercel.app/api";

export async function fetchJSON<T=unknown>(path: string, init?: RequestInit): Promise<T> {
  const url = path.startsWith("http") ? path : `${API_BASE}${path}`;
  const res = await fetch(url, { 
    ...init, 
    headers: { 
      Accept: "application/json", 
      "Content-Type": "application/json",
      ...(init?.headers||{}) 
    } 
  });
  
  if (!res.ok) {
    throw new Error(`HTTP ${res.status} ${res.statusText}`);
  }
  
  const data = await res.json();
  return data as T;
}

export const safeStr = (v: any) => (v == null ? "" : String(v));
export const safeDate = (v: any) => {
  if (!v) return "";
  const d = v instanceof Date ? v : new Date(v);
  return isNaN(+d) ? "" : d.toLocaleString();
};
