-- Nonna Stars Board: database setup for Supabase.
-- Paste this whole file into Supabase > SQL Editor > New query, then press Run.
-- It is safe to run again: it only creates what is missing and replaces the functions.
--
-- Security model
--   * Every table has row-level security switched on and no policies, so the
--     publishable (anon) key cannot read or write any table directly.
--   * The page talks to the database only through the functions below.
--   * Staff functions need the team code. Manager functions need the manager password.
--   * Codes are stored as salted SHA-256 hashes, never as plain text.

-- ---------- tables ----------
create table if not exists settings (
  id int primary key default 1 check (id = 1),
  team_pin_hash text,
  manager_pw_hash text,
  voting jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
insert into settings (id) values (1) on conflict (id) do nothing;

create table if not exists staff (
  id text primary key,
  name text not null,
  store text not null,
  photo_id uuid,
  sort int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists shoutouts (
  id uuid primary key default gen_random_uuid(),
  store text not null,
  to_id text not null,
  from_id text,
  msg text not null check (char_length(msg) between 1 and 280),
  kind text not null default 'team' check (kind in ('team', 'guest')),
  month text not null,
  edited boolean not null default false,
  author_hash text not null,
  created_at timestamptz not null default now()
);

create table if not exists votes (
  month text not null,
  store text not null,
  voter_id text not null,
  nominee_id text not null,
  reason text not null check (char_length(reason) between 1 and 280),
  voter_hash text not null,
  updated_at timestamptz not null default now(),
  primary key (month, voter_id)
);

create table if not exists scores (
  month text not null,
  store text not null,
  rows jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (month, store)
);

create table if not exists winners (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists reviews (
  id uuid primary key default gen_random_uuid(),
  store text not null,
  text text,
  author text,
  stars int not null default 5 check (stars between 1 and 5),
  date date,
  image_id uuid,
  created_at timestamptz not null default now()
);

create table if not exists reactions (
  item_key text not null,
  emoji text not null,
  who text not null,
  created_at timestamptz not null default now(),
  primary key (item_key, emoji, who)
);

create table if not exists photos (
  id uuid primary key default gen_random_uuid(),
  data text not null,
  created_at timestamptz not null default now()
);

do $$
declare t text;
begin
  foreach t in array array['settings','staff','shoutouts','votes','scores','winners','reviews','reactions','photos'] loop
    execute format('alter table %I enable row level security', t);
    execute format('revoke all on table %I from public', t);
    if exists (select 1 from pg_roles where rolname = 'anon') then
      execute format('revoke all on table %I from anon', t);
    end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
      execute format('revoke all on table %I from authenticated', t);
    end if;
  end loop;
end $$;

-- ---------- private helpers ----------
create or replace function _h(v text) returns text
language sql immutable set search_path = public as $$
  select encode(sha256(convert_to('nonna-stars:' || coalesce(v, ''), 'UTF8')), 'hex')
$$;

create or replace function _mgr_ok(p text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from settings where id = 1 and manager_pw_hash is not null and manager_pw_hash = _h('mgr:' || coalesce(p, '')))
$$;

create or replace function _pin_ok(p text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from settings where id = 1 and team_pin_hash is not null and team_pin_hash = _h('pin:' || coalesce(p, '')))
      or _mgr_ok(p)
$$;

create or replace function _need_pin(p text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not _pin_ok(p) then
    perform pg_sleep(1);
    raise exception 'bad_code' using errcode = '28000';
  end if;
end $$;

create or replace function _need_mgr(p text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not _mgr_ok(p) then
    perform pg_sleep(1);
    raise exception 'bad_password' using errcode = '28000';
  end if;
end $$;

create or replace function _this_month() returns text
language sql stable as $$ select to_char(now() at time zone 'Europe/Lisbon', 'YYYY-MM') $$;

-- ---------- setup ----------
create or replace function is_setup() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select manager_pw_hash is not null and team_pin_hash is not null from settings where id = 1), false)
$$;

create or replace function setup(new_pw text, new_pin text) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if is_setup() then raise exception 'already_setup'; end if;
  if char_length(coalesce(new_pw, '')) < 8 then raise exception 'password_too_short'; end if;
  if char_length(coalesce(new_pin, '')) < 6 then raise exception 'code_too_short'; end if;
  if new_pw = new_pin then raise exception 'same_codes'; end if;
  update settings set manager_pw_hash = _h('mgr:' || new_pw), team_pin_hash = _h('pin:' || new_pin), updated_at = now() where id = 1;
  return true;
end $$;

create or replace function check_code(p text) returns text
language plpgsql security definer set search_path = public as $$
begin
  if _mgr_ok(p) then return 'manager'; end if;
  if _pin_ok(p) then return 'team'; end if;
  perform pg_sleep(1);
  return null;
end $$;

-- ---------- staff: read ----------
create or replace function board(p text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform _need_pin(p);
  return jsonb_build_object(
    'staff', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'store', store, 'photoId', photo_id) order by sort, created_at) from staff), '[]'::jsonb),
    'voting', (select voting from settings where id = 1),
    'shoutouts', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'store', store, 'to', to_id, 'from', from_id, 'msg', msg, 'kind', kind, 'month', month, 'edited', edited, 'at', created_at, 'author', author_hash) order by created_at desc) from shoutouts), '[]'::jsonb),
    'winners', coalesce((select jsonb_agg(data || jsonb_build_object('id', id)) from winners), '[]'::jsonb),
    'reviews', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'store', store, 'text', text, 'author', author, 'stars', stars, 'date', date, 'imageId', image_id, 'at', created_at)) from reviews), '[]'::jsonb),
    'reactions', coalesce((select jsonb_agg(jsonb_build_object('key', item_key, 'emoji', emoji, 'who', who)) from reactions), '[]'::jsonb),
    'now', now()
  );
