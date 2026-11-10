-- Gym plan backup: run once in Supabase -> SQL Editor -> New query -> Run.
-- The table can't be read or written directly by the app; it can only call the
-- two functions below, and reading a backup needs its secret code.

create table if not exists public.backups (
  key        text primary key,
  data       jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.backups enable row level security;
-- (no policies on purpose: no direct access from the app)

create or replace function public.save_backup(p_key text, p_data jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if length(p_key) < 20 or octet_length(p_data::text) > 500000 then
    raise exception 'invalid backup';
  end if;
  insert into public.backups(key, data, updated_at)
  values (p_key, p_data, now())
  on conflict (key) do update set data = excluded.data, updated_at = now();
end;
$$;

create or replace function public.get_backup(p_key text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select data from public.backups where key = p_key;
$$;

revoke all on function public.save_backup(text, jsonb) from public;
revoke all on function public.get_backup(text) from public;
grant execute on function public.save_backup(text, jsonb) to anon;
grant execute on function public.get_backup(text) to anon;
