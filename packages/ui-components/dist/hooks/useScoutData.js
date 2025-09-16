import { useState, useEffect, useCallback } from 'react';
// Mock data generator - will be replaced with actual API calls
const generateMockData = (filters) => {
    const categories = ['beverages', 'snacks', 'personal-care', 'household', 'tobacco'];
    const brands = ['Coca-Cola', 'Pepsi', 'Nestle', 'Unilever', 'P&G', 'Oishi'];
    const regions = ['ncr', 'region3', 'region4a', 'region7'];
    return Array.from({ length: Math.floor(Math.random() * 1000) + 500 }, (_, i) => {
        const date = new Date();
        date.setDate(date.getDate() - Math.floor(Math.random() * 30));
        return {
            id: `tx_${i}`,
            date: date.toISOString().split('T')[0],
            revenue: Math.floor(Math.random() * 5000) + 100,
            quantity: Math.floor(Math.random() * 10) + 1,
            category: categories[Math.floor(Math.random() * categories.length)],
            brand: brands[Math.floor(Math.random() * brands.length)],
            region: regions[Math.floor(Math.random() * regions.length)],
            storeId: `store_${Math.floor(Math.random() * 50) + 1}`,
            deviceId: `device_${Math.floor(Math.random() * 100) + 1}`,
        };
    });
};
const calculateMetrics = (transactions) => {
    const totalTransactions = transactions.length;
    const totalRevenue = transactions.reduce((sum, t) => sum + t.revenue, 0);
    const totalUnits = transactions.reduce((sum, t) => sum + t.quantity, 0);
    return {
        totalTransactions,
        totalRevenue,
        avgTransaction: totalTransactions > 0 ? totalRevenue / totalTransactions : 0,
        avgUnits: totalTransactions > 0 ? totalUnits / totalTransactions : 0,
        growth: {
            transactions: Math.random() * 20 - 5, // -5% to 15% growth
            revenue: Math.random() * 25 - 5, // -5% to 20% growth  
            avgTransaction: Math.random() * 10 - 2, // -2% to 8% growth
        },
    };
};
// Custom hook for Scout data management
export function useScoutData(initialFilters) {
    const [state, setState] = useState({
        transactions: [],
        metrics: {
            totalTransactions: 0,
            totalRevenue: 0,
            avgTransaction: 0,
            avgUnits: 0,
        },
        loading: false,
        error: null,
        lastUpdated: null,
    });
    const [filters, setFilters] = useState(initialFilters);
    const fetchData = useCallback(async (currentFilters) => {
        setState(prev => ({ ...prev, loading: true, error: null }));
        try {
            // Simulate API delay
            await new Promise(resolve => setTimeout(resolve, 500 + Math.random() * 1000));
            // Generate mock data based on filters
            const transactions = generateMockData(currentFilters);
            const metrics = calculateMetrics(transactions);
            setState({
                transactions,
                metrics,
                loading: false,
                error: null,
                lastUpdated: new Date(),
            });
        }
        catch (error) {
            setState(prev => ({
                ...prev,
                loading: false,
                error: error instanceof Error ? error.message : 'Failed to fetch data',
            }));
        }
    }, []);
    const updateFilters = useCallback((newFilters) => {
        const updatedFilters = { ...filters, ...newFilters };
        setFilters(updatedFilters);
        fetchData(updatedFilters);
    }, [filters, fetchData]);
    const refetch = useCallback(() => {
        fetchData(filters);
    }, [filters, fetchData]);
    // Initial data fetch
    useEffect(() => {
        fetchData(filters);
    }, []); // Only run on mount
    // Filtered data based on current filters
    const filteredTransactions = state.transactions.filter(transaction => {
        if (filters.category !== 'all' && transaction.category !== filters.category) {
            return false;
        }
        if (filters.region !== 'all' && transaction.region !== filters.region) {
            return false;
        }
        if (filters.brand !== 'all' && transaction.brand !== filters.brand) {
            return false;
        }
        return true;
    });
    const filteredMetrics = calculateMetrics(filteredTransactions);
    return {
        // Data
        transactions: filteredTransactions,
        allTransactions: state.transactions,
        metrics: filteredMetrics,
        rawMetrics: state.metrics,
        // State
        loading: state.loading,
        error: state.error,
        lastUpdated: state.lastUpdated,
        // Filters
        filters,
        updateFilters,
        // Actions
        refetch,
    };
}
// Hook for async data operations
export function useAsyncScoutOperation(operation, dependencies = []) {
    const [data, setData] = useState(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const execute = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const result = await operation();
            setData(result);
        }
        catch (err) {
            setError(err instanceof Error ? err.message : 'Operation failed');
        }
        finally {
            setLoading(false);
        }
    }, dependencies);
    useEffect(() => {
        execute();
    }, [execute]);
    return { data, loading, error, refetch: execute };
}
