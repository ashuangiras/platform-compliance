# Operating Model

**Repository:** `platform-compliance`  
**Date:** 2026-07-08

This document describes how the compliance system operates in practice: how controls are added and changed, how repositories adopt the platform, how evidence is collected, how assessments are produced, and how exceptions are handled. It is the operational companion to the [architecture document](platform-compliance-architecture.md).

---

## Table of Contents

1. [Adding or changing a control](#1-adding-or-changing-a-control)
2. [Adding or changing a profile](#2-adding-or-changing-a-profile)
3. [Onboarding a new repository](#3-onboarding-a-new-repository)
4. [How evidence is collected](#4-how-evidence-is-collected)
5. [How assessment reports are produced](#5-how-assessment-reports-are-produced)
6. [How gate checks work](#6-how-gate-checks-work)
7. [Requesting and granting a waiver](#7-requesting-and-granting-a-waiver)
8. [Releasing a new version of platform-compliance](#8-releasing-a-new-version-of-platform-compliance)
9. [What happens when a control fails in production](#9-what-happens-when-a-control-fails-in-production)
10. [Change record process](#10-change-record-process)

---

## 1. Adding or changing a control

### When a new control is needed

A new control is needed when a risk or requirement is identified that is not addressed by any existing control. The trigger may be:
- A registered standard contains a clause that is not yet mapped to a control
- An incident reveals a gap in the current control set
- The platform's scope expands (e.g., a new technology context is introduced)
- An ADR identifies a platform decision that requires a corresponding control

### Process

```
1. Check the standards registry
   Is the standard that motivates this control registered in 01-sources/?
   If not, register it first (a standard source entry must precede any
   control that cites it).

2. Draft the control YAML
   Use the control template: templates/control.template.yaml
   Follow the control schema: schemas/control.schema.yaml
   Assign the next available ID in the domain (e.g., SRC-005 if SRC-004 exists)
   Set lifecycle_status: active or lifecycle_status: deferred as appropriate

3. Draft the mapping record
   In 05-mappings/, create or update the mapping file for the source.
   Link the specific standard clause to the new control ID.
   If the exact clause reference requires research, use [PLACEHOLDER: ...].

4. Create a change record
   Document the addition in a change record (schemas/change-record.schema.yaml).
   Reference the change record ID in the pull request description.
   This is required by CHG-001.

5. If the change is significant, create an ADR
   "Significant" means the change affects the compliance model, introduces a
   new domain, changes an enforcement level, or is otherwise non-obvious.
   Create the ADR before the control is merged. Reference the ADR in the control.

6. Open a pull request
   The PR must:
   - Include the new control YAML
   - Include the mapping record
   - Reference the change record ID in the PR description
   - Pass the merge gate (which includes CHG-001 for platform-repo type)
```

### Changing an existing control

Minor changes (clarifying wording, correcting a placeholder clause reference) follow the same process but may not require an ADR.

Breaking changes — changes that alter what downstream repositories must do to satisfy the control — require:
- An ADR explaining the change and its impact
- A change record with `breaking: true`
- A `migration_guidance` field in the change record explaining what downstream repositories must do
- A profile version bump if the change affects `PROF-PLATFORM-V1`

A control's `id` never changes. If a control is fundamentally different from its predecessor, create a new control and mark the old one as `superseded_by: NEW-ID`.

---

## 2. Adding or changing a profile

### When a profile change is needed

- A new control is added to the catalog and should be included in an existing profile
- An enforcement level changes for an existing control
- A new class of repository is introduced that needs a distinct profile
- A `manual_initially` control reaches its `automation_deadline` and moves to `automated_required`

### Process

```
1. Review the impact
   Identify all repositories that declare this profile.
   Assess which repositories will be affected by the change.

2. Draft the profile change
   Update the profile YAML.
   If adding a mandatory control, all repositories declaring this profile must
   satisfy the new control. Check whether this creates immediate failures.

3. Determine the version strategy
   - Non-breaking change (adding a deferred control, clarifying descriptions):
     increment the PATCH version (1.0.0 → 1.0.1)
   - Additive change (new manual_initially control that warns but does not block):
     increment the MINOR version (1.0.0 → 1.1.0)
   - Breaking change (new mandatory blocking control, removing a waiver pathway):
     increment the MAJOR version (1.0.0 → 2.0.0), create ADR, provide
     migration guidance, establish a transition period

4. Create a change record
   Reference the profile change. Mark breaking: true if applicable.

5. For major version bumps, create the new profile file
   PROF-PLATFORM-V2.yaml — do not edit V1 in place.
   Set PROF-PLATFORM-V1 status to deprecated with a superseded_by reference.
   Repositories migrate explicitly; they are not silently upgraded.
```

---

## 3. Onboarding a new repository

Every repository created under the platform must complete these steps before its first release.

### Step 1: Create the compliance manifest

At the repository root, create `.compliance-manifest.yaml`:

```yaml
schema_version: "1.0.0"
repository:
  name: my-new-repo
  url: https://github.com/org/my-new-repo
  type: terraform-module   # from 02-taxonomy/repository-types.yaml
declared_profiles:
  - PROF-PLATFORM-V1
technology_contexts:
  - github
  - terraform
compliance_contact: platform-team
last_updated: "2026-07-08"
```

The `type` field determines which scope conditions apply. Use `02-taxonomy/repository-types.yaml` to choose the correct type.

### Step 2: Configure CI to use the reusable workflows

In `.github/workflows/compliance.yml`:

```yaml
name: Compliance

on:
  pull_request:
  push:
    branches: [main]

jobs:
  compliance-check:
    uses: org/platform-compliance/.github/workflows/compliance-check.yaml@v1.0.0
    with:
      profile-id: PROF-PLATFORM-V1
      repository-type: terraform-module
```

Pin the `@v1.0.0` tag — do not use `@main`. Consuming repositories opt in to new versions of `platform-compliance` explicitly.

### Step 3: Satisfy mandatory controls before first merge to main

Before the first PR can be merged to the default branch, the following controls must pass (for a `terraform-module` repository):

| Control | What to do |
|---|---|
| SRC-001 | Enable branch protection on the default branch |
| SRC-002 | Require PR reviews; disable direct push |
| SEC-001 | Ensure no secrets in any file; add `.gitignore` patterns |
| SEC-002 | Enable GitHub secret scanning and push protection |
| IAC-001 | Ensure all Terraform passes `fmt -check` and `validate` |
| SUP-001 | Pin all provider versions in `required_providers` |
| DOC-001 | Create `README.md` at the repository root |

The CI pipeline will report which controls are failing. Fix each one and rerun until the merge gate passes.

### Step 4: Add CODEOWNERS before first release

Before the release gate can pass, `SRC-003` requires a `CODEOWNERS` file. Add it before attempting to tag a release.

---

## 4. How evidence is collected

Evidence is collected automatically by the reusable CI/CD workflows. The process:

```
PR opened or push to branch
        │
        ▼
compliance-check workflow
  - Reads .compliance-manifest.yaml
  - Resolves which controls apply (profile + scope conditions)
  - For each applicable automated control:
    - Runs the policy check
    - Captures the structured JSON result
        │
        ▼
evidence-collect workflow
  - Converts each policy result into an evidence record
    conforming to schemas/evidence-record.schema.yaml
  - Each record includes:
    control_id, policy_check_id, resource_ref,
    commit_sha, evaluated_at, result, details
  - Writes records to 08-evidence/collected/{repo-slug}/
  - Attaches records as CI artifacts
        │
        ▼
Evidence records are immutable once written.
A passing record from commit A is not overwritten by commit B.
Evidence accumulates; it is not replaced.
```

### Manual evidence

For controls with `automation_status: manual` or `manual` initially:

1. The control's binding specifies what the evidence must demonstrate
2. The responsible person attests to compliance by writing an evidence record manually
3. The manual record must include: the attestor's identity, the date, the method used, and the result
4. Manual records are submitted to the `08-evidence/collected/` directory via pull request
5. The PR for a manual evidence record is itself subject to the merge gate (SRC-001, SRC-002, SEC-001)

Manual evidence has an expiry: records older than the `assessment_cadence` of the control are treated as stale. Stale manual evidence produces a `not-applicable` result in the next assessment until refreshed.

---

## 5. How assessment reports are produced

An assessment report aggregates all evidence records for a subject into a compliance verdict.

```
Trigger: PR merge, release tag, deployment, or scheduled assessment
        │
        ▼
assessment-generate workflow
  - Reads all evidence records for the repository from 08-evidence/collected/
  - Filters to evidence within the assessment window (configurable; default: last 7 days)
  - For each control in the declared profile:
    - Finds the most recent evidence record
    - Applies any active waivers from 09-assessments/waivers/
    - Assigns result: pass | fail | waived | not-applicable | error
  - Calculates overall_result:
    - pass:              all mandatory controls pass or are not-applicable
    - pass-with-waivers: all mandatory controls pass or are waived
    - fail:              at least one mandatory control fails without a waiver
    - inconclusive:      evidence is missing for one or more mandatory controls
  - Writes the report to 09-assessments/reports/{repo-slug}/ASSESS-{ID}.yaml
```

Reports are immutable once generated. A new report is generated for each assessment event. Historical reports are retained as the compliance history of the repository.

---

## 6. How gate checks work

Gates consume assessment reports. They do not run policy checks directly.

```
Gate trigger (merge, release tag, or deployment)
        │
        ▼
Gate workflow reads the gate criteria file:
  09-assessments/gates/release-gate.yaml  (for release)
  09-assessments/gates/deployment-gate.yaml  (for deployment)
        │
        ▼
Gate workflow reads the latest assessment report for the repository
        │
        ▼
For each control listed in the gate criteria:
  - Check the control's result in the assessment report
  - If result is fail AND control enforcement is block → gate FAILS
  - If result is fail AND control enforcement is warn → gate WARNS
  - If result is waived AND waiver is active/non-expired → gate PASSES for this control
        │
        ▼
Gate produces one of:
  PASS         → action proceeds
  PASS-WARN    → action proceeds with visible warnings in CI
  FAIL         → action is blocked; failing controls listed
```

### Bypassing a gate

Gates cannot be bypassed by adding `--no-verify` or equivalent flags. The gate evaluation is a required CI check, and the repository's branch protection (SRC-001, SRC-002) prevents merging without passing CI.

The only legitimate path past a failing gate is:
1. Fix the failing control (preferred)
2. Obtain an approved waiver (see §7)
3. Reclassify the control as not-applicable with documented rationale (requires an ADR if the reclassification is new)

---

## 7. Requesting and granting a waiver

A waiver is a time-bounded, explicitly documented exception to a control. It is not a permanent override; it is a managed risk acceptance.

### When a waiver is appropriate

- A new repository is being bootstrapped and a control cannot be satisfied immediately (e.g., the backup policy for a new stateful service cannot be completed until the service is fully designed)
- A technical limitation makes satisfying a control infeasible in the current platform phase
- A compensating control exists that partially mitigates the risk

### Process

```
1. Create a waiver record
   Use the waiver template: templates/waiver.template.yaml
   The waiver must include:
   - control_id: the control being waived
   - resource_ref: the specific repository or service
   - rationale: why the control cannot currently be satisfied
   - risk_acceptance_statement: explicit statement of accepted risk
   - compensating_controls: any controls that partially mitigate
   - approved_by: must be platform-owner level for P1 controls
   - approved_date, expiry_date (required — no open-ended waivers)

2. Submit via pull request
   The PR creates the waiver record in 09-assessments/waivers/
   The PR itself is subject to the merge gate

3. Reference the waiver in the compliance manifest
   Add the waiver_id to the affected repository's .compliance-manifest.yaml

4. Monitor expiry
   The continuous audit gate checks for waivers nearing expiry (30 days before)
   and waivers that have expired
   Expired waivers are treated as non-existent — the control reverts to failing

5. Renew or resolve
   Before expiry: either fix the control (remove the waiver) or renew the
   waiver with updated rationale and a new approval
```

### What waivers are not

- Waivers are not retroactive: a waiver does not make past failures pass
- Waivers do not suppress evidence collection: failing evidence records are still written; the waiver is applied at assessment time, not evidence time
- Waivers are always visible: every assessment report that covers a waived control includes the waiver record

---

## 8. Releasing a new version of platform-compliance

Every tagged release of `platform-compliance` is itself a governed event. Before a release tag can be pushed:

```
1. All mandatory controls in PROF-PLATFORM-V1 must be passing
   (or waived with approved waivers)

2. A release record must be created
   File: 09-assessments/releases/v{VERSION}.yaml
   Must include: list of change record IDs in this release,
   reference to the passing assessment report, summary of changes,
   whether breaking changes are included

3. CHANGELOG.md must be updated
   With the v{VERSION} entry listing all notable changes

4. The release gate workflow must pass
   This confirms the assessment report is current and passing

5. Tag the release
   git tag -s v{VERSION}  (signed tags are the target; unsigned accepted in v1)
```

Downstream repositories pin to a specific version of `platform-compliance`. When they upgrade to a new version, their CI re-evaluates all controls against the new profile version. If the new version introduces a new mandatory control, they will see a new failure in CI. This is intentional: version upgrades are explicit, not silent.

---

## 9. What happens when a control fails in production

"Production" here means: a control that was passing at release time is now failing in the continuous audit.

```
Continuous audit detects a failing control
        │
        ▼
Evidence record written with result: fail
Assessment report updated
Notification sent to compliance_contact in .compliance-manifest.yaml
        │
        ▼
Remediation SLA begins (from 02-taxonomy/risk-levels.yaml):
  critical → 24 hours
  high     → 7 days
  medium   → 30 days
  low      → 90 days
        │
        ▼
If not remediated within SLA:
  An incident record is triggered (INC-001)
  The deployment gate blocks for the affected service
  until the control is remediated or a waiver is approved
```

The deployment gate block prevents new deployments of a non-compliant service. Existing running instances are not stopped; blocking happens at the next deploy trigger.

---

## 10. Change record process

CHG-001 requires that every PR to `platform-compliance` that modifies normative content includes a change record.

### What is normative content

Changes to any of these require a change record:
- Control YAML files in `03-catalogs/`
- Profile YAML files in `04-profiles/`
- Mapping files in `05-mappings/`
- Binding files in `06-bindings/`
- Schema files in `schemas/`
- Policy files in `07-policies/`
- Gate criteria files in `09-assessments/gates/`

### What does not require a change record

- Documentation edits that do not change the meaning of normative content
- README updates
- ADR creation (ADRs are their own record type)
- Formatting-only changes
- Adding placeholders or comments

### Format

A change record is a YAML file conforming to `schemas/change-record.schema.yaml`. It includes:
- A stable ID (`CHG-YYYYMMDD-NNN`)
- The type of change and a description
- The IDs of affected objects
- Whether the change is breaking
- Migration guidance if breaking

The change record ID must appear in the PR description as: `Change Record: CHG-YYYYMMDD-NNN`.

---

*This document describes the operating model for `platform-compliance` v1.0.0. Changes to this model require a change record. Significant changes require an ADR.*
