# CHANGELOG

All notable changes to `platform-compliance` are recorded here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

### Added

- **Agent operating layer** (`.github/`, `.vscode/`): repo-wide `copilot-instructions.md` with
  universal pre-flight/post-flight checklists; a 7-member specialist agent team under
  `.github/agents/` (compliance-router, control-author, policy-engineer, collector-engineer,
  ci-workflow-engineer, release-manager, compliance-reviewer) with role-scoped tools and
  routing; five file-scoped instruction sets under `.github/instructions/`; a GitHub MCP server
  config (`.vscode/mcp.json`); and a `PreToolUse` safety hook
  (`.github/hooks/guard-destructive-ops.json`) that prompts before irreversible git/filesystem
  operations. Change Record: CHG-20260710-006.

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
