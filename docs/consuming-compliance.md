# Consuming Compliance: How to Onboard a Repository

**Repository:** `platform-compliance`  
**Date:** 2026-07-08  
**Audience:** Owners of new platform repositories

This guide covers everything needed to create a platform repository that passes the merge gate, release gate, and deployment gate. Start here before writing any code.

---

## Prerequisites

Before creating your repository:

1. `platform-compliance` must be at `v1.0.0` or higher (the release gate for `platform-compliance` must have passed)
2. You must have write access to the GitHub organisation
3. Branch protection must be enabled on the new repository's default branch before the first PR is opened

---

## Step 1: Determine your repository type

Choose one from `02-taxonomy/repository-types.yaml`:

| Type | When to use |
|---|---|
| `terraform-module` | Reusable Terraform module (no backend, no apply) |
| `terraform-root` | Terraform root configuration (has backend, applies infrastructure) |
| `service` | Deployable containerised or process-based service |
| `platform-repo` | Platform governance or tooling repository |
| `library` | Shared code library (no deploy) |
| `documentation` | Documentation only |

Your type determines which controls apply via scope conditions in `PROF-PLATFORM-V1`.

---

## Step 2: Create the compliance manifest

At the repository root, create `.compliance-manifest.yaml`. Use the template in `templates/compliance-manifest.template.yaml` as a starting point:

```yaml
schema_version: "1.0.0"

repository:
  name: my-terraform-module
  url: "https://github.com/angirasa_risk/my-terraform-module"
  type: terraform-module
  has_container_images: false

declared_profiles:
  - PROF-PLATFORM-V1

technology_contexts:
  - github
  - terraform
  - github-actions

waiver_ids: []

compliance_contact: my-team
last_updated: "2026-07-08"
```

Adjust `technology_contexts` for your repository. Use all that apply:
- `github` — always include
- `github-actions` — include if you use GitHub Actions
- `terraform` — include if the repo contains `.tf` files
- `docker` — include if the repo builds or references Docker images

---

## Step 3: Configure branch protection before the first PR

Branch protection must exist before `SRC-001` can pass. Configure it in repository settings:

**Settings → Branches → Add rule** for `main` (or your default branch):

- [x] Require a pull request before merging
  - Required approvals: **1**
  - [x] Dismiss stale pull request approvals when new commits are pushed
- [x] Require status checks to pass before merging
  - Add the compliance check status (once CI is configured in Step 4)
  - [x] Require branches to be up to date before merging
- [x] Do not allow bypassing the above settings
- [ ] Allow force pushes — **OFF**
- [ ] Allow deletions — **OFF**

---

## Step 4: Add the reusable compliance workflow to CI

Create `.github/workflows/compliance.yml` in your repository:

```yaml
name: Compliance

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  merge-gate:
    name: "Compliance: Merge Gate"
    uses: angirasa_risk/platform-compliance/.github/workflows/reusable-compliance.yml@v1.0.0
    with:
      gate: merge_gate
      profile-id: PROF-PLATFORM-V1
      repository-type: terraform-module        # match your manifest
      technology-contexts: "github,terraform,github-actions"
      has-container-images: false
```

For service repositories that need release and deployment gates, add additional jobs:

```yaml
  release-gate:
    name: "Compliance: Release Gate"
    if: startsWith(github.ref, 'refs/tags/v')
    uses: angirasa_risk/platform-compliance/.github/workflows/reusable-compliance.yml@v1.0.0
    with:
      gate: release_gate
      profile-id: PROF-PLATFORM-V1
      repository-type: service
      technology-contexts: "github,docker,github-actions"
      has-container-images: true
```

**Always pin to a specific version tag** (`@v1.0.0`), not `@main`. When a new version of `platform-compliance` is released, update your pin deliberately.

---

## Step 5: Add the compliance check as a required status check

After the first CI run (which will create the check):

1. Go to **Settings → Branches → Branch protection rule** for `main`
2. Under "Require status checks to pass", search for `compliance / merge-gate` (or the job name you used)
3. Add it as a required status check

This is what makes the gate structurally enforced — not just advisory.

---

## Step 6: Satisfy all merge gate controls

The merge gate checks these controls (for `terraform-module` type):

| Control | What to do | Automated? |
|---|---|---|
| SRC-001 | Branch protection enabled (Step 3) | Auto |
| SRC-002 | PRs required with ≥1 review (Step 3) | Auto |
| SEC-001 | No secrets in any file | Auto |
| SEC-002 | GitHub secret scanning + push protection enabled | Auto |
| IAC-001 | `terraform fmt` and `validate` pass | Auto |
| SUP-001 | All provider/module versions pinned | Auto |
| SRC-003 | CODEOWNERS file present | Auto (warns) |
| DOC-001 | README.md present | Auto (warns) |

