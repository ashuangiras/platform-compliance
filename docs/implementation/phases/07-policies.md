# Phase 07 — Policy-as-Code

**Status:** 🔶 Partial (~55%)  
**Tasks:** PC-0048 to PC-0059

## Goal
Every automated control has an OPA/Rego policy that verifies its binding, produces structured evidence output, and has passing + failing test fixtures.

## What exists (14 policies)

| Policy | Control | Gate | Fixtures |
|---|---|---|---|
| `POL-SRC-001-GITHUB-001` | SRC-001 (branch protection) | Merge | ✅ |
| `POL-SRC-002-GITHUB-001` | SRC-002 (PR required) | Merge | ✅ |
| `POL-SRC-003-GITHUB-001` | SRC-003 (CODEOWNERS) | Release | ✅ |
| `POL-SEC-001-GITHUB-001` | SEC-001 (no secrets) | Merge | ✅ |
| `POL-SEC-002-GITHUB-001` | SEC-002 (secret scanning) | Release | ✅ |
| `POL-SEC-003-GITHUB-001` | SEC-003 (vuln SLA) | Deploy | ✅ |
| `POL-IAC-001-TERRAFORM-001` | IAC-001 (fmt+validate) | Merge | ✅ |
| `POL-SUP-001-TERRAFORM-001` | SUP-001 (pinned deps, tf) | Merge | ✅ |
| `POL-SUP-001-GITHUB-ACTIONS-001` | SUP-001 (pinned actions) | Merge | ✅ |
| `POL-SUP-002-DOCKER-001` | SUP-002 (no latest tag) | Merge | ✅ |
| `POL-RUN-001-DOCKER-001` | RUN-001 (OCI labels) | Release | ✅ |
| `POL-RUN-002-DOCKER-001` | RUN-002 (non-root user) | Release | ✅ |
| `POL-DOC-001-GITHUB-001` | DOC-001 (README present) | Merge | ✅ |
| `POL-CHG-002-GITHUB-001` | CHG-002 (release record) | Release | ✅ |

## What's missing (Phase A will address)

| Priority | Planned policy | Control | Gate |
|---|---|---|---|
| High | `POL-OBS-001-DOCKER-001` | OBS-001 (Dockerfile HEALTHCHECK) | Deploy |
| High | `POL-BAK-001-GITHUB-001` | BAK-001 (backup policy declaration) | Deploy |
| High | `POL-NET-001-GITHUB-001` | NET-001 (ingress policy declaration) | Deploy |
| High | `POL-CHG-001-GITHUB-001` | CHG-001 (change record in PR) | Merge |
| Med | `POL-IAC-002-TERRAFORM-001` | IAC-002 (plan-before-apply) | Deploy |
| Med | `POL-IAC-003-TERRAFORM-001` | IAC-003 (no hardcoded values) | Merge |
| Med | `POL-RUN-003-DOCKER-001` | RUN-003 (resource limits) | Deploy |
| Low | `POL-OBS-002-GITHUB-001` | OBS-002 (structured logging attestation) | Release |

## Architecture (ADR-0004)
- Engine: OPA/Rego, primary
- Shell scripts: data collection only (GitHub API calls, terraform CLI)
- Package convention: `package platform.{domain}.{control_id_snake_case}_{context}`
- Output contract: `result := {"result": "pass|fail|not_applicable|error", "details": {...}}`
- Fixtures: all YAML (ADR-0005)
