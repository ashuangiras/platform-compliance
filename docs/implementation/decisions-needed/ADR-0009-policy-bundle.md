# ADR-0009 Proposal — OPA Policy Bundle Distribution

**Priority:** 🟠 HIGH  
**Blocks:** Phase A (stable policy fetching in workflow), Phase B (pinned bundle in downstream repos)  

---

## The decision

How do consuming repositories access the OPA policy bundle at a pinned version?

---

## Current state (fragile)

The reusable workflow currently has a TODO for fetching policies:
```
# TODO [Phase 10]: Download 07-policies/ bundle from platform-compliance@v1.0.0
```

The placeholder suggests `curl` against the raw GitHub API, which has three problems:
1. GitHub API rate limits under load
2. A branch push could change `07-policies/` even with a version tag if the tag resolves to a non-bundle artifact
3. OPA bundle format is the standard for distributing and verifying policy packages — we should use it

---

## Options

### Option A — OPA bundle published as GitHub release artifact

At each `platform-compliance` release, a GitHub Actions workflow packages `07-policies/opa/` as an OPA bundle tarball (`policies-{version}.tar.gz`), signs it with cosign or a SHA-256 checksum, and uploads it as a release asset.

Consuming repos download the bundle at their pinned version:
```bash
curl -sSfL "https://github.com/ashuangiras/platform-compliance/releases/download/v1.1.0/policies.tar.gz" \
  -o /tmp/policies.tar.gz
sha256sum --check /tmp/policies.tar.gz.sha256  # verify integrity
tar -xz -C /tmp/policy-bundle /tmp/policies.tar.gz
```

**Pros:** Version-pinned. Content-addressable via checksum. Standard OPA bundle format. Works offline once cached.

**Cons:** Requires bundle publishing step in release workflow (straightforward, but adds a release step).

### Option B — OCI artifact (policy bundle as container image layer)

Package the OPA bundle as an OCI artifact and push to GHCR (GitHub Container Registry) alongside each release. OPA 0.44+ supports pulling bundles from OCI registries natively.

```bash
opa run --bundle ghcr.io/ashuangiras/platform-compliance-policies:v1.1.0
```

**Pros:** OPA-native. Standard OCI distribution. Image signing (cosign) provides strong integrity guarantees.

**Cons:** Requires GHCR write permissions in CI. Adds an OCI registry dependency. Slightly more complex setup.

### Option C — Direct checkout of tagged ref

The reusable workflow checks out `platform-compliance` at the pinned tag and uses the policies directly:
```yaml
- uses: actions/checkout@v4
  with:
    repository: ashuangiras/platform-compliance
    ref: v1.1.0
    path: /tmp/platform-compliance
```

**Pros:** Simplest implementation. No bundle packaging step.

**Cons:** Fetches the entire repository (heavy). No bundle format benefits (data discovery, bundle metadata). Doesn't scale for large policy sets.

---

## Recommendation

**Option A (GitHub release artifact)** for v1.1.0 and v1.2.0.  
**Option B (OCI artifact)** when container infrastructure is available (Phase C or D).

The migration is transparent: the URL to fetch the bundle changes, the OPA invocation is identical.

---

## What to decide
1. Option A or B for initial implementation
2. Bundle signing: SHA-256 checksum only (simple) or cosign (stronger but requires keys)?
3. Bundle update cadence: release-only, or also on-commit to `07-policies/` on `main`?
