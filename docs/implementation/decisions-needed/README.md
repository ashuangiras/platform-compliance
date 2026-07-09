# Decisions Needed — ADR Proposal Queue

These are architecture decisions that have been identified as necessary but not yet ratified. Each file in this directory is a structured proposal — not a ratified ADR.

**Process:** Read the proposal → decide → write the formal ADR in `decisions/` → delete the proposal from this directory.

## Priority order

| Priority | ADR | Decision needed | Phase blocked |
|---|---|---|---|
| ✅ RESOLVED | ADR-0006 | Evidence storage strategy | — |
| ✅ RESOLVED | ADR-0007 | Waiver approval governance | — |
| 🟠 HIGH | ADR-0008 | Secret management backend | Phase C |
| 🟠 HIGH | ADR-0009 | OPA policy bundle distribution | Phase A/B |
| 🟠 HIGH | ADR-0010 | Platform versioning and release cadence | Phase A/B |
| 🟡 MEDIUM | ADR-0011 | `plt` CLI technology selection | Phase B |
| 🟡 MEDIUM | ADR-0012 | Multi-environment gate differentiation | Phase C |
| 🟡 MEDIUM | ADR-0013 | Compliance dashboard architecture | Phase D |
| 🟢 LOW | ADR-0014 | Terraform state backend selection | Phase C |
| 🟢 LOW | ADR-0015 | Self-hosted Git mirror strategy | Phase D |

## How to use these proposals

Each proposal contains:
- The decision question
- Why it's blocking (what can't be built without it)
- The options with trade-offs
- A recommended option with reasoning

When the team decides, use `templates/adr-template.md` to write the formal ADR in `decisions/`, then delete or archive the proposal file here.
