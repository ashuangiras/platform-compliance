# 01-sources/registry — Standard Source Registry Entries

This directory contains one YAML file per registered external standard. A standard must be registered here before any platform control may cite it as provenance.

## Naming convention

```
SRC-{ISSUER}-{STANDARD}-{VERSION_SLUG}.yaml
```

Example: `SRC-CIS-DOCKER-V1-6.yaml`

## Schema

All files conform to `../../schemas/standard-source.schema.json`. Run:

```bash
check-jsonschema --schemafile ../../schemas/standard-source.schema.json {file}.yaml
```

## What does NOT belong here

- Control definitions (those are in `../../03-catalogs/controls/`)
- Mapping records (those are in `../../05-mappings/mappings/`)
- Platform decisions or rationale (those are ADRs in `../../decisions/`)