end $$;

create or replace function photos_get(p text, ids uuid[]) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform _need_pin(p);
  return coalesce((select jsonb_object_agg(id, data) from photos where id = any(ids)), '{}'::jsonb);
end $$;

-- ---------- staff: shout-outs ----------
create or replace function post_shout(p text, token text, store_id text, to_id text, from_id text, msg text, kind text) returns uuid
language plpgsql security definer set search_path = public as $$
declare new_id uuid;
begin
  perform _need_pin(p);
  if char_length(coalesce(token, '')) < 16 then raise exception 'bad_device'; end if;
  if not exists (select 1 from staff where id = to_id) then raise exception 'unknown_person'; end if;
  insert into shoutouts (store, to_id, from_id, msg, kind, month, author_hash)
  values (store_id, to_id, nullif(from_id, ''), btrim(msg), case when kind = 'guest' then 'guest' else 'team' end, _this_month(), _h('dev:' || token))
  returning id into new_id;
  return new_id;
end $$;

create or replace function edit_shout(p text, token text, shout_id uuid, msg text) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  perform _need_pin(p);
  update shoutouts set msg = btrim(edit_shout.msg), edited = true
   where id = shout_id and author_hash = _h('dev:' || coalesce(token, ''));
  if not found then raise exception 'not_yours'; end if;
  return true;
end $$;

