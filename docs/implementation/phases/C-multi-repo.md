# Phase C — Multi-Repo Platform

**Status:** ⬜ Not started  
**Horizon:** v2.0.0  
**Hard blockers:** v1.0.0 tag (ADR-0003), ADR-0008 (secrets), ADR-0012 (multi-env gates), ADR-0014 (Terraform state)

## Goal

The second, third, and fourth platform repositories are created under governance. Each one is born compliant. The platform governs real infrastructure, not just itself.

## Planned repository sequence

The order matters. Each repository must pass its merge gate before the next is created.

```
platform-compliance  ← already exists (v1.0.0 tagged)
       │
       ▼
platform-modules          Reusable Terraform modules
       │                  Profile: PROF-TERRAFORM-MODULE-V1
       ▼
platform-infrastructure   Root Terraform configurations
       │                  Profile: PROF-TERRAFORM-ROOT-V1
       ▼
platform-services         Deployable containerised services
                          Profile: PROF-SERVICE-V1
```

### platform-modules
- First non-governance repository
- Contains reusable Terraform modules (networking, compute, storage patterns)
- Must have: pinned providers (SUP-001), terraform fmt (IAC-001), no hardcoded values (IAC-003)
- No apply operations — validates only

### platform-infrastructure
- Root Terraform configurations that apply real infrastructure
- Requires ADR-0014 (Terraform state backend decided)
- Must have: plan-before-apply workflow (IAC-002), deployment gate in CI
- First time the deployment gate runs for real

### platform-services
- Requires ADR-0008 (secret management backend)
- First services: probably observability stack (Grafana/Prometheus) and a Git server mirror
- Must have: service contracts, health checks (OBS-001), non-root containers (RUN-002)

## New controls needed in Phase C

### CAT (Service Catalog) domain — currently empty
| Proposed ID | Statement |
|---|---|
| CAT-001 | Every service must be registered in the service catalog with a service contract |
| CAT-002 | Service dependencies must be declared in the service contract |

### REL (Reliability) domain — currently empty
| Proposed ID | Statement |
|---|---|
| REL-001 | Services must declare SLO targets in their service contract |
| REL-002 | Error budget policy must be defined before a service reaches production |

### Multi-environment profile (depends on ADR-0012)
- `PROF-STAGING-V1` — relaxed enforcement (warn instead of block for some controls)
- `PROF-PRODUCTION-V1` — full enforcement
- Gate criteria differentiation by environment type

## Placeholder resolution
All `[PLACEHOLDER: ...]` markers in mapping files (PC-0009, PC-0010, PC-0011) must be resolved before Phase C begins — controls cited in infrastructure repositories need clean provenance.

## Task IDs: PC-0146 to PC-0185
See [`tasks/v3-platform.yaml`](../tasks/v3-platform.yaml)

## Acceptance criteria
- 3 additional repositories exist under governance, each with a passing merge gate
- `platform-infrastructure` has completed at least one full deployment gate + terraform apply cycle
- `platform-services` has at least one service with a passing deployment gate assessment
- CAT-001 is active and all services have registered service contracts
- No `ashuangiras` placeholder remains in any file in any governed repository
