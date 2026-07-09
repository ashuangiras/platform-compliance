# 08-evidence/ledger — Evidence Ledger Specification

This directory defines how the evidence ledger is structured and managed.

## Contents

| File | Purpose |
|---|---|
| `format.md` | Directory structure, file naming convention, indexing, retention policy |
| `retention.md` | Detailed archival and deletion procedures (to be authored) |

## Key rules

- Evidence records go in `../collected/ashuangiras/{repo}/{YYYY-MM-DD}/`
- File naming: `{sha8}-{control-id}-{epoch-ms}.yaml`
- Records are immutable once written
- Retention minimum: 365 days; indefinite for records referenced by assessment reports or release records

## See also

- `../collected/` — where evidence is actually stored
- `../../schemas/evidence.schema.json` — canonical schema for evidence records
- `../evidence-model.md` — comprehensive evidence model documentation
