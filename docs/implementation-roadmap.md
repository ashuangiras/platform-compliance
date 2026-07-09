# Implementation Roadmap: platform-compliance

> **This file has been superseded.**  
> The roadmap has been reorganised into a structured directory.  
> **Go to: [`docs/implementation/`](implementation/)**

| What you need | Location |
|---|---|
| Current state | [`implementation/current-state.md`](implementation/current-state.md) |
| Phase overview and critical path | [`implementation/roadmap.md`](implementation/roadmap.md) |
| Phase detail specs | [`implementation/phases/`](implementation/phases/) |
| All tasks with status | [`implementation/tasks/`](implementation/tasks/) |
| Pending ADR decisions | [`implementation/decisions-needed/`](implementation/decisions-needed/) |

*This file is retained for git history continuity. All updates go to `docs/implementation/`.*

---

## Preamble

This roadmap covers the complete build-out of the `platform-compliance` repository from skeleton to v1.0.0 release-ready. It does not cover infrastructure deployment, service launches, or any downstream repository. When `platform-compliance` reaches its v1.0.0 release gate, the next repository in the platform sequence can begin.

### Current state (as of 2026-07-08)

Phases 1–4 have been partially executed through design work sessions. The following artifacts already exist:

| Artifact | Location | State |
|---|---|---|
| Architecture overview | `docs/architecture-overview.md` | Complete |
| Repository design | `docs/repository-design.md` | Complete |
| Standard source schema | `schemas/standard-source.schema.yaml` | Complete |
| Control schema | `schemas/control.schema.yaml` | Complete |
| Profile schema | `schemas/profile.schema.yaml` | Complete |
| All taxonomy files | `02-taxonomy/*.yaml` | Complete |
| All 9 source registry entries | `01-sources/registry/*.yaml` | Complete |
| All 23 initial controls | `03-catalogs/controls/**/*.yaml` | Complete |
| PROF-PLATFORM-V1 | `04-profiles/PROF-PLATFORM-V1.yaml` | Complete |

The remaining phases (5–12) have not been started. Some artifacts from phases 1–4 are still missing (READMEs for each directory, glossary, templates for all object types, remaining schemas, mappings, bindings, policies, evidence model, assessment model, workflows, self-compliance manifest, and release record).

### Scope boundary

This roadmap ends when `platform-compliance` can pass its own release gate — that is, when the repository itself satisfies `PROF-PLATFORM-V1` and produces a passing assessment report for its own `v1.0.0` tag.

---

## Phase overview

```
Phase  1  Repository skeleton and architecture docs        ██████████ COMPLETE (partial)
Phase  2  Standards registry and taxonomy                  ██████████ COMPLETE
Phase  3  Control catalog and compliance profile           ██████████ COMPLETE
Phase  4  Schemas for all governance objects               ██░░░░░░░░ IN PROGRESS
Phase  5  Mapping and provenance model                     ░░░░░░░░░░ NOT STARTED
Phase  6  Implementation binding model                     ░░░░░░░░░░ NOT STARTED
Phase  7  Policy-as-code structure and initial tests       ░░░░░░░░░░ NOT STARTED
Phase  8  Evidence model and evidence record schema        ░░░░░░░░░░ NOT STARTED
Phase  9  Assessment, finding, waiver, and exception model ░░░░░░░░░░ NOT STARTED
Phase 10  Reusable GitHub workflow design                  ░░░░░░░░░░ NOT STARTED
Phase 11  Repository compliance manifest design            ░░░░░░░░░░ NOT STARTED
Phase 12  Final review and readiness gate                  ░░░░░░░░░░ NOT STARTED
```

---

## Phase 1 — Repository skeleton and architecture docs

### Goal

Establish the complete directory skeleton with READMEs for each directory, finalize the two architecture documents, write the glossary, and add the CHANGELOG stub. The repository must be navigable by someone reading it for the first time.

### Status

**Partially complete.** The two architecture documents exist. The directory skeleton exists (directories were created implicitly when files were placed). The following remain:

- `README.md` files for each numbered directory (`01-sources/`, `02-taxonomy/`, etc.)
- `docs/glossary.md`
- `docs/onboarding.md`  
- `docs/authoring-controls.md` (authoring guide)
- `decisions/README.md`
- `CHANGELOG.md`
- `decisions/ADR-0001-compliance-first-architecture.md`

### Inputs

- `docs/architecture-overview.md` (complete)
- `docs/repository-design.md` (complete)

### Outputs

- Complete navigable skeleton: every directory has a README explaining what lives there and what does not
- `docs/glossary.md`: canonical definitions for all terms used in the system
- `docs/onboarding.md`: where a new contributor starts
- `decisions/ADR-0001`: ratifies the compliance-first architectural decision
- `CHANGELOG.md`: stub ready for first release entry

### Files to create or modify

| Action | File |
|---|---|
| Create | `01-sources/README.md` |
| Create | `02-taxonomy/README.md` |
| Create | `03-catalogs/README.md` |
| Create | `04-profiles/README.md` |
| Create | `05-mappings/README.md` |
| Create | `06-bindings/README.md` |
| Create | `07-policies/README.md` |
| Create | `08-evidence/README.md` |
| Create | `09-assessments/README.md` |
| Create | `schemas/README.md` |
| Create | `templates/README.md` |
| Create | `workflows/README.md` |
| Create | `tools/README.md` |
| Create | `decisions/README.md` |
| Create | `docs/glossary.md` |
| Create | `docs/onboarding.md` |
| Create | `docs/authoring-controls.md` |
| Create | `CHANGELOG.md` |
| Create | `decisions/ADR-0001-compliance-first-architecture.md` |

### Tasks

`PC-0001` `PC-0002` `PC-0003` `PC-0004` (see task list)

### Acceptance criteria

- [ ] Every directory in the repository structure contains a `README.md`
- [ ] Each directory README states: what the directory owns, what file types live there, and what must not be placed there
- [ ] `docs/glossary.md` defines every term used in control and profile YAML files
- [ ] `decisions/ADR-0001` exists with status `accepted` and documents why compliance precedes implementation
- [ ] `CHANGELOG.md` exists with an `[Unreleased]` section

### Validation

```bash
# Every directory has a README
find . -mindepth 1 -maxdepth 2 -type d | while read d; do
  [ -f "$d/README.md" ] || echo "MISSING README: $d"
done

# ADR-0001 exists and contains "accepted"
grep -i "status.*accepted" decisions/ADR-0001*.md
```

### Risks

- READMEs that are too terse provide no value; READMEs that are too detailed become stale
- ADR-0001 may uncover unresolved design questions that require iteration

### Must not

- No control definitions, schemas, or policies
- No tool code
- No workflow code
- Do not attempt to make the repository pass its own compliance gate yet

---

## Phase 2 — Standards registry and taxonomy

### Goal

The standards source registry and platform taxonomy are the provenance root and the shared vocabulary of the entire system. Both must be complete and stable before controls can reference them.

### Status

**Complete.** All 9 source registry entries and all taxonomy files have been created. The schema for standard sources has been defined.

### Inputs

- `schemas/standard-source.schema.yaml`
- `docs/repository-design.md` (taxonomy design)

### Outputs

- 9 source registry entries in `01-sources/registry/`
- 7 taxonomy vocabulary files in `02-taxonomy/`

### Files to create or modify

All files in this phase have been created. The only remaining work is:

| Action | File |
|---|---|
| Create | `01-sources/README.md` (Phase 1 task) |
| Create | `02-taxonomy/README.md` (Phase 1 task) |
| Validate | All `01-sources/registry/*.yaml` against `schemas/standard-source.schema.yaml` |
| Validate | All `02-taxonomy/*.yaml` for internal consistency |

### Tasks

