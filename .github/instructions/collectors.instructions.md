---
description: "Use when writing or editing platform-compliance input collectors in 07-policies/scripts (collect-*.sh / collect-*.py) or the run-all-policies.py engine. Covers the JSON output contract, defensive tool detection, and POLICY_MAP wiring."
applyTo: "07-policies/scripts/**"
---
# Input Collectors

Collectors gather facts from a repo and emit JSON that OPA policies consume. One collector per
technology context; `collect-all-inputs.py` dispatches per declared context and writes
`<control>-info.json` files; `run-all-policies.py` maps each policy to its input.

## Contract

- Emit **valid JSON** to a well-known file (e.g. `go-info.json`). Never emit partial/garbled JSON.
- Be **defensive**: if a required tool is missing, report `"unavailable"` for that check and
  keep going — a collector must never hard-fail the pipeline just because a tool is absent.
- Distinguish "tool absent" (`unavailable`) from "check ran and failed" (`fail`/`false`).

## Bash gotchas (already hit here)

- `grep -c ... || echo 0` can print a doubled `0`. Capture then default instead:
  ```bash
  COUNT=$(grep -c pattern file 2>/dev/null); COUNT=${COUNT:-0}
  ```
- Guard numeric tests: `[ "$COUNT" -gt 0 ] 2>/dev/null`.
- Keep scripts POSIX-ish and `set -euo pipefail`-safe; quote all expansions.

## Wiring a new collector

1. Add the collector under `07-policies/scripts/`, `chmod +x` if shell.
2. Dispatch it from `collect-all-inputs.py` for the matching context.
3. Add the policy → input mapping in `run-all-policies.py` `POLICY_MAP` (context-gated).
4. Test end-to-end against a real repo of that context AND a repo lacking it
   (must yield `not_applicable`, never an error).
