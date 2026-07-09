# ADR-0016: Application and Code Quality Governance Expansion

| Field | Value |
|---|---|
| **ID** | ADR-0016 |
| **Status** | accepted |
| **Date** | 2026-07-10 |
| **Deciders** | platform-team |

---

## Context

The platform compliance backbone at ratification time had **41 controls across 16 domains**, but coverage clustered into source control & supply chain (SRC, SUP, CHG, LIC), security & access (SEC, ACC, AUD, NET), and infrastructure & runtime (IAC, RUN, BAK). There was **no governance for application code**: no code-quality controls, no testing controls, no API-contract controls, no code-organization controls, and only partial telemetry coverage (metrics and logs, but no distributed tracing).

The platform was **language-blind**. Its only application-facing repository type was the generic `service`, and its only technology contexts were `github`, `terraform`, `docker`, `runtime-linux`, and `github-actions`. There was no way to express language-specific requirements for Go, Node/TypeScript, Python, or browser frontends. When application repositories are onboarded, the compliance gate would pass them with **zero code-quality enforcement**.

The full analysis and options are recorded in the proposal at `docs/implementation/decisions-needed/ADR-0016-application-quality-governance.md`.

---

## Decision

Expand the platform along four axes — **new technology contexts, new control domains, new standards, and new language-specific profiles** — rolled out in five independently-shippable phases (Go first). The following architectural decisions are ratified:

### 1. Four new control domains (all separate)

| Domain | Name | Scope |
|---|---|---|
| **QUA** | Code Quality | Linting, formatting, build/compile success, static type checking |
| **TST** | Testing | Test presence, execution in CI, coverage thresholds, integration tests |
| **API** | API Contract | OpenAPI specification, versioning strategy, breaking-change detection |
| **ARC** | Architecture & Code Organization | Project layout, module ownership boundaries, dependency-direction rules |

The domains are kept separate (not folded) because each is cohesive and independently evolvable. This brings the platform to 20 domains.

### 2. Four new technology contexts

`go`, `node` (Node.js / TypeScript), `python`, and `frontend` (browser web apps) are added to `02-taxonomy/technology-contexts.yaml`. A repository may carry several contexts simultaneously (e.g. a Go backend also carries `docker` and `github-actions`).

### 3. New repository type: `frontend-app`

A browser-facing web application is materially different from a backend `service` (no health endpoint in the same sense, different security surface — CSP, bundle-size budget, no production source maps). `frontend-app` is added to `02-taxonomy/repository-types.yaml` and governed by `PROF-FRONTEND-V1`.

### 4. Test coverage threshold

TST-002 enforces a **minimum test coverage of ≥70%**. This is the single control that ramps gradually: it lands as `warn` and promotes to `block` after a grace period, consistent with ADR-0010's MAJOR-release migration window.

### 5. Enforcement ramp

All other new code-quality controls (QUA-001/002/003/004 lint/format/build/type-check, TST-001 test-existence, TST-003 integration test, API, ARC, OBS-004) **block immediately** upon activation in a profile. Only the coverage *percentage* (TST-002) is graduated per decision 4. Rationale: linting, formatting, build success, type-checking, and the mere existence of tests can be enforced hard from day one; only the coverage percentage requires time to accumulate in an existing codebase.

### 6. Profile architecture (application-shaped)

A language layer is added beneath `PROF-SERVICE-V1`, plus new frontend and library branches:

```
PROF-BASE
├── PROF-TERRAFORM-MODULE-V1 → PROF-TERRAFORM-ROOT-V1
├── PROF-SERVICE-V1
│   ├── PROF-GO-SERVICE-V1
│   ├── PROF-NODE-SERVICE-V1
│   └── PROF-PYTHON-SERVICE-V1
├── PROF-FRONTEND-V1
└── PROF-LIBRARY-V1
```

A 3-level inheritance chain (BASE → SERVICE → GO-SERVICE) is accepted. The generic `service` profile remains valid; language profiles are opt-in refinements.

### 7. Extensions to existing domains

| Control | Domain | Requirement |
|---|---|---|
| OBS-004 | OBS | OpenTelemetry distributed tracing instrumentation |
| SRC-005 | SRC | Conventional Commits message format |
| SUP-005 | SUP | Committed dependency lockfile (go.sum, package-lock.json, poetry.lock) |
| DOC-003 | DOC | Service runbook / operational README section |

### 8. New standards

To be registered as motivating sources: Go style (Effective Go + Uber Go Style), TypeScript style (Google TS Style + ESLint), Python (PEP 8/257/484), OpenAPI 3.1, OpenTelemetry, Conventional Commits 1.0.0, The Twelve-Factor App, Google Engineering Practices, Content Security Policy (MDN/OWASP), and WCAG 2.2.

### 9. Phased rollout (Go first)

| Phase | Deliverable |
|---|---|
| **P1 — Foundations** | Register contexts, domains, standards; QUA + TST controls for Go |
| **P2 — Go service** | ARC, API, OBS-004, SRC-005, SUP-005; `PROF-GO-SERVICE-V1` |
| **P3 — Node + Python** | Extend QUA/TST/ARC bindings; `PROF-NODE-SERVICE-V1`, `PROF-PYTHON-SERVICE-V1` |
| **P4 — Frontend** | Frontend security (CSP, bundle budget), a11y; `PROF-FRONTEND-V1`, `frontend-app` type |
| **P5 — Library** | Reuse QUA/TST, relax RUN/NET/OBS; `PROF-LIBRARY-V1` |

Each phase passes its own merge gate before the next begins, per ADR-0003.

---

## Consequences

- Adds 4 domains, 4 technology contexts, 1 repository type, ~11 standards, ~17 controls, and 4–5 profiles over 5 phases.
- Makes the platform capable of governing application repositories (Go, Node, Python, frontend), not just infrastructure.
- Language-specific data collectors (`collect-go-info.sh`, `collect-node-info.sh`, `collect-python-info.sh`, `collect-frontend-info.sh`) are the largest engineering effort and must be built per phase.
- Total platform size after full rollout: ~20 domains, ~58 controls — remaining maintainable because domains are cohesive.
- **Implementation is deliberately paused after this ratification.** The decision is accepted; building Phase 1 is a separate, subsequent step to be scheduled explicitly.

---

## Follow-up ADRs anticipated

- A future ADR may define the **canonical project layout per language** (referenced by ARC-001) if the standard style guides prove insufficient.
- A future ADR may address **monorepo governance** (multiple contexts/languages in one repository) if that pattern emerges.
