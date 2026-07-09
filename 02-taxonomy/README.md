# 02-taxonomy — Platform Taxonomy

This directory defines the controlled vocabularies used across the entire compliance system. Every enumerated value used in any governance object (controls, profiles, bindings, evidence records, etc.) must be defined here before it can be used.

## What this directory owns

- Vocabulary YAML files — one per classification dimension

## Currently defined vocabulary files

| File | Purpose |
|---|---|
| `control-domains.yaml` | 13 domain codes (SRC, SUP, IAC, RUN, NET, SEC, OBS, BAK, CHG, INC, CAT, REL, DOC) |
| `enforcement-levels.yaml` | mandatory, recommended, informational; priority levels P1–P4 |
| `risk-levels.yaml` | critical, high, medium, low, informational; with remediation SLAs |
| `control-types.yaml` | preventive, detective, corrective, directive, compensating |
| `automation-status.yaml` | automated, partially-automated, manual, automation-target, not-automatable |
| `repository-types.yaml` | terraform-module, terraform-root, service, platform-repo, library, documentation |
| `technology-contexts.yaml` | github, terraform, docker, runtime-linux, github-actions |

## File format

Flat YAML files. Each file defines a named list of valid values with descriptions. No formal schema — these files are authoritative as written.

## Adding a new value

Adding a value to an existing vocabulary requires a pull request. The PR must update the vocabulary file and every schema that uses that vocabulary's values as an enum. Adding a new vocabulary file requires an ADR.

## What does NOT belong here

- Control definitions (those are in `../03-catalogs/`)
- Object instances
- Any enumerated value used only in a single file (inline that value)
- Free-form documentation

## Connection to the rest of the architecture

`02-taxonomy/` has no upstream dependencies within this repository. Every other domain directory depends on it. Because all enumerations are centralised here, schema validators can enforce referential integrity: a control that uses an invalid `domain` value fails schema validation.
