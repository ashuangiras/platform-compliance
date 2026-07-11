# CHANGELOG

All notable changes to `platform-compliance` are recorded here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v4.0.3] — 2026-07-11 (CHG-20260711-069)

### fix(policy): SUP-001 honors git ?ref pinning and exempts local modules

PATCH — bug fix only. No new controls, schemas, or profiles, and no collector change;
`breaking_changes: false`. Fixes a proven false-positive in the SUP-001 Terraform policy
`07-policies/opa/SUP/POL-SUP-001-TERRAFORM-001.rego` that flagged correctly-pinned git and
local modules as unpinned.

- **The false-positive**: the policy judged every module by the presence of a *registry*
  `version` field. Git modules (`source = "git::…//path?ref=vX.Y.Z"`) and local modules
  (`./`, `../`) have no registry `version`, so they were systematically reported as
  unpinned even when immutably pinned by a git tag or commit SHA. On real infrastructure
  (`platform-infrastructure`) this produced ~17 bogus SUP-001 violations.
- **The fix**: the policy now classifies a module's dependency **source type** before
  choosing its pinning signal. Git modules are judged via the collector's precomputed
  `modules_with_mutable_refs` — an immutable `?ref=vX.Y.Z` tag or a 40-hex commit SHA
  passes, while a mutable branch ref (or a missing ref) still FAILS. Registry modules keep
  the existing `version` bound check. Local (`./`, `../`) modules are exempt. The provider
  version-constraint checks and the `required_version` check are unchanged.
- **Enforcement preserved (non-breaking)**: genuinely-unpinned dependencies still fail — the
  FAIL fixture (git `?ref=main` plus other unpinned cases) reports four violations. The
  collector was **not** changed (verified correct for all required ref cases).
  `platform-infrastructure` now PASSES SUP-001 (`modules_with_mutable_refs == []`).

---

## [v4.0.2] — 2026-07-11 (CHG-20260711-068)

### fix(release): clean re-cut of the v4.0.1 patch on the DEFECT-6-fixed commit

PATCH — bug fix delivery only. No new controls, schemas, profiles, or OPA-policy changes;
`breaking_changes: false`. Delivers the already-merged **DEFECT-6 (release_record) fix** in
`07-policies/scripts/collect-all-inputs.py` under an immutable, release-gate-green tag cut on
`main` (`d272770`).

- **Why v4.0.2 exists**: the published `v4.0.1` tag points at pre-DEFECT-6 commit `25a151a`,
  whose tag-triggered `release-gate` **fails** — `collect-all-inputs.py` hardcoded
  `release_record: null` while `release_record_exists: true`, so `CHG-002` always reported
  `gate_assessment_id` / `release_summary` "missing" and blocked the tagged release. The
  collector now parses the release-record YAML and embeds it, so `CHG-002` validates the real
  fields and the release-gate is green on `d272770`.
- **v4.0.1 is superseded**: its tag predates the DEFECT-6 fix and its release-gate cannot pass.
  Per the maintainer's decision, **release immutability is preserved** — the published `v4.0.1`
  tag is **not** mutated or force-moved; the fix ships forward here in `v4.0.2`. The v4.0.2
  release record chains `change_record_ids` back to `CHG-20260711-067` for provenance.

---

## [v4.0.1] — 2026-07-11 (CHG-20260711-067)

### fix(enforcement): five enforcement-engine defects from the v4.0.0 downstream rollout

PATCH — bug fixes only. No new mandatory controls and no governance-object / schema /
profile / OPA-policy changes; `breaking_changes: false`. Restores the enforcement
semantics v4.0.0 already intended.

- **DEFECT-1 — SEC-001 silent non-enforcement**: the security-settings input SEC-001
  consumes was mapped in POLICY_MAP but never produced by a collector, so SEC-001
  evaluated `not_applicable` forever and never blocked. Wired
  `collect-github-security-settings.sh` into `collector-map.yaml` and
  `collect-all-inputs.py`; added `07-policies/tests/fixtures/SEC/sec-001-fail-alerts.yaml`
  (new) and updated `sec-001-pass.yaml` to prove a concrete fail (never `not_applicable`).
- **DEFECT-2 — SUP-001 warn-downgrade**: engine result ids carried technology suffixes
  (`SUP-001-TF` / `SUP-001-GA`) that did not equal the catalog id `SUP-001` the profiles
  gate on, so gate block membership silently downgraded to warn. Added `control_id_of()`
  normalization in `07-policies/scripts/run-all-policies.py`; updated
  `sup-001-terraform-pass.yaml` / `sup-001-terraform-fail.yaml`.
- **DEFECT-3 — py3.14 collector crash**: made `collect-github-security-settings.sh` and
  `collect-all-inputs.py` python3.14-safe and cwd-independent (no `.replace("'", '"')`).
- **DEFECT-4 — job4/job6 block-fallback mismatch**: aligned the job-4 runner
  (`run-all-policies.py`) and the job-6/7 workflow evaluator so a `None` sentinel (profile
  load failure) falls back to all-block while a loaded-empty gate stays non-blocking
  (`.github/workflows/self-compliance.yml`, `.github/workflows/reusable-compliance.yml`).
- **DEFECT-5 — release-gate never firing on tags**: added `push: tags: ['v*']` to
  `.github/workflows/self-compliance.yml` so tagging `vX.Y.Z` reaches and evaluates the
  guarded `release-gate` job.
- **DEFECT-6 — CHG-002 never passable on a real release**: `collect-all-inputs.py`
  hardcoded `release_record: null` in `chg-release.json` while setting
  `release_record_exists: true`, so `CHG-002` always saw an absent `gate_assessment_id`
  / `release_summary` and blocked every tagged release. Invisible until DEFECT-5 made the
  release-gate actually run on tags. The collector now parses the release-record YAML and
  embeds it so `CHG-002` validates the real fields.

---

## [v4.0.0] — 2026-07-11 (CHG-20260711-066)

### feat(enforcement)!: P0 silent-failure remediation — restore actual policy enforcement

Closes three critical findings from the systems architecture audit (2026-07-11).

**MAJOR / breaking per ADR-0010** — adds a new mandatory blocking control (CAT-003)
and promotes the 15 AGT controls to `block`. Consumers opt in when they bump their
pinned `platform-compliance-ref`; see the `migration_guide` in the v4.0.0 release record.

- **SF-4 — gate consistency**: `run-all-policies.py` (job 4) now loads the active
  profile's gate BLOCK controls (expanding the `inherits` chain) and exits non-zero
  ONLY when a BLOCK-level control fails, matching the gate evaluator (job 7).
  Warn-level failures emit `::warning::` and no longer fail CI inconsistently.
