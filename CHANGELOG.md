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
- GitHub: https://github.com/angirasa_risk/platform-compliance
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

### Added

- `schemas/binding.schema.json`: Implementation binding schema
- `schemas/policy-check.schema.json`: Policy check metadata schema
- `schemas/service-contract.schema.json`: Service contract schema with health check, backup, and ingress policy blocks
- `schemas/change-record.schema.json`: Change record schema (CHG-001 artifact)
- `schemas/release-record.schema.json`: Release record schema (CHG-002 artifact)
- `schemas/incident-record.schema.json`: Incident record schema (INC-001 artifact)
- `schemas/adr.schema.json`: ADR metadata schema
- `schemas/assessment.schema.json`: Assessment report schema with 5-result model
- `schemas/evidence.schema.json`: Commit-bound evidence record schema with artifact_hash
- `schemas/mapping.schema.json`: Standard-to-control mapping schema
- `schemas/waiver.schema.json`: Waiver/exception schema
- `schemas/repository-compliance.schema.json`: Repository compliance manifest schema
- `05-mappings/mappings/`: 9 mapping files covering all active controls across all registered standards
- `.compliance-manifest.yaml`: Self-compliance declaration (platform-compliance governs itself)
- `templates/compliance-manifest.template.yaml`: Annotated template for new repositories
- `08-evidence/evidence-model.md`: Evidence model specification
- `08-evidence/evidence-types.yaml`: 28 named evidence types covering all 23 controls
- `09-assessments/assessment-model.md`: Assessment model with evidence-to-result mapping
- `09-assessments/waiver-model.md`: Waiver lifecycle and approval process
- `07-policies/opa/README.md`: OPA engine guide with package naming, input format, output contract
- `workflows/github/reusable-compliance.yml`: 7-job skeleton reusable compliance workflow
- `workflows/github/README.md`: Consuming repository usage guide
- `docs/commit-compliance-flow.md`: Full lifecycle diagram from local commit to deployment gate
- `decisions/ADR-0001-platform-compliance-first.md`: Compliance-first architectural decision
- `decisions/ADR-0002-github-primary-remote.md`: GitHub as initial root of trust
- `decisions/ADR-0003-no-implementation-before-controls.md`: No second repo before v1.0.0 gate
- All directory README stubs (01-sources through tools/)

### Cross-checks passed (PC-0014, PC-0015)

- All control IDs referenced in `PROF-PLATFORM-V1` exist in `03-catalogs/` (CAT-001 and REL-001 are in `not_applicable` section — expected)
- All source IDs cited in control `mapped_standards` fields exist in `01-sources/registry/`
