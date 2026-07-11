# Platform Infrastructure — Chief Architect Audit
# Date: 2026-07-11
# Scope: platform-compliance, platform-modules, platform-infrastructure, platform-services
# Status: DRAFT — for roadmap planning

---

## Audit Methodology

Evidence gathered from: live Terraform state, module source code, ADR corpus, compliance control
catalog, OPA policies, CI workflow definitions, and container runtime inspection. Findings are
rated by severity: CRITICAL → HIGH → MEDIUM → LOW → OBSERVATION.

---

## Executive Summary

The platform has a sound governance-first foundation (ADR-0001/0003, compliance-before-code) and a
working single-host Docker deployment covering seven core services. The integrations layer (OIDC,
Vault KV, user provisioning) is functionally complete for staging. Twelve substantive gaps were
identified, spanning security hardening, operational resilience, environment promotion, and
architectural completeness. None are blockers for the current staging phase, but all must be
addressed before a production promotion gate is opened.

---

## CRITICAL Findings

### CRIT-001 — Plaintext credentials committed to git (terraform.tfvars in version control)

**File**: `platform-infrastructure/terraform.tfvars` (committed to main branch)

The file contains:
- `minio_root_password = "platform-admin-secret"`
- `pg_superuser_password = "pg-superuser-staging"`
- `pg_authentik_password = "pg-authentik-staging"`
- `redis_admin_password = "redis-admin-staging"`
- `redis_authentik_password = "redis-authentik-staging"`
- `authentik_secret_key = "staging-secret-key-please-change-this-to-50plus-random-chars"`
- `authentik_admin_password = "admin-staging"`
- `authentik_bootstrap_token = "platform-bootstrap-token-staging"`

`terraform.tfvars` is in `.gitignore` but was force-added (`git add -f`) during development and
committed. The SEC-001/SEC-003 CI secret-scan gates will NOT catch this because the patterns used
are common staging values, not regex-matched secret patterns. Anyone with read access to the repo
has all staging credentials.

**Impact**: Full compromise of all staging services via known credentials.

**Remediation**:
1. Rotate all staging credentials immediately.
2. Remove `terraform.tfvars` from git history (`git filter-repo --path terraform.tfvars --invert-paths`).
3. Re-add `terraform.tfvars` to `.gitignore` and remove the `git add -f` pattern from all runbooks.
4. Use `terraform.tfvars.example` with placeholder values only; actual values via CI secrets or
   operator-local files exclusively.
5. Add the specific staged credential patterns to the Semgrep ruleset (SEC-001).

**Controls violated**: SEC-001 (secret scan), IAC-007 (credentials via Vault), ADR-0008.

---

### CRIT-002 — Vault unseal key stored in unencrypted local file with no access control

**File**: `~/.platform/vault-keys.json`

The Vault root token and unseal key are written to a JSON file on the operator's filesystem by
`null_resource.vault_init_unseal`. The file is chmod 600 (correct), but:
- It is a 1-of-1 Shamir split — a single key compromise fully unseals Vault.
- The root token is never revoked; it is used indefinitely by the deploy pipeline.
- There is no key rotation, no break-glass procedure, and no key escrow.
- The file path is hardcoded to the developer's home directory (`/Users/angirasa/`), making it
  non-portable and CI-incompatible.

**Impact**: Whoever has the keys file has permanent, unlimited access to all Vault secrets.

**Remediation**:
1. Increase Shamir shares to at least 3-of-5 for production.
2. Revoke the root token after initial setup; create a named admin token with appropriate TTL.
3. Store unseal keys in a separate secure system (cloud KMS, HSM, or an encrypted secrets store).
4. Implement a documented break-glass procedure.
5. Replace `VAULT_KEYS_PATH` hardcoded path with a CI-injectable environment variable.

**Controls violated**: SEC-008 (Vault key management), ADR-0008.

---

## HIGH Findings

### HIGH-001 — No TLS anywhere in the platform (all inter-service and host traffic is plaintext HTTP)

**Evidence**:
- `vault.hcl.example`: `tls_disable = true`
- `versions.tf`: `skip_tls_verify = true` (Vault provider), `insecure = true` (Authentik provider)
- All service URLs use `http://` (Vault, MinIO, Consul, Authentik, Grafana, Prometheus)
- MinIO OIDC configured with `--insecure` flag
- Internal Docker network traffic between containers is unencrypted

While acceptable for single-host staging on a trusted localhost, this architecture cannot be
promoted to production or multi-host without a TLS layer. The current design has no path to
mTLS, and the provider configuration (skip_tls_verify) will need to change.

