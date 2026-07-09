# ADR-0007: Waiver approval governance — PR review as the canonical approval event

| Field | Value |
|---|---|
| **ID** | ADR-0007 |
| **Status** | accepted |
| **Date** | 2026-07-09 |
| **Deciders** | platform-team |

---

## Context

The waiver schema (`schemas/waiver.schema.json`) requires `approved_by` and `expiry_date`. The waiver model document (`09-assessments/waiver-model.md`) referenced "platform-owner level approval" for P1 controls without defining who the platform owner is, what the approval process is, or what the maximum waiver duration is.

Without a formal process, any waiver granted is informal and cannot be audited. This ADR establishes the governance process for granting, reviewing, and renewing waivers.

The proposal (see `docs/implementation/decisions-needed/ADR-0007-waiver-governance.md`) evaluated two mechanisms:
- **Option A** — PR approval: the PR merge constitutes the approval; CODEOWNERS restricts who can approve
- **Option B** — Separate approval file: approval can come from outside GitHub (comment, Slack, etc.)

---

## Decision

**Adopt Option A: PR review is the canonical approval event for all waivers.**

A waiver is created by:
1. Authoring a YAML file conforming to `schemas/waiver.schema.json` in `09-assessments/waivers/`
2. Opening a pull request to `platform-compliance` adding the waiver file
3. Obtaining the required approvals via GitHub PR review
4. Merging the PR — the merge timestamp is the `approved_date`

The CODEOWNERS entry for `09-assessments/waivers/` restricts approval to `@platform-team` for all waiver levels. For P1 controls, the platform owner (senior member of `@platform-team`) must be the reviewing approver — this is documented in the waiver record's `approved_by` field by name, not just by team.

### Approver levels by control priority

| Control priority | Required approver | Approval mechanism |
|---|---|---|
| P1 — Critical | Named platform owner; `@platform-team` is the CODEOWNERS restriction | PR review + explicit named approver in `approved_by` field |
| P2 — High | Any member of `@platform-team` | PR review by any team member |
| P3 — Medium | Repository compliance contact + one `@platform-team` reviewer | PR review with two approvals |
| P4 — Low | Repository compliance contact only | Self-attested PR; `approved_by` is the compliance contact |

### Maximum waiver duration by priority

| Priority | Maximum duration | Mandatory review cadence |
|---|---|---|
| P1 | 90 days | Every 30 days (set `review_date` at +30 and +60 days) |
| P2 | 180 days | At expiry |
| P3 | 365 days | At expiry |
| P4 | 365 days | At expiry |

These are ceilings. A shorter duration is always preferred. If a waiver is granted for a longer period than necessary, the approver is accountable for the extended risk acceptance.

### Waiver renewal

A renewal is a **new waiver record** with a new ID, new `approved_date`, and new `expiry_date`. The previous waiver's `status` is updated to `expired` (or it expires automatically by date). Renewals require fresh rationale — "same as before" is not acceptable. The reviewer must confirm that the original circumstances still apply and that no alternative remediation has become available.

### No perpetual waivers

Every waiver has an `expiry_date`. No exceptions. A control that will never be satisfied under any foreseeable circumstances is a candidate for reclassification:
- Move it from `mandatory` to `manual_initially` or `deferred` in the profile (via the normal change record + ADR process)
- Do not use the waiver mechanism as a permanent exception

---

## Consequences

**Positive:**

- Approval is traceable to a specific PR, a named reviewer, and a timestamp. An auditor can reconstruct every waiver decision from git history.
- The existing SRC-001 and SRC-002 controls on `platform-compliance` itself enforce that waiver PRs go through review — no waiver can be self-merged.
- The `expiry_date` requirement creates a forcing function: waivers are periodically re-evaluated.
- CODEOWNERS on `09-assessments/waivers/` ensures that a repository owner cannot grant their own waiver without platform-team review.

**Negative / trade-offs:**

- All waivers require a PR to `platform-compliance`. For P4 waivers on low-impact controls, this may feel heavyweight. Mitigation: P4 waivers can be batched in a single PR if multiple waivers are needed simultaneously.
- "Platform owner" is not a formal role with a defined title — it is whoever the most senior/responsible member of `@platform-team` is at the time the waiver is granted. This should be updated in the CODEOWNERS file as team composition changes.
- Waivers granted via Option B (informal channels) before this ADR was ratified are retroactively invalid. Any such informal exceptions must be formalised as proper waiver records or the control must be remediated.

**Constraints introduced:**

- The `09-assessments/waivers/` directory is restricted in CODEOWNERS to `@platform-team`
- The `approved_by` field in waiver records must name an individual, not a team (e.g., `approved_by: alice` not `approved_by: platform-team`)
- A CI check should validate that all active waivers listed in `.compliance-manifest.yaml` have corresponding records in `09-assessments/waivers/` with `status: active` and non-expired `expiry_date`
- The continuous audit gate must flag waivers within 30 days of expiry (implementation task: PC-0152)

---

## CODEOWNERS impact

The CODEOWNERS file must be updated to add an explicit restriction on `09-assessments/waivers/`:

```
# Waiver approvals — restricted to platform-team
# P1 controls: named platform owner must be the reviewer
09-assessments/waivers/    @platform-team
```

This is already covered by the existing `09-assessments/  @platform-team` entry, so no CODEOWNERS change is required. The P1 requirement for a named individual is enforced by convention (the `approved_by` field) rather than technical restriction.

---

## Relation to platform principles

This ADR implements Platform Principle P6 (every exception is documented, time-bounded, and visible). The PR-as-approval-event mechanism ensures that no exception is silent: it appears in git history, in the waiver record, and in every assessment report that covers the waived control.
