export type Capability = {
  code: string;
  description: string;
  signals: string[];         // keywords/intents the router detects
  inputs: string[];          // required fields the tool expects
  outputs: string[];         // what the tool returns
  risk: "low" | "medium" | "high";  // for guardrails
  cost: number;              // rough effort score for tie-breaks
};

export const CAPABILITIES: Capability[] = [
  {
    code: "SEMANTIC_QUERY",
    description: "SQL over semantic layer with GROUP BY ROLLUP, filters, time grains.",
    signals: ["aggregate", "trend", "by", "rollup", "compare", "category", "brand", "sku",
              "mtd", "wtd", "ytd", "basket", "age", "gender", "weekday", "daypart",
              "revenue", "sales", "transactions", "average", "sum", "count", "total",
              "show", "get", "fetch", "list", "breakdown", "analysis", "performance"],
    inputs: ["dimensions", "measures", "filters", "timeRange", "grain", "rollup"],
    outputs: ["table", "pivot", "chartSpec"],
    risk: "low",
    cost: 1
  },
  {
    code: "GEO_EXPORT",
    description: "Choropleth/heat metrics by polygon hierarchy (region→city→barangay→store).",
    signals: ["map", "choropleth", "heatmap", "geo", "region", "barangay", "store map",
              "geographic", "location", "area", "territory", "spatial", "visualize",
              "heat", "polygon", "boundary", "city", "municipality"],
    inputs: ["level", "metric", "filters", "timeRange"],
    outputs: ["geojson", "tiles", "downloadUrl"],
    risk: "low",
    cost: 2
  },
  {
    code: "PARITY_CHECK",
    description: "Flat vs Crosstab parity for a period.",
    signals: ["parity", "validate", "diff", "reconcile", "quality", "check", "verify",
              "audit", "consistency", "match", "compare data", "data quality"],
    inputs: ["daysBack?"],
    outputs: ["report"],
    risk: "medium",
    cost: 1
  },
  {
    code: "AUTO_SYNC_FLAT",
    description: "Change Tracking → export gold.vw_FlatExport on delta.",
    signals: ["sync", "export", "refresh", "update", "latest", "trigger", "run",
              "force", "execute", "process", "generate", "extract"],
    inputs: [],
    outputs: ["status"],
    risk: "medium",
    cost: 2
  },
  {
    code: "CATALOG_QA",
    description: "RAG over data dictionary / metrics / agent docs.",
    signals: ["what is", "definition", "field", "metric", "where is", "how to", "agent",
              "explain", "describe", "meaning", "help", "documentation", "define",
              "column", "table", "view", "procedure", "function"],
    inputs: ["question"],
    outputs: ["answer", "citations"],
    risk: "low",
    cost: 1
  }
];

export function getCapabilityByCode(code: string): Capability | undefined {
  return CAPABILITIES.find(c => c.code === code);
}

export function getAllCapabilities(): Capability[] {
  return CAPABILITIES;
}