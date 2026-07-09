# schemas — Canonical Object Schemas

This directory contains the machine-readable schema definitions for every structured object type in the platform. Schemas are the contracts that enforce structural integrity across the entire system.

## What this directory owns

- JSON Schema files (expressed in YAML) for every governance object type

## Status: partially populated

| Schema | Status |
|---|---|
| `standard-source.schema.yaml` | Complete |
| `control.schema.yaml` | Complete |
| `profile.schema.yaml` | Complete |
| `mapping.schema.yaml` | Not yet authored (Phase 4, PC-0020) |
| `binding.schema.yaml` | Not yet authored (Phase 4, PC-0021) |
| `policy-check.schema.yaml` | Not yet authored (Phase 4, PC-0022) |
| `evidence-record.schema.yaml` | Not yet authored (Phase 4, PC-0023) |
| `waiver.schema.yaml` | Not yet authored (Phase 4, PC-0024) |
| `assessment-report.schema.yaml` | Not yet authored (Phase 4, PC-0025) |
| `compliance-manifest.schema.yaml` | Not yet authored (Phase 4, PC-0026) |
| `adr.schema.yaml` | Not yet authored (Phase 4, PC-0027) |
| `change-record.schema.yaml` | Not yet authored (Phase 4, PC-0028) |
| `release-record.schema.yaml` | Not yet authored (Phase 4, PC-0029) |
| `incident-record.schema.yaml` | Not yet authored (Phase 4, PC-0030) |
| `service-contract.schema.yaml` | Not yet authored (Phase 4, PC-0031) |

## Schema conventions

All schemas follow these conventions:
- `$schema: "https://json-schema.org/draft/2020-12/schema"`
- `$id` set to the relative path within this repository
- `schemaVersion` property on the schema itself
- `additionalProperties: false` to prevent undeclared fields
- `required` array listing all required fields

## Validation

All files placed in the numbered domain directories (`01-sources/` through `09-assessments/`) are validated against their corresponding schema as part of the platform's own compliance CI.

```bash
# Validate a schema file itself is valid JSON Schema
check-jsonschema --check-metaschema schemas/control.schema.yaml

# Validate an instance against its schema
check-jsonschema --schemafile schemas/control.schema.yaml \
  03-catalogs/controls/SRC/SRC-001.yaml
```

## What does NOT belong here

- Object instances (those belong in the numbered directories)
- Template files (those are in `../templates/`)
- Documentation (that is in `../docs/`)
- Any schema specific to a single downstream repository
