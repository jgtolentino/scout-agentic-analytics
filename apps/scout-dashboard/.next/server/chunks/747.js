"use strict";exports.id=747,exports.ids=[747],exports.modules={9747:(t,a,e)=>{e.d(a,{jv:()=>o});var r=e(9424),s=e.n(r);let AzureScoutClient=class AzureScoutClient{constructor(){this.pool=null,this.cache=new Map,this.config={server:process.env.AZURE_SQL_SERVER||"",database:process.env.AZURE_SQL_DATABASE||"",user:process.env.AZURE_SQL_USER||"",password:process.env.AZURE_SQL_PASSWORD||"",options:{encrypt:!0,trustServerCertificate:!1,enableArithAbort:!0,requestTimeout:3e4,connectTimeout:3e4},pool:{max:10,min:0,idleTimeoutMillis:3e4}}}async getConnection(){return this.pool||(this.pool=new(s()).ConnectionPool(this.config),await this.pool.connect()),this.pool}async getTransactions(t={},a={}){let e=Date.now();try{let r=`transactions_${JSON.stringify({filters:t,options:a})}`,s=this.getFromCache(r);if(s)return{data:s,meta:{total:s.length,page:1,limit:s.length,has_more:!1},cache:{hit:!0,ttl:300},performance:{query_time_ms:Date.now()-e,row_count:s.length}};let o=await this.getConnection(),n=o.request(),i=`
        SELECT
          CanonicalTransactionID as transaction_id,
          FacialID as facial_id,
          StoreID as store_id,
          StoreName as store_name,
          Brand as brand,
          Category as category,
          TotalPrice as total_price,
          Age as age,
          Gender as gender,
          TransactionDate as transaction_ts,
          GeoLatitude as latitude,
          GeoLongitude as longitude,
          Municipality as municipality,
          Barangay as barangay,
          TimeOfDay as time_of_day
        FROM scout.gold_transactions_flat
        WHERE 1=1
      `;t.store_ids?.length&&(i+=` AND StoreID IN (${t.store_ids.map(t=>`'${t}'`).join(",")})`),t.brands?.length&&(i+=` AND Brand IN (${t.brands.map(t=>`'${t}'`).join(",")})`),t.categories?.length&&(i+=` AND Category IN (${t.categories.map(t=>`'${t}'`).join(",")})`),t.date_range&&(i+=` AND TransactionDate >= '${t.date_range.start}' AND TransactionDate <= '${t.date_range.end}'`),t.genders?.length&&(i+=` AND Gender IN (${t.genders.map(t=>`'${t}'`).join(",")})`),t.municipalities?.length&&(i+=` AND Municipality IN (${t.municipalities.map(t=>`'${t}'`).join(",")})`),t.min_amount&&(i+=` AND TotalPrice >= ${t.min_amount}`),t.max_amount&&(i+=` AND TotalPrice <= ${t.max_amount}`);let c=a.sort_by||"TransactionDate",l=a.sort_order||"desc";i+=` ORDER BY ${c} ${l.toUpperCase()}`;let _=Math.min(a.limit||1e3,1e4),d=a.offset||0;i+=` OFFSET ${d} ROWS FETCH NEXT ${_} ROWS ONLY`;let u=await n.query(i),g=u.recordset;return this.setCache(r,g,300),{data:g,meta:{total:g.length,page:Math.floor(d/_)+1,limit:_,has_more:g.length===_},cache:{hit:!1,ttl:300},performance:{query_time_ms:Date.now()-e,row_count:g.length}}}catch(t){throw console.error("Error fetching transactions:",t),t}}async getKPIs(t={}){let a=Date.now();try{let e=await this.getConnection(),r=e.request(),s="WHERE 1=1";t.store_ids?.length&&(s+=` AND StoreID IN (${t.store_ids.map(t=>`'${t}'`).join(",")})`),t.date_range&&(s+=` AND TransactionDate >= '${t.date_range.start}' AND TransactionDate <= '${t.date_range.end}'`);let o=`
        SELECT
          COUNT(*) as total_transactions,
          COUNT(DISTINCT FacialID) as unique_customers,
          SUM(TotalPrice) as total_revenue,
          AVG(TotalPrice) as avg_transaction_value,
          COUNT(DISTINCT StoreID) as active_stores,
          COUNT(DISTINCT Brand) as unique_brands
        FROM scout.gold_transactions_flat
        ${s}
      `,n=await r.query(o),i=n.recordset[0];return{data:{total_revenue:{value:parseFloat(i.total_revenue||0),change:8.4,trend:"up",period:"vs last 30 days"},total_transactions:{value:parseInt(i.total_transactions||0),change:12.3,trend:"up",period:"vs last 30 days"},avg_transaction_value:{value:parseFloat(i.avg_transaction_value||0),change:-3.2,trend:"down",period:"vs last 30 days"},unique_customers:{value:parseInt(i.unique_customers||0),change:15.7,trend:"up",period:"vs last 30 days"}},performance:{query_time_ms:Date.now()-a,row_count:1}}}catch(t){throw console.error("Error fetching KPIs:",t),t}}async getBrandPerformance(t={}){let a=Date.now();try{let e=await this.getConnection(),r=e.request(),s="WHERE 1=1";t.date_range&&(s+=` AND TransactionDate >= '${t.date_range.start}' AND TransactionDate <= '${t.date_range.end}'`);let o=`
        SELECT
          Brand as brand,
          COUNT(*) as total_transactions,
          COUNT(DISTINCT FacialID) as unique_customers,
          SUM(TotalPrice) as total_revenue,
          AVG(TotalPrice) as avg_transaction_value,
          COUNT(DISTINCT StoreID) as store_presence
        FROM scout.gold_transactions_flat
        ${s}
        GROUP BY Brand
        ORDER BY total_revenue DESC
      `,n=await r.query(o),i=n.recordset.map(t=>({brand_name:t.brand,category:"General",market_share_percent:0,consumer_reach_points:t.unique_customers||0,position_type:"follower",avg_price_php:parseFloat(t.avg_transaction_value||0),min_price_php:.8*parseFloat(t.avg_transaction_value||0),max_price_php:1.2*parseFloat(t.avg_transaction_value||0),price_volatility:.1,vs_category_avg:1,brand_tier:"Tier 3 - Established",value_proposition:"Mainstream",growth_status:"Stable",brand_growth_yoy:0,channels_available:t.store_presence||1,channel_list:"Retail",direct_competitors:5,last_updated:new Date().toISOString(),confidence_score:.85}));return{data:i,cache:{hit:!1,ttl:300},performance:{query_time_ms:Date.now()-a,row_count:i.length}}}catch(t){throw console.error("Error fetching brand performance:",t),t}}async getStoreGeoData(){let t=Date.now();try{let a=await this.getConnection(),e=a.request(),r=`
        SELECT
          StoreID as store_id,
          StoreName as store_name,
          AVG(GeoLatitude) as latitude,
          AVG(GeoLongitude) as longitude,
          Municipality as municipality,
          COUNT(*) as total_transactions,
          COUNT(DISTINCT FacialID) as unique_customers,
          SUM(TotalPrice) as total_revenue,
          AVG(TotalPrice) as avg_transaction_value
        FROM scout.gold_transactions_flat
        WHERE GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL
        GROUP BY StoreID, StoreName, Municipality
        ORDER BY total_revenue DESC
      `,s=await e.query(r),o=s.recordset.map(t=>({store_id:t.store_id,store_name:t.store_name,latitude:parseFloat(t.latitude||0),longitude:parseFloat(t.longitude||0),municipality:t.municipality,total_revenue:parseFloat(t.total_revenue||0),total_transactions:t.total_transactions,unique_customers:t.unique_customers,avg_transaction_value:parseFloat(t.avg_transaction_value||0),performance_score:Math.min(100,t.total_transactions/100*10),status:"active"}));return{data:o,metadata:{total_stores:o.length,active_stores:o.length,data_source:"scout.gold_transactions_flat",last_updated:new Date().toISOString(),cache_status:"fresh",query_time_ms:Date.now()-t}}}catch(t){throw console.error("Error fetching store geo data:",t),t}}async getDataQualitySummary(){let t=Date.now();try{let a=await this.getConnection(),e=a.request(),r=`
        SELECT
          COUNT(*) as total_records,
          SUM(CASE WHEN CanonicalTransactionID IS NOT NULL THEN 1 ELSE 0 END) as valid_transaction_ids,
          SUM(CASE WHEN FacialID IS NOT NULL THEN 1 ELSE 0 END) as valid_facial_ids,
          SUM(CASE WHEN TotalPrice IS NOT NULL AND TotalPrice > 0 THEN 1 ELSE 0 END) as valid_prices,
          SUM(CASE WHEN Brand IS NOT NULL AND Brand != '' THEN 1 ELSE 0 END) as valid_brands,
          SUM(CASE WHEN Category IS NOT NULL AND Category != '' THEN 1 ELSE 0 END) as valid_categories,
          SUM(CASE WHEN GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL THEN 1 ELSE 0 END) as valid_coordinates
        FROM scout.gold_transactions_flat
      `,s=await e.query(r),o=s.recordset[0],n=o.total_records||1,i=o.valid_transaction_ids/n*100,c=o.valid_prices/n*100;return{data_quality:{overall_score:Math.round((i+c)/2*100)/100,total_records:n,valid_records:o.valid_transaction_ids,invalid_records:n-o.valid_transaction_ids,completeness:Math.round(100*i)/100,accuracy:Math.round(100*c)/100,consistency:97.9,timeliness:99.1},quality_checks:{transaction_ids:{success_rate:Math.round(o.valid_transaction_ids/n*1e4)/100,total:n,passed:o.valid_transaction_ids},facial_ids:{success_rate:Math.round(o.valid_facial_ids/n*1e4)/100,total:n,passed:o.valid_facial_ids},pricing_data:{success_rate:Math.round(o.valid_prices/n*1e4)/100,total:n,passed:o.valid_prices},geographic_data:{success_rate:Math.round(o.valid_coordinates/n*1e4)/100,total:n,passed:o.valid_coordinates}},performance:{query_time_ms:Date.now()-t}}}catch(t){throw console.error("Error fetching data quality summary:",t),t}}getFromCache(t){let a=this.cache.get(t);return a&&Date.now()<a.timestamp+1e3*a.ttl?a.data:(a&&this.cache.delete(t),null)}setCache(t,a,e){this.cache.set(t,{data:a,timestamp:Date.now(),ttl:e})}clearCache(){this.cache.clear()}async close(){this.pool&&(await this.pool.close(),this.pool=null)}};let o=new AzureScoutClient}};