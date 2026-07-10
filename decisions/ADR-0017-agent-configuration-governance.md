# ADR-0017: Agent Configuration Governance

| Field | Value |
|---|---|
| **ID** | ADR-0017 |
| **Status** | accepted |
| **Date** | 2026-07-10 |
| **Deciders** | platform-team |

---

## Context

The platform is built and operated with AI coding agents, and (per ADR-0016 tooling) now ships
a full agent operating layer: repository instructions (`.github/copilot-instructions.md`), a
custom agent team (`.github/agents/`), file instructions (`.github/instructions/`), an MCP
server configuration (`.vscode/mcp.json`), and lifecycle hooks (`.github/hooks/`). Every future
governed repository will carry the same surface.

Yet the compliance backbone had **no standard, control, or gate for agent configuration**. Two
consequences followed:

1. **Inconsistency** — without controls, each repository would configure its agents differently,
   and there would be no shared definition of a correct or effective setup.
2. **Security exposure** — a hardcoded token in `.vscode/mcp.json`, or a malformed MCP config,
   would pass the compliance gate silently. Agent configuration is part of the software supply
   chain and must be governed like the rest of it.

The platform was, in effect, using agents to build governance while leaving agent configuration
ungoverned. ADR-0017 closes that contradiction.

---

## Decision

Govern agent configuration along the existing chain (standards → controls → bindings → policies
→ profiles → gates), introduced as an opt-in overlay, with platform-compliance self-governing it
from day one. The following are ratified:

### 1. One new control domain: `AGT` (Agent Governance)

