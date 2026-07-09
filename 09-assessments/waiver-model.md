# Waiver Model

**Repository:** `platform-compliance`  
**Date:** 2026-07-08  
**Schema:** [`../schemas/waiver.schema.json`](../schemas/waiver.schema.json)

---

## What a waiver is

A waiver is a documented, time-bounded, explicitly approved exception to a platform control for a specific resource. A waiver is not silence. It is not a suppression. It is an explicit risk acceptance that:

- Names the control being waived
- Explains why it cannot currently be satisfied
- States the risk accepted by not satisfying it
- Identifies who approved it
- Expires on a defined date

Waivers appear in every assessment report that covers the waived control. They are never hidden.

---

## Waiver lifecycle

```
[Proposed]
    │  Author creates waiver record; submits PR to 09-assessments/waivers/
    │  PR reviewed per normal merge gate (SRC-001, SRC-002, SEC-001 must pass)
    ▼
[Active]
    │  PR merged; waiver is in effect
    │  Referenced in .compliance-manifest.yaml of the affected repository
    │  Appears in all assessment reports for the affected control + resource
    │
    ├──── Normal expiry path:
    │     30 days before expiry_date: continuous audit generates a renewal reminder
    │     If renewed → new waiver record created; old waiver expires naturally
    │     If not renewed → waiver expires; control reverts to failing
    ▼
[Expired]   ← status set automatically when expiry_date passes
    │  The control reverts to its pre-waiver result in assessments
    │  Expired waivers are retained (not deleted) for audit history
    │
    └──── OR revocation path:
[Revoked]   ← status set manually before expiry_date
    │  Requires a PR to the waiver record with revocation_reason populated
    │  Used when the waiver reason no longer applies or was approved in error
```

---

## Waiver fields

Every waiver record must include these fields (full schema in `../schemas/waiver.schema.json`):

| Field | Required | Description |
|---|---|---|
| `id` | Yes | `WAV-{CONTROL_ID}-{YYYYMM}-{NNN}` |
| `schema_version` | Yes | Schema version |
| `control_id` | Yes | The control being waived |
| `resource_ref.type` | Yes | `repository`, `service`, or `environment` |
| `resource_ref.identifier` | Yes | Specific resource URL or name |
| `rationale` | Yes | Why the control cannot currently be satisfied (min 20 chars) |
| `risk_acceptance_statement` | Yes | Explicit statement of accepted risk (min 20 chars, distinct from rationale) |
| `compensating_controls` | No | Control IDs that partially mitigate the gap |
| `approved_by` | Yes | Named approver (P1 controls: platform-owner required) |
| `approved_date` | Yes | When approval was granted |
| `expiry_date` | Yes | **No open-ended waivers. Always required.** |
| `review_date` | No | Intermediate review before expiry |
| `status` | Yes | `active`, `expired`, or `revoked` |
| `revocation_reason` | Conditional | Required when `status: revoked` |

---

## Approval levels

The required approver level depends on the priority of the waived control:

| Control priority | Required approver | Maximum waiver duration |
|---|---|---|
| P1 (critical) | Platform-owner sign-off | 90 days |
| P2 (high) | Platform-team review | 180 days |
| P3 (medium) | Compliance contact review | 1 year |
| P4 (low) | Self-attested with documented rationale | 1 year |

These are maximum durations. A waiver may be granted for a shorter period. Renewals require fresh approval.

---

## Writing a good waiver

A waiver with insufficient rationale will be rejected at review. The following tests should be applied:

**Rationale must be specific.** "We can't do this yet" is not a valid rationale. "This service's persistent volume backup is managed by the hypervisor's snapshot capability, and the service contract tooling to declare this is not yet implemented" is valid.

**Risk acceptance must be distinct.** The rationale explains why the control is not satisfied. The risk acceptance statement explains what risk that creates and why it is acceptable. These are different questions.

**Compensating controls should be listed.** If any other control partially mitigates the gap, list it. This does not excuse the primary waiver but demonstrates thoughtful risk management.

**Expiry must be realistic.** Do not set an expiry date that is unreachable (e.g., waiving a control for 1 year because fixing it would take 1 year). The expiry should be the date by which the control will be satisfied. If the fix genuinely requires a year, document that and set a 90-day review date.

---

## How waivers affect assessment reports

When the assessment generator processes a failing control:

1. It checks the subject's `.compliance-manifest.yaml` for `waiver_ids`
2. For each listed waiver ID, it loads the waiver from `09-assessments/waivers/`
3. If the waiver matches `control_id` and `resource_ref`, is `status: active`, and `expiry_date` is in the future: the control result becomes `waived`
4. The assessment report's `control_results` entry for this control lists the `waiver_id`
5. The assessment's `overall_result` becomes `pass-with-waivers` if otherwise passing

A waiver does not prevent evidence collection. Evidence records for the waived control continue to be written with `result: fail` (or the actual result). The waiver is applied at assessment time, not evidence time. This means removing a waiver immediately causes the next assessment to show the true compliance state.

---

## Viewing active waivers

All active waivers are visible in:
1. `09-assessments/waivers/` — the canonical waiver records
2. `.compliance-manifest.yaml` of each affected repository — the `waiver_ids` field
3. Every assessment report covering the waived control — the `waiver_id` field in `control_results`

There is no way to have a silent waiver. A waiver that is not recorded in all three locations is either incorrectly applied or has not been properly approved.

---

## Waiver for platform-compliance itself

`platform-compliance` governs itself and therefore may also require waivers. For example:

- If `SRC-004` (signed commits) were activated before key management infrastructure existed, a waiver would be required
- If the `BAK-001` backup policy for `platform-compliance`'s evidence storage is not yet defined

Waivers for `platform-compliance` itself follow the same process. They are filed in `09-assessments/waivers/` and referenced in `/.compliance-manifest.yaml`.

---

## What waivers are not

- **Not a bypass**: Evidence collection continues; the waiver only affects the assessment result
- **Not retroactive**: A waiver does not change the result of assessments generated before the waiver was approved
- **Not transferable**: A waiver for repository A does not apply to repository B, even if they have the same failing control
- **Not permanent**: Every waiver has an expiry date; there are no open-ended waivers