`PC-0005` `PC-0006` `PC-0007` (see task list)

### Acceptance criteria

- [ ] 9 source entries exist in `01-sources/registry/`, each with a unique `id` matching the filename
- [ ] All source entries have `status: active` or `status: deferred`
- [ ] All source entries with `role: adapted` have a non-empty `notes` field documenting the adaptation
- [ ] All taxonomy files enumerate valid values with descriptions
- [ ] No control in `03-catalogs/` references a source ID that does not exist in `01-sources/registry/`
- [ ] `[PLACEHOLDER: ...]` markers are present for all details requiring future research (not empty fields)

### Validation

```bash
# Extract all source IDs cited in controls
grep -r "source_id:" 03-catalogs/ | awk '{print $NF}' | sort -u > /tmp/cited_sources.txt

# Extract all registered source IDs
grep "^id:" 01-sources/registry/*.yaml | awk '{print $2}' | sort -u > /tmp/registered_sources.txt

# Find any cited source that is not registered
comm -23 /tmp/cited_sources.txt /tmp/registered_sources.txt
# Expected output: empty (no unregistered citations)
```

### Risks

- Source IDs used in controls may drift from the IDs in the registry if names change
- Taxonomy values added informally (not in the taxonomy files) will break schema validation later

### Must not

- Do not create mappings in this phase (Phase 5)
- Do not create policy code
- Do not pin specific clause references — use `[PLACEHOLDER: ...]` for unresearched clauses

---

## Phase 3 — Control catalog and compliance profile

### Goal

The control catalog is the authoritative list of what must be satisfied. The compliance profile is how downstream repositories know which controls apply to them. Both must be coherent, cross-referenced, and internally consistent.

### Status

**Complete.** 23 controls across 10 domains and `PROF-PLATFORM-V1.yaml` have been created.

### Inputs

- `schemas/control.schema.yaml`
- `schemas/profile.schema.yaml`
- `02-taxonomy/` (all files)
- `01-sources/registry/` (all files)

### Outputs

- 23 control YAML files in `03-catalogs/controls/{DOMAIN}/`
- `04-profiles/PROF-PLATFORM-V1.yaml`

### Files to create or modify

All control and profile files have been created. Remaining work:

| Action | File |
|---|---|
| Validate | All control files against `schemas/control.schema.yaml` |
| Validate | `PROF-PLATFORM-V1.yaml` against `schemas/profile.schema.yaml` |
| Verify | Every control in the profile exists in the catalog |
| Create | `03-catalogs/README.md` |
| Create | `04-profiles/README.md` |

### Tasks

`PC-0008` `PC-0009` `PC-0010` (see task list)

### Acceptance criteria

- [ ] 23 control files exist, one per control ID, in the matching domain subdirectory
- [ ] Every control has all 15 required fields populated (no empty required fields)
- [ ] Every active control has at least one `mapped_standards` entry
- [ ] Every control has `lifecycle_status: active` or `lifecycle_status: deferred` (no undefined status)
- [ ] `PROF-PLATFORM-V1.yaml` references only control IDs that exist in the catalog
- [ ] Every gate in the profile includes only controls whose `failure_applies_to` is consistent with the gate
- [ ] Profile `deferred` controls have `lifecycle_status: deferred` in the catalog

### Validation

```bash
# Extract all control IDs from profile
grep "^\s*- id:" 04-profiles/PROF-PLATFORM-V1.yaml | awk '{print $NF}' | sort -u > /tmp/profile_controls.txt

# Extract all control IDs from catalog
find 03-catalogs/controls -name "*.yaml" -exec grep "^id:" {} \; | awk '{print $2}' | sort -u > /tmp/catalog_controls.txt

# Find profile entries not in catalog
comm -23 /tmp/profile_controls.txt /tmp/catalog_controls.txt
# Expected output: empty
```

### Risks

- A control may be referenced in the profile under the wrong scope condition, silently excluding repos that should be checked
- Controls with both `failure_behavior: block` and `failure_behavior: warn` for different gates may be misread (the control schema needs to support per-gate overrides)

### Must not

- Do not create implementation bindings (Phase 6)
- Do not add policy code inside control files
- Do not create controls for CAT or REL domains in Phase 3 — these are deferred

---

## Phase 4 — Schemas for all governance objects

### Goal

Every structured object type in the system must have a machine-readable schema. The three primary schemas (standard-source, control, profile) already exist. The remaining 12 schema files must be written and validated before any instances of those types are created.

### Status

**In progress.** 3 of 15 schemas complete. 12 schemas still required.

### Inputs

- `docs/repository-design.md` (§4 — Key object type definitions)
- Existing schemas as reference for conventions

### Outputs

Twelve new schema files in `schemas/`:

| Schema file | Object type |
|---|---|
| `mapping.schema.yaml` | Standard-to-control mapping |
| `binding.schema.yaml` | Implementation binding |
| `policy-check.schema.yaml` | Policy check metadata |
| `evidence-record.schema.yaml` | Evidence record |
| `assessment-report.schema.yaml` | Assessment report |
| `waiver.schema.yaml` | Waiver / exception |
| `compliance-manifest.schema.yaml` | Repository compliance manifest |
| `service-contract.schema.yaml` | Service contract |
| `adr.schema.yaml` | ADR front matter |
| `change-record.schema.yaml` | Change record |
| `release-record.schema.yaml` | Release record |
| `incident-record.schema.yaml` | Incident record |

### Files to create or modify

| Action | File |
|---|---|
| Create | `schemas/mapping.schema.yaml` |
| Create | `schemas/binding.schema.yaml` |
| Create | `schemas/policy-check.schema.yaml` |
| Create | `schemas/evidence-record.schema.yaml` |
| Create | `schemas/assessment-report.schema.yaml` |
| Create | `schemas/waiver.schema.yaml` |
| Create | `schemas/compliance-manifest.schema.yaml` |
| Create | `schemas/service-contract.schema.yaml` |
| Create | `schemas/adr.schema.yaml` |
| Create | `schemas/change-record.schema.yaml` |
| Create | `schemas/release-record.schema.yaml` |
| Create | `schemas/incident-record.schema.yaml` |
| Create | `schemas/README.md` |
| Create | `templates/` stubs for each schema |

### Tasks

`PC-0011` `PC-0012` `PC-0013` `PC-0014` `PC-0015` `PC-0016` (see task list)

### Acceptance criteria

- [ ] 15 schema files exist in `schemas/` (3 existing + 12 new)
- [ ] Every schema has a `$id`, `schemaVersion`, `title`, and `description`
- [ ] Every schema has at minimum a `required` array and `additionalProperties: false`
- [ ] Every field in each schema that references another object type uses the pattern-based ID format matching that type's convention
- [ ] A test YAML instance created from each schema's required fields passes validation
- [ ] A deliberately invalid YAML instance (missing required field) fails validation

### Validation

```bash
# Install a YAML+JSONSchema validator (e.g., check-jsonschema)
pip install check-jsonschema

# Validate a schema file itself is valid JSON Schema
check-jsonschema --check-metaschema schemas/evidence-record.schema.yaml

# Validate a test instance against its schema (example)
check-jsonschema --schemafile schemas/evidence-record.schema.yaml \
  schemas/test-fixtures/evidence-record-valid.yaml
```

### Risks

- Schema design decisions made here propagate to all tooling; an error in a field name or type is expensive to fix after instances exist
- JSON Schema `$ref` resolution may require schema bundling if schemas cross-reference each other
- Schema versioning strategy must be decided before first release (see PC-0011)

### Must not

- Do not create object instances in this phase — schemas only
- Do not add validation logic outside of schemas (no custom validation scripts yet)
- Do not use `$ref` to external schemas — keep all schemas self-contained in v1

---

