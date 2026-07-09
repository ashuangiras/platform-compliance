# 04-profiles — Compliance Profiles

This directory contains compliance profiles. A profile is a named, versioned set of controls that applies to a class of repository, service, or environment. It is the primary contract between `platform-compliance` and any downstream repository.

## What this directory owns

- One YAML file per named compliance profile

## File format

All profile files conform to `../schemas/profile.schema.yaml`.

File naming: `{PROFILE-ID}.yaml`

Naming convention: `PROF-{CONTEXT}-{VARIANT}.yaml`

## Current profiles

| ID | Applicable to | Version | Status |
|---|---|---|---|
| PROF-PLATFORM-V1 | All platform repositories (initial profile) | 1.0.0 | active |

## How repositories declare a profile

Every repository in the platform declares which profile governs it in its `.compliance-manifest.yaml`:

```yaml
declared_profiles:
  - PROF-PLATFORM-V1
```

This is the entry point for all compliance enforcement. The declared profile drives which policy checks run in CI, which controls are evaluated in assessment reports, and which gate criteria apply.

## Profile versioning

- `PATCH` bump (`1.0.0 → 1.0.1`): non-breaking clarifications
- `MINOR` bump (`1.0.0 → 1.1.0`): additive changes (new deferred/manual controls)
- `MAJOR` bump (`1.0.0 → 2.0.0`): breaking changes (new mandatory blocking controls); requires new file `PROF-PLATFORM-V2.yaml`; the V1 file is not edited in place

Repositories pin to a specific profile version. Profile upgrades are explicit, not silent.

## What does NOT belong here

- Controls themselves (those are in `../03-catalogs/`)
- Bindings (those are in `../06-bindings/`)
- Repository-specific compliance manifests (those live in each downstream repository's root)
- Waivers (those are in `../09-assessments/waivers/`)
