# Agent Learnings & Improvements Ledger

This ledger records how the repository's AI coding agents evolve — the meaningful updates to
their profiles, instructions, and configuration, and the knowledge that improves their working
efficiency over time. It is governed by **AGT-013**: every pull request must add an entry here,
so the agent team is continuously, verifiably improving.

Add a new dated entry at the top for each change. Describe *what improved* and *why it makes the
agents more effective* — not just what files changed.

---

## 2026-07-10 — Relocated the learnings ledger out of .github/agents/

- Moved this ledger from `.github/agents/LEARNINGS.md` to `.github/AGENT_LEARNINGS.md`. VS Code
  registers *any* `.md` file in `.github/agents/` as a custom agent, so the ledger was surfacing
  as a bogus "LEARNINGS" entry in the agent picker — noise that made the real specialist team
  harder to navigate. The ledger now lives one level up, outside the agent-scan folder.
- Updated `collect-agent-info.py` so `LEDGER_CANDIDATES` no longer recommends any
  `.github/agents/*` path; it now points only at `.github/AGENT_LEARNINGS.md` and
  `docs/agent-learnings.md`. Downstream repos that copy this pattern won't reintroduce the
  stray-agent problem.
- Efficiency gain: the agent picker shows only genuine agents, and the AGT-013 ledger stays
  discoverable at a clean, conventional location without polluting the agent roster.

## 2026-07-10 — Downstream agent adoptability (AGT-015)

- Turned the team-discovery settings into a **proper governed control (AGT-015)**: any repository
  with custom agents must commit `.vscode/settings.json` enabling `chat.agentFilesLocations`, so
  new downstream repos get a discoverable agent team on first clone. Added a copy-paste template
  (`templates/agent-vscode-settings.template.json`) so adoption is immediate.
- Learned: enforcing setup (a control) and enabling setup (a template) are complementary — a
  blocking control without a one-step remediation just frustrates adopters, so the two ship
  together. The control is context-gated and `not_applicable` when a repo has no agents.
- Efficiency gain: onboarding a new downstream repository to the agent operating layer is now a
  template copy plus a gate that confirms it, rather than tribal knowledge.

## 2026-07-10 — Team-wide agent discoverability (workspace settings)

- Committed `.vscode/settings.json` with `chat.agentFilesLocations: { ".github/agents": true }`
  so every team member's VS Code explicitly scans the agent team, regardless of their personal
  defaults. `.github/agents` is already a default location in current VS Code, so this is an
  explicit, documented guarantee for the whole team rather than a behavior change.
- Learned: in VS Code, custom agents are the current form of what were once "custom chat modes"
  (`.chatmode.md` is the deprecated format — do NOT convert). Agents surface in the **agents
  dropdown**; when they don't appear, the authoritative diagnosis is the Chat **Diagnostics**
  view (right-click in Chat) which lists every loaded agent and any load error, plus the
  **Configure Custom Agents** menu (`/agents`) whose per-agent eye icon can hide/show them.
- Efficiency gain: the specialist team is discoverable by default for everyone who clones the
  repo, and the troubleshooting path is now recorded for the next person.

## 2026-07-10 — Stringent agent-quality + self-improvement controls (ADR-0017 A2)

- Promoted the agent-effectiveness controls to **blocking** and expanded them to a 12-control
  suite (AGT-001…012): description quality, least-privilege tools, instruction scoping,
  pre/post-flight discipline, safety-hook integrity, routing, per-agent role/constraints,
  MCP trust/pinning, and repository-instruction completeness.
- Added **AGT-013** (every PR records an improvement in this ledger) and **AGT-014** (every PR
  completes a readiness check + retro before merge) to make the agent team *ever-improving*.
- Added `tools/check-agents.sh` so the whole suite can be run locally and fails loudly before push.
- Efficiency gain: agents now have a machine-checked, high bar for their own configuration, and a
  standing habit of recording what they learned each cycle.

## 2026-07-10 — Agent configuration governance foundations (ADR-0017 A1)

- Introduced the `AGT` domain, the `agent` context, four standards, and the first three controls
  (single-sourced instructions, valid frontmatter, secret-free MCP). platform-compliance began
  self-governing its own agent operating layer.
- Efficiency gain: the agent surface future repositories copy is now continuously validated.

## 2026-07-10 — Agent operating layer established

- Created the specialist agent team (router + six specialists), file-scoped instructions, MCP
  configuration, and a PreToolUse safety hook, with universal pre-flight/post-flight checklists.
- Efficiency gain: work is routed to the right specialist with least-privilege tools and a
  deterministic safety backstop.

---

## AGT-LEARNING-001 — ADR-0016 P2: Schema ID pattern constraints affect standard source naming

**Date:** 2026-07-10  
**Phase:** ADR-0016 P2 (Go service controls)  
**Change Record:** CHG-20260710-011

### What happened
When registering the OpenTelemetry standard source as `SRC-OPENTELEMETRY`, the schema
validation failed because the `standard-source.schema.json` ID pattern `^SRC-[A-Z0-9]+-[A-Z0-9-]+$`
requires at least two hyphen-delimited segments after `SRC-`. A single word like `OPENTELEMETRY`
only produces one segment. The ID was corrected to `SRC-CNCF-OTEL` (vendor prefix + short name).

### Learning
Before naming a new standard source, verify the ID satisfies the pattern
`^SRC-[A-Z0-9]+-[A-Z0-9-]+$` — it requires at minimum `SRC-{WORD1}-{WORD2}`.
Single-word issuer names like `OPENTELEMETRY`, `DOCKER`, `GOLANG` must be prefixed with
an issuer/org abbreviation or split: `SRC-CNCF-OTEL`, `SRC-DOCKER-CIS`, `SRC-GO-STYLE`.

### Agent config improvement
Added this rule to the control-author mental checklist. Before registering a standard source:
1. Check the schema ID pattern
2. Use format `SRC-{ORG/ISSUER}-{STANDARD}` — at least two hyphen-separated components after `SRC-`
3. For well-known single-name standards, prefix with the owning org (CNCF, NIST, OWASP, etc.)