create or replace function delete_shout(p text, token text, shout_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  perform _need_pin(p);
  delete from shoutouts where id = shout_id and (author_hash = _h('dev:' || coalesce(token, '')) or _mgr_ok(p));
  if not found then raise exception 'not_yours'; end if;
  delete from reactions where item_key = 's:' || shout_id::text;
  return true;
end $$;

-- ---------- staff: votes ----------
create or replace function my_votes(p text, token text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform _need_pin(p);
  return coalesce((select jsonb_object_agg(month, jsonb_build_object('store', store, 'voter', voter_id, 'nominee', nominee_id, 'reason', reason))
                     from votes where voter_hash = _h('dev:' || coalesce(token, ''))), '{}'::jsonb);
end $$;

create or replace function cast_vote(p text, token text, store_id text, voter text, nominee text, reason text) returns boolean
language plpgsql security definer set search_path = public as $$
declare v jsonb; m text; dev text; existing votes%rowtype;
begin
  perform _need_pin(p);
  dev := _h('dev:' || coalesce(token, ''));
  select voting into v from settings where id = 1;
  m := v->>'votingMonth';
  if not coalesce((v->>'votingOpen')::boolean, false) or m is null
     or (v ? 'closesAt' and now() >= (v->>'closesAt')::timestamptz) then
    raise exception 'voting_closed';
  end if;
  if voter = nominee then raise exception 'no_self_vote'; end if;
  if not exists (select 1 from staff where id = voter) or not exists (select 1 from staff where id = nominee) then raise exception 'unknown_person'; end if;
  if char_length(btrim(coalesce(reason, ''))) = 0 then raise exception 'reason_needed'; end if;
  select * into existing from votes where month = m and voter_id = voter;
  if found and existing.voter_hash <> dev then raise exception 'voted_elsewhere'; end if;
  if exists (select 1 from votes where month = m and voter_hash = dev and voter_id <> voter) then raise exception 'device_used'; end if;
  insert into votes (month, store, voter_id, nominee_id, reason, voter_hash)
  values (m, store_id, voter, nominee, btrim(reason), dev)
  on conflict (month, voter_id) do update set store = excluded.store, nominee_id = excluded.nominee_id, reason = excluded.reason, updated_at = now();
  return true;
end $$;

-- ---------- staff: emoji reactions ----------
create or replace function react(p text, token text, item text, emoji text) returns boolean
language plpgsql security definer set search_path = public as $$
declare dev text;
begin
  perform _need_pin(p);
  if emoji not in ('❤️', '👏', '😂', '🥹', '🔥', '⭐') then raise exception 'bad_emoji'; end if;
  if char_length(coalesce(item, '')) > 80 then raise exception 'bad_item'; end if;
  dev := _h('dev:' || coalesce(token, ''));
  delete from reactions where item_key = item and reactions.emoji = react.emoji and who = dev;
  if found then return false; end if;
  insert into reactions (item_key, emoji, who) values (item, react.emoji, dev);
  return true;
end $$;

-- ---------- manager ----------
create or replace function mgr_data(p text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform _need_mgr(p);
  return jsonb_build_object(
    'votes', coalesce((select jsonb_agg(jsonb_build_object('month', month, 'store', store, 'voter', voter_id, 'nominee', nominee_id, 'reason', reason)) from votes), '[]'::jsonb),
    'scores', coalesce((select jsonb_agg(jsonb_build_object('month', month, 'store', store, 'rows', rows)) from scores), '[]'::jsonb)
  );
end $$;

create or replace function mgr_save_score(p text, month_key text, store_id text, score_rows jsonb) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  perform _need_mgr(p);
  insert into scores (month, store, rows) values (month_key, store_id, coalesce(score_rows, '{}'::jsonb))
  on conflict (month, store) do update set rows = excluded.rows, updated_at = now();
  return true;
end $$;

create or replace function mgr_set_voting(p text, voting jsonb) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  perform _need_mgr(p);
  update settings set voting = coalesce(mgr_set_voting.voting, '{}'::jsonb), updated_at = now() where id = 1;
  return true;
end $$;

create or replace function mgr_set_winner(p text, winner_id text, data jsonb) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  perform _need_mgr(p);
  insert into winners (id, data) values (winner_id, data - 'id')
  on conflict (id) do update set data = excluded.data, updated_at = now();
  return true;
end $$;

create or replace function mgr_set_staff(p text, people jsonb) returns boolean
language plpgsql security definer set search_path = public as $$
declare person jsonb; i int := 0;
begin
  perform _need_mgr(p);
  delete from staff where id not in (select x->>'id' from jsonb_array_elements(people) x);
  for person in select * from jsonb_array_elements(people) loop
    i := i + 1;
    insert into staff (id, name, store, photo_id, sort)
    values (person->>'id', person->>'name', person->>'store', nullif(person->>'photoId', '')::uuid, i)
    on conflict (id) do update set name = excluded.name, store = excluded.store, photo_id = excluded.photo_id, sort = excluded.sort;
  end loop;
  return true;
end $$;

create or replace function mgr_add_photo(p text, data text) returns uuid
language plpgsql security definer set search_path = public as $$
declare new_id uuid;
begin
  perform _need_mgr(p);
  if data !~ '^data:image/(jpeg|png|webp);base64,' then raise exception 'not_an_image'; end if;
  if char_length(data) > 2000000 then raise exception 'too_large'; end if;
  insert into photos (data) values (mgr_add_photo.data) returning id into new_id;
  return new_id;
end $$;

create or replace function mgr_add_review(p text, review jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare new_id uuid;
begin
  perform _need_mgr(p);
  insert into reviews (store, text, author, stars, date, image_id)
  values (review->>'store', nullif(btrim(review->>'text'), ''), nullif(btrim(review->>'author'), ''),
          greatest(1, least(5, coalesce((review->>'stars')::int, 5))),
          coalesce(nullif(review->>'date', '')::date, (now() at time zone 'Europe/Lisbon')::date),
          nullif(review->>'imageId', '')::uuid)
  returning id into new_id;
  return new_id;
end $$;

create or replace function mgr_delete_review(p text, review_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare img uuid;
begin
  perform _need_mgr(p);
  delete from reviews where id = review_id returning image_id into img;
  if img is not null then delete from photos where id = img; end if;
  delete from reactions where item_key = 'r:' || review_id::text;
  return true;
end $$;

create or replace function mgr_change_codes(p text, new_pin text, new_pw text) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  perform _need_mgr(p);
  if coalesce(new_pin, '') <> '' then
    if char_length(new_pin) < 6 then raise exception 'code_too_short'; end if;
    update settings set team_pin_hash = _h('pin:' || new_pin), updated_at = now() where id = 1;
  end if;
  if coalesce(new_pw, '') <> '' then
    if char_length(new_pw) < 8 then raise exception 'password_too_short'; end if;
    update settings set manager_pw_hash = _h('mgr:' || new_pw), updated_at = now() where id = 1;
  end if;
  return true;
end $$;

-- ---------- who may call what ----------
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then grant usage on schema public to anon; end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then grant usage on schema public to authenticated; end if;
end $$;
revoke execute on all functions in schema public from public;
do $$
declare f text;
begin
  foreach f in array array[
    'is_setup()', 'setup(text,text)', 'check_code(text)', 'board(text)', 'photos_get(text,uuid[])',
    'post_shout(text,text,text,text,text,text,text)', 'edit_shout(text,text,uuid,text)', 'delete_shout(text,text,uuid)',
    'my_votes(text,text)', 'cast_vote(text,text,text,text,text,text)', 'react(text,text,text,text)',
    'mgr_data(text)', 'mgr_save_score(text,text,text,jsonb)', 'mgr_set_voting(text,jsonb)', 'mgr_set_winner(text,text,jsonb)',
    'mgr_set_staff(text,jsonb)', 'mgr_add_photo(text,text)', 'mgr_add_review(text,jsonb)', 'mgr_delete_review(text,uuid)',
    'mgr_change_codes(text,text,text)'] loop
    if exists (select 1 from pg_roles where rolname = 'anon') then
      execute format('grant execute on function %s to anon', f);
    end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
      execute format('grant execute on function %s to authenticated', f);
    end if;
  end loop;
end $$;
