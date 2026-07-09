package platform.chg.chg_001_github

# Control:  CHG-001 — Significant changes to platform-compliance must include a change record
# Binding:  BIND-CHG-001-GITHUB
# Standard: SRC-ITIL-ADAPTED (Change Enablement)
#
# Input schema (from GitHub PR context in CI):
#   input.repository.name
#   input.repository.type
#   input.pr_body               — full PR description text
#   input.changed_files[]       — list of changed file paths in the PR
#   input.is_platform_repo      — bool: is this a platform-repo type?

import future.keywords.if
import future.keywords.in

# Normative content paths that require a change record
normative_paths := {
	"03-catalogs/",
	"04-profiles/",
	"05-mappings/",
	"06-bindings/",
	"07-policies/",
	"schemas/",
	"09-assessments/gates/",
}

# Check if any changed file is in a normative path
touches_normative_content if {
	file := input.changed_files[_]
	prefix := normative_paths[_]
	startswith(file, prefix)
}

# Check if PR body contains the change record pattern
has_change_record if {
	regex.match(`(?i)change\s+record\s*:\s*CHG-\d{8}-\d{3}`, input.pr_body)
}

default result := {
	"result": "error",
	"details": {"message": "CHG-001 policy error: missing PR context data"},
}

# Not applicable to non-platform repos
result := {
	"result": "not_applicable",
	"details": {"message": "CHG-001: Only applies to platform-repo type repositories"},
} if {
	not input.is_platform_repo
}

# Not applicable if no normative files changed
result := {
	"result": "not_applicable",
	"details": {
		"message": "CHG-001: No normative files changed — change record not required",
		"checked_paths": [p | p := normative_paths[_]],
	},
} if {
	input.is_platform_repo
	not touches_normative_content
}

# Pass: normative content changed and change record present
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Change record reference in PR body for '%v'", [input.repository.name]),
		"found":    "PR body contains a valid CHG-YYYYMMDD-NNN reference",
		"expected": "Change Record: CHG-YYYYMMDD-NNN in PR description",
		"message":  "CHG-001: Change record referenced in PR description",
	},
} if {
	input.is_platform_repo
	touches_normative_content
	has_change_record
}

# Fail: normative content changed but no change record
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Change record reference in PR body for '%v'", [input.repository.name]),
		"found":    "No change record reference found in PR description",
		"expected": "Change Record: CHG-YYYYMMDD-NNN anywhere in the PR body",
		"message":  "CHG-001: Add a change record reference to the PR description. Format: 'Change Record: CHG-YYYYMMDD-NNN'",
	},
} if {
	input.is_platform_repo
	touches_normative_content
	not has_change_record
}
