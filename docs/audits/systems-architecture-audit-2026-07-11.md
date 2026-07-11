# Platform Systems Architecture Audit — Cross-Repo Collaboration & Silent Failures
# Date: 2026-07-11
# Author: System Architect
# Scope: platform-compliance, platform-modules, platform-infrastructure, platform-services
#        + the governance chain that binds them
# Status: DRAFT — for roadmap planning and remediation

---

## 0. Purpose

The earlier audit (`09-assessments/reports/ARCH-AUDIT-2026-07-11.md`) examined the
infrastructure layer (Terraform, services, secrets). This document examines the **system
of repositories as a whole** — how they collaborate, where the collaboration silently
fails, and how the platform deviates from its own governance model. It gives special
attention to **agent configuration governance**, which is currently the weakest link.

The goal state: a unified platform where the process runs end-to-end without silent
failures, and where every repository follows the policies to the letter.

---

## 1. The Four-Repository Architecture

```
                        ┌─────────────────────────┐
                        │   platform-compliance    │  Governance backbone
                        │  standards → controls →  │  (the "constitution")
                        │  bindings → policies →   │
                        │  profiles → gates        │
                        │  + reusable CI workflow  │
                        │  + forge CLI (scaffold)  │
                        └───────────┬─────────────┘
                                    │ consumed via
                    ┌───────────────┼───────────────┐
                    │ @vX.Y.Z ref   │               │
                    ▼               ▼               ▼
        ┌──────────────────┐ ┌──────────────┐ ┌──────────────────┐
        │ platform-modules │ │  platform-   │ │ platform-services│
        │ (terraform-      │ │infrastructure│ │   (service)      │
        │  module)         │ │(terraform-   │ │                  │
        │                  │ │  root)       │ │                  │
        └────────┬─────────┘ └──────┬───────┘ └──────────────────┘
                 │ consumed via     │ consumes modules +
                 │ ?ref=vX.Y.Z      │ deploys the platform
                 └──────────────────┘
```

**Collaboration contracts:**

| Producer | Consumer | Contract | Versioning |
|---|---|---|---|
| platform-compliance | all repos | reusable-compliance.yml workflow + policy bundle | `@vX.Y.Z` git ref in each repo's `.github/workflows/compliance.yml` |
| platform-compliance | all repos | compliance profile (gate criteria) | downloaded from release archive at CI time |
| platform-compliance/forge | new repos | scaffolded structure (agents, hooks, manifest) | one-time at repo creation |
| platform-modules | platform-infrastructure | Terraform modules | `?ref=vX.Y.Z` in module `source` |

**The critical insight:** every collaboration edge is a **version-pinned contract**, and
**none of them are automatically kept in sync.** This is the root of most silent failures
below.

---

## 2. Silent Failure Findings

Severity: 🔴 CRITICAL · 🟠 HIGH · 🟡 MEDIUM · ⚪ LOW

---

### 🔴 SF-1 — Compliance version drift: downstream repos never receive governance updates

**Evidence (2026-07-11):**

| Repo | Pins compliance | Latest available |
|---|---|---|
| platform-modules | `@v3.3.2` | `v3.3.6` |
| platform-infrastructure | `@v3.3.3` | `v3.3.6` |
| platform-services | `@v3.3.4` | `v3.3.6` |

Each repo's `.github/workflows/compliance.yml` pins the reusable workflow AND the policy
bundle to a fixed git tag (`platform-compliance-ref: v3.3.x`). When platform-compliance
publishes a new release — including the **10 new BLOCK controls and the exit-1 gate fix
just shipped in v3.3.5/v3.3.6** — the downstream repos keep using their old pinned
version. They will **never** enforce the new controls until someone manually edits the
ref in each repo.

**Why this is silent:** CI stays green on the old version. There is no signal that a
newer, stricter governance version exists. The platform *appears* governed while running
against stale rules. This is the single most important finding — it invalidates the
entire "policies followed to the letter" goal.

