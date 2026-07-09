package platform.sec.sec_004_github_actions

# Control:  SEC-004 — GitHub Actions workflow tokens must use read-only permissions by default
# Binding:  BIND-SEC-004-GITHUB-ACTIONS
# Standard: SRC-GITHUB-SECURITY-HARDENING (Using permissions for the GITHUB_TOKEN)
#           SRC-OPENSSF-SCORECARD-V2 (Token-Permissions check — High risk)
#           SRC-CIS-CONTROLS-V8 (Control 6 — Access Control Management)
#
# Input schema:
#   input.workflow_files_detail  — array of workflow file permission summaries
#   input.repository.name        — repository name

import future.keywords.if
import future.keywords.in

# ─── Default: error if no input ───────────────────────────────────────────────
default result := {
	"result": "error",
	"details": {
		"checked":  "GitHub Actions workflow token permissions",
		"found":    "No input provided or input malformed",
		"expected": "All workflow files with top-level read-only permissions",
		"message":  "SEC-004 policy error: missing input data",
	},
}

# ─── PASS ─────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("GITHUB_TOKEN permissions in %v workflow file(s)", [count(input.workflow_files_detail)]),
		"found":    "All workflow files declare read-only permissions at the top level",
		"expected": "permissions: read-all OR permissions.contents: read (no write at top level)",
		"message":  "SEC-004: All workflow tokens use read-only permissions by default",
	},
} if {
	count(violations) == 0
	count(input.workflow_files_detail) > 0
}

# ─── NOT APPLICABLE ───────────────────────────────────────────────────────────
result := {
	"result": "not_applicable",
	"details": {
		"message": "SEC-004: No GitHub Actions workflow files found in this repository",
	},
} if {
	count(input.workflow_files_detail) == 0
}

# ─── FAIL ─────────────────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("GITHUB_TOKEN permissions in %v workflow file(s)", [count(input.workflow_files_detail)]),
		"found":    sprintf("Insecure token permissions: %v", [concat(", ", {v | violations[v]})]),
		"expected": "permissions: read-all OR permissions.contents: read (no write at top level)",
		"message":  sprintf("SEC-004: Workflow token permissions misconfigured. Violations: %v", [concat(", ", {v | violations[v]})]),
	},
} if {
	count(violations) > 0
}

# ─── Violation rules ──────────────────────────────────────────────────────────

violations[msg] if {
	some wf in input.workflow_files_detail
	wf.permissions_declared == false
	wf.is_reusable != true
	msg := sprintf("%v: no top-level permissions block (defaults allow write access)", [wf.path])
}

violations[msg] if {
	some wf in input.workflow_files_detail
	wf.permissions_declared == true
	wf.top_level_has_write == true
	wf.is_reusable != true
	msg := sprintf("%v: top-level permissions grant write access (must be read-only)", [wf.path])
}
