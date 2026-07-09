# Phase 05 — Mapping and Provenance Model

**Status:** ✅ Complete  
**Tasks:** PC-0034 to PC-0039

## Goal
Every active control has at least one formal mapping record linking it to a registered external standard or platform decision.

## Deliverables (complete)
10 mapping collection files in `05-mappings/mappings/`:

| File | Source(s) | Domain(s) |
|---|---|---|
| `MAP-OPENSSF-SCORECARD-SRC.yaml` | Scorecard v2 | SRC |
| `MAP-OPENSSF-SCORECARD-SEC.yaml` | Scorecard v2 | SEC |
| `MAP-OPENSSF-SCORECARD-DOC.yaml` | Scorecard v2 | DOC |
| `MAP-OPENSSF-MULTI-SUP.yaml` | Scorecard v2 + SLSA v1 | SUP |
| `MAP-CIS-DOCKER-RUN.yaml` | CIS Docker 1.6 | RUN + OBS + SUP |
| `MAP-OPENGITOPS-MULTI.yaml` | OpenGitOps v1 | SRC + IAC + SUP |
| `MAP-GOOGLE-SRE-OBS.yaml` | Google SRE | OBS + INC + BAK |
| `MAP-AWS-WAF-MULTI.yaml` | AWS WAF 2024 | SEC + OBS + BAK + NET + RUN |
| `MAP-ITIL-ADAPTED-CHG.yaml` | ITIL 4 (adapted) | CHG + INC |
| `MAP-NYGARD-ADR-DOC.yaml` | Nygard ADR 2011 | DOC |

All 10 files validate against `mapping-collection.schema.json`.

## Outstanding
- PC-0009/0010/0011: Fill `[PLACEHOLDER: ...]` clause references (see Phase 02)
- No mapping files exist for RUN-003, CHG-001, OBS-002, NET-001 domain controls from AWS-WAF and ITIL sources — these have inline `mapped_standards` in the control files but no formal mapping records yet
