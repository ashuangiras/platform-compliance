# Authoring Controls

**Repository:** `platform-compliance`  
**Date:** 2026-07-09

This guide covers the complete process for adding a new control to the platform control catalog. Every step is required. Skipping a step produces an invalid control that will fail schema validation.

---

## Before you start

**Is a new control the right answer?** Ask these questions first:

1. Does an existing control already cover this requirement with a different scope condition?
2. Is this requirement better expressed as an update to an existing control's `implementation_expectations` rather than a new control?
3. Is there an external standard that supports this requirement? If not, consider whether it belongs as a platform decision (ADR) rather than a control.

If the answer to all three is "no, a new control is needed" — proceed.

---

## Step 1: Register or confirm the standard source

Every active control must have at least one mapping to a registered standard source.

**Check `01-sources/registry/` first.** If the standard is already registered, use its existing ID.

If the standard is not registered:
1. Create `01-sources/registry/SRC-{ISSUER}-{STANDARD}-{VERSION}.yaml` using the `standard-source.schema.json` schema
2. Set `role:` to the appropriate value (normative, adopted, adapted, informative, deferred)
3. If `role: adapted`, document the adaptation rationale in `notes:`
4. Add the standard to the index table in `01-sources/README.md`

---

## Step 2: Create the mapping record

A mapping connects a specific clause in the registered standard to the new control.

1. Find or create the appropriate mapping collection file in `05-mappings/mappings/`
2. Add a new mapping object to the `mappings:` array:

```yaml
- id: MAP-{SOURCE_ID_STEM}-{DOMAIN}-{NNN}
  source_id: SRC-{ISSUER}-{STANDARD}-{VERSION}
  source_clause: "[PLACEHOLDER: verify the exact clause reference]"
  control_id: {DOMAIN}-{NNN}   # the control you're about to create
  rationale: >
    Why this clause was interpreted as this control in this platform's context.
  mapping_type: derived   # derived | partial | extended | adopted
  mapped_date: "YYYY-MM-DD"
  mapped_by: platform-team
```

Use `[PLACEHOLDER: ...]` if you cannot immediately verify the exact clause reference. The mapping record must exist; the placeholder marks it for future research.

---

## Step 3: Assign a control ID

Control IDs follow the format `{DOMAIN}-{NNN}` where `NNN` is a three-digit sequential number.

1. Find the domain directory: `03-catalogs/controls/{DOMAIN}/`
2. Look at the highest existing ID in that directory
3. Assign the next sequential number
4. **IDs are permanent.** Once assigned and published, a control ID never changes.

---

## Step 4: Write the control YAML

Copy `templates/control.template.yaml` to `03-catalogs/controls/{DOMAIN}/{ID}.yaml` and fill in every required field.

The most important fields to get right:

**`statement:`** Must be normative and testable. Use "must", never "should". A statement like "Repositories should have branch protection" is not valid. "The default branch must have branch protection enabled" is valid.

**`rationale:`** Explain the failure mode. What goes wrong if this control is not satisfied?

**`evidence_required:`** What would a policy check collect to verify this control? The `type` field must match a key in `08-evidence/evidence-types.yaml`. If a new evidence type is needed, add it there first.

**`implementation_expectations:`** This is the human-readable specification that a binding author will use to write the formal binding. Be specific about what artifact or condition must be observable.

**`automation_status:`** Be honest. If you don't have a policy check yet, use `automation-target` or `manual`, not `automated`.

**`lifecycle_status:`** New controls that are not yet enforced by any profile should start as `deferred`. Promote to `active` only when a profile includes them.

---

## Step 5: Add the control to a profile

A control in the catalog that is not in any profile has no enforcement effect. Decide which profile it belongs to and in which category:

| Category | When to use |
|---|---|
| `mandatory` | Control is ready to enforce and should block the applicable gate |
| `manual_initially` | Control is important but automation isn't ready; manual evidence acceptable |
| `deferred` | Control is planned but not yet enforceable; declared for transparency |

Update `04-profiles/PROF-PLATFORM-V1.yaml` (or the appropriate profile). Set `automation_deadline:` for `manual_initially` controls.

---

## Step 6: Write the binding (Phase A requirement)

A control without a binding has no specification for how policy authors should verify it. Write at least one binding in `06-bindings/bindings/{context}/BIND-{CONTROL_ID}-{CONTEXT}.yaml`.

The binding's `specification:` field is the authoritative prose description. The `observable_artifact:` field tells policy authors exactly where to look.

---

## Step 7: Write the policy check (Phase A requirement)

For `automation_status: automated` controls, a policy check is required before the control is classified as `mandatory` (not `manual_initially`). See `07-policies/opa/README.md` for the policy authoring guide.

---

## Step 8: Submit the change

Open a PR to `platform-compliance` that includes:
- The new control YAML (`03-catalogs/controls/`)
- The mapping record update (`05-mappings/mappings/`)
- The profile update (`04-profiles/`)
- Any binding (`06-bindings/`) and policy (`07-policies/`) changes
- A change record (`templates/change-record.template.yaml`)
- An ADR (`templates/adr-template.md`) if the change affects the compliance model significantly

The PR description must include: `Change Record: CHG-YYYYMMDD-NNN`

---

## Validation

Before opening the PR, validate locally:

```bash
# Validate the control against its schema
check-jsonschema --schemafile schemas/control.schema.json \
  03-catalogs/controls/{DOMAIN}/{ID}.yaml

# Validate the profile still passes
check-jsonschema --schemafile schemas/profile.schema.json \
  04-profiles/PROF-PLATFORM-V1.yaml

# Cross-check: source ID exists
grep "source_id:" 03-catalogs/controls/{DOMAIN}/{ID}.yaml | \
  awk '{print $2}' | while read sid; do
    [ -f "01-sources/registry/${sid}.yaml" ] || echo "MISSING SOURCE: $sid"
  done

# If OPA policy was written, test it
opa test 07-policies/opa/{DOMAIN}/ --ignore "*.yaml"
```

---

## Common mistakes

| Mistake | Correct approach |
|---|---|
| Using "should" in the statement | Use "must" — controls are normative requirements |
| `lifecycle_status: active` with no mapping | Active controls must have at least one mapped_standards entry |
| `automation_status: automated` with no policy check | No policy = automation-target, not automated |
| Missing `evidence_required` | Every control needs at least one evidence type defined |
| Forgetting the change record | Every PR touching normative content requires a change record |
