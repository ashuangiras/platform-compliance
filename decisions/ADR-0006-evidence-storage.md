# ADR-0006: Distributed evidence storage — each repository owns its own ledger

| Field | Value |
|---|---|
| **ID** | ADR-0006 |
| **Status** | accepted |
| **Date** | 2026-07-09 |
| **Deciders** | platform-team |

---

## Context

The `evidence-collect` step in the reusable compliance workflow needed to know where evidence records should be written. Three options were evaluated (see the proposal in `docs/implementation/decisions-needed/ADR-0006-evidence-storage.md`):

- **Option A** — Centralised in `platform-compliance` (write contention, does not scale)
- **Option B** — Distributed (each repository owns its own evidence ledger)
- **Option C** — External store (object storage or database; requires infrastructure not yet available)

Option A was rejected due to write contention: at any real scale, every CI run in every governed repository would create a PR to `platform-compliance`, making it a write bottleneck and defeating PR-based review.

Option C was rejected as a bootstrap-phase decision because it requires operational infrastructure (S3-compatible storage, access credentials) that is itself governed by controls not yet in place.

---

## Decision

**Adopt Option B: each repository maintains its own evidence ledger.**

### Directory naming

Each governed repository stores evidence records at:
```
.evidence/collected/{YYYY-MM-DD}/{sha8}-{control-id}-{epoch-ms}.yaml
```

The `.evidence/` directory is at the repository root. The `collected/` subdirectory matches the naming established in `platform-compliance`'s own `08-evidence/collected/` path.

**Exception:** `platform-compliance` itself stores evidence under `08-evidence/collected/` to remain consistent with its existing directory structure. All other repositories use `.evidence/collected/`.

### Commit evidence to git

Evidence records are committed to git in the repository they cover. Every CI run that collects evidence commits the new records as part of that run's completion. This provides:
- Immutable, version-controlled evidence tied to the commit SHA it covers
- Evidence retention governed by the repository's git history
- No external service dependency for evidence collection or retrieval

### Future migration path

This decision is explicitly time-boxed to Phases A and B (v1.x). Option C (external storage) must be evaluated when the platform has:
1. Reliable object storage infrastructure (Phase C or later)
2. More than 10 governed repositories
3. Evidence ledgers growing large enough to cause repository bloat concerns

The migration from Option B to Option C does not require schema changes — evidence records are identical in both models. Only the write destination changes. The task for evaluating this migration is tracked as **PC-0164**.

---

## Consequences

**Positive:**

- The compliance workflow can write evidence without opening a PR to `platform-compliance`. Each repository's own CI writes to its own branch.
- Evidence is co-located with the code it covers. A developer can inspect compliance history with standard git tools: `git log .evidence/collected/`.
- No external infrastructure required to start collecting evidence.
- Write access is controlled by the repository's own branch protection — the same control that governs all other changes.
- Evidence files are small YAML documents; repository size growth is manageable for a small platform.

**Negative / trade-offs:**

- Evidence is spread across repositories. Cross-repository compliance queries require reading from multiple repositories (addressed by the `plt report status` command in Phase B and the dashboard in Phase D).
- Git history for evidence commits may create noise in the repository log. Mitigation: use a dedicated `evidence/` branch or a commit message convention (`chore(evidence): collect compliance evidence for {sha}`) that can be filtered in log views.
- Rotating evidence out of git history requires force-push (violates SRC-001). Mitigation: evidence retention is by definition permanent for records referenced by assessment reports; unreferenced old evidence can be archived to a separate branch rather than purged from main.

**Constraints introduced:**

- The `.evidence/` directory must be present in every governed repository that has had a CI compliance run.
- `.evidence/collected/` must be listed in `.gitignore` if the repository's CI writes evidence as workflow artifacts first and then commits selectively. Alternatively, evidence is committed directly.
- Consuming repositories must add the `.evidence/` write step to their CI pipeline by referencing the updated reusable workflow.
- When Option C is adopted (PC-0164), the `collect-evidence` job in the reusable workflow must be updated to write to both locations during the transition period, then to Option C only.

---

## Implementation impact

- `08-evidence/evidence-model.md`: Update the "Evidence storage layout" section to document the `.evidence/` path for downstream repos
- `.github/workflows/reusable-compliance.yml`: The `collect-evidence` job writes to `.evidence/collected/` in the calling repository's workspace, then commits
- `docs/consuming-compliance.md`: Add a note that `.evidence/` will be created in the repository by the first CI run

---

## Relation to platform principles

This decision applies Platform Principle P7 (the platform governs itself first) by explicitly documenting the migration obligation before Option C becomes necessary, rather than deferring it silently.
