# workflows — Reusable GitHub Actions Workflows

This directory contains reusable GitHub Actions workflows that implement the compliance check, evidence collection, assessment generation, and gate evaluation pipeline. These are the CI/CD entry points that downstream repositories reference.

## What this directory owns

- Reusable GitHub Actions workflow YAML files (callable workflows using `workflow_call`)

## Status

**Not yet populated.** Workflows will be authored in Phase 10 of the implementation roadmap (tasks PC-0069 to PC-0075). The policy engine (ADR) must be selected before workflows can be written.

## Planned workflows

| Workflow | Purpose |
|---|---|
| `compliance-check.yaml` | Validates the repository's compliance manifest; identifies in-scope controls |
| `evidence-collect.yaml` | Runs applicable policy checks; writes structured evidence records |
| `assessment-generate.yaml` | Aggregates evidence into a structured assessment report |
| `release-gate.yaml` | Evaluates the release gate against the assessment report |
| `deployment-gate.yaml` | Evaluates the deployment gate against the assessment report |

## How downstream repositories use these workflows

Downstream repositories reference a pinned version tag:

```yaml
jobs:
  compliance:
    uses: org/platform-compliance/.github/workflows/compliance-check.yaml@v1.0.0
    with:
      profile-id: PROF-PLATFORM-V1
      repository-type: terraform-module
```

Pin to a specific version tag (`@v1.0.0`), not `@main`. Consuming repositories opt in to new versions of `platform-compliance` explicitly.

## Workflow design constraints

- All workflows use the `workflow_call` trigger (reusable workflows)
- Workflows call policies from `../07-policies/`; they do not contain policy logic inline
- Workflows write evidence using the schema in `../08-evidence/schema/`
- Workflows evaluate gates using criteria in `../09-assessments/gates/`
- No workflow embeds repository-specific values

## What does NOT belong here

- Policy code (that is in `../07-policies/`)
- Application-specific workflow steps
- Infrastructure deployment steps
- The repository's own CI workflow (that is in `.github/workflows/self-compliance.yaml`)