- **SF-2 — agent governance enforced**: all 15 AGT controls added to the merge_gate
  of `PROF-TERRAFORM-ROOT-V1`, `PROF-TERRAFORM-MODULE-V1`, `PROF-SERVICE-V1`, and
  `PROF-PLATFORM-V1` with `enforcement: block`, scoped to the `agent` context.
- **SF-3 — manifest completeness (CAT-003)**: new control + policy that runs
  unconditionally and fails when a repository has an agent surface on disk but omits
  the `agent` context. Detects every surface the AGT collector recognizes and reads
  declared contexts from the manifest under validation. Added `BIND-CAT-003-GITHUB`
  and pass/fail/NA fixtures.

---

## [v3.3.4] — 2026-07-11 (CHG-20260711-039)

### fix(forge): ComplianceOrg, default ref v3.3.3, tfsec + gitignore for terraform types

- `ComplianceOrg` was never set in TemplateVars — compliance workflow rendered with empty org
  prefix (`/platform-compliance/...` instead of `ashuangiras/platform-compliance/...`)
- Default `ComplianceRef` updated from hardcoded `v2.6.0` to `v3.3.3`
- Terraform repos (`terraform-module`, `terraform-root`) now always get
  `.github/workflows/terraform-security.yml` and `.gitignore` in the forge scaffold

---

## [v3.3.3] — 2026-07-11 (CHG-20260711-036)

### feat(forge): role-appropriate agent stubs per repo type

`forge new repo` now scaffolds role-appropriate agents based on the repository type
instead of copying platform-compliance's internal governance team verbatim.

- `RenderAgentStubs(vars, repoType)` renders from embedded templates under
  `templates/repo/agents/<type>/`
- Types with full agent teams: `terraform-module`, `terraform-root`, `service`,
  `library`; minimal `fallback` for unknown types
- `platform-repo` type still copies the live governance team from the compliance dir
- `copilot-instructions.md.tmpl` updated with type-specific content blocks
- `pull_request_template.md.tmpl` updated: removed `tools/check-agents.sh`
  reference; replaced with type-agnostic readiness checklist
- 4 new scaffold tests; all existing tests pass

---

## [v3.3.2] — 2026-07-10 (CHG-20260710-033)

### fix(gate): profile-aware enforcement levels for downstream repos

The compliance gate pipeline now correctly enforces BLOCK vs WARN vs DEFERRED
distinctions from the active profile. Previously, any failing OPA policy (even
WARN-level or DEFERRED controls) would cause `run-all-policies.py` to exit 1,
preventing jobs 5–7 from running and making gate evaluation impossible.

**Changes:**
- `run-all-policies.py`: exits 0 always; missing input file → `not_applicable`
- `reusable-compliance.yml` job 4: `if: always()` on Upload policy results step
- Jobs 5/6/7: `if: always()` conditions — full pipeline always runs to completion
- `run-all-policies.py`: waived controls now embed `waiver_id` in result JSON
- Job 5 (evidence): propagates `waiver_id` from result JSON to evidence YAML
- Job 6 (assessment): fetches profile YAML from the platform-compliance archive,
  builds BLOCK control set for the active gate, and only fails the gate when
  BLOCK controls have unwaived failures; WARN/DEFERRED produce `pass-with-warnings`
- Profile YAML from `04-profiles/` is fetched by job 6 independently (different
  runner than job 4)

---

## [v3.3.1] — 2026-07-10 (CHG-20260710-032)

### fix(reusable-workflow): absolute script paths for downstream repo support

**Critical bugfix** — the OPA policy-checks job in `reusable-compliance.yml` ran
`collect-all-inputs.py` and `run-all-policies.py` using paths relative to the
calling repository's checkout. This worked only for platform-compliance self-governance
(where those files exist) but broke with `No such file or directory` on every
downstream repository. The bug was invisible until `platform-modules` ran its first PR.

**Changes:**
- `.github/workflows/reusable-compliance.yml`: After fetching the OPA policy bundle,
  also extract the collector scripts from the platform-compliance source archive to
  `/tmp/platform-compliance-scripts/`. Both scripts are now referenced by absolute path.
- `07-policies/scripts/collect-all-inputs.py`: Made self-locating via
  `Path(__file__).resolve().parent`. All sibling collector script calls resolve
  relative to the script's own directory, not the process CWD.
- `.github/AGENT_LEARNINGS.md`: Rule added — always test reusable workflows from at
  least one downstream repo before tagging.

---

## [v3.3.0] — 2026-07-10 (CHG-20260710-031)

### forge new repo: complete downstream repo scaffold

Every repository created with `forge new repo` now receives:
- `.github/workflows/compliance.yml` — calls `reusable-compliance.yml@ComplianceRef`;
  branch protection "Compliance: Merge Gate" can now actually post a status
- `.github/copilot-instructions.md` — repo-specific governance context
- `.vscode/settings.json` — agent discovery settings (always rendered)
- `.github/agents/*.agent.md` — full 7-agent team (when `agent` context is declared)

**Agent scaffolding logic:**
- Service/library/frontend/platform repos: agents included by default (agent context in defaultContexts)
- Terraform/infra repos: agents NOT included by default; use `--with-agents` to opt in
- Any repo: use `--no-agents` to skip agent files

This fixes the fundamental gap where forge created repos whose branch protection
required a CI status check that no workflow could ever post.

---

## [v3.2.0] — 2026-07-10 (CHG-20260710-030)

### Phase C start — ADRs ratified, platform-modules created

**ADRs ratified (PC-0131–PC-0133):**
- ADR-0008: Vault self-hosted on platform-infrastructure (secrets backend)
- ADR-0012: Environment-specific profiles — PROF-SERVICE-STAGING-V1 (relaxed) + PROF-SERVICE-PROD-V1 (strict)
- ADR-0014: S3-compatible Terraform state (MinIO self-hosted or cloud S3)
- ADR-0019: HashiCorp Consul for service config/discovery alongside Vault (secrets)

**Profiles:**
- PROF-SERVICE-STAGING-V1 (inherits PROF-SERVICE-V1; relaxes BAK-001/NET-001/OBS-001 to warn)
- PROF-SERVICE-PROD-V1 (inherits PROF-SERVICE-V1; promotes BAK-001/NET-001/OBS-001 to block)

**Taxonomy:** `vault` and `consul` technology contexts registered

**forge fix:** personal account repo creation routes to `POST /user/repos`

**Phase C (PC-0134): platform-modules created**
- https://github.com/ashuangiras/platform-modules
- Profile: PROF-TERRAFORM-MODULE-V1; contexts: github, github-actions, terraform
- Branch protection: Compliance Merge Gate + 1 required review

