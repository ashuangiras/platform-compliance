# ADR-0015 Proposal — Self-Hosted Git Mirror Strategy

**Priority:** 🟢 LOW  
**Blocks:** Phase D (if mirror is desired)

---

## The decision

When (if ever) is a self-hosted Git server introduced, and what is its role relative to GitHub?

---

## Context (from ADR-0002)

ADR-0002 established GitHub as the primary root of trust. The original motivation:

> "A self-hosted Git server requires governance to operate correctly, and that governance requires `platform-compliance`, which requires a place to live. The compliance framework must exist before the self-hosted Git server it would govern."

`platform-compliance` now exists. The bootstrapping paradox is resolved. The question is whether and when to introduce a self-hosted mirror.

---

## What "self-hosted mirror" means

A Gitea or Forgejo instance running on platform-managed infrastructure that:
- Mirrors repositories from GitHub (periodic sync)
- Is accessible on the private network
- Provides a local Git endpoint for services that can't reach GitHub

This is NOT a replacement for GitHub in v1.x. It is a resilience/availability mirror.

---

## Trigger conditions for introducing the mirror

The mirror is worth introducing when at least two of these are true:
1. GitHub outages have materially affected platform operations more than once
2. The platform has services that require local Git access (CI runners, deployment tooling)
3. The platform has infrastructure to reliably run a stateful service (BAK-001 satisfied for Gitea)
4. The team is large enough that GitHub Enterprise features are needed

None of these conditions are met at v1.0.0. This decision is genuinely low priority.

---

## If a mirror is introduced: compliance implications

A Gitea/Forgejo instance requires:
1. A new technology context: `gitea` in `02-taxonomy/technology-contexts.yaml`
2. Bindings for SRC-001 and SRC-002 in the `gitea` context (protected branches API is different from GitHub)
3. OPA policies for the Gitea API
4. The mirror service deployed via `platform-services` with a full service contract
5. BAK-001 satisfied: Gitea's repos and database must be backed up

The mirror would NOT become the root of trust unless a future ADR supersedes ADR-0002. Branch protection and code review enforcement would still be on GitHub.

---

## Recommendation

**Do not introduce a self-hosted mirror until Phase C is complete and at least one of the trigger conditions above is met.** This is a Phase D consideration, not Phase A/B/C.

When the mirror is introduced:
- It is a resilience mirror, not a primary source
- It is governed as a platform service (declared profiles, service contract, health check)
- A new ADR superseding ADR-0002 defines the new root-of-trust model

---

## What to decide
1. Confirm: no mirror in Phases A, B, or C
2. If the trigger conditions will be evaluated: who decides when they're met?
3. Technology choice for the mirror: Gitea vs Forgejo (both are actively maintained forks; preference?)
