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

Authentik is deployed in **`platform-infrastructure`** alongside Vault, Consul, and MinIO — not in `platform-services`. The rationale:

1. Authentik is a platform dependency, not a business service. Vault and MinIO need it to be running before services can authenticate.
2. Placing it in `platform-infrastructure` makes it part of the foundation that `platform-services` builds on.
3. The integration between Authentik and Vault/MinIO must be automated and lifecycle-managed with the infrastructure, not the services.
4. PostgreSQL and Redis are **shared data infrastructure** — not components of the identity system. They are deployed as a separate `data/` component that any future service in `platform-infrastructure` or `platform-services` can consume by adding a database or ACL entry.

See the full topology and module design in the "New modules required" section below.

### Automated integration (Terraform-managed)

All integration between Authentik and the platform services is managed by Terraform — no manual console configuration. This is non-negotiable: manually configured SSO is undocumented, unversioned, and fails the governance requirement (IAC-002, IAC-003).

The `platform-infrastructure/integrations/` component uses three Terraform providers:

| Provider | Manages |
|---|---|
| `goauthentik/authentik` | Authentik applications, OIDC providers, groups, flows, policies |
| `hashicorp/vault` | Vault OIDC JWT auth backend, roles, policies |
| `registry.terraform.io/hashicorp/aws` (MinIO-compatible) or MinIO Terraform provider | MinIO OIDC identity provider configuration |

**What is declared as code:**

```hcl
# identity/ — deploy Authentik stack
module "identity" {
  source = "git::...//modules/identity/authentik?ref=v1.x.x"
  # PostgreSQL + Redis + Authentik containers
  # Outputs: authentik_url, authentik_token (stored in Vault)
}

# integrations/ — configure SSO
resource "authentik_provider_oauth2" "vault" {
  name          = "vault"
  client_id     = "vault"
  # ... redirect URIs, scopes, group claims
}

resource "vault_jwt_auth_backend" "authentik" {
  path         = "oidc"
  type         = "oidc"
  oidc_discovery_url = module.identity.authentik_url
  # ... Vault reads group claims → maps to policies
}

# MinIO OIDC configured via MinIO provider or null_resource + mc admin
```

Every authentication rule, group mapping, and policy binding is a PR with a Change Record.

### New modules required in `platform-modules`

#### Data infrastructure (shared — not identity-specific)

PostgreSQL and Redis are general-purpose data services. A future observability service, a task queue, or any stateful service may need them. Deploying a new PostgreSQL or Redis per service wastes resources and multiplies operational burden. The correct pattern is one instance of each, with proper database/user/ACL separation per consumer.

```
modules/data/
  postgresql/   ← shared PostgreSQL instance; per-service databases + roles
  redis/        ← shared Redis instance; per-service ACL users + key prefixes
```

**`modules/data/postgresql`** — manages:
- The PostgreSQL container (kreuzwerker/docker provider)
- Per-service database creation via the `cyrilgdn/postgresql` provider
- Per-service roles with minimum required privileges (not superuser)
- The superuser credentials go to Vault; service credentials are outputs (sensitive)

Interface:
```hcl
variable "databases" {
  description = "Map of service name → { password } to create as database+owner role pairs."
  type = map(object({ password = string }))
  sensitive = true
}

output "connections" {
  description = "Map of service name → connection details. Sensitive — store in Vault."
  sensitive = true
  # { host, port, database, username, password }
}
```

**`modules/data/redis`** — manages:
- The Redis container (kreuzwerker/docker provider)
- Per-service ACL users with scoped commands and key prefixes (mounted `users.acl` file)
- No service shares another service's key prefix

Interface:
```hcl
variable "acl_users" {
  description = "Map of service name → { password, commands, key_prefix }."
  type = map(object({
    password   = string
    commands   = string  # e.g. "+@all" or "+@read +@write ~authentik:*"
    key_prefix = string  # e.g. "authentik:*"
  }))
  sensitive = true
}

output "connections" {
  description = "Map of service name → { host, port, username, password }. Sensitive."
  sensitive = true
}
```

#### Identity module (Authentik only — no embedded database)

```
modules/identity/
  authentik/    ← Authentik server + worker; accepts external pg + redis connections
```

**`modules/identity/authentik`** — takes PostgreSQL and Redis connection strings as inputs. It does NOT deploy its own database instances. This makes the module reusable: the same module works whether the caller provides an RDS instance, a self-hosted PostgreSQL, or the `modules/data/postgresql` module output.

```hcl
variable "database_url" {
  description = "PostgreSQL connection URL from modules/data/postgresql output."
  sensitive = true
}

variable "redis_url" {
  description = "Redis connection URL from modules/data/redis output."
  sensitive = true
}
```

### Updated deployment topology

```
platform-infrastructure/
  networking/     ← Docker bridge network
  storage/        ← MinIO + state backend
  secrets/        ← Vault
  discovery/      ← Consul
  data/           ← NEW: shared PostgreSQL + Redis (with per-service separation)
  identity/       ← NEW: Authentik (connects to data/)
  integrations/   ← NEW: Vault OIDC + MinIO OIDC + Authentik app declarations
```

**Strict deployment order:**
```
networking → storage → secrets → discovery → data → identity → integrations
```

**Why `data/` comes before `identity/`**: Authentik requires PostgreSQL and Redis to be running and the Authentik database + ACL user to exist before the container starts.

**Why `data/` is separate from `identity/`**: Any future service that needs PostgreSQL (e.g., a task queue, a service registry, a configuration audit log) calls the same `data/` module with an additional entry in `databases` and `acl_users`. No new PostgreSQL instance, no new Redis instance — just a new row in the map.

