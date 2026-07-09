# ADR-0001: Platform compliance is built before any infrastructure implementation

| Field | Value |
|---|---|
| **ID** | ADR-0001 |
| **Status** | accepted |
| **Date** | 2026-07-08 |
| **Deciders** | platform-team |

---

## Context

We are building a self-hosted infrastructure platform intended to manage tools and servers in a reproducible, auditable, and standards-driven way. There is natural pressure to begin with the visible, operational components — deploying services, configuring a server, standing up monitoring.

Historically, infrastructure platforms built without a compliance backbone accumulate three compounding problems: inconsistency between components (each built to different implicit standards), ungoverned drift (configuration that was correct at creation degrades silently), and prohibitive retrofitting cost (applying governance to existing infrastructure is significantly harder than building governed infrastructure from the start).

The question is: **should the platform be built by starting with operational components and adding governance later, or by establishing the governance model first?**

We have considered two approaches:

**Option A — Infrastructure-first.** Start by deploying something useful (a server, a container runtime, a Git service). Add compliance controls incrementally as the platform matures. This is faster to visible results but risks establishing patterns that contradict the eventual compliance model.

**Option B — Compliance-first.** Build the `platform-compliance` repository to completion before creating any other repository. All subsequent repositories are born into an established, governed system. This delays the first operational component but ensures that every component is compliant by construction.

---

## Decision

**We adopt Option B: compliance comes before implementation.**

The `platform-compliance` repository is the first repository created. No other repository, Terraform module, Docker service, or infrastructure component may be created until `platform-compliance` has reached its v1.0.0 release gate.

This decision applies permanently. Even after v1.0.0 is released, every new repository must declare a compliance manifest before its first merge, and no deployment can occur without passing the deployment gate.

---

## Consequences

**Positive:**

- Every component created after this decision is born compliant. There is no retrofitting cost.
- The compliance system is tested against real repositories from the start, rather than being designed in the abstract.
- The platform's compliance posture is auditable from day one; there is no pre-governance period to explain away.
- Standards provenance for all controls is established before any control is enforced, making the compliance model defensible.

**Negative / trade-offs:**

- The first operational component of the platform is delayed by the time needed to build `platform-compliance`. This is an explicit and accepted trade-off.
- The compliance model must accommodate future components whose requirements are not yet fully known. This is addressed by the lifecycle status (`deferred`) mechanism in the control catalog.

**Constraints introduced:**

- This decision cannot be reversed without a superseding ADR that explains what has changed and how the accumulated technical debt will be managed.
- Any team member observing that "we should just spin something up first" is applying Option A thinking. This ADR is the documented response to that argument.
- The compliance-first constraint applies to all platform repositories, including this one. `platform-compliance` must pass its own release gate before governing others.

---

## Relation to platform principles

This ADR ratifies Platform Principles P1 (compliance precedes implementation) and P10 (no service or infrastructure code until the compliance backbone is in place). See [../platform-principles.md](../platform-principles.md).
