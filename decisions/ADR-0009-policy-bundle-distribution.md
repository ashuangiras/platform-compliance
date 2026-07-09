# ADR-0009: OPA policy bundle distributed as GitHub release artifact with SHA-256 verification

| Field | Value |
|---|---|
| **ID** | ADR-0009 |
| **Status** | accepted |
| **Date** | 2026-07-09 |
| **Deciders** | platform-team |

---

## Context

The reusable compliance workflow needs to fetch the OPA policy bundle from `platform-compliance` at a specific, pinned version. Three options were evaluated (see the proposal in `docs/implementation/decisions-needed/ADR-0009-policy-bundle.md`):

- **Option A** — GitHub release artifact (`policies.tar.gz` attached to each release, verified with SHA-256)
- **Option B** — OCI image on GHCR (OPA-native, requires container infrastructure)
- **Option C** — Direct archive download from a tagged/branch ref (current approach)

Option C (current approach) was evaluated as a bootstrap measure. It fetches the full repository archive and copies out the `07-policies/opa/` subtree. While functional, it is not version-pinned to a packaged artifact, has no integrity verification, and fetches more data than needed.

Option B was deferred: OCI distribution offers the strongest integrity guarantees (cosign signing, OPA-native `opa run --bundle`) but requires GHCR write permissions and OCI infrastructure that is not yet available.

---

## Decision

**Adopt Option A: publish `policies.tar.gz` as a GitHub release asset at each version tag.**

### Bundle contents

The bundle is a tar.gz archive of `07-policies/opa/`, preserving directory structure:
```
policies.tar.gz
  SRC/POL-SRC-001-GITHUB-001.rego
  SRC/POL-SRC-002-GITHUB-001.rego
  SEC/...
  ...
```

### Integrity verification

A SHA-256 checksum file (`policies.tar.gz.sha256`) is published alongside the bundle. Consumers verify before extraction:
```bash
sha256sum --check policies.tar.gz.sha256
```

No cosign signing for v1.x. Cosign will be evaluated when SLSA L2+ provenance is implemented (Phase D).

### Fetch strategy in the reusable workflow

The workflow tries release assets first (for tag refs), then falls back to the branch archive (for `main` or branch refs):

```bash
REF="${PLATFORM_COMPLIANCE_REF}"
OWNER="${GITHUB_REPOSITORY_OWNER}"

# Try release asset (tag refs)
RELEASE_URL="https://github.com/${OWNER}/platform-compliance/releases/download/${REF}/policies.tar.gz"
if curl -sSfL "${RELEASE_URL}" -o /tmp/policies.tar.gz 2>/dev/null; then
  # Verify SHA-256
  curl -sSfL "${RELEASE_URL}.sha256" -o /tmp/policies.tar.gz.sha256 2>/dev/null
  sha256sum --check /tmp/policies.tar.gz.sha256
  echo "Verified release bundle: ${REF}"
else
  # Fall back to branch archive
  curl -sSfL "https://github.com/${OWNER}/platform-compliance/archive/refs/heads/${REF}.tar.gz" -o /tmp/bundle.tar.gz
  tar -xz -f /tmp/bundle.tar.gz -C /tmp/pc-extract
  cp -r /tmp/pc-extract/*/07-policies/opa/. /tmp/platform-compliance-policies/
fi
```

### Bundle update cadence

Bundles are published **on release only** (when a version tag is pushed). The `main` branch is used by `self-compliance.yml` (the platform's own CI) via the branch archive fallback. Consuming downstream repositories **must pin to a tag**, not `main`.

### Migration path to OCI (Phase C/D)

When container infrastructure is available, the bundle will be published as an OCI image to GHCR alongside the tar.gz artifact. The fetch URL changes; the OPA invocation is identical. Consuming repos update their `platform-compliance-ref` pin — no other changes required.

---

## Consequences

- The `release.yml` workflow (PC-0118) must package and upload the bundle on every tag push.
- The `reusable-compliance.yml` workflow must be updated to use the release artifact when available.
- The `self-compliance.yml` workflow continues to reference `"main"` (uses branch archive fallback).
- Consuming repositories pin to a tag (e.g., `v1.1.0`), not a branch.
- SHA-256 checksums prevent bundle tampering in transit (man-in-the-middle protection).
