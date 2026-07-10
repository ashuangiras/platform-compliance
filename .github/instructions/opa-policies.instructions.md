---
description: "Use when writing or debugging OPA/Rego policies for platform-compliance under 07-policies/opa. Covers the package/input/output contract, the eval_conflict_error pattern, not_applicable exclusivity, set-iteration syntax, and how to compile and test."
applyTo: "07-policies/opa/**/*.rego"
---
# OPA / Rego Policy Rules

Engine contract: [07-policies/opa/README.md](../../07-policies/opa/README.md).

## Compile + test (post-flight, mandatory)

```bash
/tmp/opa check 07-policies/opa/                 # must be clean
/tmp/opa eval -d <policy>.rego -i <fixture>.json 'data.<pkg>.result'
```

Each policy ships a `*.check.yaml` metadata file and pass/fail fixtures. Add fixtures for
every new rule and verify both a passing and a failing case.

## Output contract

A policy exposes `result` ∈ {`pass`, `fail`, `warn`, `error`, `not_applicable`} plus a `reason`.
`warn` is used when a threshold-based control triggers the lower of two thresholds (e.g. bundle-size budget at 500 KB); the block gate fires at the higher threshold (e.g. 2 MB). A `warn` result does not block the gate.
`result` rules MUST be **mutually exclusive** — overlapping outputs cause `eval_conflict_error`.

## Gotchas that have bitten this repo (do not repeat)

- **eval_conflict_error**: a *complete* rule that can produce multiple values fails. Use a
  partial set to gather, then derive a single value:
  ```rego
  found_actions[a] if { some a in input.items; a.bad }
  found_action := a if { some a in found_actions } else := ""
  ```
- **not_applicable vs fail conflict**: guard with a helper predicate (e.g. `mfa_status_known`)
  so `not_applicable` and `fail` can never both hold.
- **Set concat/iteration**: `concat(", ", {v | some v in input.violations})` —
  NOT `concat(", ", input.violations)`.
- **Conflict symptom on Linux CI**: OPA prints `{}[<error text>]`, so `json.loads` fails with
  `Extra data: line 1 column 3`. That means a policy conflict, not a JSON bug.

## Wiring

After adding a policy, register it in `07-policies/scripts/run-all-policies.py` `POLICY_MAP`
with the correct `context` (so it reports `not_applicable` on repos that lack that context)
and the input file its collector produces.
