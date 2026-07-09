# ADR-0012 Proposal — Multi-Environment Gate Differentiation

**Priority:** 🟡 MEDIUM  
**Blocks:** Phase C (first service deploying to both staging and production)

---

## The decision

Should staging and production environments have different compliance gate criteria? If so, how is the differentiation expressed?

---

## Current state

`PROF-PLATFORM-V1` applies uniformly to all repositories regardless of deployment environment. `deployment-gate.yaml` is a single file with no environment-specific branching. A deployment to staging uses the same gate as a deployment to production.

---

## The problem this causes

When `platform-services` deploys the first service:
- Staging is where things are tested — some controls will legitimately fail initially
- If staging has the same blocking gate as production, development velocity suffers
- Teams need a path to deploy-to-staging-first before all production gate controls are met

This is a tension between "compliance-first" and "operational velocity." The answer is not to lower the bar — it's to differentiate what the bar means at each stage.

---

## Options

### Option A — Environment-specific profiles

Create separate profiles for staging and production:

```yaml
# PROF-STAGING-V1: all merge gate controls mandatory; deployment gate relaxed
deployment_gate:
  required_controls:
    - id: OBS-001
      enforcement: warn    # was block in production
    - id: BAK-001
      enforcement: warn    # stateful services: warn in staging, block in production
```

Repositories declare both profiles with conditions:
```yaml
declared_profiles:
  - PROF-PLATFORM-V1         # for merge and release gates
  - PROF-STAGING-V1          # for staging deployments
  - PROF-PRODUCTION-V1       # for production deployments
```

**Pros:** Explicit, transparent, auditable. The profile difference is documented.

**Cons:** More profiles to maintain. Profile inheritance helps but adds complexity.

### Option B — Scope conditions in a single profile based on `environment_type`

Add `environment_type` to the deployment gate scope conditions:

```yaml
- control_id: BAK-001
  enforcement: block
  scope_condition: "service.type == 'stateful' and environment_type == 'production'"
```

**Pros:** Fewer files. Conditions are readable.

**Cons:** The profile becomes more complex. The `environment_type` must be passed as a workflow input, adding a parameter to every deployment call.

### Option C — No differentiation; use waivers for staging gaps

Keep a single gate. Teams request time-bounded waivers for staging deployments where a control isn't yet met.

**Pros:** Simpler model. No new profile complexity.

**Cons:** Waiver-for-staging becomes a routine operation rather than an exception. This dilutes the waiver system and creates administrative overhead.

---

## Recommendation

**Option A (environment-specific profiles)** with a base profile they both inherit from.

Structure:
```
PROF-BASE          ← universal mandatory controls (SRC, SEC, basic compliance hygiene)
  ├── PROF-STAGING-V1   ← deployment gate: warn for most controls; useful for velocity
  └── PROF-PRODUCTION-V1 ← deployment gate: block for all; zero tolerance
```

`PROF-PLATFORM-V1` (current) becomes a shorthand for `PROF-PRODUCTION-V1` for platform repos.

---

## What to decide
1. Option A, B, or C?
2. What specific controls are relaxed in staging (warn instead of block)?
3. Are there any controls that remain blocking even in staging? (SEC-001: no secrets — always block)
4. What is the process to "graduate" a service from staging to production gate compliance?
