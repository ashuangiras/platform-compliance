# 09-assessments — Assessment System

This directory contains the gate criteria, assessment report templates, generated assessment reports, and waiver records.

## What this directory owns

- Gate criteria files (release gate, deployment gate)
- Assessment report templates
- Generated assessment reports (one directory per subject)
- Waiver records

## Status

**Not yet populated.** Phase 9 of the implementation roadmap (tasks PC-0064 to PC-0068) covers the gate criteria files, templates, and waiver model.

## Planned subdirectory structure

```
09-assessments/
├── README.md           ← this file
├── gates/
│   ├── release-gate.yaml       ← machine-readable release gate criteria
│   └── deployment-gate.yaml    ← machine-readable deployment gate criteria
├── templates/
│   └── assessment-report.template.yaml
├── reports/
│   └── {repo-slug}/
│       └── ASSESS-{SUBJECT}-{DATE}-{NNN}.yaml
├── waivers/
│   ├── README.md
│   └── WAV-{CONTROL_ID}-{YYYYMM}-{NNN}.yaml
└── releases/
    └── v{VERSION}.yaml         ← release records
```

## Gate criteria files

The gate criteria files are the machine-readable source of truth consumed by the CI gate workflows. They are derived from the profile gates in `../04-profiles/PROF-PLATFORM-V1.yaml` and expressed in a format the workflows can evaluate directly.

**These files must be kept in sync with the profile.** A gate file that diverges from the profile is a split source of truth and a compliance defect.

## Waivers

Waivers are documented exceptions to controls. Every waiver must have:
- A specific `control_id` and `resource_ref`
- A documented `rationale` and `risk_acceptance_statement`
- A named `approved_by` (platform-owner level for P1 controls)
- An `expiry_date` (no open-ended waivers)

Waivers appear in every assessment report that covers the waived control. Expired waivers are treated as non-existent; the control reverts to failing.

## What does NOT belong here

- Evidence records (those are in `../08-evidence/`)
- Policy code (that is in `../07-policies/`)
- Controls (those are in `../03-catalogs/`)
- Incident records (see future INC domain tooling)
