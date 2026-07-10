# Agent Learnings & Improvements Ledger

This ledger records how the repository's AI coding agents evolve — the meaningful updates to
their profiles, instructions, and configuration, and the knowledge that improves their working
efficiency over time. It is governed by **AGT-013**: every pull request must add an entry here,
so the agent team is continuously, verifiably improving.

Add a new dated entry at the top for each change. Describe *what improved* and *why it makes the
agents more effective* — not just what files changed.

---

## AGT-LEARNING-004 — ADR-0016 P4 Frontend controls + TST-002 block promotion (2026-07-10)

**Date:** 2026-07-10 | **Change Record:** CHG-20260710-015
**Tag:** v2.0.0 (MAJOR) | **Covers:** ADR-0016 P4 Frontend (SEC-009/010/011), TST-002 block promotion, `warn` OPA result formalisation

P4 delivered SEC-009/010/011 (CSP, source maps, bundle budget) for the frontend context.
The Compliance Reviewer correctly blocked on missing fixture files and an undocumented `warn`
result value — both fixed before merge, proving the review chain works.

TST-002 promoted from warn → block at v2.0.0 per ADR-0016 decision 4; all three language
profiles (Go, Node, Python) and their TST-002 bindings updated.

`warn` is now a formally documented OPA result value in README.md and opa-policies.instructions.md.

**Agent improvement:** policy-engineer instructions should note that inline fixture runs during
authoring do NOT substitute for on-disk fixture files — the reviewer checks for the files
themselves, not just correct logic.

---

## AGT-LEARNING-003 — Full session retro: v1.7.0–v1.9.0 (2026-07-10)

**Date:** 2026-07-10 | **Change Records:** CHG-20260710-011 through CHG-20260710-014
**Tag span:** v1.7.0 → v1.9.0 | **Covers:** ADR-0016 P2+P3, agent handoff protocol, AGT-014 enforcement

### AGT-014 Readiness Check
- [x] AGT suite passes (`tools/check-agents.sh`) — 15/15 pass
- [x] All 7 agent files updated with retro-driven improvements
- [x] Pre-flight / post-flight checklists accurate and improved

### Full Retrospective

**What went well:**
- The Compliance Reviewer correctly caught the missing `evidence_type` registrations mid-chain (P3), routed back to Control Author, and blocked the merge — exactly what it should do.
- The specialist chain worked end-to-end for P3 (Control Author → Collector Engineer → Policy Engineer → Compliance Reviewer → fix loop → Release Manager) with real handoff blocks carrying context forward.
- The `collect-agent-info.py` collector architecture (env-var PR context, scoped section detection) proved sound — once the regex was fixed, it correctly distinguished real retros from placeholders.

**What was harder than expected:**
- The router executed all P2 work itself in the first attempt instead of delegating to specialists. Root cause: instructions lacked explicit "never self-execute" and one-agent-at-a-time rules. Fixed by the handoff protocol.
- AGT-014 retros were skipped in two consecutive merges (v1.7.0, v1.7.1) before the user called it out. The release-manager had no enforcement gate; it was added as pre-flight steps 4–6.
- `pr_has_retro` had a false-positive: the regex matched `- [x] checkbox text` as "retro bullets" because it searched for any bullet after any occurrence of the word "retro" rather than scoping to the `**Retrospective**` subsection. Required two iterations to fix correctly.
- Task file horizons were stale after agent governance work displaced P2–P5 version targets. No agent owned this check; added to release-manager pre-flight step 6.

**Agent instruction changes made this session (what improved and why):**

| Agent | Change | Why |
|-------|--------|-----|
| `compliance-router` | Added `## Pre-flight` block (verify branch before delegating), Step 6 AGT gate, delegation rule 7 (AGT gate is mandatory) | Router was skipping AGT check before release-manager; branch not always created first |
| `control-author` | Pre-flight step 4: register `evidence_type` before handoff; HANDOFF block now includes "Evidence types registered" field | Compliance Reviewer blocked P3 for unregistered types; fixing mid-chain costs more than preventing upfront |
| `collector-engineer` | Pre-flight step 2: `collect-all-inputs.py` dispatch is mandatory (not implied); post-flight: scoped regex warning for `collect-agent-info.py` modifications | Both were implicit; made them explicit to prevent regressions |
| `compliance-reviewer` | Approach step 2: explicit `evidence_type` check against `evidence-types.yaml` for every `*.check.yaml` in scope | Was not a named check; added so it is never skipped |
| `release-manager` | Pre-flight steps 4–6: AGT-013 ledger, AGT-014 retro (must be genuine prose, not checkbox re-statements), task file horizons | Three merges skipped these gates before the enforcement was written |
| `collect-agent-info.py` | `pr_has_retro`: scoped to `**Retrospective**` subsection; excludes `- [` checkbox lines; `pr_has_readiness`: scoped to Agent Readiness section | False positives caused incorrect gate passes |
| `copilot-instructions.md` | Added `## Agent operating rules (MANDATORY)` with 5 hard rules: 7 agents only, maximize involvement, router coordinates, HANDOFF protocol, ordering enforced | Session started without these rules; router violated all of them in the first P2 attempt |



