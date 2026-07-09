# Current State — Honest Progress Snapshot

**Date:** 2026-07-09  
**Overall status:** Foundation complete. Not yet operational.

---

## What exists and works

### Validated artifacts

| Artifact | Count | Validation |
|---|---|---|
| JSON schemas | 16 | All pass meta-schema validation |
| Standards source entries | 9 | All validate against `standard-source.schema.json` |
| Control files | 25 (21 active, 2 deferred) | All validate against `control.schema.json` |
| Compliance profile | 1 (PROF-PLATFORM-V1) | Validates against `profile.schema.json` |
| Mapping collection files | 10 | All validate against `mapping-collection.schema.json` |
| Implementation bindings | 24 | Across GitHub, Terraform, Docker, GitHub Actions contexts |
| OPA policy files | 14 Rego + 14 `.check.yaml` | All automated merge-gate controls covered |
| Policy test fixtures | 23 YAML | Pass/fail pairs per policy |
| Evidence test fixtures | 4 YAML | valid-pass, valid-fail, valid-waived, invalid |
| Assessment report | 1 (manual, v1.0.0 self-assessment) | Validates against `assessment.schema.json` |
| Release record | 1 (v1.0.0) | Validates against `release-record.schema.json` |
| Compliance manifest | 1 (`.compliance-manifest.yaml`) | Validates against `repository-compliance.schema.json` |
| Gate criteria files | 2 (release, deployment) | Match profile gate sections exactly (verified by script) |
| ADRs | 5 (ADR-0001 through ADR-0005) | All status: accepted |

### What the validation sweep confirms

Running `check-jsonschema` against all major artifacts:
- All 16 schemas meta-valid ✓
- All 25 controls schema-valid ✓
- All 10 mapping files schema-valid ✓
- Assessment report, release record, manifest, waiver template all schema-valid ✓
- Gate files match profile sections exactly (0 divergences) ✓
- All 14 Rego files have companion `.check.yaml` ✓
- 0 binding files reference a policy that doesn't exist ✓
- 0 JSON files outside `schemas/` (ADR-0005 enforced) ✓

---

## What is partial or incomplete

### Phase 07 — Policies (~55% complete)
- **Written (14 policies):** SRC-001, SRC-002, SRC-003, SEC-001, SEC-002, SEC-003, IAC-001, SUP-001 (Terraform), SUP-001 (GitHub Actions), SUP-002, RUN-001, RUN-002, DOC-001, CHG-002
- **Missing (release/deployment gate controls):** OBS-001, OBS-002, BAK-001, NET-001, CHG-001, IAC-002, IAC-003, RUN-003, SEC-003 deployment enforcement, and several more
- **Note:** All 7 automation-target bindings have `policy_check_ids: []` with planned IDs in comments — honest about current state

### Phase 10 — Reusable workflow (~30% complete)
- Structure is correct (7-job pipeline defined)
- Most jobs have `# TODO [Phase N]:` markers instead of real implementation
- Does not actually run OPA policies against inputs
- Evidence collection is a Python stub
- Gate evaluation is simplified pass/fail, not real criteria evaluation
- **The workflow exists as a design; it cannot produce real compliance evidence**

### Phase 12 — v1.0.0 release gate (not started)
- Blocked by Phase 10 (workflow must run and produce real evidence)
- Self-assessment report was authored manually, not from CI
- Repository has not been pushed to GitHub with branch protection configured

---

## What does not exist yet

| Item | Notes |
|---|---|
| `tools/plt/` CLI | Directory exists with README; no code |
| Real evidence records from CI | All evidence is theoretical/manually authored |
| Real assessment from CI run | `ASSESS-PLATFORM-COMPLIANCE-20260708-001.yaml` is manual |
| Compliance dashboard | Not designed |
| CAT domain controls | Domain defined in taxonomy; no controls |
| REL domain controls | Domain defined in taxonomy; no controls |
| `docs/onboarding.md` | Referenced in roadmap; not created |
| `docs/authoring-controls.md` | Referenced in roadmap; not created |
| `angirasa_risk` placeholder resolution | GitHub org not yet set anywhere |
| `08-evidence/collected/` content | Directory exists; no real evidence |
| Waiver records | None granted; no real waivers exist |
| Second platform repository | ADR-0003 holds all downstream repos until v1.0.0 gate |

---

## Known placeholders requiring research

Multiple mapping files and source entries contain `[PLACEHOLDER: ...]` markers where clause-level standard references need verification against the source documents. These are tracked as tasks PC-0009, PC-0010, PC-0011 in [`tasks/v1-foundation.yaml`](tasks/v1-foundation.yaml).

---

## Summary judgment

The compliance data model is complete and internally consistent. The system can explain what must be satisfied, why, and how — but it cannot yet execute that explanation automatically. The gap is Phase A: making the workflow run for real. Everything built in Phases 1-11 is the scaffolding; Phase A is the first time it runs under its own weight.
