# ADR-0008: Secret Management Backend — HashiCorp Vault

| Field | Value |
|---|---|
| **ID** | ADR-0008 |
| **Status** | accepted |
| **Date** | 2026-07-10 |
| **Deciders** | platform-team |
| **Supersedes** | docs/implementation/decisions-needed/ADR-0008-secret-management.md (draft) |

---

## Context

SEC-001 prohibits plaintext secrets in any repository. `platform-infrastructure` and
`platform-services` require a compliant path for runtime secret injection — database
passwords, API tokens, TLS private keys — before the first service deployment.

The draft (docs/implementation/decisions-needed/ADR-0008-secret-management.md) evaluated
four options: SOPS + age, HashiCorp Vault (self-hosted), age-encrypted Terraform-native
secrets, and GitHub Actions encrypted secrets + OIDC. This ADR records the accepted decision.

Phase gate PC-0141 blocks the first service deployment until this decision is ratified and
the designated backend is operational.

---

## Decision

**HashiCorp Vault (self-hosted on `platform-infrastructure`)** is the designated secret
management backend for all platform services.

### Deployment

Vault is deployed on `platform-infrastructure` as the primary secret store. No service in
`platform-services` may store or inject plaintext secrets outside of Vault.

### Injection patterns

| Consumer | Authentication method |
|---|---|
| GitHub Actions CI | GitHub OIDC → Vault JWT auth method |
| Runtime services | Vault Agent sidecar (preferred) or direct Vault API via AppRole |

### Legacy / transitional secrets

Static secrets that pre-date this decision are encrypted with **SOPS + age** and stored in
the relevant repository until they are migrated into Vault. SOPS + age is a transitional
measure only; all new secrets MUST go directly into Vault.

### Backup obligation

Vault itself is a stateful service. BAK-001 applies to the Vault data store — backup of the
Vault storage backend is mandatory and is governed by the binding for BAK-001 in the
`terraform` and `runtime-linux` contexts on `platform-infrastructure`.

### Phase gate

No service in `platform-services` may be deployed to any environment until Vault integration
is complete and the service's secrets are loaded into Vault (tracked as PC-0141).

---

## Consequences

- `platform-infrastructure` must deploy and operationalise Vault before any service can
  inject secrets. This creates a hard prerequisite on Phase C infrastructure readiness.
- A new technology context `vault` is registered in `02-taxonomy/technology-contexts.yaml`.
  Vault-specific controls (AppRole rotation, Vault Agent sidecar, audit log) will be bound
  in a `vault` binding context.
- The SEC-001 implementation binding is updated to name Vault as the designated backend.
- BAK-001 binding for the Vault data store is required on `platform-infrastructure`.
- SOPS + age configuration must remain in `platform-infrastructure` for the transitional
  period; a migration work item tracks removal once all legacy secrets are in Vault.
- The Vault cluster becomes a critical-path dependency — its availability SLO must be
  defined before service SLOs are committed.
