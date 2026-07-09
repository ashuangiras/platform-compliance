package platform.sec.sec_002_github

# Control:  SEC-002 — GitHub secret scanning with push protection must be enabled
# Binding:  BIND-SEC-002-GITHUB
# Standard: SRC-OPENSSF-SCORECARD-V2 (Secrets check)
#
# Input schema:
#   input.repository.name
#   input.repository.security_and_analysis.secret_scanning.status
#   input.repository.security_and_analysis.secret_scanning_push_protection.status

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "SEC-002 policy error: missing repository security settings"},
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Secret scanning and push protection status in '%v'", [input.repository.name]),
		"found":    "Both secret scanning and push protection are enabled",
		"expected": "security_and_analysis.secret_scanning.status == enabled AND secret_scanning_push_protection.status == enabled",
		"message":  "SEC-002: GitHub secret scanning and push protection are correctly enabled",
	},
} if {
	count(violations) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Secret scanning and push protection in '%v'", [input.repository.name]),
		"found":    sprintf("Disabled or misconfigured: %v", [concat(", ", {v | violations[v]})]),
		"expected": "Both enabled",
		"message":  sprintf("SEC-002: %v. Enable in Settings → Code security and analysis.", [concat("; ", {v | violations[v]})]),
	},
} if {
	count(violations) > 0
}

violations[msg] if {
	input.repository.security_and_analysis.secret_scanning.status != "enabled"
	msg := sprintf(
		"Secret scanning is '%v' (required: enabled)",
		[input.repository.security_and_analysis.secret_scanning.status],
	)
}

violations[msg] if {
	input.repository.security_and_analysis.secret_scanning_push_protection.status != "enabled"
	msg := sprintf(
		"Push protection is '%v' (required: enabled)",
		[input.repository.security_and_analysis.secret_scanning_push_protection.status],
	)
}
