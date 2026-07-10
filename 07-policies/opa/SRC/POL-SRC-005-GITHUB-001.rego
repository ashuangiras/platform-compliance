package platform.src.src_005_github

# Control:  SRC-005 — All commits must follow Conventional Commits format
# Binding:  BIND-SRC-005-GITHUB
# Standard: SRC-CONVENTIONAL-COMMITS

import future.keywords.if

default result := {
	"result": "error",
	"details": {"message": "SRC-005 policy error: missing input data"},
}

# NOT APPLICABLE — no Go module in this repository (SRC-005 is wired via go context)
result := {
	"result": "not_applicable",
	"details": {"message": "SRC-005: no Go module detected (has_go_module: false)"},
} if {
	input.has_go_module != true
}

# PASS
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Conventional Commits enforcement for '%v'", [input.repository.name]),
		"found":    "commitlint CI step and config both present",
		"expected": "conventional_commits_enforced == true",
		"message":  "SRC-005: Conventional Commits CI enforcement is in place",
	},
} if {
	input.has_go_module == true
	input.source_hygiene.conventional_commits_enforced == true
}

# FAIL
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Conventional Commits enforcement for '%v'", [input.repository.name]),
		"found":    "no commitlint CI step detected in .github/workflows/",
		"expected": "conventional_commits_enforced == true",
		"message":  "SRC-005: Add a commitlint step to your CI workflow to enforce Conventional Commits.",
	},
} if {
	input.has_go_module == true
	input.source_hygiene.conventional_commits_enforced != true
}
