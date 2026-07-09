# Evidence Ledger Format

**Repository:** `platform-compliance`  
**Date:** 2026-07-08  
**Schema:** [`../schema/evidence-record.schema.json`](../schema/evidence-record.schema.json) → [`../../schemas/evidence.schema.json`](../../schemas/evidence.schema.json)

This document specifies the directory structure, file naming convention, indexing approach, and retention policy for the platform evidence ledger.

---

## Directory structure

Evidence storage follows a **distributed model** (ADR-0006 — Option B). Each repository maintains its own evidence ledger.

### Downstream repositories

```
{repository-root}/
└── .evidence/
    └── collected/
        └── {YYYY-MM-DD}/
            └── {sha8}-{control-id}-{epoch-ms}.yaml
```

### platform-compliance itself

```
08-evidence/
└── collected/
    └── {YYYY-MM-DD}/
        └── {sha8}-{control-id}-{epoch-ms}.yaml
```

---

## File naming convention

```
{sha8}-{control-id}-{epoch-ms}.yaml
```

| Component | Description | Example |
|---|---|---|
| `sha8` | First 8 characters of the commit SHA | `a94a8fe5` |
| `control-id` | Platform control ID | `SRC-001` |
| `epoch-ms` | Unix epoch timestamp in milliseconds at collection time | `1751981400000` |

The `epoch-ms` component ensures uniqueness when multiple evidence records are collected for the same control at the same commit (e.g., re-runs, or evidence from different tools). It also provides natural chronological ordering within a date directory.

---

## Date directory

Evidence is organised by the **calendar date the evidence was collected** (UTC), not by the commit date. This allows the ledger to be queried by "what was collected today" independently of when the code was committed.

The date directory uses ISO 8601 format: `YYYY-MM-DD`.

---

## Indexing

No separate index file is maintained. Evidence records are queryable by:

1. **Path traversal**: `08-evidence/collected/angirasa_risk/{repo}/{date}/*.yaml`
2. **Filename parsing**: Extract `sha8` and `control-id` from any filename
3. **YAML field queries**: Load records and filter on `control_id`, `result`, `commit_sha`, `evaluated_at`

The platform CLI (`plt evidence query`) provides a query interface over the ledger without requiring a separate index.

Future tooling may introduce a SQLite index for large ledgers, but v1 uses filesystem traversal only.

---

## Retention policy

| Evidence type | Retention | Rationale |
|---|---|---|
| All evidence records | **365 days minimum** | Supports a full year of continuous audit history |
| Evidence referenced by an assessment report | **Indefinite** | Assessment reports are permanent; their referenced evidence must remain queryable |
| Evidence referenced by a release record | **Indefinite** | Release records are the audit trail for every published version |

**Retention enforcement:**

Evidence older than 365 days that is not referenced by any assessment report or release record may be archived (moved to cold storage or compressed) but must not be deleted.

The `artifact_hash` in each evidence record enables integrity verification: if an evidence file's content does not match its hash, the record is treated as corrupted and excluded from assessments.

---

## Write access control

Only the following sources may write to `08-evidence/collected/`:

1. **The `evidence-collect` reusable workflow** — automated evidence from CI/CD runs
2. **Manual evidence submissions via PR** — human-attested evidence reviewed by the compliance contact

Direct commits to `collected/` without a PR are blocked by SRC-001/SRC-002 branch protection on `platform-compliance` itself. All evidence submissions are traceable to a pull request or a specific workflow run ID.

---

## Evidence for platform-compliance itself

`platform-compliance` collects evidence for its own self-governance. Its evidence is stored at:

```
08-evidence/collected/angirasa_risk/platform-compliance/
```

This is the first evidence ledger populated in the system, and serves as the working example for all downstream repositories.

---

## See also

- [`retention.md`](retention.md) — detailed retention and archival procedures
- [`../schema/`](../schema/) — evidence record schema files
- [`../../schemas/evidence.schema.json`](../../schemas/evidence.schema.json) — canonical JSON schema
