# ADR Template

Copy this file to `decisions/ADR-NNNN-short-title.md` and fill in each section.

The format follows the Nygard ADR pattern (source: `SRC-NYGARD-ADR-2011`), with platform-specific additions for `Date` and `Deciders`.

---

# ADR-NNNN: [Imperative title: "We will do X" or "X is Y"]

| Field | Value |
|---|---|
| **ID** | ADR-NNNN |
| **Status** | proposed |
| **Date** | YYYY-MM-DD |
| **Deciders** | [list of individuals or roles who ratified this decision] |
| **Supersedes** | [ADR-NNNN if this replaces a previous ADR; omit if not applicable] |
| **Superseded by** | [ADR-NNNN if this ADR has been replaced; omit if not applicable] |

---

## Context

[Describe the situation, forces, and constraints that made this decision necessary. What is the problem being solved? What options were considered? What constraints (technical, organizational, temporal) apply?

Be honest about trade-offs. An ADR that acknowledges only benefits is suspect.

Write in past or present tense. This section describes the world as it was when the decision was made, not a prescription for the future.]

---

## Decision

[State the decision clearly and unambiguously. Use active voice: "We will do X" or "X is defined as Y."

Do not hedge. If the decision has not been made, set Status to "proposed" and come back to ratify it when consensus is reached.

One decision per ADR. If multiple decisions are being made simultaneously, split them into separate ADRs unless they are so tightly coupled that separating them would be misleading.]

---

## Consequences

[List the consequences of this decision — both positive and negative. Include:

- What becomes easier because of this decision
- What becomes harder or more expensive
- What constraints this decision introduces on future decisions
- What debt is accepted and why
- Any monitoring or review triggers (e.g., "revisit if X happens")

Be specific. "This makes things more secure" is not a consequence; "This prevents direct pushes to main, which means all changes require a pull request and at least one approval" is.]

---

## Relation to platform principles

[Optional. If this decision ratifies or constrains one of the platform principles in `platform-principles.md`, cite it here. Example: "This ADR ratifies Platform Principle P1 (compliance precedes implementation)."]

---

*After filling in this template:*
- *Set Status to `proposed` and open a pull request for review*
- *Change Status to `accepted` when the PR is merged*
- *Reference this ADR in the control, binding, or implementation it documents*
- *If this ADR is a change record (per CHG-001), include a change record ID in the PR description*
