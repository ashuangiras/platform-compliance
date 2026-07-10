# OPA/Rego Policy Engine

This directory contains compliance policy checks written in [Rego](https://www.openpolicyagent.org/docs/latest/policy-language/), the policy language for [Open Policy Agent (OPA)](https://www.openpolicyagent.org/).

OPA is the primary policy engine for `platform-compliance`. This decision will be formally ratified in ADR-0004.

---

## Why OPA/Rego

| Property | Relevance |
|---|---|
| Declarative | Policy intent is expressed as rules, not imperative steps |
| Testable | `opa test` runs unit tests against fixtures without CI |
| Structured output | Rego produces JSON natively; maps directly to evidence records |
| `conftest` integration | `conftest` wraps OPA for easy YAML/JSON input validation in CI |
| Language-independent | Policies describe rules; the engine evaluates them |
| Deterministic | Same input always produces same output |

---

## Status

**Not yet populated.** This directory will be populated in Phase 7 of the implementation roadmap (tasks PC-0049 to PC-0059), after implementation bindings (Phase 6) are complete.

The directory structure and conventions are established now to avoid reorganization later.

---

## Directory structure

```
opa/
├── README.md                    ← this file
├── SRC/
│   ├── POL-SRC-001-GITHUB-001.rego
│   ├── POL-SRC-001-GITHUB-001.check.yaml
│   ├── POL-SRC-002-GITHUB-001.rego
│   └── ...
├── SEC/
│   ├── POL-SEC-001-GITHUB-001.rego
│   └── ...
├── IAC/
│   ├── POL-IAC-001-TERRAFORM-001.rego
│   └── ...
└── ...
```

---

## Package naming convention

Every Rego policy must use this package convention:

```rego
# File: opa/SRC/POL-SRC-001-GITHUB-001.rego
package platform.src.src_001_github
```

Convention: `platform.{domain_lower}.{control_id_snake_case}_{context_lower}`

---

## Input format

OPA policies receive a structured JSON input document. The input schema depends on the technology context.

### GitHub context input

Policies in the `github` context receive:

```json
{
  "input": {
    "repository": {
      "name": "my-repo",
      "url": "https://github.com/org/my-repo",
      "type": "terraform-module"
    },
    "commit_sha": "abc123...",
    "branch_protection": { ... },    // GitHub API response for branch protection
    "secret_scanning": { ... },      // GitHub API response for security settings
    "files": [ ... ],                // List of files at the commit (path, sha, size)
    "manifest": { ... }              // Parsed .compliance-manifest.yaml
  }
}
```

### Terraform context input

```json
{
  "input": {
    "terraform_files": [ ... ],     // Parsed HCL structures
    "required_providers": { ... },
    "module_calls": [ ... ],
    "fmt_result": { "exit_code": 0, "diff": "" },
    "validate_result": { "exit_code": 0, "errors": [] }
  }
}
```

### Docker context input

```json
{
  "input": {
    "dockerfiles": [ ... ],         // Parsed Dockerfile instructions
    "compose_files": [ ... ],       // Parsed Docker Compose services
    "images_referenced": [ ... ]    // All FROM and image: references found
  }
}
```

---

## Output format contract

Every OPA policy must define a `result` rule that produces this structure:

```rego
result := {
  "result": "pass",       # "pass" | "fail" | "warn" | "not_applicable" | "error"
  "details": {
    "checked": "What the policy evaluated",
    "found": "What was actually found",
    "expected": "What was required",
    "message": "Human-readable explanation of the result"
  }
}
```

The `evidence-collect` workflow extracts this `result` object, computes the `artifact_hash` over `details`, and writes the full evidence record.

> **`warn`** is used when a threshold-based control triggers the lower of two thresholds (e.g. bundle-size budget at 500 KB); the block gate fires at the higher threshold (e.g. 2 MB). A `warn` result does not block the gate but is surfaced as an advisory in the assessment report.

---

## Policy metadata companion file

Every `.rego` file must have a companion `.check.yaml` file in the same directory:

```yaml
# POL-SRC-001-GITHUB-001.check.yaml
id: POL-SRC-001-GITHUB-001
title: "Branch protection is enabled with required settings"
binding_ids:
  - BIND-SRC-001-GITHUB
engine: opa
file_path: "07-policies/opa/SRC/POL-SRC-001-GITHUB-001.rego"
pass_criteria: >
  The default branch has protection enabled with: required PR reviews (≥1),
  status checks required, force pushes disabled, deletions disabled.
fail_criteria: >
  Branch protection is disabled, or one or more required settings are not enabled.
evidence_type: github-branch-protection-api-response
severity: high
```

---

## Testing policies

All policies must have test files. Tests live in `../tests/fixtures/{DOMAIN}/`:

```bash
# Run all OPA tests
opa test 07-policies/opa/ --verbose

# Test a specific policy
opa test 07-policies/opa/SRC/ --verbose

# Evaluate a policy against a YAML fixture manually (OPA ≥0.21 supports YAML input natively)
opa eval \
  --data 07-policies/opa/SRC/POL-SRC-001-GITHUB-001.rego \
  --input 07-policies/tests/fixtures/SRC/src-001-pass.yaml \
  "data.platform.src.src_001_github.result"
```

### Test fixture format

All fixtures are `.yaml` (see ADR-0005). Use comments to explain what scenario is being tested:

```yaml
# Fixture: SRC-001 — PASS
# Scenario: Full branch protection on a platform-repo.
# Expected result: { "result": "pass" }
input:
  repository: { name: test-repo, type: platform-repo }
  default_branch: main
  branch_protection:
    required_pull_request_reviews:
      required_approving_review_count: 1
      dismiss_stale_reviews: true
    allow_force_pushes: { enabled: false }
    allow_deletions: { enabled: false }
```

Expected output for the pass fixture:
```json
{ "result": "pass", "details": { ... } }
```

---

## First policies to implement (Phase 7)

In order of dependency and gate impact:

| Priority | Policy file | Control | Gate |
|---|---|---|---|
| 1 | `SRC/POL-SRC-001-GITHUB-001.rego` | SRC-001 (branch protection) | Merge |
| 2 | `SEC/POL-SEC-001-GITHUB-001.rego` | SEC-001 (no secrets) | Merge |
| 3 | `SEC/POL-SEC-002-GITHUB-001.rego` | SEC-002 (secret scanning) | Release |
| 4 | `SRC/POL-SRC-002-GITHUB-001.rego` | SRC-002 (PR required) | Merge |
| 5 | `SRC/POL-SRC-003-GITHUB-001.rego` | SRC-003 (CODEOWNERS) | Release |
| 6 | `IAC/POL-IAC-001-TERRAFORM-001.rego` | IAC-001 (fmt+validate) | Merge (IAC repos) |
| 7 | `SUP/POL-SUP-001-TERRAFORM-001.rego` | SUP-001 (pinned deps) | Merge |
| 8 | `SUP/POL-SUP-002-DOCKER-001.rego` | SUP-002 (no latest tag) | Merge (container repos) |
| 9 | `RUN/POL-RUN-002-DOCKER-001.rego` | RUN-002 (non-root user) | Release |
| 10 | `DOC/POL-DOC-001-GITHUB-001.rego` | DOC-001 (README exists) | Merge |
