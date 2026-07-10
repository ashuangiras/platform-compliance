<!--
  Pull request template for platform-compliance.
  The "Agent Readiness & Retro" section is required by AGT-014 — complete it (tick the boxes and
  fill the retro) before merge. AGT-013 requires an entry in .github/AGENT_LEARNINGS.md in this PR.
-->

## Summary

<!-- What this change does and why. -->

## Change Record

Change Record: CHG-YYYYMMDD-NNN

<!--
  Replace the placeholder above with the actual change record ID.
  Allocate one with: forge new change-record --compliance-dir .
  CHG-001 policy requires the format "Change Record: CHG-YYYYMMDD-NNN" on one line.
-->

---

## Agent Readiness & Retro (required — AGT-014)

**Readiness check** — confirm before merge:

- [ ] Agent configuration still passes the AGT suite locally (`tools/check-agents.sh`)
- [ ] Any new/changed workflow, control, or convention is reflected in the relevant agent
      instructions
- [ ] The pre-flight / post-flight checklists and specialist tool scopes are still accurate

**Retrospective** — what did this change teach us, and how did the agents improve?

- <!-- Replace this line with at least one substantive bullet point describing what was learned
     and how any agent instruction file was improved. A checkbox-only retro will not pass
     the AGT-014 gate. Example: "SEC-009 was missing evidence_type registration; added to
     control-author pre-flight step 4." -->
  .github/AGENT_LEARNINGS.md (required — AGT-013).
-->

-
