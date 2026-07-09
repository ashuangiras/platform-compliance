# Roadmap — Phase Map and Critical Path

**Date:** 2026-07-09

---

## Phase dependency graph

```
HORIZON 1: FOUNDATION (v1.0.0)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[01 Skeleton] ──► [02 Standards/Taxonomy] ──► [03 Controls/Profile]
                                                      │
                                             [04 Schemas] ◄─────┘
                                                      │
                              ┌───────────────────────┤
                              ▼                       ▼
                     [05 Mappings]           [06 Bindings]
                              │                       │
                              └──────────┬────────────┘
                                         ▼
                                   [07 Policies] ◄── ADR-0004 (OPA)
                                         │
                              ┌──────────┤
                              ▼          ▼
                       [08 Evidence]  [09 Assessments] ◄── ADR-0007 (Waivers)
                              │          │
                              └────┬─────┘
                                   ▼
                            [10 Workflows] ◄── ADR-0009 (Policy bundle)
                                   │
                            [11 Manifest]
                                   │
                            [12 v1.0.0 Gate]
                                   │
                                  ◆ v1.0.0 TAG ◆

HORIZON 2: OPERATIONALIZATION (v1.1)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Phase A: Operationalization] ◄── ADR-0006 (Evidence storage)
  └─ Complete workflow TODOs          ADR-0007 (Waiver governance)
  └─ Write remaining policies
  └─ First real CI run on GitHub
  └─ First real evidence + assessment

[Phase B: Tooling/CLI] ◄── ADR-0011 (plt CLI tech)
  └─ `plt` CLI implementation          ADR-0009 (Policy bundle)
  └─ Policy bundle distribution        ADR-0010 (Versioning cadence)
  └─ Developer onboarding complete
                │
               ◆ v1.1.0 TAG ◆

HORIZON 3: PLATFORM GROWTH (v2.0+)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Phase C: Multi-repo] ◄── v1.1.0 prerequisite
  └─ platform-modules (repo 2)          ADR-0008 (Secrets)
  └─ platform-infrastructure (repo 3)   ADR-0012 (Multi-env gates)
  └─ CAT and REL domain controls        ADR-0014 (Terraform state)

[Phase D: Advanced Maturity]
  └─ Compliance dashboard              ADR-0013 (Dashboard)
  └─ SLSA L2 provenance                ADR-0015 (Git mirror)
  └─ SLO tracking and REL controls
  └─ GitOps reconciliation
                │
               ◆ v2.0.0 TAG ◆
```

---

## Critical path to v1.0.0

The minimum sequence that must complete before the `v1.0.0` tag can be applied:

```
ADR-0006 (evidence storage decision)
    → Complete Phase 10 workflow (replace all TODOs)
        → Write remaining Phase 07 policies (release/deployment gate controls)
            → Push repo to GitHub + enable branch protection
                → First CI run produces real evidence
                    → Generate real assessment report from CI
                        → Phase 12: v1.0.0 release gate evaluation
                            → git tag v1.0.0
```

**Time estimate:** 4-6 focused working sessions after ADR-0006 is decided.

---

## Critical path to first downstream repository

```
v1.0.0 tagged
    → ADR-0008 (secret management) decided
        → ADR-0009 (policy bundle distribution) decided
            → platform-modules repo created under governance
```

---

## Phase status summary

| Phase | Title | Status | Key blocker |
|---|---|---|---|
| 01 | Skeleton and architecture docs | ✅ Complete | — |
| 02 | Standards registry and taxonomy | ✅ Complete | — |
| 03 | Control catalog and compliance profile | ✅ Complete | — |
| 04 | Schemas | ✅ Complete | — |
| 05 | Mappings | ✅ Complete | — |
| 06 | Bindings | ✅ Complete | — |
| 07 | Policies | 🔶 Partial (14/~25) | Need release/deploy gate policies |
| 08 | Evidence model | ✅ Complete | — |
| 09 | Assessments, waivers | ✅ Complete | — |
| 10 | Reusable workflow | 🔶 Skeleton | ADR-0006, then implement TODOs |
| 11 | Compliance manifest | ✅ Complete | — |
| 12 | v1.0.0 release gate | ⬜ Not started | Phase 10 must complete |
| A | Operationalization | ⬜ Not started | ADR-0006, ADR-0007 |
| B | Tooling / `plt` CLI | ⬜ Not started | ADR-0011, v1.1 |
| C | Multi-repo platform | ⬜ Not started | v1.0.0 tag, ADR-0008 |
| D | Advanced maturity | ⬜ Not started | v2.0 prerequisites |

---

## Versioning milestones

| Tag | What it means | Prerequisites |
|---|---|---|
| `v1.0.0` | Foundation complete. Workflow runs. Self-assessment passes CI. | Phases 01-12 |
| `v1.1.0` | Operationalization complete. `plt` CLI shipped. Policy bundle published. | Phases A-B |
| `v2.0.0` | Multi-repo platform operational. CAT/REL controls active. | Phases C-D (partial) |

---

## Task counts by phase

| Phase | Total tasks | Done | In-progress | Not started |
|---|---|---|---|---|
| 01–12 (v1.0.0) | 86 | 26 | 1 | 59 |
| A–B (v1.1.0) | ~30 | 0 | 0 | ~30 |
| C–D (v2.0+) | ~40 | 0 | 0 | ~40 |

See [`tasks/`](tasks/) for full task lists.
