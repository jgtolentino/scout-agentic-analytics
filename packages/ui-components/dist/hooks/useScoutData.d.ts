export interface ScoutFilters {
    dateRange: string;
    region: string;
    category: string;
    brand: string;
    timeOfDay: string;
    dayType: string;
}
export interface TransactionData {
    id: string;
    date: string;
    revenue: number;
    quantity: number;
    category?: string;
    brand?: string;
    storeId?: string;
    deviceId?: string;
    region?: string;
}
export interface MetricData {
    totalTransactions: number;
    totalRevenue: number;
    avgTransaction: number;
    avgUnits: number;
    growth?: {
        transactions: number;
        revenue: number;
        avgTransaction: number;
    };
}
export type ScoutMetrics = MetricData;
export interface ScoutDataState {
    transactions: TransactionData[];
    metrics: MetricData;
    loading: boolean;
    error: string | null;
    lastUpdated: Date | null;
}
export declare function useScoutData(initialFilters: ScoutFilters): {
    transactions: TransactionData[];
    allTransactions: TransactionData[];
    metrics: MetricData;
    rawMetrics: MetricData;
    loading: boolean;
    error: string | null;
    lastUpdated: Date | null;
    filters: ScoutFilters;
    updateFilters: (newFilters: Partial<ScoutFilters>) => void;
    refetch: () => void;
};
export declare function useAsyncScoutOperation<T>(operation: () => Promise<T>, dependencies?: any[]): {
    data: T | null;
    loading: boolean;
    error: string | null;
    refetch: () => Promise<void>;
};
