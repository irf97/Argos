#!/usr/bin/env bash
set -euo pipefail

ARGOS_URL="${ARGOS_URL:-http://127.0.0.1:4020}"
ARGOS_TOKEN="${ARGOS_TOKEN:-}"

project=""
canon="operator"
task=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project) project="$2"; shift 2 ;;
    --canon) canon="$2"; shift 2 ;;
    --task) task="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -z "$project" ] || [ -z "$task" ]; then
  echo "usage: codex-start.sh --project name --canon operator --task \"task\"" >&2
  exit 1
fi

mkdir -p .argos

auth_header=()
if [ -n "$ARGOS_TOKEN" ]; then
  auth_header=(-H "Authorization: Bearer $ARGOS_TOKEN")
fi

payload=$(PROJECT="$project" CANON="$canon" TASK="$task" python3 - <<'PY'
import json, os
print(json.dumps({
  "project": os.environ["PROJECT"],
  "canon": os.environ["CANON"],
  "task": os.environ["TASK"],
  "arm": "codex_cli"
}))
PY
)

pack_json=$(curl -sS "${auth_header[@]}" -H 'Content-Type: application/json' -d "$payload" "$ARGOS_URL/api/context-pack")
printf '%s\n' "$pack_json" > .argos/context-pack.json

python3 - <<'PY'
import json, pathlib
p = pathlib.Path('.argos/context-pack.json')
data = json.loads(p.read_text())
markdown = data.get('markdown') or data.get('context_pack', {}).get('markdown') or '# ARGOS Context Pack\n\nNo markdown returned. Inspect .argos/context-pack.json.\n'
pathlib.Path('.argos/context-pack.md').write_text(markdown)
PY

session_payload=$(PROJECT="$project" TASK="$task" python3 - <<'PY'
import json
pack=json.load(open('.argos/context-pack.json'))
pack_id=pack.get('id') or pack.get('context_pack',{}).get('id')
import os
print(json.dumps({
  "arm": "codex_cli",
  "project": os.environ["PROJECT"],
  "task": os.environ["TASK"],
  "context_pack_id": pack_id,
  "author": "operator"
}))
PY
)

session_json=$(curl -sS "${auth_header[@]}" -H 'Content-Type: application/json' -d "$session_payload" "$ARGOS_URL/api/arms/session/start")
printf '%s\n' "$session_json" > .argos/session.json

echo "ARGOS context written: .argos/context-pack.md"
echo "ARGOS session written: .argos/session.json"
echo
cat .argos/context-pack.md
