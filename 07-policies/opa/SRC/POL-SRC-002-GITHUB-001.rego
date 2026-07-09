package platform.src.src_002_github

# Control:  SRC-002 — Pull requests required for all changes to protected branches
# Binding:  BIND-SRC-002-GITHUB
# Standard: SRC-OPENSSF-SCORECARD-V2 (Code-Review check)
#           SRC-OPENGITOPS-V1 (Principle 2 — Versioned and Immutable)
#
# Input schema: same as SRC-001 — branch protection API response
#   input.branch_protection.required_pull_request_reviews.*
#   input.repository.name
#   input.default_branch

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "SRC-002 policy error: missing input data"},
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("PR requirement on '%v' in '%v'", [input.default_branch, input.repository.name]),
		"found":    sprintf("Required approvals: %v, stale review dismissal: enabled", [input.branch_protection.required_pull_request_reviews.required_approving_review_count]),
		"expected": "Pull requests required with ≥1 approval and stale review dismissal",
		"message":  "SRC-002: Pull request and code review requirements are correctly configured",
	},
} if {
	count(violations) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("PR requirement on '%v' in '%v'", [input.default_branch, input.repository.name]),
		"found":    sprintf("Violations: %v", [concat(", ", {v | violations[v]})]),
		"expected": "Pull requests required with ≥1 approval and stale review dismissal",
		"message":  sprintf("SRC-002: Code review requirements misconfigured: %v", [concat(", ", {v | violations[v]})]),
	},
} if {
	count(violations) > 0
}

violations[msg] if {
	not input.branch_protection
	msg := "Branch protection is not enabled"
}

violations[msg] if {
	not input.branch_protection.required_pull_request_reviews
	msg := "Pull request reviews not required"
}

violations[msg] if {
	input.branch_protection.required_pull_request_reviews.required_approving_review_count < 1
	msg := sprintf(
		"Required approvals count is %v (minimum: 1)",
		[input.branch_protection.required_pull_request_reviews.required_approving_review_count],
	)
}

violations[msg] if {
	not input.branch_protection.required_pull_request_reviews.dismiss_stale_reviews
	msg := "Stale review dismissal is disabled — approved reviews survive new commits"
}
