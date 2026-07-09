# Phase 12 — v1.0.0 Release Gate

**Status:** ⬜ Not started  
**Tasks:** PC-0081 to PC-0086  
**Hard blocker:** Phase 10 (workflow) must be complete first

## Goal
Run platform-compliance through its own release gate. The first CI run produces real evidence. The first real assessment report replaces the manual one. `v1.0.0` is tagged.

## The 7 readiness conditions (ADR-0003)
All must be true before `git tag v1.0.0`:

| # | Condition | Status |
|---|---|---|
| 1 | CI is green — all mandatory automated controls pass on `main` | ⬜ Needs GitHub + Phase 10 |
| 2 | Self-assessment passes — CI-generated, not manually authored | ⬜ Needs Phase 10 |
| 3 | All 16 schemas pass meta-schema validation | ✅ |
| 4 | Reusable workflows callable at `@v1.0.0` | ⬜ Needs Phase 10 |
| 5 | `docs/consuming-compliance.md` complete | ✅ |
| 6 | v1.0.0 release record exists | ✅ (authored manually — will be confirmed by gate) |
| 7 | ADR-0001 through ADR-0005 have status `accepted` | ✅ |

## Tasks
- **PC-0081:** Push repo to GitHub, configure branch protection (SRC-001/002)
- **PC-0082:** Enable GitHub secret scanning + push protection (SEC-002)
- **PC-0083:** First CI run — collect evidence, generate real assessment report
- **PC-0084:** Review assessment report — resolve or waive any failures
- **PC-0085:** Write `docs/next-repo-readiness.md` confirmation (update existing)
- **PC-0086:** Tag `v1.0.0`, confirm release record references passing assessment

## Acceptance criteria
- `git tag v1.0.0` exists
- CI on that tag shows all merge gate and release gate mandatory controls passing
- `09-assessments/reports/platform-compliance/` contains a CI-generated report with `overall_result: pass` or `pass-with-waivers`
- Any waivers are in `09-assessments/waivers/` with `status: active` and valid expiry