**Remediation**:
1. Add a reverse proxy (Nginx/Traefik/Caddy) as a TLS termination layer — add to platform-modules.
2. Generate/inject TLS certificates via a `vault_pki_secret_backend` (Vault PKI engine).
3. Configure internal mTLS for container-to-container using Consul service mesh or Vault Agent.
4. Document an ADR for TLS strategy before multi-host expansion.

**Controls violated**: SEC-006 (transport encryption), RUN-003 (partially), NET-001.

---

### HIGH-002 — No resource limits on any deployed container (RUN-008 not implemented)

**Evidence**: `grep -rn "memory\|cpu_shares" platform-modules/` returns zero results.

RUN-008 control exists (compliance catalog), OPA policy exists (POL-RUN-008), but the actual
Terraform module variables and Docker resource limit attributes are missing from all 9 platform-
modules container resources (Vault, Consul, MinIO, PostgreSQL, Redis, Authentik×2, Prometheus,
Grafana).

A misbehaving container (e.g., Authentik worker OOM, PostgreSQL runaway query, Prometheus
cardinality explosion) will consume all available host memory and bring down the entire platform.

**Remediation**:
1. Add `memory`, `memory_swap`, and `cpu_shares` variables to every docker_container module.
2. Document recommended values based on observed container behaviour.
3. Bump platform-modules to v1.4.0.
4. Platform-infrastructure: pass values via root variables.tf with environment-appropriate defaults.

**Controls violated**: RUN-008 (declared but not implemented).

---

### HIGH-003 — Platform-services observability modules pinned to `ref=main` (mutable ref)

**Evidence**: `platform-services/observability/main.tf`:
```
source = "git::...//modules/observability/prometheus?ref=main"
source = "git::...//modules/observability/grafana?ref=main"
```

Using `ref=main` means every `terraform init -upgrade` or fresh CI run may silently pull a
different module version. This violates the principle of reproducible infrastructure (IAC-003) and
can cause unexpected production changes when main is updated.

**Remediation**:
1. Pin to the current tagged version (v1.3.2 or appropriate tag).
2. Add IAC-003 OPA policy check for `ref=main` patterns.
3. Add `ref=main` to the CI tfsec/Semgrep ruleset.

**Controls violated**: IAC-003 (no hardcoded env-specific values — mutable refs are the converse
of this), SUP-001 (dependency pinning).

---

### HIGH-004 — Vault configured with file storage backend (no HA, no replication)

**Evidence**: `vault.hcl.example`: `storage "file" { path = "/vault/data" }`

File storage is single-node, non-replicated, and cannot be used for Vault HA. Data loss occurs
if the host disk fails. Vault HA requires Consul or Raft integrated storage.

**Remediation**:
1. Migrate to integrated Raft storage (`storage "raft"`) — Consul is already deployed and can
   serve as the storage backend alternatively.
2. Add periodic Vault snapshot to MinIO (S3 sink) via a scheduled job or Vault Snapshot Agent.
3. ADR required: ADR-0021 — Vault Storage and HA strategy.

**Controls violated**: BAK-001 (backup), REL-001/002 (SLO targets unreachable with file backend).

---

### HIGH-005 — Consul ACLs disabled (bootstrapped with default-allow policy)

**Evidence**: `consul.hcl.example`:
```hcl
# Uncomment to enable ACLs (recommended for production)
# acl { enabled = true; default_policy = "deny" ... }
```

Consul ACLs are commented out. Any process on the Docker network can read/write the entire Consul
KV store and modify service registrations without authentication. This is acceptable for single-
host staging but is a complete access control failure for any networked environment.

**Remediation**:
1. Enable Consul ACLs with `default_policy = "deny"`.
2. Bootstrap an ACL master token; store it in Vault at `secret/platform/consul/master-token`.
3. Create service-specific tokens (read-only for services, write for platform-infrastructure).
4. Add ACC control: ACC-002 (Consul ACL enforcement).

**Controls violated**: ACC-001 (access control baseline).

---

### HIGH-006 — Grafana not integrated with Authentik (local admin password, no SSO)

**Evidence**: Grafana module has no `GF_AUTH_GENERIC_OAUTH_*` environment variables. The
`grafana_admin_password` is passed directly. Grafana is also not in `integrations/authentik-identity.tf`
as an OIDC application.

Grafana represents a significant operational surface (dashboards, alert rules, data source
credentials) with no federated identity, no RBAC from Authentik groups, and no audit trail.

**Remediation**:
1. Add `module "oidc_grafana"` to `integrations/authentik-identity.tf` using the `oidc-application`
   module.
