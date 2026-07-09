# Architecture Overview

**Repository:** `platform-compliance`  
**Status:** Architecture phase — no implementation code  
**Date:** 2026-07-08  

---

## Table of Contents

1. [What the platform is](#1-what-the-platform-is)
2. [Why compliance comes before implementation](#2-why-compliance-comes-before-implementation)
3. [What platform-compliance owns](#3-what-platform-compliance-owns)
4. [What platform-compliance does not own](#4-what-platform-compliance-does-not-own)
5. [How future repositories inherit its rules](#5-how-future-repositories-inherit-its-rules)
6. [The compliance chain: standards to evidence](#6-the-compliance-chain-standards-to-evidence)
7. [How this prevents undisciplined growth](#7-how-this-prevents-undisciplined-growth)
8. [Proposed repository structure](#8-proposed-repository-structure)
9. [Open questions and future decisions](#9-open-questions-and-future-decisions)

---

## 1. What the platform is

The platform is a self-hosted infrastructure management system built on reproducibility, auditability, and standards provenance. It manages self-hosted tools and servers in a way that makes every component's configuration, rationale, and compliance state traceable, machine-verifiable where possible, and stable across operator changes.

The platform is not a set of scripts or a collection of Terraform modules. It is an **operating model**: a set of rules, contracts, profiles, and evidence requirements that govern how every component is built, deployed, and evolved. The tooling implements the model. The model comes first.

Key properties the platform must exhibit:

- **Reproducible** — the same inputs always produce the same infrastructure state.
- **Standards-driven** — every control derives from a registered external standard or a documented platform decision. "Best practice" is not sufficient provenance.
- **Auditable** — every deployment produces evidence. Evidence is retained and cross-referenced to controls.
- **Machine-verifiable** — compliance checks run automatically. Human attestation is a fallback, not the primary mechanism.
- **Contract-driven** — the interface between repositories is a declared contract (profile, binding), not an informal convention.

The initial runtime direction is Terraform/OpenTofu-first. Docker-provider patterns are compatible. Ansible is out of scope and will not be introduced.

---

## 2. Why compliance comes before implementation

Infrastructure built without a compliance backbone accumulates three compounding problems:

1. **Inconsistency** — each repository develops its own conventions because there is no canonical source to reference. Divergence becomes the default.
2. **Ungoverned drift** — there is no mechanism to detect when a deployed component moves away from its intended state. Drift is discovered only when something breaks.
3. **Retrofitting cost** — applying compliance controls after infrastructure exists is an order of magnitude harder than building them in from the start. Retrofitting also produces incomplete coverage because it cannot be applied uniformly to all historical decisions.

Building `platform-compliance` first inverts this dynamic:

- Every subsequent repository is **born into a governed system** rather than added to it later.
- Compliance controls are **pull-based**: a new repository adopts a profile and inherits its controls, rather than having controls pushed onto it individually.
- The cost of compliance is **distributed evenly** across the creation of each component rather than concentrated in a single painful remediation effort.

The platform will accumulate technical debt. Compliance-first does not eliminate that possibility, but it contains it by making ungoverned additions structurally difficult.

---

## 3. What platform-compliance owns

`platform-compliance` owns the **definition layer** of the compliance model. It does not own any operational component, but it defines the contract every operational component must satisfy.

### 3.1 Standards Source Registry

A catalogue of the external standards the platform draws controls from. Each entry in the registry records:

- The standard name, version, and issuing body
- A stable identifier used internally (e.g., `CIS-DOCKER-1.6`, `NIST-SP800-53-AC-2`)
- The canonical URL or document reference
- The date the standard was registered
- Any platform-level notes on scope or applicability

The registry is not exhaustive by default. A standard must be explicitly registered before any control can cite it. This is intentional: it prevents silent references to standards no one has reviewed.

### 3.2 Standard-to-Control Mapping

A record of which platform controls are derived from which standard entries, and how. Each mapping must identify:

- The source standard entry (from the registry)
- The specific clause, section, or requirement within that standard
- The platform control identifier it maps to
- The mapping rationale: why this clause was interpreted as this control in this platform's context

A single control may map to multiple standard clauses. A single standard clause may produce multiple controls. Both are valid. The mapping is many-to-many but every relationship must be documented.

### 3.3 Platform Control Catalog

The authoritative list of controls that apply across the platform. Each control entry records:

- A stable internal identifier (e.g., `PLT-SEC-001`)
- A short title and plain-language description
- The enforcement level: mandatory, recommended, or informational
- The applicable scope: repository, service, runtime, environment, or all
- The standard-to-control mappings that provide its provenance
- The date introduced and any superseded predecessor controls

Controls in the catalog have no implementation details. They describe **what must be satisfied**, not how.

### 3.4 Compliance Profiles

Named groupings of controls applied to a class of repository or service. A profile answers the question: "I am a new Terraform module repository — which controls apply to me?"

Each profile records:

- A stable profile identifier (e.g., `PROFILE-TERRAFORM-MODULE`)
- The set of control identifiers it includes, with any profile-specific overrides to enforcement level
- The scope it applies to
- Any inheritance from a parent profile

New repositories declare which profile governs them. That declaration becomes part of the repository's contract with the platform.

### 3.5 Implementation Binding Specifications

Implementation bindings describe **how** a specific control is satisfied in a specific context. They are specifications, not code. For example: "Control PLT-SEC-001 in the context of a GitHub-hosted Terraform repository is satisfied by the presence of a Dependabot configuration file with the terraform ecosystem enabled and an update schedule no greater than weekly."

Bindings allow the same control to be satisfied differently across different technology contexts while preserving a traceable link to the abstract control.

### 3.6 Policy-as-Code Definitions

The machine-verifiable encoding of implementation bindings. Where a binding describes a rule in prose, the policy encodes it as a checkable assertion. Policies run in CI/CD pipelines and against live infrastructure.

`platform-compliance` owns the **definition and versioning** of these policies. The mechanism that executes them (the CI tool, the OPA evaluator, the Terraform check) is defined in the execution environment. The policy logic itself is governed here.

### 3.7 Evidence Schema and Ledger Format

The schema that defines what a valid piece of compliance evidence looks like, and the format of the evidence ledger in which evidence is aggregated.

Evidence must link:

- The control it satisfies
- The policy that evaluated it
- The resource or repository it applies to
- The timestamp and context of evaluation
- The result (pass, fail, waived) and, for waivers, the documented rationale

`platform-compliance` defines this schema. Evidence is collected and stored by each repository's CI/CD pipeline using this schema.

### 3.8 Assessment Report Templates and Gate Criteria

The templates used to produce structured compliance assessment reports, and the criteria that determine whether a release gate or deployment gate is satisfied.

A release gate is a blocking check before a version is published. A deployment gate is a blocking check before infrastructure is applied. Both gates reference assessment reports produced from collected evidence.

---

## 4. What platform-compliance does not own

`platform-compliance` deliberately excludes operational content. The following belong to other repositories:

| Item | Owner (future repo) |
|------|-------------------|
| Terraform/OpenTofu modules | `platform-modules` or service-specific repos |
| Docker service configurations | Service-specific repos |
| CI/CD pipeline implementations | Each repository's own pipeline definition |
| Network topology and host configuration | Infrastructure repos |
| Application code | Application repos |
| Actual infrastructure state files | Each environment's state backend |
| Grafana dashboards, alerting rules | Observability repos |
| Secrets and credentials | Not in any repository; managed by a secrets backend |

`platform-compliance` may reference these items when defining bindings (e.g., "a Terraform module must have a `versions.tf` file"), but it does not contain them.

---

## 5. How future repositories inherit its rules

The inheritance model is profile-based and explicit. The mechanism works as follows:

1. A new repository is created.
2. Before any code is committed, the repository must declare a compliance profile. This declaration is a file in the repository (format to be defined) that names one or more profiles from the `platform-compliance` profile catalog.
3. The declared profile resolves to a set of controls.
4. Each control has one or more implementation bindings for the repository's technology context.
5. The repository's CI/CD pipeline runs the policy-as-code definitions associated with those bindings.
6. Each pipeline run produces evidence. Evidence is stored and linked to the repository and commit.
7. On release or deployment, the evidence is evaluated against the gate criteria. The gate passes or fails.

There is no opt-out. A repository that has not declared a profile fails its compliance gate by default. The platform does not contain ungoverned repositories.

Future changes to controls propagate through this chain: a control update in `platform-compliance` flows to all profiles that include it, which flows to all repositories that declare those profiles. Repositories are notified (via automated PR or check) when a profile they declare has changed.

---

## 6. The compliance chain: standards to evidence

The following diagram represents the full conceptual flow:

```
┌─────────────────────────────────────────────────────────────┐
│  EXTERNAL STANDARDS                                         │
│  (CIS Benchmarks, NIST SP 800-53, SOC 2, ISO 27001, etc.)  │
└──────────────────────────┬──────────────────────────────────┘
                           │ registered with provenance
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  STANDARDS SOURCE REGISTRY                                  │
│  Canonical list of standards the platform draws from.       │
│  Each entry is versioned, citable, and scoped.              │
└──────────────────────────┬──────────────────────────────────┘
                           │ clause → control with rationale
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  STANDARD-TO-CONTROL MAPPING                                │
│  Explicit, documented linkage between standard clauses      │
│  and platform controls. Many-to-many.                       │
└──────────────────────────┬──────────────────────────────────┘
                           │ grouped into catalog
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  PLATFORM CONTROL CATALOG                                   │
│  PLT-XXX-NNN identifiers. What must be satisfied.           │
│  No implementation detail. Enforcement levels.              │
└──────────────────────────┬──────────────────────────────────┘
                           │ grouped by scope
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  COMPLIANCE PROFILES                                        │
│  Named sets of controls per repo/service type.              │
│  PROFILE-TERRAFORM-MODULE, PROFILE-SERVICE, etc.            │
└──────────────────────────┬──────────────────────────────────┘
                           │ per-technology specification
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  IMPLEMENTATION BINDINGS                                    │
│  How a control is satisfied in a given context.             │
│  Prose specification. Links control to observable artifact. │
└──────────────────────────┬──────────────────────────────────┘
                           │ machine-encoded
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  POLICY-AS-CODE                                             │
│  Machine-verifiable rules. Runs in CI/CD and against        │
│  live infrastructure.                                       │
└──────────────────────────┬──────────────────────────────────┘
                           │ checks applied to
              ┌────────────┼────────────────┐
              ▼            ▼                ▼
         Repositories   Services      Runtime/Env
              │            │                │
              └────────────┴────────────────┘
                           │ results captured as
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  EVIDENCE LEDGER                                            │
│  Timestamped, structured evidence linked to controls,       │
│  policies, resources, and commits.                          │
└──────────────────────────┬──────────────────────────────────┘
                           │ aggregated into
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  ASSESSMENT REPORTS                                         │
│  Per-repository, per-release, per-environment reports.      │
│  Control-by-control status with evidence citations.         │
└──────────────────────────┬──────────────────────────────────┘
                           │ evaluated against gate criteria
              ┌────────────┴───────────────┐
              ▼                            ▼
     RELEASE GATE                  DEPLOYMENT GATE
     Blocks version publish         Blocks `apply`
              │                            │
              └────────────┬───────────────┘
                           ▼
              COMPLIANCE DASHBOARD
              Aggregate view across all repos/services
```

Each layer in this chain is a separate concern with a clear owner. The chain cannot be short-circuited: a policy that has no evidence cannot pass a gate, and evidence that has no policy linkage is not admitted to the ledger.

---

## 7. How this prevents undisciplined growth

Without this architecture, the typical failure modes are:

- A new service repository is created, inheriting nothing, governed by nothing. It ships. It drifts.
- Someone adds a Terraform resource directly to a module with no review of which controls it must satisfy.
- A compliance review is scheduled quarterly and finds months of ungoverned changes. Remediation is expensive and incomplete.
- Standards are referenced informally ("we follow CIS Docker Benchmark") but no one can say which specific controls are implemented, where, or verified how.

This architecture prevents those failure modes by making compliance **structural**:

| Failure mode | Prevention mechanism |
|---|---|
| New repos with no governance | Profile declaration is required. No profile = gate fails by default. |
| Standards cited without traceability | The standards registry requires registration before citation. Controls must map to registered entries. |
| Drift between declared and actual state | Policy-as-code runs continuously, not just at initial setup. Evidence is collected per-run, not once. |
| Controls that cannot be verified | Implementation bindings must specify a machine-verifiable observable. If a control cannot be encoded, that is a documented gap, not an implicit pass. |
| Waiver abuse | Waivers are first-class evidence entries with mandatory documented rationale, expiry dates, and approver records. They appear in assessment reports. |
| Ungoverned module composition | Terraform module repos declare a profile. The profile includes controls on module structure, documentation, and version pinning. |

The platform does not eliminate human judgment. It requires that human judgment be recorded, traceable, and periodically re-evaluated.

---

## 8. Proposed repository structure

```
platform-compliance/
│
├── README.md                          # Entry point. Links to this document.
│
├── docs/
│   ├── architecture-overview.md       # This document
│   ├── decisions/                     # Architecture Decision Records (ADRs)
│   │   └── ADR-0001-compliance-first.md
│   └── glossary.md                    # Canonical definitions of terms used
│
├── standards/
│   └── registry/
│       ├── README.md                  # How to register a standard
│       └── (one file or directory per registered standard)
│
├── controls/
│   ├── catalog/
│   │   ├── README.md                  # Control ID schema, enforcement levels
│   │   └── (control definition files, organized by domain)
│   └── mappings/
│       └── (standard-to-control mapping files)
│
├── profiles/
│   ├── README.md                      # How to declare a profile in a repo
│   └── (one file per named profile)
│
├── bindings/
│   ├── README.md                      # Binding specification format
│   └── (one file per control-context pair)
│
├── policies/
│   ├── README.md                      # Policy authoring guide and toolchain
│   └── (policy files organized by domain and tool)
│
├── evidence/
│   ├── schema/
│   │   └── README.md                  # Evidence record schema definition
│   └── ledger/
│       └── README.md                  # Ledger format and retention rules
│
└── assessments/
    ├── templates/
    │   └── README.md                  # Assessment report template
    └── gates/
        └── README.md                  # Release and deployment gate criteria
```

This structure is intentional. Each directory is a distinct concern. Files within a directory follow a defined format (to be specified as each directory is built out). No directory contains implementation code.

---

## 9. Open questions and future decisions

The following questions are unresolved and must be recorded as decisions before the corresponding layer is built:

| # | Question | Impacts |
|---|----------|---------|
| Q1 | Which external standards will be registered first? | Standards registry, initial control catalog |
| Q2 | What format will control definition files use (YAML, OSCAL, custom)? | Control catalog tooling, policy generation |
| Q3 | Which policy-as-code engine will be used (OPA/Rego, Conftest, Terraform checks, other)? | Policy directory structure, CI integration |
| Q4 | Where will the evidence ledger be stored and who has write access? | Evidence schema, CI/CD integration |
| Q5 | What is the initial set of compliance profiles needed before the first operational repo can be created? | Profile directory, first repo unblocked |
| Q6 | How will waivers be approved and tracked? | Evidence schema, assessment reports |
| Q7 | How will `platform-compliance` itself be governed? Which profile applies to it? | Bootstrapping sequence |

These questions will be resolved as Architecture Decision Records in `docs/decisions/`. No layer is built until its blocking questions have an ADR.

---

*This document is a living architecture note. It will be updated as decisions are made and layers are built out. The current state represents the initial alignment on concept and structure only.*
