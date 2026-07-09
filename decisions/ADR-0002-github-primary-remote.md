# ADR-0002: GitHub is the primary and initial root-of-trust remote

| Field | Value |
|---|---|
| **ID** | ADR-0002 |
| **Status** | accepted |
| **Date** | 2026-07-08 |
| **Deciders** | platform-team |

---

## Context

The platform requires a canonical location for source code that serves as the root of trust for all compliance controls that operate at the repository layer. Controls SRC-001 (branch protection), SRC-002 (pull requests required), and SEC-002 (secret scanning) all depend on features provided by the hosting platform.

The platform's long-term direction includes a self-hosted Git server as a potential mirror or alternative. The question is: **which system is the root of trust for source code, and when?**

We have considered three options:

**Option A — Self-hosted Git only.** All source code is hosted on a self-hosted Gitea or equivalent from the start. This aligns with the self-hosted philosophy but requires the Git server to be set up and governed before any code exists — a bootstrapping paradox.

**Option B — GitHub only.** All source code is hosted on GitHub as the permanent canonical location. Simple and well-understood, but creates a dependency on an external SaaS service.

**Option C — GitHub initially; self-hosted mirror later.** GitHub is the canonical, root-of-trust remote for source code. A self-hosted Git server may be introduced later as a mirror for resilience or specific use cases, but the mirror is never the root of trust unless a future ADR explicitly changes this.

The bootstrapping paradox with Option A is the decisive factor: a self-hosted Git server requires governance to operate correctly, and that governance requires `platform-compliance`, which requires a place to live. The compliance framework must exist before the self-hosted Git server it would govern.

Additionally, GitHub provides the compliance features we depend on (branch protection API, secret scanning, CODEOWNERS, Actions) without requiring additional infrastructure to be stood up and secured first.

---

## Decision

**We adopt Option C: GitHub is the primary and initial root-of-trust remote.**

All platform source code is hosted on GitHub as the canonical location. GitHub branch protection and GitHub Actions serve as the technical enforcement layer for all SRC, SEC, and workflow controls.

A self-hosted Git mirror may be introduced after `platform-compliance` reaches v1.0.0 and the mirror can itself be governed by the compliance framework. The mirror will never be the authoritative source without a superseding ADR.

---

## Consequences

**Positive:**

- No bootstrapping paradox. The compliance framework can be built before any self-hosted infrastructure exists.
- GitHub's branch protection, secret scanning, CODEOWNERS, and Actions are mature, well-documented, and directly testable by the policy checks planned for Phase 7.
- The platform can begin accumulating evidence and assessment reports immediately, without waiting for self-hosted infrastructure.

**Negative / trade-offs:**

- The platform has a dependency on GitHub, an external SaaS service. If GitHub is unavailable or its pricing/terms change materially, migration is required.
- Some platform principles (self-hosted, reproducible) create tension with relying on an external service. This tension is accepted as a bootstrap necessity.

**Constraints introduced:**

- All SRC domain controls, SEC-002, and workflow controls are designed for the GitHub context. If the root-of-trust remote changes, those bindings and policies must be rewritten for the new platform.
- The self-hosted Git server, when introduced, must not be configured as a deployment target for code without first passing the compliance gates defined in `platform-compliance`.
- Any workflow that pushes code or modifies repository settings must use GitHub's API and GitHub Actions. Direct SSH pushes to main from CI scripts are prohibited by SRC-001 and SRC-002.

---

## Relation to platform principles

This ADR ratifies Platform Principle P9 (GitHub is the initial root of trust for source code). See [../platform-principles.md](../platform-principles.md).