**Impact:** All the gate enforcement work (SEC-012/013/014, RUN-008/009, NET-002,
IAC-003b/006/007) is inert on every downstream repo. They passed their last CI runs
because their pinned version has none of these controls.

**Fix:**
1. **Immediate**: bump all three repos to `@v3.3.6` and re-run CI to surface real
   violations.
2. **Structural**: add a scheduled `compliance-version-check` job to the reusable
   workflow that compares the pinned ref against the latest release and fails (or opens
   an issue / posts a warning) when they diverge by more than N patch versions.
3. **Automated**: configure Renovate/Dependabot to open PRs bumping
   `platform-compliance-ref` when a new release is published. Pin strategy: allow patch
   auto-merge, require review for minor/major.
4. **Governance control**: add `SUP-004` (or similar) — "governed repos must track the
   compliance backbone within one minor version of latest."

---

### 🔴 SF-2 — Agent controls (AGT) run but are gated by NO profile

**Evidence:**
- 15 AGT controls exist (`03-catalogs/controls/AGT/AGT-001..015`)
- 15 AGT OPA policies exist and are wired into `run-all-policies.py` POLICY_MAP
- **Zero** AGT controls appear in ANY profile's `gates` OR `categories.mandatory`:

```
PROF-TERRAFORM-ROOT-V1:   0 AGT controls in merge_gate
PROF-TERRAFORM-MODULE-V1: 0 AGT controls in merge_gate
PROF-SERVICE-V1:          0 AGT controls in merge_gate
PROF-PLATFORM-V1:         0 AGT controls in merge_gate
```

The consequence: agent configuration policies are **evaluated** (they run and produce
pass/fail) but the gate evaluator (job 7) never treats them as blocking, because it only
reads `gates.<gate>.required_controls` with `enforcement: block`. AGT failures are
WARN-level by omission.

**This is exactly the user-reported symptom**: "agent related changes are not being made
according to the policies defined." The policies exist, they run, they even fail — but
nothing enforces them because they were never added to the gates.

**Why ADR-0017 didn't close this:** ADR-0017 ratified the AGT domain, controls, bindings,
and policies, and stated they are an "opt-in overlay." But the opt-in step — adding the
controls to each consuming profile's gate — was never completed. The overlay is defined
but not activated anywhere except partially in the compliance repo's own self-check.

**Fix:**
1. Add the AGT controls to each downstream profile's `merge_gate.required_controls` with
   `enforcement: block` and `scope_condition: "'agent' in repository.technology_contexts"`.
2. Decide the enforcement tier per control (some AGT controls like AGT-013 "agent
   learnings entry" and AGT-014 "readiness & retro" are PR-hygiene and should block;
   others like AGT-008 MCP secret scan are security and MUST block).
3. Release, then bump downstream refs (see SF-1).

---

### 🔴 SF-3 — platform-infrastructure does not declare the `agent` technology context

**Evidence:**
```
platform-infrastructure/.compliance-manifest.yaml:
  technology_contexts:
    - github
    - github-actions
    - terraform        ← no 'agent'
```
vs platform-modules and platform-services which DO list `- agent`.

Every AGT policy is context-gated on `["agent"]` in the POLICY_MAP. When a repo does not
declare the `agent` context, **all 15 AGT policies are silently marked `not_applicable`
and skipped entirely** — even though platform-infrastructure has a full `.github/agents/`
directory with 5 agents, hooks, and a copilot-instructions.md.

So the repo with agent configuration is exempt from agent governance because of one
missing line in its manifest. No error, no warning — the agents surface is simply
ungoverned.

**Fix:**
1. Add `- agent` to `platform-infrastructure/.compliance-manifest.yaml`
   `technology_contexts`.
2. Add a **manifest-completeness policy**: if a repo has `.github/agents/` OR
   `.vscode/mcp.json` OR `.github/hooks/` but does not declare the `agent` context, fail
   the gate. This prevents silent context omission from disabling governance.

---

