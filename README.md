# NGC HR Management

## Team schedule (live on Vercel)

Read-only copy of the Nonna Goes Crazy staff schedule, published for the team.

- `index.html` — the whole site (one file, no build step). Vercel serves it as is.
- The schedule is edited in the Nonna Staff Planner on claude.ai; each publish exports the current data and replaces `index.html`.
- No pay rates are included in this site.

## Stars board (runs on Claude, not on Vercel)

`stars-board/index.html` is a backup of the "Nonna Stars Board" page: shout-outs, Employee of the Month voting, the Hall of fame moodboard and the manager back office.

- It only works inside Claude, which stores its shout-outs, votes, reactions and photos. Opened anywhere else it shows an empty board.
- `.vercelignore` keeps this folder out of the Vercel site.
- Live page: https://claude.ai/artifact/V2oRy4QU9iKui7f2fv7qXi
- Every change to the board is published to Claude first and then committed here, so this folder always matches the live version.
