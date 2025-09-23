import { AppProps } from 'next/app'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useState, useEffect } from 'react'
import ErrorBoundary from '../components/ErrorBoundary'
import '../styles/globals.css'

// Create a client with error handling
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 2,
      refetchOnWindowFocus: false,
      staleTime: 5 * 60 * 1000, // 5 minutes
      // Disable caching for live data
      gcTime: 0,
    },
  },
})

function ScoutDashboardApp({ Component, pageProps }: AppProps) {
  // Environment validation on client side
  useEffect(() => {
    const requiredEnvs = [
      'NEXT_PUBLIC_MAPBOX_TOKEN'
    ]

    const missingEnvs = requiredEnvs.filter(env => !process.env[env])

    if (missingEnvs.length > 0) {
      console.error('Missing required environment variables:', missingEnvs)

      // Show error banner in development
      if (process.env.NODE_ENV === 'development') {
        const banner = document.createElement('div')
        banner.style.cssText = `
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          background: #dc2626;
          color: white;
          padding: 8px;
          text-align: center;
          z-index: 9999;
          font-size: 14px;
        `
        banner.textContent = `Missing env vars: ${missingEnvs.join(', ')}`
        document.body.prepend(banner)
      }
    }
  }, [])

  return (
    <ErrorBoundary>
      <QueryClientProvider client={queryClient}>
        <Component {...pageProps} />
      </QueryClientProvider>
    </ErrorBoundary>
  )
}

export default ScoutDashboardApp