# 03-catalogs — Platform Control Catalog

This directory contains the authoritative list of platform controls. A control defines **what must be satisfied** — not how. Implementation detail belongs in bindings (`../06-bindings/`). Policy code belongs in policies (`../07-policies/`).

## What this directory owns

- One YAML file per control, nested under domain subdirectories
- Domain subdirectories: BAK, CAT, CHG, DOC, IAC, INC, NET, OBS, REL, RUN, SEC, SRC, SUP

## File format

All control files conform to `../schemas/control.schema.yaml`.

File naming: `{CONTROL-ID}.yaml` inside the matching domain subdirectory.
Example: `controls/SRC/SRC-001.yaml`

## Current control inventory

| Domain | Controls | Active | Deferred |
|---|---|---|---|
| SRC | SRC-001 to SRC-004 | 3 | 1 (SRC-004) |
| SUP | SUP-001 to SUP-003 | 2 | 1 (SUP-003) |
| IAC | IAC-001 to IAC-003 | 3 | 0 |
| SEC | SEC-001 to SEC-003 | 3 | 0 |
| RUN | RUN-001 to RUN-003 | 3 | 0 |
| OBS | OBS-001 to OBS-002 | 2 | 0 |
| BAK | BAK-001 | 1 | 0 |
| CHG | CHG-001 to CHG-002 | 2 | 0 |
| DOC | DOC-001 to DOC-002 | 2 | 0 |
| INC | INC-001 | 1 | 0 |
| NET | NET-001 | 1 | 0 |
| **Total** | **23** | **21** | **2** |

## Control ID convention

`{DOMAIN}-{NNN}` — three-digit zero-padded sequence per domain, starting at 001.

Control IDs are permanent. A deprecated control keeps its ID with `lifecycle_status: deprecated`. A superseded control keeps its ID with `lifecycle_status: superseded` and a `superseded_by` reference. IDs are never reused.

## Rules for adding a control

1. The domain must exist in `../02-taxonomy/control-domains.yaml`
2. At least one source mapping must exist (or be created simultaneously) in `../05-mappings/`
3. The control must have all required fields as defined in `../schemas/control.schema.yaml`
4. A change record is required (CHG-001)
5. If the control introduces a new domain or changes enforcement model, an ADR is required (DOC-002)

## What does NOT belong here

- Implementation guidance (that is a binding in `../06-bindings/`)
- Policy code (that is in `../07-policies/`)
- Mapping records (those are in `../05-mappings/`)
- Profile definitions (those are in `../04-profiles/`)
- Evidence records or assessment reports
