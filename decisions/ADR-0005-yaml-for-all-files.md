# ADR-0005: YAML for all human-authored files; JSON Schema (.schema.json) only for schemas

| Field | Value |
|---|---|
| **ID** | ADR-0005 |
| **Status** | accepted |
| **Date** | 2026-07-09 |
| **Deciders** | platform-team |

---

## Context

The repository accumulated a mixed file format without an explicit decision: governance objects (sources, controls, profiles, bindings, assessments) were authored in YAML, JSON Schema definitions were authored in JSON, and OPA policy test fixtures were created in JSON (following the OPA CLI's native format convention). This resulted in 23 JSON fixture files alongside hundreds of YAML governance files, with no documented rationale.

The audit (see `docs/audits/audit-2026-07-08.md`, finding L-001) flagged this as a source of confusion. The question was: should the repository standardise on a single format, and if so, which?

We considered three options:

**Option A — YAML for all human-authored content; JSON Schema only for schema files**  
Every file a person reads or writes is YAML, with one clear exception: `.schema.json` files, because JSON Schema is a JSON-native standard.

**Option B — Keep the current mixed state with documented rationale**  
Two formats remain; an ADR explains why. This legitimises the split but does not eliminate the confusion.

**Option C — JSON everywhere**  
All files, including controls, profiles, and governance objects, become JSON. Human readability and the ability to annotate files with comments is lost.

The key argument for Option A is the direction in which the mixed state was already trending: governance objects were universally YAML, test fixtures were JSON only because OPA's CLI historically preferred it. That historical reason has been obsolete since OPA 0.21 (2021). The current version pinned in ADR-0004 is 0.70.

---

## Decision

**The platform uses YAML for all human-authored files. JSON Schema definition files (`.schema.json`) are the sole exception.**

Specifically:

- **`.schema.json`** — JSON Schema definitions in `schemas/`. JSON Schema is a JSON-native standard; its `$id`, `$ref`, `$schema`, and meta-schema resolution are all grounded in JSON. This is a genuine technical constraint, not a preference.
- **`.yaml`** — everything else:  
  - Standards source registry (`01-sources/`)
  - Taxonomy vocabularies (`02-taxonomy/`)
  - Control catalog (`03-catalogs/`)
  - Compliance profiles (`04-profiles/`)
  - Mapping collections (`05-mappings/`)
  - Implementation bindings (`06-bindings/`)
  - Policy metadata companion files (`07-policies/**/*.check.yaml`)
  - Policy test fixtures (`07-policies/tests/fixtures/**/*.yaml`)
  - Evidence records and ledger definitions (`08-evidence/`)
  - Assessment reports, gate criteria, waivers, release records (`09-assessments/`)
  - Compliance manifests (`.compliance-manifest.yaml`)
  - Templates (`templates/`)
  - ADR metadata front-matter (`decisions/`)
- **`.yml`** — GitHub Actions workflow files (`.github/workflows/*.yml`). The `.yml` extension is the GitHub Actions convention; both `.yaml` and `.yml` are valid YAML. No functional difference; follow the convention for the ecosystem.

The rule stated in one sentence: **if it's not a JSON Schema file, it's YAML.**

---

## Consequences

**Positive:**

- A contributor can apply the format rule without looking it up: everything is YAML unless the filename ends in `.schema.json`.
- YAML enables comments (`#`). Test fixtures can explain *what scenario they test and why*, which is not possible in JSON. This was the primary motivator for OPA fixtures specifically.
- The format of governance objects is consistent. Reading a control, a binding, and its test fixture all uses the same syntax, the same multi-line string conventions, and the same quoting rules.
- The audit finding L-001 (inconsistent `$schema` paths) and the general category of "format mismatch confusion" is eliminated as a source of future issues.

**Negative / trade-offs:**

- OPA's `opa eval --input` command works identically with YAML input in OPA ≥0.21. There is no functional downside to YAML fixtures for OPA evaluation. Any CI script that hardcodes `.json` extensions when running OPA tests must be updated, but this is a one-time change.
- Automated tooling that generates fixture files from JSON API responses must convert to YAML before writing. `yq`, `python -c "import yaml,json; yaml.dump(json.load(...))"`, and similar utilities make this trivial. The conversion is a one-line operation.
- If a future tool in the compliance toolchain genuinely requires JSON input (and has no YAML support), a conversion step is required at the toolchain boundary. This is an acceptable boundary: YAML is the authoring format; JSON is a serialisation option at tool interfaces where necessary.

**Constraints introduced:**

- All new files added to the repository must follow this rule. A pull request that adds a `.json` file outside `schemas/` must be challenged in review, with the rare exception documented with an explicit rationale.
- The CI pipeline (when implemented) should lint file extensions as part of the compliance check for `platform-compliance` itself.
- When referencing OPA test fixtures in documentation or scripts, use `.yaml` extensions. All 23 existing fixtures were converted as part of this decision.

---

## Relation to platform principles

This ADR implements Platform Principle P2 (every control has provenance) applied to the repository's own operating conventions — the format choice now has a documented rationale that any contributor can trace. It also supports Platform Principle P6 (no silent exceptions) by ensuring the format rule has exactly one stated exception.
