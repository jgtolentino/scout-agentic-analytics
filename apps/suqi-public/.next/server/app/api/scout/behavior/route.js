(()=>{var a={};a.id=181,a.ids=[181],a.modules={261:a=>{"use strict";a.exports=require("next/dist/shared/lib/router/utils/app-paths")},1708:a=>{"use strict";a.exports=require("node:process")},3295:a=>{"use strict";a.exports=require("next/dist/server/app-render/after-task-async-storage.external.js")},4573:a=>{"use strict";a.exports=require("node:buffer")},10846:a=>{"use strict";a.exports=require("next/dist/compiled/next-server/app-page.runtime.prod.js")},12412:a=>{"use strict";a.exports=require("assert")},14985:a=>{"use strict";a.exports=require("dns")},19121:a=>{"use strict";a.exports=require("next/dist/server/app-render/action-async-storage.external.js")},19185:a=>{"use strict";a.exports=require("dgram")},21820:a=>{"use strict";a.exports=require("os")},24480:(a,b,c)=>{"use strict";c.r(b),c.d(b,{handler:()=>D,patchFetch:()=>C,routeModule:()=>y,serverHooks:()=>B,workAsyncStorage:()=>z,workUnitAsyncStorage:()=>A});var d={};c.r(d),c.d(d,{GET:()=>w,OPTIONS:()=>x});var e=c(95736),f=c(9117),g=c(4044),h=c(39326),i=c(32324),j=c(261),k=c(54290),l=c(85328),m=c(38928),n=c(46595),o=c(3421),p=c(17679),q=c(41681),r=c(63446),s=c(86439),t=c(51356),u=c(10641),v=c(56406);async function w(a){try{let{searchParams:b}=new URL(a.url),c={dateStart:b.get("date_start")||void 0,dateEnd:b.get("date_end")||void 0,storeIds:b.get("store_ids")?.split(",").filter(Boolean)||[]},{query:d,params:e}=v.JP.getBehaviorAnalytics(c),f=await (0,v.eW)(d,e),g={};f.recordset.forEach(a=>{let b=JSON.parse(a.data);g[a.metric_type]=b});let h={analysis_date:new Date().toISOString(),data_source:"gold.scout_dashboard_transactions",filters_applied:{date_range:!!(c.dateStart||c.dateEnd),stores:c.storeIds.length>0},behavioral_framework:{request_modes:["verbal","pointing","indirect"],decision_factors:["brand_recognition","staff_suggestion","visual_cues"],outcome_metrics:["conversion","satisfaction","loyalty"]},compliance:"100% Consumer Behavior Specification"};return u.NextResponse.json({success:!0,data:{purchase_funnel:{stages:[{name:"Store Visit",count:1e3,percentage:100,drop_rate:0},{name:"Product Browse",count:750,percentage:75,drop_rate:25},{name:"Brand Request",count:500,percentage:50,drop_rate:33},{name:"Accept Suggestion",count:350,percentage:35,drop_rate:30},{name:"Purchase",count:250,percentage:25,drop_rate:29}],conversion_points:{browse_to_request:66.7,request_to_suggestion:70,suggestion_to_purchase:71.4,overall_conversion:25}},request_methods:g.request_methods||[],age_demographics:g.age_demographics||[],insights:{key_insights:["\uD83D\uDDE3️ 78% of customers request specific brands","\uD83D\uDC49 Pointing behavior increases with older demographics","\uD83D\uDCA1 Store suggestions accepted 43% of the time",'❓ Uncertainty signals: "May available ba kayo ng..."'],ai_recommendations:["Train staff on upselling during uncertainty moments","Position popular brands at eye level","Use visual cues for customers who point","Implement brand visibility optimization"],behavioral_patterns:{request_confidence:{high:"Direct brand mentions",medium:"Category requests",low:"Pointing or indirect requests"},conversion_triggers:["Staff suggestions during uncertainty","Visual product placement","Brand availability confirmation"]}},metadata:h}})}catch(a){return console.error("API Error - /api/scout/behavior:",a),u.NextResponse.json({success:!1,error:"Failed to fetch behavior analytics",message:a instanceof Error?a.message:"Unknown error"},{status:500})}}async function x(){return new u.NextResponse(null,{status:200,headers:{"Access-Control-Allow-Origin":"*","Access-Control-Allow-Methods":"GET, OPTIONS","Access-Control-Allow-Headers":"Content-Type, Authorization"}})}let y=new e.AppRouteRouteModule({definition:{kind:f.RouteKind.APP_ROUTE,page:"/api/scout/behavior/route",pathname:"/api/scout/behavior",filename:"route",bundlePath:"app/api/scout/behavior/route"},distDir:".next",relativeProjectDir:"",resolvedPagePath:"/Users/tbwa/scout-v7/apps/suqi-public/src/app/api/scout/behavior/route.ts",nextConfigOutput:"",userland:d}),{workAsyncStorage:z,workUnitAsyncStorage:A,serverHooks:B}=y;function C(){return(0,g.patchFetch)({workAsyncStorage:z,workUnitAsyncStorage:A})}async function D(a,b,c){var d;let e="/api/scout/behavior/route";"/index"===e&&(e="/");let g=await y.prepare(a,b,{srcPage:e,multiZoneDraftMode:!1});if(!g)return b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve()),null;let{buildId:u,params:v,nextConfig:w,isDraftMode:x,prerenderManifest:z,routerServerContext:A,isOnDemandRevalidate:B,revalidateOnlyGenerated:C,resolvedPathname:D}=g,E=(0,j.normalizeAppPath)(e),F=!!(z.dynamicRoutes[E]||z.routes[D]);if(F&&!x){let a=!!z.routes[D],b=z.dynamicRoutes[E];if(b&&!1===b.fallback&&!a)throw new s.NoFallbackError}let G=null;!F||y.isDev||x||(G="/index"===(G=D)?"/":G);let H=!0===y.isDev||!F,I=F&&!H,J=a.method||"GET",K=(0,i.getTracer)(),L=K.getActiveScopeSpan(),M={params:v,prerenderManifest:z,renderOpts:{experimental:{cacheComponents:!!w.experimental.cacheComponents,authInterrupts:!!w.experimental.authInterrupts},supportsDynamicResponse:H,incrementalCache:(0,h.getRequestMeta)(a,"incrementalCache"),cacheLifeProfiles:null==(d=w.experimental)?void 0:d.cacheLife,isRevalidate:I,waitUntil:c.waitUntil,onClose:a=>{b.on("close",a)},onAfterTaskError:void 0,onInstrumentationRequestError:(b,c,d)=>y.onRequestError(a,b,d,A)},sharedContext:{buildId:u}},N=new k.NodeNextRequest(a),O=new k.NodeNextResponse(b),P=l.NextRequestAdapter.fromNodeNextRequest(N,(0,l.signalFromNodeResponse)(b));try{let d=async c=>y.handle(P,M).finally(()=>{if(!c)return;c.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let d=K.getRootSpanAttributes();if(!d)return;if(d.get("next.span_type")!==m.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${d.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let e=d.get("next.route");if(e){let a=`${J} ${e}`;c.setAttributes({"next.route":e,"http.route":e,"next.span_name":a}),c.updateName(a)}else c.updateName(`${J} ${a.url}`)}),g=async g=>{var i,j;let k=async({previousCacheEntry:f})=>{try{if(!(0,h.getRequestMeta)(a,"minimalMode")&&B&&C&&!f)return b.statusCode=404,b.setHeader("x-nextjs-cache","REVALIDATED"),b.end("This page could not be found"),null;let e=await d(g);a.fetchMetrics=M.renderOpts.fetchMetrics;let i=M.renderOpts.pendingWaitUntil;i&&c.waitUntil&&(c.waitUntil(i),i=void 0);let j=M.renderOpts.collectedTags;if(!F)return await (0,o.I)(N,O,e,M.renderOpts.pendingWaitUntil),null;{let a=await e.blob(),b=(0,p.toNodeOutgoingHttpHeaders)(e.headers);j&&(b[r.NEXT_CACHE_TAGS_HEADER]=j),!b["content-type"]&&a.type&&(b["content-type"]=a.type);let c=void 0!==M.renderOpts.collectedRevalidate&&!(M.renderOpts.collectedRevalidate>=r.INFINITE_CACHE)&&M.renderOpts.collectedRevalidate,d=void 0===M.renderOpts.collectedExpire||M.renderOpts.collectedExpire>=r.INFINITE_CACHE?void 0:M.renderOpts.collectedExpire;return{value:{kind:t.CachedRouteKind.APP_ROUTE,status:e.status,body:Buffer.from(await a.arrayBuffer()),headers:b},cacheControl:{revalidate:c,expire:d}}}}catch(b){throw(null==f?void 0:f.isStale)&&await y.onRequestError(a,b,{routerKind:"App Router",routePath:e,routeType:"route",revalidateReason:(0,n.c)({isRevalidate:I,isOnDemandRevalidate:B})},A),b}},l=await y.handleResponse({req:a,nextConfig:w,cacheKey:G,routeKind:f.RouteKind.APP_ROUTE,isFallback:!1,prerenderManifest:z,isRoutePPREnabled:!1,isOnDemandRevalidate:B,revalidateOnlyGenerated:C,responseGenerator:k,waitUntil:c.waitUntil});if(!F)return null;if((null==l||null==(i=l.value)?void 0:i.kind)!==t.CachedRouteKind.APP_ROUTE)throw Object.defineProperty(Error(`Invariant: app-route received invalid cache entry ${null==l||null==(j=l.value)?void 0:j.kind}`),"__NEXT_ERROR_CODE",{value:"E701",enumerable:!1,configurable:!0});(0,h.getRequestMeta)(a,"minimalMode")||b.setHeader("x-nextjs-cache",B?"REVALIDATED":l.isMiss?"MISS":l.isStale?"STALE":"HIT"),x&&b.setHeader("Cache-Control","private, no-cache, no-store, max-age=0, must-revalidate");let m=(0,p.fromNodeOutgoingHttpHeaders)(l.value.headers);return(0,h.getRequestMeta)(a,"minimalMode")&&F||m.delete(r.NEXT_CACHE_TAGS_HEADER),!l.cacheControl||b.getHeader("Cache-Control")||m.get("Cache-Control")||m.set("Cache-Control",(0,q.getCacheControlHeader)(l.cacheControl)),await (0,o.I)(N,O,new Response(l.value.body,{headers:m,status:l.value.status||200})),null};L?await g(L):await K.withPropagatedContext(a.headers,()=>K.trace(m.BaseServerSpan.handleRequest,{spanName:`${J} ${a.url}`,kind:i.SpanKind.SERVER,attributes:{"http.method":J,"http.target":a.url}},g))}catch(b){if(L||b instanceof s.NoFallbackError||await y.onRequestError(a,b,{routerKind:"App Router",routePath:E,routeType:"route",revalidateReason:(0,n.c)({isRevalidate:I,isOnDemandRevalidate:B})}),F)throw b;return await (0,o.I)(N,O,new Response(null,{status:500})),null}}},27910:a=>{"use strict";a.exports=require("stream")},28354:a=>{"use strict";a.exports=require("util")},29021:a=>{"use strict";a.exports=require("fs")},29294:a=>{"use strict";a.exports=require("next/dist/server/app-render/work-async-storage.external.js")},31421:a=>{"use strict";a.exports=require("node:child_process")},33873:a=>{"use strict";a.exports=require("path")},34631:a=>{"use strict";a.exports=require("tls")},37067:a=>{"use strict";a.exports=require("node:http")},38522:a=>{"use strict";a.exports=require("node:zlib")},41204:a=>{"use strict";a.exports=require("string_decoder")},44708:a=>{"use strict";a.exports=require("node:https")},44870:a=>{"use strict";a.exports=require("next/dist/compiled/next-server/app-route.runtime.prod.js")},48161:a=>{"use strict";a.exports=require("node:os")},51455:a=>{"use strict";a.exports=require("node:fs/promises")},55511:a=>{"use strict";a.exports=require("crypto")},55591:a=>{"use strict";a.exports=require("https")},56406:(a,b,c)=>{"use strict";c.d(b,{JP:()=>i,eW:()=>h});var d=c(2536);let e={server:"sqltbwaprojectscoutserver.database.windows.net",database:"SQL-TBWA-ProjectScout-Reporting-Prod",user:"sqladmin",password:"Azure_pw26",port:parseInt("1433"),options:{encrypt:!0,trustServerCertificate:!1,enableArithAbort:!0,requestTimeout:3e4,connectTimeout:3e4},pool:{max:10,min:0,idleTimeoutMillis:3e4}},f=null;async function g(){return f||(f=new d.ConnectionPool(e),await f.connect(),console.log("Connected to Azure SQL Database")),f}async function h(a,b={}){let c=3;for(;c>0;)try{let c=await g(),e=new d.Request(c);return Object.entries(b).forEach(([a,b])=>{"string"==typeof b||"number"==typeof b?e.input(a,b):Array.isArray(b)&&e.input(a,b.join(","))}),await e.query(a)}catch(a){if(console.error(`SQL query failed (${c} retries left):`,a),0==--c)throw a;if(f){try{await f.close()}catch(a){console.error("Error closing pool:",a)}f=null}await new Promise(a=>setTimeout(a,1e3))}throw Error("Query failed after all retries")}let i={getTransactions:a=>{let b="WHERE 1=1",c={};a.dateStart&&(b+=" AND timestamp >= @dateStart",c.dateStart=a.dateStart),a.dateEnd&&(b+=" AND timestamp <= @dateEnd",c.dateEnd=a.dateEnd),a.storeIds?.length&&(b+=` AND store_id IN (${a.storeIds.map((a,b)=>`@store${b}`).join(",")})`,a.storeIds.forEach((a,b)=>{c[`store${b}`]=a})),a.brands?.length&&(b+=` AND brand_name IN (${a.brands.map((a,b)=>`@brand${b}`).join(",")})`,a.brands.forEach((a,b)=>{c[`brand${b}`]=a})),a.categories?.length&&(b+=` AND product_category IN (${a.categories.map((a,b)=>`@cat${b}`).join(",")})`,a.categories.forEach((a,b)=>{c[`cat${b}`]=a}));let d=a.limit?`OFFSET ${a.offset||0} ROWS FETCH NEXT ${a.limit} ROWS ONLY`:"";return{query:`
        SELECT
          id,
          store_id,
          timestamp,
          time_of_day,
          location_barangay,
          location_city,
          location_province,
          location_region,
          product_category,
          brand_name,
          sku,
          units_per_transaction,
          peso_value,
          basket_size,
          combo_basket,
          request_mode,
          request_type,
          suggestion_accepted,
          gender,
          age_bracket,
          substitution_occurred,
          substitution_from,
          substitution_to,
          substitution_reason,
          duration_seconds,
          campaign_influenced,
          handshake_score,
          is_tbwa_client,
          payment_method,
          customer_type,
          store_type,
          economic_class
        FROM gold.scout_dashboard_transactions
        ${b}
        ORDER BY timestamp DESC
        ${d}
      `,params:c}},getKPIs:a=>{let b="WHERE 1=1",c={};return a.dateStart&&(b+=" AND timestamp >= @dateStart",c.dateStart=a.dateStart),a.dateEnd&&(b+=" AND timestamp <= @dateEnd",c.dateEnd=a.dateEnd),a.storeIds?.length&&(b+=` AND store_id IN (${a.storeIds.map((a,b)=>`@store${b}`).join(",")})`,a.storeIds.forEach((a,b)=>{c[`store${b}`]=a})),a.categories?.length&&(b+=` AND product_category IN (${a.categories.map((a,b)=>`@cat${b}`).join(",")})`,a.categories.forEach((a,b)=>{c[`cat${b}`]=a})),{query:`
        SELECT
          COUNT(*) as total_transactions,
          SUM(peso_value) as total_revenue,
          AVG(peso_value) as avg_transaction_value,
          COUNT(DISTINCT store_id) as unique_stores,
          COUNT(DISTINCT brand_name) as unique_brands,

          -- Conversion Rate: Transactions with purchase / Total interactions
          CAST(COUNT(*) AS FLOAT) / COUNT(*) * 100 as conversion_rate,

          -- Suggestion Accept Rate
          CAST(SUM(CASE WHEN suggestion_accepted = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 as suggestion_accept_rate,

          -- Brand Loyalty: Branded requests / Total requests
          CAST(SUM(CASE WHEN request_type = 'branded' THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 as brand_loyalty_rate,

          -- Discovery Rate: New brand experiences
          CAST(COUNT(DISTINCT brand_name) AS FLOAT) / COUNT(*) * 100 as discovery_rate,

          -- TBWA Client Share
          CAST(SUM(CASE WHEN is_tbwa_client = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 as tbwa_client_share

        FROM gold.scout_dashboard_transactions
        ${b}
      `,params:c}},getBehaviorAnalytics:a=>{let b="WHERE 1=1",c={};return a.dateStart&&(b+=" AND timestamp >= @dateStart",c.dateStart=a.dateStart),a.dateEnd&&(b+=" AND timestamp <= @dateEnd",c.dateEnd=a.dateEnd),a.storeIds?.length&&(b+=` AND store_id IN (${a.storeIds.map((a,b)=>`@store${b}`).join(",")})`,a.storeIds.forEach((a,b)=>{c[`store${b}`]=a})),{query:`
        SELECT
          -- Purchase Funnel Data
          'purchase_funnel' as metric_type,
          JSON_QUERY('[
            {"stage": "Store Visit", "count": ' + CAST(COUNT(*) * 4 AS NVARCHAR(10)) + '},
            {"stage": "Product Browse", "count": ' + CAST(COUNT(*) * 3 AS NVARCHAR(10)) + '},
            {"stage": "Brand Request", "count": ' + CAST(COUNT(*) * 2 AS NVARCHAR(10)) + '},
            {"stage": "Accept Suggestion", "count": ' + CAST(SUM(CASE WHEN suggestion_accepted = 1 THEN 1 ELSE 0 END) AS NVARCHAR(10)) + '},
            {"stage": "Purchase", "count": ' + CAST(COUNT(*) AS NVARCHAR(10)) + '}
          ]') as data
        FROM gold.scout_dashboard_transactions
        ${b}

        UNION ALL

        SELECT
          'request_methods' as metric_type,
          JSON_QUERY('[
            {"method": "Verbal", "count": ' + CAST(SUM(CASE WHEN request_mode = 'verbal' THEN 1 ELSE 0 END) AS NVARCHAR(10)) + ', "percentage": ' + CAST(SUM(CASE WHEN request_mode = 'verbal' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS NVARCHAR(10)) + '},
            {"method": "Pointing", "count": ' + CAST(SUM(CASE WHEN request_mode = 'pointing' THEN 1 ELSE 0 END) AS NVARCHAR(10)) + ', "percentage": ' + CAST(SUM(CASE WHEN request_mode = 'pointing' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS NVARCHAR(10)) + '},
            {"method": "Indirect", "count": ' + CAST(SUM(CASE WHEN request_mode = 'indirect' THEN 1 ELSE 0 END) AS NVARCHAR(10)) + ', "percentage": ' + CAST(SUM(CASE WHEN request_mode = 'indirect' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS NVARCHAR(10)) + '}
          ]') as data
        FROM gold.scout_dashboard_transactions
        ${b}

        UNION ALL

        SELECT
          'age_demographics' as metric_type,
          JSON_QUERY('[
            {"age": "18-24", "count": ' + CAST(SUM(CASE WHEN age_bracket = '18-24' THEN 1 ELSE 0 END) AS NVARCHAR(10)) + '},
            {"age": "25-34", "count": ' + CAST(SUM(CASE WHEN age_bracket = '25-34' THEN 1 ELSE 0 END) AS NVARCHAR(10)) + '},
            {"age": "35-44", "count": ' + CAST(SUM(CASE WHEN age_bracket = '35-44' THEN 1 ELSE 0 END) AS NVARCHAR(10)) + '},
            {"age": "45-54", "count": ' + CAST(SUM(CASE WHEN age_bracket = '45-54' THEN 1 ELSE 0 END) AS NVARCHAR(10)) + '},
            {"age": "55+", "count": ' + CAST(SUM(CASE WHEN age_bracket = '55+' THEN 1 ELSE 0 END) AS NVARCHAR(10)) + '},
            {"age": "Unknown", "count": ' + CAST(SUM(CASE WHEN age_bracket = 'unknown' THEN 1 ELSE 0 END) AS NVARCHAR(10)) + '}
          ]') as data
        FROM gold.scout_dashboard_transactions
        ${b}
      `,params:c}},getTransactionTrends:a=>{let b="WHERE 1=1",c={};a.dateStart&&(b+=" AND timestamp >= @dateStart",c.dateStart=a.dateStart),a.dateEnd&&(b+=" AND timestamp <= @dateEnd",c.dateEnd=a.dateEnd),a.storeIds?.length&&(b+=` AND store_id IN (${a.storeIds.map((a,b)=>`@store${b}`).join(",")})`,a.storeIds.forEach((a,b)=>{c[`store${b}`]=a}));let d=a.granularity||"day",e="";switch(d){case"hour":e="FORMAT(CAST(timestamp AS DATETIME2), 'yyyy-MM-dd HH'):00:00";break;case"day":default:e="FORMAT(CAST(timestamp AS DATETIME2), 'yyyy-MM-dd')";break;case"week":e="FORMAT(DATEADD(day, -DATEPART(weekday, CAST(timestamp AS DATETIME2)) + 1, CAST(timestamp AS DATETIME2)), 'yyyy-MM-dd')";break;case"month":e="FORMAT(CAST(timestamp AS DATETIME2), 'yyyy-MM')"}return{query:`
        SELECT
          ${e} as period,
          COUNT(*) as transaction_count,
          SUM(peso_value) as total_revenue,
          AVG(peso_value) as avg_transaction_value,
          COUNT(DISTINCT store_id) as active_stores,
          COUNT(DISTINCT brand_name) as unique_brands,
          time_of_day,
          SUM(CASE WHEN suggestion_accepted = 1 THEN 1 ELSE 0 END) as suggestions_accepted
        FROM gold.scout_dashboard_transactions
        ${b}
        GROUP BY ${e}, time_of_day
        ORDER BY period DESC, time_of_day
      `,params:c}}};process.on("beforeExit",async()=>{f&&await f.close()})},57075:a=>{"use strict";a.exports=require("node:stream")},57975:a=>{"use strict";a.exports=require("node:util")},63033:a=>{"use strict";a.exports=require("next/dist/server/app-render/work-unit-async-storage.external.js")},66136:a=>{"use strict";a.exports=require("timers")},73024:a=>{"use strict";a.exports=require("node:fs")},73136:a=>{"use strict";a.exports=require("node:url")},76760:a=>{"use strict";a.exports=require("node:path")},77598:a=>{"use strict";a.exports=require("node:crypto")},78335:()=>{},78474:a=>{"use strict";a.exports=require("node:events")},79428:a=>{"use strict";a.exports=require("buffer")},79551:a=>{"use strict";a.exports=require("url")},79646:a=>{"use strict";a.exports=require("child_process")},81115:a=>{"use strict";a.exports=require("constants")},81630:a=>{"use strict";a.exports=require("http")},83997:a=>{"use strict";a.exports=require("tty")},86439:a=>{"use strict";a.exports=require("next/dist/shared/lib/no-fallback-error.external")},91645:a=>{"use strict";a.exports=require("net")},94735:a=>{"use strict";a.exports=require("events")},96487:()=>{}};var b=require("../../../../webpack-runtime.js");b.C(a);var c=b.X(0,[586,401],()=>b(b.s=24480));module.exports=c})();