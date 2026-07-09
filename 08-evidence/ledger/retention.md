# Evidence Ledger — Retention Policy

**Schema:** [`../../schemas/evidence.schema.json`](../../schemas/evidence.schema.json)  
**Date:** 2026-07-09

---

## Retention rules

| Evidence category | Minimum retention | Reason |
|---|---|---|
| All evidence records | 365 days | Supports a full continuous audit year |
| Records referenced by an assessment report | Indefinite | Assessment reports are permanent; their evidence must remain queryable |
| Records referenced by a release record | Indefinite | Release records link a version tag to its compliance evidence |
| Evidence for unreleased commits | 90 days | Short-lived branches and squashed commits produce evidence that is not needed long-term |

**No evidence record that is referenced by an assessment report or release record may be deleted or modified.**

---

## Archival process (after 365 days)

Evidence records older than 365 days that are **not** referenced by any assessment report or release record may be archived:

1. **Archive location:** Move to a `{repo-root}/.evidence/archive/{year}/` directory
2. **Compression:** Compress archived directories: `tar -czf archive-{year}.tar.gz {year}/`
3. **Integrity check:** Before archiving, run `sha256sum` on all files and store the manifest in `archive-{year}.sha256`
4. **Git history:** The original commit history preserves the content; the archive is a space optimisation only

This process is not automated in v1. It becomes relevant when `.evidence/collected/` directories grow large (expected at 3+ repos with high commit frequency).

---

## Integrity verification

Every evidence record has an `artifact_hash: sha256:{hex}` field. To verify:

```bash
# Verify a single evidence record's integrity
/tmp/penv/bin/python3 -c "
import yaml, json, hashlib
with open('.evidence/collected/2026-07-09/abc123-SRC-001-1234567890.yaml') as f:
    record = yaml.safe_load(f)
details = json.dumps(record['details'], sort_keys=True).encode()
computed = 'sha256:' + hashlib.sha256(details).hexdigest()
stored = record['artifact_hash']
print('VALID' if computed == stored else f'TAMPERED: stored={stored} computed={computed}')
"
```

---

## Migration to external storage (PC-0164)

The current git-committed evidence model (ADR-0006 Option B) will be migrated to external storage (Option C) when trigger conditions are met. At that point:
- Git-committed evidence remains in place as the historical record
- New evidence writes to the external store
- The retention policy above applies to both stores
