create schema if not exists security;

create table if not exists security.revoked_tokens (
  jti text primary key,
  email text,
  reason text,
  revoked_at timestamptz not null default now()
);
alter table security.revoked_tokens enable row level security;

create or replace function security.revoke_token(_jti text, _email text, _reason text default null)
returns void language plpgsql security definer as $$
begin
  insert into security.revoked_tokens(jti,email,reason)
  values (_jti,_email,_reason)
  on conflict (jti) do nothing;
end $$;

create or replace function security.is_revoked(_jti text)
returns boolean language sql stable as $$
  select exists(select 1 from security.revoked_tokens where jti=_jti);
$$;