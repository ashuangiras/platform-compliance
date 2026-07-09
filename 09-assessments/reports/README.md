# 09-assessments/reports — Assessment Reports

This directory stores generated compliance assessment reports, one subdirectory per repository or service.

## Structure

```
reports/
└── {repo-slug}/
    └── ASSESS-{SUBJECT_SLUG}-{YYYYMMDD}-{NNN}.yaml
```

Example: `reports/platform-compliance/ASSESS-PLATFORM-COMPLIANCE-20260708-001.yaml`

## Schema

All files conform to `../../schemas/assessment.schema.json`.

## How reports are generated

Assessment reports are generated automatically by the `assessment-generate` reusable workflow. They aggregate evidence records for a subject over an assessment window and produce a per-control verdict and an overall compliance result.

Manual reports (like the self-assessment for v1.0.0) follow the same schema and are submitted via pull request.

## Retention

Reports are retained indefinitely. They constitute the compliance history of the platform. Release records reference specific assessment report IDs to link a version tag to its compliance state.

## What does NOT belong here

- Evidence records (those are in `../../08-evidence/collected/`)
- Waivers (those are in `../waivers/`)
- Release records (those are in `../releases/`)
