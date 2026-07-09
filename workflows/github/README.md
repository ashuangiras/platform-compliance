# Reusable Compliance Workflow

This directory contains the design and skeleton for the platform's reusable GitHub Actions compliance workflow. When deployed, this workflow implements the full compliance check, evidence collection, assessment, and gate evaluation pipeline for all platform repositories.

---

## Important: deployment location

For GitHub Actions to recognise this as a callable reusable workflow, the final file must live at:

```
.github/workflows/reusable-compliance.yml
```

within the `platform-compliance` repository. The copy in `workflows/github/` is the design artifact. During Phase 10 (PC-0069), the deployed version will be created at `.github/workflows/reusable-compliance.yml`.

---

## What the workflow does

```
Job 1: validate-manifest
  → Confirms .compliance-manifest.yaml exists
  → Validates it against repository-compliance.schema.json
  → Parses declared profile

Job 2: check-required-files
  → Checks README.md exists (DOC-001)
  → Checks CODEOWNERS exists (SRC-003)
  → Checks .gitignore secret patterns (SEC-001 prerequisite)

Job 3: secret-scan-check  (parallel with job 2)
  → Runs gitleaks/detect-secrets against repository (SEC-001)
  → Checks GitHub API for secret scanning + push protection status (SEC-002)

Job 4: policy-checks  (after jobs 2-3)
  → Downloads OPA policy bundle from platform-compliance
  → Collects technology context inputs (GitHub API, file parsing)
  → Runs OPA against each applicable policy
  → Outputs structured policy results

Job 5: collect-evidence  (after job 4)
  → Converts policy results to evidence records
  → Adds metadata: commit_sha, profile_version, catalog_version, workflow_run_id
  → Computes artifact_hash for each record
  → Uploads evidence bundle as workflow artifact

Job 6: generate-assessment  (after job 5)
  → Aggregates evidence records
  → Applies active waivers
  → Computes control-level and overall results
  → Generates assessment report (assessment.schema.json)
  → Uploads report as workflow artifact

Job 7: evaluate-gate  (after job 6)
  → Downloads gate criteria from platform-compliance
  → Evaluates each required_control's result
  → Identifies blocking controls (fail + enforcement: block)
  → Posts result comment on PR (if pull_request event)
  → Fails workflow if gate result is fail
```

---

## How consuming repositories use this workflow

### Step 1: Add to the consuming repository's CI

Create `.github/workflows/compliance.yml` in the consuming repository:

```yaml
name: Compliance

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  merge-gate:
    uses: ashuangiras/platform-compliance/.github/workflows/reusable-compliance.yml@v1.0.0
    with:
      gate: merge_gate
      profile-id: PROF-PLATFORM-V1
      repository-type: terraform-module
      technology-contexts: "github,terraform,github-actions"
    # secrets: inherit   # if policies need GITHUB_TOKEN scoped to calling repo
```

For release gating, add a separate job triggered on tag push:

```yaml
  release-gate:
    uses: ashuangiras/platform-compliance/.github/workflows/reusable-compliance.yml@v1.0.0
    with:
      gate: release_gate
      profile-id: PROF-PLATFORM-V1
      repository-type: terraform-module
      technology-contexts: "github,terraform,github-actions"
```

### Step 2: Pin to a specific version

Always pin to a specific version tag (`@v1.0.0`), not `@main`. Consuming repositories must explicitly opt in to new versions of `platform-compliance`. See docs/consuming-compliance.md for the upgrade process.

### Step 3: Confirm required branch protection checks

In the consuming repository's branch protection settings, add these required status checks:

- `compliance / merge-gate` (or whatever you named the job)

This ensures the CI gate is enforced at the GitHub layer (SRC-001 + SRC-002), not just at the workflow layer.

---

## Workflow inputs reference

| Input | Required | Default | Description |
|---|---|---|---|
| `gate` | Yes | — | Gate to evaluate: `merge_gate`, `release_gate`, `deployment_gate`, `continuous_audit` |
| `profile-id` | Yes | — | Profile ID from `04-profiles/` (e.g., `PROF-PLATFORM-V1`) |
| `repository-type` | Yes | — | Type from `02-taxonomy/repository-types.yaml` |
| `technology-contexts` | No | `github,github-actions` | Comma-separated context list |
| `has-container-images` | No | `false` | Whether repo builds/references Docker images |
| `platform-compliance-ref` | No | `v1.0.0` | Pin of platform-compliance to use |

## Workflow outputs reference

| Output | Description |
|---|---|
| `compliance-result` | Gate result: `pass`, `fail`, `pass-with-warnings`, `held` |
| `assessment-report-path` | Path to generated assessment report artifact |
| `evidence-bundle-hash` | SHA-256 hash of the complete evidence bundle |
| `blocking-controls` | Comma-separated list of blocking control IDs (empty if passing) |

---

## Current status: skeleton

The workflow is a functional skeleton. All seven jobs are defined with their correct structure, inputs, and outputs. The `TODO [Phase N]` comments mark where actual implementation will be added:

| Phase | What gets implemented |
|---|---|
| Phase 7 | OPA policy execution, gitleaks integration, GitHub API calls |
| Phase 8 | Evidence record writing with proper schema conformance |
| Phase 9 | Assessment report generation and waiver application |
| Phase 10 | Gate criteria evaluation, PR comment posting, full integration |

The skeleton produces a `pass` result in all jobs (except if overall_result is explicitly `fail`), allowing the workflow structure to be tested and consumed before full implementation.

---

## Why local commits are not trusted

The compliance gate is enforced at the **protected branch** level, not at the developer's workstation.

1. A developer may commit code that fails compliance checks locally. This is allowed — development iteration happens in local branches.
2. When a pull request is opened targeting a protected branch, the compliance workflow runs.
3. If the merge gate fails, GitHub's required status checks prevent the PR from being merged (enforced by SRC-001 + SRC-002).
4. The developer must fix the failing controls before the PR can proceed.

This means:
- Local commits are **untrusted** until they pass the protected branch gate
- The branch protection (SRC-001) is what makes the gate enforceable — without it, developers could bypass the workflow by direct-pushing
- The combination of SRC-001 + required status checks creates the enforcement layer

A workflow alone cannot enforce compliance. The workflow + branch protection together create an enforceable gate.
