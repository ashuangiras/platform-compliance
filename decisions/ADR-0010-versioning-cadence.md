# ADR-0010: Platform versioning semantics and release cadence

| Field | Value |
|---|---|
| **ID** | ADR-0010 |
| **Status** | accepted |
| **Date** | 2026-07-09 |
| **Deciders** | platform-team |

---

## Context

Without defined versioning semantics, consuming repositories cannot reason about what upgrading their `platform-compliance-ref` pin means. A policy that was `warn` could become `block`. A new mandatory control could appear. This ADR establishes what constitutes a PATCH, MINOR, or MAJOR version bump, the release cadence, and the migration obligations for consuming repositories.

---

## Decision

### Semantic versioning semantics

#### PATCH (v1.0.0 → v1.0.1)
Changes with **zero consumer impact**. Safe to pick up without review:
- Documentation, README, and comment fixes
- Filling `[PLACEHOLDER: ...]` markers with real clause references
- Test fixture additions or corrections
- Schema description improvements (no structural changes)
- Deferred control additions to the profile's `deferred` category

#### MINOR (v1.0.0 → v1.1.0)
**Additive changes** that may require action but do not newly block any existing gate:
- Adding a new control in `manual_initially` category (warns, does not block)
- Activating a previously deferred control in `manual_initially`
- Adding a new binding or OPA policy for an existing control
- Adding optional schema fields
- Adding a new deferred control to the profile
- Releasing a new compliance profile (e.g., `PROF-TERRAFORM-MODULE-V1`)

**Consumer impact:** Low. Review the CHANGELOG. New controls may produce new evidence types. No gate that currently passes will newly block.

#### MAJOR (v1.0.0 → v2.0.0)
**Breaking changes** that will cause new gate failures in consuming repositories:
- Promoting a `manual_initially` control to `enforcement: block`
- Adding a new mandatory blocking control to the merge gate
- Changing a gate enforcement from `warn` or `notify` to `block`
- Removing a waiver pathway
- Schema changes that remove required fields or narrow allowed values (e.g., tightening a regex pattern)
- Removing a profile version

**Consumer impact:** High. Read the `migration_guide` in the release record. A 4-week transition window applies (see below).

---

### Release cadence

| Version type | Trigger |
|---|---|
| PATCH | Documentation fixes and placeholder resolutions accumulate; released on-demand or weekly |
| MINOR | Significant feature complete (new profile, new policy set, new control in `manual_initially`); monthly or milestone-driven |
| MAJOR | Profile breaking change; quarterly or less. Requires 4-week pre-announcement |

**Key rule:** No MAJOR release without a minimum **4-week notice period**. The notice is issued as a GitHub release marked `pre-release`, allowing consuming repositories to prepare.

---

### Migration window for MAJOR releases

When a MAJOR release promotes a control to blocking or adds a mandatory blocking control:

1. A pre-release tag is pushed **4 weeks before** the final MAJOR tag (e.g., `v2.0.0-rc.1`)
2. The final MAJOR tag is pushed after the 4-week window
3. During the transition window, consuming repositories **may pin to the MAJOR release with a temporary waiver** for the newly-blocking control — see `templates/waiver.template.yaml`
4. After the transition window, no waivers are auto-granted; each waiver requires explicit approval per ADR-0007

The `migration_guide` field in the release record (`09-assessments/releases/v{X}.{Y}.{Z}.yaml`) specifies exactly what consuming repositories must do.

---

### Downstream notifications (Dependabot-style)

When a new `platform-compliance` version is released, consuming repositories **should be automatically notified** via a GitHub Actions workflow that opens a pull request in each registered downstream repository, bumping the `platform-compliance-ref` pin.

**Implementation:** A `notify-consumers.yml` workflow in `platform-compliance` runs on release publication. It reads a registry of consuming repositories (to be defined in a future ADR or config file) and opens a PR in each one updating the pin. This is deferred to Phase C (multi-repo expansion); until then, consuming repositories are responsible for watching the GitHub releases feed.

---

## Consequences

- Every commit to `main` must include a conventional commit message indicating the change type (`fix:` → PATCH, `feat:` → MINOR, `feat!:` or `BREAKING CHANGE:` → MAJOR).
- The CHANGELOG must be updated on every release; the release record schema enforces `release_summary` and `breaking_changes` fields.
- Schema changes that narrow `pattern` values or remove `enum` options are MAJOR regardless of how minor they appear.
- The `self-compliance.yml` workflow pins to `"main"` for the platform's own CI; downstream repos must pin to a specific tag.
