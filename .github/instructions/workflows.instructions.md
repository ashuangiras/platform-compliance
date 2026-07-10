---
description: "Use when editing GitHub Actions workflows for platform-compliance (.github/workflows). Covers the reusable-workflow permissions rule, token selection, the self-compliance bootstrap ref, and release bundle packaging."
applyTo: ".github/workflows/**"
---
# CI / Workflow Rules

Workflows: `reusable-compliance.yml` (the 7-job engine, `workflow_call`), `self-compliance.yml`
(this repo governing itself), `release.yml` (bundle packaging), `codeql.yml` (SAST for SEC-005).

## Hard rules (each learned from a failure)

- **`reusable-compliance.yml` must NOT declare a top-level `permissions:` block.** It is a
  `workflow_call` reusable — a top-level permission there causes `startup_failure`. Set
  permissions on the **calling** workflow / per-job instead.
- **Admin API calls** (branch protection, security settings) need
  `GH_TOKEN: ${{ secrets.PLATFORM_ADMIN_TOKEN || github.token }}` — `github.token` lacks admin scope.
- Callers pass `secrets: inherit` and per-job `permissions: { contents: read,
  pull-requests: write, statuses: write }`.
- Cross-job data moves via **artifacts** (policy-results, evidence, assessment), not job outputs.
- Posting the gate result to a PR uses `continue-on-error: true` so a comment failure never
  fails the gate.

## Bootstrap ref (do not remove)

`self-compliance.yml` sets
`platform-compliance-ref: ${{ github.event_name == 'pull_request' && github.head_ref || 'main' }}`
so a PR tests **its own** branch policies. This resolves the chicken-and-egg where a policy
change could never pass its own gate.

## Release packaging

`release.yml` triggers on `v*` / `v*-rc.*` tags, packages `07-policies/opa/` into
`policies.tar.gz` + `.sha256` + an SBOM (`sbom.cdx.json` via `anchore/sbom-action`).
The reusable workflow fetches the release asset with SHA-256 verification and falls back to a
branch archive. Keep that verify-then-fallback path intact.

## Post-flight

Lint intent locally where possible, then push to a branch and let `self-compliance.yml` run.
Never merge on red; use the documented bootstrap-merge only when all 7 jobs are green.