## Phase 5 — Mapping and provenance model

### Goal

Every active control must have at least one mapping record that links it to a specific clause in a registered standard. Mappings are the machine-readable proof of provenance. Phase 5 produces the first complete set of mapping files and closes the open `[PLACEHOLDER: ...]` clause references where research is sufficient.

### Status

**Not started.** Controls contain inline `mapped_standards` references but no formal mapping records exist in `05-mappings/`.

### Inputs

- `01-sources/registry/` (all source entries)
- `03-catalogs/controls/` (all control files)
- `schemas/mapping.schema.yaml` (from Phase 4)

### Outputs

Mapping YAML files in `05-mappings/mappings/`, grouped by source:

| File | Covers |
|---|---|
| `MAP-OPENSSF-SCORECARD-SRC.yaml` | Scorecard → SRC domain controls |
| `MAP-OPENSSF-SCORECARD-SEC.yaml` | Scorecard → SEC domain controls |
| `MAP-OPENSSF-SCORECARD-SUP.yaml` | Scorecard → SUP domain controls |
| `MAP-OPENSSF-SLSA-SUP.yaml` | SLSA → SUP domain controls |
| `MAP-CIS-DOCKER-RUN.yaml` | CIS Docker → RUN domain controls |
| `MAP-CIS-DOCKER-SEC.yaml` | CIS Docker → SEC domain controls |
| `MAP-OPENGITOPS-IAC.yaml` | OpenGitOps → IAC/SRC/SUP controls |
| `MAP-GOOGLE-SRE-OBS.yaml` | Google SRE → OBS/BAK/INC controls |
| `MAP-AWS-WAF-OBS.yaml` | AWS WAF → OBS/SEC/NET/BAK controls |
| `MAP-ITIL-ADAPTED-CHG.yaml` | ITIL → CHG/INC controls |
| `MAP-NYGARD-ADR-DOC.yaml` | Nygard ADR → DOC controls |

### Files to create or modify

| Action | File |
|---|---|
| Create | `05-mappings/README.md` |
| Create | `05-mappings/mappings/MAP-OPENSSF-SCORECARD-SRC.yaml` |
| Create | `05-mappings/mappings/MAP-OPENSSF-SCORECARD-SEC.yaml` |
| Create | `05-mappings/mappings/MAP-OPENSSF-SCORECARD-SUP.yaml` |
| Create | `05-mappings/mappings/MAP-OPENSSF-SLSA-SUP.yaml` |
| Create | `05-mappings/mappings/MAP-CIS-DOCKER-RUN.yaml` |
| Create | `05-mappings/mappings/MAP-CIS-DOCKER-SEC.yaml` |
| Create | `05-mappings/mappings/MAP-OPENGITOPS-IAC.yaml` |
| Create | `05-mappings/mappings/MAP-GOOGLE-SRE-OBS.yaml` |
| Create | `05-mappings/mappings/MAP-AWS-WAF-OBS.yaml` |
| Create | `05-mappings/mappings/MAP-ITIL-ADAPTED-CHG.yaml` |
| Create | `05-mappings/mappings/MAP-NYGARD-ADR-DOC.yaml` |
| Update | Each active control: add `source_mapping_ids` references to the formal mapping IDs |

### Tasks

`PC-0017` `PC-0018` `PC-0019` `PC-0020` (see task list)

### Acceptance criteria

- [ ] Every active control has at least one mapping ID in `source_mapping_ids`
- [ ] Every mapping ID referenced in a control exists as a formal mapping record in `05-mappings/`
- [ ] Every mapping record references a valid source ID from `01-sources/registry/`
- [ ] Every mapping record has a non-empty `rationale` field
- [ ] `[PLACEHOLDER: ...]` markers remain only for clause details that genuinely require document access; mapping records exist for all controls regardless
- [ ] Deferred controls (SRC-004, SUP-003) are allowed to have no mapping records

### Validation

```bash
# Extract mapping IDs referenced in controls
grep -r "source_mapping_ids" 03-catalogs/ | grep -v "^#" | ...
# (CLI tool or script to verify referential integrity)

# Verify all active controls have at least one mapping
for f in $(find 03-catalogs/controls -name "*.yaml"); do
  status=$(grep "lifecycle_status:" "$f" | awk '{print $2}')
  if [ "$status" = "active" ]; then
    mappings=$(grep -c "source_mapping_ids" "$f" || echo 0)
    [ "$mappings" -eq 0 ] && echo "NO MAPPING: $f"
  fi
done
```

### Risks

- Researching exact clause references in standards (especially CIS Docker, NIST, SLSA) requires document access; some `[PLACEHOLDER: ...]` markers may persist into v1
- Mapping records that use overly broad clause references (e.g., just the chapter number) may not satisfy a future audit

### Must not

- Do not create implementation bindings (Phase 6)
- Do not modify control statements to match standards — map the standard to the control as-written; if the standard does not support the control statement, revise the statement in Phase 3 work
- Do not register new standards in Phase 5 — only use already-registered sources

---

## Phase 6 — Implementation binding model

### Goal

For each active control, define at least one implementation binding per applicable technology context. A binding describes in prose exactly what observable artifact or condition satisfies the control in that context. Bindings are the authoritative specification that policy code (Phase 7) implements.

### Status

**Not started.** No binding files exist in `06-bindings/`.

### Inputs

- `schemas/binding.schema.yaml` (from Phase 4)
- `03-catalogs/controls/` (all control files)
- `02-taxonomy/technology-contexts.yaml`

### Outputs

Binding YAML files in `06-bindings/bindings/{context}/`, at minimum:

| Context | Controls to bind |
|---|---|
| `github/` | SRC-001, SRC-002, SRC-003, SEC-001, SEC-002, SEC-003, CHG-001, CHG-002, DOC-001 |
| `terraform/` | IAC-001, IAC-002, IAC-003, SUP-001 |
| `docker/` | RUN-001, RUN-002, RUN-003, SUP-002, OBS-001 |
| `github-actions/` | SUP-001 (action pinning), SUP-002 (image refs in workflows) |

Minimum binding count for v1: **one binding per active control per applicable context** = approximately 25–30 binding files.

### Files to create or modify

| Action | File |
|---|---|
| Create | `06-bindings/README.md` |
| Create | `06-bindings/bindings/github/BIND-SRC-001-GITHUB.yaml` |
| Create | `06-bindings/bindings/github/BIND-SRC-002-GITHUB.yaml` |
| Create | `06-bindings/bindings/github/BIND-SRC-003-GITHUB.yaml` |
| Create | `06-bindings/bindings/github/BIND-SEC-001-GITHUB.yaml` |
| Create | `06-bindings/bindings/github/BIND-SEC-002-GITHUB.yaml` |
| Create | `06-bindings/bindings/github/BIND-SEC-003-GITHUB.yaml` |
| Create | `06-bindings/bindings/github/BIND-DOC-001-GITHUB.yaml` |
| Create | `06-bindings/bindings/github/BIND-CHG-001-GITHUB.yaml` |
| Create | `06-bindings/bindings/github/BIND-CHG-002-GITHUB.yaml` |
| Create | `06-bindings/bindings/terraform/BIND-IAC-001-TERRAFORM.yaml` |
| Create | `06-bindings/bindings/terraform/BIND-IAC-002-TERRAFORM.yaml` |
| Create | `06-bindings/bindings/terraform/BIND-IAC-003-TERRAFORM.yaml` |
| Create | `06-bindings/bindings/terraform/BIND-SUP-001-TERRAFORM.yaml` |
| Create | `06-bindings/bindings/docker/BIND-RUN-001-DOCKER.yaml` |
| Create | `06-bindings/bindings/docker/BIND-RUN-002-DOCKER.yaml` |
| Create | `06-bindings/bindings/docker/BIND-RUN-003-DOCKER.yaml` |
| Create | `06-bindings/bindings/docker/BIND-SUP-002-DOCKER.yaml` |
| Create | `06-bindings/bindings/docker/BIND-OBS-001-DOCKER.yaml` |
| Create | `06-bindings/bindings/github-actions/BIND-SUP-001-GITHUB-ACTIONS.yaml` |
| Stub | Bindings for manual_initially controls (OBS-002, BAK-001, NET-001, INC-001, DOC-002) |

