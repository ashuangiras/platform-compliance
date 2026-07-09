# Phase B — Tooling and Developer Experience

**Status:** ⬜ Not started  
**Horizon:** v1.1.0 (after Phase A)  
**Hard blockers:** Phase A complete, ADR-0009 (policy bundle), ADR-0010 (versioning), ADR-0011 (`plt` CLI tech)

## Goal

A developer can interact with the compliance system without editing raw YAML. The `plt` CLI makes compliance operations discoverable and self-documenting. The policy bundle is published as a versioned artifact. Onboarding a new repository takes less than 15 minutes.

## Deliverables

### B.1 — `plt` CLI implementation

**Language:** to be decided in ADR-0011. Current candidate: Go (single-binary distribution, no runtime dependency).

| Command | What it does |
|---|---|
| `plt validate <file>` | Validate a YAML file against its schema |
| `plt validate-repo [path]` | Validate a repo's manifest + cross-check profile coverage |
| `plt new control` | Scaffold a new control from template in the correct domain directory |
| `plt new adr` | Scaffold ADR from template with next sequential ID |
| `plt new waiver` | Scaffold waiver from template |
| `plt gate check release [repo]` | Evaluate release gate for a repository against evidence |
| `plt gate check deploy [repo]` | Evaluate deployment gate |
| `plt evidence submit <file>` | Validate and submit an evidence record |
| `plt report coverage` | Show standards coverage: which standards map to which controls |
| `plt report status [repo]` | Show compliance posture for a repository |

### B.2 — Policy bundle distribution (depends on ADR-0009)

The reusable workflow currently does a `curl` against the raw GitHub API to fetch policies. This is fragile and couples consumers to network availability. The solution:

**OPA bundle format:** Package `07-policies/opa/` as an OPA bundle tarball, sign it, and publish it as a GitHub release artifact alongside each `platform-compliance` release.

Consuming repos reference the bundle at a pinned version:
```yaml
# In the reusable workflow
- name: Fetch policy bundle
  run: |
    curl -sSfL "https://github.com/angirasa_risk/platform-compliance/releases/download/v1.1.0/policies.tar.gz" \
      | tar -xz -C /tmp/policy-bundle
```

### B.3 — Profile variants for common repository types

Currently `PROF-PLATFORM-V1` governs all repository types. This creates noise: terraform-module repos are evaluated against service controls that don't apply. The solution is lean profiles:

| Profile | Applicable to | Inherits |
|---|---|---|
| `PROF-BASE` | Universal — all repos | (new base, minimal) |
| `PROF-TERRAFORM-MODULE-V1` | terraform-module type | PROF-BASE |
| `PROF-TERRAFORM-ROOT-V1` | terraform-root type | PROF-TERRAFORM-MODULE-V1 |
| `PROF-SERVICE-V1` | service type | PROF-BASE |
| `PROF-PLATFORM-V1` | platform-repo type | PROF-BASE (all controls) |

### B.4 — Developer onboarding documentation

- `docs/onboarding.md` — complete onboarding guide (PC-0003, currently missing)
- `docs/authoring-controls.md` — how to add a control: examples, schema reference, mapping requirement (PC-0006, currently missing)
- `docs/authoring-policies.md` — OPA policy authoring guide with input format examples per context

### B.5 — Versioning and release automation (depends on ADR-0010)

Automate the release gate process:
- Script that generates a release record YAML from the current assessment
- Script that validates all 7 readiness conditions from Phase 12
- GitHub Actions workflow for tagging and publishing the policy bundle artifact

## Task IDs: PC-0116 to PC-0145
See [`tasks/v2-operationalization.yaml`](../tasks/v2-operationalization.yaml)

## Acceptance criteria
- `plt validate .compliance-manifest.yaml` works locally with no network access
- `plt new control` creates a valid, schema-conformant control stub in the correct directory
- `plt gate check release .` correctly identifies the release gate result for the current repo state
- The policy bundle is published as a GitHub release artifact
- A new contributor can set up a governed repository following `docs/onboarding.md` in under 15 minutes
