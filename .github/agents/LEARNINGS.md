# Agent Learnings & Improvements Ledger

This ledger records how the repository's AI coding agents evolve — the meaningful updates to
their profiles, instructions, and configuration, and the knowledge that improves their working
efficiency over time. It is governed by **AGT-013**: every pull request must add an entry here,
so the agent team is continuously, verifiably improving.

Add a new dated entry at the top for each change. Describe *what improved* and *why it makes the
agents more effective* — not just what files changed.

---

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
