# Onboarding Guide

**Repository:** `platform-compliance`  
**Audience:** New contributors and consumers of the platform  
**Date:** 2026-07-09

Welcome. This guide explains what this repository is, what it is not, how to navigate it, and what you need to do depending on your role.

---

## What this repository is

`platform-compliance` is the compliance backbone of the platform. It does not contain infrastructure code or deployable services. It defines and enforces the rules that govern all other platform repositories.

Before reading further, read these two documents in order:

1. [`platform-principles.md`](../platform-principles.md) — the ten constraints governing all platform decisions
2. [`docs/platform-compliance-architecture.md`](platform-compliance-architecture.md) — the full architecture

---

## Role-based starting points

### I want to create a new platform repository

Everything you need is in [`docs/consuming-compliance.md`](consuming-compliance.md).

The short version:
1. Create `.compliance-manifest.yaml` using `templates/compliance-manifest.template.yaml`
2. Add the compliance CI workflow to `.github/workflows/`
3. Configure branch protection
4. Pass the merge gate

### I want to add a new control

Read [`docs/authoring-controls.md`](authoring-controls.md) for the full guide.

The short version:
1. Register or confirm the standard source in `01-sources/registry/`
2. Create the mapping record in `05-mappings/mappings/`
3. Write the control YAML in `03-catalogs/controls/{DOMAIN}/` using `templates/control.template.yaml`
4. Submit a PR with a change record (`templates/change-record.template.yaml`)

### I want to request a waiver

Read [`09-assessments/waiver-model.md`](../09-assessments/waiver-model.md).

Use `templates/waiver.template.yaml`. Open a PR to `platform-compliance`. The PR review is the approval event.

### I want to understand why a compliance check failed

Read [`docs/traceability-model.md`](traceability-model.md) §6: "Tracing from a CI failure back to its standard."

The short version: the failing control ID in the CI output → `03-catalogs/controls/{DOMAIN}/{ID}.yaml` → `mapped_standards` → `01-sources/registry/{SRC-ID}.yaml` → `source_url`.

### I want to understand the compliance system architecture

Read [`docs/platform-compliance-architecture.md`](platform-compliance-architecture.md).

### I want to see what's planned next

Read [`docs/implementation/README.md`](implementation/README.md) for the current state and roadmap.

---

## Repository layout quick reference

```
01-sources/     Standards source registry
02-taxonomy/    Controlled vocabularies (domain codes, enforcement levels, etc.)
03-catalogs/    Platform control catalog — what must be satisfied
04-profiles/    Compliance profiles — which controls apply to which repo type
05-mappings/    Standard-to-control mappings — provenance chain
06-bindings/    Implementation bindings — how to satisfy each control
07-policies/    OPA/Rego policy checks — machine-verifiable rules
08-evidence/    Evidence schema, ledger format, retention rules
09-assessments/ Assessment reports, gate criteria, waivers, release records
schemas/        JSON Schema definitions for all governance objects
templates/      Authoring templates for every object type
decisions/      Architecture Decision Records (ADRs)
docs/           Architecture notes, guides, glossary
```

---

## Key files for new contributors

| File | Purpose |
|---|---|
| `platform-principles.md` | The 10 non-negotiable constraints |
| `docs/platform-compliance-architecture.md` | Full system architecture |
| `docs/operating-model.md` | How the system works operationally |
| `docs/traceability-model.md` | How any check traces to a standard |
| `docs/glossary.md` | Definitions for all terms |
| `docs/consuming-compliance.md` | Onboarding for governed repos |
| `docs/authoring-controls.md` | Guide for writing new controls |
| `04-profiles/PROF-PLATFORM-V1.yaml` | The governing profile |
| `decisions/` | All ratified architecture decisions |
| `docs/implementation/` | Current state and roadmap |

---

## Prerequisites for contributors

- Basic YAML familiarity
- Understanding of JSON Schema (for schema work)
- OPA/Rego familiarity (for policy work) — see `07-policies/opa/README.md`
- Git and GitHub pull request workflow

No Terraform, Docker, or infrastructure knowledge is required to contribute to this repository. This repository is governance, not implementation.

---

## Making a change

Every change to normative content (controls, profiles, bindings, schemas, policies, gate criteria) requires:

1. A pull request
2. A change record YAML (`templates/change-record.template.yaml`) referenced in the PR description as `Change Record: CHG-YYYYMMDD-NNN`
3. An ADR (`templates/adr-template.md`) if the change is architecturally significant

See [`docs/operating-model.md`](operating-model.md) §10 for the full change record process.