### Tasks

`PC-0021` `PC-0022` `PC-0023` `PC-0024` (see task list)

### Acceptance criteria

- [ ] Every active control with `automation_status: automated` or `partially-automated` has at least one binding in the applicable technology context
- [ ] Every binding references a valid control ID
- [ ] Every binding specifies a machine-locatable `observable_artifact`
- [ ] Every binding lists at least one `policy_check_id` reference (may be a planned ID not yet implemented)
- [ ] Manual controls have binding stubs marking `automation_status: manual` with attestation instructions

### Validation

```bash
# Check all bindings reference valid control IDs
for f in $(find 06-bindings -name "BIND-*.yaml"); do
  control_id=$(grep "^control_id:" "$f" | awk '{print $2}')
  catalog_file="03-catalogs/controls/$(echo $control_id | cut -d- -f1)/${control_id}.yaml"
  [ -f "$catalog_file" ] || echo "MISSING CONTROL for binding: $f (looked for $catalog_file)"
done
```

### Risks

- Binding specifications may over-specify implementation details that belong in policy code, or under-specify and leave policy authors guessing
- The same control may need bindings for contexts not yet defined in the taxonomy — if a new context is needed, add it to taxonomy first (blocking dependency)

### Must not

- Do not write executable policy code (Phase 7) — bindings are prose specifications only
- Do not bind deferred controls
- Do not create context directories for technology contexts not in `02-taxonomy/technology-contexts.yaml`

---

## Phase 7 — Policy-as-code structure and initial policy tests

### Goal

Establish the policy execution toolchain, create the policy directory structure, author policy checks for all automated controls, and create a test fixture for each policy to verify it produces the expected pass/fail result.

### Status

**Not started.** Policy engine toolchain has not been selected (ADR required). No files exist in `07-policies/`.

### Inputs

- Resolved ADR for policy engine selection (PC-0025 — see tasks)
- `06-bindings/bindings/` (all binding files)
- `schemas/policy-check.schema.yaml` (from Phase 4)

### Outputs

Policy files in `07-policies/{engine}/{DOMAIN}/`:

Minimum for v1 (automated controls only):

| Policy | Binding | Engine |
|---|---|---|
| `POL-SRC-001-GITHUB.{ext}` | BIND-SRC-001-GITHUB | TBD |
| `POL-SRC-002-GITHUB.{ext}` | BIND-SRC-002-GITHUB | TBD |
| `POL-SRC-003-GITHUB.{ext}` | BIND-SRC-003-GITHUB | TBD |
| `POL-SEC-001-GITHUB.{ext}` | BIND-SEC-001-GITHUB | TBD |
| `POL-SEC-002-GITHUB.{ext}` | BIND-SEC-002-GITHUB | TBD |
| `POL-IAC-001-TERRAFORM.{ext}` | BIND-IAC-001-TERRAFORM | TBD |
| `POL-SUP-001-TERRAFORM.{ext}` | BIND-SUP-001-TERRAFORM | TBD |
| `POL-SUP-002-DOCKER.{ext}` | BIND-SUP-002-DOCKER | TBD |
| `POL-RUN-002-DOCKER.{ext}` | BIND-RUN-002-DOCKER | TBD |
| `POL-DOC-001-GITHUB.{ext}` | BIND-DOC-001-GITHUB | TBD |

Plus: a metadata companion file for each policy check, conforming to `schemas/policy-check.schema.yaml`.

### Files to create or modify

| Action | File |
|---|---|
| Create | `decisions/ADR-0002-policy-engine-selection.md` |
| Create | `07-policies/README.md` |
| Create | `07-policies/{engine}/README.md` |
| Create | One policy file per automated control (10 minimum) |
| Create | One metadata companion `.check.yaml` per policy file |
| Create | `07-policies/tests/` directory with fixture files |
| Create | At least one passing test fixture and one failing test fixture per policy |

### Tasks

`PC-0025` `PC-0026` `PC-0027` `PC-0028` `PC-0029` (see task list)

### Acceptance criteria

- [ ] ADR-0002 exists with status `accepted` specifying the chosen policy engine
- [ ] Every automated control has at least one policy file
- [ ] Every policy file has a companion `.check.yaml` metadata file
- [ ] Every policy passes its "should pass" test fixture
- [ ] Every policy produces a failing result for its "should fail" test fixture
- [ ] All policies produce structured output (JSON) suitable for ingestion into the evidence system
- [ ] No policy file exists without a corresponding binding in `06-bindings/`

### Validation

```bash
# Run all policy tests (command depends on chosen engine)
# Example for OPA/Rego:
opa test 07-policies/rego/... --verbose

# Example for Conftest:
conftest test --policy 07-policies/conftest/ tests/fixtures/

# Verify every automated control has a policy
for f in $(find 03-catalogs/controls -name "*.yaml"); do
  automation=$(grep "automation_status:" "$f" | awk '{print $2}')
  if [ "$automation" = "automated" ]; then
    id=$(grep "^id:" "$f" | awk '{print $2}')
    count=$(find 07-policies -name "POL-${id}*.{rego,yaml,sh}" 2>/dev/null | wc -l)
    [ "$count" -eq 0 ] && echo "NO POLICY: $id"
  fi
done
```

### Risks

- Policy engine choice is a load-bearing decision that affects workflow design, CI toolchain, and all downstream repositories — the ADR process must not be rushed
- Test fixtures must reflect real-world inputs, not toy examples — collecting representative fixtures from GitHub API responses and Dockerfile examples requires research
- Policies that produce false positives will erode trust in the system faster than missing policies

### Must not

- Do not write policies for deferred or manual controls
- Do not embed policy logic directly in GitHub Actions workflow YAML — policy logic belongs in the `07-policies/` directory and is called by workflows
- Do not hardcode repository names, organisation names, or environment values in policy code

---

## Phase 8 — Evidence model and evidence record schema

### Goal

Define the complete evidence system: the schema for evidence records, the format and retention rules for the evidence ledger, the process by which evidence is collected, and validation tooling that confirms a given evidence record is structurally valid.

### Status

**Not started.** `evidence-record.schema.yaml` is listed in the schemas to create in Phase 4 but has not yet been written.

### Inputs

- `schemas/evidence-record.schema.yaml` (created in Phase 4)
- `03-catalogs/controls/` (evidence_required fields define what evidence each control needs)
- Policy check output examples from Phase 7

### Outputs

| Artifact | Location |
|---|---|
| Evidence record schema (finalized) | `schemas/evidence-record.schema.yaml` |
| Ledger format specification | `08-evidence/ledger/format.md` |
| Evidence collection guide | `08-evidence/README.md` |
| `collected/` directory stub | `08-evidence/collected/README.md` |
| Test fixtures | `08-evidence/schema/test-fixtures/` |

### Files to create or modify

| Action | File |
|---|---|
| Create | `08-evidence/README.md` |
| Create | `08-evidence/ledger/format.md` |
| Create | `08-evidence/ledger/retention.md` |
| Create | `08-evidence/schema/README.md` |
| Create | `08-evidence/collected/README.md` |
| Create | `08-evidence/schema/test-fixtures/valid-pass.yaml` |
| Create | `08-evidence/schema/test-fixtures/valid-fail.yaml` |
| Create | `08-evidence/schema/test-fixtures/valid-waived.yaml` |
| Create | `08-evidence/schema/test-fixtures/invalid-missing-required.yaml` |
| Finalize | `schemas/evidence-record.schema.yaml` (from Phase 4 draft) |

