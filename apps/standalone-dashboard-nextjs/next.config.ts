import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Enable standalone build for Azure App Service deployment
  output: 'standalone',
  reactStrictMode: true,
  // experimental: {
  //   optimizeCss: true
  // },
  images: {
    unoptimized: true // dashboard usually doesn't need remote images
  },
  eslint: {
    ignoreDuringBuilds: true // relax during initial integration
  },
  typescript: {
    ignoreBuildErrors: true // disable TypeScript errors for production builds
  },
  // Fix workspace root detection for monorepo builds
  outputFileTracingRoot: '/Users/tbwa/scout-v7/apps/standalone-dashboard-nextjs',
  // Use standard webpack build for production stability
  // experimental turbopack disabled due to CSS processing issues
  // Configure for Plotly.js compatibility and SQL server-side only
  webpack: (config) => {
    config.resolve.alias = {
      ...config.resolve.alias,
      // Fix for plotly.js
      'plotly.js/dist/plotly': 'plotly.js-dist-min'
    };

    // Exclude SQL modules from client bundle
    if (!config.isServer) {
      config.resolve.fallback = {
        ...config.resolve.fallback,
        tls: false,
        net: false,
        dns: false,
        child_process: false,
        fs: false,
        crypto: false,
        stream: false,
        util: false,
        url: false,
        zlib: false,
        http: false,
        https: false,
        events: false,
        buffer: false,
        os: false,
        path: false,
      };

      // Prevent mssql from being bundled in client
      config.externals = [
        ...(config.externals || []),
        'mssql',
        'tedious',
        '@azure/msal-node',
        '@azure/identity'
      ];
    }

    return config;
  },
};

export default nextConfig;