---

## [v3.1.0] — 2026-07-10 (CHG-20260710-029)

### Full repo audit — gap fixes

**New controls implemented:**
- `SRC-004` (commit signing) — binding, collector field (`required_signatures.enabled`),
  OPA policy `POL-SRC-004-GITHUB-001` (block), 3 fixtures
- `SUP-003` (Dependabot alerts) — binding, collector fields
  (`vulnerability_alerts_enabled`, `automated_security_fixes_enabled`),
  OPA policy `POL-SUP-003-GITHUB-001` (block for alerts, warn for auto-fixes), 4 fixtures

**Evidence type completeness:**
- `08-evidence/evidence-types.yaml`: 7 new types added; 2 existing types updated
  (SRC-004 added to `github-branch-protection-api-response`;
   SUP-003 added to `dependency-vulnerability-alert-status`)
  Total: 44 registered evidence types — all `*.check.yaml` files now covered

**Housekeeping:**
- `.gitignore` — created at repo root with required SEC-001 patterns
  (`*.pem`, `*.key`, `.env`, `*.tfvars` etc.); stops CI warnings on every PR
- 3 stale ADR drafts removed from `decisions-needed/`:
  ADR-0009 (policy-bundle), ADR-0010 (versioning-cadence), ADR-0011 (plt-cli)
- `docs/implementation/current-state.md` — updated to v3.0.0 reality
- `docs/implementation/decisions-needed/README.md` — ADR-0009/0010/0011 marked resolved

---

## [v3.0.0] — 2026-07-10 (CHG-20260710-028)

### forge v3.0.0 — CI pipeline, CodeQL SAST, binary releases, user docs

**MAJOR** version bump: forge is now a first-class CI deliverable of platform-compliance.
Every tag ships `forge` binaries alongside `policies.tar.gz`.

- `.github/workflows/forge-ci.yml` (new) — build, vet, and test forge on PRs that touch
  `tools/forge/**`; satisfies QUA-001/002/003/004 and TST-001 for the forge codebase itself
- `.github/workflows/codeql.yml` — `codeql-go` job added for Go SAST on `tools/forge`;
  `paths:` trigger filter added covering both Python (07-policies/scripts) and Go (tools/forge)
- `.github/workflows/release.yml` — `build-forge` job: cross-compiles
  `forge_Linux_x86_64`, `forge_Darwin_x86_64`, `forge_Darwin_arm64` + `forge_checksums.txt`
  and uploads to every release
- `tools/forge/README.md` (new) — install guide, quickstart, full command reference,
  how downstream repos use forge, collector extension guide, development commands

---

## [v2.9.3] — 2026-07-10 (CHG-20260710-027)

### fix: SRC-001/002 bootstrap CI race condition

- `09-assessments/waivers/WAV-SRC-001-202607-001.yaml` — SRC-001 waiver (single-developer bootstrap)
- `.compliance-manifest.yaml` — WAV-SRC-001-202607-001 added to waiver_ids
- `07-policies/scripts/run-all-policies.py` — waiver-aware policy runner:
  `load_active_waivers()` reads manifest waivers at runtime; waived controls
  print "~ CONTROL: fail (waived)" and do not cause exit 1
- `.github/agents/release-manager.agent.md` — bootstrap-merge procedure updated:
  use DELETE /enforce_admins + --admin merge to avoid the required_approving_review_count=0
  race condition that caused SRC-001/002 to fail during bootstrap window

---

## [v2.9.2] — 2026-07-10 (CHG-20260710-026)

### fix: CHG-001 PR body format + AGT-014 retro guidance

- `.github/pull_request_template.md`: Change Record section now shows
  `Change Record: CHG-YYYYMMDD-NNN` inline (matching CHG-001 policy regex)
- `tools/forge/pkg/scaffold/templates/repo/pull_request_template.md.tmpl`: same fix
- `.github/agents/release-manager.agent.md`: pre-flight step 7 — always write
  `Change Record: CHG-...` inline, never just a section header

---

## [v2.9.1] — 2026-07-10 (CHG-20260710-025)

### forge: data-driven collector dispatch (no code change for new collectors)

- `07-policies/scripts/collector-map.yaml` — new file: maps every OPA input
  file to its collector script and interpreter; read by forge at runtime
- `tools/forge/pkg/opa/runner.go` — CollectForEntries reads collector-map.yaml
  instead of a hardcoded Go map; adding a new collector now requires only a
  YAML entry, not a forge recompile
- collector-engineer instructions updated: step 5 now includes the YAML entry

---

## [v2.9.0] — 2026-07-10 (CHG-20260710-024)

### forge v1.0.0 complete — Phases B.3–B.6

**Phase B.3 — `forge check` and `forge gate`:**
- `pkg/opa/`: POLICY_MAP parser, embedded OPA evaluation, collector subprocess invocation
- `pkg/gate/`: gate criteria loading, gate evaluation against policy runs
- `forge check all|policy <id>`: run OPA policies locally
- `forge gate merge|deploy|release`: evaluate compliance gates

**Phase B.4 — `forge evidence` and `forge assess`:**
- `forge evidence submit|list`: manage evidence records
- `forge assess run|show`: generate and view assessment reports

**Phase B.5 — authoring scaffolds:**
- `forge new control|adr|waiver|change-record`: scaffold governance objects
- ID allocators: NextControlID, NextADRID, NextChangeRecord, NextWaiverID

**Phase B.6 — `forge registry` and `forge report`:**
- `forge registry list controls|profiles|standards|contexts|domains`: browse governance objects
- `forge registry show <id>`: display any governance object
- `forge report coverage|drift|profile <id>`: compliance reporting

All 50+ forge subcommands are now implemented. 19 tests passing.
Phase C (downstream repo bootstrapping) is fully unlocked.

---

## [v2.8.0] — 2026-07-10 (CHG-20260710-023)

### forge Phase B.2 — `forge new repo` (governed repository bootstrapping)

- `pkg/github/`: GitHub API client — CreateRepo, CommitFiles, SetMergeGateProtection
- `pkg/scaffold/`: template renderer (Go embed.FS), 5 repo templates
- `cmd/new/repo.go`: `forge new repo <name>` with --dry-run, --with-agents, --profile,
  --type, --contexts, --private, --description flags
- Phase B.2 unlocks Phase C: use `forge new repo` to create downstream repositories
- 19 tests total (6 new scaffold tests), all passing
- Smoke test: forge new repo platform-services --with-agents --dry-run → 13 files

---

## [v2.7.0] — 2026-07-10 (CHG-20260710-022)

