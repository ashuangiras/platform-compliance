# Evidence Model

**Repository:** `platform-compliance`  
**Date:** 2026-07-08  
**Schema:** [`../schemas/evidence.schema.json`](../schemas/evidence.schema.json)

This document describes the evidence model: what evidence is, how it is structured, how it is collected, and how it flows into the assessment system.

---

## What evidence is

An evidence record is the atomic unit of compliance proof. It is a structured, immutable, commit-bound record of a single policy check evaluation against a specific resource at a specific moment in time.

Evidence is not an audit log. It is not a list of things that happened. It is a structured claim: "At commit `abc123` in repository `X`, control `SRC-001` was evaluated using policy `POL-SRC-001-GITHUB-001` and the result was `pass`. The following details explain why."

Every evidence record is commit-bound: it is linked to a specific 40-character SHA. This means the compliance state of any commit in any repository's history is reconstructible from its evidence records. A deployment cannot claim compliance based on evidence collected from a different commit.

---

## Evidence record structure

All evidence records conform to [`../schemas/evidence.schema.json`](../schemas/evidence.schema.json). The following fields are required on every evidence record:

| Field | Type | Purpose |
|---|---|---|
| `id` | UUID v4 | Globally unique identifier, generated at collection time |
| `schema_version` | string | Schema version for forward-compatible parsing |
| `repository.name` | string | Short name of the repository |
| `repository.url` | URI | Full HTTPS URL to the repository |
| `commit_sha` | string (40-char hex) | The exact Git commit being evaluated |
| `control_id` | string | The control this evidence addresses (e.g., `SRC-001`) |
| `profile_version` | string | Version of the declared profile at collection time |
| `control_catalog_version` | string | Git tag/SHA of `platform-compliance` used |
| `policy_bundle_version` | string | Version of `07-policies/` used for evaluation |
| `workflow_run_id` | string | CI workflow run that produced this record |
| `evaluated_at` | ISO 8601 datetime | When the check was run |
| `result` | enum | The outcome (see Result Types below) |
| `artifact_hash` | `sha256:{hex}` | Hash of the `details` payload for tamper-evidence |

---

## Result types

Every evidence record carries one of six result values:

| Result | Meaning | Gate behavior |
|---|---|---|
| `pass` | The control is satisfied at this commit | Counts toward gate pass |
| `fail` | The control is not satisfied | Blocks gate if enforcement is `block` |
| `manual_review` | Automated check cannot determine result; requires human assessment | Holds gate until reviewed |
| `not_applicable` | Scope condition evaluated to false; control does not apply | Excluded from gate evaluation |
| `waived` | Control is failing but an active, approved waiver exists | Counts as `pass-with-waiver` in assessment |
| `error` | Policy check encountered an error; result is indeterminate | Treated as `fail` at gate unless resolved |

### Conditional fields by result type

- `result: waived` **requires** `waiver_id` referencing an active waiver record in `09-assessments/waivers/`
- `result: manual_review` **requires** `attestor` identifying the reviewer
- `result: fail` or `result: error` **should** include a `details.message` explaining the failure

---

## The artifact hash

The `artifact_hash` field is a SHA-256 hash of the serialized `details` field and any attached binary artifacts. Its purpose is tamper-evidence: if an evidence record's `details` are modified after writing, the hash will not match, indicating the record has been tampered with.

**Hash computation:**

```
artifact_hash = "sha256:" + hex(sha256(canonical_json(details)))
```

Where `canonical_json` is deterministic JSON serialization (sorted keys, no whitespace).

This does not make the evidence system cryptographically secure (the hash is stored in the same file as the details), but it detects accidental corruption and provides a basis for stronger signing in future maturity levels.

---

## Evidence immutability

Evidence records are immutable once written. They are never edited in place. If an evidence record is incorrect:

1. A new evidence record is written with the correct information
2. The original record is retained with a `voided_reason` annotation (outside the schema — tracked in ledger metadata)
3. The assessment generator uses the newest non-voided record for each `(repository, commit_sha, control_id)` combination

