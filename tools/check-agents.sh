#!/usr/bin/env bash
#
# check-agents.sh — Local "fail loudly" checker for agent configuration (AGT controls).
#
# Runs the agent-config collector and evaluates every AGT OPA policy against THIS repository,
# entirely offline (no GitHub API needed). Prints a clear pass/fail report and exits non-zero
# if any agent-configuration control fails — so a developer catches a sub-standard agent setup
# locally, before it ever reaches CI.
#
# Usage:  tools/check-agents.sh            # checks the repository root
#         tools/check-agents.sh /path/repo # checks another repo
#
set -uo pipefail

# Resolve the repository root (this script lives in <repo>/tools/).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET="${1:-$REPO_ROOT}"

cd "$REPO_ROOT" || exit 2

# Locate tools.
PY="$(command -v python3 || true)"
OPA="$(command -v opa || true)"
[ -z "$OPA" ] && [ -x /tmp/opa ] && OPA="/tmp/opa"

if [ -z "$PY" ]; then echo "ERROR: python3 not found" >&2; exit 2; fi
if [ -z "$OPA" ]; then echo "ERROR: opa not found on PATH (or /tmp/opa)" >&2; exit 2; fi

COLLECTOR="07-policies/scripts/collect-agent-info.py"
POLDIR="07-policies/opa/AGT"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if ! "$PY" "$COLLECTOR" "$TARGET" > "$tmp/agent-info.json" 2>"$tmp/err"; then
  echo "ERROR: collector failed:" >&2; cat "$tmp/err" >&2; exit 2
fi

echo "Agent configuration check for: $TARGET"
echo "──────────────────────────────────────────────"

fails=0
total=0
for rego in "$POLDIR"/POL-AGT-*.rego; do
  [ -e "$rego" ] || continue
  total=$((total + 1))
  num="$(basename "$rego" | sed -E 's/.*POL-AGT-([0-9]+)-.*/\1/')"
  query="data.platform.agt.agt_${num}_agent.result"
  out="$("$OPA" eval -d "$rego" -i "$tmp/agent-info.json" "$query" --format raw 2>/dev/null)"
  res="$(printf '%s' "$out" | "$PY" -c 'import json,sys
try:
    d=json.load(sys.stdin); print(d.get("result","error"))
except Exception:
    print("error")')"
  msg="$(printf '%s' "$out" | "$PY" -c 'import json,sys
try:
    d=json.load(sys.stdin); print(d.get("details",{}).get("message",""))
except Exception:
    print("")')"
  case "$res" in
    pass)            printf '  ✓ AGT-%s  pass\n' "$num" ;;
    not_applicable)  printf '  ○ AGT-%s  n/a\n' "$num" ;;
    *)               printf '  ✗ AGT-%s  %s — %s\n' "$num" "$res" "$msg"; fails=$((fails + 1)) ;;
  esac
done

echo "──────────────────────────────────────────────"
if [ "$fails" -gt 0 ]; then
  echo "FAIL: $fails of $total agent-configuration control(s) did not pass." >&2
  echo "Fix the items above; agent setup must meet the platform's AGT standards." >&2
  exit 1
fi
echo "OK: all $total agent-configuration controls passed."
