# Architecture Decision Records

This directory contains all Architecture Decision Records (ADRs) for `platform-compliance`.

An ADR is an immutable record of a significant architecture decision: what was decided, in what context, and with what consequences. ADRs are created before the decisions they document are implemented (see DOC-002).

## Format

All ADRs follow the template in [../templates/adr-template.md](../templates/adr-template.md), which is derived from the Nygard ADR format registered as source `SRC-NYGARD-ADR-2011`.

Required sections: Title, Status, Date, Deciders, Context, Decision, Consequences.

## Statuses

| Status | Meaning |
|---|---|
| `proposed` | Under discussion; not yet ratified |
| `accepted` | Ratified; the decision is in effect |
| `deprecated` | No longer recommended but not replaced |
| `superseded` | Replaced by a newer ADR; the superseded_by field names the replacement |

## Index

| ID | Title | Status |
|---|---|---|
| [ADR-0001](ADR-0001-platform-compliance-first.md) | Platform compliance is built before any infrastructure implementation | accepted |
| [ADR-0002](ADR-0002-github-primary-remote.md) | GitHub is the primary and initial root-of-trust remote | accepted |
| [ADR-0003](ADR-0003-no-implementation-before-controls.md) | No infrastructure implementation repository may be created before platform-compliance reaches v1.0.0 | accepted |
| [ADR-0004](ADR-0004-opa-policy-engine.md) | OPA/Rego is the primary policy engine; shell scripts are data collection only | accepted |
| [ADR-0005](ADR-0005-yaml-for-all-files.md) | YAML for all human-authored files; JSON Schema (.schema.json) is the sole exception | accepted |
| [ADR-0006](ADR-0006-evidence-storage.md) | Distributed evidence storage — each repository owns its own `.evidence/` ledger; future migration to external store tracked as PC-0164 | accepted |
| [ADR-0007](ADR-0007-waiver-governance.md) | Waiver approval governance — PR review as canonical approval event; approver levels and max durations by control priority | accepted |

## Rules

- ADR IDs are sequential and never reused.
- ADRs are immutable once accepted. Corrections are made in a superseding ADR, not by editing the original.
- A superseded ADR retains its file and its original content with an updated `Status` line and a `superseded_by` reference.
- ADRs are cited by controls using the `adr_ids` field and by profiles and bindings where platform decisions (not external standards) are the provenance.
