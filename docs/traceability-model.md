# Traceability Model

**Repository:** `platform-compliance`  
**Date:** 2026-07-08

This document describes how any compliance check in the platform traces back to a registered external standard or a ratified Architecture Decision Record. It is the provenance guide for the system.

---

## Table of Contents

1. [The provenance chain](#1-the-provenance-chain)
2. [Reading a control's provenance](#2-reading-a-controls-provenance)
3. [Following the full trace](#3-following-the-full-trace)
4. [ID naming conventions and how they connect](#4-id-naming-conventions-and-how-they-connect)
5. [Placeholder markers and known gaps](#5-placeholder-markers-and-known-gaps)
6. [Tracing from a CI failure back to its standard](#6-tracing-from-a-ci-failure-back-to-its-standard)
7. [What breaks the chain](#7-what-breaks-the-chain)
8. [Audit trail summary](#8-audit-trail-summary)

---

## 1. The provenance chain

Every compliance check in the platform exists within a seven-link chain:

```
External Standard
    │
    │  registered as
    ▼
Standard Source Entry         (01-sources/registry/SRC-*.yaml)
    │
    │  cited by
    ▼
Mapping Record                (05-mappings/mappings/MAP-*.yaml)
    │
    │  derives
    ▼
Platform Control              (03-catalogs/controls/{DOMAIN}/{ID}.yaml)
    │
    │  included in
    ▼
Compliance Profile            (04-profiles/PROF-*.yaml)
    │
    │  implemented by
    ▼
Implementation Binding        (06-bindings/bindings/{context}/BIND-*.yaml)
    │
    │  encoded as
    ▼
Policy Check                  (07-policies/{engine}/{DOMAIN}/POL-*.{ext})
    │
    │  produces
    ▼
Evidence Record               (08-evidence/collected/{repo}/...)
    │
    │  aggregated into
    ▼
Assessment Report             (09-assessments/reports/{repo}/ASSESS-*.yaml)
```

No link in this chain can be skipped. A policy check that has no binding has no specification. A binding that has no control has no authority. A control that has no mapping has no provenance. An assessment that has no evidence has no basis.

---

## 2. Reading a control's provenance

Every control YAML file in `03-catalogs/` contains a `mapped_standards` field that lists the standards sources and clauses that motivate the control, with a rationale for each mapping.

Example: `03-catalogs/controls/SRC/SRC-001.yaml`

```yaml
id: SRC-001
title: Default branch must be branch-protected
domain: SRC
...
mapped_standards:
  - source_id: SRC-OPENSSF-SCORECARD-V2
    clause: "Branch-Protection check"
    mapping_note: >
      Scorecard's Branch-Protection check directly tests whether branch
      protection is enabled with the required settings.
  - source_id: SRC-OPENGITOPS-V1
    clause: "Principle 2 — Versioned and Immutable"
    mapping_note: >
      GitOps Principle 2 requires that desired state be stored immutably
      with complete version history. Branch protection enforces this.
```

This entry tells you:
- **Where to find the standard:** `01-sources/registry/SRC-OPENSSF-SCORECARD-V2.yaml` for the full registration, including the canonical URL and retrieval date
- **What clause motivates the control:** The Branch-Protection check in Scorecard v2
- **Why this clause was interpreted as this control:** The `mapping_note` provides the rationale

The formal mapping record in `05-mappings/` expands this with a stable mapping ID, the formal clause reference, and a more detailed rationale.

---

## 3. Following the full trace

### Trace example: "Why does my CI check branch protection?"

**Start:** A CI job fails with a message referencing `SRC-001`.

**Step 1 — Find the control:**
```
03-catalogs/controls/SRC/SRC-001.yaml
```
Read the `statement`, `rationale`, and `mapped_standards` fields.

**Step 2 — Find the standard source:**
```
01-sources/registry/SRC-OPENSSF-SCORECARD-V2.yaml
```
This gives you the OpenSSF Scorecard's name, version, publisher, canonical URL (`https://securityscorecards.dev/`), and the date it was retrieved and registered.

**Step 3 — Find the binding:**
```
06-bindings/bindings/github/BIND-SRC-001-GITHUB.yaml
```
This tells you exactly what GitHub settings must be configured to satisfy `SRC-001` in the GitHub context — the specific branch protection settings, the API endpoint to verify them, and which policy check verifies them.

**Step 4 — Find the policy:**
```
07-policies/{engine}/SRC/POL-SRC-001-GITHUB.{ext}
```
This is the executable rule. Its companion metadata file (`POL-SRC-001-GITHUB.check.yaml`) links back to the binding ID and the evidence type it produces.

**Step 5 — Find the evidence:**
```
08-evidence/collected/{repo}/{commit-sha}-SRC-001-{timestamp}.yaml
```
This is the actual evidence record for a specific run: what was checked, when, against which commit, and what the result was.

**Step 6 — Find the assessment:**
```
09-assessments/reports/{repo}/ASSESS-{repo}-{date}.yaml
```
This shows the aggregated verdict for the repository, including SRC-001's contribution to the overall result.

### Answering "Why does this control exist?"

The answer is always: `03-catalogs/controls/{DOMAIN}/{ID}.yaml` → `rationale` field → `mapped_standards` → `01-sources/registry/{SRC-ID}.yaml` → `source_url`.

The chain from control to external standard is two hops: control → mapping → standard source. It can be traversed in either direction.

---

## 4. ID naming conventions and how they connect

IDs in this system are designed to be self-describing and to reflect their position in the chain.

### Standard source IDs

```
SRC-{ISSUER}-{STANDARD}-{VERSION}

Examples:
  SRC-OPENSSF-SCORECARD-V2    → OpenSSF Scorecard, version 2.x
  SRC-CIS-DOCKER-V1-6         → CIS Docker Benchmark, version 1.6
  SRC-OPENGITOPS-V1           → OpenGitOps, version 1.0
```

The `SRC-` prefix is not a domain code — it stands for "Source" and distinguishes these IDs from control IDs.

### Control IDs

```
{DOMAIN}-{NNN}

Examples:
  SRC-001    → Source Control domain, control 001
  SEC-002    → Security domain, control 002
  IAC-001    → Infrastructure as Code domain, control 001
```

Control IDs never change. A deprecated control retains its ID with `lifecycle_status: deprecated`. The domain prefix always matches the subdirectory under `03-catalogs/controls/`.

### Mapping IDs

```
MAP-{SOURCE_ID_STEM}-{DOMAIN}-{NNN}

Examples:
  MAP-OPENSSF-SCORECARD-SRC-001   → Scorecard → SRC domain, mapping 001
  MAP-CIS-DOCKER-RUN-001          → CIS Docker → RUN domain, mapping 001
```

A mapping ID encodes both the source and the destination domain, making it easy to see at a glance which standards inform which control domains.

### Binding IDs

```
BIND-{CONTROL_ID}-{CONTEXT}

Examples:
  BIND-SRC-001-GITHUB       → SRC-001 in the GitHub context
  BIND-IAC-001-TERRAFORM    → IAC-001 in the Terraform context
  BIND-SUP-002-DOCKER       → SUP-002 in the Docker context
```

### Policy check IDs

```
POL-{CONTROL_ID}-{CONTEXT}-{NNN}

Examples:
  POL-SRC-001-GITHUB-001      → First policy check for SRC-001 in GitHub context
  POL-IAC-001-TERRAFORM-001   → First policy check for IAC-001 in Terraform context
```

### Evidence record IDs

```
{UUID-v4}
```

Evidence records use UUIDs because they are generated at runtime by CI systems, not authored by humans. The UUID provides global uniqueness without requiring coordination.

### Assessment report IDs

```
ASSESS-{SUBJECT_SLUG}-{YYYYMMDD}-{NNN}

Example:
  ASSESS-PLATFORM-COMPLIANCE-20260708-001
```

### Profile IDs

```
PROF-{CONTEXT}-{VARIANT}

Examples:
  PROF-PLATFORM-V1         → Platform compliance profile, version 1
  PROF-TERRAFORM-MODULE-V1 → Profile for Terraform module repositories, version 1
```

### ADR IDs

```
ADR-{NNNN}

Examples:
  ADR-0001   → First ADR; compliance-first architecture
  ADR-0002   → Second ADR; GitHub as primary remote
```

ADR IDs are sequential and never reused. The zero-padded four-digit format supports up to 9,999 ADRs before requiring a format change.

---

## 5. Placeholder markers and known gaps

Where clause-level details in standards have not been researched and verified, the field contains a `[PLACEHOLDER: ...]` marker. This is not a gap in the traceability chain — it is a documented acknowledgment that the research is incomplete. The structure of the chain is correct; only one detail is pending.

Example in a control:
```yaml
mapped_standards:
  - source_id: SRC-CIS-DOCKER-V1-6
    clause: "[PLACEHOLDER: CIS Docker 4.x — verify exact section number]"
    mapping_note: >
      CIS Docker section 4.x addresses image labelling requirements.
      The exact section number will be confirmed when the full document
      is reviewed.
```

**A `[PLACEHOLDER: ...]` is never treated as satisfying a mapping requirement.** It is a work item. The roadmap task `PC-0009` through `PC-0011` covers resolving the primary placeholder clusters. Until resolved, assessments that check provenance completeness will flag the placeholder as a known gap rather than a failure.

Placeholders are permitted in v1.0.0 with the following constraints:
- The mapping record and control must exist (the placeholder is a clause detail, not the whole mapping)
- The placeholder must describe what needs to be researched
- There must be a roadmap task assigned to resolve it

---

## 6. Tracing from a CI failure back to its standard

When a CI compliance check fails, the failure message includes the control ID. The following procedure resolves any control ID back to its external standard source.

```bash
# 1. Read the control file to understand what it requires and why
cat 03-catalogs/controls/{DOMAIN}/{CONTROL-ID}.yaml

# Key fields to read:
#   statement    — what must be true
#   rationale    — why this control exists
#   mapped_standards — which standards inform this control

# 2. Read the standard source entry for each mapped standard
cat 01-sources/registry/{SRC-ID}.yaml

# Key fields:
#   name, version, publisher — identify the standard
#   source_url               — where to find the original document
#   role                     — how the platform relates to this standard
#   notes                    — adaptation rationale if role is "adapted"

# 3. Find the implementation binding for your technology context
cat 06-bindings/bindings/{context}/BIND-{CONTROL-ID}-{CONTEXT}.yaml

# Key fields:
#   specification         — what must be observable to satisfy the control
#   observable_artifact   — specific, locatable artifact or configuration
#   policy_check_ids      — which policies verify this binding

# 4. Read the policy check metadata
cat 07-policies/{engine}/{DOMAIN}/POL-{CONTROL-ID}-{CONTEXT}.check.yaml

# Key fields:
#   pass_criteria   — human description of what passing looks like
#   fail_criteria   — human description of what failing looks like
#   evidence_type   — what evidence type this check produces
```

This procedure can be executed by any operator without special access. All the information needed to understand why a check exists and what it requires is in the repository itself.

---

## 7. What breaks the chain

The following conditions indicate a broken provenance chain and are treated as compliance defects within `platform-compliance` itself:

| Condition | Why it breaks the chain |
|---|---|
| A control cites a `source_id` that does not exist in `01-sources/registry/` | The standard source is not registered; the control's authority is unclaimed |
| A control has `lifecycle_status: active` but no `mapped_standards` entries | An active control with no provenance is an ungrounded assertion |
| A binding references a `control_id` that does not exist in `03-catalogs/` | The binding has no corresponding control specification |
| A policy check has no companion `.check.yaml` metadata file | The policy check is unregistered; it has no formal connection to the binding it implements |
| An evidence record references a `policy_check_id` that does not exist | The evidence cannot be attributed to a known check |
| A profile references a `control_id` that does not exist in the catalog | The profile is internally inconsistent |

These conditions are detected by the platform's self-compliance tooling and produce failing evidence records in the assessment report for `platform-compliance` itself.

---

## 8. Audit trail summary

For any given check in a downstream repository's CI, the complete audit trail is:

| Question | Answer found in |
|---|---|
| What failed? | CI job output; evidence record `result` field |
| What control does this check implement? | Policy metadata `.check.yaml` → `binding_id` → `control_id` |
| What does the control require? | `03-catalogs/controls/{DOMAIN}/{ID}.yaml` — `statement` field |
| Why does this control exist? | Same file — `rationale` field |
| What standard motivates this control? | Same file — `mapped_standards` → `01-sources/registry/{SRC-ID}.yaml` |
| Where is the original standard? | `01-sources/registry/{SRC-ID}.yaml` — `source_url` field |
| How should the control be satisfied in my context? | `06-bindings/bindings/{context}/BIND-{ID}-{CONTEXT}.yaml` |
| What was the CI actually checking? | Policy file in `07-policies/` |
| What evidence does this check produce? | Evidence record in `08-evidence/collected/` |
| What is the overall compliance verdict? | Assessment report in `09-assessments/reports/` |
| What platform decision explains this design? | `decisions/ADR-*.md` |

---

*This document is the traceability reference for `platform-compliance`. It must be updated whenever the ID naming conventions or chain structure changes. Changes require a change record (CHG-001).*
