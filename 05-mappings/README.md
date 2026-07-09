# 05-mappings — Standards-to-Control Mappings

This directory contains the provenance layer of the compliance system: the explicit, documented linkage between specific clauses in registered external standards and platform controls.

## What this directory owns

- Mapping YAML files linking standard clauses to control IDs

## File format

All mapping files conform to `../schemas/mapping.schema.yaml`.

File naming: `MAP-{SOURCE_ID_STEM}-{DOMAIN}-{NNN}.yaml`

Example: `MAP-OPENSSF-SCORECARD-SRC-001.yaml`

## Status

**Not yet populated.** Mapping files will be authored in Phase 5 of the implementation roadmap (tasks PC-0035 to PC-0039). Controls currently contain inline `mapped_standards` references; formal mapping records are the next step.

## What a mapping record contains

Each mapping record links:
- A `source_id` — the registered standard (from `../01-sources/registry/`)
- A `source_clause` — the specific clause, section, or check within that standard
- A `control_id` — the platform control it informs (from `../03-catalogs/controls/`)
- A `mapping_type` — `derived`, `partial`, or `extended`
- A `rationale` — why this clause was interpreted as this control in this platform's context

## Why mappings are a separate layer

Controls contain an inline `mapped_standards` field for human readability. Formal mapping records in this directory provide:
- Stable mapping IDs that can be cited (e.g., in future tooling or audit exports)
- A separation between the control definition (what must be satisfied) and its provenance (why it must be satisfied)
- A query surface: "which controls are derived from CIS Docker?" is answerable by scanning this directory

## What does NOT belong here

- Control definitions (those are in `../03-catalogs/`)
- Standard source registrations (those are in `../01-sources/`)
- Binding specifications (those are in `../06-bindings/`)
- Any file that is not a standard-to-control mapping record
