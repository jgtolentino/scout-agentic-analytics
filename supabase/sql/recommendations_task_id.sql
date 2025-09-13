create extension if not exists pgcrypto;

create schema if not exists scout;

-- Generate short, human-friendly task ids like "250913-7f3a91c2"
create or replace function scout.gen_task_id()
returns text language plpgsql volatile as $
declare v text;
begin
  v := to_char(now(),'YYMMDD') || '-' || substr(encode(gen_random_bytes(8),'hex'),1,8);
  return lower(v);
end $;

alter table scout.recommendations
  add column if not exists task_id text;

-- Backfill missing task_id first, to satisfy unique constraint
update scout.recommendations
   set task_id = scout.gen_task_id()
 where (task_id is null or length(task_id)=0);

-- Enforce uniqueness
do $ begin
  alter table scout.recommendations
    add constraint uq_recommendations_task_id unique (task_id);
exception when duplicate_object then null; end $;

-- Auto-assign on insert/update when null/blank
create or replace function scout._tg_reco_task_id()
returns trigger language plpgsql as $
begin
  if new.task_id is null or length(new.task_id)=0 then
    new.task_id := scout.gen_task_id();
  end if;
  return new;
end $;

do $ begin
  create trigger _reco_task_id_ins before insert on scout.recommendations
  for each row execute function scout._tg_reco_task_id();
exception when duplicate_object then null; end $;

do $ begin
  create trigger _reco_task_id_upd before update on scout.recommendations
  for each row execute function scout._tg_reco_task_id();
exception when duplicate_object then null; end $;

-- Convenience RPC to ensure task_id for a given reco
create or replace function scout.ensure_task_id(p_id uuid)
returns text language plpgsql security definer as $
declare t text;
begin
  update scout.recommendations
     set task_id = coalesce(nullif(task_id,''), scout.gen_task_id()),
         updated_at = now()
   where id = p_id
  returning task_id into t;
  return t;
end $;
grant execute on function scout.ensure_task_id(uuid) to authenticated;