### forge Phase B.1 — `forge validate` (offline schema validation)

- `pkg/config`: Config struct + global/repo/env loading
- `pkg/taxonomy`: loads all 02-taxonomy/ files into typed structs
- `pkg/schema`: validates any governance YAML against its schema;
  infers schema from $schema field (handles .yaml extension) or file path pattern;
  supports all 16 schemas
- `pkg/manifest`: reads .compliance-manifest.yaml; deep validation
  (profiles exist, contexts registered, waivers have files)
- `pkg/compliance`: local directory loader + profile inheritance resolver
- `cmd/validate`: `forge validate <file>`, `forge validate repo [path]`,
  `forge validate manifest [path]`
- 13 tests passing; 75 real controls validated in test suite
- `forge validate repo . --compliance-dir .` validates the entire compliance repo

---

## [v2.6.0] — 2026-07-10 (CHG-20260710-021)

### forge Go module scaffolded + implementation plan

- `tools/forge/` — compiling Go module (Go 1.26, cobra + viper + OPA embedded)
  `forge --version` works; all package directories created
- `tools/forge/docs/IMPLEMENTATION-PLAN.md` — full phased plan:
  exact types, function signatures, file creation order, deliverable checklists for B.1–B.6
- `tools/forge/Makefile` — build, test, lint, release-binaries targets
- Phase B.1 (`forge validate`) is ready to implement

---

## [v2.5.0] — 2026-07-10 (CHG-20260710-020)

### forge full architecture (pre-implementation design)

- `docs/forge-architecture.md` — complete design:
  full command taxonomy (50+ subcommands), 16 Go packages, 6 implementation phases,
  GitHub API + OPA + compliance-ref-cache integration, configuration model, testing strategy
- ADR-0018 updated to reference the architecture document
- Phase B implementation sequence: B.1 (validate) → B.2 (new repo, unlocks Phase C) →
  B.3 (check/gate) → B.4 (evidence/assess) → B.5 (authoring scaffolds) → B.6 (registry/report)

---

## [v2.4.0] — 2026-07-10 (CHG-20260710-019)

### ADR-0018 ratified — forge CLI (supersedes ADR-0011)

- CLI renamed from `plt` to `forge`; primary command is `forge new repo <name>`
- Location: `tools/forge/` in this repository (not a separate platform-plt repo)
- Distribution: pre-built Go binaries attached to each platform-compliance release tag
- ADR-0011 status updated to `superseded by ADR-0018`
- `tools/README.md` updated to describe `forge`

---

## [v2.3.0] — 2026-07-10 (CHG-20260710-018)

### ADR-0011 ratified — plt CLI technology selection

- Decision: Go language, pre-built binaries via GitHub Releases, separate repository
  `ashuangiras/platform-plt`
- `tools/README.md` updated: pointer to platform-plt, drop stale planned structure
- Phase B (plt CLI implementation) unblocked

---

## [v2.2.0] — 2026-07-10 (CHG-20260710-017)

### ADR-0017 A3 — Agent baseline promotion (PC-0277, PC-0278)

- AGT-001, AGT-002, AGT-003 added to `PROF-BASE` (mandatory, enforcement: block at merge
  and release gates). These controls are now universal for all platform repositories.
- OPA policies gate on `has_agent_config` — repositories without agent configuration
  receive `not_applicable`, not a failure.
- `PROF-AGENTIC-V1` unchanged: remains the full 15-control AGT overlay profile.

---

## [v2.1.0] — 2026-07-10 (CHG-20260710-016)

### ADR-0016 Phase P5 — Library Profile (PC-0254, PC-0255)

- New profile `PROF-LIBRARY-V1` (inherits `PROF-BASE`; `applicable_to: [library]`)
  - Mandatory (all `block`): QUA-001/002/003/004, TST-001, TST-002
  - Explicitly not applicable: TST-003, RUN/OBS/BAK/NET controls
  - Libraries mandate code quality and test coverage; runtime controls do not apply
- `02-taxonomy/repository-types.yaml`: `library` type now points to `PROF-LIBRARY-V1`
  with `implied_domains: [SUP, QUA, TST]`

---

## [v2.0.0] — 2026-07-10 (CHG-20260710-015)

### ADR-0016 Phase P4 — Frontend Security Controls + TST-002 Block Promotion

**New standards:**
- `SRC-WEB-CSP` — W3C Content Security Policy Level 3
- `SRC-WCAG-2-2` — Web Content Accessibility Guidelines 2.2

**New controls:**
- `SEC-009` — Content-Security-Policy header required (block)
- `SEC-010` — No production source maps (block)
- `SEC-011` — Bundle-size budget: warn ≥500 KB, fail ≥2 MB (warn enforcement)

**New profile:**
- `PROF-FRONTEND-V1` (inherits `PROF-BASE`; applicable to `frontend-app`)

**New collector:**
- `collect-frontend-info.sh` (CSP detection, source map scan, bundle sizing)

**New policies (3):**
- `POL-SEC-009-FRONTEND-001` — CSP header presence check
- `POL-SEC-010-FRONTEND-001` — Source map detection check
- `POL-SEC-011-FRONTEND-001` — Bundle size budget check

**New bindings (3):**
- `BIND-SEC-009-FRONTEND`, `BIND-SEC-010-FRONTEND`, `BIND-SEC-011-FRONTEND`

**New mapping:**
- `MAP-WEB-CSP-SEC` — W3C CSP Level 3 → SEC-009/SEC-010 mapping

**BREAKING — TST-002 coverage threshold promoted `warn` → `block`:**
- `PROF-GO-SERVICE-V1`, `PROF-NODE-SERVICE-V1`, `PROF-PYTHON-SERVICE-V1` — TST-002 is now
  `enforcement: block` across all gate sections (ADR-0016 decision 4, v2.0.0 milestone)
- `BIND-TST-002-GO` — specification updated to reflect block enforcement from v2.0.0

**OPA contract update:**
- `warn` result value formally documented in `07-policies/opa/README.md` and
  `opa-policies.instructions.md`

**Tasks closed:** PC-0248, PC-0249, PC-0250, PC-0251, PC-0252, PC-0253

---

## [v1.9.1] — 2026-07-10 (CHG-20260710-014)

### AGT — Session Retro + Final Agent Instruction Improvements

**Agent layer improvements:**
- `AGENT_LEARNINGS.md` — AGT-LEARNING-003: full retrospective for the v1.7.0–v1.9.0 session
- `release-manager.agent.md` — pre-flight step 5 formalised: retro must be genuine prose, not
  checkbox-only; CI collector will reject a retro that contains only checkbox-style bullets
