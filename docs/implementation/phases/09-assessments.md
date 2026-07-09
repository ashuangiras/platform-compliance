# Phase 09 — Assessments, Waivers, and Release Records

**Status:** ✅ Complete  
**Tasks:** PC-0064 to PC-0068

## Goal
The assessment system converts evidence into verdicts, gates block on those verdicts, waivers provide documented exceptions, and release records link versions to their compliance state.

## Deliverables (complete)
- `09-assessments/gates/release-gate.yaml` — 15 required controls
- `09-assessments/gates/deployment-gate.yaml` — 18 required controls
- Both gate files match their profile counterparts exactly (0 divergences verified)
- `09-assessments/assessment-model.md`
- `09-assessments/waiver-model.md`
- `09-assessments/changes/CHG-20260708-001.yaml` — first change record
- `09-assessments/releases/v1.0.0.yaml` — release record
- `09-assessments/reports/platform-compliance/ASSESS-PLATFORM-COMPLIANCE-20260708-001.yaml` — manual self-assessment
- `schemas/assessment.schema.json`, `waiver.schema.json`, `release-record.schema.json`, `change-record.schema.json`

## 5-result assessment system

| Result | Meaning | Gate behavior |
|---|---|---|
| `pass` | Control satisfied | Gate passes for this control |
| `fail` | Not satisfied, no waiver | Blocks gate if `enforcement: block` |
| `manual_review` | Human review required | Holds gate |
| `not_applicable` | Scope condition false | Excluded from gate |
| `waived` | Active approved waiver | Counts as pass-with-waiver |

## Outstanding
- **ADR-0007 needed:** Waiver approval governance — who approves, what authority level, maximum duration by priority
- `09-assessments/waivers/` is empty — no real waivers have been granted yet
- Assessment report is manually authored — a real CI-generated report will replace it in Phase A
- `commit_sha` in assessment report is omitted — will be set to actual SHA when v1.0.0 is tagged
