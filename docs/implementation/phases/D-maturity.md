# Phase D — Advanced Maturity

**Status:** ⬜ Not started  
**Horizon:** v3.0.0+  
**Hard blockers:** Phase C substantially complete, ADR-0013, ADR-0015

## Goal

The platform operates with continuous, automated, audit-ready compliance. Compliance state is visible in real time. Supply chain security reaches SLSA L2. Reliability is tracked against declared SLOs. The self-hosted Git mirror operates under the same governance as GitHub.

## Deliverables

### D.1 — Compliance dashboard (depends on ADR-0013)

A queryable, human-readable view of compliance state across all governed repositories:

**Minimum viable:** A GitHub Actions scheduled job that reads evidence files, computes per-repository compliance scores, and publishes a generated report to GitHub Pages or a dedicated `compliance-reports` branch.

**Full:** Grafana dashboard backed by a time-series database fed by continuous audit evidence. Controls tracked over time. Trend lines for waiver counts, failing controls, SLA breaches.

### D.2 — SLSA Build L2 provenance (depends on ADR-0017)

Current supply chain controls reach approximately SLSA L1 (provenance exists). L2 adds:
- Builds performed in a hosted, isolated environment (GitHub Actions satisfies this)
- Provenance is non-falsifiable: the build platform attests to the source, deps, and artifacts
- Artifact digests recorded in the provenance attestation

Implementation: Use `slsa-framework/slsa-github-generator` GitHub Actions to generate L2 provenance attestations for all published artifacts. Update SUP-001/SUP-002 controls or add SUP-004/SUP-005.

### D.3 — SLO tracking and REL domain activation

The REL domain controls (REL-001, REL-002) declared in Phase C become meaningful only when there's infrastructure to measure them:
- Deploy a time-series database (Prometheus or VictoriaMetrics) to collect metrics
- Define SLI definitions per service type
- Build dashboards per service showing error budget burn rate
- Activate REL domain policies in the deployment gate

### D.4 — Self-hosted Git mirror (depends on ADR-0015)

When introduced, the Git mirror (Gitea/Forgejo) must itself be a governed service:
- Deploy under `platform-services` with a full service contract
- New technology context: `gitea` or `forgejo` (registered in `02-taxonomy/technology-contexts.yaml`)
- Bindings for SRC-001 and SRC-002 in the gitea context (branch protection equivalents)
- OPA policies for the gitea API
- Mirror sync is verified by evidence: last successful sync time in continuous audit

ADR-0002 defined GitHub as the root of trust. ADR-0015 will define the conditions under which the mirror transitions from mirror to co-equal or primary — if ever.

### D.5 — Automated waiver expiry enforcement

Currently waivers expire based on the `expiry_date` field, but nothing enforces this automatically. Phase D adds:
- Continuous audit policy that detects waivers with `expiry_date` within 30 days
- Automated PR created to the waiver owner requesting renewal or closure
- Deployment gate blocks if an expired waiver is still listed in `.compliance-manifest.yaml`
- Dashboard shows waiver expiry timeline

### D.6 — SRC-004 signed commits rollout (depends on ADR-0016)

SRC-004 is deferred pending a key management decision. Phase D activates it:
- Decision: GPG keys, SSH keys, or a signing-as-a-service approach
- Key provisioning guide and grace period
- Signed commit policy activated in PROF-PLATFORM-V2 or v3
- Historical commits exempt; policy applies from activation date

## Task IDs: PC-0186+
See [`tasks/v3-platform.yaml`](../tasks/v3-platform.yaml)

## Acceptance criteria
- Compliance state for all governed repositories is visible without looking at individual files
- SLSA L2 attestations exist for all published artifacts from `platform-compliance`
- At least one service has SLO declarations and error budget tracking
- Waiver expiry is enforced automatically — no expired waivers silently remain active
- Self-hosted Git mirror (when deployed) passes its own compliance gate
