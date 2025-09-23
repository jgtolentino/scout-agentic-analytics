/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  trailingSlash: false,
  images: {
    domains: [
      'fn-scout-readonly.azurewebsites.net'
    ],
    unoptimized: true // Prevent image optimization issues on Vercel
  },
  experimental: {
    serverComponentsExternalPackages: ['mssql'],
    esmExternals: false
  },
  // Disable static optimization to prevent SSR issues
  async exportPathMap() {
    return {}
  },
  async headers() {
    return [
      {
        source: '/api/:path*',
        headers: [
          { key: 'Access-Control-Allow-Origin', value: '*' },
          { key: 'Access-Control-Allow-Methods', value: 'GET, POST, PUT, DELETE, OPTIONS' },
          { key: 'Access-Control-Allow-Headers', value: 'Content-Type, Authorization' },
          { key: 'Cache-Control', value: 'no-cache, no-store, must-revalidate' },
        ],
      },
    ]
  },
  env: {
    NEXT_PUBLIC_MAPBOX_TOKEN: process.env.NEXT_PUBLIC_MAPBOX_TOKEN,
    NEXT_PUBLIC_APP_MODE: process.env.NEXT_PUBLIC_APP_MODE,
    NEXT_PUBLIC_SCOUT_SCHEMA: process.env.NEXT_PUBLIC_SCOUT_SCHEMA,
    NEXT_PUBLIC_DATASOURCE: process.env.NEXT_PUBLIC_DATASOURCE,
  }
}

module.exports = nextConfig