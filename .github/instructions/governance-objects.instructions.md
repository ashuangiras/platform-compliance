---
description: "Use when authoring or editing platform-compliance governance objects — standards (01-sources), controls (03-catalogs), profiles (04-profiles), mappings (05-mappings), or bindings (06-bindings). Covers ID conventions, required schema fields, taxonomy registration, and validation."
applyTo: "01-sources/**/*.yaml, 03-catalogs/**/*.yaml, 04-profiles/**/*.yaml, 05-mappings/**/*.yaml, 06-bindings/**/*.yaml"
---
# Authoring Governance Objects

Full guide: [docs/authoring-controls.md](../../docs/authoring-controls.md).
Traceability rules: [docs/traceability-model.md](../../docs/traceability-model.md).

## Golden rule — validate everything

Every object MUST validate against its schema before commit:

```bash
/tmp/penv/bin/check-jsonschema --schemafile schemas/control.schema.json 03-catalogs/controls/QUA/QUA-001.yaml
```

Schema map: control → `control.schema.json`, mapping collection → `mapping-collection.schema.json`,
binding → `binding.schema.json`, profile → `profile.schema.json`, source → `source.schema.json`.

## ID conventions

- Control: `<DOMAIN>-NNN` (e.g. `QUA-001`), file at `03-catalogs/controls/<DOMAIN>/<ID>.yaml`.
- Binding: `BIND-<CONTROL>-<CONTEXT>` under `06-bindings/bindings/<context>/`.
- Source: `SRC-<SHORT-NAME>` under `01-sources/registry/`.
- Every `<DOMAIN>` and `<context>` MUST already exist in `02-taxonomy/`. Register new
  vocabulary (taxonomy file **and** the schema `enum`) in the same change, before first use.

## Referential integrity

- A control's `mapped_standards` must reference `SRC-*` IDs that exist in `01-sources/registry/`.
- Every control referenced by a profile must exist (or be listed under `not_applicable`).
- Every binding must reference an existing control and an existing context.
- New enforceable controls need: control + mapping entry + binding + OPA policy + `POLICY_MAP`
  entry in `run-all-policies.py`. A control with no policy is documentation, not enforcement.

## Enforcement semantics

- `enforcement: block` fails the gate; `warn` records a finding without failing.
- Language/context-specific controls (QUA, TST, API, ARC) belong in **language profiles**
  (e.g. `PROF-GO-SERVICE-V1`), NOT in `PROF-BASE`.
- Coverage/quality thresholds that will tighten later start as `warn` and are promoted to
  `block` at a named version — state that in the control's rationale.
