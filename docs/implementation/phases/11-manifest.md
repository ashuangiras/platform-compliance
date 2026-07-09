# Phase 11 — Repository Compliance Manifest

**Status:** ✅ Complete  
**Tasks:** PC-0076 to PC-0080

## Goal
Every platform repository has a `.compliance-manifest.yaml` at its root that declares its profile, type, and contexts — the entry point for all compliance enforcement.

## Deliverables (complete)
- `.compliance-manifest.yaml` at the repo root (platform-compliance governs itself) ✅
- `schemas/repository-compliance.schema.json` ✅
- `templates/compliance-manifest.template.yaml` — annotated template for new repos ✅
- `docs/consuming-compliance.md` — 9-step onboarding guide ✅
- Manifest validates against schema ✅

## The manifest contract (platform-compliance's own)
```yaml
schema_version: "1.0.0"
repository:
  name: platform-compliance
  url: "https://github.com/angirasa_risk/platform-compliance"   # angirasa_risk to be resolved
  type: platform-repo
  has_container_images: false
declared_profiles:
  - PROF-PLATFORM-V1
technology_contexts:
  - github
  - github-actions
compliance_contact: platform-team
last_updated: "2026-07-09"
```

## Outstanding
- `angirasa_risk` placeholder — needs to be replaced with the actual GitHub org name
- `templates/service-contract.template.yaml` — exists in schemas, template not yet authored
