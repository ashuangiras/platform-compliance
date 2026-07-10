# ADR-0012: Multi-Environment Compliance Gates — Staging vs Production Profiles

| Field | Value |
|---|---|
| **ID** | ADR-0012 |
| **Status** | accepted |
| **Date** | 2026-07-10 |
| **Deciders** | platform-team |

---

## Context

`PROF-SERVICE-V1` defines a single enforcement posture for all service deployments. In
practice, a staging environment must allow a service to deploy before it achieves full
runtime compliance (e.g., backup policy is meaningless for a staging DB replica; a health
check endpoint may not be wired up until integration testing). Blocking a staging deployment
on operational controls that only matter in production creates unnecessary friction without
improving safety.

Conversely, production must never relax any control: every control that is advisory in
staging must be blocking in production. A single shared profile cannot express both
requirements cleanly.

---

## Decision

Two environment-specific profiles are defined as children of `PROF-SERVICE-V1`:

### `PROF-SERVICE-STAGING-V1`

Inherits `PROF-SERVICE-V1`. Purpose: pre-production deployments.

| Control | Inherited enforcement | Staging override |
|---|---|---|
| `BAK-001` | block (scope-conditioned) | `warn` — backup policy advisory in staging |
| `NET-001` | warn (scope-conditioned) | `warn` — no change; explicit override for clarity |
| `OBS-001` | warn | `warn` — health check advisory in staging |

All QUA, TST, and SEC controls remain at inherited enforcement — no override. Staging must
still pass security and code quality gates; only runtime operational controls are relaxed.

### `PROF-SERVICE-PROD-V1`

Inherits `PROF-SERVICE-V1`. Purpose: production deployments.

| Control | Inherited enforcement | Prod override |
|---|---|---|
| `BAK-001` | block (scope-conditioned) | `block` — unconditional in production |
| `NET-001` | warn (scope-conditioned) | `block` — unconditional in production |
| `OBS-001` | warn | `block` — health check mandatory in production |

Nothing is advisory in production. All controls from `PROF-SERVICE-V1` are at `block`
enforcement in production; the overrides promote the three formerly-advisory controls.

### Profile declaration convention

Repositories declare both profiles, selecting the appropriate one per deployment manifest:

```yaml
# staging .compliance-manifest.yaml
declared_profiles:
  - PROF-SERVICE-V1
  - PROF-SERVICE-STAGING-V1

# production .compliance-manifest.yaml
declared_profiles:
  - PROF-SERVICE-V1
  - PROF-SERVICE-PROD-V1
```

The more specific environment profile takes precedence for `enforcement_override` resolution.
`PROF-SERVICE-V1` is always included to anchor the full control list.

---

## Consequences

- `04-profiles/PROF-SERVICE-STAGING-V1.yaml` and `04-profiles/PROF-SERVICE-PROD-V1.yaml` are
  created in this change.
- `02-taxonomy/repository-types.yaml` is updated: the `service` type's `applicable_profiles`
  list adds `PROF-SERVICE-STAGING-V1` and `PROF-SERVICE-PROD-V1`.
- The OPA policy engine must resolve `enforcement_override` from the most specific profile
  declared in the manifest. The compliance reviewer must verify resolution order.
- Any service that declares `PROF-SERVICE-PROD-V1` and does not satisfy `OBS-001`, `NET-001`,
  or `BAK-001` will have its deployment gate blocked — there is no advisory escape.
- A future ADR will address multi-environment manifests (single repo, multiple manifests) once
  `forge validate-repo` supports manifest discovery.
