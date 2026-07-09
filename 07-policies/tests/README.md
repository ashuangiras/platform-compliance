# 07-policies/tests — Policy Test Fixtures

This directory contains JSON test fixtures for OPA policy tests. Each fixture provides structured input data that exercises a specific policy check.

## Structure

```
tests/fixtures/{DOMAIN}/
  {control-id}-pass.yaml       — input that produces result: "pass"
  {control-id}-fail.yaml       — input that produces result: "fail"
  {control-id}-fail-{reason}.yaml  — specific failure scenario
```

## Fixture format

Fixtures wrap the policy input in an `input` key matching the OPA convention.
Use YAML comments to explain what scenario the fixture tests and why:

```yaml
# Fixture: SRC-001 — PASS
# Scenario: Fully compliant branch protection on a platform-repo.
# Expected policy result: { "result": "pass" }
input:
  repository:
    name: test-repo
    type: platform-repo
  default_branch: main
  branch_protection:
    required_pull_request_reviews:
      required_approving_review_count: 1
    allow_force_pushes:
      enabled: false
```

All fixtures are `.yaml` (see ADR-0005).

## Running tests

```bash
# Test all policies
opa test 07-policies/opa/ --verbose

# Test a specific policy manually
opa eval \
  --data 07-policies/opa/SRC/POL-SRC-001-GITHUB-001.rego \
  --input 07-policies/tests/fixtures/SRC/src-001-pass.yaml \
  "data.platform.src.src_001_github.result"
```

## What does NOT belong here

- Policy `.rego` files (those are in `../opa/`)
- Test fixtures for schemas or other non-policy objects
