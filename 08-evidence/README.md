# 08-evidence — Evidence System

This directory defines the evidence schema, the ledger format, and (optionally) stores collected evidence records. Evidence is the factual record of what was checked, when, and what the result was.

## Structure

```
08-evidence/
├── README.md           ← this file
├── evidence-model.md   ← comprehensive evidence model documentation
├── evidence-types.yaml ← 28 named evidence types covering all 23 controls
├── schema/             ← schema test fixtures (the canonical schema is schemas/evidence.schema.json)
│   └── test-fixtures/
├── ledger/             ← ledger format specification and retention rules
│   ├── format.md
│   └── retention.md
└── collected/          ← evidence records for platform-compliance itself
    └── {YYYY-MM-DD}/
        └── {sha8}-{control-id}-{epoch-ms}.yaml
```

## Evidence storage model (ADR-0006)

Evidence follows a **distributed model**: each repository stores its own evidence in a `.evidence/` directory at its root. `platform-compliance` itself uses `08-evidence/collected/` (consistent with this repo's domain structure).

Evidence records are committed to git. Future migration to external storage (S3/MinIO) is tracked as task PC-0164 and will be decided when trigger conditions in ADR-0006 are met.

## Evidence record properties

An evidence record links: control → policy → resource → commit → result → timestamp.

Key constraints:
- Evidence records are immutable once written
- A `result: waived` record must reference an active waiver in `../09-assessments/waivers/`
- Evidence for automated controls must include a `policy_check_id`
- Evidence for manual controls must include an `attestor` identity and `collection_method`

## Write access

Only the platform CI system (via the reusable `evidence-collect` workflow) should have write access to `collected/`. Human-submitted evidence records require a pull request reviewed by the compliance contact.

## What does NOT belong here

- Policy code (that is in `../07-policies/`)
- Assessment reports (those are in `../09-assessments/`)
- Waivers (those are in `../09-assessments/waivers/`)
- Infrastructure state files or configuration
