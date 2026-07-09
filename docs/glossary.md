# Glossary

**Repository:** `platform-compliance`  
**Date:** 2026-07-08

Canonical definitions for terms used across the compliance system. When a term appears in a control, schema, profile, or policy, this glossary is the authoritative definition. If a term is used but not defined here, it should be added before being used in normative content.

---

### A

**ADR (Architecture Decision Record)**  
A structured document recording a significant architecture decision: its context, the decision made, and its consequences. ADRs are immutable once accepted. See `decisions/` and `templates/adr-template.md`. Governed by DOC-002 and sourced from SRC-NYGARD-ADR-2011.

**Assessment report**  
An aggregated compliance verdict for a subject (repository, service, release, or environment) at a specific point in time. Produced from evidence records, a declared profile, and any active waivers. Consumed by gate evaluation. Schema: `schemas/assessment.schema.json`.

**Artifact hash**  
A SHA-256 hash of the evidence record's `details` field, stored as `sha256:{hex}`. Provides tamper-evidence for evidence records. Format: `sha256:` followed by 64 lowercase hex characters.

**Assessment cadence**  
How frequently a control is evaluated. One of: `per-commit`, `per-merge`, `per-release`, `per-deployment`, `continuous`, `on-change`. Defined in the control catalog.

**Automation status**  
Whether a control's evidence is collected by machine or human. One of: `automated`, `partially-automated`, `manual`, `automation-target`, `not-automatable`. Controls with `automated` status must have OPA policy checks.

---

### B

**Binding** (implementation binding)  
A prose specification of how a control is satisfied in a specific technology context. Links the abstract "what" of a control to the concrete "how" of a policy check. Lives in `06-bindings/`. Not executable — defines the specification that policies implement.

**Branch protection**  
A GitHub repository setting that prevents direct pushes to a branch, requires pull request reviews, and enforces status checks before merge. Required by SRC-001 and SRC-002.

---

### C

**Change record**  
A structured record of a significant change to `platform-compliance`. Required for any PR modifying normative content. Referenced in the PR description as `Change Record: CHG-YYYYMMDD-NNN`. Schema: `schemas/change-record.schema.json`.

**CODEOWNERS**  
A file in a repository that maps paths to responsible reviewers. Required by SRC-003. GitHub uses CODEOWNERS to automatically request reviews.

**Compliance manifest** (`.compliance-manifest.yaml`)  
The declaration each repository places at its root to declare its compliance profile, type, and technology contexts. Entry point for all compliance enforcement. Schema: `schemas/repository-compliance.schema.json`.

**Compliance profile**  
A named, versioned set of controls for a class of repository or service. Defines which controls are mandatory, manual, or deferred, and the gate criteria for each transition point. Lives in `04-profiles/`. Schema: `schemas/profile.schema.json`.

**Control**  
A platform requirement: what must be true, not how to achieve it. Identified by a stable ID (e.g., `SRC-001`). Organised in the catalog (`03-catalogs/`) by domain. Has provenance via mappings and is satisfied via bindings and policies.

**Control catalog**  
The authoritative list of all platform controls. Lives in `03-catalogs/controls/`. Controls are organised by domain subdirectory.

**Control domain**  
A prefix code categorising a group of related controls. Defined in `02-taxonomy/control-domains.yaml`. Examples: SRC (Source Control), SEC (Security), IAC (Infrastructure as Code).

**Continuous audit**  
A compliance gate that runs on a recurring schedule (daily/weekly) independent of code changes. Detects configuration drift. Failures generate alerts but do not immediately block operations.

---

### D

**Deferred** (control lifecycle status)  
A control that is planned but not yet active. Included in profiles to signal intent. Not checked; failures do not affect gates.

**Deployment gate**  
A compliance check that must pass before `terraform apply` or service deployment. Includes all release gate controls plus deployment-specific checks (health checks, backup policies, etc.).

**Drift**  
The condition where actual infrastructure or configuration state has diverged from the declared desired state. Detected by the continuous audit gate.

---

### E

**Evidence record**  
A timestamped, structured, immutable record of a single policy check evaluation against a specific resource at a specific commit. The atomic unit of compliance proof. Schema: `schemas/evidence.schema.json`.

**Evidence ledger**  
The organised collection of all evidence records. Structured as `08-evidence/collected/angirasa-risk/{repo}/{date}/`.

**Enforcement level**  
How strongly a gate enforces a control. One of: `block` (failure prevents the gated action), `warn` (failure generates a warning but does not block), `notify` (failure generates an alert). Set per-gate in the profile or gate criteria files.

---

### G

