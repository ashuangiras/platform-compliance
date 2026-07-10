# ADR-0019: Application Configuration Management — Vault + Consul

| Field | Value |
|---|---|
| **ID** | ADR-0019 |
| **Status** | accepted |
| **Date** | 2026-07-10 |
| **Deciders** | platform-team |

---

## Context

Services need two categories of external configuration at runtime:

1. **Secrets** — credentials, keys, tokens. Must never appear in plaintext. Governed by
   ADR-0008 (HashiCorp Vault).
2. **Application configuration (non-secrets)** — feature flags, service endpoint URLs,
   tuning parameters, peer service addresses. These change more frequently than secrets,
   are not sensitive by default, but must still be governed (a config change that disables
   a circuit breaker is a platform change).

Using environment variables for non-trivial configuration is fragile: variables are not
versioned, not audited, and not discoverable across services. A shared configuration store
is required.

---

## Decision

### Secrets: HashiCorp Vault (per ADR-0008)

All secrets are injected from Vault. See ADR-0008. Not repeated here.

### Application configuration: HashiCorp Consul

**HashiCorp Consul** is the platform's application configuration store:

| Consul capability | Platform use |
|---|---|
| **KV store** | Feature flags, service URLs, tuning parameters |
| **Service Discovery** | Service registration with health-checked DNS (`<service>.service.consul`) |
| **Consul Connect** (service mesh) | Optional mTLS between services — adopted per service |

### Runtime configuration pattern

Services follow this pattern at startup:

1. Read non-secret configuration from Consul KV (e.g., `config/<service>/feature-flags`).
2. Read secrets from Vault via Vault Agent or direct API call.
3. No environment variables for non-trivial configuration. `PORT`, `LOG_LEVEL`, and other
   truly process-local variables are exempt.

### Configuration change governance

Changes to Consul KV that affect service behaviour are treated as governed platform changes:

- **SEC-001** applies: no secrets may be stored in Consul KV (Vault only).
- **CHG-001** applies: changes to Consul KV for platform-critical config paths must
  reference a Change Record and be applied via the governed change process, not ad-hoc.

### Technology context registration

`consul` is registered as a new technology context in `02-taxonomy/technology-contexts.yaml`.
A `consul` binding context will govern Consul-specific controls (KV ACLs, health check
registration, Connect policy) in a future extension to ADR-0016.

### Deployment topology

Both Vault and Consul are deployed on `platform-infrastructure` as co-located platform
services. They are not deployed per-environment — staging and production services connect
to the same Consul cluster with environment-namespaced KV paths
(e.g., `config/staging/<service>/` vs `config/production/<service>/`).

---

## Consequences

- `platform-infrastructure` deploys both Vault and Consul before any service is operational.
- The new technology context `consul` is registered in `02-taxonomy/technology-contexts.yaml`
  in this change.
- SEC-001 binding is extended: Consul KV must not contain secrets (enforced via Consul ACL
  policy that denies writes to secret-classified paths from non-Vault actors).
- CHG-001 binding for `consul` context will govern who may write to Consul KV and require
  a Change Record for platform-critical paths. This binding is deferred to a future ADR-0016
  extension.
- Services that adopt Consul Connect gain mTLS between services without additional
  certificate management — the compliance binding for NET-001 (network segmentation) may
  reference Consul Connect as a compliant implementation in future.
- A Consul agent must run on every host that services consume (or services must use the
  HTTP API directly). The deployment model is documented in `platform-infrastructure`.
