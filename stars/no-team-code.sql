-- Run once in Supabase: SQL Editor > New query > paste > Run.
-- Lets staff use the Stars board without a team code. Management still needs the password.
create or replace function _need_pin(p text) returns void
language plpgsql security definer set search_path = public as $$
begin
  return;
end $$;
