import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function middleware(req: NextRequest) {
  const res = NextResponse.next();

  // CORS headers for public export API
  if (req.nextUrl.pathname.startsWith('/api/export')) {
    res.headers.set("Access-Control-Allow-Origin", "*");           // or restrict to your domains
    res.headers.set("Access-Control-Allow-Methods", "GET,POST");
    res.headers.set("Access-Control-Allow-Headers", "Content-Type");
    res.headers.set("X-Content-Type-Options", "nosniff");
    res.headers.set("Cache-Control", "no-store");                   // exports should be fresh
    res.headers.set("X-Frame-Options", "DENY");
    res.headers.set("X-Scout-API-Version", "1.0.0");
  }

  return res;
}

export const config = {
  matcher: '/api/export/:path*'
};