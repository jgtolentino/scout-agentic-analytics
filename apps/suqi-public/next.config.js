/** @type {import('next').NextConfig} */
const nextConfig = {
  env: {
    AZURE_SQL_SERVER: process.env.AZURE_SQL_SERVER || 'sqltbwaprojectscoutserver.database.windows.net',
    AZURE_SQL_DATABASE: process.env.AZURE_SQL_DATABASE || 'SQL-TBWA-ProjectScout-Reporting-Prod',
    AZURE_SQL_USER: process.env.AZURE_SQL_USER || 'sqladmin',
    AZURE_SQL_PASSWORD: process.env.AZURE_SQL_PASSWORD || 'Azure_pw26',
    AZURE_SQL_PORT: process.env.AZURE_SQL_PORT || '1433',
  },
  async headers() {
    return [
      {
        source: '/api/:path*',
        headers: [
          { key: 'Access-Control-Allow-Origin', value: '*' },
          { key: 'Access-Control-Allow-Methods', value: 'GET, POST, PUT, DELETE, OPTIONS' },
          { key: 'Access-Control-Allow-Headers', value: 'Content-Type, Authorization' },
        ],
      },
    ];
  },
  images: {
    domains: ['localhost'],
  },
  webpack: (config) => {
    config.externals.push({
      'utf-8-validate': 'commonjs utf-8-validate',
      'bufferutil': 'commonjs bufferutil',
    });
    return config;
  },
};

module.exports = nextConfig;