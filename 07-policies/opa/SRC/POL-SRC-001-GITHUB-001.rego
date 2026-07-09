package platform.src.src_001_github

# Control:  SRC-001 — Default branch must be branch-protected
# Binding:  BIND-SRC-001-GITHUB
# Standard: SRC-OPENSSF-SCORECARD-V2 (Branch-Protection check)
#           SRC-OPENGITOPS-V1 (Principle 2 — Versioned and Immutable)
#
# Input schema:
#   input.branch_protection  — GitHub API response body for branch protection
#                              (null or absent if protection is not enabled)
#   input.repository.name    — Repository name (for error messages)
#   input.default_branch     — Name of the default branch being evaluated

import future.keywords.if
import future.keywords.in

# ─── Default: error if no input ───────────────────────────────────────────────
default result := {
	"result": "error",
	"details": {
		"checked": "GitHub branch protection settings",
		"found":   "No input provided or input malformed",
		"expected": "Branch protection API response",
		"message": "SRC-001 policy error: missing input data",
	},
}

# ─── PASS ─────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Branch protection on '%v' in '%v'", [input.default_branch, input.repository.name]),
		"found":    "All required settings are enabled",
		"expected": "Branch protection: required PR reviews ≥1, stale review dismissal, status checks, no force-push, no deletion",
		"message":  "SRC-001: Branch protection is correctly configured",
	},
} if {
	count(violations) == 0
}

# ─── FAIL ─────────────────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Branch protection on '%v' in '%v'", [input.default_branch, input.repository.name]),
		"found":    sprintf("Missing or misconfigured: %v", [concat(", ", {v | violations[v]})]),
		"expected": "Branch protection: required PR reviews ≥1, stale review dismissal, status checks, no force-push, no deletion",
		"message":  sprintf("SRC-001: Branch protection misconfigured. Violations: %v", [concat(", ", {v | violations[v]})]),
	},
} if {
	count(violations) > 0
}

# ─── NOT APPLICABLE ───────────────────────────────────────────────────────────
# Repository type documentation does not require branch protection
# (uncomment if needed based on manifest scope condition evaluation)
# result := {
#     "result": "not_applicable",
#     "details": {"message": "Repository type is exempt from SRC-001"}
# } if {
#     input.repository.type == "documentation"
# }

# ─── Violation rules ─────────────────────────────────────────────────────────

violations[msg] if {
	not input.branch_protection
	msg := "Branch protection is not enabled"
}

violations[msg] if {
	not input.branch_protection.required_pull_request_reviews
	msg := "Required pull request reviews not configured"
}

violations[msg] if {
	input.branch_protection.required_pull_request_reviews.required_approving_review_count < 1
	msg := sprintf(
		"Required approvals is %v (minimum: 1)",
		[input.branch_protection.required_pull_request_reviews.required_approving_review_count],
	)
}

violations[msg] if {
	not input.branch_protection.required_pull_request_reviews.dismiss_stale_reviews
	msg := "Stale review dismissal is not enabled"
}

violations[msg] if {
	not input.branch_protection.required_status_checks
	msg := "Required status checks not configured"
}

violations[msg] if {
	input.branch_protection.allow_force_pushes.enabled == true
	msg := "Force pushes are allowed (must be disabled)"
}

violations[msg] if {
	input.branch_protection.allow_deletions.enabled == true
	msg := "Branch deletions are allowed (must be disabled)"
}
