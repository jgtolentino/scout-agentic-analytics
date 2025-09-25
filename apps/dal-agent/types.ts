export type SectionKey = "kpis"|"brands"|"compare"|"transactions"|"storesGeo"|"health";

export type BundleResponse = {
  bundle: Partial<{
    kpis: any[];
    brands: { items: any[]; summary?: any };
    compare: { pairs: any[]; insights?: any[] };
    transactions: { items: any[]; page: number; pageSize: number; total?: number };
    storesGeo: { features: any[]; summary?: any };
    health: any;
  }>;
  errors?: Record<string, { message: string }>;
  timestamp: string;
};