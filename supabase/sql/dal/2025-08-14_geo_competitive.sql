create table if not exists scout.ext_competitor_sales_by_region_daily (
  dte date not null,
  region text not null,
  brand  text not null,
  revenue_php numeric(14,2) not null,
  primary key (dte, region, brand)
);

create or replace view scout.gold_region_revenue_daily as
select date_trunc('day', t.sold_at)::date as dte,
       s.region,
       sum(t.total_amount) as revenue_php
from scout.gold_transactions t
join scout.dim_store s on s.store_id_nk = t.store_id and s.is_current
group by 1,2;

create or replace function dal.get_region_revenue_summary(p_start date, p_end date)
returns table(region text, revenue_php numeric, growth_pct numeric)
language sql stable as $func$
  with cur as (
    select region, sum(revenue_php) rev
    from scout.gold_region_revenue_daily
    where dte >= p_start and dte < (p_end + interval '1 day')
    group by 1
  ),
  prev as (
    select region, sum(revenue_php) rev
    from scout.gold_region_revenue_daily
    where dte >= (p_start - (p_end - p_start + 1)) and dte < p_start
    group by 1
  )
  select coalesce(c.region,p.region) as region,
         coalesce(c.rev,0) as revenue_php,
         case when coalesce(p.rev,0)=0 then null
              else round(100*(coalesce(c.rev,0) - p.rev)/p.rev, 1) end as growth_pct
  from cur c full join prev p using(region)
  where coalesce(c.region,p.region) is not null
  order by 1;
$func$;

create or replace function dal.get_market_share_by_region(p_start date, p_end date)
returns table(region text, our_share_pct numeric, top_competitor text, top_comp_share_pct numeric, delta_pct numeric)
language sql stable as $func$
  with our_cur as (
    select region, sum(revenue_php) rev
    from scout.gold_region_revenue_daily
    where dte >= p_start and dte < (p_end + interval '1 day')
    group by 1
  ),
  comp_cur as (
    select region, brand, sum(revenue_php) rev
    from scout.ext_competitor_sales_by_region_daily
    where dte >= p_start and dte < (p_end + interval '1 day')
    group by 1,2
  ),
  totals as (
    select coalesce(o.region, c.region) region,
           coalesce(o.rev,0) as our_rev,
           coalesce(sum(c.rev),0) as comp_rev
    from our_cur o
    full join comp_cur c using(region)
    group by 1,2
  ),
  top_comp as (
    select region, brand, rev,
           row_number() over(partition by region order by rev desc) rn
    from comp_cur
  )
  select t.region,
         case when (t.our_rev + t.comp_rev)=0 then null
              else round(100*t.our_rev/(t.our_rev+t.comp_rev),1) end as our_share_pct,
         tc.brand as top_competitor,
         case when (t.our_rev + t.comp_rev)=0 then null
              else round(100*coalesce(tc.rev,0)/(t.our_rev+t.comp_rev),1) end as top_comp_share_pct,
         case when (t.our_rev + t.comp_rev)=0 then null
              else round(100*t.our_rev/(t.our_rev+t.comp_rev),1)
                   - round(100*coalesce(tc.rev,0)/(t.our_rev+t.comp_rev),1) end as delta_pct
  from totals t
  left join top_comp tc on tc.region=t.region and tc.rn=1
  order by our_share_pct desc nulls last;
$func$;
