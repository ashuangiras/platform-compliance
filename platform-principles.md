# Platform Principles

These principles govern every decision made in this platform. They are not aspirations — they are constraints. When a proposed action conflicts with a principle, the principle holds unless a formal Architecture Decision Record changes it.

---

## P1 — Compliance precedes implementation

No infrastructure component, service deployment, or Terraform module may be created until the compliance framework that governs it exists. The compliance model is not retrofitted onto existing infrastructure; infrastructure is born into an existing compliance model.

*Rationale:* Infrastructure built before governance is in place accumulates ungoverned technical debt that is expensive and often impossible to fully remediate. Every component created under governance is compliant by construction.

---

## P2 — Every control has provenance

No platform control exists without a documented link to either a registered external standard or a ratified Architecture Decision Record. "Best practice" without citation is not a valid source. Provenance is machine-readable and auditable.

*Rationale:* Controls without provenance cannot be evaluated against external requirements, cannot be debated on their merits, and cannot be removed when they are no longer justified. Provenance makes the compliance model defensible and evolvable.

---

## P3 — Compliance is machine-verifiable by default

Every control that can be verified by a machine must be. Human attestation is a fallback for controls where automation is genuinely infeasible, not a convenience for controls where automation is merely inconvenient. The automation status of every control is declared and tracked.

*Rationale:* Human attestation does not scale, is inconsistent, and depends on the attention and memory of individuals. Machine verification is repeatable, timestamped, and consistent.

---

## P4 — Evidence is collected continuously, not periodically

Compliance evidence is not collected once at audit time. Policy checks run on every commit, merge, release, and deployment. Evidence is stored with timestamps and linked to specific commits. The compliance state of any repository at any point in its history is reconstructible.

*Rationale:* Periodic audits measure a single point in time and miss the drift that occurs between audits. Continuous evidence collection means compliance is the steady state, not a temporary condition achieved before an audit.

---

## P5 — Standards provenance is explicit

The platform cites specific registered standards, not vague references to "industry best practices." Each standard in the registry is version-locked, retrieved at a specific date, and assigned a defined role (normative, adopted, adapted, informative, or deferred). Control derivations cite specific clauses, not document titles.

*Rationale:* Vague references to "best practices" cannot be evaluated, updated, or traced. A standard's role determines how tightly it binds the platform and what process is required to deviate from it.

---

## P6 — Every exception is documented, time-bounded, and visible

Waivers exist. Not every control can be satisfied immediately. But every waiver must be explicitly documented with rationale, a named approver, a risk acceptance statement, and an expiry date. Waivers appear in every assessment report that covers the waived control. There are no silent exceptions.

*Rationale:* Undocumented exceptions are indistinguishable from non-compliance. A documented waiver is a conscious risk acceptance; an undocumented exception is a gap. The difference matters for audit, for operational decision-making, and for trust.

---

## P7 — The platform governs itself first

`platform-compliance` declares its own compliance profile and must pass its own release gate before governing any other repository. A compliance system that exempts itself from compliance is not a compliance system.

*Rationale:* Self-governance demonstrates that the compliance system is functional, not ceremonial. It also means that operators of the platform experience the compliance requirements they impose on others, creating a natural incentive to keep those requirements reasonable.

---

## P8 — Terraform and OpenTofu are the runtime execution model

Infrastructure desired state is expressed in Terraform or OpenTofu. Imperative scripts, configuration management tools, and ad-hoc shell automation are not the primary runtime model. Docker-provider patterns are compatible with Terraform-managed infrastructure.

*Rationale:* Declarative infrastructure-as-code is a prerequisite for reproducibility, auditability, and plan-before-apply review. This principle is a constraint on tooling choices, not a prohibition on shell scripts as supporting tooling where appropriate.

---

## P9 — GitHub is the initial root of trust for source code

All platform source code is hosted on GitHub as the canonical location. A self-hosted Git mirror may be introduced later but must not be the authoritative source. Branch protection and code review controls are implemented at the GitHub layer, not only at a downstream mirror.

*Rationale:* Self-hosted Git requires the same governance controls as the code it hosts. Establishing those controls requires the compliance framework that this platform is building. A self-hosted root of trust can be introduced after the compliance framework is in place and can itself be governed by it.

---

## P10 — No service or infrastructure code until the compliance backbone is in place

Docker services, Grafana dashboards, monitoring stacks, reverse proxies, and all other operational components are implementation. They are created after `platform-compliance` reaches its v1.0.0 release gate. This is not a sequencing preference; it is a hard constraint enforced by the roadmap.

*Rationale:* The purpose of the compliance backbone is to ensure that every subsequent component is born compliant. Creating components before the backbone defeats that purpose entirely.

---

*These principles are governed by the platform itself. Changes require an ADR with status `accepted` before taking effect.*
