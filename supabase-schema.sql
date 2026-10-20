-- Crypto Wall: private-by-default dashboard state via RPC.
-- Run this in Supabase Dashboard > SQL Editor.
-- The browser can only read/write through these functions when it knows the room key.
-- Do NOT add public table policies or expose a service_role key in the frontend.

create table if not exists public.crypto_wall_rooms (
  dashboard_id text primary key,
  room_key text not null,
  config jsonb,
  updated_at timestamptz not null default now()
);

alter table public.crypto_wall_rooms enable row level security;
revoke all on table public.crypto_wall_rooms from anon, authenticated;

create or replace function public.get_dashboard_state(
  p_dashboard_id text,
  p_room_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  select jsonb_build_object('config', r.config, 'updated_at', r.updated_at)
    into result
    from public.crypto_wall_rooms r
   where r.dashboard_id = p_dashboard_id
     and r.room_key = p_room_key;
  if result is null then
    return jsonb_build_object('config', null, 'updated_at', null);
  end if;
  return result;
end;
$$;

create or replace function public.save_dashboard_state(
  p_dashboard_id text,
  p_room_key text,
  p_state jsonb
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_dashboard_id is null or length(p_dashboard_id) < 3
     or p_room_key is null or length(p_room_key) < 20
     or p_state is null then
    raise exception 'Invalid dashboard parameters';
  end if;

  insert into public.crypto_wall_rooms(dashboard_id, room_key, config, updated_at)
  values (p_dashboard_id, p_room_key, p_state, now())
  on conflict (dashboard_id) do update
    set config = excluded.config,
        updated_at = now()
    where public.crypto_wall_rooms.room_key = excluded.room_key;

  if not found then
    raise exception 'Dashboard ID exists but room key does not match';
  end if;
  return true;
end;
$$;

revoke all on function public.get_dashboard_state(text, text) from public;
revoke all on function public.save_dashboard_state(text, text, jsonb) from public;
grant execute on function public.get_dashboard_state(text, text) to anon, authenticated;
grant execute on function public.save_dashboard_state(text, text, jsonb) to anon, authenticated;
