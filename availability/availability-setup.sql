-- Nonna Availability: database setup for Supabase.
-- Run this AFTER stars/supabase-setup.sql and checks/checks-setup.sql
-- (it reuses the same staff link, manager password and team list).
-- Paste this whole file into Supabase > SQL Editor > New query, then press Run.
-- It is safe to run again: it only creates what is missing and replaces the functions.
--
-- How it works
--   * Every month, each person marks the days of the NEXT month they can't work
--     (whole day, lunch only or evening only) and may add a note.
--   * Deadline: the 10th of the month before (for January: 10 December). From the 11th the
--     month is locked for staff; only management can still change it.
--   * The planner imports the submissions with a private export key (never shown to staff).
--   * Same security model as the checks: row-level security on, no policies, everything
--     goes through functions that need the staff link / team code or the manager password.

create table if not exists availability (
  id uuid primary key default gen_random_uuid(),
  month text not null check (month ~ '^\d{4}-(0[1-9]|1[0-2])$'),
  staff_id text not null check (char_length(staff_id) between 1 and 60),
  staff_name text not null check (char_length(staff_name) between 1 and 60),
  days jsonb not null default '{}'::jsonb,       -- {"2027-01-05": "day" | "lunch" | "eve", ...}
  note text not null default '' check (char_length(note) <= 500),
  device_hash text not null default '',
  by_manager boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (month, staff_id)
);
create index if not exists availability_month on availability (month);

alter table availability enable row level security;
revoke all on table availability from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then revoke all on table availability from anon; end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then revoke all on table availability from authenticated; end if;
end $$;

-- Private key for the planner export (hash only). Management can rotate it with mgr_new_avail_export_key.
alter table settings add column if not exists avail_export_key_hash text;
update settings set avail_export_key_hash = _h('avail-export:WxqRUOeRzE3N9dNXbZqc-XxIfAofapYc') where id = 1 and avail_export_key_hash is null;

-- ---------- helpers ----------
-- Deadline for a month = the 10th of the month before. Staff can submit while Lisbon's date <= deadline.
create or replace function avail_deadline(month_in text) returns date
language sql immutable as $$
  select (to_date(month_in || '-01', 'YYYY-MM-DD') - interval '1 month' + interval '9 days')::date
$$;

create or replace function _avail_locked(month_in text) returns boolean
language sql stable as $$ select _lisbon_today() > avail_deadline(month_in) $$;

create or replace function _avail_json(a availability) returns jsonb
language sql stable as $$
  select jsonb_build_object('id', a.id, 'month', a.month, 'staffId', a.staff_id, 'staffName', a.staff_name,
    'days', a.days, 'note', a.note, 'byManager', a.by_manager, 'createdAt', a.created_at, 'updatedAt', a.updated_at)
$$;

create or replace function _avail_export_ok(p text) returns boolean
language sql stable security definer set search_path = public as $$
  select _mgr_ok(p) or exists (select 1 from settings where id = 1 and avail_export_key_hash is not null
                                 and avail_export_key_hash = _h('avail-export:' || coalesce(p, '')))
$$;

create or replace function _avail_staff() returns jsonb
language sql stable as $$
  select coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'store', store) order by sort, created_at)
                   from staff where store not like 'former:%'), '[]'::jsonb)
$$;