### 🟠 SF-4 — Job 4 and Job 7 disagree on what "failure" means

**Evidence:**
- Job 4 (`run-all-policies.py`, after the v3.3.6 fix): exits 1 when **any** policy fails
  (`if failed > 0: return 1`).
- Job 7 (gate evaluator): sets `result=fail` only when a **BLOCK-listed** control fails.

These two definitions now diverge. A control that fails but is NOT in the profile's gate
(e.g. any AGT control today, per SF-2) will:
- Turn **job 4 red** (step "OPA policy checks" fails)
- Leave **job 7 green** (step "Evaluate merge_gate" passes)

The PR shows a mix of red and green compliance steps with contradictory meaning. An
operator cannot tell whether the gate actually blocked. Worse: if branch protection
requires "Compliance: Merge Gate" as a status check, the behaviour depends on which job
that check maps to.

**Root cause:** the exit-1 fix (correct for making failures visible) was applied at the
policy-runner level, but the *authoritative* gate decision lives in job 7 using profile
criteria. The two layers now encode different policies.

**Fix — pick one consistent model:**
- **Option A (recommended):** job 4 exits 1 only when a **BLOCK-level** control fails
  (read the profile, same logic as job 7). Non-blocking failures emit `::warning::` and
  keep job 4 green. This makes job 4 and job 7 agree, and the red/green signal is
  trustworthy.
- **Option B:** job 4 always exits 0 (revert), and rely solely on job 7 for the
  pass/fail decision + branch protection on job 7's check. Simpler but loses the inline
  `::error::` visibility on job 4.

Option A is preferred because it keeps failures visible AND consistent. Implementation:
`run-all-policies.py` must load the profile's gate BLOCK set (same code job 7 uses) and
only `return 1` when a block-level control failed without a waiver.

---

### 🟠 SF-5 — Agent configuration surface has drifted and is unreconciled across repos

**Evidence (agent surface inventory):**

| Repo | copilot-instructions | agents/ | instructions/ | mcp.json | hooks/ | LEARNINGS |
|---|---|---|---|---|---|---|
| platform-compliance | ✅ | 7 | 5 | ✅ | 2 | ✅ |
| platform-infrastructure | ✅ | 5 | **0** | **❌** | 2 | ✅ |
| platform-modules | ✅ | 6 | **0** | **❌** | **0** | ✅ |
| platform-services | ✅ | 6 | **0** | **❌** | 2 | ✅ |

The forge CLI scaffolds a per-repo-type agent set at creation, but there is **no
reconciliation mechanism** afterward. As a result:
- Only platform-compliance has `instructions/` files and an `mcp.json`.
- platform-modules is missing lifecycle `hooks/` entirely.
- No downstream repo has an `mcp.json`, so any AGT policy checking MCP config
  (AGT-008 secret scan) is not_applicable there — a security control silently disabled.

Because the scaffolding is one-shot, drift is guaranteed over time. Nothing detects that
a repo's agent surface no longer matches its repo-type template.

**Fix:**
1. Add an AGT control: "agent surface must match the repo-type baseline" — forge (or a
   policy) compares the actual agent files against the template manifest for the
   repo-type and fails on missing required files.
2. Provide a `forge reconcile` command that re-applies the repo-type agent template
   (additively, non-destructively) so drift can be closed with one command.
3. Decide policy intent: is `mcp.json` required for all repos or only those using MCP?
   Encode that decision so AGT-008 is either applicable everywhere or explicitly waived.

---

### 🟠 SF-6 — No registry of governed repositories; rollout is manual and lossy

**Evidence:** there is no authoritative list of which repositories consume
platform-compliance. `01-sources/registry/` holds *standards* (SRC-*), not *repos*. The
forge tool has a `cmd/registry` but it is not populated as a live inventory of governed
consumers.

**Consequence:** when a governance change ships (a new control, a gate fix, a profile
update), there is no list to drive a rollout. Each of the three (soon more) repos must be
remembered and updated by hand. This is why SF-1 (version drift) happened — nobody has a
single place that says "these 3 repos are on v3.3.2/3/4 and need v3.3.6."

