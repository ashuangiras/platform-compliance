# 05-mappings/mappings — Mapping Collection Files

This directory contains mapping collection files, each grouping related mappings from one or more standard sources to control domains.

## File format

Each file uses the collection format (validated by `../../schemas/mapping-collection.schema.json`):

```yaml
source_id: SRC-...       # primary source (informational)
domain: SRC              # primary domain (informational)
mappings:
  - id: MAP-...-SRC-001
    source_id: SRC-...
    source_clause: "..."
    control_id: SRC-001
    rationale: "..."
    mapping_type: derived
    mapped_date: "YYYY-MM-DD"
    mapped_by: platform-team
```

## Naming convention

`MAP-{SOURCE_STEM}-{DOMAIN_OR_MULTI}.yaml`

Example: `MAP-OPENSSF-SCORECARD-SRC.yaml`, `MAP-AWS-WAF-MULTI.yaml`

## Schema

All files conform to `../../schemas/mapping-collection.schema.json` (not `mapping.schema.json`, which validates individual objects).

## What does NOT belong here

- Standard source registrations (those are in `../../01-sources/registry/`)
- Control definitions (those are in `../../03-catalogs/controls/`)
