# Phase 10 — Reusable GitHub Workflow

**Status:** 🔶 Skeleton  
**Tasks:** PC-0069 to PC-0075

## Goal
A reusable GitHub Actions workflow that any platform repository can call to run the full compliance check pipeline: validate manifest → run policies → collect evidence → generate assessment → evaluate gate.

## What exists
`.github/workflows/reusable-compliance.yml` — 7-job structure:
1. `validate-manifest` — validates `.compliance-manifest.yaml` against schema ✅
2. `check-required-files` — checks CODEOWNERS, README, .gitignore ✅
3. `secret-scan-check` — calls gitleaks + GitHub secret scanning API 🔶 (placeholder)
4. `policy-checks` — fetches policy bundle, runs OPA against inputs 🔶 (placeholder)
5. `collect-evidence` — converts policy results to evidence records + hashes 🔶 (Python stub)
6. `generate-assessment` — aggregates evidence into assessment report 🔶 (Python stub)
7. `evaluate-gate` — evaluates gate criteria, posts PR comment, fails if blocking 🔶 (simplified)

`.github/workflows/self-compliance.yml` — uses the above for platform-compliance's own CI ✅

## TODOs remaining (Phase A work)

| Job | What needs replacing |
|---|---|
| `policy-checks` | Real OPA evaluation against GitHub API inputs, Dockerfile parsing, Terraform HCL parsing |
| `secret-scan-check` | Real gitleaks invocation (requires gitleaks binary or GitHub Actions) |
| `collect-evidence` | Real evidence schema conformance, real artifact_hash computation |
| `generate-assessment` | Real waiver application, real gate criteria evaluation |
| `evaluate-gate` | Real per-control blocking logic from gate criteria file |

## Key dependencies
- **ADR-0006 (evidence storage):** The `collect-evidence` job must know where to write evidence
- **ADR-0009 (policy bundle):** The `policy-checks` job needs a stable way to fetch the OPA bundle

## Acceptance criteria for "complete"
- The workflow runs end-to-end on `platform-compliance` itself in GitHub Actions
- It produces real evidence records that validate against `evidence.schema.json`
- It produces a real assessment report that validates against `assessment.schema.json`
- The merge gate check blocks a deliberately non-compliant PR from merging
