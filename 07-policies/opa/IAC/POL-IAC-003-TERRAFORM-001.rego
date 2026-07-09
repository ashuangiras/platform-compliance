package platform.iac.iac_003_terraform

# Control:  IAC-003 — Terraform modules must not contain hardcoded environment-specific values
# Binding:  BIND-IAC-003-TERRAFORM
# Standard: SRC-OPENGITOPS-V1 (Principle 1 — Declarative)
#
# Input schema (from collect-terraform-info.sh):
#   input.repository.name
#   input.hardcoded_violations[]     — pre-computed by scan tool or regex
#   input.hardcoded_violations[].file
#   input.hardcoded_violations[].line
#   input.hardcoded_violations[].pattern
#   input.hardcoded_violations[].value
#   input.hardcoded_violations[].severity

import future.keywords.if
import future.keywords.in

default result := {
	"result": "error",
	"details": {"message": "IAC-003 policy error: missing terraform analysis data"},
}

result := {
	"result": "not_applicable",
	"details": {"message": "IAC-003: No terraform files found — not applicable"},
} if {
	not input.hardcoded_violations
}

result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Hardcoded value scan in '%v'", [input.repository.name]),
		"found":    "No hardcoded environment-specific values detected",
		"expected": "No literal IP addresses, account IDs, or environment names in module code",
		"message":  "IAC-003: No hardcoded values detected",
	},
} if {
	is_array(input.hardcoded_violations)
	count(input.hardcoded_violations) == 0
}

result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Hardcoded value scan in '%v'", [input.repository.name]),
		"found":    sprintf("%v hardcoded value(s) detected", [count(input.hardcoded_violations)]),
		"expected": "All environment-specific values parameterised as input variables",
		"message":  sprintf("IAC-003: Parameterise these values: %v", [concat("; ", [sprintf("%v:%v (%v)", [v.file, v.line, v.pattern]) | v := input.hardcoded_violations[_]])]),
		"violations": input.hardcoded_violations,
	},
} if {
	is_array(input.hardcoded_violations)
	count(input.hardcoded_violations) > 0
}
