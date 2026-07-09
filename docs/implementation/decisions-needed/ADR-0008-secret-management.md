# ADR-0008 Proposal — Secret Management Backend

**Priority:** 🟠 HIGH  
**Blocks:** Phase C (`platform-services` cannot deploy without this)  
**Decision needed by:** Before the first service with runtime secrets is deployed

---

## The decision

Which backend stores and distributes runtime secrets for platform services?

---

## Why this is blocking

SEC-001 prohibits plaintext secrets in any repository. `platform-infrastructure` and `platform-services` will need to inject secrets (database passwords, API tokens, TLS private keys) into running services. Without a decided backend, the first service deployment has no compliant path for secret injection.

The compliance binding for SEC-001 says: "All secrets must be stored in the designated secrets management backend (to be defined in an ADR before any service is deployed)." This ADR fulfills that contract.

---

## Options

### Option A — SOPS + age (encrypted files in git)

Secrets are encrypted with `age` or `gpg`, committed to git as `*.sops.yaml`, and decrypted at deploy time by CI or the Terraform provider.

**Pros:** No additional service to operate. Works with Terraform (sops provider). Secrets are version-controlled. Self-hosted.

**Cons:** Key rotation is complex. Secrets are visible (encrypted) in git history — a repository leak exposes the encrypted form. Not suitable for very high-sensitivity secrets without additional protection.

**Best for:** Small team, low-sensitivity secrets, simple operations model.

### Option B — HashiCorp Vault (self-hosted)

A Vault cluster is deployed as a platform service. Terraform uses the Vault provider. Services authenticate via AppRole or GitHub OIDC.

**Pros:** Industry standard. Fine-grained access control. Dynamic secrets (DB credentials that expire). Audit log built in.

**Cons:** Vault itself must be secured, backed up, and highly available. Before the platform has any HA infrastructure, deploying Vault creates a bootstrapping dependency. Operational overhead is significant for a small team.

**Best for:** Large platforms with operational maturity and multiple teams.

### Option C — Age-encrypted secrets + Terraform `sensitive` values

Secrets are stored as age-encrypted files in `platform-infrastructure`. Terraform reads them at apply time and passes them as `sensitive` outputs to services. No additional infrastructure.

**Pros:** Simpler than Vault for small scale. Terraform native. No additional service.

**Cons:** Less flexible than Vault. Key management is still manual.

### Option D — GitHub Actions encrypted secrets + OIDC

Secrets are stored in GitHub Actions repository secrets or organisation secrets. Services are deployed from CI using OIDC-issued short-lived credentials. No secrets are stored in infrastructure repos.

**Pros:** Zero additional infrastructure. GitHub-native. OIDC eliminates long-lived credentials.

**Cons:** Couples infrastructure to GitHub availability. All secrets depend on GitHub. Doesn't help with runtime secret injection into deployed services (only CI-time injection).

---

## Recommendation

**Phase A/B:** Option D (GitHub OIDC for CI credentials) + Option A (SOPS for configuration secrets)  
This covers the bootstrap phase without requiring a Vault deployment.

**Phase C/D:** Option B (Vault) once the platform has enough operational maturity to run a stateful HA service. Vault would be the first use of BAK-001 (backup policy required for stateful services).

The two-phase approach keeps things simple now and provides a migration path to the proper solution.

---

## What to decide
1. Confirm the two-phase approach or choose a single option
2. If SOPS: which encryption backend? (age keys vs PGP vs AWS KMS equivalent)
3. If OIDC for CI: confirm that the first service repos will use GitHub OIDC exclusively for CI-time credentials
4. Define the timeline for introducing Vault (Phase C milestone or Phase D)