### Database and cache user management policy

- **PostgreSQL**: the `modules/data/postgresql` module creates a dedicated role and database per service. Each role has `CONNECT`, `USAGE`, and object-level privileges on its own database only — no cross-database access. The superuser credentials are bootstrapped and stored in Vault; application credentials use the per-service roles.

- **Redis**: ACL entries constrain each service to its own key prefix (`authentik:*`, `grafana:*` etc.) and the minimum required command set. The `default` user is disabled. All credentials go to Vault after module output.

### Vault as the single credential store (non-negotiable)

**Every credential — superuser and service-level — is stored in Vault immediately after creation.** No credential is held only in Terraform state, environment variables, config files, or `tfvars`. The only place credentials exist at runtime is inside the running service process, read from Vault via Vault Agent or direct API call.

#### Credential generation and storage flow

```
Terraform random_password resource
        │
        ▼
modules/data/postgresql  ──────────────────────► PostgreSQL container
  (creates DB + role with generated password)           │
        │                                               │  runtime
        │                                               ▼
        ▼                                     Service reads credentials
platform-infrastructure/integrations/         from Vault via Vault Agent
  vault_kv_secret_v2 resources                (never in container env spec)
  (writes all credentials to Vault)
        │
        ▼
Vault KV v2 — single source of truth at runtime
```

#### Vault secret paths

All platform data credentials live under `secret/platform/`:

| Secret path | Contents |
|---|---|
| `secret/platform/postgresql/superuser` | `username`, `password` — PostgreSQL superuser |
| `secret/platform/postgresql/databases/<name>` | `username`, `password`, `database`, `host`, `port` — per-service DB role |
| `secret/platform/redis/admin` | `password` — Redis admin (ACL user with full access) |
| `secret/platform/redis/users/<name>` | `username`, `password`, `key_prefix` — per-service ACL user |
| `secret/platform/authentik/admin` | `username`, `password` — Authentik bootstrap admin |
| `secret/platform/authentik/secret-key` | `value` — Authentik SECRET_KEY (Django signing key) |

#### Terraform implementation in `integrations/`

```hcl
# Generate credentials deterministically (idempotent via keepers)
resource "random_password" "pg_authentik" {
  length  = 32
  special = false
  keepers = { service = "authentik" }
}

# Write to Vault immediately — credentials never live only in state
resource "vault_kv_secret_v2" "pg_authentik" {
  mount = "secret"
  name  = "platform/postgresql/databases/authentik"
  data_json = jsonencode({
    username = "authentik"
    password = random_password.pg_authentik.result
    database = "authentik"
    host     = module.data.postgresql_host
    port     = module.data.postgresql_port
  })
}

# Module receives the password transiently — only uses it for DB role creation
module "data" {
  source    = "git::...//modules/data/postgresql?ref=v1.x.x"
  databases = { authentik = { password = random_password.pg_authentik.result } }
}
```

#### Service runtime access

Services read credentials from Vault at startup via:
- **Vault Agent sidecar** (preferred): injects credentials as environment variables or files before the service process starts — zero credentials in the container spec.
- **Direct Vault API**: for services with native Vault SDK support.

**No credential ever appears in `terraform.tfvars`, Docker `env` blocks, or mounted config files.** The transient exception is during `terraform apply`: the generated password exists in Terraform state (local backend, operator's machine only) for the duration of the apply, then is immediately written to Vault. It is never committed to version control.

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
- **Additional stateful services**: Authentik requires PostgreSQL and Redis. These add to the backup obligation (BAK-001 applies to Authentik's database). Deployed as Docker containers in `platform-infrastructure/identity/` managed by Terraform.
- **Bootstrap dependency**: The platform engineer who runs the initial Authentik setup needs a local admin account before SSO is configured. This is the same bootstrap pattern as Vault initialisation. The Authentik admin bootstrap token is stored in Vault immediately after first deploy.
- **Integration complexity**: `platform-infrastructure/integrations/` adds a fourth Terraform provider (`goauthentik/authentik`) alongside docker, vault, and potentially minio. The `integrations/` component must run after both Vault and Authentik are healthy.

### Migration path for existing services

`platform-infrastructure/integrations/` is a new Terraform component that manages all SSO wiring. Adding SSO to an existing service is a governed PR to this component:

1. Add an `authentik_application` + `authentik_provider_oauth2` resource
2. Add the corresponding service-side resource (e.g., `vault_jwt_auth_backend`, Grafana env vars)
3. Test with a staging deploy
4. PR with Change Record → merge → staging gate passes → production

### Implementation tasks (Phase C identity extension)

| Task ID | Task | Depends on |
|---|---|---|
| PC-0160 | Ratify ADR-0020 | — |
| PC-0161 | Add `modules/identity/postgresql`, `modules/identity/redis`, `modules/identity/authentik` to platform-modules | PC-0160 |
| PC-0162 | Add `identity/` component to platform-infrastructure (deploys Authentik stack) | PC-0161 |
| PC-0163 | Add `integrations/` component to platform-infrastructure (Vault OIDC + MinIO OIDC + Authentik app declarations) | PC-0162 |
| PC-0164 | Migrate Grafana in platform-services to use Authentik OIDC (env vars from integrations output) | PC-0163 |
| PC-0165 | Deploy Authentik forward auth proxy for Consul UI + Prometheus | PC-0163 |
| PC-0166 | Remove all static admin credentials from tfvars (MinIO, Grafana) — replaced by OIDC | PC-0164, PC-0165 |
| PC-0167 | Define ACC-002 control (SSO mandatory for all human-facing services) | PC-0166 |
