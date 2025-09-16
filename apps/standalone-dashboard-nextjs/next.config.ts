import type { NextConfig } from "next";

const nextConfig: NextConfig = {
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
  // Configure for Plotly.js compatibility
  webpack: (config) => {
    config.resolve.alias = {
      ...config.resolve.alias,
      // Fix for plotly.js
      'plotly.js/dist/plotly': 'plotly.js-dist-min'
    };
    return config;
  },
};

export default nextConfig;