**Gate**  
A named compliance checkpoint at a transition point (merge, release, deployment, continuous audit). Defined in the profile and machine-readable gate criteria files (`09-assessments/gates/`). Gates are evaluated against assessment reports.

**Gate criteria file**  
A machine-readable YAML file listing the controls and enforcement levels for a specific gate. Lives in `09-assessments/gates/`. Derived from and must stay in sync with the profile.

---

### I

**Implementation binding** — see *Binding*.

**Incident record**  
A structured record of a compliance incident (failure, gap, or breach). Required for threshold-meeting incidents (high/critical severity). Must be created within 48 hours of resolution. Schema: `schemas/incident-record.schema.json`.

---

### L

**Lifecycle status** (control)  
Current state of a control. One of: `active` (enforced), `deferred` (planned, not yet enforced), `deprecated` (no longer recommended), `superseded` (replaced by another control).

---

### M

**Mapping** (standard-to-control mapping)  
An explicit, documented linkage between a specific clause in a registered external standard and a platform control. Provides the provenance chain. Lives in `05-mappings/`. Schema: `schemas/mapping.schema.json`.

**Merge gate**  
A compliance check that must pass before a pull request can be merged to a protected branch. The primary compliance enforcement point for day-to-day development.

---

### N

**Not applicable**  
An evidence/assessment result indicating that a control's scope condition evaluated to false for the assessed repository or service. Does not affect gate pass/fail.

---

### O

**Observable artifact**  
In a binding: the specific, machine-locatable thing that a policy checks to verify a control is satisfied. Examples: "GitHub API response for branch protection", "Dockerfile USER instruction".

**OPA (Open Policy Agent)**  
The primary policy engine for platform compliance. Policies are written in Rego and evaluated with the `opa` CLI or `conftest`. Selected by ADR-0004.

**Overall result** (assessment)  
The top-level compliance verdict for an assessment. One of: `pass`, `fail`, `pass-with-waivers`, `manual-review-required`, `inconclusive`.

---

### P

**Platform compliance profile** — see *Compliance profile*.

**Policy check**  
An OPA Rego file (or shell script) that evaluates a binding against actual infrastructure/code and produces a structured JSON result. Lives in `07-policies/`. Registered via a companion `.check.yaml` metadata file.

**Provenance chain**  
The traceable link from an external standard → mapping → control → binding → policy → evidence → assessment. Every compliance claim is provable by following this chain.

**Push protection**  
A GitHub feature that intercepts commits containing detected secrets before they reach the remote repository. Required (along with secret scanning) by SEC-002.

---

### R

**Release gate**  
A compliance check that must pass before a version tag is published and artifacts are released. Includes all merge gate controls plus release-specific checks.

**Release record**  
A structured record of a versioned release of `platform-compliance`. Links the release tag to the compliance evidence and gate assessment. Schema: `schemas/release-record.schema.json`.

**Rego**  
The policy language used by OPA. Declarative, testable, and produces structured JSON output. Used for all automated compliance policy checks in `07-policies/opa/`.

**Repository compliance manifest** — see *Compliance manifest*.

**Root of trust**  
The authoritative source for platform code. GitHub is the current root of trust (ADR-0002). The root of trust is where branch protection and compliance gates are enforced.

---

### S

**Schema**  
A JSON Schema definition specifying the required structure of a governance object. Lives in `schemas/`. All governance objects are validated against their schema.

**Scope condition**  
A boolean expression in a binding or profile control entry, evaluated against the `.compliance-manifest.yaml`, that determines whether a control applies to a specific repository. Example: `repository.type in ['terraform-module', 'terraform-root']`.

**Secret scanning**  
A GitHub feature that automatically scans repository contents for credential patterns. Required (with push protection enabled) by SEC-002.

**Severity** (control)  
The impact of a control failure. One of: `critical`, `high`, `medium`, `low`, `informational`. Distinct from priority (process to obtain an exception).

**Standard source registry**  
The authoritative catalogue of external standards the platform draws controls from. Lives in `01-sources/registry/`. A standard must be registered here before any control can cite it.

---

### T

**Taxonomy**  
The controlled vocabularies used across the compliance system. Lives in `02-taxonomy/`. Every enumerated value used in any governance object is defined here.

**Technology context**  
A classification of the technology environment a binding applies to. One of: `github`, `terraform`, `docker`, `runtime-linux`, `github-actions`. Defined in `02-taxonomy/technology-contexts.yaml`.

---

### W

**Waiver**  
A documented, time-bounded, approved exception to a platform control. Not a silence — an explicit risk acceptance. Has a mandatory expiry date, named approver, and documented rationale. Appears in all assessment reports covering the waived control. Schema: `schemas/waiver.schema.json`.
