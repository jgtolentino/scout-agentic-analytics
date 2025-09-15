(globalThis.TURBOPACK || (globalThis.TURBOPACK = [])).push(["chunks/[root-of-the-server]__f2b15f93._.js",
"[externals]/node:buffer [external] (node:buffer, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("node:buffer", () => require("node:buffer"));

module.exports = mod;
}),
"[externals]/node:async_hooks [external] (node:async_hooks, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("node:async_hooks", () => require("node:async_hooks"));

module.exports = mod;
}),
"[project]/middleware.ts [middleware-edge] (ecmascript)", ((__turbopack_context__) => {
"use strict";

__turbopack_context__.s([
    "config",
    ()=>config,
    "middleware",
    ()=>middleware
]);
var __TURBOPACK__imported__module__$5b$project$5d2f$scout$2d$v7$2f$apps$2f$standalone$2d$dashboard$2d$nextjs$2f$node_modules$2f$next$2f$dist$2f$esm$2f$api$2f$server$2e$js__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__$3c$locals$3e$__ = __turbopack_context__.i("[project]/scout-v7/apps/standalone-dashboard-nextjs/node_modules/next/dist/esm/api/server.js [middleware-edge] (ecmascript) <locals>");
var __TURBOPACK__imported__module__$5b$project$5d2f$scout$2d$v7$2f$apps$2f$standalone$2d$dashboard$2d$nextjs$2f$node_modules$2f$next$2f$dist$2f$esm$2f$server$2f$web$2f$exports$2f$index$2e$js__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/scout-v7/apps/standalone-dashboard-nextjs/node_modules/next/dist/esm/server/web/exports/index.js [middleware-edge] (ecmascript)");
;
function middleware(request) {
    const { pathname, searchParams } = request.nextUrl;
    const isAgentCall = pathname.startsWith('/api/agent');
    const isHealthCheck = pathname === '/api/health' || pathname === '/api/ping';
    // Log all Pulser-related API calls
    if (isAgentCall || isHealthCheck) {
        const timestamp = new Date().toISOString();
        const userAgent = request.headers.get('user-agent') || 'unknown';
        const ip = request.ip || request.headers.get('x-forwarded-for') || 'unknown';
        console.log(`[Pulser Middleware] ${request.method} ${pathname}`, {
            timestamp,
            ip,
            userAgent: userAgent.substring(0, 100),
            hasAuth: !!request.headers.get('authorization'),
            queryParams: Object.fromEntries(searchParams.entries())
        });
        // Add request ID for tracing
        const requestId = `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        const response = __TURBOPACK__imported__module__$5b$project$5d2f$scout$2d$v7$2f$apps$2f$standalone$2d$dashboard$2d$nextjs$2f$node_modules$2f$next$2f$dist$2f$esm$2f$server$2f$web$2f$exports$2f$index$2e$js__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__["NextResponse"].next();
        response.headers.set('x-pulser-request-id', requestId);
        return response;
    }
    // Security headers for all requests
    const response = __TURBOPACK__imported__module__$5b$project$5d2f$scout$2d$v7$2f$apps$2f$standalone$2d$dashboard$2d$nextjs$2f$node_modules$2f$next$2f$dist$2f$esm$2f$server$2f$web$2f$exports$2f$index$2e$js__$5b$middleware$2d$edge$5d$__$28$ecmascript$29$__["NextResponse"].next();
    // Add security headers in production
    if ("TURBOPACK compile-time falsy", 0) //TURBOPACK unreachable
    ;
    return response;
}
const config = {
    matcher: [
        '/api/agent/:path*',
        '/api/health',
        '/api/ping',
        '/((?!_next/static|_next/image|favicon.ico).*)'
    ]
};
}),
]);

//# sourceMappingURL=%5Broot-of-the-server%5D__f2b15f93._.js.map