# Repository Design: platform-compliance

**Document type:** Architecture design  
**Status:** Proposed — pending ADR ratification per domain  
**Date:** 2026-07-08  
**Supersedes:** Initial structure sketch in `architecture-overview.md §8`

---

## Table of Contents

1. [Design principles](#1-design-principles)
2. [Full directory structure](#2-full-directory-structure)
3. [Domain directory specifications](#3-domain-directory-specifications)
   - [01-sources/](#31-01-sources--standards-source-registry)
   - [02-taxonomy/](#32-02-taxonomy--platform-taxonomy)
   - [03-catalogs/](#33-03-catalogs--platform-control-catalog)
   - [04-profiles/](#34-04-profiles--compliance-profiles)
   - [05-mappings/](#35-05-mappings--standards-to-control-mappings)
   - [06-bindings/](#36-06-bindings--implementation-bindings)
   - [07-policies/](#37-07-policies--policy-as-code)
   - [08-evidence/](#38-08-evidence--evidence-system)
   - [09-assessments/](#39-09-assessments--assessment-system)
   - [schemas/](#310-schemas--canonical-object-schemas)
   - [templates/](#311-templates--authoring-templates)
   - [workflows/](#312-workflows--reusable-cicd-workflows)
   - [tools/](#313-tools--platform-cli-and-tooling)
   - [docs/](#314-docs--documentation)
   - [decisions/](#315-decisions--architecture-decision-records)
4. [Key object type definitions](#4-key-object-type-definitions)
5. [Cross-domain dependency graph](#5-cross-domain-dependency-graph)
6. [Structural coherence rationale](#6-structural-coherence-rationale)
7. [What does not belong in this repository](#7-what-does-not-belong-in-this-repository)
8. [Bootstrapping sequence](#8-bootstrapping-sequence)

---

## 1. Design principles

These principles govern every structural decision in this repository. When a placement decision is ambiguous, resolve it against these principles in order.

**P1 — Single source of truth per concern.**  
Each object type has exactly one home. There is no concept of a "canonical copy" and a "synced copy." If something is duplicated, one copy is wrong.

**P2 — Derivation is explicit.**  
When one object is derived from another (a control from a standard clause, a policy from a binding, an assessment from evidence), that derivation is recorded as a machine-readable reference, not implied by file proximity.

**P3 — Directories are contracts, not folders.**  
Every directory in the numbered sequence has a defined schema for the files it contains. A file placed in the wrong directory or in the wrong format is a compliance violation within this repository itself.

**P4 — Forward references are forbidden.**  
A lower-numbered domain may not reference objects from a higher-numbered domain. `01-sources` does not know about controls. `03-catalogs` does not know about bindings. Dependencies flow downward only. This makes the dependency graph acyclic and auditable.

**P5 — Implementation is downstream of specification.**  
Schemas and templates precede instances. Bindings precede policies. Profiles precede compliance manifests. Nothing is built before its specification exists.

**P6 — The repository governs itself.**  
`platform-compliance` must declare its own compliance profile. Changes to controls, profiles, and policies are themselves subject to the change record and ADR process defined here.

---

## 2. Full directory structure

```
platform-compliance/
│
├── 01-sources/
│   ├── README.md
│   └── registry/
│       ├── SRC-CIS-DOCKER.yaml
│       ├── SRC-NIST-SP800-53.yaml
│       └── ...
│
├── 02-taxonomy/
│   ├── README.md
│   ├── resource-types.yaml
│   ├── service-types.yaml
│   ├── environment-types.yaml
│   ├── repository-types.yaml
│   ├── risk-levels.yaml
│   ├── enforcement-levels.yaml
│   ├── control-domains.yaml
│   └── technology-contexts.yaml
│
├── 03-catalogs/
│   ├── README.md
│   └── controls/
│       ├── SEC/
│       │   ├── PLT-SEC-001.yaml
│       │   ├── PLT-SEC-002.yaml
│       │   └── ...
│       ├── OPS/
│       │   └── PLT-OPS-001.yaml
│       ├── CHG/
│       │   └── PLT-CHG-001.yaml
│       ├── NET/
│       ├── DAT/
│       ├── AUD/
│       └── REL/
│
├── 04-profiles/
│   ├── README.md
│   └── profiles/
│       ├── PROF-BASE.yaml
│       ├── PROF-TERRAFORM-MODULE.yaml
│       ├── PROF-SERVICE.yaml
│       ├── PROF-PLATFORM-REPO.yaml
│       └── ...
│
├── 05-mappings/
│   ├── README.md
│   └── mappings/
│       ├── MAP-SRC-CIS-DOCKER-PLT-SEC.yaml
│       ├── MAP-SRC-NIST-SP800-53-PLT-SEC.yaml
│       └── ...
│
├── 06-bindings/
│   ├── README.md
│   └── bindings/
│       ├── github/
│       │   ├── BIND-PLT-SEC-001-GITHUB.yaml
│       │   └── ...
│       ├── terraform/
│       │   └── ...
│       ├── docker/
│       │   └── ...
│       └── runtime/
│           └── ...
│
├── 07-policies/
│   ├── README.md
│   ├── rego/
│   │   ├── SEC/
│   │   │   └── PLT-SEC-001.rego
│   │   └── ...
│   ├── conftest/
│   │   └── ...
│   ├── terraform/
│   │   └── ...
│   └── scripts/
│       └── ...
│
├── 08-evidence/
│   ├── README.md
│   ├── schema/
│   │   └── evidence.schema.json
│   ├── ledger/
│   │   ├── README.md
│   │   └── format.md
│   └── collected/
│       └── (auto-generated; one directory per repository slug)
│
├── 09-assessments/
│   ├── README.md
│   ├── gates/
│   │   ├── release-gate.yaml
│   │   └── deployment-gate.yaml
│   ├── templates/
│   │   └── assessment-report.template.yaml
│   └── reports/
│       └── (auto-generated; one directory per subject)
│
├── schemas/
│   ├── README.md
│   ├── standard-source.schema.yaml
│   ├── control.schema.yaml
│   ├── profile.schema.yaml
│   ├── mapping.schema.yaml
│   ├── binding.schema.yaml
│   ├── policy-check.schema.yaml
│   ├── evidence.schema.json
│   ├── assessment-report.schema.yaml
│   ├── waiver.schema.yaml
│   ├── compliance-manifest.schema.yaml
│   ├── service-contract.schema.yaml
│   ├── adr.schema.yaml
│   ├── change-record.schema.yaml
│   ├── release-record.schema.yaml
│   └── incident-record.schema.yaml
│
├── templates/
│   ├── README.md
│   ├── standard-source.template.yaml
│   ├── control.template.yaml
│   ├── profile.template.yaml
│   ├── mapping.template.yaml
│   ├── binding.template.yaml
│   ├── policy-check.template.yaml
│   ├── evidence-record.template.yaml
│   ├── assessment-report.template.yaml
│   ├── waiver.template.yaml
│   ├── compliance-manifest.template.yaml
│   ├── service-contract.template.yaml
│   ├── adr.template.md
│   ├── change-record.template.yaml
│   ├── release-record.template.yaml
│   └── incident-record.template.yaml
│
├── workflows/
│   ├── README.md
│   ├── compliance-check.yaml
│   ├── evidence-collect.yaml
│   ├── assessment-generate.yaml
│   ├── release-gate.yaml
│   └── deployment-gate.yaml
│
├── tools/
│   ├── README.md
│   ├── plt/                        (platform CLI — "plt")
│   │   ├── cmd/
│   │   │   ├── validate.go
│   │   │   ├── assess.go
│   │   │   ├── evidence.go
│   │   │   └── report.go
│   │   ├── go.mod
│   │   └── go.sum
│   └── scripts/
│       ├── validate-schemas.sh
│       ├── check-profile-coverage.sh
│       └── generate-dashboard-data.sh
│
├── docs/
│   ├── architecture-overview.md
│   ├── repository-design.md         (this file)
│   ├── glossary.md
│   ├── onboarding.md
│   ├── authoring-controls.md
│   ├── authoring-profiles.md
│   ├── authoring-bindings.md
│   ├── authoring-policies.md
│   └── consuming-compliance.md
│
├── decisions/
│   ├── README.md
│   ├── ADR-0001-compliance-first-architecture.md
│   ├── ADR-0002-standards-registry-format.md
│   └── ...
│
├── .compliance-manifest.yaml        (this repo's own compliance declaration)
├── CHANGELOG.md
└── README.md
```

---

## 3. Domain directory specifications

### 3.1 `01-sources/` — Standards Source Registry

**What it owns:**  
The authoritative catalogue of external standards, frameworks, and benchmarks that the platform draws controls from. This is the root of the provenance chain. Nothing can be cited as a compliance source unless it is registered here.

**What kind of files live here:**  
One YAML file per registered standard, validated against `schemas/standard-source.schema.yaml`. Files are named with the stable source ID (`SRC-{ISSUER}-{STANDARD}-{VERSION-SLUG}.yaml`). An index file lists all registered sources.

**How it connects to the rest of the architecture:**  
- Referenced by `05-mappings/` — every mapping cites a source ID and clause from this registry
- Referenced by `03-catalogs/` controls indirectly via mappings — controls never cite sources directly; they cite mappings
- Referenced by `schemas/` — the source schema defines what a valid registration looks like
- Referenced by `docs/` — the authoring guide explains how to register a new standard

**What future repos will consume from it:**  
Future repos do not consume from `01-sources/` directly. They inherit controls that trace back to sources, but the source registry is an upstream-only concern. Assessment reports include source citations for human reviewers.

**What should not be placed here:**  
- Platform-internal decisions or rationale (those are ADRs in `decisions/`)
- Control definitions (those are in `03-catalogs/`)
- Mappings between standards and controls (those are in `05-mappings/`)
- Any file that is not a standard source registration

---

### 3.2 `02-taxonomy/` — Platform Taxonomy

**What it owns:**  
The controlled vocabularies and classification schemes used across the entire repository. Every enumerated value used in any object type must be defined here. This is the shared type system of the compliance model.

**What kind of files live here:**  
Flat YAML vocabulary files. Each file defines a named list of valid values with descriptions. Key vocabulary files:

| File | Purpose |
|------|---------|
| `resource-types.yaml` | What kinds of infrastructure resources the platform manages |
| `service-types.yaml` | Classification of services (stateless-api, stateful-db, gateway, etc.) |
| `environment-types.yaml` | Environment tiers (local, ci, staging, production) |
| `repository-types.yaml` | Repository classifications (terraform-module, service, platform-repo, library) |
| `risk-levels.yaml` | Risk severity scale used in controls and waivers |
| `enforcement-levels.yaml` | Mandatory, recommended, informational — with definitions |
| `control-domains.yaml` | SEC, OPS, CHG, NET, DAT, AUD, REL — with descriptions |
| `technology-contexts.yaml` | Technology context identifiers used in bindings (github, terraform, docker, runtime-linux) |

**How it connects to the rest of the architecture:**  
`02-taxonomy/` is a dependency of almost every other domain. Controls reference `control-domains` and `enforcement-levels`. Profiles reference `repository-types`. Bindings reference `technology-contexts`. Evidence records reference `environment-types`. Because all enumerations are centralised here, schema validators can enforce referential integrity across the entire system.

**What future repos will consume from it:**  
Future repos reference taxonomy values when writing their compliance manifest (e.g., declaring their `repository-type`). The taxonomy is stable — changes require an ADR.

**What should not be placed here:**  
- Any object instances (actual controls, profiles, bindings)
- Free-form documentation
- Standards source entries
- Anything that is not a controlled vocabulary definition

---

### 3.3 `03-catalogs/` — Platform Control Catalog

**What it owns:**  
The authoritative set of platform controls. A control describes **what must be satisfied** — not how. Controls are the unit of compliance. Everything downstream (profiles, bindings, policies, evidence) is organised around control IDs.

**What kind of files live here:**  
One YAML file per control, nested under domain subdirectories (`SEC/`, `OPS/`, `CHG/`, `NET/`, `DAT/`, `AUD/`, `REL/`). Each file is validated against `schemas/control.schema.yaml`. Control IDs follow the scheme `PLT-{DOMAIN}-{NNN}`.

The domain subdirectory names are drawn from `02-taxonomy/control-domains.yaml`.

**How it connects to the rest of the architecture:**  
- Controls cite mapping IDs from `05-mappings/` for provenance
- Controls are referenced by profiles in `04-profiles/`
- Controls are referenced by bindings in `06-bindings/`
- Controls are referenced by evidence records in `08-evidence/`
- Controls are referenced by assessment reports in `09-assessments/`
- Controls are referenced by waivers in `09-assessments/`

**What future repos will consume from it:**  
Future repos do not author controls. They reference control IDs in evidence records and receive control-level feedback in assessment reports. The platform CLI reads the catalog to resolve which controls a declared profile requires.

**What should not be placed here:**  
- Implementation guidance (that is a binding in `06-bindings/`)
- Policy code (that is in `07-policies/`)
- Mapping details (that is in `05-mappings/`)
- Any control that does not have at least one source mapping before it is activated
- Profile definitions

---

### 3.4 `04-profiles/` — Compliance Profiles

**What it owns:**  
Named sets of controls that apply to a class of repository, service, or environment. A profile is the primary interface between `platform-compliance` and every downstream repository. By declaring a profile, a repository accepts all controls included in that profile.

**What kind of files live here:**  
One YAML file per named profile, validated against `schemas/profile.schema.yaml`. Profile IDs follow the scheme `PROF-{CONTEXT}-{VARIANT}`.

Profiles may inherit from a parent profile using `inherits`. The base profile `PROF-BASE` defines the minimum controls that apply to all platform repositories with no exceptions.

**How it connects to the rest of the architecture:**  
- Profiles include controls from `03-catalogs/` by control ID
- Profiles reference taxonomy values from `02-taxonomy/` for their `applicable_to` field
- Profiles are declared in repository compliance manifests (`.compliance-manifest.yaml`)
- Profiles are consumed by the platform CLI and CI/CD workflows to determine what must be checked
- Profiles are referenced in assessment reports as the governing profile

**What future repos will consume from it:**  
Every repository in the platform declares one or more profiles from this directory in its `.compliance-manifest.yaml`. The declared profiles determine which policies run in the repository's CI/CD pipeline.

**What should not be placed here:**  
- Controls themselves (those are in `03-catalogs/`)
- Bindings (those are in `06-bindings/`)
- Compliance manifests for specific repositories (those live in each repository)
- Environment-specific configuration

---

### 3.5 `05-mappings/` — Standards-to-Control Mappings

**What it owns:**  
The explicit, documented linkage between registered standard clauses and platform controls. This is the provenance layer. Without a mapping, a control cannot claim derivation from an external standard.

**What kind of files live here:**  
YAML files grouping related mappings (e.g., all mappings from a single source to a single control domain), validated against `schemas/mapping.schema.yaml`. Mapping IDs follow the scheme `MAP-{SOURCE_ID}-{DOMAIN}-{NNN}`.

Each mapping record contains:
- The source ID (from `01-sources/`)
- The specific clause, section, or requirement identifier within that standard
- The platform control ID (from `03-catalogs/`)
- The mapping rationale: how and why the clause was interpreted to produce this control in this platform's context

**How it connects to the rest of the architecture:**  
- References source entries in `01-sources/`
- References controls in `03-catalogs/`
- Cited by controls as their provenance chain
- Used by assessment reports to generate source citations
- Used by audit tooling to prove standards coverage

**What future repos will consume from it:**  
Future repos do not consume mappings directly. Auditors and compliance reviewers use mappings to verify that platform controls are grounded in cited standards. The platform CLI uses mappings to generate coverage reports.

**What should not be placed here:**  
- Source registrations (those are in `01-sources/`)
- Control definitions (those are in `03-catalogs/`)
- Implementation guidance
- Anything that is not a standard clause to control mapping record

---

### 3.6 `06-bindings/` — Implementation Bindings

**What it owns:**  
Prose specifications of how a control is satisfied in a specific technology context. A binding bridges the abstract "what" of a control and the concrete "how" of a policy check. It is a specification document, not executable code.

**What kind of files live here:**  
YAML files nested under technology context subdirectories (`github/`, `terraform/`, `docker/`, `runtime/`). File naming follows `BIND-{CONTROL_ID}-{CONTEXT}.yaml`, validated against `schemas/binding.schema.yaml`.

A binding specifies:
- The control it implements
- The technology context it applies to (from `02-taxonomy/technology-contexts.yaml`)
- A prose description of the observable artifact or condition that satisfies the control
- References to the policy checks in `07-policies/` that verify it

**How it connects to the rest of the architecture:**  
- References controls from `03-catalogs/`
- References technology contexts from `02-taxonomy/`
- Drives the creation of policy checks in `07-policies/`
- Consumed by the platform CLI to generate per-repository compliance checklists
- Consumed by documentation generation tools

**What future repos will consume from it:**  
Bindings tell repository owners what they must produce to satisfy a control in their context. The binding for `PLT-SEC-001` in the `github` context describes exactly what file, configuration, or workflow state must be present. Future repos use bindings as their authoritative implementation checklist.

**What should not be placed here:**  
- Policy code (that is in `07-policies/`)
- Control definitions (those are in `03-catalogs/`)
- Any file that executes or asserts rather than specifies
- Bindings for technology contexts not registered in `02-taxonomy/`

---

### 3.7 `07-policies/` — Policy-as-Code

**What it owns:**  
Machine-verifiable rule implementations. Each policy check is the executable counterpart of one or more implementation bindings. Policies run in CI/CD pipelines and against live infrastructure and produce pass/fail results that become evidence records.

**What kind of files live here:**  
Policy files organised by engine subdirectory (`rego/`, `conftest/`, `terraform/`, `scripts/`), then by domain. Each policy file is accompanied by a companion metadata file (or an inline header block) that registers it as a `policy-check` object referencing its binding. The metadata is validated against `schemas/policy-check.schema.yaml`.

The engine choice is an open question (see `decisions/`). Until resolved, the directory structure accommodates multiple engines. Each engine subdirectory has its own `README.md` explaining execution requirements.

**How it connects to the rest of the architecture:**  
- References bindings from `06-bindings/`
- Produces evidence records conforming to `schemas/evidence.schema.json`
- Executed by reusable workflows in `workflows/`
- Results feed the evidence ledger in `08-evidence/`
- Referenced by the platform CLI and CI/CD tooling

**What future repos will consume from it:**  
Future repos do not copy policy files. They reference the reusable workflow in `workflows/` which internally calls the appropriate policies. Policy updates in `platform-compliance` propagate automatically to all consuming repos on their next CI run (version-pinned via the reusable workflow reference).

**What should not be placed here:**  
- Binding specifications (those are in `06-bindings/`)
- Infrastructure code (Terraform modules, Docker configs)
- Application-specific business rules
- Test fixtures or mock data for application code
- Any policy that lacks a companion binding reference

---

### 3.8 `08-evidence/` — Evidence System

**What it owns:**  
The schema and format specification for all compliance evidence, the evidence ledger structure, and (optionally) collected evidence artifacts submitted by repositories. The evidence system is the factual record of what was checked, when, against what, and what the result was.

**What kind of files live here:**  

| Subdirectory | Contents |
|---|---|
| `schema/` | The canonical `evidence.schema.json` — the definition of a valid evidence record |
| `ledger/` | The ledger format specification: how evidence is indexed, queried, and retained |
| `collected/` | Auto-generated or CI-submitted evidence records, one directory per repository slug |

The `collected/` subdirectory is the most sensitive. Its write access must be controlled: only the CI/CD system (via the reusable workflow) should be able to submit new evidence. Human-submitted evidence requires explicit documentation of the collection method.

**How it connects to the rest of the architecture:**  
- Evidence records reference control IDs from `03-catalogs/`
- Evidence records reference policy check IDs from `07-policies/`
- Evidence records are the input to assessment reports in `09-assessments/`
- Evidence records reference waivers in `09-assessments/` when result is waived
- The ledger is queried by the platform CLI and dashboard tools

**What future repos will consume from it:**  
Future repos write evidence records in the format defined by `schemas/evidence.schema.json`. They may submit them to the `collected/` directory here, or maintain their own evidence ledger that conforms to the schema. Either model is valid; the schema is non-negotiable.

**What should not be placed here:**  
- Policy code (that is in `07-policies/`)
- Assessment reports (those are in `09-assessments/`)
- Waivers (those are in `09-assessments/`)
- Infrastructure state or configuration files
- Application logs that are not compliance-specific

---

### 3.9 `09-assessments/` — Assessment System

**What it owns:**  
The gate criteria that determine pass/fail for releases and deployments, the templates for structured assessment reports, generated assessment reports, and waiver/exception records.

**What kind of files live here:**  

| Subdirectory | Contents |
|---|---|
| `gates/` | Gate definitions: `release-gate.yaml` and `deployment-gate.yaml`, each specifying the evidence criteria required to pass |
| `templates/` | The canonical `assessment-report.template.yaml` |
| `reports/` | Generated assessment reports, one directory per subject (repo, environment, release) |

Waiver records live in `09-assessments/waivers/` alongside the assessment reports they affect. A waiver is not stored with the control it waives — it is stored with the assessment system because a waiver is an assessment-time decision, not a catalog-time one.

**How it connects to the rest of the architecture:**  
- Gate criteria reference control IDs and enforcement levels from `03-catalogs/`
- Assessment reports reference evidence records from `08-evidence/`
- Assessment reports reference the governing profile from `04-profiles/`
- Waivers reference control IDs, resource identifiers, and expiry dates
- Assessment reports are the input to the compliance dashboard
- Gate pass/fail is the output consumed by CI/CD release and deployment pipelines

**What future repos will consume from it:**  
- Release and deployment pipelines reference the gate definitions to determine their pass criteria
- Repositories receive assessment reports as CI artifacts
- Waivers granted in this directory are referenced in repository compliance manifests

**What should not be placed here:**  
- Evidence records (those are in `08-evidence/`)
- Policy code (that is in `07-policies/`)
- Controls (those are in `03-catalogs/`)
- Profiles (those are in `04-profiles/`)
- Any assessment for a subject that has not declared a compliance profile

---

### 3.10 `schemas/` — Canonical Object Schemas

**What it owns:**  
The machine-readable schema definitions for every structured object type in the platform. Schemas are the contracts that enforce structural integrity across the entire system. Every YAML or JSON file in any domain directory is validated against the appropriate schema.

**What kind of files live here:**  
JSON Schema files (in YAML format for readability). One schema per object type. Schema IDs follow the convention `https://platform-compliance/schemas/{object-type}.schema.yaml` with a `$id` field for referencing. Schema files are versioned with a `schemaVersion` property.

**How it connects to the rest of the architecture:**  
`schemas/` is a pure dependency of every other domain. It has no upstream dependencies within the repository itself. All CI validation runs schema checks before any other check. The platform CLI uses schemas for local validation.

**What future repos will consume from it:**  
- The `compliance-manifest.schema.yaml` is used by every downstream repository to validate its own compliance manifest
- The `evidence.schema.json` is used by CI/CD pipelines when writing evidence
- The `waiver.schema.yaml` is used when requesting a formal waiver

**What should not be placed here:**  
- Template instances
- Object instances
- Documentation
- Policy code
- Any schema that is not platform-wide (repo-specific schemas belong in the repo)

---

### 3.11 `templates/` — Authoring Templates

**What it owns:**  
Human-facing starter templates for every object type. Templates are the minimal valid skeleton of each object type, with comments explaining each field. They make authoring new objects fast and correct.

**What kind of files live here:**  
One template file per object type, named `{object-type}.template.yaml` (or `.md` for ADRs). Templates are valid instances of their schema — a template rendered without modification should pass schema validation.

**How it connects to the rest of the architecture:**  
Templates reference schemas in their header comments. The platform CLI uses templates when generating new objects (`plt new control`, `plt new adr`, etc.). Templates are human-readable companions to schemas.

**What future repos will consume from it:**  
- The `compliance-manifest.template.yaml` is the starting point for every new repository's compliance manifest
- The `waiver.template.yaml` is the starting point for any waiver request
- The `service-contract.template.yaml` is the starting point for service contract declarations

**What should not be placed here:**  
- Schema definitions
- Actual object instances
- Policy code
- Documentation prose

---

### 3.12 `workflows/` — Reusable CI/CD Workflows

**What it owns:**  
Reusable GitHub Actions workflow definitions that implement the compliance check, evidence collection, assessment generation, and gate evaluation pipeline. These are the CI/CD entry points that downstream repositories reference.

**What kind of files live here:**  
GitHub Actions reusable workflow YAML files (callable workflows using `workflow_call`). One workflow per logical phase:

| Workflow | Purpose |
|---|---|
| `compliance-check.yaml` | Validates the repository's compliance manifest and profile coverage |
| `evidence-collect.yaml` | Runs applicable policy checks and records evidence |
| `assessment-generate.yaml` | Generates an assessment report from collected evidence |
| `release-gate.yaml` | Evaluates assessment report against release gate criteria |
| `deployment-gate.yaml` | Evaluates assessment report against deployment gate criteria |

**How it connects to the rest of the architecture:**  
- Workflows invoke policy files from `07-policies/`
- Workflows write evidence records conforming to `08-evidence/schema/`
- Workflows invoke the assessment template from `09-assessments/templates/`
- Workflows evaluate gate criteria from `09-assessments/gates/`
- Workflows use the platform CLI from `tools/`

**What future repos will consume from it:**  
Every downstream repository's CI/CD pipeline includes these workflows using the GitHub Actions reusable workflow mechanism, pinned to a specific version tag. Updates to these workflows are versioned; consuming repos opt in to new versions deliberately.

**What should not be placed here:**  
- Application-specific workflow steps
- Infrastructure deployment steps
- Policy code (policies are in `07-policies/`, workflows call them)
- Anything that is not a reusable workflow or a script called directly by a workflow

---

### 3.13 `tools/` — Platform CLI and Tooling

**What it owns:**  
The `plt` command-line tool and supporting scripts that allow operators, authors, and CI/CD pipelines to interact with the compliance system programmatically. The CLI is the human interface to the system.

**What kind of files live here:**  

| Subdirectory | Contents |
|---|---|
| `plt/` | Source code for the `plt` CLI (language TBD; Go is the current candidate — see `decisions/`) |
| `scripts/` | Shell scripts for operations too simple to warrant CLI commands |

Key CLI commands (proposed):

| Command | Purpose |
|---|---|
| `plt validate <file>` | Validate a file against its schema |
| `plt validate-repo <path>` | Validate a repository's compliance manifest and check profile coverage |
| `plt new control` | Scaffold a new control from template |
| `plt new adr` | Scaffold a new ADR from template |
| `plt new profile` | Scaffold a new profile from template |
| `plt assess <repo>` | Generate an assessment report for a repository |
| `plt evidence submit <file>` | Submit an evidence record to the ledger |
| `plt gate check release <repo>` | Evaluate release gate for a repository |
| `plt gate check deploy <repo>` | Evaluate deployment gate |
| `plt report coverage` | Report standards coverage across the control catalog |

**How it connects to the rest of the architecture:**  
The CLI reads schemas from `schemas/`, uses templates from `templates/`, reads controls from `03-catalogs/`, reads profiles from `04-profiles/`, reads gates from `09-assessments/gates/`, and writes evidence to `08-evidence/collected/`. It is a consumer of the entire system.

**What future repos will consume from it:**  
Future repos install the `plt` CLI (via a documented install method) for local development compliance checks. CI/CD workflows invoke `plt` for validation, assessment, and gate evaluation.

**What should not be placed here:**  
- Policy files (those are in `07-policies/`)
- Workflow definitions (those are in `workflows/`)
- Infrastructure code
- Application code unrelated to compliance operations

---

### 3.14 `docs/` — Documentation

**What it owns:**  
Human-readable documentation about the compliance system: architecture notes, authoring guides, onboarding material, and the glossary. Documentation explains and guides; it does not define or enforce.

**What kind of files live here:**  
Markdown files. Structured into:
- Architecture documents (this file, `architecture-overview.md`)
- Authoring guides (how to write a control, profile, binding, policy)
- Consumption guides (how a new repository declares a profile, how to read an assessment report)
- Glossary (canonical definitions of all terms)
- Onboarding (where to start if you are new to the platform)

**How it connects to the rest of the architecture:**  
Documentation references all other directories but is referenced by none. It is a terminal node in the dependency graph. Documentation is never authoritative — the schemas, controls, profiles, and policies are. If documentation contradicts a schema, the schema wins.

**What future repos will consume from it:**  
Repository owners read the onboarding and consumption guides. The `consuming-compliance.md` guide is the canonical reference for how a new repository integrates with the platform.

**What should not be placed here:**  
- ADRs (those are in `decisions/`)
- Schema definitions
- Object instances
- Executable scripts
- Policy code

---

### 3.15 `decisions/` — Architecture Decision Records

**What it owns:**  
The complete history of architecture decisions made about the platform compliance system itself. ADRs are the provenance record for platform-internal decisions, just as the standards registry is the provenance record for external standards. When a control or binding exists for a reason that is not traceable to an external standard, an ADR is its provenance.

**What kind of files live here:**  
Markdown files following the `templates/adr.template.md` format. Files are named `ADR-{NNNN}-{slug}.md`. ADRs are immutable once accepted — superseded ADRs are marked as such but not deleted. An index file lists all ADRs with their status.

**How it connects to the rest of the architecture:**  
- Controls may cite an ADR ID in place of (or in addition to) a standard mapping when the control derives from a platform decision
- Profiles cite ADRs when their control set is shaped by platform-specific reasoning
- The `decisions/` directory is the justification trail for the system's own structure

**What future repos will consume from it:**  
Future repos read ADRs to understand why constraints exist, particularly when an ADR explains a constraint that might otherwise seem arbitrary. ADRs are read-only from the perspective of downstream repositories.

**What should not be placed here:**  
- Design documents (those are in `docs/`)
- Change records (those are a separate object type managed by the change record schema)
- Meeting notes or informal discussion
- Proposed decisions that have not been ratified

---

## 4. Key object type definitions

Each object type below is described by its purpose, its required and optional fields, its schema location, and its relationships to other types. These definitions drive the schema files in `schemas/`.

---

### 4.1 Standard Source

**Purpose:** Registers an external standard as a valid source of compliance provenance. A standard must be registered before any control can derive from it.

| Field | Required | Description |
|---|---|---|
| `id` | Yes | Stable identifier: `SRC-{ISSUER}-{STANDARD}-{VERSION_SLUG}` |
| `name` | Yes | Full name of the standard |
| `version` | Yes | Version string as published by the issuing body |
| `issuing_body` | Yes | Organisation that published the standard |
| `canonical_url` | Yes | Stable URL to the published standard |
| `registered_date` | Yes | ISO 8601 date this entry was added |
| `registered_by` | Yes | Author of the registration |
| `scope_notes` | No | Platform-level notes on applicability scope |
| `status` | Yes | `active`, `deprecated`, or `superseded` |
| `superseded_by` | No | Source ID of the superseding standard |

**Schema:** `schemas/standard-source.schema.yaml`  
**Relationships:** Referenced by `mapping.control_mapping_id` in `05-mappings/`

---

### 4.2 Control

**Purpose:** Defines what must be satisfied — not how. The unit of compliance. All downstream objects (profiles, bindings, policies, evidence) are organised around control IDs.

| Field | Required | Description |
|---|---|---|
| `id` | Yes | `PLT-{DOMAIN}-{NNN}` — domain values from `02-taxonomy/control-domains.yaml` |
| `title` | Yes | Short, imperative title |
| `description` | Yes | Plain-language statement of what must be true |
| `domain` | Yes | Control domain — from `02-taxonomy/control-domains.yaml` |
| `enforcement_level` | Yes | `mandatory`, `recommended`, or `informational` — from `02-taxonomy/enforcement-levels.yaml` |
| `applicable_scopes` | Yes | One or more of: `repository`, `service`, `runtime`, `environment` |
| `source_mapping_ids` | Yes | List of mapping IDs from `05-mappings/` (at least one required for activation) |
| `adr_ids` | No | List of ADR IDs for platform-decision provenance |
| `introduced_date` | Yes | ISO 8601 date |
| `introduced_by` | Yes | Author |
| `supersedes` | No | List of control IDs this control replaces |
| `status` | Yes | `active`, `deprecated`, or `superseded` |
| `notes` | No | Clarifying notes for human readers |

**Schema:** `schemas/control.schema.yaml`  
**Relationships:** Referenced by profiles (04), bindings (06), evidence records (08), assessments (09), waivers (09), mappings (05)

---

### 4.3 Compliance Profile

**Purpose:** A named, versioned set of controls that applies to a class of repository, service, or environment. The primary contract between `platform-compliance` and downstream repositories.

| Field | Required | Description |
|---|---|---|
| `id` | Yes | `PROF-{CONTEXT}-{VARIANT}` |
| `name` | Yes | Human-readable name |
| `description` | Yes | What this profile governs and why |
| `version` | Yes | Semantic version string |
| `applicable_to` | Yes | One or more values from `02-taxonomy/repository-types.yaml` or `service-types.yaml` |
| `inherits` | No | Parent profile ID — included controls are merged and deduplicated |
| `control_inclusions` | Yes | List of objects: `{control_id, enforcement_level_override?}` |
| `control_exclusions` | No | List of objects: `{control_id, rationale}` — must justify any exclusion |
| `introduced_date` | Yes | ISO 8601 date |
| `status` | Yes | `active`, `deprecated`, or `superseded` |

**Schema:** `schemas/profile.schema.yaml`  
**Relationships:** Declared in compliance manifests; references controls from 03; drives binding selection in 06 and policy execution in 07; cited in assessment reports in 09

---

### 4.4 Mapping

**Purpose:** The explicit, documented linkage between a specific clause in a registered external standard and a platform control. Provides the provenance chain.

| Field | Required | Description |
|---|---|---|
| `id` | Yes | `MAP-{SOURCE_ID}-{DOMAIN}-{NNN}` |
| `source_id` | Yes | Standard source ID from `01-sources/` |
| `source_clause` | Yes | The specific clause, section, or requirement reference within the standard |
| `source_clause_text` | No | Brief quoted text from the standard clause for human reference |
| `control_id` | Yes | Platform control ID from `03-catalogs/` |
| `rationale` | Yes | Why this clause was interpreted as this control in this platform's context |
| `mapping_type` | Yes | `derived` (control is a direct derivation), `partial` (clause partially covered), `extended` (control goes beyond the clause) |
| `mapped_date` | Yes | ISO 8601 date |
| `mapped_by` | Yes | Author |

**Schema:** `schemas/mapping.schema.yaml`  
**Relationships:** References sources from 01; references controls from 03; cited by controls as `source_mapping_ids`

---

### 4.5 Implementation Binding

**Purpose:** A prose specification of how a control is satisfied in a specific technology context. Bridges the abstract control and the concrete policy check.

| Field | Required | Description |
|---|---|---|
| `id` | Yes | `BIND-{CONTROL_ID}-{CONTEXT}` |
| `control_id` | Yes | Platform control ID from `03-catalogs/` |
| `technology_context` | Yes | From `02-taxonomy/technology-contexts.yaml` |
| `specification` | Yes | Prose description of the observable artifact or condition that satisfies the control in this context |
| `observable_artifact` | Yes | Specific, machine-locatable artifact (file path, API field, config key) that can be checked |
| `policy_check_ids` | Yes | List of policy check IDs from `07-policies/` that verify this binding |
| `introduced_date` | Yes | ISO 8601 date |
| `status` | Yes | `active`, `deprecated` |
| `notes` | No | Clarifying notes or known edge cases |

**Schema:** `schemas/binding.schema.yaml`  
**Relationships:** References controls from 03; references technology contexts from 02; drives policy checks in 07; consumed by downstream repo owners as implementation checklist

---

### 4.6 Policy Check

**Purpose:** The machine-verifiable rule that implements one or more implementation bindings. The executable counterpart to a binding.

| Field | Required | Description |
|---|---|---|
| `id` | Yes | `POL-{CONTROL_ID}-{CONTEXT}-{NNN}` |
| `title` | Yes | Short description of what the check verifies |
| `binding_ids` | Yes | List of binding IDs this policy implements |
| `engine` | Yes | `opa`, `conftest`, `terraform-check`, `shell`, `github-action` |
| `file_path` | Yes | Relative path to the policy file within `07-policies/` |
| `pass_criteria` | Yes | Human-readable description of what constitutes a passing result |
| `fail_criteria` | Yes | Human-readable description of what constitutes a failing result |
| `evidence_type` | Yes | The `type` field value produced in evidence records |
| `severity` | Yes | From `02-taxonomy/risk-levels.yaml` — severity of a failure |
| `introduced_date` | Yes | ISO 8601 date |
| `status` | Yes | `active`, `deprecated` |

**Schema:** `schemas/policy-check.schema.yaml`  
**Relationships:** References bindings from 06; produces evidence records consumed by 08; executed by workflows in `workflows/`

---

### 4.7 Evidence Record

**Purpose:** A timestamped, structured record of a single policy check evaluation against a specific resource. The atomic unit of compliance evidence.

| Field | Required | Description |
|---|---|---|
| `id` | Yes | UUID v4 — generated at collection time |
| `schema_version` | Yes | Schema version for forward compatibility |
| `control_id` | Yes | Platform control ID from `03-catalogs/` |
| `policy_check_id` | Yes | Policy check ID from `07-policies/` |
| `resource_ref` | Yes | The resource evaluated: `{type, identifier}` — e.g., `{type: repository, identifier: github.com/org/repo}` |
| `environment_type` | No | From `02-taxonomy/environment-types.yaml` — if runtime evaluation |
| `commit_sha` | No | Git SHA at evaluation time — required for repository-scoped evidence |
| `evaluated_at` | Yes | ISO 8601 timestamp |
| `result` | Yes | `pass`, `fail`, `waived`, `not-applicable`, `error` |
| `details` | Yes | Structured object: `{checked: ..., found: ..., expected: ...}` |
| `waiver_id` | No | Required when `result` is `waived` |
| `collected_by` | Yes | `{tool, version, workflow_run_id}` — identifies what produced this record |

**Schema:** `schemas/evidence.schema.json`  
**Relationships:** References controls from 03; references policy checks from 07; references waivers from 09; consumed by assessment system in 09

---

### 4.8 Assessment Report

**Purpose:** An aggregated, structured summary of compliance state for a subject at a point in time. The output consumed by gates and the compliance dashboard.

| Field | Required | Description |
|---|---|---|
| `id` | Yes | `ASSESS-{SUBJECT_SLUG}-{YYYYMMDD}-{NNN}` |
| `schema_version` | Yes | Schema version |
| `subject` | Yes | `{type, identifier}` — `repository`, `service`, `environment`, or `release` |
| `profile_id` | Yes | The governing profile declared by the subject |
| `assessment_date` | Yes | ISO 8601 timestamp |
| `evidence_window` | Yes | `{from, to}` — the time range of included evidence |
| `evidence_refs` | Yes | List of evidence record IDs included in this assessment |
| `control_results` | Yes | List of `{control_id, result, evidence_ids, waiver_ids}` — one entry per in-scope control |
| `summary` | Yes | `{total_controls, pass, fail, waived, not_applicable, error}` |
| `overall_result` | Yes | `pass`, `fail`, `pass-with-waivers`, `inconclusive` |
| `gate_evaluation` | No | `{gate_id, result, blocking_controls}` — if tied to a gate |
| `generated_by` | Yes | `{tool, version, workflow_run_id}` |

**Schema:** `schemas/assessment-report.schema.yaml`  
**Relationships:** References profiles from 04; references controls from 03; aggregates evidence from 08; references waivers from 09; consumed by gates and dashboard

---

### 4.9 Waiver / Exception

**Purpose:** A documented, time-bounded exception granted to a specific resource for a specific control. A waiver is not a silence — it is an explicit risk acceptance that appears in all assessment reports and expires on a defined date.

| Field | Required | Description |
|---|---|---|
| `id` | Yes | `WAV-{CONTROL_ID}-{YYYYMM}-{NNN}` |
| `control_id` | Yes | The control being waived |
| `resource_ref` | Yes | The resource the waiver applies to |
| `rationale` | Yes | Why the control cannot currently be satisfied |
| `risk_acceptance_statement` | Yes | Explicit statement of the risk accepted by granting this waiver |
| `compensating_controls` | No | List of control IDs that partially mitigate the gap |
| `approved_by` | Yes | Identity of the approver |
| `approved_date` | Yes | ISO 8601 date |
| `expiry_date` | Yes | ISO 8601 date — waivers without an expiry are invalid |
| `review_date` | No | Intermediate review date before expiry |
| `status` | Yes | `active`, `expired`, `revoked` |
| `revocation_reason` | No | Required if `status` is `revoked` |

**Schema:** `schemas/waiver.schema.yaml`  
**Relationships:** Referenced by evidence records when `result` is `waived`; referenced by assessment reports; managed in `09-assessments/waivers/`

---

### 4.10 Repository Compliance Manifest

**Purpose:** The declaration each repository makes to the platform. The compliance manifest is the repository's contract with `platform-compliance`. It declares the repository's profile, technology context, and any referenced waivers.

| Field | Required | Description |
|---|---|---|
| `schema_version` | Yes | Schema version |
| `repository` | Yes | `{name, url, type}` — type from `02-taxonomy/repository-types.yaml` |
| `declared_profiles` | Yes | List of profile IDs from `04-profiles/` |
| `technology_contexts` | Yes | List of technology contexts from `02-taxonomy/technology-contexts.yaml` |
| `waiver_ids` | No | List of active waiver IDs from `09-assessments/waivers/` |
| `compliance_contact` | Yes | The team or individual responsible for this repo's compliance state |
| `last_updated` | Yes | ISO 8601 date |

**File location:** `.compliance-manifest.yaml` in the root of every platform repository  
**Schema:** `schemas/compliance-manifest.schema.yaml`  
**Relationships:** References profiles from 04; references technology contexts from 02; references waivers from 09; consumed by CI/CD compliance check workflows

---

### 4.11 Service Contract

**Purpose:** The declared interface and compliance obligations of a service. Extends the compliance manifest for service-type repositories by documenting the service's API contract, dependencies, and SLA commitments.

| Field | Required | Description |
|---|---|---|
| `id` | Yes | `SVC-{SERVICE_SLUG}` |
| `schema_version` | Yes | Schema version |
| `service_name` | Yes | Human-readable service name |
| `service_type` | Yes | From `02-taxonomy/service-types.yaml` |
| `repository_ref` | Yes | Repository identifier where the service lives |
| `declared_profiles` | Yes | List of applicable profile IDs |
| `api_contract_ref` | No | Reference to an OpenAPI spec, AsyncAPI spec, or equivalent |
| `dependencies` | No | List of `{service_id, required_version_range}` |
| `data_classification` | No | Classification of data handled, from taxonomy |
| `sla_references` | No | References to documented SLA commitments |
| `last_updated` | Yes | ISO 8601 date |

**Schema:** `schemas/service-contract.schema.yaml`  
**Relationships:** References profiles from 04; references service types and other taxonomy values from 02; referenced by other service contracts as a dependency

---

### 4.12 ADR — Architecture Decision Record

**Purpose:** The durable record of a significant architecture decision. ADRs are immutable once accepted. They provide the "why" behind every non-obvious design choice in the platform.

| Field | Required | Description |
|---|---|---|
| `id` | Yes | `ADR-{NNNN}` — sequential, never reused |
| `title` | Yes | Decision title in imperative form |
| `status` | Yes | `proposed`, `accepted`, `deprecated`, `superseded` |
| `date` | Yes | ISO 8601 date the decision was accepted |
| `deciders` | Yes | List of individuals who made or ratified the decision |
| `context` | Yes | The situation and constraints that made this decision necessary |
| `decision` | Yes | The specific decision made |
| `consequences` | Yes | The resulting constraints, implications, and trade-offs |
| `superseded_by` | No | ADR ID of the replacing decision |

**Format:** Markdown (not YAML), following `templates/adr.template.md`  
**Schema:** `schemas/adr.schema.yaml` — schema validates a thin front-matter block; the body is free-form Markdown  
**Relationships:** Cited by controls as `adr_ids`; cited by profiles; documents decisions in every domain

---

### 4.13 Change Record

**Purpose:** A structured record of a significant change made to `platform-compliance` — a control update, a profile version bump, a new binding, or a policy change. Provides the operational change history separate from git history.

| Field | Required | Description |
|---|---|---|
| `id` | Yes | `CHG-{YYYYMMDD}-{NNN}` |
| `change_type` | Yes | `control`, `profile`, `policy`, `binding`, `schema`, `workflow`, `tool` |
| `description` | Yes | What changed and why |
| `affected_object_ids` | Yes | List of IDs of objects changed |
| `related_adr_id` | No | ADR that drove this change |
| `breaking` | Yes | Boolean — does this change break existing consuming repositories? |
| `migration_guidance` | No | Required if `breaking` is true |
| `author` | Yes | Author of the change |
| `date` | Yes | ISO 8601 date |
| `review_refs` | No | Pull request URL or review record references |

**Schema:** `schemas/change-record.schema.yaml`  
**Relationships:** References changed objects by ID; references ADRs; aggregated into release records

---

### 4.14 Release Record

**Purpose:** The record of a versioned release of `platform-compliance`. A release is the mechanism by which downstream repositories opt in to a new version of the compliance system. Release records bundle change records, document the gate evaluation, and serve as the audit trail for the state of the compliance system at a point in time.

| Field | Required | Description |
|---|---|---|
| `id` | Yes | Semantic version string: `{MAJOR}.{MINOR}.{PATCH}` |
| `release_date` | Yes | ISO 8601 date |
| `change_record_ids` | Yes | List of change record IDs included in this release |
| `gate_assessment_id` | Yes | Assessment report ID for the release gate evaluation of `platform-compliance` itself |
| `release_summary` | Yes | Human-readable summary of what this release contains |
| `breaking_changes` | Yes | Boolean — if any included change record is breaking |
| `migration_guide` | No | Required if `breaking_changes` is true |
| `released_by` | Yes | Author |

**Schema:** `schemas/release-record.schema.yaml`  
**Relationships:** References change records; references its own gate assessment; referenced by downstream repos when pinning to a specific compliance version

---

### 4.15 Incident Record

**Purpose:** A structured record of a compliance incident — a failure, gap, or breach discovered in the platform's compliance state. Incident records capture the discovery, root cause, remediation, and any lessons learned that should drive control or policy changes.

| Field | Required | Description |
|---|---|---|
| `id` | Yes | `INC-{YYYYMMDD}-{NNN}` |
| `title` | Yes | Short title |
| `severity` | Yes | From `02-taxonomy/risk-levels.yaml` |
| `description` | Yes | What happened, how it was discovered |
| `affected_control_ids` | Yes | Controls that were violated or exposed as inadequate |
| `affected_resources` | Yes | Resources affected |
| `discovered_at` | Yes | ISO 8601 timestamp |
| `resolved_at` | No | ISO 8601 timestamp — absent if not yet resolved |
| `root_cause` | Yes | Factual root cause analysis |
| `remediation` | Yes | What was done to resolve the incident |
| `recurrence_prevention` | Yes | What changes prevent recurrence |
| `lessons_learned_adr_id` | No | ADR generated from lessons learned |
| `lessons_learned_change_ids` | No | Change records resulting from this incident |
| `status` | Yes | `open`, `resolved`, `monitoring` |

**Schema:** `schemas/incident-record.schema.yaml`  
**Relationships:** References controls from 03; may drive new ADRs in `decisions/` and change records

---

## 5. Cross-domain dependency graph

The following diagram shows the allowed dependency direction between domains (P4: forward references are forbidden).

```
schemas/        ←─── (no upstream dependencies within the repository)
    ↓ validates
02-taxonomy/    ←─── (no upstream dependencies)
    ↓ vocabulary referenced by
01-sources/     ←─── (no upstream dependencies)
    ↓ cited by
05-mappings/    ←─── depends on: 01-sources, 03-catalogs
    ↑ provides provenance to
03-catalogs/    ←─── depends on: 02-taxonomy, 05-mappings
    ↓ controls included by
04-profiles/    ←─── depends on: 02-taxonomy, 03-catalogs
    ↓ profile drives binding selection
06-bindings/    ←─── depends on: 02-taxonomy, 03-catalogs
    ↓ binding drives policy creation
07-policies/    ←─── depends on: 06-bindings
    ↓ execution produces
08-evidence/    ←─── depends on: schemas, 03-catalogs, 07-policies
    ↓ aggregated into
09-assessments/ ←─── depends on: 03-catalogs, 04-profiles, 08-evidence

templates/      ←─── depends on: schemas (mirrors them)
workflows/      ←─── depends on: 07-policies, 08-evidence, 09-assessments
tools/          ←─── depends on: schemas, all domains (read-only)
docs/           ←─── depends on: everything (read-only; never authoritative)
decisions/      ←─── depends on: nothing; cited by controls and profiles
```

The numbered sequence (01 through 09) is not arbitrary. It is the topological order of the dependency graph.

---

## 6. Structural coherence rationale

The directory structure is coherent for six reasons:

**1. The numbered sequence encodes the dependency graph.**  
No numbered domain depends on a higher-numbered domain. This means a CI check can validate the entire repository by processing directories in numeric order: if `03-catalogs/` passes, `04-profiles/` can be validated knowing its dependencies are clean.

**2. Every object type has exactly one home.**  
There is no ambiguity about where to create or find a waiver, a control, a profile, or a policy. This eliminates the most common form of documentation rot: objects in the wrong place.

**3. Schema-first design enforces structural contracts.**  
`schemas/` has no dependencies within the repository. It defines the contracts that all other directories satisfy. Adding a new field to a control is a change to a schema, which is a change record, which may require an ADR. This prevents schema creep.

**4. The repository governs itself.**  
The `.compliance-manifest.yaml` at the repository root declares `platform-compliance`'s own profile. This is not ceremonial — it means the compliance system is tested against its own rules before every release. A CI failure in `platform-compliance` is a compliance failure, treated the same as any other.

**5. Downstream consumption is via stable interfaces.**  
Downstream repositories do not consume internal files from `03-catalogs/` or `06-bindings/` directly. They interact with three stable surfaces: the profile they declare (from `04-profiles/`), the workflows they reference (from `workflows/`), and the schema they validate against (from `schemas/`). Internal reorganisation does not break downstream repositories as long as these interfaces are stable.

**6. Evidence and assessments are separated.**  
Evidence records are the raw facts. Assessment reports are the interpretation of those facts against a profile and gate criteria. Separating them means evidence can be queried independently, reports can be regenerated from the same evidence under different criteria, and waivers can be applied or removed without changing the underlying evidence.

---

## 7. What does not belong in this repository

| Item | Why | Where it belongs |
|---|---|---|
| Terraform modules | Implementation, not specification | `platform-modules` or service repos |
| Docker compose or service files | Implementation | Service-specific repos |
| Application business logic | Not platform compliance | Application repos |
| Infrastructure state | Sensitive operational data | State backend (e.g., Terraform Cloud, S3 with locking) |
| Secrets or credentials | Never in any repository | Secrets management backend |
| Environment-specific configuration | Operational, not normative | Environment repos |
| Application-specific CI workflow steps | Belongs to the app | Application repos, referencing these workflows |
| Ansible playbooks or roles | Out of scope by platform decision | Not introduced |
| Per-repository compliance reports that are not submitted back here | Optional submission | Each repository's own CI artifacts |
| Network diagrams or architectural visuals | Not normative | Separate documentation repository or wiki |

---

## 8. Bootstrapping sequence

Before the first operational repository can be governed, the following must exist in `platform-compliance` in this order:

1. `schemas/` — all object type schemas defined and validated
2. `02-taxonomy/` — all vocabulary files populated
3. `decisions/ADR-0001` — architecture decision ratifying this design
4. `01-sources/` — at least one standard registered (the minimum required for the first active control)
5. `03-catalogs/` — at minimum, the controls required by `PROF-BASE`
6. `05-mappings/` — mappings providing provenance for all active controls
7. `04-profiles/PROF-BASE.yaml` — the base profile that all repositories inherit
8. `04-profiles/PROF-PLATFORM-REPO.yaml` — the profile that governs `platform-compliance` itself
9. `06-bindings/` — bindings for all controls in `PROF-PLATFORM-REPO` in the `github` context
10. `07-policies/` — at least stub policies for all bindings above
11. `.compliance-manifest.yaml` — this repository declares `PROF-PLATFORM-REPO`
12. `workflows/compliance-check.yaml` — the first reusable workflow, enabling CI

Only after step 12 can `platform-compliance` pass its own release gate. Only after that can a downstream repository be created under governance.

---

*This document defines the design of `platform-compliance`. Implementation begins only after this design is ratified by ADR. Open questions are tracked in [docs/architecture-overview.md §9](architecture-overview.md#9-open-questions-and-future-decisions).*