2. Add Grafana OIDC env vars to the Grafana module in platform-modules:
   - `GF_AUTH_GENERIC_OAUTH_ENABLED=true`
   - `GF_AUTH_GENERIC_OAUTH_CLIENT_ID`, `_CLIENT_SECRET`
   - `GF_AUTH_GENERIC_OAUTH_SCOPES=openid email profile`
   - `GF_AUTH_GENERIC_OAUTH_AUTH_URL`, `_TOKEN_URL`, `_API_URL`
3. Map Authentik platform-admins group to Grafana Admin role.

**Controls violated**: RUN-009 (all services must use Authentik as IDP — Grafana excluded).

---

### HIGH-007 — No Vault audit device configured (zero audit trail for secret access)

**Evidence**: `grep -rn "vault_audit" platform-infrastructure/integrations/` returns empty.

Vault ships with all audit devices disabled by default. Without an audit device, there is no
record of which service accessed which secret, when tokens were used, or if a credential was
exfiltrated. This is a fundamental security compliance gap.

**Remediation**:
1. Add `vault_audit` resource to `integrations/vault-oidc-auth.tf` (or a new `vault-audit.tf`):
```hcl
resource "vault_audit" "file" {
  type = "file"
  path = "file/"
  options = { file_path = "/vault/logs/audit.log" }
}
```
2. Mount a host-path volume for the audit log directory in the Vault container.
3. Add log rotation and forwarding to a SIEM or Prometheus Loki.

**Controls violated**: AUD (audit domain — no AUD control addresses Vault audit specifically;
this is itself a gap — AUD-002 needed).

---

## MEDIUM Findings

### MED-001 — Vault root token used as the long-lived service identity

The deploy pipeline exports `VAULT_TOKEN` (the root token) and uses it for all Terraform Vault
provider operations. Root tokens:
- Cannot be revoked by TTL.
- Bypass all Vault policies.
- Are not distinguishable from each other in audit logs.

**Remediation**:
1. After Vault initialisation, create a named AppRole for Terraform with only the permissions
   needed to manage `secret/platform/*`, `auth/`, and `sys/policies/`.
2. Store the AppRole credentials in a CI secret, not in a file on the operator's host.
3. Reserve the root token for break-glass use only.

---

### MED-002 — PostgreSQL and Redis bound to host port 0.0.0.0 (publicly accessible on host)

**Evidence**: `postgresql/main.tf`: `external = var.port` (defaults to 5432, bound to 0.0.0.0).
Similarly Redis is bound to 0.0.0.0:6379.

For a single-host developer machine this is a minor risk, but for any networked host (cloud VM,
shared server) these ports become publicly accessible. Database services should never be exposed
on the host interface — they only need to be accessible within the Docker network.

**Remediation**:
1. Bind internal-only services to `127.0.0.1` instead of `0.0.0.0`:
```hcl
ports {
  internal = 5432
  external = var.port
  ip       = "127.0.0.1"   # add this
}
```
2. Better: remove host port binding entirely for PostgreSQL and Redis — they are only needed by
   containers on the Docker network. The postgresql Terraform provider connects via localhost
   during the same apply; add a health check instead to avoid the race.
3. Update locals.tf port_assignments to mark these as internal-only (already partially done with
   comments but not enforced).

---

### MED-003 — No Consul service mesh / health-check integration

Consul is deployed but used only as a single-node KV store in dev mode. None of the platform
services register themselves with Consul's service catalog. This means:
- Consul UI shows no services.
- Service discovery is unused; all communication uses hardcoded Docker network hostnames.
- Consul health checks are not wired into any SLO measurement.

**Remediation**:
1. Register each platform service with Consul at deploy time (Consul registration block in each
   Docker container or via Consul API from integrations/).
2. Use Consul service names for inter-service communication (resilience to container rename).
3. Wire Consul health checks into the platform SLO dashboards.

---

### MED-004 — Platform-services backend.hcl not initialised (state bucket may not exist)

**Evidence**: `backend.hcl.example` exists but `backend.hcl` is in `.gitignore` and not generated
by `deploy.sh`. The MinIO bucket `platform-terraform-state` is also not provisioned by
platform-infrastructure.

Platform-services cannot be applied until: (a) the MinIO bucket is created, (b) `backend.hcl` is
populated with credentials, (c) `terraform init -backend-config=backend.hcl` is run. None of
these steps are automated.

**Remediation**:
1. Add `minio_bucket` resource to `platform-infrastructure/storage/` creating
   `platform-terraform-state` on first apply.
2. Add a `deploy-services.sh` (or extend `deploy.sh`) that generates `backend.hcl` from Vault KV
   and initialises the platform-services backend automatically.
