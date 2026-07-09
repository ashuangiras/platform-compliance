package platform.sec.sec_008_github_actions

# Control:  SEC-008 — No self-hosted runners without documented justification
# Binding:  BIND-SEC-008-GITHUB-ACTIONS
# Standard: SRC-GITHUB-SECURITY-HARDENING, SRC-CIS-CONTROLS-V8 (Control 6.4)

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "SEC-008 policy error: missing input data"},
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("GitHub Actions runner types in '%v'", [input.repository.name]),
		"found":    "No self-hosted runners detected",
		"expected": "Only GitHub-hosted runners (ubuntu-latest, etc.)",
		"message":  "SEC-008: All workflows use GitHub-hosted runners",
	},
} if {
	count(input.workflow_files) > 0
	count(input.self_hosted_jobs) == 0
}

result := {
	"result": "not_applicable",
	"details": {"message": "SEC-008: No GitHub Actions workflow files found"},
} if {
	count(input.workflow_files) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("GitHub Actions runner types in '%v'", [input.repository.name]),
		"found":    sprintf("Self-hosted runner(s) detected in %v job(s)", [count(input.self_hosted_jobs)]),
		"expected": "Only GitHub-hosted runners (ubuntu-latest, etc.)",
		"message":  sprintf("SEC-008: %v self-hosted runner job(s) require documented justification (ADR or waiver).", [count(input.self_hosted_jobs)]),
	},
} if {
	count(input.workflow_files) > 0
	count(input.self_hosted_jobs) > 0
}
