# ADR-0003: No infrastructure implementation repository may be created before platform-compliance reaches v1.0.0

| Field | Value |
|---|---|
| **ID** | ADR-0003 |
| **Status** | accepted |
| **Date** | 2026-07-08 |
| **Deciders** | platform-team |

---

## Context

ADR-0001 establishes that compliance precedes implementation at the philosophical level. This ADR establishes the same constraint as a concrete, enforceable gate: no second repository in the platform may exist until the first one (`platform-compliance`) has produced a passing v1.0.0 release.

The pressure to create other repositories early is real and comes from legitimate motivations:

- The desire to test compliance tooling against a real repository while building it
- Wanting to stand up a basic infrastructure to support the development of `platform-compliance` itself
- The perception that "it's just a small test repo; it doesn't need to be fully compliant"

Each of these motivations leads to the same outcome: an ungovernance repository exists in the platform. Once an ungoverned repository exists, the principle that "every repository is born compliant" is false, and the compliance model must now accommodate a pre-compliance era.

---

## Decision

**No repository other than `platform-compliance` may be created in the platform organisation until `platform-compliance` has:**

1. Passed its own release gate (`PROF-PLATFORM-V1` release gate with `overall_result: pass` or `overall_result: pass-with-waivers`)
2. Published a `v1.0.0` release record
3. Made its reusable workflows callable at the `@v1.0.0` tag
4. Published its consuming documentation (`docs/consuming-compliance.md`)

This constraint applies regardless of the intended purpose of the new repository — infrastructure, tooling, testing, documentation, or any other use.

**Corollary:** No Docker services, Terraform modules, monitoring configuration, or server deployments may be created before this gate is passed, because all such work would require a repository.

---

## Consequences

**Positive:**

- The compliance-first principle (ADR-0001) is operationalised as a concrete, verifiable gate rather than a cultural aspiration.
- The first downstream repository inherits a complete, tested compliance system — not one that is "mostly done."
- Operators developing `platform-compliance` experience the full onboarding flow that downstream repository owners will experience, revealing gaps and usability issues before external consumers encounter them.

**Negative / trade-offs:**

- Development work on `platform-compliance` itself cannot be tested against an external "real" repository. All testing must occur within `platform-compliance` itself.
- If the compliance system has a blocking issue that is only discoverable when applied to a second repository, that discovery is delayed until after v1.0.0.

**Mitigations for the negatives:**

- `platform-compliance`'s self-compliance (it governs itself with `PROF-PLATFORM-V1`) provides a meaningful test bed for the compliance system.
- The bootstrapping sequence in `docs/implementation-roadmap.md` Phase 12 includes a "next-repo readiness" gate specifically designed to verify that the system is ready for a second repository.

**Constraints introduced:**

- Any repository created in the platform organisation before the v1.0.0 gate passes violates this ADR. If this occurs, the repository must either be deleted or immediately retrospectively governed (which requires a waiver and an incident record).
- `platform-compliance` development may create temporary branches and pull requests freely. This ADR constrains the creation of *additional repositories*, not branches within this repository.

---

## What counts as "infrastructure implementation"

For the avoidance of doubt, the following are all prohibited until the v1.0.0 gate passes:

- Any Terraform module repository
- Any Terraform root configuration repository
- Any repository containing Docker Compose or Dockerfile definitions intended for deployment
- Any repository containing server configuration
- Any repository containing service code
- Any "test" or "scratch" infrastructure repository

The only exception: a repository used exclusively for local development tooling (e.g., a repository of development scripts or documentation) is permitted if it declares a compliance manifest and passes the merge gate. In practice, this means branch protection must be enabled from the first commit.

---

## Relation to platform principles

This ADR operationalises Platform Principles P1 (compliance precedes implementation) and P10 (no service or infrastructure code until the compliance backbone is in place). See [../platform-principles.md](../platform-principles.md).

The v1.0.0 readiness conditions are fully specified in `docs/implementation-roadmap.md` Phase 12, task PC-0085.