- `collector-engineer.agent.md` — post-flight note added: regex patterns in collectors must be
  scoped to avoid false positives; always test on a PR body that contains only checkboxes

---

## [v1.9.0] — 2026-07-10 (CHG-20260710-014)

### AGT-014 Enforcement — Stronger Retro/Readiness Detection + Router Gate

**Agent layer improvements (CHG-20260710-014):**
- `collect-agent-info.py` — `pr_has_retro` regex scoped to the `## Retrospective` subsection
  and excludes checkbox lines; `pr_has_readiness` aligned to the same pattern
- `07-policies/opa/AGT/` — AGT-013 and AGT-014 policies updated to use the stronger detection
- `compliance-router.agent.md` — explicit AGT-014 gate step before handing off to
  `release-manager`; router now blocks the chain if readiness or retro is missing
- `release-manager.agent.md` — pre-flight steps 4–6 formalised: AGT-013 ledger check,
  AGT-014 retro confirmation, task file horizon verification

**Bug fix:**
- `pr_has_retro` regex previously matched bullet items inside checkbox lines as "retro text";
  now anchored to the `**Retrospective**` heading and excludes lines starting with `- [` to
  prevent false positives

---

## [v1.8.0] — 2026-07-10 (CHG-20260710-013)

### ADR-0016 Phase P3 — Node + Python Quality Controls (PC-0241–PC-0247)

**New standards:**
- `SRC-TS-STYLE` — TypeScript Style Guide (ESLint + typescript-eslint)
- `SRC-PYTHON-PEP8` — Python Style Guide (PEP 8 + ruff)

**New bindings:**
- Node: `BIND-QUA-{001,002,003,004}-NODE`, `BIND-TST-{001,002}-NODE` (6 bindings)
- Python: `BIND-QUA-{001,002,004}-PYTHON`, `BIND-TST-{001,002}-PYTHON` (5 bindings; QUA-003 intentionally absent)

**New profiles:**
- `PROF-NODE-SERVICE-V1` (inherits `PROF-SERVICE-V1`)
- `PROF-PYTHON-SERVICE-V1` (inherits `PROF-SERVICE-V1`)

**New policies (11):**
- `07-policies/opa/QUA/`: POL-QUA-{001,002,003,004}-NODE-001, POL-QUA-{001,002,004}-PYTHON-001
- `07-policies/opa/TST/`: POL-TST-{001,002}-NODE-001, POL-TST-{001,002}-PYTHON-001

**New input collectors:**
- `collect-node-info.sh` (ESLint, tsc, jest/vitest, coverage)
- `collect-python-info.sh` (ruff, mypy, pytest, coverage)

**Evidence types registered:** `node-quality`, `node-testing`, `python-quality`, `python-testing`
(also back-filled `go-quality`, `go-testing` from P1)

---

## [v1.7.1] — 2026-07-10

### Summary

Agent inter-communication protocol: handoff blocks, exclusivity rules, and specialist ordering.
Adds mandatory `## HANDOFF` output sections to all 7 agent files and codifies the 5 operating
rules (agent exclusivity, maximize agent involvement, router-coordinates/specialists-execute,
inter-agent handoff protocol, ordering enforcement) in `.github/copilot-instructions.md`.
Change record: CHG-20260710-012. Improvement recorded per AGT-013.

### Changed

**Agent operating layer:**
- `.github/copilot-instructions.md` — Agent Operating Rules section added (5 rules, canonical
  specialist sequence, inter-agent handoff protocol definition)
- `.github/agents/compliance-router.agent.md` — routing table extended; `## HANDOFF` output
  block + decomposition protocol added
- `.github/agents/control-author.agent.md` — `## HANDOFF` output block added
- `.github/agents/collector-engineer.agent.md` — `## HANDOFF` output block added
- `.github/agents/policy-engineer.agent.md` — `## HANDOFF` output block added
- `.github/agents/compliance-reviewer.agent.md` — `## HANDOFF` output block added
- `.github/agents/ci-workflow-engineer.agent.md` — `## HANDOFF` output block added
- `.github/agents/release-manager.agent.md` — `## HANDOFF` output block added

**Tracker:**
- `docs/implementation/tasks/v4-agent-governance.yaml` — PC-0267 and PC-0279 marked `done`

### AGT-013 Improvement

Inter-agent handoff protocol is now formally defined and enforced. All 7 agents emit a
structured `## HANDOFF` block. The router is explicitly prohibited from authoring governance
objects. Specialist ordering (control-author → collector → policy → reviewer → ci → release)
is now a mandatory constraint, not a guideline.

---

## [v1.7.0] — 2026-07-10

### Summary

ADR-0016 Phase P2: Go service controls. Adds 9 new controls (ARC-001, ARC-003, API-001/002/003,
OBS-004, SRC-005, SUP-005, DOC-003) with bindings, OPA policies, and a new Go-service profile
(PROF-GO-SERVICE-V1) that inherits from PROF-SERVICE-V1. Change record: CHG-20260710-011.

### Added

**Standards (01-sources/registry/):**
- `SRC-OPENAPI-3-1` — OpenAPI Specification 3.1 (OpenAPI Initiative)
- `SRC-CNCF-OTEL` — OpenTelemetry observability framework (CNCF)
- `SRC-CONVENTIONAL-COMMITS` — Conventional Commits v1.0.0
- `SRC-12-FACTOR` — The Twelve-Factor App (12factor.net)

**Controls (03-catalogs/controls/):**
- `ARC-001` — Go repositories must follow standard project layout (cmd/internal/pkg) [warn]
- `ARC-003` — Zero import cycles and layer boundaries (go vet) [block]
- `API-001` — Services must include a machine-readable OpenAPI spec [block]
- `API-002` — OpenAPI spec must declare explicit version and versioned path prefix [block]
- `API-003` — PRs modifying OpenAPI spec must include breaking-change analysis [warn]
- `OBS-004` — Services must instrument distributed tracing using OpenTelemetry [warn]
- `SRC-005` — All commits must follow Conventional Commits format [warn]
- `SUP-005` — Go repositories must commit go.sum and keep it tidy [block]
- `DOC-003` — Service repositories must include a runbook [warn]

**Bindings (06-bindings/bindings/):**
- `BIND-ARC-001-GO`, `BIND-ARC-003-GO` — ARC controls for go context
- `BIND-API-001-GO`, `BIND-API-002-GO`, `BIND-API-003-GO` — API controls for go context
- `BIND-OBS-004-GO` — OBS-004 for go context
- `BIND-SRC-005-GITHUB` — SRC-005 for github context
- `BIND-SUP-005-GO` — SUP-005 for go context
- `BIND-DOC-003-GO` — DOC-003 for go context