3. Write `secret/platform/terraform-state/services` to Vault with MinIO credentials.

---

### MED-005 — `deploy.sh --destroy` deletes Docker volumes without data backup

**Evidence**: `deploy.sh --destroy`:
```bash
docker volume ls | grep "^platform-" | xargs -r docker volume rm
```

This permanently deletes PostgreSQL data, Vault KV data, Redis state, MinIO objects, Prometheus
TSDB, and Grafana dashboards with no confirmation prompt, no backup step, and no "dry-run" option.

**Remediation**:
1. Add `--no-volumes` flag to skip volume deletion (useful for container-only resets).
2. Add a backup step before volume removal: snapshot MinIO, PostgreSQL pg_dump, Vault snapshot.
3. Require explicit confirmation: `read -p "Destroy ALL data? Type YES to confirm: "`.

---

### MED-006 — Authentik bootstrap_token is a static hardcoded string

**Evidence**: `terraform.tfvars`: `authentik_bootstrap_token = "platform-bootstrap-token-staging"`

The bootstrap token is a predictable, static string committed to git (see CRIT-001). Authentik
bootstrap tokens are created on first startup — if the value is known, anyone can authenticate
to the Authentik API as a super-admin.

**Remediation**:
1. Generate a cryptographically random 32-character token: `openssl rand -hex 32`.
2. Inject it as a CI/CD secret or via operator-local `terraform.tfvars` (never committed).
3. After initial setup, rotate to a named API token with minimum permissions using the Authentik
   admin API or Terraform.

---

### MED-007 — No secrets rotation strategy or TTL enforcement

No service credential has a defined rotation schedule, expiry, or TTL. PostgreSQL passwords,
Redis passwords, MinIO credentials, and the Authentik secret key are static since deployment.
Vault stores them but does not rotate them. There is no `vault_policy` that enforces credential
TTL on service tokens.

**Remediation**:
1. Implement Vault Dynamic Secrets for PostgreSQL using `vault_database_secret_backend_*` resources.
2. Set token TTL on all Vault service tokens (max 30 days, renewable).
3. Add a rotation runbook and schedule to the platform operational model.
4. Add SEC control: SEC-012 (credential rotation policy).

---

## LOW Findings

### LOW-001 — Missing ADR-0013 (gap in ADR numbering)

The ADR series jumps from ADR-0012 to ADR-0014. ADR-0013 is either missing or was abandoned.
This creates confusion when cross-referencing decisions.

**Remediation**: Either create ADR-0013 retroactively for a past decision, or add a tombstone
ADR-0013 acknowledging the gap.

---

### LOW-002 — Compute module (ec2-instance) exists in platform-modules but is unintegrated

`platform-modules/modules/compute/ec2-instance/` exists but is not referenced by any
platform-infrastructure component, has no corresponding ADR, and no deployment path.

**Remediation**:
1. Determine if ec2-instance is intended for the production target (likely yes).
2. Create ADR-0022: Multi-host Production Deployment Strategy (Docker Swarm, cloud VMs, K8s?).
3. Either integrate the module or remove it from platform-modules to reduce confusion.

---

### LOW-003 — Grafana and Prometheus not connected to platform credentials in Vault

Grafana's admin password and Prometheus have no Vault KV entries. The `integrations/vault-credentials.tf`
writes PostgreSQL, Redis, and Authentik credentials, but not observability stack credentials.

**Remediation**:
1. Add `vault_kv_secret_v2.grafana_admin` and `vault_kv_secret_v2.prometheus_config` to
   `integrations/vault-credentials.tf`.

---

### LOW-004 — `locals.tf` port registry is a comment, not enforced at runtime

The `locals.tf` port map uses port number as key to catch duplicates at parse time. However,
the module calls use `var.X_port` variables — if a new module is added without updating locals.tf,
there is no enforcement. The registry is advisory.

**Remediation**:
1. Add an OPA policy or tfsec custom rule that validates every `external =` port binding against
   `local.port_assignments`.
2. Or: make the module calls use `local.port_assignments` values directly as the source of truth.

---

### LOW-005 — No platform health dashboard or runbook

The platform has 7+ services with health checks and metrics. There is no:
- Consolidated health-check script or endpoint.
- `STATUS.md` or operator runbook for "platform is healthy" definition.
- Grafana dashboard for platform-infrastructure services themselves (only user-services are in
  platform-services; infrastructure services are unmonitored by Prometheus).

**Remediation**:
1. Move Prometheus and Grafana to platform-infrastructure (monitoring the platform is infrastructure).
2. Create a platform-health Grafana dashboard covering all 7 core services.
3. Add a `./deploy.sh --status` command that queries all service health endpoints.