**Date:** 2026-07-10
**Change Record:** CHG-20260710-014

### What happened
The `pr_has_retro` check in `collect-agent-info.py` was matching bullet text inside checkbox
lines (e.g., `- [x] release-manager now verifies ...`) as "retro content", because the regex
searched for any non-empty line after a `Retrospective` heading without excluding `- [` prefixes.
This caused the AGT-014 gate to pass even when no genuine retrospective narrative was present —
a PR with only checkboxes and no prose would appear compliant.

Additionally, the detection was scanning the entire PR body rather than scoping to the
`**Retrospective**` subsection, so a stray retro-like sentence anywhere in the body would pass.

### Fix
Regex now anchors to the `**Retrospective**` subsection heading and requires at least one line
that does **not** start with `- [` (i.e., not a checkbox). The `pr_has_readiness` check was
aligned to the same scoped pattern.

### Agent config improvement
Release-manager pre-flight now explicitly states: "confirm the retro is a genuine prose
narrative, not just checkbox re-statements." Collector-engineer instructions note the scoped
detection pattern so future regex updates stay anchored to subsection headings.

 (ADR-0016 P2 + P3 + agent handoff protocol)

**Agent Readiness Check (AGT-014):**
- [x] AGT suite passes locally (`tools/check-agents.sh`) — all 15 controls pass
- [x] New conventions (handoff protocol, specialist ordering) reflected in all 7 agent files
  and `copilot-instructions.md`
- [x] Pre-flight / post-flight checklists updated (control-author, collector-engineer,
  compliance-reviewer, release-manager) based on session retro findings

**Retrospective — what this session taught us and what changed:**

1. **Router self-execution (original problem → fixed)**
   The router was invoked as a single subagent for P2 and did all the work itself, defeating
   the multi-specialist model. Root cause: the router's instructions did not mandate sequential
   single-agent delegation with HANDOFF blocks. Fixed by adding `## Agent operating rules` to
   `copilot-instructions.md` and rewriting `compliance-router.agent.md` with explicit delegation
   rules, the inter-agent handoff protocol, and a template for prompting each specialist.
   *All 7 agent files now carry a typed `## HANDOFF` output section.*

2. **Evidence type registration gap (caught at review → control-author pre-flight updated)**
   P3 node/python policies used `evidence_type` values (`node-quality`, `node-testing`, etc.)
   that were not registered in `08-evidence/evidence-types.yaml`. The compliance-reviewer
   blocked the chain and routed back to control-author. A pre-existing P1 gap (`go-quality`,
   `go-testing`) was also caught and back-filled.
   *Control-author pre-flight now has an explicit step 4: register all evidence_type values
   before handing off. Compliance-reviewer approach now lists evidence-type check as step 2.*

3. **collect-all-inputs.py dispatch was implicit (collector-engineer clarified)**
   The collector-engineer correctly updated `collect-all-inputs.py` for new contexts, but this
   responsibility was not explicit in the instructions.
   *Collector-engineer pre-flight step 2 now states: "adding the dispatch block is part of this
   task — not optional."*

4. **Release manager skipped AGT-013/014 gates (release-manager pre-flight strengthened)**
   Two merges (v1.7.0 and v1.7.1) completed without verifying that AGENT_LEARNINGS.md was
   updated and without recording a retro. The release-manager let this pass.
   *Release-manager pre-flight now has explicit steps 4 and 5: AGT-013 ledger check and
   AGT-014 retro confirmation before any merge is allowed.*

5. **Feature branch was not verified before specialist delegation (router pre-flight added)**
   The router delegated to control-author without first confirming the feature branch was
   checked out. Specialists must always work on a feature branch, never on main.
   *Router now has a `## Pre-flight` block: create/verify branch before Step 1.*

6. **Task file horizons go stale when versions are displaced by other work**
   Agent governance work consumed v1.4.0–v1.6.1, pushing the P2/P3/P4/P5 horizons forward.
   The task file was not updated promptly, creating confusion about which version to target.
   *Release-manager pre-flight step 6: confirm task file horizons are correct before merging.*



- **Lesson:** `evidence_type` values in `*.check.yaml` files must be registered in
  `08-evidence/evidence-types.yaml` before `compliance-reviewer` will pass the validation
  sweep. The Go (P1) policies set the precedent, but `go-quality` and `go-testing` were never
  registered at the time — this gap went undetected until P3 added `node-quality`,
  `node-testing`, `python-quality`, and `python-testing`, which triggered the reviewer check
  and blocked the chain until evidence types were back-filled for all four contexts.
- **Action:** `control-author` must register all new `evidence_type` values in
  `08-evidence/evidence-types.yaml` as part of every new policy phase — not deferred to review.
  The registration step is now a required pre-flight item in the control-author handoff.

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