**Fix:**
1. Maintain a governed-repos registry (`01-sources/registry/consumers.yaml` or a
   `forge registry` backed file) listing each repo, its declared profile, its pinned
   compliance version, and its technology contexts.
2. A scheduled workflow reconciles the registry against reality (queries each repo's
   manifest + workflow ref) and reports drift.
3. This registry becomes the driver for automated version-bump PRs (SF-1 fix #3).

---

### 🟡 SF-7 — Module version drift between platform-infrastructure and platform-modules

**Evidence:** platform-infrastructure references platform-modules at a mix of pinned tags
(v1.1.1 … v1.4.0 across different components). Each `?ref=` is updated by hand when a
module changes. There is no check that all module references in a root config point at
the same (or latest compatible) module release.

**Consequence:** a security fix to a module (e.g. the vault audit volume in v1.4.0) does
not reach a component still pinned to v1.2.1 until someone manually bumps it. Same silent
drift pattern as SF-1, one layer down.

**Fix:**
1. Add an IAC policy: "all git module refs in a root config must be within one minor
   version of each other" (or must equal a declared `module_baseline_version`).
2. Renovate rule for `git::` Terraform sources.

---

### 🟡 SF-8 — Profile duplication: same controls maintained in 4 places

**Evidence:** the audit-driven controls had to be added to `PROF-PLATFORM-V1`,
`PROF-TERRAFORM-ROOT-V1`, `PROF-TERRAFORM-MODULE-V1`, and `PROF-SERVICE-V1` separately.
There is no inheritance/composition — each profile restates the full control + gate list.

**Consequence:** it is easy to add a control to one profile and forget the others — which
is precisely how SF-2 happened (controls added to PROF-PLATFORM-V1 only). Profiles drift
apart silently.

**Fix:**
1. Introduce profile composition: `PROF-BASE` defines universal controls; specific
   profiles `extends: PROF-BASE` and add only their deltas. The gate evaluator resolves
   the inheritance.
2. Alternatively, a lint that verifies a defined "core control set" appears in every
   profile.

---

### 🟡 SF-9 — collect-terraform-info.sh runs terraform init/validate in CI without network guarantees

**Evidence:** the collector runs `terraform init -backend=false` then `validate` to
produce the IAC-001 signal. Module sources are `git::https://…` — if the CI runner cannot
reach GitHub (rate limit, outage, private repo without token), init fails, validate
reports invalid, and IAC-001 fails for reasons unrelated to the code under review. The
recent `|| true` and binary-order fixes reduced but did not eliminate this fragility.

**Fix:** cache the module downloads or vendor them; distinguish "validate failed because
code is invalid" from "validate could not run" (the latter should be `manual_review` or
`error`, not `fail`).

---

### ⚪ SF-10 — AGENT_LEARNINGS.md is per-repo and drifts; cross-repo lessons are lost

**Evidence:** each repo has its own `AGENT_LEARNINGS.md` (33–37 lines, diverging content).
A lesson learned while working in platform-modules (e.g. the `nonsensitive() for_each`
fix) is not visible to an agent working in platform-infrastructure.

**Consequence:** the same mistake can be re-learned in each repo. The compliance repo's
learnings (the richest) are not shared downstream.

**Fix:** designate platform-compliance's `AGENT_LEARNINGS.md` (or a dedicated
`docs/agent-playbook.md`) as the canonical cross-repo lessons file, referenced by every
repo's copilot-instructions. Keep repo-local learnings for repo-specific facts only.

---

## 3. Agent Governance — Deep Dive (the user's primary concern)

The user observed that "agent related changes are not being made according to the
policies defined." The evidence explains exactly why, in a chain of three compounding
silent failures:

