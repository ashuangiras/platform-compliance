package platform.sup.sup_003_github

# Control:  SUP-003 — Dependabot vulnerability alerts must be enabled
# Binding:  BIND-SUP-003-GITHUB
# Standard: SRC-OPENSSF-SCORECARD-V2 (Vulnerabilities check)
#
# Input schema:
#   input.vulnerability_alerts_enabled       — bool (true/false) or absent
#   input.automated_security_fixes_enabled   — bool (true/false) or absent
#   input.repository.name                    — Repository name
#
# Results:
#   pass           — alerts AND automated fixes both enabled
#   warn           — alerts enabled, automated fixes disabled (does not block gate)
#   fail (block)   — alerts not enabled
#   not_applicable — vulnerability_alerts_enabled field is absent/non-boolean

import future.keywords.if

# ─── Default: error if no input ───────────────────────────────────────────────
default result := {
	"result": "error",
	"details": {"message": "SUP-003 policy error: missing vulnerability alert data"},
}

# ─── NOT APPLICABLE ───────────────────────────────────────────────────────────
# Guard: vulnerability_alerts_enabled is not a boolean — field is absent or null,
# meaning this repository context does not expose Dependabot status.
result := {
	"result": "not_applicable",
	"details": {"message": "SUP-003: vulnerability_alerts_enabled not present; Dependabot check skipped"},
} if {
	not vuln_status_known
}

# ─── PASS ─────────────────────────────────────────────────────────────────────
result := {
	"result": "pass",
	"details": {
		"checked":  sprintf("Dependabot alerts and automated fixes in '%v'", [input.repository.name]),
		"found":    "vulnerability_alerts_enabled: true, automated_security_fixes_enabled: true",
		"expected": "Both Dependabot alerts and automated security fixes enabled",
		"message":  "SUP-003: Dependabot alerts and automated security fixes are enabled",
	},
} if {
	vuln_status_known
	input.vulnerability_alerts_enabled == true
	input.automated_security_fixes_enabled == true
}

# ─── WARN ─────────────────────────────────────────────────────────────────────
# Alerts active but auto-fixes disabled — advisory only, does not block merge gate.
result := {
	"result": "warn",
	"details": {
		"checked":  sprintf("Dependabot automated security fixes in '%v'", [input.repository.name]),
		"found":    "vulnerability_alerts_enabled: true, automated_security_fixes_enabled: false or absent",
		"expected": "automated_security_fixes_enabled: true",
		"message":  "SUP-003: Dependabot alerts are enabled but automated security fixes are disabled. Enable automated security fixes to auto-create dependency update PRs.",
	},
} if {
	vuln_status_known
	input.vulnerability_alerts_enabled == true
	input.automated_security_fixes_enabled != true
}

# ─── FAIL ─────────────────────────────────────────────────────────────────────
result := {
	"result": "fail",
	"details": {
		"checked":  sprintf("Dependabot vulnerability alerts in '%v'", [input.repository.name]),
		"found":    "vulnerability_alerts_enabled: false",
		"expected": "vulnerability_alerts_enabled: true",
		"message":  "SUP-003: Dependabot vulnerability alerts are not enabled. Enable them to receive alerts for known vulnerabilities in dependencies.",
	},
} if {
	vuln_status_known
	input.vulnerability_alerts_enabled != true
}

# ─── Guard predicate ──────────────────────────────────────────────────────────
# Ensures not_applicable is mutually exclusive with fail/warn/pass.
vuln_status_known if {
	is_boolean(input.vulnerability_alerts_enabled)
}
