# NGC HR Management

## Team schedule (live on Vercel)

Read-only copy of the Nonna Goes Crazy staff schedule, published for the team.

- `index.html` — the whole site (one file, no build step). Vercel serves it as is.
- The schedule is edited in the Nonna Staff Planner on claude.ai; each publish exports the current data and replaces `index.html`.
- No pay rates are included in this site.

## Stars board (live on Vercel at /stars)

Shout-outs, Employee of the Month voting, the Hall of fame moodboard and the manager back office.

- `stars/index.html` — the page (one file, no build step).
- `stars/config.js` — the Supabase Project URL and publishable key. The publishable key is meant to be public.
- `stars/supabase-setup.sql` — run once in Supabase > SQL Editor. Safe to run again after changes. Not deployed.
- Staff open the page and type the team code once; managers log in with the manager password. Both are set the first time the page is opened and can be changed in Back office > Team.
- Shift counts for the scorecard are read from this site's schedule (`/index.html`), so publishing the schedule also updates the shifts.
- `stars-board/` — the earlier Claude-hosted version, kept as a backup and not deployed.
