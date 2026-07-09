# Phase 03 — Control Catalog and Compliance Profile

**Status:** ✅ Complete  
**Tasks:** PC-0012 to PC-0019

## Goal
Build the authoritative control catalog and the first compliance profile that governs all platform repositories.

## Deliverables (complete)
- 25 control files: 21 active + 2 deferred (SRC-004, SUP-003)
- Domains covered: SRC, SUP, IAC, SEC, RUN, OBS, BAK, CHG, DOC, INC, NET
- `04-profiles/PROF-PLATFORM-V1.yaml` — 4 gates, 4 control categories
- All 25 controls pass `control.schema.json` validation
- Profile passes `profile.schema.json` validation
- Cross-checks confirmed: all profile control IDs exist in catalog; all source IDs resolve

## Gate coverage in PROF-PLATFORM-V1

| Gate | Required controls | Blocking controls |
|---|---|---|
| Merge gate | 9 | SRC-001, SRC-002, SEC-001, IAC-001*, SUP-001*, SUP-002*, CHG-001** | 
| Release gate | 15 | All merge + SRC-003, SEC-002, CHG-002, DOC-001, RUN-002* |
| Deployment gate | 18 | All release + IAC-002*, OBS-001**, BAK-001***, NET-001**** |
| Continuous audit | 6 | SEC-001, SEC-002, SEC-003, SRC-001, INC-001**, BAK-001*** |

`*` scope condition; `**` platform-repo only; `***` stateful services; `****` externally exposed

## Outstanding
- PC-0016/0017/0018: Formal peer review of control statement clarity — in progress
- CAT and REL domains: defined in taxonomy but have zero controls (deferred to Phase C)
