-- View: public.scout_gold_transactions_flat
-- NOTE: underlying table/column names on your silver/gold may differ slightly; adjust joins if needed.

create or replace view public.scout_gold_transactions_flat as
select
  t.category,
  t.brand,
  t.brand_raw,
  t.product,
  t.qty,
  t.unit,
  t.unit_price,
  t.total_price,
  coalesce(i.device, i.deviceid::text) as device,
  s.store                                 as store,
  s.storename,
  s.storelocationmaster,
  s.storedeviceid,
  s.storedevicename,
  s.location,
  t.transaction_id,

  to_char(t.transaction_ts at time zone 'Asia/Manila','YYYY-MM-DD') as date_ph,
  to_char(t.transaction_ts at time zone 'Asia/Manila','HH24:MI:SS') as time_ph,
  to_char(t.transaction_ts at time zone 'Asia/Manila','DY')         as day_of_week,
  case when extract(isodow from t.transaction_ts at time zone 'Asia/Manila') in (6,7)
       then 'Weekend' else 'Weekday' end                             as weekday_weekend,
  t.time_of_day,
  t.payment_method,
  t.bought_with_other_brands,
  t.transcript_audio,
  t.edge_version,
  t.sku,
  to_char(t.transaction_ts at time zone 'Asia/Manila','YYYY-MM-DD"T"HH24:MI:SS') as ts_ph,

  d.facialid,
  d.gender,
  d.emotion,
  d.age,
  d.agebracket,

  s.storeid,
  i.interactionid,
  t.productid,
  t.transaction_ts as transactiondate,
  i.deviceid,
  d.sex,
  d.age_query_4_1   as "age__query_4_1",
  d.emotionalstate,
  d.transcriptiontext,
  d.gender_query_4_1 as "gender__query_4_1",
  s.barangay,
  s.storename_query_10 as "storename__query_10",
  s.location_query_10  as "location__query_10",
  s.size,
  s.geolatitude,
  s.geolongitude,
  s.storegeometry,
  s.managername,
  s.managercontactinfo,
  s.devicename,
  s.deviceid_query_10  as "deviceid__query_10",
  s.barangay_query_10  as "barangay__query_10"
from scout.silver_transactions t
left join scout.silver_interactions i on i.transaction_id = t.transaction_id
left join scout.silver_demographics d on d.interaction_id = i.interactionid
left join scout.silver_stores s on s.storeid = i.storeid;

-- Ensure RLS of base tables applies under anon via invoker rights:
alter view public.scout_gold_transactions_flat set (security_invoker = on);

-- Grants for anon (read-only via PostgREST)
grant usage on schema public to anon;
grant select on public.scout_gold_transactions_flat to anon;