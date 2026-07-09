# Phase 06 — Implementation Bindings

**Status:** ✅ Complete  
**Tasks:** PC-0040 to PC-0047

## Goal
For every active control, at least one binding describes how it is satisfied in the applicable technology context.

## Deliverables (complete)
24 binding files in `06-bindings/bindings/`:

| Context | Count | Controls bound |
|---|---|---|
| `github/` | 13 | SRC-001-003, SEC-001-003, DOC-001-002, CHG-001-002, OBS-002, BAK-001, INC-001, NET-001 |
| `terraform/` | 4 | IAC-001-003, SUP-001 |
| `docker/` | 5 | RUN-001-003, SUP-002, OBS-001 |
| `github-actions/` | 1 | SUP-001 (action pinning) |

All 24 files validate against `binding.schema.json`.  
0 bindings reference a policy check ID that doesn't exist (PC-0047 ✅).

## Design note
7 bindings for automation-target controls have `policy_check_ids: []` with planned IDs preserved in YAML comments. This is intentional: the planned policy ID signals intent without referencing a non-existent file. These policies will be written in Phase A.
