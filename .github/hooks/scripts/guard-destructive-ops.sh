#!/usr/bin/env bash
# PreToolUse guard for platform-compliance agents.
#
# Reads the hook payload on stdin and asks the user to confirm before any tool call that
# would perform an irreversible or destructive operation (force-push, hard reset, rm -rf,
# --no-verify, or branch/tag deletion). Non-destructive calls pass through untouched.
#
# Contract: emit a PreToolUse permissionDecision of "ask" only when a dangerous pattern is
# present; otherwise stay silent and exit 0 (default behavior). This never hard-blocks — it
# forces a human decision on the risky operations, in line with the repo's safety model.
set -uo pipefail

payload="$(cat)"

# Hard-to-reverse patterns (extended regex, case-insensitive).
patterns='git[[:space:]]+push[[:space:]]+.*(--force|-f([[:space:]]|$))'
patterns+='|--force-with-lease'
patterns+='|git[[:space:]]+reset[[:space:]]+--hard'
patterns+='|(^|[^a-zA-Z])rm[[:space:]]+-[a-zA-Z]*[rR]'
patterns+='|(^|[^a-zA-Z])rm[[:space:]]+--recursive'
patterns+='|--no-verify'
patterns+='|git[[:space:]]+branch[[:space:]]+-D'
patterns+='|git[[:space:]]+branch[[:space:]]+--delete[[:space:]]+--force'
patterns+='|git[[:space:]]+push[[:space:]]+.*--delete'
patterns+='|git[[:space:]]+tag[[:space:]]+-d'
patterns+='|git[[:space:]]+filter-branch'

if printf '%s' "$payload" | grep -Eiq "$patterns"; then
  reason="Irreversible operation detected (force-push, hard reset, rm -rf, --no-verify, or branch/tag deletion). Confirm this is intended before proceeding."
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$reason"
fi

exit 0