-- ---------- staff ----------
-- What one person sees for one month: the deadline, whether it is locked, the team list and their own submission.
create or replace function avail_open(p text, month_in text, staff_id_in text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform _need_checks(p);
  if month_in !~ '^\d{4}-(0[1-9]|1[0-2])$' then raise exception 'bad_month'; end if;
  return jsonb_build_object(
    'today', _lisbon_today(),
    'deadline', avail_deadline(month_in),
    'locked', _avail_locked(month_in),
    'staff', _avail_staff(),
    'submitted', coalesce((select jsonb_agg(a.staff_id) from availability a where a.month = month_in), '[]'::jsonb),
    'mine', (select _avail_json(a) from availability a where a.month = month_in and a.staff_id = coalesce(staff_id_in, ''))
  );
end $$;

create or replace function avail_save(p text, token text, month_in text, staff_id_in text, staff_name_in text, days_in jsonb, note_in text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r availability; k text; v text; is_mgr boolean;
begin
  perform _need_checks(p);
  is_mgr := _mgr_ok(p);
  if month_in !~ '^\d{4}-(0[1-9]|1[0-2])$' then raise exception 'bad_month'; end if;
  if _avail_locked(month_in) and not is_mgr then raise exception 'locked'; end if;
  if coalesce(trim(staff_name_in), '') = '' or coalesce(trim(staff_id_in), '') = '' then raise exception 'name_needed'; end if;
  if not is_mgr and char_length(coalesce(token, '')) < 16 then raise exception 'bad_device'; end if;
  if days_in is null or jsonb_typeof(days_in) <> 'object' or char_length(days_in::text) > 4000 then raise exception 'bad_days'; end if;
  for k, v in select key, value #>> '{}' from jsonb_each(days_in) loop
    if k !~ '^\d{4}-\d{2}-\d{2}$' or left(k, 7) <> month_in then raise exception 'bad_days'; end if;
    if v not in ('day', 'lunch', 'eve') then raise exception 'bad_days'; end if;
  end loop;
  insert into availability (month, staff_id, staff_name, days, note, device_hash, by_manager)
  values (month_in, trim(staff_id_in), trim(staff_name_in), days_in, left(coalesce(note_in, ''), 500), _h('dev:' || coalesce(token, '')), is_mgr)
  on conflict (month, staff_id) do update
    set staff_name = excluded.staff_name, days = excluded.days, note = excluded.note,
        device_hash = excluded.device_hash, by_manager = excluded.by_manager, updated_at = now()
  returning * into r;
  return _avail_json(r);
end $$;

-- ---------- manager / planner ----------
-- Everything for one month: all submissions plus who is still missing. Manager password or the export key.
create or replace function avail_export(p text, month_in text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not _avail_export_ok(p) then perform pg_sleep(1); raise exception 'bad_password' using errcode = '28000'; end if;
  if month_in !~ '^\d{4}-(0[1-9]|1[0-2])$' then raise exception 'bad_month'; end if;
  return jsonb_build_object(
    'month', month_in,
    'today', _lisbon_today(),
    'deadline', avail_deadline(month_in),
    'locked', _avail_locked(month_in),
    'staff', _avail_staff(),
    'rows', coalesce((select jsonb_agg(_avail_json(a) order by a.staff_name) from availability a where a.month = month_in), '[]'::jsonb)
  );
end $$;

create or replace function mgr_delete_avail(p text, avail_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  perform _need_mgr(p);
  delete from availability where id = avail_id;
  return found;
end $$;

create or replace function mgr_new_avail_export_key(p text, new_key text) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  perform _need_mgr(p);
  if char_length(coalesce(new_key, '')) < 16 then raise exception 'key_too_short'; end if;
  update settings set avail_export_key_hash = _h('avail-export:' || new_key), updated_at = now() where id = 1;
  return true;
end $$;

-- ---------- access ----------
revoke all on function _avail_locked(text), _avail_json(availability), _avail_export_ok(text), _avail_staff() from public;
do $$
declare f text;
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on function _avail_locked(text), _avail_json(availability), _avail_export_ok(text), _avail_staff() from anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    revoke all on function _avail_locked(text), _avail_json(availability), _avail_export_ok(text), _avail_staff() from authenticated;
  end if;
  foreach f in array array[
    'avail_deadline(text)',
    'avail_open(text, text, text)',
    'avail_save(text, text, text, text, text, jsonb, text)',
    'avail_export(text, text)',
    'mgr_delete_avail(text, uuid)',
    'mgr_new_avail_export_key(text, text)'] loop
    execute 'revoke all on function ' || f || ' from public';
    if exists (select 1 from pg_roles where rolname = 'anon') then execute 'grant execute on function ' || f || ' to anon'; end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then execute 'grant execute on function ' || f || ' to authenticated'; end if;
  end loop;
end $$;

notify pgrst, 'reload schema';
