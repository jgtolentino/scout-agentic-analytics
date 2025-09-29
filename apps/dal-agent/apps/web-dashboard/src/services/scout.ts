import { fetchJSON } from "../lib/api";
export type TxnKpis = { tx_count:number; revenue:number; units:number; stores:number };
export async function getKpis(){ return fetchJSON<TxnKpis>("/transactions/kpis"); }
export async function getTransactions(params: Record<string,string|number|undefined> = {}){
  const q = new URLSearchParams();
  for (const [k,v] of Object.entries(params)) if (v!=null) q.set(k,String(v));
  const qs = q.toString();
  return fetchJSON<{count:number;rows:any[]}>("/scout/transactions" + (qs?`?${qs}`:""));
}