**OPA policies (07-policies/opa/):**
- `ARC/POL-ARC-001-GO-001`, `ARC/POL-ARC-003-GO-001`
- `API/POL-API-001-GO-001`, `API/POL-API-002-GO-001`, `API/POL-API-003-GO-001`
- `OBS/POL-OBS-004-GO-001`
- `SRC/POL-SRC-005-GITHUB-001`
- `SUP/POL-SUP-005-GO-001`
- `DOC/POL-DOC-003-GO-001`
- All 9 policies compile clean (`/tmp/opa check`) and validate against `policy-check.schema.json`

**Profile:**
- `PROF-GO-SERVICE-V1` — Go service compliance profile inheriting PROF-SERVICE-V1;
  4 new blocking controls (ARC-003, API-001, API-002, SUP-005) + 5 warn controls

**Collector updates (07-policies/scripts/):**
- `collect-go-info.sh` — extended with architecture, api, observability, supply_chain,
  documentation, and source_hygiene sections
- `run-all-policies.py` — 9 new POLICY_MAP entries for all P2 controls

### Validation results
- 4/4 standard-source files: `check-jsonschema` PASS
- 9/9 control files: `check-jsonschema` PASS
- 9/9 binding files: `check-jsonschema` PASS
- 1/1 profile file: `check-jsonschema` PASS
- 9/9 policy `.check.yaml` files: `check-jsonschema` PASS
- OPA compile: `/tmp/opa check 07-policies/opa/` PASS (exit 0)
- `bash -n collect-go-info.sh` PASS
- `py_compile run-all-policies.py` PASS

---

## [v1.0.0] — 2026-07-09

### Summary

Initial release of the platform compliance backbone. Establishes the complete compliance
model from registered external standards to reusable CI/CD enforcement workflows.
All pre-push validation checks pass. 75/86 v1 tasks done; the 11 remaining require GitHub.

### Added

**Standards and governance foundation:**
- 9 registered external standards with full provenance metadata (01-sources/)
- 7 taxonomy vocabulary files (02-taxonomy/)
- 23 platform controls across 10 domains: SRC, SUP, IAC, SEC, RUN, OBS, BAK, CHG, DOC, INC, NET (03-catalogs/)
- PROF-PLATFORM-V1 compliance profile with 4 gates (04-profiles/)
- 10 standard-to-control mapping collection files (05-mappings/)
- 24 implementation bindings across GitHub, Terraform, Docker, GitHub Actions contexts (06-bindings/)

**Validation layer:**
- 16 JSON schemas for all governance object types (schemas/) — all pass meta-schema validation
- 14 OPA/Rego policy checks covering all merge-gate mandatory automated controls (07-policies/)
- 23 YAML policy test fixtures — 10 key pass/fail pairs verified with `opa eval`

**Evidence and assessment infrastructure:**
- Evidence ledger format + retention policy (08-evidence/ledger/)
- 4 evidence schema test fixtures
- Release gate and deployment gate criteria files (09-assessments/gates/)
- v1.0.0 self-assessment report (manually authored; will be replaced by CI in Phase A)
- v1.0.0 release record (09-assessments/releases/)
- First change record CHG-20260708-001

**CI/CD:**
- Reusable 7-job compliance workflow (.github/workflows/reusable-compliance.yml) — passes actionlint
- Self-compliance CI (.github/workflows/self-compliance.yml)

**Architecture decisions:**
- ADR-0001: Compliance before implementation
- ADR-0002: GitHub as primary root of trust
- ADR-0003: No second repo before v1.0.0 gate passes
- ADR-0004: OPA/Rego as primary policy engine
- ADR-0005: YAML for all human-authored files; JSON Schema only for schemas
- ADR-0006: Distributed evidence storage (each repo owns its own `.evidence/` ledger)
- ADR-0007: Waiver approval governance (PR review as canonical approval event)

**Documentation:**
- Architecture overview, operating model, traceability model, commit compliance flow
- Onboarding guide (`docs/onboarding.md`)
- Authoring controls guide (`docs/authoring-controls.md`)
- Consuming compliance guide (`docs/consuming-compliance.md`)
- Glossary (`docs/glossary.md`)
- Full implementation roadmap with 249 total files

**Repository identity:**
- GitHub: https://github.com/ashuangiras/platform-compliance
- Self-compliance manifest declaring PROF-PLATFORM-V1

### Schema validation (all pass)
- 16/16 schemas pass meta-schema validation
- 9/9 source entries validate
- 25/25 control files validate
- PROF-PLATFORM-V1 validates
- 10/10 mapping collection files validate
- Gate files exactly match profile gate sections (0 divergences)

### Known gaps at v1.0.0
- Branch protection and secret scanning require GitHub repository setup (PC-0080-0086)
- OPA workflow integration is a skeleton (Phase A — unblocked, ADR-0006/0007 resolved)
- 3 clause-level [PLACEHOLDER:] markers need standard document research (PC-0009-0011)
- CAT and REL domain controls are reserved for v2.0.0
- Evidence records are manually authored; CI will produce real records after Phase A

### Summary

Initial release of the platform compliance backbone. Establishes the complete compliance
model from registered external standards to reusable CI/CD enforcement workflows.

### Added

**Standards and governance foundation:**
- 9 registered external standards with full provenance metadata (01-sources/)
- 7 taxonomy vocabulary files (02-taxonomy/)
- 23 platform controls across 10 domains: SRC, SUP, IAC, SEC, RUN, OBS, BAK, CHG, DOC, INC, NET (03-catalogs/)
- PROF-PLATFORM-V1 compliance profile with 4 gates and categorised control sets (04-profiles/)
- 10 standard-to-control mapping files covering all active controls (05-mappings/)
- 24 implementation bindings across GitHub, Terraform, Docker, GitHub Actions contexts (06-bindings/)

**Validation layer:**
- 15 JSON schemas for all governance object types (schemas/)
- 12 OPA/Rego policy checks covering all merge-gate mandatory automated controls (07-policies/)
- 18 policy test fixtures (pass and fail cases per policy)

**Evidence and assessment infrastructure:**
- Evidence ledger format specification (08-evidence/ledger/)
- 4 evidence schema test fixtures
- Release gate and deployment gate criteria files (09-assessments/gates/)
- v1.0.0 self-assessment report (09-assessments/reports/)
- v1.0.0 release record (09-assessments/releases/)

**CI/CD:**
- Reusable 7-job compliance workflow (.github/workflows/reusable-compliance.yml)
- Self-compliance CI (.github/workflows/self-compliance.yml)

