-- Nonna Daily Checks: database setup for Supabase.
-- Run this AFTER stars/supabase-setup.sql (it reuses the same team code,
-- manager password and team list).
-- Paste this whole file into Supabase > SQL Editor > New query, then press Run.
-- It is safe to run again: it only creates what is missing and replaces the functions.
--
-- Security model (same as the Stars board)
--   * The checks table has row-level security on and no policies, so the
--     publishable key cannot read or write it directly.
--   * Staff functions need the team code; history and deleting need the manager password.
--   * Staff can only log checks for today (or yesterday, for closing after midnight).
--     Entries are never edited: a correction is a new entry, so the log stays honest.

create table if not exists checks (
  id uuid primary key default gen_random_uuid(),
  store text not null check (char_length(store) between 1 and 40),
  day date not null,
  kind text not null check (kind in ('temp', 'clean', 'toilet')),
  item text not null check (char_length(item) between 1 and 60),
  slot text not null default '' check (char_length(slot) <= 40),
  value numeric(5,1) check (value between -60 and 150),
  ok boolean not null default true,
  details jsonb not null default '{}'::jsonb,
  staff_id text not null check (char_length(staff_id) between 1 and 60),
  staff_name text not null check (char_length(staff_name) between 1 and 60),
  device_hash text not null,
  created_at timestamptz not null default now()
);
create index if not exists checks_store_day on checks (store, day);

alter table checks enable row level security;
revoke all on table checks from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then revoke all on table checks from anon; end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then revoke all on table checks from authenticated; end if;
end $$;

create or replace function _lisbon_today() returns date
language sql stable as $$ select (now() at time zone 'Europe/Lisbon')::date $$;

create or replace function _check_json(c checks) returns jsonb
language sql stable as $$
  select jsonb_build_object('id', c.id, 'store', c.store, 'day', c.day, 'kind', c.kind, 'item', c.item,
    'slot', c.slot, 'value', c.value, 'ok', c.ok, 'details', c.details, 'staffId', c.staff_id,
    'staffName', c.staff_name, 'at', c.created_at)
$$;

-- ---------- staff link ----------
-- Staff open the page through a private link (…/checks#k=…), so they don't type a code.
-- Only a hash of the link key is stored. The team code and manager password keep working too.
-- Management can make a new link from History; the old link then stops working.
alter table settings add column if not exists checks_key_hash text;
update settings set checks_key_hash = '9d21b0e5cc2def2fe13e9268d3f4fa287947cdd771dc56152f0422543dd96983' where id = 1 and checks_key_hash is null;

create or replace function _checks_ok(p text) returns boolean
language sql stable security definer set search_path = public as $$
  select _pin_ok(p) or exists (select 1 from settings where id = 1 and checks_key_hash is not null
                                 and checks_key_hash = _h('checks:' || coalesce(p, '')))
$$;

create or replace function _need_checks(p text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not _checks_ok(p) then
    perform pg_sleep(1);
    raise exception 'bad_code' using errcode = '28000';
  end if;
end $$;

-- ---------- staff ----------
create or replace function checks_day(p text, store_id text, day_in date) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform _need_checks(p);
  return jsonb_build_object(
    'today', _lisbon_today(),
    'now', now(),
    'staff', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'store', store) order by sort, created_at) from staff where store not like 'former:%'), '[]'::jsonb),
    'rows', coalesce((select jsonb_agg(_check_json(c) order by c.created_at) from checks c
                      where c.store = store_id and c.day = coalesce(day_in, _lisbon_today())), '[]'::jsonb),
    -- Weekly and monthly tasks from the last 5 weeks, so the page knows what is already done this week/month.
    'periodic', coalesce((select jsonb_agg(_check_json(c) order by c.created_at) from checks c
                      where c.store = store_id and c.kind = 'clean' and c.details->>'every' in ('week', 'month')
                        and c.day between coalesce(day_in, _lisbon_today()) - 35 and coalesce(day_in, _lisbon_today())), '[]'::jsonb)
  );
end $$;

create or replace function checks_add(p text, token text, store_id text, day_in date, kind_in text, item_in text,
  slot_in text, value_in numeric, ok_in boolean, details_in jsonb, staff_id_in text, staff_name_in text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r checks;
begin
  perform _need_checks(p);
  if char_length(coalesce(token, '')) < 16 then raise exception 'bad_device'; end if;
  if day_in is null or day_in > _lisbon_today() or day_in < _lisbon_today() - 1 then raise exception 'wrong_day'; end if;
  if kind_in = 'temp' and value_in is null then raise exception 'value_needed'; end if;
  if coalesce(trim(staff_name_in), '') = '' then raise exception 'name_needed'; end if;
  if details_in is not null and char_length(details_in::text) > 2000 then raise exception 'too_long'; end if;
  if not ok_in and coalesce(trim(details_in->>'action'), '') = '' then raise exception 'action_needed'; end if;
  insert into checks (store, day, kind, item, slot, value, ok, details, staff_id, staff_name, device_hash)
  values (store_id, day_in, kind_in, item_in, coalesce(slot_in, ''), value_in, coalesce(ok_in, true),
          coalesce(details_in, '{}'::jsonb), staff_id_in, trim(staff_name_in), _h('dev:' || token))
  returning * into r;
  return _check_json(r);
end $$;

-- A mis-tap can be undone from the same phone or tablet within 10 minutes.
create or replace function checks_undo(p text, token text, check_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  perform _need_checks(p);
  delete from checks where id = check_id and device_hash = _h('dev:' || coalesce(token, ''))
    and created_at > now() - interval '10 minutes';
  if not found then raise exception 'cannot_undo'; end if;
  return true;
end $$;

-- ---------- manager ----------
create or replace function mgr_checks_range(p text, store_id text, from_day date, to_day date) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform _need_mgr(p);
  if to_day - from_day > 400 then raise exception 'range_too_long'; end if;
  return coalesce((select jsonb_agg(_check_json(c) order by c.day, c.created_at) from checks c
                   where (store_id is null or c.store = store_id) and c.day between from_day and to_day), '[]'::jsonb);
end $$;

create or replace function mgr_new_checks_key(p text, new_key text) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  perform _need_mgr(p);
  if char_length(coalesce(new_key, '')) < 16 then raise exception 'key_too_short'; end if;
  update settings set checks_key_hash = _h('checks:' || new_key), updated_at = now() where id = 1;
  return true;
end $$;

create or replace function mgr_delete_check(p text, check_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  perform _need_mgr(p);
  delete from checks where id = check_id;
  return found;
end $$;

-- ---------- access ----------
revoke all on function _lisbon_today(), _check_json(checks), _checks_ok(text), _need_checks(text) from public;
do $$
declare f text;
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on function _lisbon_today(), _check_json(checks), _checks_ok(text), _need_checks(text) from anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    revoke all on function _lisbon_today(), _check_json(checks), _checks_ok(text), _need_checks(text) from authenticated;
  end if;
  foreach f in array array[
    'checks_day(text, text, date)',
    'checks_add(text, text, text, date, text, text, text, numeric, boolean, jsonb, text, text)',
    'checks_undo(text, text, uuid)',
    'mgr_checks_range(text, text, date, date)',
    'mgr_new_checks_key(text, text)',
    'mgr_delete_check(text, uuid)'] loop
    execute 'revoke all on function ' || f || ' from public';
    if exists (select 1 from pg_roles where rolname = 'anon') then execute 'grant execute on function ' || f || ' to anon'; end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then execute 'grant execute on function ' || f || ' to authenticated'; end if;
  end loop;
end $$;

notify pgrst, 'reload schema';
