#!/usr/bin/env bash
set -euo pipefail

ARGOS_URL="${ARGOS_URL:-http://127.0.0.1:4020}"
ARGOS_TOKEN="${ARGOS_TOKEN:-}"

mkdir -p .argos

auth_header=()
if [ -n "$ARGOS_TOKEN" ]; then
  auth_header=(-H "Authorization: Bearer $ARGOS_TOKEN")
fi

git_status=$(git status --short 2>/dev/null || true)
git_diff_stat=$(git diff --stat 2>/dev/null || true)
changed_files=$(git diff --name-only 2>/dev/null || true)

test_output=""
test_status="not_run"
if [ -f mix.exs ]; then
  set +e
  test_output=$(mix test 2>&1)
  code=$?
  set -e
  if [ "$code" -eq 0 ]; then test_status="pass"; else test_status="fail"; fi
fi

GIT_STATUS="$git_status" \
GIT_DIFF_STAT="$git_diff_stat" \
CHANGED_FILES="$changed_files" \
TEST_STATUS="$test_status" \
TEST_OUTPUT="$test_output" \
python3 - <<'PY'
import json, pathlib
import os
session = {}
pack = {}
try: session = json.load(open('.argos/session.json'))
except Exception: pass
try: pack = json.load(open('.argos/context-pack.json'))
except Exception: pass
changed_files = [line for line in os.environ["CHANGED_FILES"].splitlines() if line.strip()]
outcome = {
  "arm": "codex_cli",
  "arm_session_id": session.get("id") or session.get("arm_session", {}).get("id"),
  "context_pack_id": pack.get("id") or pack.get("context_pack", {}).get("id"),
  "result": "success" if os.environ["TEST_STATUS"] in ["pass", "not_run"] else "fail",
  "summary": "Codex session ended.",
  "metrics": {"test_status": os.environ["TEST_STATUS"]},
  "artifacts": {
    "git_status": os.environ["GIT_STATUS"],
    "git_diff_stat": os.environ["GIT_DIFF_STAT"],
    "changed_files": changed_files,
    "test_output": os.environ["TEST_OUTPUT"]
  },
  "author": "operator"
}
pathlib.Path('.argos/outcome.json').write_text(json.dumps(outcome, indent=2))
PY

end_payload=$(python3 - <<'PY'
import json
outcome=json.load(open('.argos/outcome.json'))
print(json.dumps({
  "arm_session_id": outcome.get("arm_session_id"),
  "status": "ended" if outcome.get("result") != "blocked" else "blocked",
  "summary": outcome.get("summary"),
  "metrics": outcome.get("metrics", {}),
  "artifacts": outcome.get("artifacts", {}),
  "author": "operator"
}))
PY
)

curl -sS "${auth_header[@]}" -H 'Content-Type: application/json' -d "$end_payload" "$ARGOS_URL/api/arms/session/end"
curl -sS "${auth_header[@]}" -H 'Content-Type: application/json' --data-binary @.argos/outcome.json "$ARGOS_URL/api/outcomes"

echo "ARGOS outcome written: .argos/outcome.json"