**Documentation:**
- Architecture overview (docs/platform-compliance-architecture.md)
- Operating model (docs/operating-model.md)
- Traceability model (docs/traceability-model.md)
- Commit compliance flow lifecycle (docs/commit-compliance-flow.md)
- Consuming compliance onboarding guide (docs/consuming-compliance.md)
- Implementation roadmap — 86 tasks (docs/implementation-roadmap.md)
- Glossary (docs/glossary.md)
- Next-repository readiness gate (docs/next-repo-readiness.md)
- Repository design reference (docs/repository-design.md)

**Templates:**
- Compliance manifest template
- Waiver template
- ADR template

**Decisions:**
- ADR-0001: Compliance before implementation
- ADR-0002: GitHub as primary root of trust
- ADR-0003: No second repository before v1.0.0 gate passes
- ADR-0004: OPA/Rego as primary policy engine

### Schema validation

All 15 schemas pass JSON Schema meta-schema validation.
9/9 standard source entries pass schema validation.
25/25 control files pass schema validation.
PROF-PLATFORM-V1 passes profile schema validation.
.compliance-manifest.yaml passes repository-compliance schema validation.

### Known gaps at v1.0.0

- Branch protection (SRC-001, SRC-002) and secret scanning (SEC-002) require GitHub repository setup
- OPA policies for release-gate-only controls (OBS-001, BAK-001, NET-001) are not yet implemented
- Phase 7 policies for RUN-001, CHG-001, INC-001 are not yet implemented
- Standard clause [PLACEHOLDER] markers remain for CIS Docker, SLSA, and Scorecard specific references
- `docs/glossary.md` covers all v1.0.0 terms; CAT and REL domains are reserved for v2.0.0

---

## [Unreleased]

*No unreleased changes at this time.*

---

## [v1.6.1] — 2026-07-10

### Summary

Housekeeping fix. Relocates the AGT-013 agent learnings ledger from `.github/agents/LEARNINGS.md`
to `.github/AGENT_LEARNINGS.md` so it is no longer mis-registered as a VS Code custom agent, and
trims the collector so it stops recommending agent-folder ledger paths.

Change Record: CHG-20260710-010.

### Changed

- Moved the AGT-013 learnings ledger from `.github/agents/LEARNINGS.md` to
  `.github/AGENT_LEARNINGS.md` — keeping it out of `.github/agents/` so it is no longer picked up
  as a stray VS Code custom agent.
- `collect-agent-info.py` `LEDGER_CANDIDATES` no longer recommends agent-folder ledger paths
  (`.github/agents/LEARNINGS.md`, `.github/agents/IMPROVEMENTS.md`).
- Updated AGT-013 references to the new ledger path across the control statement
  (`AGT-013.yaml`), the OPA policy (`POL-AGT-013-AGENT-001.rego`), `copilot-instructions.md`, and
  `pull_request_template.md`.

---

## [v1.6.0] — 2026-07-10

### Summary

Makes the agent operating layer adoptable by downstream repositories out of the box. Adds
**AGT-015** (blocking): a repository with custom agents must commit the workspace discovery
settings so the agent team is visible on every clone and for every new downstream repo — plus a
copy-paste template. The AGT suite is now **15 controls, all blocking**, and ships in the release
bundle downstream repos consume.

Change Record: CHG-20260710-009.

### Added

- **AGT-015** (block) — repositories with custom agents must commit `.vscode/settings.json`
  enabling `chat.agentFilesLocations` for `.github/agents`; `not_applicable` when no agents exist.
- `templates/agent-vscode-settings.template.json` — ready-to-copy discovery settings for
  downstream repositories to enable the agent team immediately.
- `collect-agent-info.py` gains a `discovery` signal (settings present + agent location enabled).

### Changed

- `PROF-AGENTIC-V1`: AGT-015 added to the mandatory set and the merge, release, and
  continuous-audit gates.
- `run-all-policies.py` POLICY_MAP: +1 (AGT-015, context-gated on `agent`).
- ADR-0017 follow-up recorded; rollout tracker updated.

---

## [v1.5.0] — 2026-07-10

### Summary

Raises the agent-configuration bar from a secure baseline to a **stringent, blocking quality
standard** (ADR-0017 A2, amended). The AGT suite grows from 3 to **14 controls — all blocking** —
covering setup, security, effectiveness, and continuous self-improvement. Agents must now record a
learning on every change and pass a readiness check + retro before merge. platform-compliance
self-enforces the entire suite and passes it.

Change Record: CHG-20260710-008.

### Added

**Effectiveness controls (block):**
- AGT-004 discoverable descriptions · AGT-005 least-privilege tools · AGT-006 instruction scoping
- AGT-007 pre/post-flight discipline · AGT-008 safety-hook integrity (scripts exist + executable)
- AGT-009 multi-agent routing · AGT-010 per-agent role + constraints
- AGT-011 MCP server trust & version pinning · AGT-012 repository-instruction completeness

**Continuous-improvement controls (block):**
- AGT-013 — every pull request records a meaningful entry in `.github/agents/LEARNINGS.md`
- AGT-014 — every pull request completes a readiness check + retrospective before merge

**Tooling & artifacts:**
- `tools/check-agents.sh` — offline "fail loudly" runner for the whole AGT suite
- `.github/agents/LEARNINGS.md` — the agent learnings/improvement ledger
- `.github/pull_request_template.md` — Agent Readiness & Retro section
- `collect-agent-info.py` extended with quality signals + PR context (changed files, PR body via env)

### Changed

- `PROF-AGENTIC-V1` → v2.0.0: all 14 AGT controls mandatory and blocking at the merge gate
- `run-all-policies.py` POLICY_MAP: +11 AGT entries (context-gated on `agent`)
- `copilot-instructions.md`: post-flight now requires a ledger entry, `tools/check-agents.sh`, and
  a completed readiness/retro
- ADR-0017 amended: A2 promoted from warn to block and expanded

---

## [v1.4.0] — 2026-07-10

### Summary

Agent configuration becomes a governed, self-enforced part of the platform. This release pairs
the **agent operating layer** (how the platform is built with AI agents) with **ADR-0017 phase
A1** (governance for agent configuration in any repository). platform-compliance is the first
repository governed by the new AGT controls — and passes them.

Change Records: CHG-20260710-006 (agent operating layer), CHG-20260710-007 (ADR-0017 A1).

### Added

**Agent operating layer** (`.github/`, `.vscode/`):
- Repo-wide `copilot-instructions.md` with universal pre-flight / post-flight checklists
- A 7-member specialist agent team under `.github/agents/` (compliance-router + control-author,
  policy-engineer, collector-engineer, ci-workflow-engineer, release-manager, compliance-reviewer)
  with role-scoped tools and routing
