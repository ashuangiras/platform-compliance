# How a Commit Becomes Compliant

**Repository:** `platform-compliance`  
**Date:** 2026-07-08

This document explains the full lifecycle of a code change from a developer's local branch to a deployed infrastructure component, describing exactly what compliance checks occur at each stage, why local commits are not trusted, and how each gate works.

---

## The fundamental principle: trust is earned at protected boundaries

A commit on a developer's local machine, or in a feature branch, is **not trusted** from a compliance perspective. Compliance is not about the code; it is about the code passing verifiable checks at a protected boundary.

The protected boundaries in this platform are:

| Boundary | What protects it | Control |
|---|---|---|
| Merge to default branch | GitHub branch protection + required CI status | SRC-001, SRC-002 |
| Release tag publication | Release gate workflow | CHG-002 |
| Infrastructure apply | Deployment gate workflow | IAC-002 |
| Continuous state | Daily/weekly audit | SEC-001, SEC-002, SEC-003 |

Without branch protection (SRC-001), a developer could push code directly to the default branch, bypassing all workflow checks. The workflow and the branch protection are co-dependent: the workflow provides the check, and branch protection makes the check enforceable.

---

## The full lifecycle

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  STAGE 0: LOCAL DEVELOPMENT                                                  │
│                                                                              │
│  Developer creates a feature branch and makes commits.                       │
│  No compliance checks run. All code is provisional.                          │
│  Recommendation (not enforced): install pre-commit hooks (gitleaks,          │
│  terraform fmt) to catch obvious issues before push.                         │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │  git push origin feature/my-change
                                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  STAGE 1: PULL REQUEST OPENED                                                │
│                                                                              │
│  Developer opens a PR targeting the default branch (main).                  │
│  GitHub fires the compliance workflow trigger (on: pull_request).            │
│                                                                              │
│  The reusable-compliance.yml workflow runs with gate: merge_gate.            │
│                                                                              │
│  What is checked at the MERGE GATE:                                          │
│                                                                              │
│  SRC-001  ─→  Branch protection is enabled on default branch         [AUTO] │
│  SRC-002  ─→  This PR has at least one reviewer assigned             [AUTO] │
│  SEC-001  ─→  No secrets in the commit or repo                       [AUTO] │
│  SEC-002  ─→  GitHub secret scanning + push protection is enabled    [AUTO] │
│  IAC-001  ─→  terraform fmt + validate passes (IAC repos only)       [AUTO] │
│  SUP-001  ─→  All dependencies are pinned (IAC/service repos)        [AUTO] │
│  SUP-002  ─→  No mutable image tags (container repos)                [AUTO] │
│  SRC-003  ─→  CODEOWNERS file exists                                 [WARN] │
│  DOC-001  ─→  README.md exists                                       [WARN] │
│  CHG-001  ─→  Change record referenced in PR (platform-repo only)    [AUTO] │
│                                                                              │
│  Controls marked [AUTO] must pass — failure blocks the PR.                  │
│  Controls marked [WARN] produce visible warnings but do not block.          │
│                                                                              │
│  The merge gate result is posted as a PR comment (✅/❌) and as a           │
│  required status check.                                                      │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                     ┌────────────┴────────────┐
                     │                         │
                     ▼                         ▼
           MERGE GATE: FAIL            MERGE GATE: PASS
           PR is blocked               Reviewer reviews code
           Developer fixes             Reviewer approves
                     │                         │
                     └────────────┬────────────┘
                                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  STAGE 2: REVIEW AND MERGE                                                   │
