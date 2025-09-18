-- Scout Gold Transactions Flat View
-- Creates a flattened view matching the CSV schema for seamless data mode switching

-- Drop existing view if it exists
drop view if exists public.scout_gold_transactions_flat;

-- Create the flattened view matching CSV column names exactly
create or replace view public.scout_gold_transactions_flat as
select
  -- Core transaction fields
  coalesce(i.category, 'Unknown') as category,
  coalesce(i.brand, 'Unknown') as brand,
  coalesce(i.brand_raw, i.brand, 'Unknown') as brand_raw,
  coalesce(i.product, 'Unknown') as product,
  coalesce(i.qty, 1) as qty,
  coalesce(i.unit, 'pc') as unit,
  coalesce(i.unit_price, 0.0) as unit_price,
  coalesce(i.total_price, 0.0) as total_price,

  -- Device and store information
  coalesce(t.device_id, 'Unknown') as device,
  coalesce(s.store_id, 0) as store,
  coalesce(s.store_name, 'Unknown') as storename,
  coalesce(s.location, 'Unknown') as storelocationmaster,
  s.store_device_id as storedeviceid,
  s.store_device_name as storedevicename,
  coalesce(s.location, 'Unknown') as location,
  t.transaction_id,

  -- Philippines timezone date/time fields
  to_char(t.transaction_date at time zone 'Asia/Manila', 'YYYY-MM-DD') as date_ph,
  to_char(t.transaction_date at time zone 'Asia/Manila', 'HH24:MI:SS.US') as time_ph,
  to_char(t.transaction_date at time zone 'Asia/Manila', 'Day') as day_of_week,
  case
    when extract(isodow from t.transaction_date at time zone 'Asia/Manila') in (6,7)
    then 'weekend'
    else 'weekday'
  end as weekday_weekend,
  case
    when extract(hour from t.transaction_date at time zone 'Asia/Manila') between 6 and 11 then 'morning'
    when extract(hour from t.transaction_date at time zone 'Asia/Manila') between 12 and 17 then 'afternoon'
    when extract(hour from t.transaction_date at time zone 'Asia/Manila') between 18 and 22 then 'evening'
    else 'night'
  end as time_of_day,

  -- Transaction metadata
  t.payment_method,
  t.bought_with_other_brands,
  t.transcript_audio,
  t.edge_version,
  i.sku,
  to_char(t.transaction_date at time zone 'Asia/Manila', 'YYYY-MM-DD HH24:MI:SS.US') as ts_ph,

  -- Demographics and interaction data (if available)
  d.facial_id as facialid,
  d.gender,
  d.emotion,
  d.age,
  d.age_bracket as agebracket,

  -- Store and interaction IDs
  s.store_id as storeid,
  t.interaction_id as interactionid,
  i.product_id as productid,
  t.transaction_date as transactiondate,
  t.device_id as deviceid,
  d.sex,
  d.age as age__query_4_1,
  d.emotional_state as emotionalstate,
  d.transcription_text as transcriptiontext,
  d.gender as gender__query_4_1,

  -- Location details
  s.barangay,
  s.store_name as storename__query_10,
  s.location as location__query_10,
  s.size,
  s.geo_latitude as geolatitude,
  s.geo_longitude as geolongitude,
  s.store_geometry as storegeometry,
  s.manager_name as managername,
  s.manager_contact_info as managercontactinfo,
  s.device_name as devicename,
  s.device_id as deviceid__query_10,
  s.barangay as barangay__query_10

from scout.bronze_edge_transactions t
left join scout.bronze_edge_items i on i.transaction_id = t.transaction_id
left join scout.bronze_azure_stores s on s.store_id = t.store_id
left join scout.bronze_azure_devices d on d.device_id = t.device_id
order by t.transaction_date desc;

-- Enable Row Level Security for read-only access
alter view public.scout_gold_transactions_flat set (security_invoker = on);

-- Create a policy for anonymous read access (if using RLS on underlying tables)
-- Note: This assumes the underlying tables have appropriate RLS policies
comment on view public.scout_gold_transactions_flat is
'Flattened view of Scout transactions matching CSV schema for data mode switching';