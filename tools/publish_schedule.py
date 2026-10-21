"""Rebuild the schedule data in index.html from a Nonna Staff Planner export.

Usage: python3 -I tools/publish_schedule.py <export_dir> [repo_dir]

<export_dir> holds the planner documents as saved by ArtifactData out_dir:
  config/main.json
  stores/<store>/config/people.json
  stores/<store>/months/<YYYY-MM>.json

Only names are copied from the people lists (no pay rates), plus the
availability rules. Prints "changed" when index.html was rewritten with new
schedule data, or "unchanged" when the schedule is the same as what is live.
"""
import datetime, glob, json, os, sys
from zoneinfo import ZoneInfo

export_dir = sys.argv[1]
repo_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
page = os.path.join(repo_dir, 'index.html')
KEY = 'window.NGC_DATA ='

html = open(page, encoding='utf-8').read()
start = html.index(KEY) + len(KEY)
end = html.index('</script>', start)
old = json.loads(html[start:end].strip().rstrip(';'))

main = json.load(open(os.path.join(export_dir, 'config', 'main.json'), encoding='utf-8'))
config = {k: main[k] for k in old['config'] if k in main}

stores = [s['id'] for s in config.get('stores', [])] or list(old['months'])
people, months = {}, {}
for store in stores:
    p_path = os.path.join(export_dir, 'stores', store, 'config', 'people.json')
    src = json.load(open(p_path, encoding='utf-8')) if os.path.exists(p_path) else old['people'].get(store, {})
    people[store] = {k: (v if k in ('rules', 'rulesFrom') or not isinstance(v, list)
                         else [{'name': (x or {}).get('name', '')} for x in v])
                     for k, v in src.items()}
    found = {os.path.basename(f)[:-5]: json.load(open(f, encoding='utf-8'))
             for f in sorted(glob.glob(os.path.join(export_dir, 'stores', store, 'months', '*.json')))}
    months[store] = found or old['months'].get(store, {})

new = {'config': config, 'people': people, 'months': months}
if all(new[k] == old.get(k) for k in new):
    print('unchanged')
    sys.exit(0)

if '"rate"' in json.dumps(new):
    sys.exit('refusing to publish: pay rates found in the export')

new['published'] = datetime.datetime.now(ZoneInfo('Europe/Lisbon')).strftime('%d/%m/%Y %H:%M')
blob = json.dumps(new, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')
html = html[:start] + ' ' + blob + ';' + html[end:]
open(page, 'w', encoding='utf-8').write(html)
print('changed', new['published'])