│                                                                              │
│  SRC-002 enforcement: at least 1 approving review is required.              │
│  GitHub's branch protection enforces this — merge is blocked without it.    │
│                                                                              │
│  After approval + passing merge gate: PR is merged to default branch.       │
│  A post-merge assessment is generated (no gate — accumulates evidence).     │
│                                                                              │
│  Evidence records from the merge gate run are retained at:                  │
│  08-evidence/collected/{repo}/{date}/{sha}-{control-id}-{ts}.yaml           │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                                  │  (time passes; more commits accumulate)
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  STAGE 3: RELEASE TAG                                                        │
│                                                                              │
│  Developer (or release automation) pushes a version tag: git tag v1.2.3     │
│  The release gate workflow runs with gate: release_gate.                    │
│                                                                              │
│  What is checked at the RELEASE GATE (in addition to merge gate controls):  │
│                                                                              │
│  SRC-003  ─→  CODEOWNERS must now be present (was warn at merge)    [BLOCK] │
│  SEC-002  ─→  Secret scanning still enabled                          [BLOCK] │
│  SEC-003  ─→  No unresolved critical dependency vulnerabilities      [WARN]  │
│  RUN-002  ─→  Container images run as non-root (container repos)    [BLOCK] │
│  RUN-001  ─→  OCI labels present on images                           [WARN]  │
│  CHG-002  ─→  Release record exists for this tag                    [BLOCK] │
│  DOC-001  ─→  README.md now required (was warn at merge)            [BLOCK] │
│  DOC-002  ─→  ADR coverage reviewed                                  [WARN]  │
│                                                                              │
│  A CHG-002 requirement means: before the release tag can pass the gate,     │
│  a release record YAML file must exist in 09-assessments/releases/v1.2.3.  │
│  This is typically created by the release workflow.                          │
│                                                                              │
│  Release gate failure: tag exists, but artifact publication is blocked.     │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                     ┌────────────┴────────────┐
                     │                         │
                     ▼                         ▼
         RELEASE GATE: FAIL          RELEASE GATE: PASS
         Fix issues, re-tag           Artifacts published
                                      CHANGELOG updated
                                             │
                                             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  STAGE 4: DEPLOYMENT TRIGGER                                                 │
│                                                                              │
│  For Terraform: a deployment is triggered (manually or by GitOps trigger).  │
│  The deployment gate workflow runs with gate: deployment_gate.               │
│                                                                              │
│  What is checked at the DEPLOYMENT GATE (in addition to release gate):      │
│                                                                              │
│  IAC-002  ─→  terraform plan reviewed before this apply (IAC repos)  [BLOCK]│
│  OBS-001  ─→  Health check declared in service contract (services)   [BLOCK]│
│  BAK-001  ─→  Backup policy declared (stateful services only)        [BLOCK]│
│  NET-001  ─→  Ingress policy declared (externally exposed services)  [BLOCK]│
│  SEC-003  ─→  No unresolved critical vulnerabilities                 [BLOCK]│
│  RUN-003  ─→  Resource limits declared                               [WARN]  │
│  OBS-002  ─→  Structured logging attestation present                 [WARN]  │
│                                                                              │
│  IAC-002 specifically: the deployment gate checks that a terraform plan     │
│  was generated for the PR that is being applied, and that the plan was      │
│  reviewed (approved by the PR reviewer) before this apply runs.             │
│                                                                              │
│  Deployment gate failure: terraform apply / service deploy is blocked.      │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                     ┌────────────┴────────────┐
                     │                         │
                     ▼                         ▼
      DEPLOYMENT GATE: FAIL        DEPLOYMENT GATE: PASS
      Fix issues, re-deploy          Infrastructure applied
                                     Evidence records written
                                     Assessment report generated
                                             │
                                             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  STAGE 5: CONTINUOUS AUDIT (ongoing)                                         │
