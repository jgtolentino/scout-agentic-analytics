/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',             // good for Vercel & Docker
  experimental: { typedRoutes: true }
};
export default nextConfig;