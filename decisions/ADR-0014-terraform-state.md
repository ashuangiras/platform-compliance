# ADR-0014: Terraform State Backend — S3-Compatible Object Storage

| Field | Value |
|---|---|
| **ID** | ADR-0014 |
| **Status** | accepted |
| **Date** | 2026-07-10 |
| **Deciders** | platform-team |

---

## Context

`platform-infrastructure` manages real infrastructure via Terraform root configurations.
Terraform state must be stored remotely so that:

1. CI and multiple operators can share state without conflict.
2. State is not lost if a local machine is destroyed.
3. Concurrent applies are prevented (state locking).

The choice of state backend determines where sensitive state data lives, who can access it,
and what backup strategy applies (BAK-001 scope).

---

## Decision

### Backend: S3-compatible object storage

Terraform state is stored in an **S3-compatible backend** — initially a cloud provider S3
bucket (AWS free tier or equivalent), migrating to self-hosted MinIO once
`platform-infrastructure` is running MinIO.

```hcl
terraform {
  backend "s3" {
    bucket = "platform-terraform-state"
    key    = "<environment>/<module>/terraform.tfstate"
    region = "<region>"
    # DynamoDB table for locking (cloud) or MinIO object locking (self-hosted)
    dynamodb_table = "platform-terraform-locks"
    encrypt        = true
  }
}
```

### State locking

- **Cloud (bootstrap):** DynamoDB table provides atomic locking.
- **Self-hosted MinIO:** MinIO object locking (WORM mode) replaces DynamoDB once the
  platform is self-hosted.

### Access control

| Actor | Permitted operation |
|---|---|
| GitHub Actions CI | Write (via short-lived OIDC credentials or static service account) |
| Platform operators | Read-only (break-glass write requires a waiver) |
| Services | No access |

State files contain sensitive values (IP addresses, generated passwords, resource IDs).
Access is restricted to the CI service account and platform-team operators.

### Backup obligation

The S3 bucket (or MinIO bucket) that stores state files is a stateful data store subject to
**BAK-001**. Versioning MUST be enabled on the bucket so previous state versions are
recoverable. A backup policy entry is required on `platform-infrastructure`.

### Bootstrap path

1. Create a minimal S3 bucket on a cloud provider free tier.
2. Enable bucket versioning and server-side encryption.
3. Create a DynamoDB table for locking.
4. Configure the Terraform backend in `platform-infrastructure`.
5. Once `platform-infrastructure` runs MinIO, migrate state bucket to self-hosted MinIO
   and replace DynamoDB locking with MinIO object locking.

---

## Consequences

- A cloud S3 bucket and DynamoDB table are created manually before any Terraform apply.
  These are the only resources created outside of Terraform (they cannot bootstrap
  themselves).
- `platform-infrastructure` must document the bootstrap instructions in its README before
  the first `terraform apply`.
- BAK-001 binding for the state backend is required on `platform-infrastructure`. The
  binding uses the `terraform` context.
- Sensitive state must never be committed to git. `.gitignore` in `platform-infrastructure`
  must exclude `*.tfstate` and `*.tfstate.backup`.
- The migration from cloud S3 to self-hosted MinIO is a future work item tracked in
  `platform-infrastructure`; no ADR amendment is required — the backend interface is
  S3-compatible in both cases.
- State access credentials (CI service account key or OIDC role ARN) are stored in Vault
  per ADR-0008.
