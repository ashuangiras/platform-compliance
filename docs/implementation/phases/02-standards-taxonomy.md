# Phase 02 — Standards Registry and Taxonomy

**Status:** ✅ Complete  
**Tasks:** PC-0007 to PC-0011

## Goal
Establish the platform's shared vocabulary (taxonomy) and register the external standards that provide provenance for all controls.

## Deliverables (complete)
- 9 source registry entries (`01-sources/registry/*.yaml`)
- 7 taxonomy vocabulary files (`02-taxonomy/*.yaml`)
- `schemas/standard-source.schema.json` — validated
- All 9 source entries pass schema validation

## Outstanding
- **PC-0009:** Resolve `[PLACEHOLDER: ...]` markers for OpenSSF Scorecard exact check IDs — requires reading Scorecard v2 documentation
- **PC-0010:** Resolve `[PLACEHOLDER: ...]` for CIS Docker 1.6.0 exact section numbers — requires accessing the registered document
- **PC-0011:** Resolve `[PLACEHOLDER: ...]` for SLSA v1.0 Build track requirement IDs — requires reading SLSA v1.0 spec

## Note on placeholders
All controls have at least one mapping record even where the clause detail is a placeholder. The provenance chain is structurally complete; only the leaf-level clause reference needs confirmation. These can be resolved incrementally without blocking any other phase.
