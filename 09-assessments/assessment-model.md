# Assessment Model

**Repository:** `platform-compliance`  
**Date:** 2026-07-08  
**Schema:** [`../schemas/assessment.schema.json`](../schemas/assessment.schema.json)

This document describes how evidence records are converted into assessment reports and how assessment reports are evaluated against gate criteria.

---

## The role of assessment

Evidence records are raw facts. An assessment report is an interpretation: given this body of evidence for this subject under this profile, what is the compliance verdict?

Separating evidence from assessment has three advantages:
1. Evidence can be queried and analysed independently
2. Assessment reports can be regenerated from the same evidence under different criteria (e.g., after a waiver is granted)
3. Gate evaluation can be performed against a report without re-running all policies

---

## Assessment trigger events

An assessment is generated automatically by the `assessment-generate` workflow:

| Trigger | Assessment type | Gate evaluated |
|---|---|---|
| PR opened or pushed to | Pre-merge assessment | Merge gate |
| Merge to default branch | Post-merge assessment | No gate; accumulates evidence |
| Release tag pushed | Release assessment | Release gate |
| Deployment triggered | Deployment assessment | Deployment gate |
| Scheduled (daily/weekly) | Continuous audit assessment | Continuous audit |

---

## How evidence maps to control results

The assessment generator processes evidence for a given subject as follows:

```
For each control in the subject's declared profile:
  1. Retrieve all evidence records for (repository, commit_sha, control_id)
     within the evidence_window
  2. Determine scope applicability
  3. Select the most recent non-voided evidence record
  4. Apply waiver resolution
  5. Assign result
```

### Step 2 — Scope applicability

The control's `scope_conditions` are evaluated against the subject's `.compliance-manifest.yaml`. If the condition evaluates to false, the result is `not_applicable` and the control is excluded from the gate evaluation.

Example: `IAC-001` has `scope_condition: "repository.type in ['terraform-module', 'terraform-root']"`. For a service-type repository, this evaluates to false → `not_applicable`.

### Step 3 — Evidence selection

The most recent evidence record is selected within the evidence window. If no evidence record exists within the window, the result is `not_applicable` with a note that evidence is missing. Missing evidence is treated differently from a `fail`: it indicates the policy has not run, not that the control is violated.

> **Exception:** For mandatory controls with `automation_status: automated`, missing evidence within the window is escalated to `error` rather than `not_applicable`. Automated checks are expected to run; their absence is itself a compliance concern.

### Step 4 — Waiver resolution

If the selected evidence record has `result: fail` (or `error`):
1. Check the subject's `.compliance-manifest.yaml` for listed `waiver_ids`
2. For each waiver ID, check the waiver record in `09-assessments/waivers/`
3. If a waiver exists for this `control_id` and `resource_ref`, and the waiver's `status: active` and `expiry_date` is in the future: override the result to `waived`
4. If the waiver is expired or revoked: result remains `fail`

### Step 5 — Result assignment

| Evidence result | Waiver? | Assessment result |
|---|---|---|
| `pass` | n/a | `pass` |
| `fail` | No waiver | `fail` |
| `fail` | Active waiver | `waived` |
| `manual_review` | n/a | `manual_review` |
| `not_applicable` | n/a | `not_applicable` |
| `error` | No waiver | `error` (treated as `fail` at gate) |
| `error` | Active waiver | `waived` |
| No evidence (automated) | n/a | `error` |
| No evidence (manual, within cadence) | n/a | `not_applicable` |
| No evidence (manual, stale) | n/a | `manual_review` |

---

## Overall result derivation

After all control results are determined, the overall report result is calculated:

| Condition | Overall result |
|---|---|
| All mandatory in-scope controls: `pass` or `not_applicable` | `pass` |
| All mandatory in-scope controls: `pass`, `not_applicable`, or `waived`; at least one `waived` | `pass-with-waivers` |
| Any mandatory in-scope control: `manual_review` (and none are `fail`) | `manual-review-required` |
| Any mandatory in-scope control: `fail` or `error` | `fail` |
| Any mandatory in-scope control has no evidence (missing): indeterminate | `inconclusive` |

A `fail` takes precedence over `manual-review-required`. An `inconclusive` result is treated as `fail` at the gate.

---

## Gate evaluation

Assessment reports are the input to gate evaluation. A gate evaluation applies the gate criteria (from `09-assessments/gates/`) to the assessment report's `control_results`.

For each control in the gate's `required_controls`:

```
if control.result == 'pass' or 'not_applicable' or 'waived':
    → control contributes to gate PASS

if control.result == 'fail' or 'error':
    if gate_enforcement == 'block':
        → control blocks the gate; adds to blocking_controls list
    if gate_enforcement == 'warn':
        → gate produces PASS-WITH-WARNINGS; warning logged

if control.result == 'manual_review':
    if gate_enforcement == 'block':
        → gate is held pending review; treated as INCONCLUSIVE
    if gate_enforcement == 'warn':
        → warning logged; gate may proceed
```

### Gate outcomes

| Condition | Gate outcome | Action |
|---|---|---|
| All required controls: pass / not_applicable / waived | `pass` | Gated action proceeds |
| Some required controls: warn only | `pass-with-warnings` | Gated action proceeds; warnings visible in CI |
| Any required control with `block` enforcement: `fail` or `error` | `fail` | Gated action blocked; `blocking_controls` listed |
| Any required control with `block` enforcement: `manual_review` | `held` | Gated action held pending human review |

---

## Gate criteria files

The machine-readable gate criteria are in `09-assessments/gates/`. They are derived from the profile gates defined in `04-profiles/PROF-PLATFORM-V1.yaml` but expressed in a format directly consumed by the gate evaluation workflow.

The gate criteria files and the profile gates **must be kept in sync**. A CI check verifies consistency between them.

---

## Assessment report retention

Assessment reports are retained indefinitely. They constitute the compliance history of the platform. Each release gate assessment is referenced by the release record, creating a permanent link between a released version and its compliance state at release time.

Reports in `09-assessments/reports/` are organized by subject:
```
09-assessments/reports/
└── {repo-slug}/
    └── ASSESS-{SUBJECT_SLUG}-{YYYYMMDD}-{NNN}.yaml
```

---

## What a report enables

Given a release tag, an auditor can:
1. Find the release record in `09-assessments/releases/`
2. Follow `gate_assessment_id` to the assessment report
3. See the compliance verdict for every in-scope control
4. Follow `evidence_ids` to individual evidence records
5. Follow `waiver_id` to any waivers that were in effect
6. Follow `control_catalog_version` to the exact control definitions used
7. Follow each control's `mapped_standards` to the external standard citations

This chain is complete and requires no external system to reconstruct.
