# 09-assessments/waivers — Waiver Records

This directory stores all active, expired, and revoked waiver records. A waiver is a documented, time-bounded exception to a platform control.

## Naming convention

`WAV-{CONTROL_ID}-{YYYYMM}-{NNN}.yaml`

Example: `WAV-BAK-001-202607-001.yaml`

## Schema

All files conform to `../../schemas/waiver.schema.json`.

## Creating a waiver

1. Copy `../../templates/waiver.template.yaml`
2. Fill in all required fields — especially `expiry_date` (no open-ended waivers)
3. Submit as a pull request to this repository
4. Add the waiver ID to the affected repository's `.compliance-manifest.yaml`
5. See `../waiver-model.md` for the full approval process

## Status lifecycle

```
active → expired (when expiry_date passes)
active → revoked (when manually cancelled)
```

Expired and revoked waivers are retained here for audit history. They are never deleted.

## What does NOT belong here

- Assessment reports (those are in `../reports/`)
- Evidence records (those are in `../../08-evidence/collected/`)