### Tasks

`PC-0030` `PC-0031` `PC-0032` (see task list)

### Acceptance criteria

- [ ] `schemas/evidence-record.schema.yaml` validates all four test fixtures correctly (3 valid pass, 1 invalid fails)
- [ ] The ledger format document specifies: directory structure, file naming convention, indexing mechanism, and retention policy
- [ ] The `collected/` directory structure is defined: one subdirectory per `angirasa_risk/{repo}`, one file per `{commit-sha}-{control-id}-{timestamp}.yaml`
- [ ] Evidence records produced by Phase 7 policy checks conform to the schema
- [ ] The schema enforces that `result: waived` requires a non-null `waiver_id`
- [ ] The schema enforces that `result: pass` or `result: fail` for automated controls requires a non-null `policy_check_id`

### Validation

```bash
check-jsonschema --check-metaschema schemas/evidence-record.schema.yaml

check-jsonschema --schemafile schemas/evidence-record.schema.yaml \
  08-evidence/schema/test-fixtures/valid-pass.yaml
check-jsonschema --schemafile schemas/evidence-record.schema.yaml \
  08-evidence/schema/test-fixtures/valid-fail.yaml

# This must fail (invalid):
check-jsonschema --schemafile schemas/evidence-record.schema.yaml \
  08-evidence/schema/test-fixtures/invalid-missing-required.yaml \
  && echo "SCHEMA ERROR: should have rejected invalid fixture"
```

### Risks

- Evidence records grow large over time; retention and archival strategy must be decided before the first real evidence is written
- The `collected/` directory write-access control is critical — only the CI system should be allowed to write evidence; human submissions require strict review

### Must not

- Do not create actual evidence records for platform-compliance in this phase — evidence collection begins in Phase 12 (the self-assessment)
- Do not define evidence aggregation queries or dashboard tooling — that is out of scope for v1

---

## Phase 9 — Assessment, finding, waiver, and exception model

### Goal

Define the complete assessment system: assessment reports, gate criteria files, the waiver/exception model, and the templates for each. The gate criteria files for release and deployment gates must be machine-readable and consumed by the workflows in Phase 10.

### Status

**Not started.** No files exist in `09-assessments/`.

### Inputs

- `schemas/assessment-report.schema.yaml` (from Phase 4)
- `schemas/waiver.schema.yaml` (from Phase 4)
- `04-profiles/PROF-PLATFORM-V1.yaml` (gate criteria are derived from profile gates)
- `08-evidence/` (evidence schema, from Phase 8)

### Outputs

| Artifact | Location |
|---|---|
| Release gate criteria | `09-assessments/gates/release-gate.yaml` |
| Deployment gate criteria | `09-assessments/gates/deployment-gate.yaml` |
| Assessment report template | `09-assessments/templates/assessment-report.template.yaml` |
| Waiver template | `templates/waiver.template.yaml` |
| Waiver process ADR | `decisions/ADR-0003-waiver-approval-process.md` |
| Test assessment report fixtures | `09-assessments/templates/test-fixtures/` |

### Files to create or modify

| Action | File |
|---|---|
| Create | `09-assessments/README.md` |
| Create | `09-assessments/gates/release-gate.yaml` |
| Create | `09-assessments/gates/deployment-gate.yaml` |
| Create | `09-assessments/templates/assessment-report.template.yaml` |
| Create | `09-assessments/reports/README.md` |
| Create | `09-assessments/waivers/README.md` |
| Create | `templates/waiver.template.yaml` |
| Create | `templates/compliance-manifest.template.yaml` |
| Create | `decisions/ADR-0003-waiver-approval-process.md` |

### Tasks

`PC-0033` `PC-0034` `PC-0035` `PC-0036` (see task list)

### Gate criteria file structure

The gate criteria files are the machine-readable source of truth consumed by CI workflows. They must be derived from the profile gates but expressed in a format that the workflow tooling can evaluate directly.

```yaml
# 09-assessments/gates/release-gate.yaml (structure)
gate_id: release-gate
version: "1.0.0"
profile_id: PROF-PLATFORM-V1
description: "..."
pass_criteria:
  - type: control-check
    control_id: SRC-001
    enforcement: block
    scope_condition: null         # always applies
  - type: control-check
    control_id: IAC-001
    enforcement: block
    scope_condition: "repository.type in ['terraform-module', 'terraform-root']"
  # ... all blocking controls
fail_fast: false   # evaluate all controls before reporting
```

### Acceptance criteria

- [ ] `release-gate.yaml` lists all blocking controls from `PROF-PLATFORM-V1.release_gate`
- [ ] `deployment-gate.yaml` lists all blocking controls from `PROF-PLATFORM-V1.deployment_gate`
- [ ] Gate criteria files can be loaded and parsed by a script without errors
- [ ] ADR-0003 exists with status `accepted` and documents the waiver approval process, escalation path, and expiry policy
- [ ] Assessment report template includes all fields from `schemas/assessment-report.schema.yaml`
- [ ] A test assessment report (passing) and a test assessment report (failing) exist as fixtures and validate against the schema

### Validation

```bash
# Verify gate files are valid YAML
python -c "import yaml; yaml.safe_load(open('09-assessments/gates/release-gate.yaml'))"
python -c "import yaml; yaml.safe_load(open('09-assessments/gates/deployment-gate.yaml'))"

# Cross-check: every blocking control in profile.release_gate appears in release-gate.yaml
# (requires a comparison script in tools/)
```

### Risks

- Gate criteria files that diverge from the profile become a split source of truth — the gate files must be generated from (or validated against) the profile, not authored independently
- The waiver approval process involves human judgement at multiple levels — if the process is too burdensome, it will be bypassed informally

### Must not

- Do not generate actual assessment reports in this phase — the first real assessment happens in Phase 12
- Do not define incident records in this phase — that is a separate record type handled by Phase 12

---

## Phase 10 — Reusable GitHub workflow design

### Goal

Design and write the five reusable GitHub Actions workflows that implement the compliance check pipeline for all downstream repositories. The workflows call the policies from Phase 7, collect evidence conforming to Phase 8's schema, and evaluate gates defined in Phase 9.

### Status

**Not started.** No workflow files exist in `workflows/`.

### Inputs

- `07-policies/` (all policy files and metadata)
- `08-evidence/schema/` (evidence record schema)
- `09-assessments/gates/` (gate criteria files)
- `schemas/compliance-manifest.schema.yaml` (from Phase 4)

### Outputs

Five reusable workflow files in `workflows/`:

| Workflow | Trigger | Produces |
|---|---|---|
| `compliance-check.yaml` | PR, push | Validates manifest; identifies in-scope controls |
| `evidence-collect.yaml` | Called by compliance-check | Runs policies; writes evidence records |
| `assessment-generate.yaml` | PR merge, release | Generates assessment report from evidence |
| `release-gate.yaml` | Tag creation | Evaluates release gate; passes or blocks |
| `deployment-gate.yaml` | Deployment trigger | Evaluates deployment gate; passes or blocks |

### Files to create or modify

