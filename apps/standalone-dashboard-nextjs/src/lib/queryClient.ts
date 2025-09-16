'use client';

import { QueryClient } from '@tanstack/react-query';

// Singleton pattern for QueryClient to prevent multiple instances
const g = globalThis as unknown as { __scoutQueryClient?: QueryClient };

export const queryClient =
  g.__scoutQueryClient ??
  new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 30_000, // 30 seconds
        refetchOnWindowFocus: false,
        retry: 2,
        // Use mock data when available
        queryFn: async ({ queryKey, meta }) => {
          // Default query function will be overridden by specific hooks
          console.warn('No queryFn provided for:', queryKey);
          return null;
        },
      },
      mutations: {
        retry: 1,
      },
    },
  });

// Store singleton in development
if (process.env.NODE_ENV !== 'production') {
  g.__scoutQueryClient = queryClient;
}

export default queryClient;