For **SRC-003**: add a `CODEOWNERS` file before your first release. It can warn at the merge gate but will block the release gate.

For **DOC-001**: add a `README.md` with at least 100 bytes of meaningful content.

---

## Step 7: What to do when a gate fails

The CI workflow will post a comment on your PR with the result. For each failing control:

### Option A — Fix the issue (preferred)

Follow the control's `implementation_expectations` in `03-catalogs/controls/{DOMAIN}/{ID}.yaml`. The binding in `06-bindings/bindings/{context}/BIND-{ID}-{CONTEXT}.yaml` gives the specific observable artifact.

### Option B — Request a waiver

If you cannot satisfy a control immediately:

1. Copy `templates/waiver.template.yaml` (when available) or follow the schema in `schemas/waiver.schema.json`
2. Create the waiver file at `09-assessments/waivers/WAV-{CONTROL_ID}-{YYYYMM}-{NNN}.yaml` in `platform-compliance`
3. Fill in: `control_id`, `resource_ref`, `rationale`, `risk_acceptance_statement`, `approved_by`, `expiry_date`
4. Open a PR to `platform-compliance` to add the waiver
5. Once merged, add the waiver ID to your `.compliance-manifest.yaml` under `waiver_ids`

P1 controls require platform-owner approval. P2 controls require team review. See `09-assessments/waiver-model.md` for the full process.

---

## Step 8: Understanding the release gate

Before you can publish a tagged release (`v1.0.0`):

Additional controls that become blocking at the release gate:

| Control | What it requires |
|---|---|
| SRC-003 | CODEOWNERS file (was warn at merge, now blocks) |
| SEC-002 | Secret scanning + push protection confirmed enabled |
| CHG-002 | Release record YAML file at `09-assessments/releases/{tag}.yaml` |
| DOC-001 | README.md (was warn, now blocks) |
| RUN-002 | Non-root container user (container repos only) |

For `CHG-002`: Create `09-assessments/releases/v1.0.0.yaml` in your repository before or alongside the tag. See `schemas/release-record.schema.json` for the required fields.

---

## Step 9: Understanding the deployment gate

For `terraform-root` and `service` repositories, additional controls apply before deploy:

| Control | What it requires |
|---|---|
| IAC-002 | Terraform plan reviewed in PR (terraform-root only) |
| OBS-001 | Health check declared in service-contract.yaml (services) |
| BAK-001 | Backup policy declared (stateful services only) |
| NET-001 | Ingress policy declared (externally exposed services) |
| SEC-003 | No unresolved critical vulnerability alerts |

---

## Reading an assessment report

Assessment reports are generated automatically by CI and attached as workflow artifacts named `assessment-report-{run_id}`. They are also stored in `09-assessments/reports/{repo-slug}/`.

Key fields to read:

```yaml
overall_result: pass          # pass | fail | pass-with-waivers | inconclusive
control_results:
  - control_id: SRC-001
    result: pass              # per-control result
  - control_id: BAK-001
    result: not_applicable    # scope condition evaluated false
  - control_id: SEC-003
    result: waived
    waiver_id: WAV-SEC-003-202607-001
gate_evaluation:
  gate_id: merge_gate
  gate_result: pass
  blocking_controls: []       # empty = gate passes
```

If `overall_result: fail`, look at `gate_evaluation.blocking_controls` for the list of control IDs to fix.

---

## Upgrading to a new version of platform-compliance

When a new version is released:

1. Review `CHANGELOG.md` and the release record in `09-assessments/releases/` for breaking changes
2. If breaking: follow the `migration_guide` in the release record
3. Update the workflow reference in `.github/workflows/compliance.yml`:
   ```yaml
   uses: angirasa_risk/platform-compliance/.github/workflows/reusable-compliance.yml@v1.1.0
   ```
4. Merge the update; CI will re-evaluate all controls against the new version
5. Fix any new failures introduced by the version update

Version updates are always explicit. Nothing changes in your CI without you updating the pin.

---

## Getting help

- Architecture explanation: `docs/platform-compliance-architecture.md`
- How gates work: `docs/commit-compliance-flow.md`
- Control catalog: `03-catalogs/controls/{DOMAIN}/`
- Binding specifications: `06-bindings/bindings/{context}/`
- Waiver process: `09-assessments/waiver-model.md`
