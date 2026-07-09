# platform-compliance

This repository is the compliance backbone of the platform. It does not contain infrastructure code, service deployments, or Terraform modules. It defines the rules, controls, evidence requirements, and gate criteria that govern every other repository in the platform.

No other platform repository may be created until this one has reached its v1.0.0 release gate.

## Purpose

`platform-compliance` establishes and maintains the authoritative chain from registered external standards to deployed infrastructure. Every repository, service, module, host, and deployment in the platform must trace its compliance controls back to this repository.

The platform complies with its own [Platform Compliance Profile v1](04-profiles/PROF-PLATFORM-V1.yaml). That profile's controls are mapped to registered external standards with documented provenance. The platform does not claim formal certification against any standard; it declares its controls, traces them to standards sources, and makes the evidence of compliance available for inspection.

## Read this first

| Document | Purpose |
|---|---|
| [platform-principles.md](platform-principles.md) | The ten constraints that govern all platform decisions |
| [docs/platform-compliance-architecture.md](docs/platform-compliance-architecture.md) | Full architecture: what the system is and how it works |
| [docs/operating-model.md](docs/operating-model.md) | How controls, profiles, evidence, and assessments work in practice |
| [docs/traceability-model.md](docs/traceability-model.md) | How any check traces back to an external standard |
| [docs/implementation-roadmap.md](docs/implementation-roadmap.md) | 86-task roadmap to v1.0.0 |

## Repository structure

| Directory | Purpose |
|-----------|---------|
| `01-sources/` | Standards source registry — registered external standards with version, URL, and role |
| `02-taxonomy/` | Platform taxonomy — controlled vocabularies used by all object types |
| `03-catalogs/` | Platform control catalog — what must be satisfied, by domain |
| `04-profiles/` | Compliance profiles — named control sets declared by each repository |
| `05-mappings/` | Standards-to-control mappings — explicit provenance chain |
| `06-bindings/` | Implementation bindings — how each control is satisfied per technology context |
| `07-policies/` | Policy-as-code — machine-verifiable rule implementations |
| `08-evidence/` | Evidence schema, ledger format, and collected evidence records |
| `09-assessments/` | Assessment reports, gate criteria, and waiver records |
| `schemas/` | Canonical JSON Schema definitions for all object types |
| `templates/` | Authoring templates for every object type |
| `workflows/` | Reusable GitHub Actions workflows for compliance, evidence, and gates |
| `tools/` | Platform CLI (`plt`) and helper scripts |
| `docs/` | Architecture notes, design documents, authoring guides |
| `decisions/` | Architecture Decision Records |

## Status

**Architecture and initial implementation phase.** The control catalog, source registry, taxonomy, and base schemas are in place. Mappings, bindings, policies, evidence infrastructure, and workflows are being built. See [docs/implementation-roadmap.md](docs/implementation-roadmap.md) for the current task status.

## What is intentionally not here

The following will never be in this repository:

- Terraform modules or root configurations
- Docker service definitions or Compose files
- Application code of any kind
- Infrastructure state files
- Secrets or credentials
- Grafana dashboards, alerting rules, or monitoring configuration
- Ansible playbooks

These belong in downstream repositories that are governed by the profiles defined here.
