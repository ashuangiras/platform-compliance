# ADR-0014 Proposal — Terraform State Backend Selection

**Priority:** 🟢 LOW  
**Blocks:** Phase C (`platform-infrastructure` repo creation)

---

## The decision

Where does Terraform state live for `platform-infrastructure`?

---

## Requirements

- Locking to prevent concurrent applies
- Access control (only CI can write; humans can read)
- Encryption at rest
- Backup (covered by BAK-001)
- Self-hosted preference (but pragmatic over dogmatic)

---

## Options

### Option A — Terraform Cloud (free tier)

Managed state backend, free for small teams and open source.

**Pros:** Zero infrastructure. Locking built in. State encryption by default. Remote execution available if needed.

**Cons:** External SaaS dependency. State contains sensitive infrastructure data (IP addresses, resource IDs). Free tier has run limits.

### Option B — S3-compatible storage (MinIO or cloud S3)

State in an S3 bucket with DynamoDB (or MinIO + a lock file) for locking.

**Pros:** Self-hosted with MinIO. Standard Terraform backend. Encryption via server-side encryption.

**Cons:** MinIO itself must be deployed before Terraform state can be stored — bootstrapping problem. If using cloud S3, that's an external cloud dependency.

**For self-hosted MinIO:** This creates a circular dependency — the platform infrastructure manages MinIO, but MinIO manages the platform state. Needs a careful bootstrap sequence (local state for the MinIO deployment, then migrate to MinIO backend).

### Option C — Git-based state (terragrunt or terraform-git-backend)

State stored encrypted in a git repository. Simpler than S3 for small teams.

**Pros:** No additional service. Git provides versioning and access control.

**Cons:** Not officially supported by Terraform. Locking is hard. State files grow large. Not recommended for production.

### Option D — Local state + git-crypt (simplest bootstrap)

Start with local state in the git repository, encrypted with `git-crypt`. Migrate to a proper backend once the platform has infrastructure to host it.

**Pros:** Zero infrastructure needed initially. Works immediately.

**Cons:** Not suitable for multiple contributors or automation. Must migrate early.

---

## Recommendation

**Start with Option A (Terraform Cloud free tier)** for the bootstrap phase. It provides immediate, zero-infrastructure state storage with all required properties.

**Migrate to Option B (self-hosted MinIO)** once `platform-infrastructure` is mature enough to run its own stateful services and BAK-001 can be properly satisfied for the MinIO deployment.

The Terraform configuration should use `remote` backend configuration to make migration between backends a one-line change.

---

## What to decide
1. Accept the two-phase approach (Terraform Cloud → MinIO)?
2. If Option A: create a Terraform Cloud organisation before `platform-infrastructure` is created
3. Confirm: state encryption requirement — Terraform Cloud encrypts by default; document this satisfies the encryption requirement for CHG-002/BAK-001 purposes
