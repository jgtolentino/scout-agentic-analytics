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