| Action | File |
|---|---|
| Create | `workflows/README.md` |
| Create | `workflows/compliance-check.yaml` |
| Create | `workflows/evidence-collect.yaml` |
| Create | `workflows/assessment-generate.yaml` |
| Create | `workflows/release-gate.yaml` |
| Create | `workflows/deployment-gate.yaml` |
| Create | `.github/workflows/self-compliance.yaml` (this repo's own CI using the above) |

### Tasks

`PC-0037` `PC-0038` `PC-0039` `PC-0040` `PC-0041` (see task list)

### Workflow design constraints

- All workflows must be reusable (`workflow_call` trigger), not directly triggered
- Input parameters must include: `profile-id`, `repository-type`, `technology-contexts`
- Output must include: `assessment-result` (pass/fail), `assessment-report-path`
- Workflows must be version-pinned when referenced by consuming repositories
- No workflow may embed policy logic — it calls `07-policies/` files
- Evidence must be written as a workflow artifact (not only as a log)

### Acceptance criteria

- [ ] All 5 workflow files are valid GitHub Actions YAML (parseable by `actionlint`)
- [ ] Each workflow has a `workflow_call` trigger with documented inputs and outputs
- [ ] `self-compliance.yaml` runs `compliance-check` and `evidence-collect` on every PR to `platform-compliance`
- [ ] A dry-run of `release-gate.yaml` against a test repository produces a structured JSON output
- [ ] Workflows reference policies by path (not by inline code)
- [ ] Workflow input validation prevents running without a valid `profile-id`

### Validation

```bash
# Validate workflow YAML syntax
pip install actionlint-py
actionlint workflows/*.yaml
actionlint .github/workflows/self-compliance.yaml

# Dry-run compliance check on platform-compliance itself
gh workflow run compliance-check.yaml \
  --ref main \
  -f profile-id=PROF-PLATFORM-V1 \
  -f repository-type=platform-repo
```

### Risks

- GitHub Actions reusable workflow limitations (e.g., secrets propagation, output size limits) may require design workarounds
- The `self-compliance.yaml` workflow must not create a circular dependency — the workflow that checks this repository must be usable before the repository passes its own gate

### Must not

- Do not build a compliance dashboard in this phase
- Do not implement deployment automation (Atlantis, GitOps controller) — only gate workflows
- Do not pin to any specific version of `platform-compliance` inside these workflows — the workflows use relative paths within the repository

---

## Phase 11 — Repository compliance manifest design

### Goal

Define the `.compliance-manifest.yaml` format that every downstream repository must create, write the template and consumption guide, and write `platform-compliance`'s own compliance manifest. The manifest is the entry point for all downstream compliance.

### Status

**Not started.** No compliance manifest files or templates exist.

### Inputs

- `schemas/compliance-manifest.schema.yaml` (from Phase 4)
- `04-profiles/PROF-PLATFORM-V1.yaml`
- `02-taxonomy/repository-types.yaml`
- `02-taxonomy/technology-contexts.yaml`

### Outputs

| Artifact | Location |
|---|---|
| Compliance manifest schema (finalized) | `schemas/compliance-manifest.schema.yaml` |
| Compliance manifest template | `templates/compliance-manifest.template.yaml` |
| Consumption guide | `docs/consuming-compliance.md` |
| platform-compliance's own manifest | `.compliance-manifest.yaml` (repo root) |
| Service contract template | `templates/service-contract.template.yaml` |

### Files to create or modify

| Action | File |
|---|---|
| Create | `templates/compliance-manifest.template.yaml` |
| Create | `templates/service-contract.template.yaml` |
| Create | `templates/adr.template.md` |
| Create | `templates/waiver.template.yaml` (if not done in Phase 9) |
| Create | `templates/control.template.yaml` |
| Create | `templates/README.md` |
| Create | `docs/consuming-compliance.md` |
| Create | `.compliance-manifest.yaml` (platform-compliance's own declaration) |

### platform-compliance's own manifest

```yaml
# .compliance-manifest.yaml
schema_version: "1.0.0"
repository:
  name: platform-compliance
  url: https://github.com/angirasa_risk/platform-compliance
  type: platform-repo
declared_profiles:
  - PROF-PLATFORM-V1
technology_contexts:
  - github
  - github-actions
compliance_contact: platform-team
last_updated: "2026-07-08"
```

### Tasks

`PC-0042` `PC-0043` `PC-0044` `PC-0045` (see task list)

### Acceptance criteria

- [ ] `templates/compliance-manifest.template.yaml` validates against `schemas/compliance-manifest.schema.yaml`
- [ ] `.compliance-manifest.yaml` at the repository root validates against the schema
- [ ] `docs/consuming-compliance.md` covers: how to create a manifest, how to declare a profile, how to request a waiver, how to read an assessment report, how to reference workflows
- [ ] All templates in `templates/` are valid instances of their corresponding schema (required fields populated with representative values)
- [ ] `templates/README.md` lists all templates with brief descriptions

### Validation

```bash
check-jsonschema --schemafile schemas/compliance-manifest.schema.yaml \
  .compliance-manifest.yaml

check-jsonschema --schemafile schemas/compliance-manifest.schema.yaml \
  templates/compliance-manifest.template.yaml
```

### Risks

- The consuming guide must anticipate the questions a new repository owner will have — if it is incomplete, the first downstream repository will reveal the gaps
- `.compliance-manifest.yaml` at the root is the first file checked by the compliance workflow — any error here will block the first CI run of `platform-compliance` itself

### Must not

- Do not create compliance manifests for future repositories (each repo creates its own)
- Do not define service contracts for platform-compliance (it is not a service)

---

## Phase 12 — Final review and readiness gate for the next repository

### Goal

Run `platform-compliance`'s own release gate against itself, produce the first self-assessment report, collect evidence for all mandatory controls, resolve or waive any failures, and publish `v1.0.0`. After this phase, the first downstream repository can be created.

### Status

**Not started.** All preceding phases must be complete.

### Inputs

All preceding phases complete:
- Workflows running in CI (`self-compliance.yaml`)
- `.compliance-manifest.yaml` present and valid
- All mandatory active controls have bindings and policies
- Gate criteria files exist

### Outputs

| Artifact | Location |
|---|---|
| Evidence records from CI | `08-evidence/collected/platform-compliance/` |
| Self-assessment report | `09-assessments/reports/platform-compliance/` |
| First release record | `09-assessments/releases/v1.0.0.yaml` |
| CHANGELOG entry | `CHANGELOG.md` |
| v1.0.0 git tag | `git tag v1.0.0` |
| Next-repo readiness document | `docs/next-repo-readiness.md` |

### Files to create or modify

| Action | File |
|---|---|
| Verify | CI passes all mandatory controls |
| Create | `09-assessments/reports/platform-compliance/ASSESS-PLATFORM-COMPLIANCE-v1.0.0.yaml` |
| Update | `CHANGELOG.md` with v1.0.0 entry |
| Create | `09-assessments/releases/v1.0.0.yaml` (release record) |
| Create | `docs/next-repo-readiness.md` |
| Execute | `git tag -s v1.0.0` |

### Tasks

`PC-0046` `PC-0047` `PC-0048` `PC-0049` `PC-0050` (see task list)

### Next-repo readiness gate

Before the second platform repository can be created, `platform-compliance` must demonstrate:

1. **CI is green**: All mandatory automated controls pass on the `main` branch
2. **Self-assessment passes**: The assessment report for `platform-compliance` shows `overall_result: pass` or `overall_result: pass-with-waivers` (any waivers must be approved and documented)
3. **All schemas are complete**: All 15 schemas exist and pass meta-schema validation
4. **Workflows are callable**: The reusable workflows are tested against at least one dry-run
5. **Consuming guide is complete**: `docs/consuming-compliance.md` is reviewed and approved
6. **Release record exists**: `v1.0.0` release record references the passing assessment
7. **ADRs are ratified**: ADR-0001 (compliance-first), ADR-0002 (policy engine), ADR-0003 (waiver process) all have status `accepted`

### Acceptance criteria

- [ ] `git tag v1.0.0` exists
- [ ] CI pipeline on the `v1.0.0` tag passes all mandatory merge gate and release gate checks
- [ ] `09-assessments/reports/platform-compliance/` contains a valid assessment report with `overall_result` not equal to `fail`
- [ ] All waivers in the assessment report are in `09-assessments/waivers/` and have `status: active` with non-expired `expiry_date`
- [ ] `09-assessments/releases/v1.0.0.yaml` exists and is valid against `schemas/release-record.schema.yaml`
- [ ] All 7 next-repo readiness conditions above are met
- [ ] `docs/next-repo-readiness.md` confirms all conditions met, with evidence citations

### Validation

```bash
# Verify v1.0.0 tag exists
git tag | grep "^v1.0.0$"

# Validate release record
check-jsonschema --schemafile schemas/release-record.schema.yaml \
  09-assessments/releases/v1.0.0.yaml

# Run all schema meta-validations
for f in schemas/*.schema.yaml; do
  check-jsonschema --check-metaschema "$f" && echo "VALID: $f"
done

# Check all 7 readiness conditions
# (this check is documented in docs/next-repo-readiness.md and verified manually)
```

### Risks

- Accumulated `[PLACEHOLDER: ...]` markers in mappings may prevent full provenance validation — each PLACEHOLDER represents an unresolved research item that must either be resolved or explicitly documented as a v1 known gap
- Platform-compliance's own CI may discover control failures in itself (e.g., missing CODEOWNERS, missing signed commits) — these are expected and handled by the waiver process
- The temptation to skip Phase 12 "because the repo obviously works" must be resisted — the self-assessment is the proof of concept for the entire system

### Must not

- Do not create the second platform repository before the readiness gate passes
- Do not add infrastructure deployment code to this repository
- Do not tag `v1.0.0` until the assessment report exists and passes

---

## Task list

Each task corresponds to a specific, reviewable PR. Dependencies are listed where one task must precede another. Status values: `done`, `in-progress`, `not-started`.

### Phase 1 — Repository skeleton and architecture docs

| ID | Title | Depends on | Status |
|---|---|---|---|
| PC-0001 | Create README stubs for all domain directories | — | done |
| PC-0002 | Write `docs/glossary.md` | PC-0001 | not-started |
| PC-0003 | Write `docs/onboarding.md` | PC-0001 | not-started |
| PC-0004 | Author `decisions/ADR-0001-compliance-first-architecture.md` | PC-0001 | done |
| PC-0005 | Create `CHANGELOG.md` with `[Unreleased]` section | — | done |
| PC-0006 | Create `docs/authoring-controls.md` guide | PC-0002 | not-started |

### Phase 2 — Standards registry and taxonomy

| ID | Title | Depends on | Status |
|---|---|---|---|
| PC-0007 | Validate all 9 source entries against `standard-source.schema.yaml` | Phase 1 | done |
| PC-0008 | Validate all taxonomy files for internal consistency and completeness | PC-0007 | done |
| PC-0009 | Research and fill `[PLACEHOLDER: ...]` markers for Scorecard check IDs | PC-0007 | not-started |
| PC-0010 | Research and fill `[PLACEHOLDER: ...]` for CIS Docker section references | PC-0007 | not-started |
| PC-0011 | Research and fill `[PLACEHOLDER: ...]` for SLSA v1.0 requirement IDs | PC-0007 | not-started |

### Phase 3 — Control catalog and compliance profile

| ID | Title | Depends on | Status |
|---|---|---|---|
| PC-0012 | Validate all 23 control files against `control.schema.yaml` | Phase 2 | done |
| PC-0013 | Validate `PROF-PLATFORM-V1.yaml` against `profile.schema.yaml` | PC-0012 | done |
| PC-0014 | Cross-check: all profile control IDs exist in the catalog | PC-0013 | done |
| PC-0015 | Cross-check: all source IDs in controls exist in registry | PC-0012 | done |
| PC-0016 | Peer review of all SRC and SEC domain controls for statement clarity | PC-0012 | not-started |
| PC-0017 | Peer review of all IAC, SUP, RUN domain controls | PC-0012 | not-started |
| PC-0018 | Peer review of OBS, BAK, CHG, DOC, INC, NET domain controls | PC-0012 | not-started |
| PC-0019 | Write `docs/authoring-controls.md` (authoring guide for controls) | PC-0016 | not-started |

### Phase 4 — Schemas for all governance objects

| ID | Title | Depends on | Status |
|---|---|---|---|
| PC-0020 | Write `schemas/mapping.schema.json` | Phase 3 | done |
| PC-0021 | Write `schemas/binding.schema.json` | Phase 3 | done |
| PC-0022 | Write `schemas/policy-check.schema.json` | PC-0021 | done |
| PC-0023 | Write `schemas/evidence.schema.json` | PC-0022 | done |
| PC-0024 | Write `schemas/waiver.schema.json` | Phase 3 | done |
| PC-0025 | Write `schemas/assessment.schema.json` | PC-0023, PC-0024 | done |
| PC-0026 | Write `schemas/repository-compliance.schema.json` | Phase 3 | done |
| PC-0027 | Write `schemas/adr.schema.json` | Phase 1 | done |
| PC-0028 | Write `schemas/change-record.schema.json` | Phase 3 | done |
| PC-0029 | Write `schemas/release-record.schema.json` | PC-0028 | done |
| PC-0030 | Write `schemas/incident-record.schema.json` | Phase 3 | done |
| PC-0031 | Write `schemas/service-contract.schema.json` | PC-0026 | done |
| PC-0032 | Run meta-schema validation on all 15 schema files | PC-0020–PC-0031 | not-started |
| PC-0033 | Create test fixtures (valid + invalid) for all 12 new schemas | PC-0032 | not-started |

### Phase 5 — Mapping and provenance model

| ID | Title | Depends on | Status |
|---|---|---|---|
| PC-0034 | Write `schemas/mapping.schema.yaml` test fixtures | PC-0020 | not-started |
| PC-0035 | Create SRC and SEC domain mapping files (Scorecard source) | PC-0009, PC-0020 | done |
| PC-0036 | Create SUP domain mapping files (SLSA and Scorecard sources) | PC-0011, PC-0020 | done |
| PC-0037 | Create IAC domain mapping files (OpenGitOps source) | PC-0020 | done |
| PC-0038 | Create RUN and OBS mapping files (CIS Docker and SRE sources) | PC-0010, PC-0020 | done |
| PC-0039 | Create CHG, DOC, INC, BAK, NET mapping files | PC-0020 | done |

### Phase 6 — Implementation binding model

| ID | Title | Depends on | Status |
|---|---|---|---|
| PC-0040 | Write `schemas/binding.schema.yaml` test fixtures | PC-0021 | not-started |
| PC-0041 | Write GitHub-context bindings for SRC-001, SRC-002, SRC-003 | PC-0021 | not-started |
| PC-0042 | Write GitHub-context bindings for SEC-001, SEC-002, SEC-003 | PC-0021 | not-started |
| PC-0043 | Write Terraform-context bindings for IAC-001, IAC-002, IAC-003, SUP-001 | PC-0021 | not-started |
| PC-0044 | Write Docker-context bindings for RUN-001, RUN-002, SUP-002, OBS-001 | PC-0021 | not-started |
| PC-0045 | Write GitHub-Actions-context bindings for SUP-001 (action pinning) | PC-0021 | not-started |
| PC-0046 | Write stubs for manual_initially controls (OBS-002, BAK-001, INC-001, DOC-002) | PC-0021 | not-started |
| PC-0047 | Cross-check: all automated controls have at least one binding | PC-0041–PC-0046 | not-started |

### Phase 7 — Policy-as-code structure and initial tests

| ID | Title | Depends on | Status |
|---|---|---|---|
| PC-0048 | Author `decisions/ADR-0004-opa-policy-engine.md` (OPA selected) | Phase 6 | in-progress |
| PC-0049 | Create `07-policies/` directory structure and `schemas/policy-check.schema.yaml` fixtures | PC-0048 | not-started |
| PC-0050 | Write policy check for SRC-001 (branch protection) with passing/failing fixtures | PC-0041, PC-0049 | not-started |
| PC-0051 | Write policy check for SRC-002 (PR required) with fixtures | PC-0041, PC-0049 | not-started |
| PC-0052 | Write policy check for SEC-001 (no secrets) with fixtures | PC-0042, PC-0049 | not-started |
| PC-0053 | Write policy check for SEC-002 (secret scanning enabled) with fixtures | PC-0042, PC-0049 | not-started |
| PC-0054 | Write policy check for IAC-001 (fmt + validate) with fixtures | PC-0043, PC-0049 | not-started |
| PC-0055 | Write policy check for SUP-001 (pinned deps) with fixtures | PC-0043, PC-0049 | not-started |
| PC-0056 | Write policy check for SUP-002 (no latest tag) with fixtures | PC-0044, PC-0049 | not-started |
| PC-0057 | Write policy check for RUN-002 (non-root user) with fixtures | PC-0044, PC-0049 | not-started |
| PC-0058 | Write policy checks for SRC-003, DOC-001, CHG-002 with fixtures | PC-0041–PC-0042, PC-0049 | not-started |
| PC-0059 | Run all policy tests and confirm all pass | PC-0050–PC-0058 | not-started |

### Phase 8 — Evidence model and evidence record schema

| ID | Title | Depends on | Status |
|---|---|---|---|
| PC-0060 | Finalize `schemas/evidence-record.schema.yaml` with Phase 7 output examples | PC-0023, PC-0059 | not-started |
| PC-0061 | Write `08-evidence/ledger/format.md` (structure, naming, retention) | PC-0060 | not-started |
| PC-0062 | Create valid and invalid evidence record test fixtures | PC-0060 | not-started |
| PC-0063 | Validate policy check outputs from Phase 7 conform to evidence schema | PC-0059, PC-0060 | not-started |

### Phase 9 — Assessment, finding, waiver, and exception model

| ID | Title | Depends on | Status |
|---|---|---|---|
| PC-0064 | Finalize `schemas/assessment-report.schema.yaml` with evidence schema | PC-0025, PC-0060 | not-started |
| PC-0065 | Create `09-assessments/gates/release-gate.yaml` derived from profile | PC-0013, PC-0064 | not-started |
| PC-0066 | Create `09-assessments/gates/deployment-gate.yaml` derived from profile | PC-0013, PC-0064 | not-started |
| PC-0067 | Author `decisions/ADR-0003-waiver-approval-process.md` | Phase 4 | not-started |
| PC-0068 | Write waiver template and assessment report template | PC-0024, PC-0064 | not-started |

### Phase 10 — Reusable GitHub workflow design

| ID | Title | Depends on | Status |
|---|---|---|---|
| PC-0069 | Write `workflows/compliance-check.yaml` reusable workflow | PC-0026, PC-0059 | not-started |
| PC-0070 | Write `workflows/evidence-collect.yaml` reusable workflow | PC-0060, PC-0069 | not-started |
| PC-0071 | Write `workflows/assessment-generate.yaml` reusable workflow | PC-0064, PC-0070 | not-started |
| PC-0072 | Write `workflows/release-gate.yaml` reusable workflow | PC-0065, PC-0071 | not-started |
| PC-0073 | Write `workflows/deployment-gate.yaml` reusable workflow | PC-0066, PC-0071 | not-started |
| PC-0074 | Create `.github/workflows/self-compliance.yaml` that calls above workflows | PC-0069–PC-0073 | not-started |
| PC-0075 | Validate all workflows with `actionlint` | PC-0069–PC-0074 | not-started |

### Phase 11 — Repository compliance manifest design

| ID | Title | Depends on | Status |
|---|---|---|---|
| PC-0076 | Finalize `schemas/compliance-manifest.schema.yaml` | PC-0026 | not-started |
| PC-0077 | Write `templates/compliance-manifest.template.yaml` | PC-0076 | not-started |
| PC-0078 | Write all remaining templates (control, waiver, ADR, change-record, etc.) | PC-0026–PC-0031 | not-started |
| PC-0079 | Write `docs/consuming-compliance.md` | PC-0077 | not-started |
| PC-0080 | Write `.compliance-manifest.yaml` for platform-compliance itself | PC-0076 | not-started |

### Phase 12 — Final review and readiness gate

| ID | Title | Depends on | Status |
|---|---|---|---|
| PC-0081 | Run self-compliance CI and collect first evidence batch | PC-0074, PC-0080 | not-started |
| PC-0082 | Generate first assessment report for platform-compliance | PC-0081 | not-started |
| PC-0083 | Resolve or waive any failing controls in the assessment | PC-0082 | not-started |
| PC-0084 | Write v1.0.0 `CHANGELOG.md` entry and release record | PC-0082 | not-started |
| PC-0085 | Write `docs/next-repo-readiness.md` and verify all 7 conditions | PC-0082, PC-0084 | not-started |
| PC-0086 | Tag `v1.0.0` and publish release | PC-0083, PC-0084, PC-0085 | not-started |

---

## Task summary

| Phase | Tasks | Status summary |
|---|---|---|
| 1 — Skeleton | PC-0001 to PC-0006 | All not-started |
| 2 — Standards & Taxonomy | PC-0007 to PC-0011 | PC-0007, PC-0008 done; 3 not-started |
| 3 — Controls & Profile | PC-0012 to PC-0019 | PC-0012, PC-0013 done; 6 not-started |
| 4 — Schemas | PC-0020 to PC-0033 | All not-started |
| 5 — Mappings | PC-0034 to PC-0039 | All not-started |
| 6 — Bindings | PC-0040 to PC-0047 | All not-started |
| 7 — Policies | PC-0048 to PC-0059 | All not-started (ADR required first) |
| 8 — Evidence | PC-0060 to PC-0063 | All not-started |
| 9 — Assessment & Waiver | PC-0064 to PC-0068 | All not-started |
| 10 — Workflows | PC-0069 to PC-0075 | All not-started |
| 11 — Manifest | PC-0076 to PC-0080 | All not-started |
| 12 — Release | PC-0081 to PC-0086 | All not-started |
| **Total** | **86 tasks** | **4 done, 82 not-started** |

---

## Critical path

The following tasks form the critical path to `v1.0.0`. No task on this path can be skipped or parallelized with its predecessor.

```
PC-0004 (ADR-0001)
  → PC-0007 (validate sources)
    → PC-0012 (validate controls)
      → PC-0013 (validate profile)
        → PC-0020 thru PC-0033 (schemas)
          → PC-0035 thru PC-0039 (mappings)
            → PC-0041 thru PC-0047 (bindings)
              → PC-0048 (ADR-0002 policy engine)
                → PC-0050 thru PC-0059 (policies + tests)
                  → PC-0060 thru PC-0063 (evidence schema)
                    → PC-0064 thru PC-0068 (assessment + waiver)
                      → PC-0069 thru PC-0075 (workflows)
                        → PC-0076 thru PC-0080 (manifest)
                          → PC-0081 thru PC-0086 (self-assessment + release)
```

Tasks that can be parallelized off the critical path: PC-0001–PC-0006 (skeleton), PC-0009–PC-0011 (placeholder research), PC-0016–PC-0019 (peer review), PC-0067 (ADR-0003 waiver process).

---

*This roadmap is the authoritative task breakdown for `platform-compliance` v1.0.0. Updates to this roadmap are change records under CHG-001. The roadmap is superseded when a PROF-PLATFORM-V2 is initiated.*