│                                                                              │
│  Runs on a daily or weekly schedule (does not require a code change).        │
│                                                                              │
│  What is checked by CONTINUOUS AUDIT:                                        │
│                                                                              │
│  SEC-001  ─→  No secrets have been introduced since last audit      [BLOCK] │
│  SEC-002  ─→  Secret scanning is still enabled                      [BLOCK] │
│  SEC-003  ─→  No new unresolved critical vulnerabilities (ageing)   [NOTIFY]│
│  SRC-001  ─→  Branch protection is still enabled (drift check)      [BLOCK] │
│  INC-001  ─→  Incidents have incident records within 48h            [NOTIFY]│
│  BAK-001  ─→  Backup restore test is not stale (>120 days)          [WARN]  │
│                                                                              │
│  Continuous audit failures generate alerts to the compliance_contact        │
│  declared in .compliance-manifest.yaml. They do not immediately block       │
│  active operations, but a BLOCK-level failure that is not resolved within   │
│  the control's remediation SLA triggers an INC-001 incident process,        │
│  which then blocks the next deployment gate.                                 │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Why branch protection + workflow together are required

A compliance workflow alone is not enforceable. A developer with direct push access can bypass the workflow entirely:

```
Without branch protection:
  git commit -m "skip compliance"
  git push origin main          ← succeeds, no checks run
  Result: ungoverned code in main
```

With branch protection (SRC-001) and required status checks:

```
With branch protection:
  git push origin main          ← fails: "direct push not allowed"
  Developer must open a PR
  PR triggers compliance workflow
  Compliance workflow result is a required status check
  Branch protection enforces: merge blocked until required check passes
  Result: compliance gate is structurally enforced
```

**The compliance gate is the intersection of:**
1. The workflow (which does the checking)
2. Branch protection (which makes the check result mandatory for merge)
3. Required status checks (which names the specific check that must pass)

Remove any one of the three and the gate becomes advisory, not enforceable.

---

## How future repositories consume the workflow

Every new platform repository:

1. Creates `.compliance-manifest.yaml` at the root
2. Adds a CI workflow referencing the reusable workflow:
   ```yaml
   uses: angirasa_risk/platform-compliance/.github/workflows/reusable-compliance.yml@v1.0.0
   ```
3. Configures branch protection with the compliance check as a required status check

From that point, the repository is governed by `PROF-PLATFORM-V1`. The platform team does not need to configure each repository individually — the workflow is pulled by the consuming repository, not pushed.

When `platform-compliance` releases `v1.1.0` (a new minor version), consuming repositories continue using `@v1.0.0` until they explicitly update their workflow reference. This prevents silent changes to gate criteria affecting repositories without their knowledge.

---

## The four gates summarised

| Gate | Trigger | What it blocks | Key failing controls |
|---|---|---|---|
| **Merge gate** | Pull request to protected branch | PR merge | SRC-001, SEC-001, IAC-001, SUP-001 |
| **Release gate** | Version tag creation | Artifact publication | SRC-003, CHG-002, DOC-001, RUN-002 |
| **Deployment gate** | `terraform apply` / service deploy | Infrastructure change | IAC-002, OBS-001, BAK-001, NET-001 |
| **Continuous audit** | Daily/weekly schedule | Next deployment (via SLA) | SEC-001, SEC-002, SRC-001 |

Gates are cumulative: the release gate includes all merge gate controls, and the deployment gate includes all release gate controls.

---

## Handling gate failures: the options

When a gate fails, the person responsible has three legitimate paths:

**Path 1 — Fix the failing control (preferred)**  
Implement what the control requires. Commit the fix. The next CI run re-evaluates the gate. If the fix satisfies the control, evidence changes from `fail` to `pass`.

**Path 2 — Obtain a waiver**  
If the control cannot be satisfied immediately, request a waiver following the process in `09-assessments/waiver-model.md`. An approved waiver changes the assessment result from `fail` to `waived`, allowing the gate to pass. Waivers require documented rationale, risk acceptance, approver sign-off, and an expiry date.

**Path 3 — Challenge the control**  
If the control itself is wrong — the rationale is invalid, the standard mapping is incorrect, or the scope condition is misconfigured — open a PR to `platform-compliance` with a proposed change record and (if significant) an ADR. The change must be ratified before the control assessment changes.

There is no Path 4 (ignore the gate). Branch protection makes the gate structurally enforced. Bypassing branch protection requires a formal waiver of SRC-001 at platform-owner level, which creates a visible audit trail.