---

### LOW-006 — Vault `cluster_port` (8201) is exposed on the host but Vault is single-node

`vault/main.tf` exposes port 8201 (cluster port) on the host. This port is only used for Vault
HA cluster communication. With file storage (single-node), this port is never used and should
not be exposed.

**Remediation**: Remove cluster_port host binding for non-HA deployments. Add a `ha_enabled`
variable to the vault module; only bind cluster_port when true.

---

## Observations (No Action Required Now)

### OBS-001 — Module versioning cadence is patch-heavy, suggesting missing abstraction boundaries

The platform-modules repo has been tagged 10 times (v1.0.0 through v1.3.2) in a single session,
with most patches addressing operational issues found during first deployment rather than feature
additions. This suggests the modules were under-specified before deployment — the "compliance first,
implementation second" principle (ADR-0001/0003) was not uniformly applied to the module API design.

### OBS-002 — Platform-services is disconnected from platform-infrastructure outputs

`platform-services/variables.tf` declares `platform_network_name` with a hardcoded default
`"platform-backend"`. This string must match what platform-infrastructure creates, but there is
no Terraform data source or remote state reference connecting the two. If the network name changes
in platform-infrastructure, platform-services silently breaks.

**Recommended**: Use `terraform_remote_state` data source from platform-services pointing at
platform-infrastructure's MinIO backend to read `network_id` directly.

### OBS-003 — No multi-environment path defined (staging only)

All configurations are for a single "staging" environment. ADR-0012 references multi-environment
gates but no `environments/production/` or environment-specific tfvars structure exists. When the
time comes for production, there is no clear promotion path.

### OBS-004 — `terraform.tfstate.staging` and `versions.tf.bak` are tracked in git

These files appear in `git ls-files` despite `.gitignore` entries. The state files contain
sensitive resource IDs and were added via force-add. Historical state files should be removed.

### OBS-005 — deploy.sh is macOS-specific (Docker Desktop socket path hardcoded)

`deploy.sh` exports `DOCKER_HOST="unix://$HOME/.docker/run/docker.sock"` and
`PATH="/Applications/Docker.app/..."` — both are macOS Docker Desktop paths. Running on Linux
(CI or production) will fail.

**Recommended**: Auto-detect platform or use a `DOCKER_HOST` env var override pattern.

---

## Gap Map by Domain

| Domain | Controls Defined | Policies Active | Implementation | Gap |
|--------|-----------------|----------------|----------------|-----|
| SEC    | 11 controls      | Semgrep, tfsec | Partial        | No TLS, no audit device, creds in git |
| IAC    | 7 controls       | validate, fmt, tfsec | Strong   | ref=main in services |
| RUN    | 9 controls       | Docker checks  | Partial        | No resource limits, Grafana no OIDC |
| ACC    | 1 control        | Branch protection | Minimal     | No Consul ACL, no Vault AppRole |
| AUD    | Unknown          | None           | None           | No Vault audit, no log aggregation |
| BAK    | 1 control        | None           | None           | No backups anywhere |
| NET    | 1 control        | None           | Minimal        | All HTTP, DBs exposed on 0.0.0.0 |
| REL    | 2 controls       | SLO defined    | Monitoring only| No HA, no redundancy |
| OBS    | Unknown          | Prometheus/Grafana deployed | Partial | Infra not self-monitored |

---

## Recommended Roadmap Priority Order

**P0 — Immediate (before sharing the repo or deploying to any networked host)**
1. CRIT-001: Rotate and remove credentials from git history
2. CRIT-002: Vault unseal key management
3. HIGH-007: Enable Vault audit device

**P1 — Before first production deployment**
4. HIGH-001: TLS everywhere (reverse proxy + Vault PKI)
5. HIGH-002: Container resource limits (platform-modules v1.4.0)
6. HIGH-004: Vault HA (Raft integrated storage)
7. HIGH-005: Consul ACLs
8. HIGH-006: Grafana → Authentik SSO
9. MED-001: Replace root token with AppRole

**P2 — Before production readiness sign-off**
10. MED-002: Bind DBs to 127.0.0.1 or remove host port
11. MED-004: Automate platform-services backend initialisation
12. MED-005: Safe destroy with backup pre-step
13. MED-007: Credential rotation strategy
14. HIGH-003: Pin observability refs to a version tag

**P3 — Operational excellence**
15. MED-003: Consul service mesh integration
16. LOW-005: Platform health dashboard
17. LOW-002: Compute module integration or removal
18. OBS-002: Remote state reference between infra and services
19. OBS-003: Define multi-environment promotion path
