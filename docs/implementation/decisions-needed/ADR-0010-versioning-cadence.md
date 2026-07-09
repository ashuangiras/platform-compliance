# ADR-0010 Proposal — Platform Versioning and Release Cadence

**Priority:** 🟠 HIGH  
**Blocks:** Phase A/B (release process clarity), downstream repo migration planning

---

## The decision

What constitutes a PATCH, MINOR, or MAJOR version bump in `platform-compliance`? How frequently are versions released? What is the migration obligation for consuming repositories?

---

## Why this matters

Without clear versioning semantics, consuming repositories cannot reason about what upgrading from `v1.0.0` to `v1.1.0` means. A policy that was `warn` could become `block`. A new mandatory control could appear. They need to know what to expect before they update the pin in their CI.

---

## Proposed versioning semantics

### PATCH (v1.0.0 → v1.0.1)
Changes that do not affect any gate, control enforcement, or schema:
- Documentation fixes
- README improvements
- Comment clarifications in policy files
- Fixing a `[PLACEHOLDER: ...]` with the real clause reference
- Adding a deferred control to the profile's `deferred` category
- Test fixture additions

**Consumer impact:** None. Safe to pick up without review.

### MINOR (v1.0.0 → v1.1.0)
Additive changes that may require action but do not break the existing gate:
- Adding a new control in `manual_initially` category (warns, doesn't block yet)
- Adding a new binding or policy for an existing control
- Activating a previously deferred control in `manual_initially` (not blocking)
- New schema optional fields
- New policy for a control already in the profile
- Adding a new deferred control to the profile

**Consumer impact:** Low. Review the CHANGELOG. New controls may generate new evidence types. No existing gate should newly block.

### MAJOR (v1.0.0 → v2.0.0)
Breaking changes that will cause new gate failures in consuming repositories:
- Promoting a `manual_initially` control to `automated_required` with `enforcement: block`
- Adding a new mandatory blocking control to the merge gate
- Changing a gate enforcement from `warn` to `block`
- Removing a waiver pathway
- Schema changes that remove required fields or narrow allowed values

**Consumer impact:** High. Read the `migration_guide` in the release record. Consuming repos must action the new requirements before upgrading their pin.

---

## Proposed release cadence

| Cadence | What triggers it |
|---|---|
| PATCH | Whenever documentation or placeholder fixes accumulate (weekly or on-demand) |
| MINOR | When a significant new feature is complete (monthly or milestone-driven) |
| MAJOR | When the profile changes in a breaking way (quarterly or less often) |

**Key rule:** No MAJOR release without a minimum 4-week notice period. Consuming repositories need time to prepare.

---

## Migration obligation

When a MINOR release introduces a new `manual_initially` control:
- Consuming repos have until the `automation_deadline` in the profile to provide evidence
- If they don't act before the deadline, a future MINOR/MAJOR release may promote it to blocking

When a MAJOR release promotes a control to blocking:
- The `migration_guide` in the release record specifies what consuming repos must do
- A **4-week transition window** is provided: during this period, consuming repos can run with a temporary waiver
- After the transition window, the control is blocking without waiver

---

## What to decide
1. Confirm PATCH/MINOR/MAJOR semantics above (or propose changes)
2. Confirm the 4-week migration window for MAJOR releases
3. Decide: should consuming repos be automatically notified via a GitHub Dependabot-like PR when a new `platform-compliance` version is released?