A single cohesive domain (the platform's 21st) covers both the *setup* and the *effective usage*
of agent configuration. Setup and usage are two facets of one concern and are not split into
separate domains.

### 2. One new technology context: `agent`

A repository carries the `agent` context when it ships any agent configuration. The context is
**opt-in** initially (like `go`), declared in the repository manifest. Intent: fold the
structural controls into the universal baseline at v2.0.0 once adoption is broad.

### 3. Four registered standards

| ID | Source | Role |
|---|---|---|
| `SRC-VSCODE-AGENT-CUSTOMIZATION` | VS Code Copilot customization docs | normative |
| `SRC-AGENTS-MD` | AGENTS.md open standard | adopted |
| `SRC-MCP-SPEC` | Model Context Protocol specification | normative |
| `SRC-PLATFORM-AGENT-CONVENTIONS` | Internal house conventions | normative |

### 4. Control set (9 controls, phased)

**Setup / structure / security — block immediately (phase A1):**

| Control | Requirement |
|---|---|
| AGT-001 | Repository agent instructions present and single-sourced (copilot-instructions.md XOR AGENTS.md) |
| AGT-002 | Every `.agent.md` / `.instructions.md` / `.prompt.md` has valid frontmatter + a description |
| AGT-003 | MCP configuration is valid JSON and contains no hardcoded secrets |

**Effective usage / quality — warn, then block at v2.0.0 (phase A2):**

| Control | Requirement |
|---|---|
| AGT-004 | Keyword-rich descriptions on agents and instructions |
| AGT-005 | Least-privilege agent tools (read-only/review agents must not hold `edit`) |
| AGT-006 | Instruction scoping hygiene (`applyTo` present, `"**"` discouraged) |
| AGT-007 | Pre-flight / post-flight discipline in repository instructions |
| AGT-008 | A `PreToolUse` safety hook guarding irreversible operations |
| AGT-009 | A coordinator/router agent when multiple specialist agents exist |

### 5. Enforcement ramp

AGT-001/002/003 block immediately (structural correctness and secret exposure cannot be phased
in gradually). AGT-004…009 land as `warn` and are promoted to `block` at v2.0.0, consistent with
ADR-0016's MAJOR-release migration window.

### 6. Opt-in overlay profile: `PROF-AGENTIC-V1`

A repository declares `PROF-AGENTIC-V1` in addition to its primary profile. The AGT controls are
kept out of `PROF-BASE` for now (like ADR-0016's language controls); they fold into `PROF-BASE`
at v2.0.0 once agent configuration is universal.

### 7. Python collector (`collect-agent-info.py`)

Agent facts require parsing YAML frontmatter and JSON, so the collector is Python (stdlib-only,
with best-effort PyYAML) rather than bash. It scans instructions, customization-file frontmatter,
MCP config (with a secret scan of `.vscode/mcp.json` only), hooks, and the agent roster.

### 8. Dogfooding — platform-compliance self-governs

platform-compliance declares the `agent` context and `PROF-AGENTIC-V1`, and its self-compliance
workflow runs AGT-001/002/003 against its own agent operating layer. It is the first repository to
be governed by these controls, and it passes them.

---

## Consequences

- The exact files future repositories will copy (the platform's own agent operating layer) are
  now continuously validated for structure and secret-safety.
- New governed repositories get a consistent, secure agent-configuration baseline by declaring
  the `agent` context.
- A hardcoded credential in an MCP config now fails the gate instead of shipping silently.
- Additional surface to maintain (one domain, one context, four standards, nine controls across
  two phases), accepted as proportionate to the risk.

---

## Rollout

Three phases, each independently shippable and self-governing, tracked in
`docs/implementation/tasks/v4-agent-governance.yaml`:

- **A1 — Foundations (v1.4.0)**: domain, context, standards, collector, AGT-001/002/003 (block),
  `PROF-AGENTIC-V1`, platform-compliance self-governance.
- **A2 — Effectiveness (v1.5.0)**: AGT-004…009 (warn) + collector signals + policies.
- **A3 — Baseline (v2.0.0)**: promote AGT-004/005/006 to block; fold AGT-001/002/003 into
  `PROF-BASE` so every repository is covered.

This ADR is sequenced **before** ADR-0016 Phase 2 (Go service tier): the agent operating layer
was just built, so governing it while it is fresh — and self-dogfooding — hardens the reference
implementation immediately.

---

## Amendment 2026-07-10 — A2 made stringent and expanded (v1.5.0)

Per a stakeholder directive to hold agent configuration to a very high, loudly-enforced bar,
Phase A2 is amended:

- **Enforcement promoted from `warn` to `block`.** All A2 controls fail the merge and release
  gates immediately; there is no grace period. (Decision 5 is superseded for the A2 controls.)
- **Control set expanded from six to eleven.** In addition to AGT-004 (description quality),
  AGT-005 (least-privilege tools), AGT-006 (scoping), AGT-007 (pre/post-flight), AGT-008 (safety
  hook), and AGT-009 (routing), three quality controls are added — **AGT-010** (per-agent role +
  constraints), **AGT-011** (MCP server trust & version pinning), **AGT-012** (repository-
  instruction completeness) — plus two continuous-improvement controls:
  - **AGT-013** — every pull request must record a meaningful improvement in an agent learnings
    ledger (`.github/agents/LEARNINGS.md`), keeping the agents ever-improving.
  - **AGT-014** — every pull request must contain a completed readiness check and a retrospective
    before it may merge.
- **AGT-008 strengthened** to verify the guard's hook scripts exist and are executable.
- **`PROF-AGENTIC-V1` bumped to v2.0.0**: all twelve setup/effectiveness controls plus the two
  improvement controls are mandatory and block at the merge gate.
- **New artifacts**: `tools/check-agents.sh` (offline "fail loudly" runner for the whole AGT
  suite), `.github/agents/LEARNINGS.md` (the ledger), and `.github/pull_request_template.md`
  (readiness + retro section). The collector gains PR context (changed files + PR body) via
  environment variables so it stays offline and stdlib-only.

A3 remains: fold the structural controls into `PROF-BASE` at v2.0.0. The promotion of A2 to block
is already complete, so A3's promotion step now applies only to the eventual `PROF-BASE` merge.
