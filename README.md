# NGC HR Management

## Team schedule (live on Vercel)

Read-only copy of the Nonna Goes Crazy staff schedule, published for the team.

- `index.html` — the whole site (one file, no build step). Vercel serves it as is.
- The schedule is edited in the Nonna Staff Planner on claude.ai; each publish exports the current data and replaces `index.html`.
- No pay rates are included in this site.
- A scheduled task publishes it automatically every morning: it exports the planner, runs `tools/publish_schedule.py`, and commits only when the schedule changed.

## Stars board (live on Vercel at /stars)

Shout-outs, Employee of the Month voting, the Hall of fame moodboard and the manager back office.

- `stars/index.html` — the page (one file, no build step).
- `stars/config.js` — the Supabase Project URL and publishable key. The publishable key is meant to be public.
- `stars/supabase-setup.sql` — run once in Supabase > SQL Editor. Safe to run again after changes. Not deployed.
- Staff open the page and type the team code once; managers log in with the manager password. Both are set the first time the page is opened and can be changed in Back office > Team.
- Shift counts for the scorecard are read from this site's schedule (`/index.html`), so publishing the schedule also updates the shifts.
- `stars-board/` — the earlier Claude-hosted version, kept as a backup and not deployed.

## Daily checks (live on Vercel at /checks)

Fridge and freezer temperatures (opening and closing), daily cleaning tasks and the two daily toilet checks.

- `checks/index.html` — the page (one file, no build step).
- `checks/checks-config.js` — the fridges and their limits, cleaning tasks (daily at closing per role, weekly, monthly — based on the chef, cashier and production booklets), toilet checklist and stores. Edit this to change what staff see.
- `checks/checks-setup.sql` — run once in Supabase > SQL Editor, after `stars/supabase-setup.sql`. Safe to run again. Not deployed.
- Uses the same Supabase project, team code, manager password and team list as the Stars board. A phone already logged in on /stars is logged in here too.
- Staff open it with the private staff link (`/checks#k=…`), so they don't type a code. Only a hash of the link key is stored; the key only opens the checks (not Stars, not History). Management can make a new link in History, which switches off the old one. The team code and manager password still work too.
- Staff log checks for today (or yesterday, for closing after midnight) and can undo a mis-tap within 10 minutes. Management sees History (any date range), can remove wrong entries, download a CSV for Excel or print.
