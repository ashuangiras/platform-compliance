# Platform Compliance Architecture

**Repository:** `platform-compliance`  
**Version:** 1.0 (draft)  
**Date:** 2026-07-08

This document describes the architecture of the platform compliance system. It is written to be self-contained: no prior conversation context or external documents are required to understand it.

---

## Table of Contents

1. [What this platform is](#1-what-this-platform-is)
2. [Why compliance precedes implementation](#2-why-compliance-precedes-implementation)
3. [The compliance chain](#3-the-compliance-chain)
4. [Layer-by-layer explanation](#4-layer-by-layer-explanation)
5. [How future repositories inherit compliance](#5-how-future-repositories-inherit-compliance)
6. [Self-governance: the platform governing itself](#6-self-governance-the-platform-governing-itself)
7. [What this platform does not claim](#7-what-this-platform-does-not-claim)
8. [What is intentionally out of scope now](#8-what-is-intentionally-out-of-scope-now)

---

## 1. What this platform is

This is a self-hosted infrastructure platform designed around three non-negotiable properties:

**Reproducibility** — the same inputs always produce the same infrastructure state. No manual steps, no implicit environment assumptions, no undeclared dependencies.

**Auditability** — every component's configuration, the rationale for it, and the evidence that it satisfies the platform's controls are traceable and retained. An operator or auditor can answer "why is this configured this way?" and "how do I know it is still configured that way?" for any component.

**Standards provenance** — every control the platform enforces is linked to either a registered external standard or a ratified Architecture Decision Record. Controls do not exist because someone decided they were good ideas. They exist because they are traceable to a documented source.

The platform manages self-hosted tools and servers. The long-term execution model is Terraform/OpenTofu-first, Docker-provider-compatible, and GitOps-informed. The source code is hosted on GitHub as the initial root of trust.

This platform does not use Ansible and does not plan to introduce it.

---

## 2. Why compliance precedes implementation

The instinct when building a new platform is to start with the infrastructure: spin up a server, deploy a service, iterate. That instinct is correct for prototyping. It is incorrect for a platform intended to be reproducible, auditable, and governed.

Infrastructure built without a compliance backbone has three compounding failure modes:

**Inconsistency.** Each new component is created by whoever is available at the time, with whatever conventions that person applies. Over months and years, the platform becomes a collection of inconsistent components with no single standard to point to.

**Ungoverned drift.** Configuration that is not checked continuously can drift silently. A security control that was satisfied at creation may no longer be satisfied six months later. Without continuous verification, this is only discovered when something breaks.

**Retrofitting cost.** Applying compliance controls to existing infrastructure is significantly harder than building compliant infrastructure in the first place. It requires auditing every component, identifying gaps, fixing them, and maintaining that state — all while the platform continues to operate. Retrofitting produces incomplete coverage because it cannot be applied uniformly to historical decisions.

The compliance-first approach inverts all three:

- Every new component is born into an established compliance model, so consistency is structural rather than cultural.
- Policy checks run continuously, so drift is detected before it becomes a problem.
- The retrofitting cost is zero because there is nothing to retrofit: the first component was compliant, and so was every subsequent one.

The cost of this approach is that the platform takes longer to produce its first operational component. That is an acceptable trade-off for a platform intended to operate for years.

---

## 3. The compliance chain

The following diagram shows the complete flow from external standards to deployed infrastructure. Every layer in this chain is owned by `platform-compliance`.

```
┌──────────────────────────────────────────────────────────────────┐
│  EXTERNAL STANDARDS                                              │
│  CIS Docker Benchmark, OpenSSF SLSA, OpenSSF Scorecard,         │
│  Google SRE, AWS Well-Architected, OpenGitOps, ITIL (adapted),  │
│  CNCF Platform Engineering Maturity, Nygard ADR                 │
└─────────────────────────────┬────────────────────────────────────┘
                              │  registered with: name, version, URL,
                              │  role, retrieval date
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  01 — STANDARDS SOURCE REGISTRY                                  │
│  Canonical list of standards the platform draws from.            │
│  A standard must be registered here before any control may       │
│  cite it. Each entry has a stable ID (e.g., SRC-CIS-DOCKER-V1-6)│
└─────────────────────────────┬────────────────────────────────────┘
                              │  clause → control, with rationale
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  05 — STANDARD-TO-CONTROL MAPPINGS                               │
│  Explicit, documented linkage between specific standard clauses  │
│  and platform controls. Many-to-many. Every relationship has a   │
│  rationale explaining the interpretation.                        │
└─────────────────────────────┬────────────────────────────────────┘
                              │  grouped into a catalog
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  03 — PLATFORM CONTROL CATALOG                                   │
│  PLT-SEC-001, SRC-001, IAC-001, etc.                             │
│  What must be satisfied — not how. Each control has: domain,     │
│  type, priority, severity, statement, rationale, evidence        │
│  required, and lifecycle status.                                 │
└─────────────────────────────┬────────────────────────────────────┘
                              │  selected into named profiles
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  04 — COMPLIANCE PROFILES                                        │
│  PROF-PLATFORM-V1, PROF-TERRAFORM-MODULE, etc.                   │
│  Named sets of controls for repository/service types.            │
│  Defines: mandatory, automated-required, manual-initially,       │
│  deferred. Defines the four gates and which controls block each. │
└─────────────────────────────┬────────────────────────────────────┘
                              │  per-technology specification
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  06 — IMPLEMENTATION BINDINGS                                    │
│  BIND-SRC-001-GITHUB, BIND-IAC-001-TERRAFORM, etc.               │
│  How each control is satisfied in each technology context.       │
│  Prose specification: what observable artifact must exist?       │
│  Links controls to the policies that verify them.                │
└─────────────────────────────┬────────────────────────────────────┘
                              │  machine-encoded rules
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  07 — POLICY-AS-CODE                                             │
│  POL-SRC-001-GITHUB.rego, POL-IAC-001-TERRAFORM.sh, etc.        │
│  Executable checks that verify bindings are satisfied.           │
│  Each policy produces a structured JSON result.                  │
└─────────────────────────────┬────────────────────────────────────┘
                              │  checks applied to
           ┌──────────────────┼──────────────────────┐
           ▼                  ▼                       ▼
    Repositories         Services              Runtime/Env
           │                  │                       │
           └──────────────────┴──────────────────────┘
                              │  results captured as
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  08 — EVIDENCE LEDGER                                            │
│  Timestamped, structured records. Each record links:             │
│  control → policy → resource → commit → result → timestamp.     │
│  Retained per repository per commit.                             │
└─────────────────────────────┬────────────────────────────────────┘
                              │  aggregated into
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  09 — ASSESSMENT REPORTS                                         │
│  Per-repository, per-release, per-environment.                   │
│  Control-by-control status with evidence citations.              │
│  Includes waiver records for any failing controls.               │
└─────────────────────────────┬────────────────────────────────────┘
                              │  evaluated against gate criteria
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
    MERGE GATE          RELEASE GATE       DEPLOYMENT GATE
    (blocks PR merge)   (blocks tag)       (blocks apply)
          │                   │                   │
          └───────────────────┴───────────────────┘
                              │
                   CONTINUOUS AUDIT
                   (scheduled; alerts on drift)
```

The numbered sequence `01 → 05 → 03 → 04 → 06 → 07 → 08 → 09` is the topological dependency order. No layer may reference a later layer. This makes the dependency graph acyclic and allows validation to proceed in numeric order.

Note: `02-taxonomy/` is a horizontal dependency of all layers — it provides the controlled vocabularies (domain codes, enforcement levels, repository types, technology contexts) used everywhere.

---

## 4. Layer-by-layer explanation

### 4.1 Standards Source Registry (`01-sources/`)

The registry is the root of provenance. Before any control can derive authority from an external standard, that standard must be registered here.

Each entry records:
- A stable ID (e.g., `SRC-OPENSSF-SCORECARD-V2`)
- The standard's name, version, publisher, and canonical URL
- The date it was retrieved and reviewed
- Its **role**: how the platform relates to it
  - `normative` — controls are directly derived from specific requirements
  - `adopted` — practices are applied as-is
  - `adapted` — the standard's intent is applied but tailored to the platform's context; adaptations are documented
  - `informative` — referenced for context only, not a source of controls
  - `deferred` — registered but not yet active

Currently registered: CIS Docker Benchmark 1.6, OpenSSF SLSA v1, OpenSSF Scorecard v2, Google SRE, AWS Well-Architected Framework 2024, OpenGitOps 1.0, ITIL 4 (adapted), CNCF Platform Engineering Maturity Model (informative), Nygard ADR 2011.

### 4.2 Platform Taxonomy (`02-taxonomy/`)

The shared vocabulary. Every enumerated value used in any governance object is defined here. This includes: domain codes (SRC, SEC, IAC, etc.), enforcement levels (mandatory, recommended, informational), priority levels (P1–P4), risk severity levels (critical, high, medium, low), control types (preventive, detective, directive, etc.), repository types, service types, environment types, and technology contexts.

Because all enumerations are centralised, schema validators can enforce referential integrity across the entire system. Adding a new value requires updating the taxonomy first.

### 4.3 Standard-to-Control Mappings (`05-mappings/`)

The provenance layer. Each mapping record links a specific clause in a registered standard to a specific platform control, with a documented rationale explaining the interpretation. Mappings are many-to-many: one control may derive from multiple standards; one standard clause may inform multiple controls.

Mappings make the compliance model auditable: given any control, an auditor can follow the mapping chain to the original standard clause that motivates it.

Where specific clause references require document research and are not yet verified, they are marked with `[PLACEHOLDER: ...]`. A v1.0.0 release does not require all placeholders to be resolved, but every active control must have at least one mapping record even if the clause is a placeholder.

### 4.4 Platform Control Catalog (`03-catalogs/`)

The authoritative list of **what must be satisfied**. Controls do not describe how; that is the role of bindings. A control states the requirement, explains the rationale, and specifies what evidence would demonstrate compliance.

The 23 initial controls are organized into 10 domains: SRC (Source Control), SUP (Supply Chain), IAC (Infrastructure as Code), SEC (Security), RUN (Runtime/Docker), OBS (Observability), BAK (Backup), CHG (Change/Release), DOC (Documentation), INC (Incident), NET (Network). Each control has a stable ID that never changes (e.g., `SRC-001`, `SEC-002`).

Controls have a lifecycle status: `active` (currently enforced), `deferred` (planned but not yet active), `deprecated`, or `superseded`.

### 4.5 Compliance Profiles (`04-profiles/`)

A profile is a named, versioned set of controls for a class of repository or service. It answers the question: *"I am a Terraform module repository — which controls apply to me, and what happens if one fails?"*

`PROF-PLATFORM-V1` is the initial profile. It classifies controls into:
- **Mandatory** — must pass; failure blocks the applicable gate
- **Automated required** — a subset of mandatory controls that must be machine-verified; manual attestation is not sufficient
- **Manual initially** — manual evidence is accepted in v1; each has an automation deadline
- **Deferred** — planned but not yet checked; declaring them signals intent

The profile defines four gates. Each gate specifies which controls are evaluated and what happens when one fails:

| Gate | When evaluated | Failure blocks |
|---|---|---|
| Merge gate | Every pull request | PR merge |
| Release gate | Before a version tag is published | Tag/release |
| Deployment gate | Before `terraform apply` or service deploy | Apply/deploy |
| Continuous audit | Daily/weekly schedule | Triggers alert; does not immediately block |

### 4.6 Implementation Bindings (`06-bindings/`)

A binding describes **how** a control is satisfied in a specific technology context. It is a prose specification, not executable code. For example: "Control SRC-001 in the GitHub context is satisfied by the presence of branch protection on the default branch with these specific settings enabled."

Bindings bridge the abstract control and the concrete policy check. They make it possible for the same control to be satisfied differently in different technology contexts (a branch protection check works differently in GitHub than in a self-hosted Gitea) without losing the connection to the abstract requirement.

### 4.7 Policy-as-Code (`07-policies/`)

The executable implementation of bindings. Each policy check runs against a real repository, real infrastructure code, or a running service and produces a structured JSON result (pass, fail, waived, not-applicable, error).

Policy results are the inputs to the evidence ledger. Policies must be testable: every policy has at least one fixture that should produce a pass result and at least one that should produce a fail result.

The policy engine (the technology used to run policies — OPA/Rego, Conftest, shell scripts, etc.) is chosen by ADR before any policies are written.

### 4.8 Evidence Ledger (`08-evidence/`)

The factual record of what was checked, when, against what, and what the result was. An evidence record links:
- The control it addresses
- The policy check that produced it
- The resource it covers (repository, service, environment)
- The commit SHA at evaluation time
- The timestamp
- The result

Evidence is collected automatically by CI/CD pipelines (via reusable workflows) and stored in a defined schema. Evidence records are immutable once written. An incorrect evidence record is corrected by writing a new one and voiding the old one with a reason.

### 4.9 Assessment Reports (`09-assessments/`)

An assessment report aggregates evidence records for a subject (a repository, a service, an environment, or a release) into a structured compliance verdict. It answers: "Does this subject satisfy its declared profile as of this assessment date?"

Assessment reports are the input to gate evaluations. The release gate and deployment gate consume assessment reports, not raw evidence. This separation allows the gate criteria to be evaluated independently of the evidence collection mechanism.

Waivers are stored alongside assessments. A waiver is a time-bounded, documented exception to a control — not a silent skip, but an explicit risk acceptance with a named approver and an expiry date.

---

## 5. How future repositories inherit compliance

Every repository in the platform (past, present, and future) follows this process:

**Step 1: Declare a compliance manifest.** Every repository root contains a `.compliance-manifest.yaml` that declares:
- The repository's type (from the taxonomy)
- Which compliance profile governs it
- Which technology contexts apply
- Any active waivers

**Step 2: Profile drives gate checks.** The declared profile determines which controls are checked at each gate. Scope conditions within the profile apply controls only when relevant (e.g., IAC controls only apply to terraform-type repositories).

**Step 3: CI/CD runs the reusable workflows.** The repository's CI pipeline references the reusable workflows defined in this repository. Those workflows:
1. Validate the compliance manifest
2. Determine which controls apply based on the profile and the repository's declared context
3. Run the applicable policy checks
4. Write evidence records
5. Generate an assessment report
6. Evaluate the applicable gate (merge, release, or deployment)

**Step 4: Gates pass or block.** A gate evaluation produces a pass, a pass-with-waivers, or a fail. A fail blocks the gated action (merge, release, or deployment). A waiver allows a failing control to count as pass-with-waiver if an approved, non-expired waiver record exists for that control and resource.

**Step 5: Evidence accumulates.** Every CI run contributes evidence records. The evidence record for a repository grows over time, providing a full history of its compliance state at every assessed commit.

This model has two important properties:

*Pull-based inheritance.* A new repository does not need to be "added to" the compliance system. It pulls in compliance by declaring a manifest and referencing the reusable workflows. Any update to `platform-compliance` (a new control, an updated gate criteria) flows to all repositories on their next CI run against the updated profile version.

*No opt-out.* A repository that has not declared a compliance manifest fails the merge gate by default. There is no mechanism to be on the platform without compliance governance.

---

## 6. Self-governance: the platform governing itself

`platform-compliance` declares its own compliance manifest at its root:

```yaml
repository:
  name: platform-compliance
  type: platform-repo
declared_profiles:
  - PROF-PLATFORM-V1
technology_contexts:
  - github
  - github-actions
```

This means the repository that defines the controls is also subject to them. `platform-compliance` must:
- Have branch protection enabled (SRC-001, SRC-002)
- Have no plaintext secrets (SEC-001)
- Have secret scanning enabled (SEC-002)
- Have a CODEOWNERS file (SRC-003)
- Have a README (DOC-001)
- Have ADRs for significant decisions (DOC-002)
- Produce a change record for every normative change (CHG-001)
- Have a release record for every version tag (CHG-002)

The v1.0.0 release of `platform-compliance` cannot be published until this repository passes its own release gate. That gate evaluation is the first end-to-end test of the compliance system.

---

## 7. What this platform does not claim

**This platform does not claim formal certification against any standard.** It does not hold a CIS certification, an ISO 27001 certificate, a SOC 2 report, or any equivalent formal certification. It cites registered standards as the provenance for its controls; it does not submit to a formal certification process.

**This platform does not claim full coverage of any registered standard.** A standard may be registered as `normative` and still only have a subset of its requirements mapped to controls. The mapping records document which clauses are mapped and which are not. Unmapped clauses from normative standards are gaps, not omissions; they are candidates for future controls.

**This platform does not claim that passing its compliance gates is equivalent to being "secure."** Compliance is a necessary but not sufficient condition for security. The controls represent a defensible minimum baseline. They are intended to prevent the most common and most costly failure modes, not to provide comprehensive protection against all threats.

---

## 8. What is intentionally out of scope now

The following items are explicitly not part of the current build phase. They are not deprioritized; they are sequenced. Each will be addressed after `platform-compliance` reaches its v1.0.0 release gate.

| Item | Why it comes later |
|---|---|
| Terraform modules | Implementation code that requires the compliance framework to govern it |
| Docker services | Same — runtime components governed by this framework |
| Grafana, monitoring, alerting | Operational tooling — comes after the first service is deployed |
| A self-hosted Git mirror | Requires the compliance framework to govern the mirror's own operations |
| SLO declarations and reliability controls | REL domain is defined; controls will be added in PROF-PLATFORM-V2 |
| Service catalog (CAT domain) | Requires at least one service to catalog |
| Full SLSA provenance pipeline | SLSA L3+ requires build infrastructure that does not yet exist |
| Automated dependency updates (SUP-003) | Deferred until first set of repositories is established |
| Signed commits (SRC-004) | Requires team-wide key management process (ADR needed) |
| Compliance dashboard | Requires evidence infrastructure to be operational |
| Multi-environment gate differentiation | All environments use the same profile in v1; environment-specific profiles come later |

---

*This document is the primary architecture reference for `platform-compliance`. It is updated whenever the architecture changes. Changes require a change record (CHG-001). Significant changes require an ADR (DOC-002).*
