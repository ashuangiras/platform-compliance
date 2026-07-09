# 01-sources — Standards Source Registry

This directory is the root of the platform's provenance chain. Before any platform control can derive authority from an external standard, that standard must be registered here.

## What this directory owns

- One YAML file per registered external standard
- An index of all registered standards (this README serves as the index)

## File format

All files conform to `../schemas/standard-source.schema.yaml`.

File naming: `{ID}.yaml` where `{ID}` is the stable source identifier assigned at registration.

Naming convention: `SRC-{ISSUER}-{STANDARD}-{VERSION_SLUG}.yaml`

Examples:
- `SRC-OPENSSF-SLSA-V1.yaml`
- `SRC-CIS-DOCKER-V1-6.yaml`

## Currently registered standards

| ID | Name | Role | Status |
|---|---|---|---|
| SRC-OPENSSF-SLSA-V1 | Supply-chain Levels for Software Artifacts v1 | normative | active |
| SRC-OPENSSF-SCORECARD-V2 | OpenSSF Scorecard v2 | normative | active |
| SRC-CIS-DOCKER-V1-6 | CIS Docker Benchmark 1.6.0 | normative | active |
| SRC-OPENGITOPS-V1 | OpenGitOps Principles v1.0 | adopted | active |
| SRC-GOOGLE-SRE | Google SRE Book (2016) | adopted | active |
| SRC-AWS-WAF-2024 | AWS Well-Architected Framework (2024) | adapted | active |
| SRC-ITIL-ADAPTED | ITIL 4 — Platform-Adapted Subset | adapted | active |
| SRC-CNCF-PLATFORM-MATURITY-V1 | CNCF Platform Engineering Maturity Model v1 | informative | active |
| SRC-NYGARD-ADR-2011 | Documenting Architecture Decisions (Nygard 2011) | adopted | active |

## What does NOT belong here

- Control definitions (those are in `../03-catalogs/`)
- Mapping records (those are in `../05-mappings/`)
- Policy documentation or code
- Any document that is not an external standard registration
- Platform-internal decisions (those are ADRs in `../decisions/`)

## How to register a new standard

1. Review `../schemas/standard-source.schema.yaml` for required fields
2. Assign the next available stable ID using the naming convention
3. Create the YAML file in `registry/`
4. Add an entry to the index table in this README
5. Open a pull request; this requires a change record (CHG-001)
6. The standard may be cited in mappings only after the PR is merged
