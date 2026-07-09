# Implementation — Navigation Index

This directory is the authoritative source for all implementation planning, task tracking, and pending architecture decisions for the `platform-compliance` repository and the broader platform.

The original flat roadmap (`docs/implementation-roadmap.md`) has been superseded by this structure. That file now redirects here.

---

## How to navigate

| You want to… | Go to |
|---|---|
| Understand where things stand right now | [`current-state.md`](current-state.md) |
| See the full phase map and critical path | [`roadmap.md`](roadmap.md) |
| Read the spec for a specific phase | [`phases/`](phases/) |
| See all tasks with current status | [`tasks/`](tasks/) |
| Review decisions that are blocking work | [`decisions-needed/`](decisions-needed/) |

---

## Phase summary

### Horizon 1 — Foundation (v1.0.0)
*Build the compliance backbone. No implementation code until this gate passes.*

| # | Phase | Status |
|---|---|---|
| 01 | Repository skeleton and architecture docs | **Complete** |
| 02 | Standards registry and taxonomy | **Complete** |
| 03 | Control catalog and compliance profile | **Complete** |
| 04 | Schemas for all governance objects | **Complete** |
| 05 | Mapping and provenance model | **Complete** |
| 06 | Implementation binding model | **Complete** |
| 07 | Policy-as-code structure and initial tests | **Partial** (14/~25 policies) |
| 08 | Evidence model and evidence record schema | **Complete** |
| 09 | Assessment, finding, waiver, and exception model | **Complete** |
| 10 | Reusable GitHub workflow design | **Partial** (skeleton — TODOs remain) |
| 11 | Repository compliance manifest design | **Complete** |
| 12 | Final review and v1.0.0 release gate | **Not started** (blocked by Phase 10) |

### Horizon 2 — Operationalization (v1.1)
*Make the system run against real repositories.*

| # | Phase | Status |
|---|---|---|
| A | Operationalization — complete the running workflow | **Not started** |
| B | Tooling and developer experience (`plt` CLI) | **Not started** |

### Horizon 3 — Platform growth (v2.0+)
*Govern the rest of the platform.*

| # | Phase | Status |
|---|---|---|
| C | Multi-repo platform — second and subsequent repositories | **Not started** |
| D | Advanced maturity — dashboard, SLSA L2, SLOs, GitOps | **Not started** |

---

## Blocking decisions

These ADR proposals must be ratified before specific phases can proceed. See [`decisions-needed/`](decisions-needed/) for the full proposal documents.

| ADR | Decision | Blocks | Status |
|---|---|---|---|
| ADR-0006 | Evidence storage strategy | Phase A | ✅ Accepted — Option B (distributed) |
| ADR-0007 | Waiver approval governance | Phase A | ✅ Accepted — PR review as approval event |
| ADR-0008 | Secret management backend | Phase C | ⬜ Pending |
| ADR-0009 | OPA policy bundle distribution | Phase A/B | ⬜ Pending |
| ADR-0010 | Platform versioning and release cadence | Phase A/B | ⬜ Pending |
| ADR-0011 | `plt` CLI technology selection | Phase B | ⬜ Pending |
| ADR-0012 | Multi-environment gate differentiation | Phase C | ⬜ Pending |
| ADR-0013 | Compliance dashboard architecture | Phase D | ⬜ Pending |
| ADR-0014 | Terraform state backend | Phase C | ⬜ Pending |
| ADR-0015 | Self-hosted Git mirror strategy | Phase D | ⬜ Pending |
