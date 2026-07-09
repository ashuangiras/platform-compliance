# Phase 04 — Schemas for All Governance Objects

**Status:** ✅ Complete  
**Tasks:** PC-0020 to PC-0033

## Goal
Every structured object type in the system has a machine-readable JSON Schema definition.

## Deliverables (complete)
All 16 schemas in `schemas/`:

| Schema | Validates |
|---|---|
| `standard-source.schema.json` | `01-sources/registry/*.yaml` |
| `control.schema.json` | `03-catalogs/controls/**/*.yaml` |
| `profile.schema.json` | `04-profiles/PROF-*.yaml` |
| `mapping.schema.json` | Individual mapping objects |
| `mapping-collection.schema.json` | `05-mappings/mappings/*.yaml` (grouped files) |
| `binding.schema.json` | `06-bindings/bindings/**/*.yaml` |
| `policy-check.schema.json` | `07-policies/**/*.check.yaml` |
| `evidence.schema.json` | Evidence records in `08-evidence/` |
| `assessment.schema.json` | `09-assessments/reports/**/*.yaml` |
| `waiver.schema.json` | `09-assessments/waivers/*.yaml` |
| `repository-compliance.schema.json` | `.compliance-manifest.yaml` in any repo |
| `service-contract.schema.json` | `service-contract.yaml` in service repos |
| `adr.schema.json` | ADR front-matter metadata |
| `change-record.schema.json` | `09-assessments/changes/*.yaml` |
| `release-record.schema.json` | `09-assessments/releases/*.yaml` |
| `incident-record.schema.json` | `09-assessments/incidents/*.yaml` |

All 16 pass `check-jsonschema --check-metaschema` validation.

## Key design decisions
- `$schema` is allowed as a property in all schemas (permits editor tooling without validation failures)
- `additionalProperties: false` on all schemas (strict — unknown fields are rejected)
- All schemas follow ADR-0005 (JSON Schema = JSON, everything else = YAML)

## Outstanding
- PC-0033: Test fixtures for 12 newer schemas — evidence fixtures complete (4); remaining 11 schema types need at least one valid + one invalid fixture