```
ADR-0017 defines AGT domain, 15 controls, 15 policies, bindings
        │
        ├─ ✅ Controls authored (03-catalogs/controls/AGT/*)
        ├─ ✅ Policies authored + wired into POLICY_MAP (they RUN)
        │
        ├─ 🔴 SF-2: NOT added to any profile's gate
        │        → AGT failures never block the gate (job 7)
        │
        ├─ 🔴 SF-3: platform-infrastructure omits 'agent' context
        │        → all 15 AGT policies not_applicable there (skipped)
        │
        └─ 🟠 SF-5: agent surface drift (no mcp.json downstream)
                 → AGT-008 (MCP secret scan) not_applicable → security gap
```

**Net effect:** an agent can change `.github/agents/`, `copilot-instructions.md`, hooks,
or MCP config in any downstream repo and **no gate stops a non-compliant change.** The
governance exists on paper (ADR-0017) and in policy files, but the enforcement path from
policy → gate → PR block is broken at every join.

**The fix is a single coherent activation sequence:**
1. Add `- agent` context to platform-infrastructure manifest (SF-3).
2. Add AGT controls to all three downstream profiles' gates with the correct enforcement
   tier and `agent`-context scope condition (SF-2).
3. Reconcile the agent surface so `mcp.json` / hooks / instructions exist where the
   policy expects them, or explicitly waive where not (SF-5).
4. Make job 4 / job 7 agree so AGT block failures visibly block (SF-4).
5. Bump downstream compliance refs so the above actually ships (SF-1).

Only when all five are done will an agent-config change be governed end-to-end.

---

## 4. Systemic Root Cause

Every finding above is a variant of one structural problem:

> **The platform's collaboration contracts are version-pinned but not version-managed.**

Pinning is correct (it gives reproducibility). The missing half is a **propagation and
reconciliation layer**: something that knows what the current versions are, what the
latest versions are, and drives the gap to zero — for compliance refs, module refs,
profiles, and agent surfaces alike.

Without it, the platform silently runs on whatever version each repo happened to pin last,
and governance improvements never reach the repos they were written for.

---

## 5. Remediation Roadmap (priority-ordered)

**P0 — Restore actual enforcement (do first, this week)**
1. SF-3: add `agent` context to platform-infrastructure manifest.
2. SF-2: add AGT controls to the 3 downstream profiles' gates.
3. SF-4: make job 4 use BLOCK-level logic so it agrees with job 7.
4. SF-1: bump all downstream repos to `@v3.3.6` (or the release containing 1–3) and
   triage the real violations that surface.

**P1 — Prevent recurrence (this month)**
5. SF-6: create the governed-repos registry.
6. SF-1: automated compliance-ref bump PRs (Renovate) driven by the registry.
7. SF-1: `compliance-version-check` job that warns/fails on stale pins.
8. SF-5: `forge reconcile` + agent-surface baseline policy.

**P2 — Reduce structural fragility (this quarter)**
9. SF-8: profile composition (extends/base) to kill duplication.
10. SF-7: module-ref consistency policy + Renovate for `git::` sources.
11. SF-9: robust terraform validate (cache modules, distinguish can't-run from invalid).
12. SF-10: canonical cross-repo agent playbook.

**P3 — Maturity**
13. A single "platform status" dashboard: every repo, its pinned versions, its gate
    results, its drift — the operational view that currently does not exist.

---

## 6. Definition of Done for "no silent failures"

The platform meets its goal when all of the following are continuously true and machine-
verified:

- [ ] Every governed repo is within one minor version of the latest compliance release.
- [ ] Every profile contains the full core control set (no drift between profiles).
- [ ] Every repo with an agent surface declares the `agent` context AND is gated by AGT
      controls.
- [ ] Job 4 and job 7 always agree on pass/fail.
- [ ] A governed-repos registry exists and a scheduled job proves it matches reality.
- [ ] Module refs within a root config are version-consistent.
- [ ] Adding a control to the core set automatically applies to all consuming profiles.

Until these hold, the platform can appear green while silently running on stale, partial,
or unenforced governance — which is the exact failure mode this audit documents.
