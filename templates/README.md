# templates — Authoring Templates

This directory contains human-facing starter templates for every governance object type. A template is a minimal, valid skeleton of an object type with comments explaining each field.

## What this directory owns

- One template file per governance object type
- The ADR template (`adr-template.md`) for authoring Architecture Decision Records

## Status: partially populated

| Template | Status |
|---|---|
| `adr-template.md` | Complete |
| `control.template.yaml` | Not yet authored (Phase 11, PC-0078) |
| `profile.template.yaml` | Not yet authored (Phase 11, PC-0078) |
| `mapping.template.yaml` | Not yet authored (Phase 11, PC-0078) |
| `binding.template.yaml` | Not yet authored (Phase 11, PC-0078) |
| `evidence-record.template.yaml` | Not yet authored (Phase 11, PC-0078) |
| `assessment-report.template.yaml` | Not yet authored (Phase 11, PC-0078) |
| `waiver.template.yaml` | Not yet authored (Phase 9, PC-0068) |
| `compliance-manifest.template.yaml` | Not yet authored (Phase 11, PC-0077) |
| `service-contract.template.yaml` | Not yet authored (Phase 11, PC-0078) |
| `change-record.template.yaml` | Not yet authored (Phase 11, PC-0078) |
| `release-record.template.yaml` | Not yet authored (Phase 11, PC-0078) |
| `incident-record.template.yaml` | Not yet authored (Phase 11, PC-0078) |

## Template conventions

- Templates are valid instances of their schema: a template rendered without modification must pass schema validation
- All required fields are populated with representative example values
- Fields are annotated with inline YAML comments explaining purpose and valid values
- Optional fields are present but commented out (showing availability without requiring completion)

## How templates are used

- The platform CLI (`tools/plt/`) uses templates when scaffolding new objects: `plt new control`
- Human authors copy the relevant template and fill in the fields
- CI validation checks that all objects in the numbered directories pass their schema — using the template as a starting point helps avoid validation failures

## What does NOT belong here

- Schema definitions (those are in `../schemas/`)
- Actual object instances (those belong in the numbered directories)
- ADRs themselves (those are in `../decisions/`)
