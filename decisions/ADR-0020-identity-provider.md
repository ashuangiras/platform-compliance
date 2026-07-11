# ADR-0020: Identity Provider — Authentik for Platform-Wide SSO

| Field | Value |
|---|---|
| **ID** | ADR-0020 |
| **Status** | accepted |
| **Date** | 2026-07-11 |
| **Deciders** | platform-team |

---

## Context

The platform now runs multiple services — Vault, Consul, MinIO, Grafana, Prometheus — each with its own authentication mechanism:

| Service | Current auth | Problem |
|---|---|---|
| Vault | Root token / AppRole | Manual rotation; no MFA; separate identity |
| MinIO | Root credential in tfvars | Static secret; no RBAC per user |
| Grafana | Local admin password | Separate password; no group-based access |
| Consul | ACL tokens | Opaque tokens; no human identity |
| Prometheus | None | No auth at all on default install |

This creates five separate identity silos. Every new service added to `platform-services` would introduce a sixth. The consequences are:

1. **No single source of truth for who has access to what** — revocation on offboarding requires touching five systems
2. **No MFA** across any service — a compromised password reaches everything it has access to
3. **No audit trail linking human identity to actions** — "admin token X did Y" is not "Alice did Y"
4. **Inconsistent access control** — some services have RBAC, others have a single shared admin
5. **REL-001/OBS-001 gap** — Prometheus has no auth and should not be directly exposed

A platform identity provider (IdP) centralises authentication and enables SSO via OIDC/OAuth2 across all services without each service maintaining its own user database.

---

## Options Considered

### Option A — Keycloak (Java, Red Hat)

**Pros:** Most widely deployed open-source IdP; battle-hardened at enterprise scale; comprehensive SAML, OIDC, LDAP; large community.

**Cons:** Heavy JVM footprint (≥512MB RAM minimum, 1GB+ recommended); complex configuration UI; slow startup (30–60s); overkill for a small self-hosted platform.

**Verdict:** Rejected. The operational cost of running and maintaining Keycloak outweighs its enterprise feature advantage for a single-operator platform.

### Option B — Dex (CNCF)

**Pros:** Lightweight Go binary; CNCF project; native Kubernetes integration; OIDC focus.

**Cons:** Read-only IdP — Dex is a connector, not a user store. Requires an upstream LDAP/GitHub/other IdP to federate. Cannot manage local platform users directly.

**Verdict:** Rejected. Dex requires a separate user store (LDAP server) which adds another service. Not suitable as the primary identity layer.

### Option C — Zitadel

**Pros:** Modern, cloud-native, OIDC-first; built-in SCIM; strong audit logging; written in Go.

**Cons:** Requires CockroachDB or PostgreSQL as backing store — a significant additional dependency; relatively young project.

**Verdict:** Rejected. Database dependency adds operational complexity before the platform has a managed database service.

### Option D — Authentik (accepted)

**Pros:**
- Self-contained Docker deployment (single container + PostgreSQL + Redis, or all-in-one)
- First-class OIDC, SAML 2.0, LDAP proxy, and forward authentication (proxy provider)
- Native Vault OIDC integration — Vault can use Authentik as its OIDC provider
- MinIO OIDC support — MinIO natively accepts OIDC tokens from Authentik
- Grafana OIDC — Grafana has built-in OAuth2/OIDC sign-in
- Forward authentication — services that don't natively support OIDC (Prometheus, Consul UI) can be protected via Authentik's outpost/proxy provider
- Written in Python/Django (same tooling as existing platform collectors)
- Active development; good documentation; growing adoption in self-hosted community
- Lightweight enough for single-host staging (256MB RAM minimum)

**Cons:** Python runtime; requires PostgreSQL (adds a stateful dependency); forward auth adds an additional network hop for proxied services.

**Verdict:** Accepted. Authentik provides the best balance of features, operational simplicity, and community support for a self-hosted platform of this scale.

---

## Decision