---

## Evidence collection methods

### Automated collection (preferred)

The `evidence-collect` workflow (see `../workflows/github/reusable-compliance.yml`) runs policy checks from `../07-policies/` and converts their output into evidence records. The workflow:

1. Reads the repository's `.compliance-manifest.yaml`
2. Resolves which controls apply (profile + scope conditions)
3. Runs each applicable policy check via the OPA evaluator
4. Converts the structured OPA output to an evidence record
5. Computes the `artifact_hash`
6. Writes the record to `../08-evidence/collected/ashuangiras/{repo}/`

### Manual collection (fallback)

For controls with `automation_status: manual` or `manual_review` results:

1. The responsible person performs the check described in the binding's `specification`
2. They write an evidence record using the template
3. Required additional fields: `attestor` (identity), `collection_method` (what was done)
4. The record is submitted via pull request to `../08-evidence/collected/`
5. The PR is reviewed by the compliance contact before merge

Manual evidence requires periodic refresh. The `assessment_cadence` of the control determines the staleness window. Manual evidence older than the cadence window is treated as stale (`not_applicable`) until refreshed.

---

## Evidence storage layout

Evidence storage follows a distributed model (ADR-0006). Each repository maintains its own evidence ledger.

### For all governed repositories (except `platform-compliance` itself)

```
{repository-root}/
└── .evidence/
    └── collected/
        └── {YYYY-MM-DD}/
            └── {sha8}-{control-id}-{epoch-ms}.yaml
```

The `.evidence/` directory is at the repository root. It is committed to git — evidence records are part of the repository's version history.

### For `platform-compliance` itself

```
08-evidence/
└── collected/
    └── {YYYY-MM-DD}/
        └── {sha8}-{control-id}-{epoch-ms}.yaml
```

`platform-compliance` uses `08-evidence/collected/` to remain consistent with its existing directory structure.

### File naming convention

```
{sha8}-{control-id}-{epoch-ms}.yaml
```

| Component | Description | Example |
|---|---|---|
| `sha8` | First 8 characters of the assessed commit SHA | `a94a8fe5` |
| `control-id` | Platform control ID | `SRC-001` |
| `epoch-ms` | Unix epoch in milliseconds at collection time | `1751981400000` |

### Future migration (PC-0164)

The current git-committed model is ADR-0006 Option B. ADR-0006 explicitly requires migration to Option C (external store — S3/MinIO) when trigger conditions are met:
- More than 10 governed repositories, OR
- Evidence directories causing noticeable repository bloat, OR
- Reliable object storage infrastructure is available

The migration from Option B to Option C requires no schema changes. Evidence records are identical; only the write destination changes.

---

## Evidence and versions

Every evidence record carries three version fields that together specify the exact compliance configuration at collection time:

| Field | What it identifies | Why it matters |
|---|---|---|
| `profile_version` | Which profile version was declared | Determines which controls were in scope |
| `control_catalog_version` | Which `platform-compliance` release | Identifies the control definitions used |
| `policy_bundle_version` | Which policy files were executed | Identifies the exact rules that produced the result |

When these versions change, older evidence records are still valid for historical reconstruction but may not satisfy the current gate criteria. The assessment generator flags evidence collected against a different `control_catalog_version` as stale when the current version has changed.

---

## Evidence types

All valid evidence type identifiers are enumerated in [`evidence-types.yaml`](evidence-types.yaml). The `type` field in a control's `evidence_required` array must match a key in that file. This ensures that every expected evidence type is documented before it is required.

See [`evidence-types.yaml`](evidence-types.yaml) for the complete list of types, their descriptions, the controls they serve, and their collection method.

---

## What evidence is not

- Evidence is not a deployment log or operational event stream
- Evidence is not a performance metric or SLI measurement
- Evidence is not a security scan report (a scan report is the raw input; the evidence record is the structured claim derived from it)
- Evidence does not accumulate indefinitely — retention policy is defined in [`ledger/format.md`](ledger/format.md) (to be authored in Phase 8)
