# Phase 08 — Evidence Model

**Status:** ✅ Complete  
**Tasks:** PC-0060 to PC-0063

## Goal
Define the evidence schema, ledger structure, and collection process. Every policy check result has a defined, immutable, commit-bound evidence record format.

## Deliverables (complete)
- `schemas/evidence.schema.json` — 9 required fields including `artifact_hash`
- `08-evidence/evidence-model.md` — immutability, collection, storage, version fields
- `08-evidence/evidence-types.yaml` — 28 named evidence types covering all 23 controls
- `08-evidence/ledger/format.md` — directory structure, naming, retention rules
- 4 test fixtures (valid-pass, valid-fail, valid-waived, invalid-missing-required)
- Invalid fixture correctly rejected by schema ✅

## Key design decisions baked into the schema
- Evidence is **commit-bound**: `commit_sha` is a required 40-char hex field
- Version triad required: `profile_version`, `control_catalog_version`, `policy_bundle_version`
- `artifact_hash` is required: `sha256:{hex}` of the `details` payload — tamper-evidence
- `result: waived` requires `waiver_id` (enforced by schema conditional)

## Outstanding
- `08-evidence/ledger/retention.md` — detailed archival/deletion procedures not yet written
- `08-evidence/collected/` is empty — no real evidence exists yet (filled in Phase A)
- Write access control for `collected/` — needs CI pipeline enforcing (Phase A)