**Authentik is the platform identity provider.** All platform services that support OIDC/OAuth2 integrate directly; services without native SSO support use Authentik's forward authentication proxy.

### Deployment topology

Authentik runs as a service in `platform-services`, deployed before any user-facing service:

```
platform-services/
  identity/           ← new component
    main.tf           ← Authentik + PostgreSQL + Redis
    variables.tf
    outputs.tf
    service-contracts/
      authentik.yaml
```

### Authentication integration map

| Service | Integration method | Authentik provider type |
|---|---|---|
| **Vault** | Vault OIDC auth method → Authentik OIDC application | OIDC provider |
| **MinIO** | MinIO OpenID configuration → Authentik | OIDC provider |
| **Grafana** | Grafana OAuth2 settings → Authentik | OAuth2/OIDC provider |
| **Consul UI** | Authentik outpost (forward auth) | Proxy provider |
| **Prometheus** | Authentik outpost (forward auth) | Proxy provider |
| **MinIO console** | Authentik outpost or OIDC | OIDC or proxy |

### User lifecycle

All human identities are managed exclusively in Authentik. No service maintains a local user database for human operators:

1. **Provision**: User created in Authentik → assigned to platform group(s)
2. **Authentication**: User signs in via Authentik SSO → service receives OIDC token
3. **Authorisation**: Service maps Authentik group membership to internal roles (e.g., Authentik `platform-admins` group → Vault `admin` policy)
4. **Revocation**: User disabled in Authentik → access revoked across all services within token TTL (default 5m)
5. **MFA**: Enforced at the Authentik layer; all services inherit MFA without per-service configuration

### Service accounts (non-human)

Service-to-service authentication continues to use Vault AppRole. Authentik governs human identity only; machine identity remains with Vault.

### Technology context

A new technology context `authentik` is registered in `02-taxonomy/technology-contexts.yaml`. Repositories that integrate with Authentik (initially `platform-services`) declare this context in their `.compliance-manifest.yaml`.

### New control (future)

**ACC-002** (future, Phase D): Every platform service accessible to human operators must enforce authentication via the platform identity provider. Services that allow unauthenticated access or local-only credentials (outside of break-glass procedures) fail this control.

---

## Consequences

### Positive
- Single user store, single revocation point, single MFA enforcement layer
- Audit trail linking human identity to actions across all services
- No more static credentials in `terraform.tfvars` for human-facing services
- Onboarding/offboarding is a single Authentik operation

### Negative
- **New critical dependency**: Authentik becomes a hard dependency for all human access. If Authentik is down, human operators cannot authenticate (machine workloads via AppRole are unaffected). Mitigation: break-glass emergency tokens stored in Vault's emergency response kit.
- **Additional stateful services**: Authentik requires PostgreSQL and Redis. These add to the backup obligation (BAK-001 applies to Authentik's database). This will be deployed as part of `platform-services/identity/` using Docker containers managed by Terraform.
- **Bootstrap dependency**: The platform engineer who runs the initial Authentik setup needs a local admin account before SSO is configured. This is the same bootstrap pattern as Vault initialisation.

### Migration path for existing services

After Authentik is deployed:
1. Grafana: configure OIDC in `platform-services/observability/` Terraform config
2. MinIO: configure OIDC endpoint in `platform-infrastructure/storage/` config
3. Vault: add OIDC auth method via `platform-infrastructure/secrets/` config
4. Consul/Prometheus: deploy Authentik outpost and configure forward auth

Each migration is a governed PR with a Change Record.

### Implementation tasks (Phase C extension)

| Task | Depends on |
|---|---|
| Deploy Authentik (PostgreSQL + Redis + Authentik) | Vault running (secrets) |
| Configure OIDC applications for each service | Authentik deployed |
| Migrate Grafana auth → Authentik | Authentik OIDC app |
| Configure MinIO OIDC | Authentik OIDC app |
| Add Vault OIDC auth method | Authentik OIDC app |
| Deploy forward auth proxy for Consul/Prometheus | Authentik outpost |
| Define ACC-002 control | All migrations complete |