- Five file-scoped instruction sets under `.github/instructions/`
- A GitHub MCP server config (`.vscode/mcp.json`)
- A `PreToolUse` safety hook (`.github/hooks/guard-destructive-ops.json`) that prompts before
  irreversible git/filesystem operations

**Agent configuration governance (ADR-0017 A1):**
- New control domain **AGT** (Agent Governance) and technology context **agent** (opt-in)
- Four standards: `SRC-VSCODE-AGENT-CUSTOMIZATION`, `SRC-AGENTS-MD`, `SRC-MCP-SPEC`,
  `SRC-PLATFORM-AGENT-CONVENTIONS`
- Three controls (all block): **AGT-001** single-sourced repository instructions,
  **AGT-002** valid customization-file frontmatter + description,
  **AGT-003** MCP configuration valid and free of hardcoded secrets
- `collect-agent-info.py` collector (stdlib-only; scans instructions, frontmatter, MCP secret
  scan, hooks, agent roster) wired into `collect-all-inputs.py`
- 3 OPA policies + check metadata + 3 bindings; `POLICY_MAP` +3 (context-gated on `agent`)
- `PROF-AGENTIC-V1` opt-in overlay profile
- ADR-0017 ratified; rollout tracker `docs/implementation/tasks/v4-agent-governance.yaml`

### Changed

- Schema enums: `control` / `mapping-collection` domain += `AGT`; `binding` /
  `repository-compliance` technology_context += `agent`
- `.compliance-manifest.yaml`: declares the `agent` context and `PROF-AGENTIC-V1`
- `self-compliance.yml`: both gates now run the `agent` context, so platform-compliance
  self-enforces AGT-001/002/003

---

## [v1.3.0] — 2026-07-10

### Summary

First increment of ADR-0016 (application & code quality governance). Extends the platform
from infrastructure-only enforcement to governing application source code, beginning with
Go. Adds application-quality (QUA) and testing (TST) control domains and the data collection
needed to evaluate them in CI. Go controls are context-gated and therefore report
`not_applicable` on `platform-compliance` itself (not a Go repository).

Change Records: CHG-20260710-004 (ADR-0016 ratification), CHG-20260710-005 (Phase 1).

### Added

**Foundations:**
- 4 technology contexts: `go`, `node`, `python`, `frontend` (02-taxonomy/technology-contexts.yaml)
- 4 control domains: QUA, TST, API, ARC (02-taxonomy/control-domains.yaml)
- `frontend-app` repository type (02-taxonomy/repository-types.yaml)
- Standards `SRC-GO-STYLE`, `SRC-TESTING-PRACTICES` (01-sources/registry/)

**Go code-quality controls (all block):**
- QUA-001: `golangci-lint` must pass
- QUA-002: `gofmt` formatting must pass
- QUA-003: `go build ./...` must succeed
- QUA-004: `go vet ./...` must pass

**Go testing controls:**
- TST-001: tests exist and `go test` passes (block)
- TST-002: coverage ≥ 70% (warn now; promotes to block at v2.0.0 per ADR-0016)
- TST-003: integration/e2e test present for services (warn, service-scoped)

**Enforcement:**
- `07-policies/scripts/collect-go-info.sh`: detects `go.mod`, runs golangci-lint / gofmt /
  go build / go vet / go test with coverage, detects integration tests; defensively reports
  `unavailable` when the toolchain is absent
- 7 OPA/Rego policies + 7 policy-check manifests (07-policies/opa/QUA, /TST)
- 7 implementation bindings (06-bindings/bindings/go/)
- `collect-all-inputs.py` wires the `go` context to `go-info.json`
- `run-all-policies.py`: +7 context-gated POLICY_MAP entries

### Changed

- `schemas/control.schema.json`, `schemas/mapping-collection.schema.json`: domain enums += QUA, TST, API, ARC
- `schemas/binding.schema.json`, `schemas/repository-compliance.schema.json`: technology_context enums += go, node, python, frontend
- `decisions/ADR-0016-application-quality-governance.md`: accepted

---

## [v1.2.0] — 2026-07-10

### Summary

Operationalizes the compliance backbone in CI and completes a three-tier security hardening
program. Phase A wires the reusable workflow end-to-end (input collection, policy bundle,
evidence, assessment, gates); Groups 1–4 add the profile layer and release packaging; the
security tiers add 17 new controls with policies and profile integration.

### Added

**Phase A operationalization (PC-0108–0111):**
- Input-collection scripts (`07-policies/scripts/`) and helpers feeding the OPA engine
- 8 remaining Phase-A OPA policies; workflow TODO placeholders replaced with real steps
- Bootstrap waiver for single-developer merge process
- Policy bundle packaging (`policies.tar.gz` + SHA-256 + SBOM) via the release workflow

**Profile layer (PC-0124–0127):**
- PROF-BASE, PROF-TERRAFORM-MODULE-V1, PROF-TERRAFORM-ROOT-V1, PROF-SERVICE-V1
- ADR-0009 / ADR-0010 ratified (bundle distribution + profile inheritance)

**Tier 1 security hardening (PC-0165–0187):**
- 6 controls + 5 standards (CIS Controls v8, OWASP SAMM v2, NTIA SBOM, GitHub Security Hardening, NIST CSF v2)
- CodeQL SAST workflow (SEC-005), upgraded to `codeql-action` v4

**Tier 2 security hardening (PC-0188–0197):**
- SUP-004, ACC-001 (2FA), SEC-007, IAC-005, AUD-001 (audit log)

**Tier 3 security hardening (PC-0198–0212):**
- Dependabot vulnerability SLA, license governance (LIC-001), and profile integration of all hardening controls
- MIT `LICENSE` file added (closed the gap caught by LIC-001)

### Changed

- Migrated repository to the `ashuangiras` GitHub account; repository made public to enable branch protection
- `self-compliance.yml`: PRs test their own branch policies (`github.head_ref`) to resolve the bootstrap chicken-and-egg
- Domain enums extended with ACC, AUD, LIC

### Fixed

- Multiple CI pipeline failures: `/tmp/inputs` creation, gitleaks OS casing, `PLATFORM_ADMIN_TOKEN` for admin API calls, `secrets: inherit`, cross-job artifact passing, `pull-requests: write` permission
- OPA `eval_conflict_error` in SEC-004/005, IAC-004, SEC-006, ACC-001 (partial-set + mutual-exclusivity refactors)
- PyYAML parsing YAML `on:` key as Python boolean in reusable-workflow detection
- Reusable-workflow `startup_failure` from a top-level `permissions` block
